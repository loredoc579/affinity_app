import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

import './auth/auth_service.dart';

// Import del HeartProgressIndicator personalizzato
import '../widgets/heart_progress_indicator.dart';

class ProfileScreen extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController hobbiesController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  // Lista di URL per le 9 foto
  List<String?> photoUrls = List<String?>.filled(9, null);
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      final data = doc.data();
      // Recupero foto importata da Facebook se presente
      final fbPhoto = data?['photoUrl'] as String?;
      final urls = data?['photoUrls'] as List<dynamic>?;
      setState(() {
        nameController.text = data?['name'] ?? '';
        ageController.text = data?['age'] ?? '';
        hobbiesController.text = data?['hobbies'] ?? '';
        emailController.text = data?['email'] ?? user!.email ?? '';
        // Se ci sono già 9 URL salvati, li uso
        if (urls != null && urls.length >= 9) {
          photoUrls = urls.map((e) => e as String?).toList();
        } else {
          // Altrimenti inizializzo la lista e, se c'è la foto FB, la metto come principale
          photoUrls = List<String?>.filled(9, null);
          if (fbPhoto != null && fbPhoto.isNotEmpty) {
            photoUrls[0] = fbPhoto;
          }
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> saveProfile() async {
    if (user == null) return;
    setState(() => isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({
        'name': nameController.text,
        'age': ageController.text,
        'hobbies': hobbiesController.text,
        'email': emailController.text,
        'photoUrls': photoUrls,
      }, SetOptions(merge: true));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> pickImage(int index) async {
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
        minWidth: 512,
        minHeight: 512,
        quality: 80,
        format: CompressFormat.jpeg,
      );
    }
    final ref = FirebaseStorage.instance
        .ref()
        .child('users/${user!.uid}/photo_$index.jpg');
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();
    setState(() => photoUrls[index] = url);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .set({'photoUrls': photoUrls}, SetOptions(merge: true));
  }

  Future<void> removeImage(int index) async {
    if (photoUrls[index] == null || user == null) return;
    setState(() => isLoading = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('users/${user!.uid}/photo_$index.jpg');
      await ref.delete();
      photoUrls[index] = null;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({'photoUrls': photoUrls}, SetOptions(merge: true));
    } catch (e) {
      // gestisci errori
    } finally {
      setState(() => isLoading = false);
    }
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
              await signOut();
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: HeartProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 9,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final url = photoUrls[index];
                      final bool isMain = index == 0;
                      return Stack(
                        children: [
                          GestureDetector(
                            onTap: () => pickImage(index),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isMain
                                        ? Colors.green
                                        : Theme.of(context).primaryColor,
                                    width: isMain ? 3 : 2,
                                  ),
                                  image: url != null
                                      ? DecorationImage(
                                          image: NetworkImage(url),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: url == null
                                    ? const Center(
                                        child: Icon(
                                          Icons.add_a_photo,
                                          size: 36,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          if (url != null)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => removeImage(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          if (isMain)
                            Positioned(
                              bottom: 4,
                              left: 0,
                              right: 0,
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                color: Colors.green.withOpacity(0.7),
                                child: const Text(
                                  'Principale',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Nome"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ageController,
                    decoration: const InputDecoration(labelText: "Età"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hobbiesController,
                    decoration: const InputDecoration(labelText: "Passioni"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: "Email"),
                  ),
                  const SizedBox(height: 24),
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
