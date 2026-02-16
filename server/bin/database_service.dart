import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Database _db;
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _db = sqlite3.open('kadi_game.db');
    _createTables();
    _initialized = true;
    print('SQLite Database initialized.');
  }

  void _createTables() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        email TEXT,
        googleId TEXT,
        wins INTEGER DEFAULT 0,
        coins INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        avatar TEXT,
        resetToken TEXT,
        resetTokenExpiry TEXT
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS friends (
        userId TEXT NOT NULL,
        friendUserId TEXT NOT NULL,
        username TEXT,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        PRIMARY KEY (userId, friendUserId)
      )
    ''');
    
    _db.execute('CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)');
  }

  // --- Migration ---
  void migrateFromJSON(Map<String, dynamic> usersData) {
    _db.execute('BEGIN TRANSACTION');
    try {
      usersData.forEach((username, data) {
        final id = data['id'];
        _db.execute('''
          INSERT OR IGNORE INTO users (id, username, password, email, googleId, wins, coins, created_at, avatar, resetToken, resetTokenExpiry)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          id,
          username,
          data['password'] ?? '',
          data['email'],
          data['googleId'],
          data['wins'] ?? 0,
          data['coins'] ?? 0,
          data['created_at'] ?? DateTime.now().toIso8601String(),
          data['avatar'],
          data['resetToken'],
          data['resetTokenExpiry']
        ]);

        // Migrate friends
        if (data['friends'] != null) {
          final friends = data['friends'] as List;
          for (var friend in friends) {
            _db.execute('''
              INSERT OR IGNORE INTO friends (userId, friendUserId, username, status, createdAt)
              VALUES (?, ?, ?, ?, ?)
            ''', [
              id,
              friend['userId'],
              friend['username'],
              friend['status'] ?? 'pending',
              friend['createdAt'] ?? DateTime.now().toIso8601String()
            ]);
          }
        }
      });
      _db.execute('COMMIT');
      print('Migration from JSON completed successfully.');
    } catch (e) {
      _db.execute('ROLLBACK');
      print('Migration failed: $e');
    }
  }

  // --- User Operations ---

  Map<String, dynamic>? getUserByUsername(String username) {
    final ResultSet results = _db.select('SELECT * FROM users WHERE username = ?', [username]);
    if (results.isEmpty) return null;
    return _rowToMap(results.first);
  }

  Map<String, dynamic>? getUserById(String userId) {
    final ResultSet results = _db.select('SELECT * FROM users WHERE id = ?', [userId]);
    if (results.isEmpty) return null;
    return _rowToMap(results.first);
  }

  void saveUser(String username, Map<String, dynamic> userData) {
    _db.execute('''
      INSERT OR REPLACE INTO users (id, username, password, email, googleId, wins, coins, created_at, avatar, resetToken, resetTokenExpiry)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      userData['id'],
      username,
      userData['password'],
      userData['email'],
      userData['googleId'],
      userData['wins'],
      userData['coins'],
      userData['created_at'],
      userData['avatar'],
      userData['resetToken'],
      userData['resetTokenExpiry']
    ]);
  }

  void updateUser(String userId, Map<String, dynamic> updates) {
    if (updates.isEmpty) return;
    
    final keys = updates.keys.toList();
    final values = updates.values.toList();
    final setClause = keys.map((k) => '$k = ?').join(', ');
    
    values.add(userId);
    _db.execute('UPDATE users SET $setClause WHERE id = ?', values);
  }

  void updateUsername(String oldUsername, String newUsername) {
    _db.execute('UPDATE users SET username = ? WHERE username = ?', [newUsername, oldUsername]);
  }

  Map<String, Map<String, dynamic>> getAllUsers() {
    final ResultSet results = _db.select('SELECT * FROM users');
    final Map<String, Map<String, dynamic>> users = {};
    for (var row in results) {
      final userData = _rowToMap(row);
      users[row['username']] = userData;
    }
    return users;
  }

  // --- Friend Operations ---

  List<Map<String, dynamic>> getFriends(String userId) {
    final ResultSet results = _db.select('SELECT * FROM friends WHERE userId = ?', [userId]);
    return results.map((row) => {
      'userId': row['friendUserId'],
      'username': row['username'],
      'status': row['status'],
      'createdAt': row['createdAt'],
    }).toList();
  }

  void addFriendRequest(String userId, String friendUserId, String friendUsername) {
    _db.execute('''
      INSERT OR IGNORE INTO friends (userId, friendUserId, username, status, createdAt)
      VALUES (?, ?, ?, ?, ?)
    ''', [userId, friendUserId, friendUsername, 'pending', DateTime.now().toIso8601String()]);
  }

  void acceptFriendRequest(String userId, String friendUserId) {
    _db.execute('UPDATE friends SET status = ? WHERE userId = ? AND friendUserId = ?', ['accepted', userId, friendUserId]);
  }

  void removeFriend(String userId, String friendUserId) {
    _db.execute('DELETE FROM friends WHERE (userId = ? AND friendUserId = ?) OR (userId = ? AND friendUserId = ?)', 
      [userId, friendUserId, friendUserId, userId]);
  }

  // --- Helpers ---

  Map<String, dynamic> _rowToMap(Row row) {
    final map = Map<String, dynamic>.from(row);
    // In our JSON structure, friends was a list within the user object.
    // For compatibility with existing server logic, we might need to fetch friends.
    // But let's see if we can refactor server.dart to use getFriends(userId) separately.
    return map;
  }
  
  void close() {
    _db.dispose();
  }
}
