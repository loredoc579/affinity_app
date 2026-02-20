// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';

import '../widgets/heart_progress_indicator.dart';
import 'profile_preview_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final emailController = TextEditingController();
  final _jobController = TextEditingController();
  final _bioController = TextEditingController();
  String _city = 'Caricamento...';
  List<String> _selectedHobbies = [];
  final List<String> _availableHobbies = [
    'Viaggi', 'Sport', 'Palestra', 'Musica', 'Cinema', 
    'Lettura', 'Videogiochi', 'Cucina', 'Animali', 'Arte'
  ];
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
      
      if (!doc.exists) return; 

      final data = doc.data();
      final fbPhoto = data?['photoUrl'] as String?;
      final urls = data?['photoUrls'] as List<dynamic>?;

      if (!mounted) return;

      setState(() {
        nameController.text = data?['name'] ?? '';       
        ageController.text = data?['age']?.toString() ?? '';        
        emailController.text = data?['email'] ?? user!.email ?? '';
        _jobController.text = data?['jobTitle'] ?? '';
        _bioController.text = data?['bio'] ?? '';
        _city = (data?['location'] as Map<String, dynamic>?)?['city'] as String? ?? 'Sconosciuta';
        
        final fetchedHobbies = data?['hobbies'];
        if (fetchedHobbies is List) {
          _selectedHobbies = List<String>.from(fetchedHobbies);
        } else {
          _selectedHobbies = [];
        }

        if (urls != null && urls.isNotEmpty) {
           photoUrls = List<String?>.filled(9, null);
           for (int i = 0; i < urls.length && i < 9; i++) {
             photoUrls[i] = urls[i] as String?;
           }
        } else {
          photoUrls = List<String?>.filled(9, null);
          if (fbPhoto != null && fbPhoto.isNotEmpty) {
            photoUrls[0] = fbPhoto;
          }
        }
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Errore caricamento profilo: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> saveProfile() async {
    if (user == null) return;
    setState(() => isLoading = true);
    
    // --- CRITICAL FIX: Convert age back to Integer for Firestore ---
    int? ageInt = int.tryParse(ageController.text);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({
        'name': nameController.text.trim(),
        'age': ageInt ?? 18,
        'email': emailController.text.trim(), 
        'photoUrls': photoUrls,
        'jobTitle': _jobController.text.trim(),
        'bio': _bioController.text.trim(),
        'hobbies': _selectedHobbies, 
      }, SetOptions(merge: true));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profilo salvato con successo!"))
      );
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore salvataggio: $e"))
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> pickImage(int index) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    
    setState(() => isLoading = true);

    try {
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
      
      // 1. NOME UNIVOCO: Usiamo i millisecondi così le foto non si sovrascrivono mai!
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref().child('users/${user!.uid}/photo_$uniqueId.jpg');
      
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final newUrl = await ref.getDownloadURL();

      // 2. SOSTITUZIONE: Se c'era già una foto, la cancelliamo dallo storage e dalla cache
      if (photoUrls[index] != null) {
        final oldUrl = photoUrls[index]!;
        await CachedNetworkImageProvider(oldUrl).evict();
        try {
          await FirebaseStorage.instance.refFromURL(oldUrl).delete();
        } catch (e) {
          debugPrint("Il vecchio file era già stato rimosso");
        }
      }

      setState(() => photoUrls[index] = newUrl);

      // 3. AGGIORNAMENTO FIRESTORE
      Map<String, dynamic> updates = {'photoUrls': photoUrls};
      if (index == 0) updates['photoUrl'] = newUrl;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set(updates, SetOptions(merge: true));
          
    } catch (e) {
      debugPrint("Errore upload foto: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> removeImage(int index) async {
    if (photoUrls[index] == null || user == null) return;
    setState(() => isLoading = true);
    
    try {
      final urlToDelete = photoUrls[index]!;
      
      // 1. Svuota la cache e rimuovi la foto da Firebase Storage usando direttamente il link!
      await CachedNetworkImageProvider(urlToDelete).evict();
      try {
        await FirebaseStorage.instance.refFromURL(urlToDelete).delete();
      } catch(e) {
        debugPrint("Foto assente sullo storage");
      }
      
      photoUrls[index] = null;

      // 2. LA MAGIA: Compattiamo l'array! (Shifting)
      // Prendiamo solo le foto valide rimaste e le spingiamo tutte verso sinistra
      List<String> fotoValide = photoUrls.whereType<String>().toList();
      
      // Ricreiamo l'array vuoto da 9 posti e lo riempiamo in ordine
      photoUrls = List<String?>.filled(9, null);
      for (int i = 0; i < fotoValide.length; i++) {
        photoUrls[i] = fotoValide[i];
      }

      // 3. Aggiorniamo Firestore
      Map<String, dynamic> updates = {'photoUrls': photoUrls};
      
      // Aggiorniamo l'avatar. Se fotoValide è vuoto, metterà una stringa vuota ('')
      updates['photoUrl'] = photoUrls[0] ?? '';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set(updates, SetOptions(merge: true));
          
    } catch (e) {
      debugPrint("Errore eliminazione foto: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: HeartProgressIndicator());
    }
    return SingleChildScrollView(
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
                                  image: CachedNetworkImageProvider(url),
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
                  if (url != null) ...[
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
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          TextField(
            controller: TextEditingController(text: _city),
            readOnly: true,
            style: const TextStyle(color: Colors.grey),
            decoration: const InputDecoration(
              labelText: 'Città Attuale',
              prefixIcon: Icon(Icons.location_on, color: Colors.grey),
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Nome"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Età"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _jobController,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: "Professione",
              hintText: "Es. Software Engineer",
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: "Bio",
              hintText: "Raccontaci qualcosa di te...",
              alignLabelWithHint: true,
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('I tuoi Hobbies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _availableHobbies.map((hobby) {
              final isSelected = _selectedHobbies.contains(hobby);
              return FilterChip(
                label: Text(hobby),
                selected: isSelected,
                selectedColor: Colors.pink.shade100,
                checkmarkColor: Colors.pink,
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      if (_selectedHobbies.length < 5) _selectedHobbies.add(hobby);
                    } else {
                      _selectedHobbies.remove(hobby);
                    }
                  });
                },
              );
            }).toList(),
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
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.remove_red_eye, color: Colors.pink),
            label: const Text(
              "Vedi come appari agli altri", 
              style: TextStyle(color: Colors.pink)
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.pink),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
            ),
            onPressed: () {
              if (user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePreviewScreen(uid: user!.uid),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 24), // Spazio extra in fondo
        ],
      ),
    );
  }
}
