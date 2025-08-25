// lib/screens/planning_list.dart
//
// Lecture des events désormais via DAO (pullRangeFromRemote -> getForRange),
// pour garantir le contrat user=TRI / trigramme=TRI / uid séparé.
//
// + Appui long sur une case ayant un event (du user courant) → Éditer / Supprimer
// + Restauration d’offset pour ne pas retomber au 01/01.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:horizontal_data_table/horizontal_data_table.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart'; // PlanningEvent
import '../data/planning_dao.dart';
import '../widgets/custom_app_bar.dart';

enum OneDayOption { today, yesterday, other }

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
  late ScrollController _vCtrl;
  late ScrollController _hCtrl;
  late int _selectedYear;
  late List<DateTime> _days;
  bool _jumped = false;
  String _trigram = '---';
  double? _savedHOffset;

  bool _isReady = false;
  late List<String> _users; // trigrammes
  late Map<String, List<PlanningEvent>> _eventsByUser;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _generateDays(_selectedYear);
    _loadTrigram();
    _preloadData();
  }

  // --- Helpers normalisation / logs ------------------------------------------

  String _normTri(String s) => s.trim().toUpperCase();

  void _logUsersOrder(String stage) {
    debugPrint("PLANNING[users][$stage] count=${_users.length}");
    if (_users.isNotEmpty) {
      debugPrint("PLANNING[users][$stage] first='${_users.first}' codeUnits=${_users.first.codeUnits}");
      final idxPvt = _users.indexOf('PVT');
      debugPrint("PLANNING[users][$stage] indexOf('PVT')=$idxPvt");
      final preview = _users.take(15).join(', ');
      debugPrint("PLANNING[users][$stage] head15=[$preview]");
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> _preloadData() async {
    // 1) Users (locaux)
    final usersRows = await widget.dao.attachedDatabase
        .select(widget.dao.attachedDatabase.users)
        .get();

    final raw = usersRows
        .map((u) => (u.trigramme ?? '').toString())
        .where((s) => s.isNotEmpty)
        .map(_normTri)
        .toSet()
        .toList();

    raw.remove('---'); // ne pas afficher le placeholder
    raw.sort((a, b) => a.compareTo(b));
    _users = raw;

    _logUsersOrder('after_local_load_and_sort');

    _eventsByUser = {for (var t in _users) t: []};

    // 2) PULL Firestore -> LOCAL sur l'année sélectionnée
    final start = DateTime(_selectedYear, 1, 1);
    final endExcl = DateTime(_selectedYear + 1, 1, 1); // borne exclusive
    await widget.dao.pullRangeFromRemote(
      start: start,
      end: endExcl,
      trigramFilter: _users,
    );

    // 3) Lecture LOCALE des events sur l'année
    final events = await widget.dao.getForRange(start, endExcl);
    for (final e in events) {
      final tri = _normTri(e.user);
      if (_eventsByUser.containsKey(tri)) {
        _eventsByUser[tri]!.add(e);
      }
    }

    debugPrint("PLANNING[events] totalLocal=${events.length}");

    if (mounted) setState(() => _isReady = true);
  }

  Future<void> _loadTrigram() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _trigram = _normTri(prefs.getString('userTrigram') ?? '---');
    });
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
    if (!_isReady) {
      return Scaffold(
        appBar: CustomAppBar('${_trigram}_appGAP_Planning'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalWidth = _days.length * _cellWidth;

    return Scaffold(
      appBar: CustomAppBar('${_trigram}_appGAP_Planning'),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter un événement',
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
      ..._days.map(
            (day) => Container(
          width: _cellWidth,
          height: 50,
          alignment: Alignment.center,
          child: Text(DateFormat('dd/MM').format(day)),
        ),
      ),
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

        final canEdit = evt != null && _normTri(evt.user) == _trigram;

        return GestureDetector(
          onLongPress: canEdit ? () => _showEditDeleteDialog(context, evt!) : null,
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

    if (_savedHOffset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hCtrl.hasClients) return;
        final max = _hCtrl.position.maxScrollExtent;
        final target = _savedHOffset!.clamp(0.0, max);
        _hCtrl.jumpTo(target);
        _savedHOffset = null;
      });
      _jumped = true;
      return;
    }

    if (!_jumped && _selectedYear == DateTime.now().year) {
      final idx =
          DateTime.now().difference(DateTime(_selectedYear, 1, 1)).inDays;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _hCtrl.jumpTo(idx * _cellWidth));
      _jumped = true;
    }
  }

  // =========================
  // Ajout d’événements (+)
  // =========================

  void _showEventSelector(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          ...['TWR', 'CRM', 'BAR', 'PN', 'RU'].map(
                (e) => ListTile(
              title: Text(e),
              onTap: () {
                Navigator.pop(ctx);
                _showOneDayDialog(ctx, e);
              },
            ),
          ),
          ...['AST', 'DA', 'CA'].map(
                (e) => ListTile(
              title: Text(e),
              onTap: () {
                Navigator.pop(ctx);
                _showMultiDayPicker(ctx, e);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showOneDayDialog(BuildContext ctx, String type) {
    OneDayOption? choice;
    DateTime? custom;
    int twrRank = 1; // défaut

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setD) => AlertDialog(
          title: Text('Ajouter $type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (type == 'TWR') ...[
                const SizedBox(height: 4),
                const Text('Rang (n°)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [1, 2, 3].map((r) {
                    final selected = twrRank == r;
                    return ChoiceChip(
                      label: Text('n°$r'),
                      selected: selected,
                      onSelected: (_) => setD(() => twrRank = r),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
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
                  final now = DateTime.now();
                  final init = custom ?? DateTime(now.year, now.month, now.day);
                  final d = await showDatePicker(
                    context: ctx2,
                    initialDate: init,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setD(() => custom = d);
                  choice = OneDayOption.other;
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: choice == null ? null : () async {
                _savedHOffset = _hCtrl.hasClients ? _hCtrl.position.pixels : null;

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
                  rank: type == 'TWR' ? twrRank : null,
                );

                if (mounted) Navigator.pop(ctx2);
                await _preloadData();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_hCtrl.hasClients || _savedHOffset == null) return;
                  final max = _hCtrl.position.maxScrollExtent;
                  final target = _savedHOffset!.clamp(0.0, max);
                  _hCtrl.jumpTo(target);
                  _savedHOffset = null;
                });
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMultiDayPicker(BuildContext ctx, String type) async {
    _savedHOffset = _hCtrl.hasClients ? _hCtrl.position.pixels : null;

    final now = DateTime.now();
    final initial = DateTime(now.year, now.month, now.day);
    final range = await showDateRangePicker(
      context: ctx,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: initial, end: initial),
      helpText: 'Sélectionnez la période $type',
      saveText: 'Valider',
    );
    if (range == null) return;

    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end   = DateTime(range.end.year,   range.end.month,   range.end.day);

    await widget.dao.insertEvent(
      user: _trigram,
      typeEvent: type,
      dateStart: start,
      dateEnd: end,
    );

    await _preloadData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hCtrl.hasClients || _savedHOffset == null) return;
      final max = _hCtrl.position.maxScrollExtent;
      final target = _savedHOffset!.clamp(0.0, max);
      _hCtrl.jumpTo(target);
      _savedHOffset = null;
    });
  }

  // =========================
  // Éditer / Supprimer (long press)
  // =========================

  void _showEditDeleteDialog(BuildContext context, PlanningEvent e) {
    final isMulti = e.dateEnd.difference(e.dateStart).inDays > 0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Action sur ${e.typeEvent}'),
        content: Text(isMulti
            ? 'Modifier la période ou supprimer cet événement ?'
            : 'Modifier la date (et le rang si TWR) ou supprimer cet événement ?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (isMulti) {
                await _editMultiDayEvent(e);
              } else {
                await _editOneDayEvent(e);
              }
            },
            child: const Text('Éditer'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                if (e.firestoreId != null && e.firestoreId!.isNotEmpty) {
                  await widget.dao.deleteEventByFirestoreId(e.firestoreId!);
                }
              } catch (err) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Suppression refusée ou erreur: $err')),
                );
              }

              await _preloadData();

              if (_hCtrl.hasClients) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final max = _hCtrl.position.maxScrollExtent;
                  final target = (_hCtrl.position.pixels).clamp(0.0, max);
                  _hCtrl.jumpTo(target);
                });
              }
            },
            child: const Text('Supprimer'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ],
      ),
    );
  }

  Future<void> _editOneDayEvent(PlanningEvent e) async {
    DateTime selected = DateTime(e.dateStart.year, e.dateStart.month, e.dateStart.day);
    int twrRank = e.typeEvent == 'TWR' ? (e.rank ?? 1) : 1;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setD) => AlertDialog(
          title: Text('Éditer ${e.typeEvent}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (e.typeEvent == 'TWR') ...[
                const Text('Rang (n°)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [1, 2, 3].map((r) {
                    final sel = twrRank == r;
                    return ChoiceChip(
                      label: Text('n°$r'),
                      selected: sel,
                      onSelected: (_) => setD(() => twrRank = r),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              ListTile(
                title: Text('Date: ${DateFormat('dd/MM/yyyy').format(selected)}'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx2,
                    initialDate: selected,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setD(() => selected = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (e.firestoreId != null && e.firestoreId!.isNotEmpty) {
                    await widget.dao.updateEventByFirestoreId(
                      firestoreId: e.firestoreId!,
                      dateStart: selected,
                      dateEnd: selected,
                      rank: e.typeEvent == 'TWR' ? twrRank : null,
                    );
                  }
                } catch (err) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Modification refusée ou erreur: $err')),
                  );
                }
                Navigator.pop(ctx2);
                await _preloadData();
                if (_hCtrl.hasClients) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final max = _hCtrl.position.maxScrollExtent;
                    final target = (_hCtrl.position.pixels).clamp(0.0, max);
                    _hCtrl.jumpTo(target);
                  });
                }
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMultiDayEvent(PlanningEvent e) async {
    final start0 = DateTime(e.dateStart.year, e.dateStart.month, e.dateStart.day);
    final end0   = DateTime(e.dateEnd.year,   e.dateEnd.month,   e.dateEnd.day);

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: start0, end: end0),
      helpText: 'Modifier la période ${e.typeEvent}',
      saveText: 'Valider',
    );
    if (range == null) return;

    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end   = DateTime(range.end.year,   range.end.month,   range.end.day);

    try {
      if (e.firestoreId != null && e.firestoreId!.isNotEmpty) {
        await widget.dao.updateEventByFirestoreId(
          firestoreId: e.firestoreId!,
          dateStart: start,
          dateEnd: end,
        );
      }
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Modification refusée ou erreur: $err')),
      );
    }

    await _preloadData();
    if (_hCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final max = _hCtrl.position.maxScrollExtent;
        final target = (_hCtrl.position.pixels).clamp(0.0, max);
        _hCtrl.jumpTo(target);
      });
    }
  }
}
