// lib/screens/organigramme_list.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/app_database.dart';

class OrganigrammeList extends StatelessWidget {
  final AppDatabase db;
  const OrganigrammeList({super.key, required this.db});

  Future<List<User>> _loadUsers() async {
    return await db.select(db.users).get();
  }

  void _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Impossible de lancer l’appel vers \$phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organigramme')),
      body: FutureBuilder<List<User>>(
        future: _loadUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('Aucun utilisateur'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final u = users[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(u.fullName ?? u.trigramme),
                subtitle: Text(u.role),
                trailing: IconButton(
                  icon: const Icon(Icons.phone),
                  onPressed: u.phone != null ? () => _callNumber(u.phone!) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
