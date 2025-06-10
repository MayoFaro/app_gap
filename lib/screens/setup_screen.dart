// lib/screens/setup_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/user_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';
/*
class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isChecking = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isChecking = true);
    final email = _emailController.text.trim();

    try {
      // Récupère les méthodes d'authentification déjà enregistrées pour cet email
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);

      if (methods.isEmpty) {
        // Nouvel utilisateur → on pousse vers l'écran d'enregistrement
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RegisterScreen(initialEmail: email)),
        );
      } else {
        // Utilisateur existant → on pousse vers l'écran de login
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LoginScreen(initialEmail: email)),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Si Gmail/MDP pas autorisé ou autre erreur
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Erreur Firebase'),
          content: Text(e.message ?? 'Erreur lors de la vérification de l’email.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
          ],
        ),
      );
    } finally {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Entrez votre email';
                  final emailRegEx = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!emailRegEx.hasMatch(v.trim())) return 'Email non valide';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _isChecking
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _onNext,
                child: const Text('Suivant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/