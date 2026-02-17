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
    // 1. Gestione Età
    int parsedAge = 18;
    if (map['age'] is int) {
      parsedAge = map['age'];
    } else if (map['age'] is String) {
      parsedAge = int.tryParse(map['age']) ?? 18;
    }

    // 2. Gestione Interessi
    List<String> parsedInterests = [];
    if (map['hobbies'] is String) {
      parsedInterests = (map['hobbies'] as String)
          .split(',')
          .map((e) => e.trim())
          .toList();
    } else if (map['interests'] is List) {
      parsedInterests = List<String>.from(map['interests']);
    }

    // 3. IL FIX È QUI: Gestione sicura della "scatola" Location
    Map<String, dynamic>? parsedLocation;
    if (map['location'] != null && map['location'] is Map) {
      // Creiamo una mappa pulita e tipizzata per la location
      parsedLocation = Map<String, dynamic>.from(map['location'] as Map);
    }

    return UserModel(
      id: map['uid'] ?? map['id'] ?? '', 
      name: map['name'] ?? 'Sconosciuto',
      age: parsedAge,
      imageUrls: List<String>.from(map['photoUrls'] ?? []),
      bio: map['bio'] ?? '',
      jobTitle: map['jobTitle'] ?? '',
      interests: parsedInterests,
      location: parsedLocation, // <-- Ora passiamo la mappa pulita!
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': id,
      'name': name,
      'age': age.toString(), 
      'bio': bio,
      'jobTitle': jobTitle,
      'hobbies': interests.join(', '), 
      'location': location,
      'photoUrls': imageUrls,
    };
  }

  @override
  List<Object?> get props => [id, name, age, imageUrls, bio, location, interests];
}