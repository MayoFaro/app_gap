// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_service.dart';
import '../data/app_database.dart';
import 'home_screen.dart';
/*
class RegisterScreen extends StatefulWidget {
  final String initialEmail;
  const RegisterScreen({Key? key, required this.initialEmail}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = widget.initialEmail.trim();
    final psw = _passwordController.text.trim();

    try {
      // Création du compte Firebase
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: psw,
      );

      // Récupère le profil JSON correspondant à l’email
      final userInfo = await UserService.findByEmail(email);
      if (userInfo == null) {
        // Improbable si JSON ne contient pas l’email fournie
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Erreur'),
            content: const Text('Aucun profil utilisateur associé à cet email.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
            ],
          ),
        );
        await FirebaseAuth.instance.currentUser?.delete();
        return;
      }

      // Stocke en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userTrigram', userInfo.trigramme);
      await prefs.setString('userGroup', userInfo.group);

      // Redirection vers HomeScreen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            db: AppDatabase(),
            userTrigram: userInfo.trigramme,
            userGroup: userInfo.group,
            isAdmin: userInfo.isAdmin,
          ),
        ),
            (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'Le mot de passe est trop faible';
      } else if (e.code == 'email-already-in-use') {
        message = 'Cet email est déjà utilisé';
      } else {
        message = e.message ?? 'Erreur lors de la création du compte';
      }
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Erreur'),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
          ],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Email : ${widget.initialEmail}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Entrez un mot de passe';
                  if (v.length < 6) return 'Doit faire au moins 6 caractères';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                decoration: const InputDecoration(labelText: 'Confirmez mot de passe'),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirmez votre mot de passe';
                  if (v != _passwordController.text) return 'Les mots de passe ne correspondent pas';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(onPressed: _onRegister, child: const Text('Créer le compte')),
            ],
          ),
        ),
      ),
    );
  }
}
*/