import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final int age;
  final List<String> imageUrls;
  final String bio;
  final String jobTitle;
  final List<String> interests;
  final Map<String, dynamic>? location;
  final String gender;

  const UserModel({
    required this.id,
    required this.name,
    required this.age,
    required this.imageUrls,
    required this.bio,
    required this.jobTitle,
    required this.interests,
    this.location,
    required this.gender,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // 1. Gestione Età Sicura
    int parsedAge = 18;
    if (map['age'] is int) {
      parsedAge = map['age'];
    } else if (map['age'] is String) {
      parsedAge = int.tryParse(map['age']) ?? 18;
    }

    // 2. Gestione Interessi Sicura (Stringa o Array)
    List<String> parsedInterests = [];
    if (map['hobbies'] is String && map['hobbies'].toString().isNotEmpty) {
      parsedInterests = (map['hobbies'] as String).split(',').map((e) => e.trim()).toList();
    } else if (map['hobbies'] is List) {
      parsedInterests = (map['hobbies'] as List).where((e) => e != null).map((e) => e.toString()).toList();
    } else if (map['interests'] is List) {
      parsedInterests = (map['interests'] as List).where((e) => e != null).map((e) => e.toString()).toList();
    }

    // 3. Gestione Location Sicura
    Map<String, dynamic>? parsedLocation;
    if (map['location'] != null && map['location'] is Map) {
      parsedLocation = Map<String, dynamic>.from(map['location'] as Map);
    }

    // 4. IL FIX DEL CRASH: Gestione Foto Sicura
    List<String> parsedImages = [];
    if (map['photoUrls'] is List) {
      // Peschiamo solo le stringhe valide, ignorando i 'null' degli slot vuoti!
      parsedImages = (map['photoUrls'] as List)
          .where((item) => item != null && item.toString().isNotEmpty)
          .map((item) => item.toString())
          .toList();
    }
    // Fallback: se la griglia è vuota ma ha un avatar base
    if (parsedImages.isEmpty && map['photoUrl'] != null && map['photoUrl'].toString().isNotEmpty) {
      parsedImages.add(map['photoUrl'].toString());
    }

    return UserModel(
      id: (map['uid'] ?? map['id'] ?? '').toString(), 
      name: (map['name'] ?? 'Sconosciuto').toString(),
      age: parsedAge,
      imageUrls: parsedImages,
      bio: (map['bio'] ?? '').toString(),
      jobTitle: (map['jobTitle'] ?? '').toString(),
      interests: parsedInterests,
      location: parsedLocation,
      gender: (map['gender'] ?? 'N.D.').toString(), 
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': id,
      'name': name,
      'age': age, // Lo salviamo come numero pulito
      'bio': bio,
      'jobTitle': jobTitle,
      'hobbies': interests.join(', '), 
      'location': location,
      'photoUrls': imageUrls,
      'gender': gender, 
    };
  }

  @override
  List<Object?> get props => [id, name, age, imageUrls, bio, location, interests, gender]; 
}