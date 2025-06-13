import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/app_database.dart';
import '../data/mission_dao.dart';
import '../data/destinations.dart';

/// Contient la liste des missions filtrées et l'autorisation de l'utilisateur
class _MissionsData {
  final List<Mission> missions;
  final bool isChef;
  _MissionsData({required this.missions, required this.isChef});
}

/// Écran principal affichant les missions hebdomadaires
/// - Seuls les utilisateurs avec fonction "chef" peuvent ajouter ou modifier
/// - Affichage filtré selon le groupe (avion vs hélico)
class MissionsList extends StatefulWidget {
  final MissionDao dao;
  const MissionsList({Key? key, required this.dao}) : super(key: key);

  @override
  State<MissionsList> createState() => _MissionsListState();
}

class _MissionsListState extends State<MissionsList> {
  late Future<_MissionsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  /// Charge la fonction/groupe et filtre les missions
  Future<_MissionsData> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final fonction = prefs.getString('fonction')?.toLowerCase();
    final group = prefs.getString('userGroup')?.toLowerCase();
    final all = await widget.dao.getAllMissions();
    final isChef = fonction == 'chef';

    // DEBUG: vérifier la fonction et le flag isChef
    debugPrint('DEBUG MissionsList._loadData: fonction=$fonction, isChef=$isChef, userGroup=$group');


    // Vecteurs autorisés par groupe
    const groupVecteurs = {
      'avion': ['ATR72'],
      'helico': ['AH175', 'EC225'],
    };

    final filtered = group != null
        ? all.where((m) => groupVecteurs[group]?.contains(m.vecteur) ?? false).toList()
        : <Mission>[];

    return _MissionsData(missions: filtered, isChef: isChef);
  }

  /// Ouvre le dialogue d'ajout pour comparer DropdownButton et CupertinoPicker
  void _showAddMissionDialog() {
    String selectedDropdown = destinations.first;
    String selectedCupertino = destinations.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Ajouter une mission'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Sélecteur Material (DropdownButton)'),
                  DropdownButton<String>(
                    value: selectedDropdown,
                    isExpanded: true,
                    items: destinations
                        .map((code) => DropdownMenuItem(
                      value: code,
                      child: Text(code),
                    ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => selectedDropdown = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Sélecteur iOS (CupertinoPicker)'),
                  SizedBox(
                    height: 150,
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: destinations.indexOf(selectedCupertino),
                      ),
                      itemExtent: 32,
                      onSelectedItemChanged: (index) {
                        setState(() => selectedCupertino = destinations[index]);
                      },
                      children: destinations
                          .map((code) => Center(child: Text(code)))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Choix Dropdown: \$selectedDropdown'),
                  Text('Choix Cupertino: \$selectedCupertino'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  // TODO: Créer et insérer la mission via widget.dao.insertMission(...)
                  Navigator.of(context).pop();
                  setState(() => _dataFuture = _loadData());
                },
                child: const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Missions Hebdo')),
      body: FutureBuilder<_MissionsData>(
        future: _dataFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          if (data.missions.isEmpty) {
            return const Center(child: Text('Aucune mission disponible'));
          }
          return ListView.builder(
            itemCount: data.missions.length,
            itemBuilder: (_, i) {
              final m = data.missions[i];
              return ListTile(
                title: Text(
                  '${m.date.toLocal().toIso8601String().split("T").first}  ${m.vecteur}',
                ),
                subtitle: Text(
                  "${m.pilote1}${m.pilote2 != null ? "/${m.pilote2}" : ""} → ${m.destinationCode}${m.description != null ? " – ${m.description}" : ""}",
                ),

                onTap: data.isChef ? () {
                  // TODO: naviguer vers l’édition de la mission
                } : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<_MissionsData>(
        future: _dataFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done || !(snap.data?.isChef ?? false)) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: _showAddMissionDialog,
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}
