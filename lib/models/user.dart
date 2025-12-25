
class User {
  final String username;
  final String password; // In a real app, this should be hashed!

  User({required this.username, required this.password});

  Map<String, dynamic> toMap() => {
        'username': username,
        'password': password,
      };

  factory User.fromMap(Map<dynamic, dynamic> map) => User(
        username: map['username'] as String,
        password: map['password'] as String,
      );
}
