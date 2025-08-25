// lib/services/astreinte_engine.dart
//
// Moteur d'astreintes (avion) — version DAO-first.
// - Lit/écrit via PlanningDao (Drift). On ne touche Firestore qu'indirectement,
//   puisque le DAO pousse déjà (createAndPush / updateAndPush / deleteAndPush).
// - Compte correctement les jours critiques (samedi + dimanche + JF) en INCLUSIF.
// - Génère 3 propositions réellement différentes (profils + seeds).
// - Respecte : pas de 1-1 (sauf contrainte dure), 1-0-1 toléré si profil “agressif”,
//   et 1-0-1 doit être suivi de 0-0-* autant que possible.
// - Variabilité des couples (pénalité) + priorité aux semaines “étranglées”.
//
// NB : Ce fichier expose les mêmes méthodes publiques que l’ancienne version pour
//      rester aligné avec l’UI.

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/planning_dao.dart';
import '../data/app_database.dart';

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
          other is WeekSpan &&
              monday == other.monday &&
              sunday == other.sunday;

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
  final Future<
      List<DateTime>> Function(DateTime from, DateTime to)? joursFeriesProvider;

  AstreinteEngine({
    required this.planningDao,
    this.joursFeriesProvider,
  });

  // =========================
  // Public API pour l’UI
  // =========================

  // =========================
