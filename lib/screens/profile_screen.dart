import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

class ProfileScreen extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController hobbiesController = TextEditingController();

  String? profileImageUrl;
  String? email;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final data = doc.data();
    setState(() {
      nameController.text    = data?['name']    ?? '';
      ageController.text     = data?['age']     ?? '';
      hobbiesController.text = data?['hobbies'] ?? '';
      email                  = data?['email']   ?? user!.email;
      final url = data?['photoUrl'] as String?;
      profileImageUrl = (url != null && url.isNotEmpty) ? url : null;
    });
  }

  Future<void> saveProfile() async {
    if (user == null) return;
    setState(() => isLoading = true);
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'name': nameController.text,
      'age': ageController.text,
      'hobbies': hobbiesController.text,
      'email': email,
      'photoUrl': profileImageUrl ?? '',
    }, SetOptions(merge: true));
    setState(() => isLoading = false);
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    Uint8List bytes;
    if (kIsWeb) {
      bytes = await picked.readAsBytes();
    } else {
      final raw = await picked.readAsBytes();
      bytes = await FlutterImageCompress.compressWithList(
        raw,
        minWidth: 256,
        minHeight: 256,
        quality: 75,
        format: CompressFormat.jpeg,
      );
    }
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_images/${user!.uid}.jpg');
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();
    setState(() => profileImageUrl = url);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .set({'photoUrl': url}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profilo"),
        leading: BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // 1) Controlla se esiste un token FB
              final fb = FacebookAuth.instance;
              final tokenData = await fb.accessToken;
              if (tokenData != null) {
                // Se c’è, invalida la sessione sul JS SDK
                await fb.logOut();
              }

              // 2) Effettua sempre il logout da Firebase Auth
              await FirebaseAuth.instance.signOut();

              // 3) Torna al login (ripulendo la history)
              if (!mounted) return;
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: profileImageUrl != null
                          ? NetworkImage(profileImageUrl!)
                          : null,
                      child: profileImageUrl == null
                          ? const Icon(Icons.add_a_photo, size: 32)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Nome"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ageController,
                    decoration: const InputDecoration(labelText: "Età"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hobbiesController,
                    decoration: const InputDecoration(labelText: "Passioni"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: email ?? ''),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "Email",
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: saveProfile,
                    child: const Text("Salva"),
                  ),
                ],
              ),
            ),
    );
  }
}
