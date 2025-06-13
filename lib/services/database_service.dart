// database_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  late final FirebaseDatabase _rtdb;

  DatabaseService._internal();

  static DatabaseService get instance {
    return _instance;
  }

  Future<void> init() async {
    await Firebase.initializeApp();
    _rtdb = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://affinity-9e25e-default-rtdb.europe-west1.firebasedatabase.app',
    );
  }

  DatabaseReference ref(String path) => _rtdb.ref(path);
}
