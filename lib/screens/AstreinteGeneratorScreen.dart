// lib/screens/AstreinteGeneratorScreen.dart
//
// Écran de génération/commit/RAZ des astreintes.
// - Sélection période (dd/MM/yy), saisie JF supplémentaires (CSV dd/MM/yyyy)
// - Bouton DEBUG (ex: DPS) : baseline + indispos sur la plage
// - Génération jusqu’à 3 propositions, affichage clair (semaines → couples)
// - Bouton "Valider cette proposition" → écrit les AST (sans écraser les cases)
// - Bouton "RAZ AST sur la période" → trim/supprime tous les AST sur la plage
//
// Dépend de : AstreinteEngine (services/astreinte_engine.dart)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../data/planning_dao.dart';
import '../services/astreinte_engine.dart';
import '../services/jours_feries_provider.dart';

// dans l'état
final JoursFeriesProvider _jf = JoursFeriesProvider.gabonDefaults2025();

Map<String, int> _yearTotals = {};


class AstreinteGeneratorScreen extends StatefulWidget {
  final AppDatabase db;
  final PlanningDao planningDao;

  const AstreinteGeneratorScreen({
    Key? key,
    required this.db,
    required this.planningDao,
  }) : super(key: key);

  @override
  State<AstreinteGeneratorScreen> createState() => _AstreinteGeneratorScreenState();
}

class _AstreinteGeneratorScreenState extends State<AstreinteGeneratorScreen> {
  late final AstreinteEngine _engine;

  final _extraJfController = TextEditingController();
  final _fmt = DateFormat('dd/MM/yyyy');
  Map<String, int> _yearTotals = {};


  Future<void> _refreshYearTotals() async {
    if (_pilotes.isEmpty) return;
    final totals = await _engine.computeFullYearWeJfCounts(
      pilotes: _pilotes,
      year: 2025,
    );
    if (!mounted) return;
    setState(() => _yearTotals = totals);
  }


  DateTime _start = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _end   = DateTime(DateTime.now().year, DateTime.now().month, 1)
      .add(const Duration(days: 90));

  bool _loading = false;
  List<String> _pilotes = [];
  List<AstreinteProposal> _proposals = [];

  @override
  void initState() {
    super.initState();

    _engine = AstreinteEngine(
      planningDao: widget.planningDao,
      // Union des JF "fixes" 2025 + JF saisis dans l'UI, bornés à la plage demandée.
      joursFeriesProvider: (from, to) async {
        final fixed = _jf.getForRange(from, to); // Set<DateTime>
        final extras = _parseExtraJf(_extraJfController.text)
            .where((d) => !d.isBefore(from) && !d.isAfter(to))
            .map((d) => DateTime(d.year, d.month, d.day));
        return {...fixed, ...extras}.toList();
      },
    );

    _loadPilotesAvion();
  }


  Future<void> _loadPilotesAvion() async {
    final rows = await widget.db.select(widget.db.users).get();
    final tris = rows
        .where((u) =>
    (u.group.toLowerCase() == 'avion') &&
        (u.role.toLowerCase() == 'pilote'))
        .map((u) => u.trigramme.trim().toUpperCase())
        .where((t) => t.length == 3)
        .toSet()
        .toList()
      ..sort();

    if (!mounted) return;
    setState(() => _pilotes = tris);

    // maintenant que _pilotes est à jour, calcule les totaux annuels
    await _refreshYearTotals();
  }


