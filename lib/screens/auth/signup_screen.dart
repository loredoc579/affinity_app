import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

  void _signup(BuildContext context) async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // 1. Creiamo l'utente su Firebase Auth (Email/Password)
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      // 2. CREIAMO IL DOCUMENTO SU FIRESTORE (Fondamentale per la tua app!)
      // Senza questo, getProfiles e la Home andranno in crash.
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': 'Nuovo Utente',     // Nome di default
        'age': 18,                  // Età minima di default
        'gender': 'male',           // Default (dovresti mettere un selettore nella UI)
        'bio': 'Ciao, sono nuovo qui!',
        'jobTitle': '',
        'hobbies': '',              // Stringa vuota o lista vuota
        'photoUrls': [],            // Lista vuota (gestita dai tuoi SafeAvatar)
        'photoUrl': '',             // Per compatibilità
        'location': {
          'city': 'Sconosciuta',
          'position': const GeoPoint(0, 0), // Posizione nulla (il GPS la aggiornerà dopo)
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Tutto ok, andiamo alla Home
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }

    } catch (e) {
      print('Errore Signup: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrazione")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: () => _signup(context),
                  child: const Text("Registrati"),
                ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Torna al login
              },
              child: const Text("Hai già un account? Login"),
            )
          ],
        ),
      ),
    );
  }
}