// lib/screens/planning_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value; // pour Value
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/app_database.dart';
import '../data/planning_dao.dart';

/// Affiche un calendrier mensuel pour l'utilisateur connecté avec coloration par type d'événement
class PlanningCalendarScreen extends StatefulWidget {
  final AppDatabase db;
  const PlanningCalendarScreen({super.key, required this.db});

  @override
  State<PlanningCalendarScreen> createState() => _PlanningCalendarScreenState();
}

class _PlanningCalendarScreenState extends State<PlanningCalendarScreen> {
  late final PlanningDao _dao;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  List<int> _years = [];
  List<DateTime> _daysInMonth = [];
  List<User> _users = [];
  Map<String, Map<int, PlanningEvent>> _events = {}; // user -> day -> event
  String? _currentUser;

  @override
  void initState() {
    super.initState();
    _dao = PlanningDao(widget.db);
    _initYears();
    _loadCurrentUser().then((_) => _loadData());
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _currentUser = prefs.getString('userTrigram'));
  }

  void _initYears() {
    final current = DateTime.now().year;
    _years = [for (var y = 2021; y <= current + 1; y++) y];
  }

  Future<void> _loadData() async {
    final lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    _daysInMonth = [for (var d = 1; d <= lastDay; d++) DateTime(_selectedYear, _selectedMonth, d)];

    final users = await widget.db.select(widget.db.users).get();
    final allEvents = await _dao.getAllEvents();

    final monthEvents = allEvents.where((e) {
      final start = e.dateStart;
      final end = e.dateEnd;
      return (start.year == _selectedYear && start.month == _selectedMonth) ||
          (end.year == _selectedYear && end.month == _selectedMonth) ||
          (start.isBefore(DateTime(_selectedYear, _selectedMonth, 1)) &&
              end.isAfter(DateTime(_selectedYear, _selectedMonth, lastDay)));
    });

    final map = <String, Map<int, PlanningEvent>>{};
    for (var u in users) {
      map[u.trigramme] = {};
    }
    for (var e in monthEvents) {
      final start = e.dateStart;
      final end = e.dateEnd;
      final from = (start.year == _selectedYear && start.month == _selectedMonth) ? start.day : 1;
      final to = (end.year == _selectedYear && end.month == _selectedMonth) ? end.day : lastDay;
      for (var day = from; day <= to; day++) {
        map[e.user]?[day] = e;
      }
    }

    setState(() {
      _users = users;
      _events = map;
    });
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'ST': return Colors.blue.shade200;
      case 'BAR': return Colors.green.shade200;
      case 'CRM': return Colors.orange.shade200;
      case 'RU': return Colors.purple.shade200;
      case 'AST': return Colors.red.shade200;
      case 'DA': return Colors.grey.shade400;
      case 'CA': return Colors.yellow.shade200;
      default: return Colors.white;
    }
  }

  String _labelFor(String? type) => type ?? '';

  Future<void> _onAddEvent() async {
    if (_currentUser == null) return;
    DateTime dateStart = DateTime(_selectedYear, _selectedMonth, DateTime.now().day);
    DateTime? dateEnd;
    String selectedType = 'ST';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setState2) {
            final multiDay = ['AST', 'DA', 'CA'].contains(selectedType);
            return AlertDialog(
              title: const Text('Ajouter un événement'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    items: const [
                      DropdownMenuItem(value: 'ST', child: Text('ST')),
                      DropdownMenuItem(value: 'BAR', child: Text('BAR')),
                      DropdownMenuItem(value: 'CRM', child: Text('CRM')),
                      DropdownMenuItem(value: 'RU', child: Text('RU')),
                      DropdownMenuItem(value: 'AST', child: Text('AST')),
                      DropdownMenuItem(value: 'DA', child: Text('DA')),
                      DropdownMenuItem(value: 'CA', child: Text('CA')),
                    ],
                    onChanged: (v) => setState2(() {
                      selectedType = v!;
                      if (!multiDay) dateEnd = null;
                    }),
                    decoration: const InputDecoration(labelText: 'Type d’événement'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text('Date: ${DateFormat.yMd().format(dateStart)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final dt = await showDatePicker(
                        context: ctx2,
                        initialDate: dateStart,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (dt != null) setState2(() => dateStart = dt);
                    },
                  ),
                  if (multiDay) ...[
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text('Fin: ${DateFormat.yMd().format(dateEnd ?? dateStart)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final dt = await showDatePicker(
                          context: ctx2,
                          initialDate: dateEnd ?? dateStart,
                          firstDate: dateStart,
                          lastDate: DateTime(2100),
                        );
                        if (dt != null) setState2(() => dateEnd = dt);
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx2).pop(), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: () async {
                    // Détermination de la plage de jours
                    final from = dateStart.day;
                    final to = multiDay ? (dateEnd?.day ?? dateStart.day) : dateStart.day;

                    // Récupérer les events existants pour l'utilisateur
                    final existing = _events[_currentUser] ?? {};
                    final overlapDays = <int>[];
                    for (var d = from; d <= to; d++) {
                      if (existing.containsKey(d)) overlapDays.add(d);
                    }
                    // Si chevauchement, demander confirmation
                    if (overlapDays.isNotEmpty) {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx3) => AlertDialog(
                            title: const Text('Conflit d\'événements'),
                            content: Text('Il existe déjà un événement sur les jours suivants : ${overlapDays.join(", ")}.Voulez-vous les remplacer ?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx3).pop(false),
                            child: const Text('Annuler'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx3).pop(true),
                            child: const Text('Remplacer'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) {
                    return;
                    }
                    // Supprimer les events existants sur ces jours
                    for (var day in overlapDays) {
                    final evt = existing[day]!;
                    await _dao.deleteEvent(evt.id);
                    }
                    }
                    // Insérer le nouvel événement
                    final entry = PlanningEventsCompanion.insert(
                    user: _currentUser!,
                    dateStart: dateStart,
                    dateEnd: dateEnd ?? dateStart,
                    typeEvent: selectedType,
                    description: const Value(''),
                    );
                    await _dao.insertEvent(entry);
                    Navigator.of(ctx2).pop();
                    _loadData();
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning Mensuel'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(width: 16),
              DropdownButton<int>(
                value: _selectedYear,
                items: _years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                onChanged: (v) => setState(() { _selectedYear = v!; _loadData(); }),
              ),
              const SizedBox(width: 16),
              DropdownButton<int>(
                value: _selectedMonth,
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(value: m, child: Text(DateFormat.MMMM().format(DateTime(0, m)))))
                    .toList(),
                onChanged: (v) => setState(() { _selectedMonth = v!; _loadData(); }),
              ),
            ],
          ),
        ),
      ),
      body: _users.isEmpty
          ? const Center(child: Text('Aucun utilisateur'))
          : Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: 120),
                  for (var d in _daysInMonth)
                    Container(
                      width: 40,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(4),
                      child: Text('${d.day}'),
                    ),
                ],
              ),
              for (var u in _users)
                Row(
                  children: [
                    Container(
                      width: 120,
                      padding: const EdgeInsets.all(4),
                      child: Text(u.trigramme),
                    ),
                    for (var d in _daysInMonth)
                      (() {
                        final evt = _events[u.trigramme]?[d.day];
                        final type = evt?.typeEvent;
                        return GestureDetector(
                          onTap: () async {
                            if (evt != null) {
                              final action = await showDialog<String>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Événement'),
                                  content: Text(
                                    'Type: ${evt.typeEvent}\nDu: ${DateFormat.yMd().format(evt.dateStart)}${evt.dateEnd != evt.dateStart
                                        ? '\nAu: ${DateFormat.yMd().format(evt.dateEnd)}'
                                        : ''}',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop('delete'),
                                      child: const Text('Supprimer'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: const Text('Annuler'),
                                    ),
                                  ],
                                ),
                              );
                              if (action == 'delete') {
                                await _dao.deleteEvent(evt.id);
                                _loadData();
                              }
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 32,
                            margin: const EdgeInsets.all(1),
                            color: _colorFor(type),
                            alignment: Alignment.center,
                            child: Text(
                              _labelFor(type),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        );
                      })(),
                  ],
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddEvent,
        child: const Icon(Icons.add),
      ),
    );
  }
}
