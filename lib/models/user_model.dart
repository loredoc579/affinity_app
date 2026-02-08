import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final int age;
  final List<String> imageUrls;
  final String bio;
  final String jobTitle;
  final List<String> interests;
  final Map<String, dynamic>? location; // Manteniamo la mappa per flessibilità

  const UserModel({
    required this.id,
    required this.name,
    required this.age,
    required this.imageUrls,
    required this.bio,
    required this.jobTitle,
    required this.interests,
    this.location,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // 1. Gestione robusta dell'Età (Stringa "27" -> Int 27)
    int parsedAge = 18;
    if (map['age'] is int) {
      parsedAge = map['age'];
    } else if (map['age'] is String) {
      parsedAge = int.tryParse(map['age']) ?? 18;
    }

    // 2. Gestione Interessi/Hobby (Stringa "a, b" -> Lista ["a", "b"])
    List<String> parsedInterests = [];
    if (map['hobbies'] is String) {
      // Se nel DB è "cucina, yoga", diventa ["cucina", "yoga"]
      parsedInterests = (map['hobbies'] as String)
          .split(',')
          .map((e) => e.trim()) // Rimuove spazi extra
          .toList();
    } else if (map['interests'] is List) {
      parsedInterests = List<String>.from(map['interests']);
    }

    return UserModel(
      // L'ID viene passato dalla Cloud Function o preso dal campo se esiste
      id: map['uid'] ?? map['id'] ?? '', 
      
      name: map['name'] ?? 'Sconosciuto',
      
      age: parsedAge,
      
      // Supporta sia 'imageUrls' che 'photoUrls' (come nel tuo DB)
      imageUrls: List<String>.from(
        map['imageUrls'] ?? map['photoUrls'] ?? []
      ),
      
      // Se manca la bio, stringa vuota
      bio: map['bio'] ?? '',
      
      jobTitle: map['jobTitle'] ?? '',
      
      interests: parsedInterests,
      
      location: map['location'],
    );
  }

  // Metodo per convertire il modello in mappa (utile se dovessi salvare dati)
  Map<String, dynamic> toMap() {
    return {
      'uid': id,
      'name': name,
      'age': age.toString(), // Salviamo come stringa per coerenza col tuo DB
      'bio': bio,
      'jobTitle': jobTitle,
      'hobbies': interests.join(', '), // Salviamo come stringa separata da virgole
      'location': location,
      'photoUrls': imageUrls,
    };
  }

  @override
  List<Object?> get props => [id, name, age, imageUrls, bio, location, interests];
}