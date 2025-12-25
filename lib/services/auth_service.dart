import 'package:hive/hive.dart';
import '../models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  late Box _userBox;
  late Box _sessionBox;

  Future<void> init() async {
    _userBox = await Hive.openBox('users');
    _sessionBox = await Hive.openBox('session');
  }

  // Sign up a new user
  Future<bool> signUp(String username, String password) async {
    if (_userBox.containsKey(username)) {
      return false; // User already exists
    }
    final user = User(username: username, password: password);
    await _userBox.put(username, user.toMap());
    // Auto login after signup
    await login(username, password);
    return true;
  }

  // Login a user
  Future<bool> login(String username, String password) async {
    final storedUserMap = _userBox.get(username);
    
    if (storedUserMap == null) return false;

    final user = User.fromMap(storedUserMap);
    if (user.password == password) {
      await _sessionBox.put('currentUser', username);
      return true;
    }
    return false;
  }

  // Logout
  Future<void> logout() async {
    await _sessionBox.delete('currentUser');
  }

  // Check if user is logged in
  bool get isLoggedIn => _sessionBox.containsKey('currentUser');

  String? get currentUser => _sessionBox.get('currentUser');
}
