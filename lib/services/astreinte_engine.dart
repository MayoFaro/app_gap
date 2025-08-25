// lib/services/astreinte_engine.dart
//
// Moteur d'astreintes (avion) — version DAO-first.
// ✅ Cette version ajoute UNIQUEMENT des logs de diagnostic (kAstreinteDebug).
// ❌ Aucune logique fonctionnelle n’a été modifiée.
//
// -----------------------------------------------------------------------------
// MODE DEBUG
// -----------------------------------------------------------------------------

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/planning_dao.dart';
import '../data/app_database.dart';

// Active / coupe tous les logs de ce moteur.
const bool kAstreinteDebug = true;

// Logger local : n’écrit qu’en debug + si kAstreinteDebug=true
void logAst(String msg) {
  if (kDebugMode && kAstreinteDebug) debugPrint(msg);
}

// -----------------------------------------------------------------------------
// Top-level helpers (accessibles partout dans ce fichier)
// -----------------------------------------------------------------------------

String _fmtDateFr(DateTime d) =>
    DateFormat('dd/MM/yy').format(DateTime(d.year, d.month, d.day));

String _weekdayShortFr(DateTime d) {
  switch (d.weekday) {
    case DateTime.monday:
      return 'Lun';
    case DateTime.tuesday:
      return 'Mar';
    case DateTime.wednesday:
      return 'Mer';
    case DateTime.thursday:
      return 'Jeu';
    case DateTime.friday:
      return 'Ven';
    case DateTime.saturday:
      return 'Sam';
    case DateTime.sunday:
      return 'Dim';
  }
  return '';
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

Iterable<DateTime> _daysInclusive(DateTime a, DateTime b) sync* {
  final start = a.isBefore(b) ? a : b;
  final end = a.isBefore(b) ? b : a;
  var cur = _dayOnly(start);
  final last = _dayOnly(end);
  while (!cur.isAfter(last)) {
    yield cur;
    cur = cur.add(const Duration(days: 1));
  }
}

(String, String) canonPair(String a, String b) {
  final aa = a.toUpperCase().trim();
  final bb = b.toUpperCase().trim();
  return (aa.compareTo(bb) <= 0) ? (aa, bb) : (bb, aa);
}

extension _Between on DateTime {
  bool isBetween(DateTime a, DateTime b) => !isBefore(a) && !isAfter(b);
}

// Mémo semé : semaines -1 / -2 avant la période + couples observés
class _SeedHistory {
  final Map<String, List<int>> preWeeksByPilot;   // ex: {'DPS': [-1], 'LCM': [-2], ...}
  final Set<(String, String)> prevCouplesBefore;  // couples canoniques observés S-1 / S-2

  const _SeedHistory({
    required this.preWeeksByPilot,
    required this.prevCouplesBefore,
  });
}

// -----------------------------------------------------------------------------
// Inputs / modèles
// -----------------------------------------------------------------------------

class AstreinteInputs {
  final DateTime start; // inclus
  final DateTime end; // inclus
  final List<DateTime> extraJoursFeries; // saisis dans l’UI
  final Map<int, Set<String>> chefExclusionsByWeek; // index semaine → pilotes exclus

  AstreinteInputs({
    required this.start,
    required this.end,
    this.extraJoursFeries = const [],
    this.chefExclusionsByWeek = const {},
  });
}

class WeekSpan {
  final DateTime monday;
  final DateTime sunday;
  WeekSpan(this.monday, this.sunday);

  @override
  String toString() => 'Semaine(${_fmtDateFr(monday)} → ${_fmtDateFr(sunday)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is WeekSpan && monday == other.monday && sunday == other.sunday;

  @override
  int get hashCode => Object.hash(monday, sunday);
}

class AstreinteProposal {
  final Map<WeekSpan, (String, String)> assignment; // couple par semaine
  final double score; // plus petit = mieux
  final Map<String, int> deltaCriticalDaysByPilot; // +WE/JF ajoutés par le plan
  final Map<String, int> projectedWeJfDaysByPilot; // baseline + plan

  AstreinteProposal({
    required this.assignment,
    required this.score,
    required this.deltaCriticalDaysByPilot,
    required this.projectedWeJfDaysByPilot,
  });
}

// Profil de pondérations pour varier les propositions
class _GreedyProfile {
  final String name;

  // pénalités espacement
  final double hugePenaltyConsec; // 1-1 → très, très cher
  final double penalty101; // 1-0-1
  final double hugePenaltyTriple; // 1-0-1-0-1
  final double wSpacing; // cooldown si gap ≤ 3

  // homogénéisation
  final double balanceWeight; // poids de l'écart max-min
  final double boostLow; // boost (récompense) pour les pilotes très à la traîne

  // variabilité des couples
  final double pairRepeatPenalty; // réutiliser un couple

  // tolérance “dernière chance” quand il n’y a plus de solutions strictes
  final bool allowRelaxed;

  const _GreedyProfile({
    required this.name,
    required this.hugePenaltyConsec,
    required this.penalty101,
    required this.hugePenaltyTriple,
    required this.wSpacing,
    required this.balanceWeight,
    required this.boostLow,
    required this.pairRepeatPenalty,
    required this.allowRelaxed,
  });

  static _GreedyProfile cool() => const _GreedyProfile(
    name: 'cool',
    hugePenaltyConsec: 5000,
    penalty101: 900,
    hugePenaltyTriple: 2500,
    wSpacing: 150,
    balanceWeight: 6,
    boostLow: 2.0,
    pairRepeatPenalty: 60,
    allowRelaxed: false,
  );

  static _GreedyProfile balanced() => const _GreedyProfile(
    name: 'balanced',
    hugePenaltyConsec: 6000,
    penalty101: 700,
    hugePenaltyTriple: 3000,
    wSpacing: 200,
    balanceWeight: 10,
    boostLow: 3.0,
    pairRepeatPenalty: 50,
    allowRelaxed: true,
  );

  static _GreedyProfile aggressive() => const _GreedyProfile(
    name: 'aggressive',
    hugePenaltyConsec: 7000,
    penalty101: 450, // autorise plus le 1-0-1
    hugePenaltyTriple: 3500,
    wSpacing: 220,
    balanceWeight: 14,
    boostLow: 4.0,
    pairRepeatPenalty: 45,
    allowRelaxed: true,
  );
}

// -----------------------------------------------------------------------------
// Moteur principal
// -----------------------------------------------------------------------------

class AstreinteEngine {
  final PlanningDao planningDao;

  /// Optionnel : provider de JF (from..to → dates dayOnly). Si null, pas de JF dynamiques.
  final Future<List<DateTime>> Function(DateTime from, DateTime to)? joursFeriesProvider;

  AstreinteEngine({
    required this.planningDao,
    this.joursFeriesProvider,
  });

  // =========================
  // Public API pour l’UI
  // =========================

  // Mesure la dispo le week-end (sam+dim) : set des pilotes dispo par semaine.
  List<Set<String>> _availabilityByWeekSets({
    required List<String> tris,
    required List<WeekSpan> weeks,
    required Map<String, Set<DateTime>> indisposByPilot,
  }) {
    final out = <Set<String>>[];
    for (final w in weeks) {
      final sat = _dayOnly(w.monday.add(const Duration(days: 5)));
      final sun = _dayOnly(w.monday.add(const Duration(days: 6)));
      final avail = <String>{};
      for (final t in tris) {
        final busy = indisposByPilot[t] ?? const <DateTime>{};
        final can = !(busy.contains(sat) || busy.contains(sun));
        if (can) avail.add(t);
      }
      out.add(avail);
    }
    return out;
  }

  // Trouve des grappes d’étranglement consécutives (<= threshold disponibles)
  List<(int start, int end)> _bottleneckClusters({
    required List<Set<String>> availByWeek,
    required int threshold,
  }) {
    final res = <(int, int)>[];
    int? runStart;
    for (int i = 0; i < availByWeek.length; i++) {
      final tight = availByWeek[i].length <= threshold;
      if (tight) {
        runStart ??= i;
      } else if (runStart != null) {
        res.add((runStart, i - 1));
        runStart = null;
      }
    }
    if (runStart != null) res.add((runStart, availByWeek.length - 1));
    return res;
  }

  // HARD-GUARD : filtre “dur” contre 1-1-1 et 1-1 (sauf dernier recours).
  bool _forbidden11(String p, int w, Map<String, List<int>> assigned) {
    final L = assigned[p] ?? const <int>[];
    return L.contains(w - 1); // 1-1
  }

  bool _forbidden111(String p, int w, Map<String, List<int>> assigned) {
    final L = assigned[p] ?? const <int>[];
    return L.contains(w - 1) && L.contains(w - 2); // 1-1-1
  }

  // Choisit un couple sur une semaine d’étranglement, en respectant les gardes.
  ({String a, String b})? _choosePairForBottleneck({
    required int w,
    required WeekSpan span,
    required List<String> tris,
    required Set<String> available,
    required Map<String, List<int>> assignedWeeksByPilot,
    required Map<String, int> projectedWeJfDays,
    required Set<(String, String)> previousCouples,
    required Map<String, double> prefBoostRetard,
  }) {
    final cand = <({String a, String b, double score})>[];
    final L = available.toList()..sort();
    for (int i = 0; i < L.length; i++) {
      for (int j = i + 1; j < L.length; j++) {
        final a = L[i], b = L[j];

        if (_forbidden111(a, w, assignedWeeksByPilot)) continue;
        if (_forbidden111(b, w, assignedWeeksByPilot)) continue;

        final would11 = _forbidden11(a, w, assignedWeeksByPilot) || _forbidden11(b, w, assignedWeeksByPilot);

        final pa = projectedWeJfDays[a] ?? 0;
        final pb = projectedWeJfDays[b] ?? 0;

        double s = 0;
        s += (max(pa, pb) * 12) + (pa + pb) * 1.0;

        final canon = canonPair(a, b);
        if (previousCouples.contains(canon)) s += 15;

        s -= (prefBoostRetard[a] ?? 0.0);
        s -= (prefBoostRetard[b] ?? 0.0);

        if (would11) s += 2000;

        cand.add((a: a, b: b, score: s));
      }
    }
    if (cand.isEmpty) return null;

    cand.sort((x, y) => x.score.compareTo(y.score));

    final pick = cand.first;
    return (a: pick.a, b: pick.b);
  }

  // Précalcule les verrous (locked) sur les semaines d’étranglement + seed des historiques
  Future<({
  Map<int, (String, String)> lockedByWeek,
  Map<String, List<int>> preWeeksByPilot,
  Set<(String, String)> prevCouplesBefore
  })> _preassignFromBottlenecks({
    required List<String> tris,
    required List<WeekSpan> weeks,
    required Map<String, Set<DateTime>> indisposByPilot,
    required Map<String, int> baseline,
  }) async {
    final availByWeek = _availabilityByWeekSets(
      tris: tris,
      weeks: weeks,
      indisposByPilot: indisposByPilot,
    );

    final threshold = max(2, (tris.length / 2).floor());
    final clusters = _bottleneckClusters(availByWeek: availByWeek, threshold: threshold);

    // Logs diagnostic
    logAst('AST[pre] tris=${tris.length}, weeks=${weeks.length}, threshold=$threshold');
    for (int i = 0; i < weeks.length; i++) {
      final av = availByWeek[i].length;
      if (av <= threshold) {
        logAst('  - tight W${i + 1} ${_fmtDateFr(weeks[i].monday)} avail=$av/${tris.length}');
      }
    }
    if (clusters.isEmpty) {
      logAst('AST[pre] aucun cluster d’étranglement détecté');
    } else {
      logAst('AST[pre] clusters=${clusters.map((e) => '[${e.$1 + 1}..${e.$2 + 1}]').join(', ')}');
    }

    // Préférence retard
    final minDone = baseline.values.isEmpty ? 0 : baseline.values.reduce(min);
    final maxDone = baseline.values.isEmpty ? 0 : baseline.values.reduce(max);
    final spanDone = max(1, maxDone - minDone);
    final boost = <String, double>{
      for (final t in tris) t: ((maxDone - (baseline[t] ?? 0)) / spanDone) * 10.0
    };

    final locked = <int, (String, String)>{};
    final assignedSeed = <String, List<int>>{for (final t in tris) t: <int>[]};
    final prevCouples = <(String, String)>{};
    final projected = Map<String, int>.from(baseline);

    for (final (start, end) in clusters) {
      for (int w = start; w <= end; w++) {
        if (locked.containsKey(w)) continue;
        final span = weeks[w];
        final avail = availByWeek[w];

        final pick = _choosePairForBottleneck(
          w: w,
          span: span,
          tris: tris,
          available: avail,
          assignedWeeksByPilot: assignedSeed,
          projectedWeJfDays: projected,
          previousCouples: prevCouples,
          prefBoostRetard: boost,
        );
        if (pick == null) continue;

        final canon = canonPair(pick.a, pick.b);
        locked[w] = canon;

        assignedSeed[pick.a]!.add(w);
        assignedSeed[pick.b]!.add(w);
        prevCouples.add(canon);

        projected[pick.a] = (projected[pick.a] ?? 0) + 2;
        projected[pick.b] = (projected[pick.b] ?? 0) + 2;

        logAst("AST[pre][LOCK] W${w + 1} ${_fmtDateFr(span.monday)} => ${canon.$1}/${canon.$2}");
      }
    }

    final sHist = await _seedHistoryBeforePeriod(
      tris: tris,
      firstMonday: weeks.first.monday,
      jfForWeeks: {},
    );

    final pre = <String, List<int>>{
      for (final t in tris)
        t: [
          ...(sHist.preWeeksByPilot[t] ?? const <int>[]),
          ...(assignedSeed[t] ?? const <int>[]),
        ]
    };

    final couplesBefore = <(String, String)>{}
      ..addAll(sHist.prevCouplesBefore)
      ..addAll(prevCouples);

    return (lockedByWeek: locked, preWeeksByPilot: pre, prevCouplesBefore: couplesBefore);
  }

  // =========================
  // Historique S-1 / S-2 (avant période)
  // =========================

  Future<_SeedHistory> _seedHistoryBeforePeriod({
    required List<String> tris,
    required DateTime firstMonday,
    required Set<DateTime> jfForWeeks,
  }) async {
    final m1 = _dayOnly(firstMonday.subtract(const Duration(days: 7)));
    final m2 = _dayOnly(firstMonday.subtract(const Duration(days: 14)));

    final pre = <String, List<int>>{for (final t in tris) t: <int>[]};
    final prevCouples = <(String, String)>{};

    Future<bool> hadAstWeBothDays(String t, DateTime weekMonday) async {
      final monday = _dayOnly(weekMonday);
      final sat = _dayOnly(monday.add(const Duration(days: 5)));
      final sun = _dayOnly(monday.add(const Duration(days: 6)));

      final evs = await planningDao.getForRange(
        monday,
        monday.add(const Duration(days: 7)),
        forUser: t,
      );

      final ast = evs.where((x) => x.typeEvent == 'AST').toList();

      bool hasSat = false, hasSun = false;
      for (final e in ast) {
        final s = _dayOnly(e.dateStart);
        final eend = _dayOnly(e.dateEnd);
        if (!(eend.isBefore(sat) || s.isAfter(sat))) hasSat = true;
        if (!(eend.isBefore(sun) || s.isAfter(sun))) hasSun = true;
        if (hasSat && hasSun) return true;
      }
      return false;
    }

    final onMinus1 = <String>[];
    for (final t in tris) {
      if (await hadAstWeBothDays(t, m1)) {
        pre[t]!.add(-1);
        onMinus1.add(t);
      }
    }
    if (onMinus1.length == 2) {
      prevCouples.add(canonPair(onMinus1[0], onMinus1[1]));
    }

    final onMinus2 = <String>[];
    for (final t in tris) {
      if (await hadAstWeBothDays(t, m2)) {
        pre[t]!.add(-2);
        onMinus2.add(t);
      }
    }
    if (onMinus2.length == 2) {
      prevCouples.add(canonPair(onMinus2[0], onMinus2[1]));
    }

    logAst('AST[seed] S-1: ${onMinus1.join('/')}  |  S-2: ${onMinus2.join('/')}');
    return _SeedHistory(preWeeksByPilot: pre, prevCouplesBefore: prevCouples);
  }

  /// A) Debug : dump lisible pour un pilote (AST WE+JF + indispos)
  Future<void> debugDumpPilotReads({
    required String trigramme,
    required DateTime from,
    required DateTime to,
  }) async {
    final tri = trigramme.toUpperCase().trim();
    final s = _dayOnly(from);
    final e = _dayOnly(to);

    final jf = (joursFeriesProvider != null) ? await joursFeriesProvider!(s, e) : <DateTime>[];

    final evs = await planningDao.getForRange(s, e.add(const Duration(days: 1)), forUser: tri);
    final ast = evs.where((x) => x.typeEvent == 'AST').toList();

    final counted = _collectAstWeJfDaysFromEvents(
      ast,
      from: s,
      toInclusive: e,
      extraJoursFeries: jf,
    ).toList()
      ..sort();

    logAst("=== DEBUG AST ENGINE / $tri ===");
    logAst("JOURS CRITIQUES = samedis + dimanches + JF");
    logAst("[A] Évents lus (tous) : ${evs.length} / AST : ${ast.length}");
    logAst("[A] AST (WE+JF) réalisés du ${_fmtDateFr(s)} au ${_fmtDateFr(e)} : ${counted.length} jour(s)");
    final fmt = DateFormat('dd/MM/yy');
    for (final d in counted.take(12)) {
      final jfTag = _isJourFerie(d, jf) ? ' + JF' : '';
      logAst("  - ${_weekdayShortFr(d)} ${fmt.format(d)}$jfTag");
    }

    final indispos = <DateTime>{};
    for (final ev in evs) {
      for (final d in _daysInclusive(_dayOnly(ev.dateStart), _dayOnly(ev.dateEnd))) {
        if (d.isBefore(s) || d.isAfter(e)) continue;
        indispos.add(d);
      }
    }
    final listInd = indispos.toList()..sort();
    logAst("[B] Indispos ${_fmtDateFr(s)} → ${_fmtDateFr(e)} : ${listInd.length} jour(s) (échantillon ${listInd.take(10).map((d)=>fmt.format(d)).join(', ')})");
    logAst("=== FIN DEBUG $tri ===");
  }

  /// B) Compte des jours AST WE+JF sur l'année (inclut les AST déjà planifiées futures)
  Future<Map<String, int>> computeFullYearWeJfCounts({
    required List<String> pilotes,
    required int year,
  }) async {
    final from = DateTime(year, 1, 1);
    final to = DateTime(year, 12, 31);

    final jf = (joursFeriesProvider != null) ? await joursFeriesProvider!(from, to) : <DateTime>[];
    final out = <String, int>{for (final t in pilotes) t: 0};

    for (final t in pilotes) {
      final evs = await planningDao.getForRange(from, to.add(const Duration(days: 1)), forUser: t);
      final ast = evs.where((x) => x.typeEvent == 'AST').toList();
      final days = _collectAstWeJfDaysFromEvents(
        ast,
        from: from,
        toInclusive: to,
        extraJoursFeries: jf,
      );
      out[t] = days.length;
    }
    return out;
  }

  // Helper debug: nettoie les trigrammes comme le moteur et trace les rejets
  List<String> _sanitizeTrisWithDebug(List<String> pilotesTrigrammes) {
    final raw = pilotesTrigrammes;
    logAst('AST[gen] pilotes(raw) len=${raw.length} -> $raw');
    final trimmedUpper = raw.map((e) => (e ?? '').toString().trim().toUpperCase()).toList();
    final kept = <String>[];
    final seen = <String>{};
    for (final t in trimmedUpper) {
      if (t.length != 3) {
        logAst('AST[gen][drop] "$t" (len=${t.length})');
        continue;
      }
      if (seen.contains(t)) {
        logAst('AST[gen][drop] "$t" (duplicate)');
        continue;
      }
      seen.add(t);
      kept.add(t);
    }
    kept.sort();
    logAst('AST[gen] pilotes(clean) len=${kept.length} -> $kept');
    return kept;
  }

  /// C) Génération de propositions
  Future<List<AstreinteProposal>> generateProposals({
    required List<String> pilotesTrigrammes,
    required AstreinteInputs inputs,
    int? maxSolutions,
  }) async {
    // Trace les pilotes reçus et la normalisation identique à l’existant
    final tris = _sanitizeTrisWithDebug(pilotesTrigrammes);

    if (tris.length < 2) {
      logAst('AST[gen][ERROR] moins de 2 pilotes après nettoyage → $tris');
      throw StateError("Il faut au moins 2 pilotes.");
    }

    final weeks = _weeksFrom(inputs.start, inputs.end);
    logAst('AST[gen] weeks=${weeks.length} (from ${_fmtDateFr(weeks.first.monday)} to ${_fmtDateFr(weeks.last.sunday)})');
    if (weeks.isEmpty) {
      logAst('AST[gen][ERROR] aucune semaine dans la période');
      throw StateError("Aucune semaine dans la période demandée.");
    }

    final baseline = await _baselineWeJf(
      pilotes: tris,
      startOfFirstWeek: weeks.first.monday,
    );
    logAst('AST[gen] baseline(WE+JF since 01/01/2025) -> ${baseline.entries.map((e) => '${e.key}:${e.value}').join(', ')}');

    final indisposByPilot = await _loadIndisposOnPeriodDao(
      pilotes: tris,
      start: weeks.first.monday,
      end: weeks.last.sunday,
    );
    for (final t in tris) {
      final c = indisposByPilot[t]?.length ?? 0;
      if (c > 0) {
        final sample = indisposByPilot[t]!.toList()..sort();
        logAst('AST[indispos] $t : $c jours (ex: ${sample.take(6).map(_fmtDateFr).join(', ')})');
      } else {
        logAst('AST[indispos] $t : 0 jour');
      }
    }

    // 1) Pré-assignation étranglements
    final pre = await _preassignFromBottlenecks(
      tris: tris,
      weeks: weeks,
      indisposByPilot: indisposByPilot,
      baseline: baseline,
    );

    // 2) Trois profils
    final profiles = <_GreedyProfile>[
      _GreedyProfile(
        name: 'cool',
        hugePenaltyConsec: 5000,
        penalty101: 300,
        hugePenaltyTriple: 9000,
        wSpacing: 160,
        balanceWeight: 12,
        boostLow: 10,
        pairRepeatPenalty: 15,
        allowRelaxed: false,
      ),
      _GreedyProfile(
        name: 'balance',
        hugePenaltyConsec: 5000,
        penalty101: 220,
        hugePenaltyTriple: 9000,
        wSpacing: 180,
        balanceWeight: 10,
        boostLow: 12,
        pairRepeatPenalty: 20,
        allowRelaxed: false,
      ),
      _GreedyProfile(
        name: 'aggressive',
        hugePenaltyConsec: 5000,
        penalty101: 150,
        hugePenaltyTriple: 9000,
        wSpacing: 200,
        balanceWeight: 8,
        boostLow: 16,
        pairRepeatPenalty: 25,
        allowRelaxed: false,
      ),
    ];

    final proposals = <AstreinteProposal>[];
    final seeds = [0, 1, 2, 3, 4, 5, 6, 7];
    for (final prof in profiles) {
      for (final seed in seeds) {
        final p = _buildGreedyPlan(
          tris: tris,
          weeks: weeks,
          baselineWeJfDays: Map<String, int>.from(baseline),
          indisposByPilot: indisposByPilot,
          chefExclusionsByWeek: inputs.chefExclusionsByWeek,
          seed: seed,
          profile: prof,
          preWeeksByPilot: pre.preWeeksByPilot,
          prevCouplesBefore: pre.prevCouplesBefore,
          lockedByWeek: pre.lockedByWeek,
        );
        if (p != null) {
          proposals.add(p);
          logAst('AST[gen] profil=${prof.name} seed=$seed OK score=${p.score.toStringAsFixed(1)}');
          break;
        } else {
          logAst('AST[gen] profil=${prof.name} seed=$seed → échec (aucun couple faisable sur une semaine)');
        }
      }
    }
    proposals.sort((a, b) => a.score.compareTo(b.score));
    logAst('AST[gen] solutions trouvées=${proposals.length}');
    return proposals;
  }

  /// D) Écriture de la proposition : on segmente pour ne JAMAIS écraser une cellule occupée
  Future<void> commitProposal({required AstreinteProposal chosen}) async {
    for (final entry in chosen.assignment.entries) {
      final span = entry.key;
      final (p1, p2) = entry.value;
      await _createAstSegmentsForPilotInWeekDao(p1, span);
      await _createAstSegmentsForPilotInWeekDao(p2, span);
    }
  }

  /// E) RAZ AST sur [start..end] (trim/split/suppr)
  Future<void> razAstInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final s = _dayOnly(start);
    final e = _dayOnly(end);

    final evs = await planningDao.getForRange(s, e.add(const Duration(days: 1)));
    final asts = evs.where((x) => x.typeEvent == 'AST').toList();

    for (final ev in asts) {
      final evS = _dayOnly(ev.dateStart);
      final evE = _dayOnly(ev.dateEnd);

      final fullyInside = !evS.isBefore(s) && !evE.isAfter(e);
      if (fullyInside) {
        if (ev.firestoreId != null && ev.firestoreId!.isNotEmpty) {
          await planningDao.deleteEventByFirestoreId(ev.firestoreId!);
        }
        continue;
      }

      if (evS.isBefore(s) && evE.isBetween(s, e)) {
        final newEnd = s.subtract(const Duration(days: 1));
        if (ev.firestoreId != null && ev.firestoreId!.isNotEmpty) {
          await planningDao.updateEventByFirestoreId(
            firestoreId: ev.firestoreId!,
            dateStart: evS,
            dateEnd: newEnd,
          );
        }
        continue;
      }

      if (evS.isBetween(s, e) && evE.isAfter(e)) {
        final newStart = e.add(const Duration(days: 1));
        if (ev.firestoreId != null && ev.firestoreId!.isNotEmpty) {
          await planningDao.updateEventByFirestoreId(
            firestoreId: ev.firestoreId!,
            dateStart: newStart,
            dateEnd: evE,
          );
        }
        continue;
      }

      if (evS.isBefore(s) && evE.isAfter(e)) {
        if (ev.firestoreId != null && ev.firestoreId!.isNotEmpty) {
          await planningDao.updateEventByFirestoreId(
            firestoreId: ev.firestoreId!,
            dateStart: evS,
            dateEnd: s.subtract(const Duration(days: 1)),
          );
        }
        await planningDao.insertEvent(
          user: ev.user,
          typeEvent: ev.typeEvent,
          dateStart: e.add(const Duration(days: 1)),
          dateEnd: evE,
        );
      }
    }
  }

  // =========================
  // Interne : génération gloutonne “choke-first”
  // =========================

  AstreinteProposal? _buildGreedyPlan({
    required List<String> tris,
    required List<WeekSpan> weeks,
    required Map<String, int> baselineWeJfDays,
    required Map<String, Set<DateTime>> indisposByPilot,
    required Map<int, Set<String>> chefExclusionsByWeek,
    required int seed,
    required _GreedyProfile profile,
    required Map<String, List<int>> preWeeksByPilot,
    required Set<(String, String)> prevCouplesBefore,
    Map<int, (String, String)>? lockedByWeek,
  }) {
    final rnd = Random(seed);

    final assignment = <WeekSpan, (String, String)>{};
    final assignedWeeksByPilot = <String, List<int>>{
      for (final t in tris) t: List<int>.from(preWeeksByPilot[t] ?? const <int>[])
    };
    final projected = Map<String, int>.from(baselineWeJfDays);
    final previousCouples = <(String, String)>{}..addAll(prevCouplesBefore);

    for (int w = 0; w < weeks.length; w++) {
      final span = weeks[w];

      if (lockedByWeek != null && lockedByWeek.containsKey(w)) {
        final lock = lockedByWeek[w]!;
        assignment[span] = lock;
        assignedWeeksByPilot[lock.$1]!.add(w);
        assignedWeeksByPilot[lock.$2]!.add(w);
        previousCouples.add(lock);
        projected[lock.$1] = (projected[lock.$1] ?? 0) + 2;
        projected[lock.$2] = (projected[lock.$2] ?? 0) + 2;
        logAst('AST[plan] W${w + 1} ${_fmtDateFr(span.monday)} LOCK=${lock.$1}/${lock.$2}');
        continue;
      }

      // Compteurs debug par raisons de rejet
      int rejChefExcl = 0, rejWe = 0, rejWeekday = 0, rej111 = 0;
      int candKept = 0;

      final candidates = <({(String, String) pair, double score, bool would11})>[];
      final shuffled = [...tris]..shuffle(rnd);

      for (int i = 0; i < shuffled.length; i++) {
        for (int j = i + 1; j < shuffled.length; j++) {
          final a = shuffled[i];
          final b = shuffled[j];

          if (chefExclusionsByWeek[w]?.contains(a) == true || chefExclusionsByWeek[w]?.contains(b) == true) {
            rejChefExcl++;
            continue;
          }
          if (!_weekendBothFree(a, b, span, indisposByPilot)) {
            rejWe++;
            continue;
          }
          if (!_weekdayFeasible(a, b, span, indisposByPilot)) {
            rejWeekday++;
            continue;
          }
          if (_forbidden111(a, w, assignedWeeksByPilot) || _forbidden111(b, w, assignedWeeksByPilot)) {
            rej111++;
            continue;
          }

          final would11 = _forbidden11(a, w, assignedWeeksByPilot) || _forbidden11(b, w, assignedWeeksByPilot);

          final pa = projected[a] ?? 0;
          final pb = projected[b] ?? 0;
          double score = 0;

          score += (max(pa, pb) * profile.balanceWeight) + (pa + pb) * 1.0;

          final baseVals = projected.values.toList();
          final minDone = baseVals.isEmpty ? 0 : baseVals.reduce(min);
          final maxDone = baseVals.isEmpty ? 0 : baseVals.reduce(max);
          final spanDone = max(1, maxDone - minDone);

          double lag(String t) => ((maxDone - (projected[t] ?? 0)) / spanDone) * profile.boostLow;
          score -= lag(a);
          score -= lag(b);

          int spacingPen(String p) {
            final lst = assignedWeeksByPilot[p]!..sort();
            if (lst.isEmpty) return 0;
            final last = lst.last;
            final gap = w - last;
            if (gap <= 0) return 9999;
            if (gap <= 3) return (4 - gap) * (profile.wSpacing.toInt());
            return 0;
          }
          score += spacingPen(a) + spacingPen(b);

          final canon = canonPair(a, b);
          if (previousCouples.contains(canon)) score += profile.pairRepeatPenalty;

          final hadW2 = (assignedWeeksByPilot[a]?.contains(w - 2) == true) ||
              (assignedWeeksByPilot[b]?.contains(w - 2) == true);
          if (hadW2) score += profile.penalty101;

          if (would11 && !profile.allowRelaxed) score += 2000;

          candidates.add((pair: canon, score: score, would11: would11));
          candKept++;
        }
      }

      if (candidates.isEmpty) {
        logAst("AST[plan] W${w + 1} ${_fmtDateFr(span.monday)} : 0 candidats (rejChef=$rejChefExcl, rejWE=$rejWe, rejWD=$rejWeekday, rej111=$rej111)");
        return null;
      }

      final strict = candidates.where((c) => !c.would11).toList()
        ..sort((x, y) => x.score.compareTo(y.score));

      ({(String, String) pair, double score, bool would11}) chosen;
      if (strict.isNotEmpty) {
        chosen = strict.first;
      } else {
        candidates.sort((x, y) => x.score.compareTo(y.score));
        chosen = candidates.first;
      }

      final best = chosen.pair;
      assignment[span] = best;
      assignedWeeksByPilot[best.$1]!.add(w);
      assignedWeeksByPilot[best.$2]!.add(w);
      previousCouples.add(best);
      projected[best.$1] = (projected[best.$1] ?? 0) + 2;
      projected[best.$2] = (projected[best.$2] ?? 0) + 2;

      logAst("AST[plan] W${w + 1} ${_fmtDateFr(span.monday)} kept=$candKept (rejChef=$rejChefExcl, rejWE=$rejWe, rejWD=$rejWeekday, rej111=$rej111) -> CHOISI ${best.$1}/${best.$2} (score=${chosen.score.toStringAsFixed(1)}${chosen.would11 ? ' ; 1-1' : ''})");
    }

    final totalScore = _planScore(
      couples: assignment.values.toList(),
      projectedWeJfDays: projected,
      profile: profile,
    );

    final delta = <String, int>{for (final t in tris) t: 0};
    for (final c in assignment.values) {
      delta[c.$1] = (delta[c.$1] ?? 0) + 2;
      delta[c.$2] = (delta[c.$2] ?? 0) + 2;
    }

    logAst('AST[plan] FIN profil=${profile.name} score=${totalScore.toStringAsFixed(1)} '
        'projected=${projected.entries.map((e) => '${e.key}:${e.value}').join(', ')}');

    return AstreinteProposal(
      assignment: assignment,
      score: totalScore,
      deltaCriticalDaysByPilot: delta,
      projectedWeJfDaysByPilot: projected,
    );
  }

  // =========================
  // Scoring & contraintes
  // =========================

  List<WeekSpan> _weeksFrom(DateTime startIncl, DateTime endIncl) {
    final start = _dayOnly(startIncl);
    final end = _dayOnly(endIncl);

    DateTime monday = start.subtract(Duration(days: (start.weekday - DateTime.monday + 7) % 7));
    final lastMonday = end.subtract(Duration(days: (end.weekday - DateTime.monday + 7) % 7));

    final out = <WeekSpan>[];
    while (!monday.isAfter(lastMonday)) {
      final sunday = monday.add(const Duration(days: 6));
      out.add(WeekSpan(monday, sunday));
      monday = monday.add(const Duration(days: 7));
    }
    return out;
  }

  // Baseline 2025 jusqu’à veille de la période
  Future<Map<String, int>> _baselineWeJf({
    required List<String> pilotes,
    required DateTime startOfFirstWeek,
  }) async {
    final from = DateTime(2025, 1, 1);
    final to = _dayOnly(startOfFirstWeek.subtract(const Duration(days: 1)));
    if (to.isBefore(from)) {
      return {for (final t in pilotes) t: 0};
    }

    final jf = (joursFeriesProvider != null) ? await joursFeriesProvider!(from, to) : <DateTime>[];
    final out = <String, int>{};

    for (final t in pilotes) {
      final evs = await planningDao.getForRange(from, to.add(const Duration(days: 1)), forUser: t);
      final ast = evs.where((x) => x.typeEvent == 'AST').toList();
      final days = _collectAstWeJfDaysFromEvents(
        ast,
        from: from,
        toInclusive: to,
        extraJoursFeries: jf,
      );
      out[t] = days.length;
    }
    return out;
  }

  // Renvoie tous les couples valides (dispo week-end + faisabilité semaine)
  List<(String, String)> _validPairsForWeek({
    required List<String> tris,
    required WeekSpan span,
    required Map<String, Set<DateTime>> indispos,
    required Set<String> chefExclusions,
  }) {
    final L = <(String, String)>[];
    for (int i = 0; i < tris.length; i++) {
      for (int j = i + 1; j < tris.length; j++) {
        final a = tris[i];
        final b = tris[j];
        if (chefExclusions.contains(a) || chefExclusions.contains(b)) continue;
        if (!_weekendBothFree(a, b, span, indispos)) continue;
        if (!_weekdayFeasible(a, b, span, indispos)) continue;
        L.add(canonPair(a, b));
      }
    }
    return L;
  }

  bool _weekendBothFree(
      String a,
      String b,
      WeekSpan span,
      Map<String, Set<DateTime>> indispos,
      ) {
    final sat = _dayOnly(span.monday.add(const Duration(days: 5)));
    final sun = _dayOnly(span.monday.add(const Duration(days: 6)));
    final ia = indispos[a] ?? {};
    final ib = indispos[b] ?? {};
    return !(ia.contains(sat) || ia.contains(sun) || ib.contains(sat) || ib.contains(sun));
  }

  bool _weekdayFeasible(
      String a,
      String b,
      WeekSpan span,
      Map<String, Set<DateTime>> indispos,
      ) {
    final days = List<DateTime>.generate(5, (i) => _dayOnly(span.monday.add(Duration(days: i))));
    final ia = indispos[a] ?? {};
    final ib = indispos[b] ?? {};

    final offA = days.where(ia.contains).length;
    final offB = days.where(ib.contains).length;

    final aFull = offA == 0;
    final bFull = offB == 0;

    if (aFull && bFull) return true;
    if (aFull && offB <= 4) return true;
    if (bFull && offA <= 4) return true;
    return false;
  }

  bool _willBeConsecutive(
      String pilot,
      int weekIndex,
      Map<String, List<int>> assignedWeeksByPilot,
      ) {
    final lst = assignedWeeksByPilot[pilot] ?? const <int>[];
    return lst.contains(weekIndex - 1);
  }

  double _spacingPenaltyForPilot(
      String pilot,
      int weekIndex,
      Map<String, List<int>> assignedWeeksByPilot,
      _GreedyProfile profile,
      ) {
    double pen = 0;
    final lst = List<int>.from(assignedWeeksByPilot[pilot] ?? const <int>[])..sort();

    if (lst.contains(weekIndex - 1)) pen += profile.hugePenaltyConsec;
    if (lst.contains(weekIndex - 2)) pen += profile.penalty101;
    if (lst.contains(weekIndex - 2) && lst.contains(weekIndex - 4)) {
      pen += profile.hugePenaltyTriple;
    }

    final last = lst.isNotEmpty ? lst.last : null;
    if (last != null) {
      final gap = weekIndex - last;
      if (gap <= 3) {
        pen += (4 - gap) * profile.wSpacing;
      }
    }
    return pen;
  }

  double _scorePair({
    required String a,
    required String b,
    required int weekIndex,
    required Map<String, List<int>> assignedWeeksByPilot,
    required Map<String, int> projectedWeJfDays,
    required Set<(String, String)> previousCouples,
    required _GreedyProfile profile,
  }) {
    double score = 0;

    score += _spacingPenaltyForPilot(a, weekIndex, assignedWeeksByPilot, profile);
    score += _spacingPenaltyForPilot(b, weekIndex, assignedWeeksByPilot, profile);

    final canon = canonPair(a, b);
    if (previousCouples.contains(canon)) score += profile.pairRepeatPenalty;

    final pa = projectedWeJfDays[a] ?? 0;
    final pb = projectedWeJfDays[b] ?? 0;

    final minAB = min(pa, pb).toDouble();
    score -= minAB * profile.boostLow;

    score += (max(pa, pb) * profile.balanceWeight) + (pa + pb) * 0.5;

    return score;
  }

  double _planScore({
    required List<(String, String)> couples,
    required Map<String, int> projectedWeJfDays,
    required _GreedyProfile profile,
  }) {
    double score = 0;

    if (projectedWeJfDays.isNotEmpty) {
      final vals = projectedWeJfDays.values.toList()..sort();
      score += (vals.last - vals.first) * profile.balanceWeight;
    }

    final seen = <String, int>{};
    for (final c in couples) {
      final key = "${c.$1}|${c.$2}";
      seen[key] = (seen[key] ?? 0) + 1;
    }
    for (final e in seen.entries) {
      if (e.value > 1) score += (e.value - 1) * profile.pairRepeatPenalty;
    }

    return score;
  }

  // =========================
  // DAO — LECTURES / ÉCRITURES
  // =========================

  /// Indispos (tous codes) jour par jour sur la période.
  Future<Map<String, Set<DateTime>>> _loadIndisposOnPeriodDao({
    required List<String> pilotes,
    required DateTime start,
    required DateTime end,
  }) async {
    final map = <String, Set<DateTime>>{for (final t in pilotes) t: <DateTime>{}};

    for (final t in pilotes) {
      final evs = await planningDao.getForRange(_dayOnly(start), _dayOnly(end).add(const Duration(days: 1)), forUser: t);
      for (final e in evs) {
        if (e.typeEvent.trim().isEmpty) continue;
        for (final d in _daysInclusive(_dayOnly(e.dateStart), _dayOnly(e.dateEnd))) {
          if (d.isBefore(_dayOnly(start)) || d.isAfter(_dayOnly(end))) continue;
          map[t]!.add(d);
        }
      }
    }
    return map;
  }

  /// Crée des segments AST pour les jours **libres** d’une semaine (évite toute collision).
  Future<void> _createAstSegmentsForPilotInWeekDao(String trigramme, WeekSpan span) async {
    final tri = trigramme.toUpperCase().trim();

    final evs = await planningDao.getForRange(span.monday, span.sunday.add(const Duration(days: 1)), forUser: tri);
    final busy = <DateTime>{};
    for (final e in evs) {
      if (e.typeEvent.trim().isEmpty) continue;
      for (final d in _daysInclusive(_dayOnly(e.dateStart), _dayOnly(e.dateEnd))) {
        busy.add(d);
      }
    }

    final days = List<DateTime>.generate(7, (i) => _dayOnly(span.monday.add(Duration(days: i))));
    DateTime? segStart;

    for (final d in days) {
      final isFree = !busy.contains(d);
      if (isFree) {
        segStart ??= d;
      } else {
        if (segStart != null) {
          final segEnd = d.subtract(const Duration(days: 1));
          await planningDao.insertEvent(
            user: tri,
            typeEvent: 'AST',
            dateStart: segStart,
            dateEnd: segEnd,
          );
          segStart = null;
        }
      }
    }
    if (segStart != null) {
      await planningDao.insertEvent(
        user: tri,
        typeEvent: 'AST',
        dateStart: segStart,
        dateEnd: _dayOnly(span.sunday),
      );
    }
  }
}

// =========================
// Compteurs AST (WE+JF)
// =========================

Set<DateTime> _collectAstWeJfDaysFromEvents(
    List<PlanningEvent> astEvents, {
      required DateTime from,
      required DateTime toInclusive,
      required List<DateTime> extraJoursFeries,
    }) {
  final s = _dayOnly(from);
  final e = _dayOnly(toInclusive);
  final jf = extraJoursFeries.map(_dayOnly).toSet();

  final counted = <DateTime>{};
  for (final ev in astEvents) {
    final a = _dayOnly(ev.dateStart);
    final b = _dayOnly(ev.dateEnd);
    for (final d in _daysInclusive(a, b)) {
      if (d.isBefore(s) || d.isAfter(e)) continue;
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday || jf.contains(d)) {
        counted.add(d);
      }
    }
  }
  return counted;
}

bool _isJourFerie(DateTime d, List<DateTime> jf) {
  final set = jf.map((x) => DateTime(x.year, x.month, x.day)).toSet();
  final dd = DateTime(d.year, d.month, d.day);
  return set.contains(dd);
}