// Historique S-1 / S-2 (avant période)
// =========================

  Future<_SeedHistory> _seedHistoryBeforePeriod({
    required List<String> tris,
    required DateTime firstMonday,
    required Set<DateTime> jfForWeeks, // présent pour homogénéité, pas essentiel ici
  }) async {
    // Deux semaines avant la période
    final m1 = _dayOnly(firstMonday.subtract(const Duration(days: 7)));
    final m2 = _dayOnly(firstMonday.subtract(const Duration(days: 14)));

    final pre = <String, List<int>>{for (final t in tris) t: <int>[]};
    final prevCouples = <(String, String)>{};

    // Helper local : a-t-il eu AST sur les deux jours du WE donné ?
    // (Méthode d’instance → a accès à planningDao)
    Future<bool> hadAstWeBothDays(String t, DateTime weekMonday) async {
      final monday = _dayOnly(weekMonday);
      final sat = _dayOnly(monday.add(const Duration(days: 5)));
      final sun = _dayOnly(monday.add(const Duration(days: 6)));

      // Drift: end exclusif → Monday + 7
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

    // S-1
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

    // S-2
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

    // JF dynamiques éventuels
    final jf = (joursFeriesProvider != null)
        ? await joursFeriesProvider!(s, e)
        : <DateTime>[];

    // Lecture DAO
    final evs = await planningDao.getForRange(
        s, e.add(const Duration(days: 1)), forUser: tri);
    final ast = evs.where((x) => x.typeEvent == 'AST').toList();

    final counted = _collectAstWeJfDaysFromEvents(
      ast,
      from: s,
      toInclusive: e,
      extraJoursFeries: jf,
    ).toList()
      ..sort();

    debugPrint("=== DEBUG AST ENGINE / $tri ===");
    debugPrint("JOURS CRITIQUES = samedis + dimanches + JF");
    debugPrint("[A] Évents lus (tous) : ${evs.length} / AST : ${ast.length}");
    debugPrint("[A] AST (WE+JF) réalisés du ${_fmtDateFr(s)} au ${_fmtDateFr(
        e)} : ${counted.length} jour(s)");
    final fmt = DateFormat('dd/MM/yy');
    for (final d in counted) {
      final jfTag = _isJourFerie(d, jf) ? ' + JF' : '';
      debugPrint("  - ${_weekdayShortFr(d)} ${fmt.format(d)}$jfTag");
    }

    // Indispos (tous codes) sur la même plage
    final indispos = <DateTime>{};
    for (final ev in evs) {
      for (final d in _daysInclusive(
          _dayOnly(ev.dateStart), _dayOnly(ev.dateEnd))) {
        if (d.isBefore(s) || d.isAfter(e)) continue;
        indispos.add(d);
      }
    }
    final listInd = indispos.toList()
      ..sort();
    debugPrint("[B] Indispos sur ${_fmtDateFr(s)} → ${_fmtDateFr(e)} : ${listInd
        .length} jour(s)");
    for (final d in listInd) {
      debugPrint("  - ${_weekdayShortFr(d)} ${fmt.format(d)}");
    }
    debugPrint("=== FIN DEBUG $tri ===");
  }

  /// B) Compte des jours AST WE+JF sur l'année (inclut les AST déjà planifiées futures)
  Future<Map<String, int>> computeFullYearWeJfCounts({
    required List<String> pilotes,
    required int year,
  }) async {
    final from = DateTime(year, 1, 1);
    final to = DateTime(year, 12, 31);

    final jf = (joursFeriesProvider != null) ? await joursFeriesProvider!(
        from, to) : <DateTime>[];
    final out = <String, int>{for (final t in pilotes) t: 0};

    for (final t in pilotes) {
      final evs = await planningDao.getForRange(
          from, to.add(const Duration(days: 1)), forUser: t);
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

  /// C) Génération de propositions
  Future<List<AstreinteProposal>> generateProposals({
    required List<String> pilotesTrigrammes,
    required AstreinteInputs inputs,
    int? maxSolutions,
  }) async {
    final tris = pilotesTrigrammes
        .map((e) => e.toUpperCase().trim())
        .where((e) => e.length == 3)
        .toSet()
        .toList()
      ..sort();

    if (tris.length < 2) {
      throw StateError("Il faut au moins 2 pilotes.");
    }

    final weeks = _weeksFrom(inputs.start, inputs.end);
    if (weeks.isEmpty) {
      throw StateError("Aucune semaine dans la période demandée.");
    }

    // Baseline depuis 01/01/2025 jusqu’à la veille de la période
    final baseline = await _baselineWeJf(
      pilotes: tris,
      startOfFirstWeek: weeks.first.monday,
    );

    // Indispos réelles (DAO)
    final indisposByPilot = await _loadIndisposOnPeriodDao(
      pilotes: tris,
      start: weeks.first.monday,
      end: weeks.last.sunday,
    );

    // JF dynamiques pour info/compte (pas obligatoire au scoring)
    final jfList = (joursFeriesProvider != null)
        ? await joursFeriesProvider!(weeks.first.monday, weeks.last.sunday)
        : <DateTime>[];

    // Historique S-1 / S-2 pour éviter 1-1 ou 1-0-1 en bordure
    final seedHist = await _seedHistoryBeforePeriod(
      tris: tris,
      firstMonday: weeks.first.monday,
      jfForWeeks: jfList.toSet(),
    );

    final limit = (maxSolutions == null || maxSolutions <= 0)
        ? 3
        : maxSolutions;

    final profiles = <_GreedyProfile>[
      _GreedyProfile.cool(),
      _GreedyProfile.balanced(),
      _GreedyProfile.aggressive(),
    ];

    final proposals = <AstreinteProposal>[];
    int seed = 0;

    for (final profile in profiles) {
      if (proposals.length >= limit) break;

      final p = _buildGreedyPlan(
        tris: tris,
        weeks: weeks,
        baselineWeJfDays: Map<String, int>.from(baseline),
        indisposByPilot: indisposByPilot,
        chefExclusionsByWeek: inputs.chefExclusionsByWeek,
        profile: profile,
        seed: seed++,
        prevCouplesBefore: seedHist.prevCouplesBefore,
        preWeeksByPilot: seedHist.preWeeksByPilot,
      );

      if (p != null) proposals.add(p);
    }

    // Si une proposition a échoué (choke trop dur), on tente des seeds supplémentaires
    while (proposals.length < limit) {
      final p = _buildGreedyPlan(
        tris: tris,
        weeks: weeks,
        baselineWeJfDays: Map<String, int>.from(baseline),
        indisposByPilot: indisposByPilot,
        chefExclusionsByWeek: inputs.chefExclusionsByWeek,
        profile: _GreedyProfile.balanced(),
        seed: seed++,
        prevCouplesBefore: seedHist.prevCouplesBefore,
        preWeeksByPilot: seedHist.preWeeksByPilot,
      );
      if (p != null) proposals.add(p);
      if (seed > 20) break; // garde-fou
    }

    // trie par score
    proposals.sort((a, b) => a.score.compareTo(b.score));
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

    final evs = await planningDao.getForRange(
        s, e.add(const Duration(days: 1)));
    final asts = evs.where((x) => x.typeEvent == 'AST').toList();

    for (final ev in asts) {
      final evS = _dayOnly(ev.dateStart);
      final evE = _dayOnly(ev.dateEnd);

      // A) entièrement dedans → delete
      final fullyInside = !evS.isBefore(s) && !evE.isAfter(e);
      if (fullyInside) {
        if (ev.firestoreId != null && ev.firestoreId!.isNotEmpty) {
          await planningDao.deleteEventByFirestoreId(ev.firestoreId!);
        }
        continue;
      }

      // B) chevauche à gauche → raccourcit à gauche
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

      // C) chevauche à droite → décale début après la plage
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

      // D) couvre toute la plage → split
      if (evS.isBefore(s) && evE.isAfter(e)) {
        if (ev.firestoreId != null && ev.firestoreId!.isNotEmpty) {
          await planningDao.updateEventByFirestoreId(
            firestoreId: ev.firestoreId!,
            dateStart: evS,
            dateEnd: s.subtract(const Duration(days: 1)),
          );
        }
        // recrée la partie droite
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
    required _GreedyProfile profile,
    required int seed,
    required Set<(String, String)> prevCouplesBefore,
    required Map<String, List<int>> preWeeksByPilot,
  }) {
    final rnd = Random(seed);

    final assignment = <WeekSpan, (String, String)>{};
    final assignedWeeksByPilot = <String, List<int>>{
      for (final t in tris) t: List<int>.from(
          preWeeksByPilot[t] ?? const <int>[])
    };
    final projected = Map<String, int>.from(baselineWeJfDays);
    final previousCouples = <(String, String)>{...prevCouplesBefore};

    // 1) Détecte les semaines “étranglées” (peu de couples admis)
    final couplesByWeek = <int, List<(String, String)>>{};
    for (int w = 0; w < weeks.length; w++) {
      final span = weeks[w];
      final L = _validPairsForWeek(
        tris: tris,
        span: span,
        indispos: indisposByPilot,
        chefExclusions: chefExclusionsByWeek[w] ?? const <String>{},
      );
      couplesByWeek[w] = L;
    }

    // Tri des semaines par contrainte croissante (moins de couples d’abord)
    final weekOrder = List<int>.generate(weeks.length, (i) => i);
    weekOrder.sort((a, b) =>
        (couplesByWeek[a]!.length).compareTo(couplesByWeek[b]!.length));

    // 2) Construction gloutonne
    for (final w in weekOrder) {
      final span = weeks[w];
      var candidates = couplesByWeek[w]!;
      if (candidates.isEmpty) {
        debugPrint("Semaine ${_fmtDateFr(
            span.monday)} : aucun couple faisable → ABANDON DU PLAN");
        return null;
      }

      // On filtre d’abord les couples qui créeraient 1-1 pour A ou B
      var admissibles = candidates.where((p) {
        final a = p.$1;
        final b = p.$2;
        if (_willBeConsecutive(a, w, assignedWeeksByPilot)) return false;
        if (_willBeConsecutive(b, w, assignedWeeksByPilot)) return false;
        return true;
      }).toList();

      if (admissibles.isEmpty && profile.allowRelaxed) {
        // On relâche (cas extrême) : on réintroduit tous les couples, mais ils vont
        // être lourdement pénalisés par le scoring (1-1).
        admissibles = List<(String, String)>.from(candidates);
      }

      if (admissibles.isEmpty) {
        debugPrint("Semaine ${_fmtDateFr(
            span.monday)} : aucun couple admissible après règles → ABANDON");
        return null;
      }

      // Score des admissibles
      final scored = <({(String, String) pair, double score})>[];
      for (final pair in admissibles) {
        final s = _scorePair(
          a: pair.$1,
          b: pair.$2,
          weekIndex: w,
          assignedWeeksByPilot: assignedWeeksByPilot,
          projectedWeJfDays: projected,
          previousCouples: previousCouples,
          profile: profile,
        );
        scored.add((pair: pair, score: s));
      }

      // vraie variabilité : léger shake aléatoire
      for (int i = 0; i < scored.length; i++) {
        scored[i] = (
        pair: scored[i].pair,
        score: scored[i].score + rnd.nextDouble() * 0.001
        );
      }
      scored.sort((x, y) => x.score.compareTo(y.score));

      // LOG top 3
      debugPrint("S${w + 1} ${_fmtDateFr(span.monday)} candidats=${scored
          .length}, top3 :");
      for (int k = 0; k < min(3, scored.length); k++) {
        final p = scored[k];
        debugPrint("  ${k + 1}) ${p.pair.$1}/${p.pair.$2} score=${p.score
            .toStringAsFixed(1)}");
      }

      final best = scored.first.pair;
      assignment[span] = best;

      // Projection : chaque semaine ajoute 2 jours WE (sam + dim)
      projected[best.$1] = (projected[best.$1] ?? 0) + 2;
      projected[best.$2] = (projected[best.$2] ?? 0) + 2;

      assignedWeeksByPilot[best.$1]!.add(w);
      assignedWeeksByPilot[best.$2]!.add(w);

      previousCouples.add(canonPair(best.$1, best.$2));
    }

    // Score global de plan (écart max-min + réutilisation des couples)
    final totalScore = _planScore(
      couples: assignment.values.toList(),
      projectedWeJfDays: projected,
      profile: profile,
    );

    final delta = <String, int>{for (final t in tris) t: 0};
    for (final c in assignment.values) {
      delta[c.$1] = delta[c.$1]! + 2;
      delta[c.$2] = delta[c.$2]! + 2;
    }

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

    DateTime monday = start.subtract(
        Duration(days: (start.weekday - DateTime.monday + 7) % 7));
    final lastMonday = end.subtract(
        Duration(days: (end.weekday - DateTime.monday + 7) % 7));

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

    final jf = (joursFeriesProvider != null) ? await joursFeriesProvider!(
        from, to) : <DateTime>[];
    final out = <String, int>{};

    for (final t in pilotes) {
      final evs = await planningDao.getForRange(
          from, to.add(const Duration(days: 1)), forUser: t);
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

  bool _weekendBothFree(String a,
      String b,
      WeekSpan span,
      Map<String, Set<DateTime>> indispos,) {
    final sat = _dayOnly(span.monday.add(const Duration(days: 5)));
    final sun = _dayOnly(span.monday.add(const Duration(days: 6)));
    final ia = indispos[a] ?? {};
    final ib = indispos[b] ?? {};
    return !(ia.contains(sat) || ia.contains(sun) || ib.contains(sat) ||
        ib.contains(sun));
  }

  bool _weekdayFeasible(String a,
      String b,
      WeekSpan span,
      Map<String, Set<DateTime>> indispos,) {
    final days = List<DateTime>.generate(
        5, (i) => _dayOnly(span.monday.add(Duration(days: i))));
    final ia = indispos[a] ?? {};
    final ib = indispos[b] ?? {};

    final offA = days
        .where(ia.contains)
        .length;
    final offB = days
        .where(ib.contains)
        .length;

    final aFull = offA == 0;
    final bFull = offB == 0;

    if (aFull && bFull) return true;
    if (aFull && offB <= 4) return true;
    if (bFull && offA <= 4) return true;
    return false;
  }

  bool _willBeConsecutive(String pilot, int weekIndex,
      Map<String, List<int>> assignedWeeksByPilot) {
    final lst = assignedWeeksByPilot[pilot] ?? const <int>[];
    return lst.contains(weekIndex - 1);
  }

  double _spacingPenaltyForPilot(String pilot,
      int weekIndex,
      Map<String, List<int>> assignedWeeksByPilot,
      _GreedyProfile profile,) {
    double pen = 0;
    final lst = List<int>.from(assignedWeeksByPilot[pilot] ?? const <int>[])
      ..sort();

    // 1-1
    if (lst.contains(weekIndex - 1)) pen += profile.hugePenaltyConsec;

    // 1-0-1
    if (lst.contains(weekIndex - 2)) pen += profile.penalty101;

    // 1-0-1-0-1
    if (lst.contains(weekIndex - 2) && lst.contains(weekIndex - 4)) {
      pen += profile.hugePenaltyTriple;
    }

    // cooldown général : plus l’écart avec la dernière astreinte est court, plus on pénalise
    final last = lst.isNotEmpty ? lst.last : null;
    if (last != null) {
      final gap = weekIndex - last;
      if (gap <= 3) {
        pen += (4 - gap) * profile.wSpacing; // gap=1→3*w, 2→2*w, 3→1*w
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

    // Espacement / alternances
    score +=
        _spacingPenaltyForPilot(a, weekIndex, assignedWeeksByPilot, profile);
    score +=
        _spacingPenaltyForPilot(b, weekIndex, assignedWeeksByPilot, profile);

    // Variabilité du couple
    final canon = canonPair(a, b);
    if (previousCouples.contains(canon)) score += profile.pairRepeatPenalty;

    // Homogénéisation : on favorise les pilotes en retard
    final pa = projectedWeJfDays[a] ?? 0;
    final pb = projectedWeJfDays[b] ?? 0;

    // Récompense “boost low” : plus faible est pa/pb, plus on favorise
    final minAB = min(pa, pb).toDouble();
    score -= minAB * profile.boostLow; // c’est une récompense → on soustrait

    // On garde aussi un terme qui limite le pic et la somme
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
      final vals = projectedWeJfDays.values.toList()
        ..sort();
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
    final map = <String, Set<DateTime>>{
      for (final t in pilotes) t: <DateTime>{}
    };

    for (final t in pilotes) {
      final evs = await planningDao.getForRange(
          _dayOnly(start), _dayOnly(end).add(const Duration(days: 1)),
          forUser: t);
      for (final e in evs) {
        if (e.typeEvent
            .trim()
            .isEmpty) continue;
        for (final d in _daysInclusive(
            _dayOnly(e.dateStart), _dayOnly(e.dateEnd))) {
          if (d.isBefore(_dayOnly(start)) || d.isAfter(_dayOnly(end))) continue;
          map[t]!.add(d);
        }
      }
    }
    return map;
  }

  /// Crée des segments AST pour les jours **libres** d’une semaine (évite toute collision).
  Future<void> _createAstSegmentsForPilotInWeekDao(String trigramme,
      WeekSpan span) async {
    final tri = trigramme.toUpperCase().trim();

    final evs = await planningDao.getForRange(
        span.monday, span.sunday.add(const Duration(days: 1)), forUser: tri);
    final busy = <DateTime>{};
    for (final e in evs) {
      if (e.typeEvent
          .trim()
          .isEmpty) continue;
      for (final d in _daysInclusive(
          _dayOnly(e.dateStart), _dayOnly(e.dateEnd))) {
        busy.add(d);
      }
    }

    final days = List<DateTime>.generate(
        7, (i) => _dayOnly(span.monday.add(Duration(days: i))));
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
  // Historique S-1 / S-2 (avant période)
  // =========================

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

