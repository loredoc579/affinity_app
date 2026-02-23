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
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../widgets/heart_progress_indicator.dart';
import 'profile_preview_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class PromptEntry {
  String question;
  TextEditingController controller;
  PromptEntry({required this.question, required String answer}) 
      : controller = TextEditingController(text: answer);
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
  final _songController = TextEditingController();
  final _promptAnswerController = TextEditingController();
  List<PromptEntry> _promptsList = [];
  final List<String> _availablePrompts = [
    'Due verità e una bugia...',
    'Il mio talento inutile è...',
    'La domenica perfetta per me è...',
    'Non potrei mai vivere senza...',
    'Il mio peggior appuntamento è stato...'
  ];
  List<String?> photoUrls = List<String?>.filled(9, null, growable: true);
  bool isLoading = true;

  // --- CALCOLO COMPLETEZZA (Spaccato a 100) ---
  int _calculateCompleteness() {
    int score = 0;
    if (nameController.text.trim().isNotEmpty) score += 5;
    if (ageController.text.trim().isNotEmpty) score += 5;
    if (_jobController.text.trim().isNotEmpty) score += 10;
    if (_bioController.text.trim().length > 10) score += 15; 
    if (_selectedHobbies.isNotEmpty) score += 5;
    if (_selectedHobbies.length >= 3) score += 5; 
    if (_songController.text.trim().isNotEmpty) score += 5;

    if (photoUrls.any((url) => url != null)) score += 20; 

    // Aggiunge 10 punti per OGNI prompt compilato (max 30)
    for (var p in _promptsList) {
      if (p.question.isNotEmpty && p.controller.text.trim().isNotEmpty) {
        score += 10; 
      }
    }
    return score.clamp(0, 100);
  }

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

        // --- CARICA ICEBREAKER ---
        _songController.text = data?['favoriteSong'] ?? '';
        final savedPrompts = data?['prompts'];
        if (savedPrompts is List) {
          _promptsList = savedPrompts.map((p) => PromptEntry(
            question: p['question']?.toString() ?? '',
            answer: p['answer']?.toString() ?? ''
          )).toList();
        } else {
          _promptsList = [];
        }
        
        final fetchedHobbies = data?['hobbies'];
        if (fetchedHobbies is List) {
          _selectedHobbies = List<String>.from(fetchedHobbies);
        } else {
          _selectedHobbies = [];
        }

        if (urls != null && urls.isNotEmpty) {
           photoUrls = List<String?>.filled(9, null, growable: true);
           for (int i = 0; i < urls.length && i < 9; i++) {
             photoUrls[i] = urls[i] as String?;
           }
        } else {
          photoUrls = List<String?>.filled(9, null, growable: true);
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
        'favoriteSong': _songController.text.trim(),
        'prompts': _promptsList
            .where((p) => p.question.isNotEmpty && p.controller.text.trim().isNotEmpty)
            .map((p) => {'question': p.question, 'answer': p.controller.text.trim()})
            .toList(),
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

  // --- NUOVA FUNZIONE: CARICAMENTO MULTIPLO OTTIMIZZATO ---
  Future<void> pickMultipleImages() async {
    // 1. Troviamo quanti "buchi" vuoti abbiamo PRIMA di aprire il selettore
    List<int> emptyIndices = [];
    for (int i = 0; i < 9; i++) {
      if (photoUrls[i] == null) emptyIndices.add(i);
    }

    int maxPhotos = emptyIndices.length;
    
    // Se la griglia è stranamente già piena, non facciamo nulla
    if (maxPhotos == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hai già raggiunto il limite di 9 foto!")));
      return;
    }

    final picker = ImagePicker();
    List<XFile> pickedFiles = [];
    
    // 2. IL BIVIO MAGICO: Gestiamo il caso del singolo slot vuoto!
    if (maxPhotos == 1) {
      // Se c'è 1 solo posto, usiamo il selettore singolo (evitando il crash)
      final XFile? singleFile = await picker.pickImage(source: ImageSource.gallery);
      if (singleFile != null) pickedFiles.add(singleFile);
    } else {
      // Se ci sono 2 o più posti, usiamo il selettore multiplo
      final List<XFile> multiFiles = await picker.pickMultiImage(limit: maxPhotos);
      pickedFiles.addAll(multiFiles);
    }
    
    if (pickedFiles.isEmpty) return;
    
    setState(() => isLoading = true);
    
    if (pickedFiles.isEmpty) return;
    
    setState(() => isLoading = true);

    try {
      // 3. Carichiamo in blocco (ora sappiamo che i file scelti entrano perfettamente nei buchi)
      for (int i = 0; i < pickedFiles.length; i++) {
        final picked = pickedFiles[i];
        final slotIndex = emptyIndices[i]; // Prendiamo il buco corrispondente

        Uint8List bytes;
        if (kIsWeb) {
          bytes = await picked.readAsBytes();
        } else {
          final raw = await picked.readAsBytes();
          bytes = await FlutterImageCompress.compressWithList(
            raw, minWidth: 512, minHeight: 512, quality: 80, format: CompressFormat.jpeg,
          );
        }
        
        final uniqueId = DateTime.now().millisecondsSinceEpoch + i;
        final ref = FirebaseStorage.instance.ref().child('users/${user!.uid}/photo_$uniqueId.jpg');
        
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        final newUrl = await ref.getDownloadURL();

        photoUrls[slotIndex] = newUrl; 
      }

      // 4. Compattiamo l'array
      List<String> fotoValide = photoUrls.whereType<String>().toList();
      photoUrls = List<String?>.filled(9, null, growable: true); // <-- Growable per il Drag&Drop!
      for (int i = 0; i < fotoValide.length; i++) {
        photoUrls[i] = fotoValide[i];
      }

      // 5. Salvataggio su Firestore
      Map<String, dynamic> updates = {'photoUrls': photoUrls};
      if (photoUrls[0] != null) updates['photoUrl'] = photoUrls[0]; 

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set(updates, SetOptions(merge: true));
          
    } catch (e) {
      debugPrint("Errore upload foto multiplo: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Errore: $e")));
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
      photoUrls = List<String?>.filled(9, null, growable: true);
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
      return const Center(child: HeartProgressIndicator(size: 60));
    }

    // Calcoliamo la percentuale in tempo reale ad ogni re-build
    final int completeness = _calculateCompleteness();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // Allarga tutto al massimo
        children: [
          
          // --- 1. BARRA DI COMPLETEZZA ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink.shade400, Colors.pink.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Completezza Profilo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('$completeness%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: completeness / 100,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
                if (completeness < 100)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('Aggiungi più dettagli per ottenere più Match!', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- 2. LE MIE FOTO (Multi-Upload & Drag & Drop) ---
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Le mie foto (Trascina per riordinare)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          
          ReorderableGridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            // --- LA MAGIA DEL DRAG & DROP CORRETTA ---
            onReorder: (oldIndex, newIndex) async {
              setState(() {
                // 1. Creiamo una copia "elastica" (growable) della lista attuale!
                List<String?> tempUrls = List.from(photoUrls);

                // 2. Spostiamo fisicamente l'elemento nella copia
                final item = tempUrls.removeAt(oldIndex);
                tempUrls.insert(newIndex, item);

                // 3. Ricompattiamo l'array
                List<String> fotoValide = tempUrls.whereType<String>().toList();
                
                // Ricreiamo la lista ufficiale dicendo esplicitamente "growable: true"
                photoUrls = List<String?>.filled(9, null, growable: true); 
                
                for (int i = 0; i < fotoValide.length; i++) {
                  photoUrls[i] = fotoValide[i];
                }
              });

              // Salviamo in background il nuovo ordine su Firebase
              if (user != null) {
                await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                  'photoUrls': photoUrls,
                  'photoUrl': photoUrls[0] ?? '', // La prima foto diventa il nuovo avatar
                });
              }
            },
            itemBuilder: (context, index) {
              final url = photoUrls[index];
              final bool isMain = index == 0;
              
              // IMPORTANTE: Ogni elemento in un Reorderable deve avere una "key" univoca!
              return Stack(
                key: ValueKey('photo_slot_$index'), 
                children: [
                  GestureDetector(
                    // --- ORA RICHIAMA L'UPLOAD MULTIPLO ---
                    onTap: () => url == null ? pickMultipleImages() : null, 
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(
                            color: isMain ? Colors.green : Colors.grey.shade300,
                            width: isMain ? 3 : 2,
                          ),
                          image: url != null ? DecorationImage(image: CachedNetworkImageProvider(url), fit: BoxFit.cover) : null,
                        ),
                        child: url == null ? Icon(Icons.add_photo_alternate_rounded, size: 36, color: Colors.grey.shade400) : null,
                      ),
                    ),
                  ),
                  if (url != null) ...[
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => removeImage(index),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    if (isMain)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.green.withOpacity(0.85),
                          child: const Text('Principale', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // --- 3. CARD INFORMAZIONI BASE ---
          Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Informazioni base', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: nameController,
                          onChanged: (_) => setState(() {}), // Ricalcola barra!
                          decoration: InputDecoration(labelText: "Nome", filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: ageController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(labelText: "Età", filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _jobController,
                    maxLength: 30,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: "Professione", hintText: "Es. Architetto", filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: _city),
                    readOnly: true,
                    decoration: InputDecoration(labelText: 'Città Attuale', prefixIcon: const Icon(Icons.location_on, color: Colors.pink), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- 4. CARD BIO E INTERESSI ---
          Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Su di me', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 500,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: "Bio", hintText: "Raccontaci qualcosa di interessante...", alignLabelWithHint: true, filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 16),
                  const Text('I miei Hobbies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
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
                        backgroundColor: Colors.grey.shade100,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // --- NUOVA CARD: ICEBREAKERS MULTIPLI ---
          Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Spunti di conversazione (Max 3)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 16),
                  
                  // Genera i box dei prompt
                  ..._promptsList.asMap().entries.map((entry) {
                    int index = entry.key;
                    PromptEntry p = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.pink.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: p.question.isEmpty ? null : p.question,
                                      hint: const Text('Scegli una domanda...'),
                                      items: _availablePrompts.map((q) => DropdownMenuItem(value: q, child: Text(q, overflow: TextOverflow.ellipsis))).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => p.question = val);
                                      },
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey),
                                  onPressed: () => setState(() => _promptsList.removeAt(index)),
                                )
                              ],
                            ),
                            if (p.question.isNotEmpty)
                              TextField(
                                controller: p.controller,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(hintText: "La tua risposta...", filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                                maxLines: 2,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                  // Bottone per aggiungere un nuovo prompt
                  if (_promptsList.length < 3)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _promptsList.add(PromptEntry(question: '', answer: ''))),
                        icon: const Icon(Icons.add, color: Colors.pink),
                        label: const Text('Aggiungi uno spunto', style: TextStyle(color: Colors.pink)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.pink.shade300, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12)
                        ),
                      ),
                    ),
                  
                  const Divider(height: 32),
                  
                  // Canzone Spotify
                  TextField(
                    controller: _songController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: "La mia canzone del momento", hintText: "Es. Shape of You - Ed Sheeran", prefixIcon: const Icon(Icons.music_note, color: Colors.green), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          // --- 5. BOTTONI SALVATAGGIO / ANTEPRIMA ---
          ElevatedButton(
            onPressed: saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 4,
            ),
            child: const Text("Salva Profilo", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.remove_red_eye, color: Colors.pink),
            label: const Text("Vedi come appari agli altri", style: TextStyle(color: Colors.pink, fontSize: 16)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.pink, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () {
              if (user != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePreviewScreen(uid: user!.uid)));
              }
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
