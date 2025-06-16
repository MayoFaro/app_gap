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
  double _cellWidth = 60;
  late ScrollController _vCtrl, _hCtrl;
  late int _selectedYear;
  late List<DateTime> _days;
  bool _jumped = false;
  String _trigram = '---';

  bool _isReady = false;
  late List<String> _users;
  late Map<String, List<PlanningEvent>> _eventsByUser;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _generateDays(_selectedYear);
    _loadTrigram();
    _preloadData();
  }

  Future<void> _preloadData() async {
    // Charge tous les utilisateurs
    final usersRows = await widget.dao.attachedDatabase
        .select(widget.dao.attachedDatabase.users)
        .get();
    _users = usersRows.map((u) => u.trigramme).toList();

    // Charge tous les événements pour l'année sélectionnée
    final allEvents = await widget.dao.attachedDatabase
        .select(widget.dao.attachedDatabase.planningEvents)
        .get();

    // Indexe les événements par utilisateur
    _eventsByUser = {for (var u in _users) u: []};
    for (var e in allEvents) {
      if (_eventsByUser.containsKey(e.user)) {
        _eventsByUser[e.user]!.add(e);
      }
    }

    setState(() => _isReady = true);
  }

  Future<void> _loadTrigram() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _trigram = prefs.getString('userTrigram') ?? '---');
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

  void _zoomIn() => setState(() => _cellWidth = min(120, _cellWidth + 10));
  void _zoomOut() => setState(() => _cellWidth = max(20, _cellWidth - 10));

  @override
  Widget build(BuildContext context) {
    final totalWidth = _days.length * _cellWidth;

    if (!_isReady) {
      return Scaffold(
        appBar: CustomAppBar('${_trigram}_appGAP_Planning'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: CustomAppBar('${_trigram}_appGAP_Planning'),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showEventSelector(context),
      ),
      body: Column(
        children: [
          _buildControls(),
          Expanded(
            child: HorizontalDataTable(
              leftHandSideColumnWidth: 120,
              rightHandSideColumnWidth: totalWidth,
              isFixedHeader: true,
              headerWidgets: _buildHeader(),
              leftSideItemBuilder: (ctx, i) => _buildUserCell(i),
              rightSideItemBuilder: (ctx, i) => _buildRow(i),
              itemCount: _users.length,
              rowSeparatorWidget: const Divider(color: Colors.grey),
              onScrollControllerReady: (v, h) => _onScrollReady(v, h),
              leftHandSideColBackgroundColor: Colors.white,
              rightHandSideColBackgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Année :'),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _selectedYear,
            items: [
              for (var y in [_selectedYear, _selectedYear + 1])
                DropdownMenuItem(value: y, child: Text('$y'))
            ],
            onChanged: (year) {
              if (year == null) return;
              setState(() {
                _selectedYear = year;
                _generateDays(year);
                _isReady = false;
              });
              _preloadData();
            },
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.remove), tooltip: 'Dézoomer', onPressed: _zoomOut),
          const Icon(Icons.search),
          IconButton(icon: const Icon(Icons.add), tooltip: 'Zoomer', onPressed: _zoomIn),
        ],
      ),
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
      ..._days.map((day) => Container(
        width: _cellWidth,
        height: 50,
        alignment: Alignment.center,
        child: Text(DateFormat('dd/MM').format(day)),
      )),
    ];
  }

  Widget _buildUserCell(int index) {
    final user = _users[index];
    return Container(
      width: 120,
      height: 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(6),
      child: Text(user),
    );
  }

  Widget _buildRow(int index) {
    final user = _users[index];
    final events = _eventsByUser[user] ?? [];
    final mapEvent = <DateTime, PlanningEvent>{};
    for (var e in events) {
      final start = DateTime(e.dateStart.year, e.dateStart.month, e.dateStart.day);
      final end = DateTime(e.dateEnd.year, e.dateEnd.month, e.dateEnd.day);
      for (int d = 0; d <= end.difference(start).inDays; d++) {
        mapEvent[start.add(Duration(days: d))] = e;
      }
    }

    return Row(
      children: _days.map((day) {
        final evt = mapEvent[day];
        final label = evt?.typeEvent ?? '';
        final bg = evt != null ? eventColors[evt.typeEvent] : null;
        return GestureDetector(
          onLongPress: evt != null && evt.user == _trigram
              ? () => _showEditDeleteDialog(context, evt)
              : null,
          child: Container(
            width: _cellWidth,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(label),
          ),
        );
      }).toList(),
    );
  }

  void _onScrollReady(ScrollController v, ScrollController h) {
    _vCtrl = v;
    _hCtrl = h;
    if (!_jumped && _selectedYear == DateTime.now().year) {
      final idx = DateTime.now().difference(DateTime(_selectedYear, 1, 1)).inDays;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hCtrl.jumpTo(idx * _cellWidth));
      _jumped = true;
    }
  }

  void _showEventSelector(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          ...['TWR','CRM','BAR','PN','RU'].map((e) => ListTile(
            title: Text(e),
            onTap: () { Navigator.pop(ctx); _showOneDayDialog(ctx, e); },
          )),
          ...['AST','DA','CA'].map((e) => ListTile(
            title: Text(e),
            onTap: () { Navigator.pop(ctx); _showMultiDayDialog(ctx, e); },
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
              title: const Text("Aujourd'hui"),
              value: OneDayOption.today,
              groupValue: choice,
              onChanged: (v) => setD(() { choice = v; custom = null; }),
            ),
            RadioListTile<OneDayOption>(
              title: const Text('Hier'),
              value: OneDayOption.yesterday,
              groupValue: choice,
              onChanged: (v) => setD(() { choice = v; custom = null; }),
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
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: choice == null ? null : () async {
                DateTime dt;
                if (choice == OneDayOption.today) {
                  final now = DateTime.now();
                  dt = DateTime(now.year, now.month, now.day);
                } else if (choice == OneDayOption.yesterday) {
                  final y = DateTime.now().subtract(const Duration(days: 1));
                  dt = DateTime(y.year, y.month, y.day);
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
                _preloadData();
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMultiDayDialog(BuildContext ctx, String type,
      {int? eventId, DateTime? initialStart, DateTime? initialEnd}) {
    DateTime start = initialStart ?? DateTime.now();
    DateTime end = initialEnd ?? start;
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setD) => AlertDialog(
          title: Text((eventId == null ? 'Ajouter ' : 'Éditer ') + type),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text('Début: ${DateFormat('dd/MM/yyyy').format(start)}'),
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
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Annuler')),
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
                _preloadData();
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDeleteDialog(BuildContext context, PlanningEvent e) {
    final isMulti = e.dateEnd.difference(e.dateStart).inDays > 0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Action sur ${e.typeEvent}'),
        content: Text(
            isMulti
                ? 'Modifier ou supprimer cet événement ?'
                : 'Supprimer cet événement ?'
        ),
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
              _preloadData();
            },
            child: const Text('Supprimer'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ],
      ),
    );
  }
}
