// lib/screens/tripfuel_screen.dart
import 'package:flutter/material.dart';
import '../data/app_database.dart';

class TripFuelScreen extends StatefulWidget {
  final AppDatabase db;
  const TripFuelScreen({super.key, required this.db});

  @override
  State<TripFuelScreen> createState() => _TripFuelScreenState();
}

class Leg {
  String? from;
  String? to;
  int durationMinutes;
  Leg({this.from, this.to, this.durationMinutes = 0});
}

class _TripFuelScreenState extends State<TripFuelScreen> {
  final List<Leg> _legs = [Leg()];
  List<Airport> _airports = []; //The name 'Airport' isn't a type, so it can't be used as a type argument.
  int _totalMinutes = 0;
  double _totalFuel = 0;

  @override
  void initState() {
    super.initState();
    _loadAirports();
  }

  Future<void> _loadAirports() async {
    _airports = await widget.db.select(widget.db.airports).get();
    setState(() {});
  }

  void _addLeg() {
    setState(() {
      final previousDestination = _legs.isNotEmpty ? _legs.last.to : null;
      _legs.add(Leg(from: previousDestination));
    });
  }

  void _calculateTotals() {
    _totalMinutes = _legs.fold(0, (sum, leg) => sum + leg.durationMinutes);
    _totalFuel = _totalMinutes * 10.0; // Exemple de consommation
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calcul Carburant')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _legs.length,
                itemBuilder: (context, index) {
                  final leg = _legs[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: leg.from,
                              items: _airports
                                  .map((a) => DropdownMenuItem(
                                value: a.code,
                                child: Text(a.code),
                              ))
                                  .toList(),
                              onChanged: (v) => setState(() => leg.from = v),
                              decoration: const InputDecoration(labelText: 'Départ'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: leg.to,
                              items: _airports
                                  .map((a) => DropdownMenuItem(
                                value: a.code,
                                child: Text(a.code),
                              ))
                                  .toList(),
                              onChanged: (v) => setState(() => leg.to = v),
                              decoration: const InputDecoration(labelText: 'Destination'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              initialValue: leg.durationMinutes.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Min'),
                              onChanged: (v) => setState(() => leg.durationMinutes = int.tryParse(v) ?? 0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _addLeg,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter étape'),
                ),
                ElevatedButton(
                  onPressed: _calculateTotals,
                  child: const Text('Calculer'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Durée totale : $_totalMinutes minutes'),
            Text('Carburant total : ${_totalFuel.toStringAsFixed(1)} L'),
          ],
        ),
      ),
    );
  }
}
