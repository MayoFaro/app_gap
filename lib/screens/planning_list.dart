// lib/screens/planning_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:horizontal_data_table/horizontal_data_table.dart';

import '../data/planning_dao.dart';
import '../data/app_database.dart';

class PlanningList extends StatefulWidget {
  final PlanningDao dao;
  const PlanningList({Key? key, required this.dao}) : super(key: key);

  @override
  State<PlanningList> createState() => _PlanningListState();
}

class _PlanningListState extends State<PlanningList> {
  late ScrollController _verticalController;
  late ScrollController _horizontalController;

  // largeur d'une cellule jour (modifiée par pinch-to-zoom)
  double _cellWidth = 60;
  double _baseCellWidth = 60;

  // années disponibles
  final List<int> _years = List.generate(6, (i) => 2025 + i);

  // année sélectionnée (entre 2025 et 2030)
  late int _selectedYear;

  // tous les jours de l'année sélectionnée
  List<DateTime> _daysOfYear = [];
  bool _hasJumpedToToday = false;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year.clamp(2025, 2030);
    _generateDaysForYear(_selectedYear);
  }

  void _generateDaysForYear(int year) {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31);
    _daysOfYear = List.generate(
      end.difference(start).inDays + 1,
          (i) => start.add(Duration(days: i)),
    );
    _hasJumpedToToday = false;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseCellWidth = _cellWidth;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _cellWidth = (_baseCellWidth * details.scale).clamp(30.0, 120.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<User>>(
      future: widget.dao.attachedDatabase.select(widget.dao.attachedDatabase.users).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final users = snapshot.data!;
        if (users.isEmpty) {
          return const Center(child: Text('Aucun utilisateur trouvé.'));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Planning'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  // TODO : ouvrir écran d'ajout/modification pour l'utilisateur connecté
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // dropdown année
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text('Année :'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _selectedYear,
                      items: _years
                          .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (y) {
                        if (y == null) return;
                        setState(() {
                          _selectedYear = y;
                          _generateDaysForYear(y);
                        });
                      },
                    ),
                  ],
                ),
              ),
              // planning grid with pinch-to-zoom
              Expanded(
                child: GestureDetector(
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  child: HorizontalDataTable(
                    leftHandSideColumnWidth: 120,
                    rightHandSideColumnWidth: _daysOfYear.length * _cellWidth,
                    isFixedHeader: true,
                    headerWidgets: _buildHeader(),
                    leftSideItemBuilder: (context, rowIndex) {
                      final user = users[rowIndex];
                      return Container(
                        width: 120,
                        height: 40,
                        padding: const EdgeInsets.all(6),
                        alignment: Alignment.centerLeft,
                        child: Text(user.fullName ?? user.trigramme),
                      );
                    },
                    rightSideItemBuilder: (context, rowIndex) {
                      return Row(
                        children: _daysOfYear.map((date) {
                          return Container(
                            width: _cellWidth,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Text(''),
                          );
                        }).toList(),
                      );
                    },
                    itemCount: users.length,
                    rowSeparatorWidget: const Divider(color: Colors.grey),
                    onScrollControllerReady: (vertical, horizontal) {
                      _verticalController = vertical;
                      _horizontalController = horizontal;
                      // première fois : centrer sur aujourd’hui si année courante
                      if (!_hasJumpedToToday && _selectedYear == DateTime.now().year) {
                        final today = DateTime.now();
                        final offsetDays = today
                            .difference(DateTime(_selectedYear, 1, 1))
                            .inDays;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _horizontalController.jumpTo(offsetDays * _cellWidth);
                        });
                        _hasJumpedToToday = true;
                      }
                    },
                    leftHandSideColBackgroundColor: Colors.white,
                    rightHandSideColBackgroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildHeader() {
    return [
      Container(
        width: 120,
        height: 50,
        alignment: Alignment.center,
        color: Colors.blue.shade100,
        child: const Text('Nom', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      ..._daysOfYear.map((date) {
        return Container(
          width: _cellWidth,
          height: 50,
          alignment: Alignment.center,
          child: Text(DateFormat('dd/MM').format(date)),
        );
      }).toList(),
    ];
  }
}
