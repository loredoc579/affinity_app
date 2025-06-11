import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:affinity_app/screens/home_screen.dart';

import 'auth_service.dart';   // contiene signInWithFacebook()

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void _login(BuildContext context) async {
    final email    = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Porta l’utente alla home e svuota lo stack di login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('🚨 Login failed: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login fallito: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Email / Password ────────────────────────────────────────────────
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _login(context),
              child: const Text("Login"),
            ),
            // ─────────────────────────────────────────────────────────────────────
            const Divider(height: 40),
            // ── Facebook ────────────────────────────────────────────────────────
            SignInButton(
                Buttons.facebook,
                text: "Facebook login",
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final user = await getAuthService().signInWithFacebook(); 
                    if (user != null) {
                      // Sostituisci lo stack con la HomeScreen
                      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(content: Text("Login fallito: utente nullo")),
                      );
                    }
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text("Login Facebook fallito: $e")),
                    );
                  }
                },
              ),

            // ─────────────────────────────────────────────────────────────────────
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              child: const Text("Non hai un account? Registrati"),
            ),
          ],
        ),
      ),
    );
  }
}
