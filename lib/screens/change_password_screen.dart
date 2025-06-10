
// lib/screens/change_password_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen to change existing password or switch user
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPwdController = TextEditingController();
  final _newPwdController = TextEditingController();

  Future<void> _changePassword() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('userPwd');
    if (_oldPwdController.text != stored) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ancien mot de passe incorrect')),
      );
      return;
    }
    await prefs.setString('userPwd', _newPwdController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mot de passe mis à jour')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _switchUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isConfigured', false);
    Navigator.of(context).pushReplacementNamed('/setup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _oldPwdController,
                decoration: const InputDecoration(labelText: 'Ancien mot de passe'),
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _newPwdController,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _changePassword,
                child: const Text('Modifier le mot de passe'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _switchUser,
                child: const Text('Changer d’utilisateur'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
