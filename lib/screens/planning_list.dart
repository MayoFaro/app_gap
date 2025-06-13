// lib/screens/planning_list.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:horizontal_data_table/horizontal_data_table.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/planning_dao.dart';
import '../data/app_database.dart';
import '../widgets/custom_app_bar.dart';

/// Options pour un événement d’un seul jour.
enum OneDayOption { today, yesterday, other }

/// Couleurs par type d’événement.
const Map<String, Color> eventColors = {
  'TWR': Colors.orange,
  'CRM': Colors.green,
  'BAR': Colors.blue,
  'PN': Colors.purple,
  'RU': Colors.red,
  'AST': Colors.lightBlue,
  'DA': Colors.lightGreen,
  'CA': Colors.amber,
};

class PlanningList extends StatefulWidget {
  final PlanningDao dao;
  const PlanningList({Key? key, required this.dao}) : super(key: key);

  @override
  State<PlanningList> createState() => _PlanningListState();
}

class _PlanningListState extends State<PlanningList> {
  double _cellWidth = 60; // largeur zoomable
  late ScrollController _vCtrl, _hCtrl;
  late int _selectedYear;
  late List<DateTime> _days;
  bool _jumped = false;
  String _trigram = '---';
  final _years = List.generate(6, (i) => 2025 + i);

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year.clamp(2025, 2030);
    _generateDays(_selectedYear);
    _loadTrigram();
  }

  Future<void> _loadTrigram() async {
    final prefs = await SharedPreferences.getInstance();
    _trigram = prefs.getString('userTrigram') ??
        prefs.getString('userTrigramme') ??
        '---';
    setState(() {});
  }

  void _generateDays(int year) {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31);
    _days = List.generate(
      end.difference(start).inDays + 1,
          (i) => start.add(Duration(days: i)),
    );
    _jumped = false;
  }

  void _zoomIn() {
    setState(() => _cellWidth = min(120, _cellWidth + 10));
  }

  void _zoomOut() {
    setState(() => _cellWidth = max(20, _cellWidth - 10));
  }

  @override
  Widget build(BuildContext context) {
    final totalWidth = _days.length * _cellWidth;

    return FutureBuilder<List<User>>(
      future: widget.dao.attachedDatabase.select(widget.dao.attachedDatabase.users).get(),
      builder: (ctx, uSnap) {
        if (!uSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = uSnap.data!;

        return Scaffold(
          appBar: CustomAppBar('${_trigram}_appGAP_Planning'),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () => _showEventSelector(context),
          ),
          body: Column(
            children: [
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text('Année :'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _selectedYear,
                      items: _years
                          .map((y) =>
                          DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (year) {
                        if (year == null) return;
                        setState(() {
                          _selectedYear = year;
                          _generateDays(year);
                        });
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      tooltip: 'Dézoomer',
                      onPressed: _zoomOut,
                    ),
                    const Icon(Icons.search),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Zoomer',
                      onPressed: _zoomIn,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: HorizontalDataTable(
                  leftHandSideColumnWidth: 120,
                  rightHandSideColumnWidth: totalWidth,
                  isFixedHeader: true,
                  headerWidgets: _buildHeader(),
                  leftSideItemBuilder: (ctx, i) => Container(
                    width: 120,
                    height: 40,
                    padding: const EdgeInsets.all(6),
                    alignment: Alignment.centerLeft,
                    child: Text(users[i].trigramme),
                  ),
                  rightSideItemBuilder: (ctx, i) {
                    return StreamBuilder<List<PlanningEvent>>(
                      stream:
                      widget.dao.watchEventsForUser(users[i].trigramme),
                      builder: (_, evSnap) {
                        final events = evSnap.data ?? [];
                        // Map date → PlanningEvent for full range
                        final mapEvent = <DateTime, PlanningEvent>{};
                        for (var e in events) {
                          final start = DateTime(
                              e.dateStart.year, e.dateStart.month, e.dateStart.day);
                          final end = DateTime(
                              e.dateEnd.year, e.dateEnd.month, e.dateEnd.day);
                          for (int d = 0;
                          d <= end.difference(start).inDays;
                          d++) {
                            mapEvent[start.add(Duration(days: d))] = e;
                          }
                        }

                        return Row(
                          children: _days.map((day) {
                            final evt = mapEvent[day];
                            final label = evt?.typeEvent ?? '';
                            final bg = evt != null
                                ? eventColors[evt.typeEvent]
                                : null;

                            return GestureDetector(
                              onLongPress: (evt != null && evt.user == _trigram)
                                  ? () => _handleLongPress(context, evt)
                                  : null,
                              child: Container(
                                width: _cellWidth,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: bg,
                                  border:
                                  Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(label),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                  itemCount: users.length,
                  rowSeparatorWidget: const Divider(color: Colors.grey),
                  onScrollControllerReady: (v, h) {
                    _vCtrl = v;
                    _hCtrl = h;
                    if (!_jumped &&
                        _selectedYear == DateTime.now().year) {
                      final idx = DateTime.now()
                          .difference(DateTime(_selectedYear, 1, 1))
                          .inDays;
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _hCtrl.jumpTo(idx * _cellWidth));
                      _jumped = true;
                    }
                  },
                  leftHandSideColBackgroundColor: Colors.white,
                  rightHandSideColBackgroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildHeader() => [
    Container(
      width: 120,
      height: 50,
      alignment: Alignment.center,
      color: Colors.blue.shade100,
      child: const Text('Nom',
          style: TextStyle(fontWeight: FontWeight.bold)),
    ),
    ..._days.map((day) => Container(
      width: _cellWidth,
      height: 50,
      alignment: Alignment.center,
      child: Text(DateFormat('dd/MM').format(day)),
    )),
  ];

  void _showEventSelector(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) => ListView(
        children: [
          ...['TWR', 'CRM', 'BAR', 'PN', 'RU'].map((e) => ListTile(
            title: Text(e),
            onTap: () {
              Navigator.pop(ctx);
              _showOneDayDialog(ctx, e);
            },
          )),
          ...['AST', 'DA', 'CA'].map((e) => ListTile(
            title: Text(e),
            onTap: () {
              Navigator.pop(ctx);
              _showMultiDayDialog(ctx, e);
            },
          )),
        ],
      ),
    );
  }

  void _showOneDayDialog(BuildContext ctx, String type) {
    OneDayOption? choice;
    DateTime? custom;
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setD) => AlertDialog(
          title: Text('Ajouter $type'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            RadioListTile<OneDayOption>(
              title: const Text('Aujourd\'hui'),
              value: OneDayOption.today,
              groupValue: choice,
              onChanged: (v) => setD(() {
                choice = v;
                custom = null;
              }),
            ),
            RadioListTile<OneDayOption>(
              title: const Text('Hier'),
              value: OneDayOption.yesterday,
              groupValue: choice,
              onChanged: (v) => setD(() {
                choice = v;
                custom = null;
              }),
            ),
            RadioListTile<OneDayOption>(
              title: const Text('Autre jour'),
              value: OneDayOption.other,
              groupValue: choice,
              onChanged: (v) async {
                final d = await showDatePicker(
                  context: ctx2,
                  initialDate: custom ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2030),
                );
                if (d != null) setD(() => custom = d);
                choice = OneDayOption.other;
              },
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: choice == null
                  ? null
                  : () async {
                DateTime dt;
                if (choice == OneDayOption.today) {
                  final n = DateTime.now();
                  dt = DateTime(n.year, n.month, n.day);
                } else if (choice == OneDayOption.yesterday) {
                  final m = DateTime.now()
                      .subtract(const Duration(days: 1));
                  dt = DateTime(m.year, m.month, m.day);
                } else {
                  dt = custom!;
                }
                await widget.dao.insertEvent(
                  user: _trigram,
                  typeEvent: type,
                  dateStart: dt,
                  dateEnd: dt,
                );
                Navigator.pop(ctx2);
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMultiDayDialog(BuildContext ctx, String type,
      {int? eventId,
        DateTime? initialStart,
        DateTime? initialEnd}) {
    DateTime start = initialStart ?? DateTime.now();
    DateTime end = initialEnd ?? start;
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setD) => AlertDialog(
          title: Text(eventId == null ? 'Ajouter $type' : 'Éditer $type'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text(
                  'Début: ${DateFormat('dd/MM/yyyy').format(start)}'),
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx2,
                  initialDate: start,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2030),
                );
                if (d != null) setD(() => start = d);
              },
            ),
            ListTile(
              title: Text('Fin: ${DateFormat('dd/MM/yyyy').format(end)}'),
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx2,
                  initialDate: end,
                  firstDate: start,
                  lastDate: DateTime(2030),
                );
                if (d != null) setD(() => end = d);
              },
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (eventId == null) {
                  await widget.dao.insertEvent(
                    user: _trigram,
                    typeEvent: type,
                    dateStart: start,
                    dateEnd: end,
                  );
                } else {
                  await widget.dao.updateEvent(
                    id: eventId,
                    dateStart: start,
                    dateEnd: end,
                  );
                }
                Navigator.pop(ctx2);
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLongPress(BuildContext context, PlanningEvent e) {
    final isMulti = e.dateEnd.difference(e.dateStart).inDays > 0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Action sur ${e.typeEvent}'),
        content: Text(isMulti
            ? 'Modifier ou supprimer cet événement ?'
            : 'Supprimer cet événement ?'),
        actions: [
          if (isMulti)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showMultiDayDialog(
                  context,
                  e.typeEvent,
                  eventId: e.id,
                  initialStart: e.dateStart,
                  initialEnd: e.dateEnd,
                );
              },
              child: const Text('Éditer'),
            ),
          TextButton(
            onPressed: () async {
              await widget.dao.deleteEvent(e.id);
              Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}
