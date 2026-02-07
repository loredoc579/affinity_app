import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final int age;
  final List<String> imageUrls;
  final String bio;
  final String jobTitle;
  final List<String> interests;
  final Map<String, dynamic>? location; // Lat/Long se servono

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

  // Metodo Factory: Trasforma la Map della Cloud Function in un oggetto Dart sicuro
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['uid'] ?? map['id'] ?? '', // Controlla come la tua function chiama l'id
      name: map['name'] ?? '',
      age: map['age'] ?? 18,
      // Gestione sicura delle liste (spesso Firebase le manda come dynamic)
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      bio: map['bio'] ?? '',
      jobTitle: map['jobTitle'] ?? '',
      interests: List<String>.from(map['interests'] ?? []),
      location: map['location'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': id,
      'id': id,
      'name': name,
      'age': age,
      'bio': bio,
      'jobTitle': jobTitle,
      'interests': interests,
      'location': location,
      
      // TRUCCO COMPATIBILITÀ:
      // Il tuo vecchio codice cerca 'photoUrls', il nuovo modello usa 'imageUrls'.
      // Li mettiamo entrambi così funzionano tutti i widget!
      'imageUrls': imageUrls,
      'photoUrls': imageUrls, 
    };
  }

  // Serve a Equatable per evitare refresh inutili
  @override
  List<Object?> get props => [id, name, age, imageUrls, bio];
}