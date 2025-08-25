// lib/services/jours_feries_provider.dart
//
// Fournit les jours fériés (JF) par année, avec une liste 2025 "en dur"
// à compléter par le chef. On peut aussi injecter des JF additionnels
// (propre à la période courante) depuis l'UI.
//

import 'package:flutter/foundation.dart';

/// Provider simple des jours fériés par année.
/// - getForRange() renvoie l'ensemble des JF compris dans [start, end] inclus.
/// - Ajoute aussi des JF "additionnels" transmis à l'appel (ex: saisis par le chef pour la période).
class JoursFeriesProvider {
  /// Map<year, Set<DateTime(dateOnly)>>
  final Map<int, Set<DateTime>> _byYear;

  JoursFeriesProvider._(this._byYear);

  /// Factory par défaut avec l'année 2025 "en dur".
  /// ⚠️ À COMPLÉTER : renseigne ici tous les JF connus (Gabon 2025 : nationaux, religieux, etc.).
  factory JoursFeriesProvider.gabonDefaults2025() {
    final Map<int, Set<DateTime>> data = {
      2025: {
        // TODO: REMPLIR LA LISTE 2025 AVEC LES JF RÉELS

         DateTime(2025, 6,6),
          DateTime(2025, 6, 9),
         DateTime(2025, 5, 1),
        DateTime(2025, 4, 17),
        DateTime(2025, 4, 21),
        // ...
      },
    };
    return JoursFeriesProvider._(data);
  }

  /// Normalise à date-only (00:00).
  static DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Renvoie l'ensemble des jours fériés présents dans [start, end] inclus,
  /// en y ajoutant [extraForThisPeriod] (saisis par le chef pour la période).
  Set<DateTime> getForRange(DateTime start, DateTime end, {List<DateTime> extraForThisPeriod = const []}) {
    final s = _d(start);
    final e = _d(end);
    final out = <DateTime>{};
    DateTime cur = s;
    while (!cur.isAfter(e)) {
      final setYear = _byYear[cur.year];
      if (setYear != null && setYear.contains(cur)) {
        out.add(cur);
      }
      cur = cur.add(const Duration(days: 1));
    }
    for (final x in extraForThisPeriod) {
      out.add(_d(x));
    }
    return out;
  }

  /// Permet d'ajouter facilement des JF "en dur" pour une année.
  /// Utile si tu veux injecter les JF 2026 plus tard.
  void addFixedHolidaysForYear(int year, List<DateTime> dates) {
    final target = _byYear.putIfAbsent(year, () => <DateTime>{});
    for (final d in dates) {
      target.add(_d(d));
    }
  }
}
