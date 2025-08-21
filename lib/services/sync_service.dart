import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/app_database.dart'; // Drift
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart'; // si besoin

enum Fonction { chef, cdt, none }
// --- A1) Début de journée locale (00:00:00) ---
DateTime _startOfTodayLocal() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

// --- A2) Lecture/écriture du "dernier sync" par collection ---
Future<DateTime?> _getLastSync(String key) async {
  final prefs = await SharedPreferences.getInstance();
  final millis = prefs.getInt('sync_last_$key');
  if (millis == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

Future<void> _setLastSync(String key, DateTime dt) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('sync_last_$key', dt.millisecondsSinceEpoch);
}
// --- B) Construit la Query Firestore pour "missions" selon la fonction ---
Query<Map<String, dynamic>> _buildMissionsQuery() {
  final col = firestore.collection('missions');
  final today = _startOfTodayLocal();

  if (fonction == Fonction.chef) {
    // Chef : historique complet mais en incrémental via updatedAt
    // - 1er run (pas de lastSync) : full scan ordonné par updatedAt (paginate)
    // - Runs suivants : updatedAt > lastSync
    return col.orderBy('updatedAt', descending: false);
  } else {
    // cdt ou rien : toujours borné à partir d'aujourd'hui
    // NB: on ne met pas de filtre updatedAt ici pour éviter un index composé
    //     inutile ; l'ensemble est limité par "date >= today" et paginé.
    return col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .orderBy('date', descending: false);
  }
}

class SyncService {
  final AppDatabase db;
  final Fonction fonction;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  SyncService({required this.db, required this.fonction});

  Future<void> syncAll() async {
    print("SYNC: Début synchronisation pour fonction=$fonction");

    await _syncUsers();
    await _syncChefMessages();
    await _syncOrganigramme();
    await _syncMissions();
    await _syncPlanningEvents();

    print("SYNC: Fin de la synchronisation");
  }

  Future<void> _syncUsers() async {
    // TODO: rapatrier toute la collection users (full + incrémentale)
  }

  Future<void> _syncChefMessages() async {
    // TODO: createdAt >= today, pas d’archives
  }

  Future<void> _syncOrganigramme() async {
    // TODO: full + incrémentale
  }

  Future<void> _syncMissions() async {
    if (fonction == Fonction.chef) {
      // TODO: sync complète
    } else {
      // TODO: uniquement where date >= today
    }
  }

  Future<void> _syncPlanningEvents() async {
    if (fonction == Fonction.chef || fonction == Fonction.cdt) {
      // TODO: sync complète
    } else {
      // TODO: uniquement where date >= today
    }
  }
}