  List<DateTime> _parseExtraJf(String raw) {
    final out = <DateTime>[];
    if (raw.trim().isEmpty) return out;
    for (final token in raw.split(',')) {
      final t = token.trim();
      try {
        final d = _fmt.parseStrict(t);
        out.add(DateTime(d.year, d.month, d.day));
      } catch (_) {/* ignore */}
    }
    return out;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initStart = _start;
    final initEnd   = _end.isBefore(_start) ? _start : _end;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: initStart, end: initEnd),
      helpText: 'Sélectionnez la période (semaines LUN→DIM)',
      saveText: 'Valider',
    );
    if (range == null) return;

    setState(() {
      _start = DateTime(range.start.year, range.start.month, range.start.day);
      _end   = DateTime(range.end.year,   range.end.month,   range.end.day);
    });
  }

  Future<void> _onDebugDPS() async {
    setState(() => _loading = true);
    try {
      await _engine.debugDumpPilotReads(
        trigramme: 'DPS',
        from: _start, // ✅ au lieu de DateTime(2025,1,1)
        to: _end,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log debug "DPS" envoyé dans Logcat.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('DEBUG erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<void> _onGenerate() async {
    setState(() => _loading = true);
    try {
      final inputs = AstreinteInputs(
        start: _start,
        end: _end,
        extraJoursFeries: _parseExtraJf(_extraJfController.text),
        chefExclusionsByWeek: const {}, // (UI exclusions à venir)
      );

      final props = await _engine.generateProposals(
        pilotesTrigrammes: _pilotes,
        inputs: inputs,
        maxSolutions: 3,
      );

      setState(() => _proposals = props);
    } catch (e) {
      setState(() => _proposals = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Génération impossible: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onCommit(AstreinteProposal p) async {
    setState(() => _loading = true);
    try {
      await _engine.commitProposal(chosen: p);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Astreintes enregistrées.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Écriture impossible: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRaz() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('RAZ AST'),
        content: Text('Supprimer/recadrer toutes les AST du ${DateFormat('dd/MM/yy').format(_start)} au ${DateFormat('dd/MM/yy').format(_end)} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _engine.razAstInRange(start: _start, end: _end);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RAZ effectuée.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('RAZ impossible: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _extraJfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM');

    return Scaffold(
      appBar: AppBar(title: const Text('Générateur d’astreintes (avion)')),
      body: Column(
        children: [
          _buildControls(fmt),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildProposals(fmt)),
        ],
      ),
    );
  }

  Widget _buildControls(DateFormat fmt) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Période :  ', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${fmt.format(_start)} → ${fmt.format(_end)}'),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: const Text('Changer'),
                onPressed: _pickRange,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _onDebugDPS,
                icon: const Icon(Icons.bug_report),
                label: const Text('Debug DPS'),
              ),
            ],
          ),//
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('JF en plus (CSV dd/MM/yyyy) : '),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _extraJfController,
                  decoration: const InputDecoration(
                    hintText: 'ex: 01/11/2025, 25/12/2025',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _onGenerate,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Générer (3)'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _onRaz,
                icon: const Icon(Icons.delete_forever),
                label: const Text('RAZ AST'),
              ),
            ],
          ),
          // Sous le Row des contrôles (JF / Générer / RAZ), ajoute :
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: -6,
              children: _pilotes.map((t) {
                final n = _yearTotals[t] ?? 0;
                return Chip(label: Text('$t $n')); // <-- bilan 2025 actuel
              }).toList(),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildProposals(DateFormat fmt) {
    if (_proposals.isEmpty) {
      return const Center(child: Text('Aucune proposition. Lance une génération.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _proposals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, idx) {
        final p = _proposals[idx];
        final weeks = p.assignment.keys.toList()
          ..sort((a, b) => a.monday.compareTo(b.monday));

        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(label: Text('Score: ${p.score.toStringAsFixed(2)}')),
                    // Les chips TRI total(+delta)
                    ...p.deltaCriticalDaysByPilot.entries.map((e) {
                      final base = _yearTotals[e.key] ?? 0;
                      final tot  = base + e.value;
                      return Chip(label: Text('${e.key} $tot(+${e.value})'));
                    }),
                    // Le bouton peut passer à la ligne si nécessaire
                    ElevatedButton.icon(
                      onPressed: () => _onCommit(p),
                      icon: const Icon(Icons.check),
                      label: const Text('Valider cette proposition'),
                    ),
                  ],
                ),

                const Divider(),
                Column(
                  children: weeks.map((w) {
                    final pair = p.assignment[w]!;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.calendar_month),
                      title: Text('Semaine ${fmt.format(w.monday)} → ${fmt.format(w.sunday)}'),
                      trailing: Text('${pair.$1} / ${pair.$2}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
