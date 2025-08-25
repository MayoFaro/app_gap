// lib/services/astreinte_weekend_counter.dart
//
// Compteur robuste des jours AST "critiques" (samedis, dimanches, jours fériés)
// sur une période. Corrige les erreurs classiques :
//  - fin exclusive → on étend les events en jours "INCLUSIFS"
//  - mauvais test du dimanche (en Dart, Sunday == 7)
//  - chevauchements & doublons → on déduplique par Set<DateTime(dayOnly))
//
// Utilisation typique (dans astreinte_engine / écran debug) :
// final counter = AstreinteWeekendCounter(planningDao);
// final n = await counter.countAstWeJfForUser(
//   trigramme: 'DPS',
//   from: DateTime(2025,1,1),
//   toInclusive: DateTime(2025,8,21),
//   extraJoursFeries: [ ... ],
// );
// await counter.logDebugForUser(
//   trigramme: 'DPS',
//   from: DateTime(2025,1,1),
//   toInclusive: DateTime(2025,8,21),
//   extraJoursFeries: [ ... ],
// );
//
// NB : on s'appuie sur PlanningDao.getForRange(start, endExclusive, forUser)
// qui attend [start, end[ → on lui passe endExclusive = toInclusive + 1 jour.

import 'package:intl/intl.dart';
import '../data/planning_dao.dart';
import '../data/app_database.dart';

class AstreinteWeekendCounter {
  final PlanningDao dao;

  AstreinteWeekendCounter(this.dao);

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  /// Retourne le nombre de JOURS AST "critiques" (samedi/dimanche/JF) réellement effectués
  /// par `trigramme` sur [from .. toInclusive].
  Future<int> countAstWeJfForUser({
    required String trigramme,
    required DateTime from,
    required DateTime toInclusive,
    List<DateTime> extraJoursFeries = const [],
  }) async {
    final set = await _collectAstWeJfDays(
      trigramme: trigramme,
      from: from,
      toInclusive: toInclusive,
      extraJoursFeries: extraJoursFeries,
    );
    return set.length;
  }

  /// Log détaillé (FR) de tous les jours comptés + quelques stats.
  Future<void> logDebugForUser({
    required String trigramme,
    required DateTime from,
    required DateTime toInclusive,
    List<DateTime> extraJoursFeries = const [],
    String tag = 'AST ENGINE',
  }) async {
    final fmt = DateFormat('dd/MM/yy');
    final counted = await _collectAstWeJfDays(
      trigramme: trigramme,
      from: from,
      toInclusive: toInclusive,
      extraJoursFeries: extraJoursFeries,
    );

    // Relit les events bruts pour stats
    final endExclusive = _dayOnly(toInclusive).add(const Duration(days: 1));
    final events = await dao.getForRange(_dayOnly(from), endExclusive, forUser: trigramme);
    final astOnly = events.where((e) => e.typeEvent == 'AST').toList();

    // Tri pour un log lisible
    final days = counted.toList()
      ..sort((a, b) => a.compareTo(b));

    // En-tête
    _log("=== DEBUG $tag / $trigramme ===");
    _log("JOURS CRITIQUES = samedis + dimanches + JF");
    _log("[A] Évents lus (tous) : ${events.length} / AST : ${astOnly.length}");
    _log("[A] AST (WE+JF) réalisés du ${fmt.format(_dayOnly(from))} au ${fmt.format(_dayOnly(toInclusive))} : ${days.length} jour(s)");

    // Détail jour par jour
    for (final d in days) {
      final wd = _weekdayShortFr(d);
      final jf = _isJourFerie(d, extraJoursFeries) ? ' + JF' : '';
      _log("  - $wd ${fmt.format(d)}  (AST compté$jf)");
    }

    _log("=== FIN DEBUG $trigramme ===");
  }

  // --------------------------------------------------------------------------
  // Core
  // --------------------------------------------------------------------------

  Future<Set<DateTime>> _collectAstWeJfDays({
    required String trigramme,
    required DateTime from,
    required DateTime toInclusive,
    required List<DateTime> extraJoursFeries,
  }) async {
    final startD = _dayOnly(from);
    final endD = _dayOnly(toInclusive);
    if (endD.isBefore(startD)) return <DateTime>{};

    // On demande au DAO avec fin EXCLUSIVE (+1 jour).
    final endExclusive = endD.add(const Duration(days: 1));
    final events = await dao.getForRange(startD, endExclusive, forUser: trigramme);

    // JF normalisés (dayOnly)
    final jf = extraJoursFeries.map(_dayOnly).toSet();

    // Pour chaque event AST, on l'étend jour par jour **INCLUSIF**,
    // puis on filtre : samedi OU dimanche OU JF → on garde.
    final counted = <DateTime>{};

    for (final e in events) {
      if (e.typeEvent != 'AST') continue;

      final eStart = _dayOnly(e.dateStart);
      final eEnd = _dayOnly(e.dateEnd);

      // Étend en jours inclusifs (évite le piège fin exclusive)
      for (final d in _daysInclusive(eStart, eEnd)) {
        // On ignore les jours hors de [from..toInclusive] pour être rigoureux
        if (d.isBefore(startD) || d.isAfter(endD)) continue;

        if (_isSamedi(d) || _isDimanche(d) || jf.contains(d)) {
          counted.add(d); // Set = déduplication automatique
        }
      }
    }

    return counted;
  }

  // --------------------------------------------------------------------------
  // Date helpers
  // --------------------------------------------------------------------------

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Iterable<DateTime> _daysInclusive(DateTime a, DateTime b) sync* {
    DateTime cur = a.isBefore(b) ? a : b;
    final last = a.isBefore(b) ? b : a;
    while (!cur.isAfter(last)) {
      yield cur;
      cur = cur.add(const Duration(days: 1));
    }
  }

  bool _isSamedi(DateTime d)   => d.weekday == DateTime.saturday; // 6
  bool _isDimanche(DateTime d) => d.weekday == DateTime.sunday;   // 7

  bool _isJourFerie(DateTime d, List<DateTime> jf) {
    final set = jf.map(_dayOnly).toSet();
    return set.contains(_dayOnly(d));
  }

  String _weekdayShortFr(DateTime d) {
    switch (d.weekday) {
      case DateTime.monday:    return 'Lun';
      case DateTime.tuesday:   return 'Mar';
      case DateTime.wednesday: return 'Mer';
      case DateTime.thursday:  return 'Jeu';
      case DateTime.friday:    return 'Ven';
      case DateTime.saturday:  return 'Sam';
      case DateTime.sunday:    return 'Dim';
      default: return '';
    }
  }

  void _log(String s) {
    // Garde console simple et centralisée
    // (tu peux basculer sur debugPrint si tu préfères)
    // ignore: avoid_print
    print(s);
  }
}
