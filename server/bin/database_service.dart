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
        games_played INTEGER DEFAULT 0,
        coins INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        avatar TEXT,
        resetToken TEXT,
        resetTokenExpiry TEXT
      )
    ''');

    try {
      _db.execute('ALTER TABLE users ADD COLUMN games_played INTEGER DEFAULT 0');
    } catch (_) {
      // Column might already exist
    }

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

    _db.execute('''
      CREATE TABLE IF NOT EXISTS feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT,
        username TEXT,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS fcm_tokens (
        userId TEXT PRIMARY KEY,
        token TEXT NOT NULL,
        lastUpdated TEXT NOT NULL
      )
    ''');

    // --- Clan System Expansion ---
    _db.execute('''
      CREATE TABLE IF NOT EXISTS clans (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        tag TEXT UNIQUE NOT NULL,
        description TEXT,
        ownerId TEXT NOT NULL,
        totalScore INTEGER DEFAULT 0,
        seasonScore INTEGER DEFAULT 0,
        trophies INTEGER DEFAULT 0,
        capacity INTEGER DEFAULT 50,
        entryFee INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS clan_members (
        userId TEXT PRIMARY KEY,
        clanId TEXT NOT NULL,
        role TEXT NOT NULL,
        joinedAt TEXT NOT NULL,
        seasonPoints INTEGER DEFAULT 0,
        totalPoints INTEGER DEFAULT 0,
        FOREIGN KEY (clanId) REFERENCES clans(id) ON DELETE CASCADE
      )
    ''');
    _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_clan_members_clanId ON clan_members(clanId)');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS clan_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clanId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        senderName TEXT NOT NULL,
        senderAvatar TEXT,
        message TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_clan_messages_clanId ON clan_messages(clanId)');

    // Safe schema migrations for existing database files
    try { _db.execute('ALTER TABLE clans ADD COLUMN seasonScore INTEGER DEFAULT 0'); } catch (_) {}
    try { _db.execute('ALTER TABLE clans ADD COLUMN trophies INTEGER DEFAULT 0'); } catch (_) {}
    try { _db.execute('ALTER TABLE clan_members ADD COLUMN seasonPoints INTEGER DEFAULT 0'); } catch (_) {}
    try { _db.execute('ALTER TABLE clan_members ADD COLUMN totalPoints INTEGER DEFAULT 0'); } catch (_) {}
    try { _db.execute('ALTER TABLE clans ADD COLUMN entryFee INTEGER DEFAULT 0'); } catch (_) {}
  }

  // --- Migration ---
  void migrateFromJSON(Map<String, dynamic> usersData) {
    _db.execute('BEGIN TRANSACTION');
    try {
      usersData.forEach((username, data) {
        final id = data['id'];
        _db.execute('''
          INSERT OR IGNORE INTO users (id, username, password, email, googleId, wins, games_played, coins, created_at, avatar, resetToken, resetTokenExpiry)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          id,
          username,
          data['password'] ?? '',
          data['email'],
          data['googleId'],
          data['wins'] ?? 0,
          data['games_played'] ?? 0,
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
    final ResultSet results =
        _db.select('SELECT * FROM users WHERE username = ?', [username]);
    if (results.isEmpty) return null;
    return _rowToMap(results.first);
  }

  Map<String, dynamic>? getUserById(String userId) {
    final ResultSet results =
        _db.select('SELECT * FROM users WHERE id = ?', [userId]);
    if (results.isEmpty) return null;
    return _rowToMap(results.first);
  }

  void saveUser(String username, Map<String, dynamic> userData) {
    _db.execute('''
      INSERT OR REPLACE INTO users (id, username, password, email, googleId, wins, games_played, coins, created_at, avatar, resetToken, resetTokenExpiry)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      userData['id'],
      username,
      userData['password'],
      userData['email'],
      userData['googleId'],
      userData['wins'],
      userData['games_played'],
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
    _db.execute('UPDATE users SET username = ? WHERE username = ?',
        [newUsername, oldUsername]);
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

  void incrementWins(String userId) {
    _db.execute('UPDATE users SET wins = wins + 1 WHERE id = ?', [userId]);
  }

  void incrementGamesPlayed(String userId) {
    _db.execute('UPDATE users SET games_played = games_played + 1 WHERE id = ?', [userId]);
  }

  void incrementCoins(String userId, int amount) {
    _db.execute(
        'UPDATE users SET coins = coins + ? WHERE id = ?', [amount, userId]);
  }

  /// Adds points to a user's clan contributions and the clan's overall score
  void addClanPoints(String userId, int points) {
    final rs = _db.select('SELECT clanId FROM clan_members WHERE userId = ?', [userId]);
    if (rs.isNotEmpty) {
      final clanId = rs.first['clanId'];
      _db.execute('''
        UPDATE clan_members 
        SET seasonPoints = seasonPoints + ?, totalPoints = totalPoints + ? 
        WHERE userId = ?
      ''', [points, points, userId]);
      
      _db.execute('''
        UPDATE clans 
        SET seasonScore = seasonScore + ?, totalScore = totalScore + ? 
        WHERE id = ?
      ''', [points, points, clanId]);
    }
  }

  /// Ends the weekly clan war:
  /// 1. Finds the clan with the highest seasonScore
  /// 2. Awards them +1 trophy
  /// 3. Resets seasonScore (for clans) and seasonPoints (for members)
  /// Returns the winning clan's details (or null if no points were scored)
  Map<String, dynamic>? resetClanWars() {
    // Find winner
    final rs = _db.select('''
      SELECT id, name, tag, seasonScore 
      FROM clans 
      WHERE seasonScore > 0 
      ORDER BY seasonScore DESC 
      LIMIT 1
    ''');
    
    Map<String, dynamic>? winner;
    if (rs.isNotEmpty) {
      winner = Map<String, dynamic>.from(rs.first);
      final winnerId = winner['id'];
      // Award trophy
      _db.execute('UPDATE clans SET trophies = trophies + 1 WHERE id = ?', [winnerId]);
    }

    // Reset all season scores and points
    _db.execute('UPDATE clans SET seasonScore = 0');
    _db.execute('UPDATE clan_members SET seasonPoints = 0');

    return winner;
  }

  // --- FCM Token Operations ---

  void saveFCMToken(String userId, String token) {
    _db.execute('''
      INSERT OR REPLACE INTO fcm_tokens (userId, token, lastUpdated)
      VALUES (?, ?, ?)
    ''', [userId, token, DateTime.now().toIso8601String()]);
  }

  String? getFCMToken(String userId) {
    final ResultSet results =
        _db.select('SELECT token FROM fcm_tokens WHERE userId = ?', [userId]);
    if (results.isEmpty) return null;
    return results.first['token'] as String;
  }

  List<String> getAllFCMTokens() {
    final ResultSet results = _db.select('SELECT token FROM fcm_tokens');
    return results.map((row) => row['token'] as String).toList();
  }

  // --- Clan System Operations ---

  Map<String, dynamic>? createClan(String clanId, String name, String tag,
      String description, String ownerId, int entryFee) {
    try {
      _db.execute('BEGIN TRANSACTION');

      // Removed server-side coin validation since coins are currently managed locally by ProgressionService
      // on the client-side. We will handle deduction strictly on the frontend for now.

      // Insert Clan
      _db.execute('''
        INSERT INTO clans (id, name, tag, description, ownerId, entryFee, createdAt)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [
        clanId,
        name,
        tag,
        description,
        ownerId,
        entryFee,
        DateTime.now().toIso8601String()
      ]);

      // Add owner as member
      _db.execute('''
        INSERT INTO clan_members (userId, clanId, role, joinedAt)
        VALUES (?, ?, ?, ?)
      ''', [ownerId, clanId, 'owner', DateTime.now().toIso8601String()]);

      _db.execute('COMMIT');
      return {'success': true, 'clanId': clanId, 'tag': tag};
    } catch (e) {
      _db.execute('ROLLBACK');
      throw Exception('Failed to create clan: $e');
    }
  }

  void joinClan(String userId, String clanId) {
    try {
      _db.execute('BEGIN TRANSACTION');

      // Check if already in a clan
      final memberCheck = _db
          .select('SELECT clanId FROM clan_members WHERE userId = ?', [userId]);
      if (memberCheck.isNotEmpty) throw Exception("User already in a clan");

      // Check capacity
      final clanCheck = _db.select('''
        SELECT c.capacity, (SELECT COUNT(*) FROM clan_members WHERE clanId = ?) as memberCount 
        FROM clans c WHERE c.id = ?
      ''', [clanId, clanId]);

      if (clanCheck.isEmpty) throw Exception("Clan not found");

      int capacity = clanCheck.first['capacity'] as int;
      int memberCount = clanCheck.first['memberCount'] as int;
      if (memberCount >= capacity) throw Exception("Clan is full");

      _db.execute('''
        INSERT INTO clan_members (userId, clanId, role, joinedAt)
        VALUES (?, ?, 'member', ?)
      ''', [userId, clanId, DateTime.now().toIso8601String()]);

      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void leaveClan(String userId) {
    _db.execute('DELETE FROM clan_members WHERE userId = ?', [userId]);
  }

  /// Owner kicks a specific member from their clan
  void kickMember(String targetUserId) {
    _db.execute('DELETE FROM clan_members WHERE userId = ?', [targetUserId]);
  }

  /// Delete the entire clan (owner only). Cascades to clan_members via FK.
  void deleteClan(String clanId) {
    _db.execute('DELETE FROM clan_messages WHERE clanId = ?', [clanId]);
    _db.execute('DELETE FROM clan_members WHERE clanId = ?', [clanId]);
    _db.execute('DELETE FROM clans WHERE id = ?', [clanId]);
  }

  /// Returns the clan owned by this user, or null if they don't own any clan.
  Map<String, dynamic>? getClanByOwner(String userId) {
    final res = _db.select('SELECT * FROM clans WHERE ownerId = ?', [userId]);
    if (res.isEmpty) return null;
    return Map<String, dynamic>.from(res.first);
  }

  Map<String, dynamic>? getClanDetails(String clanId) {
    final ResultSet clanRes =
        _db.select('SELECT * FROM clans WHERE id = ?', [clanId]);
    if (clanRes.isEmpty) return null;

    var clan = _rowToMap(clanRes.first);

    final ResultSet memberRes = _db.select('''
      SELECT cm.userId, cm.role, cm.joinedAt, cm.seasonPoints, cm.totalPoints, u.username, u.avatar, u.wins, u.games_played 
      FROM clan_members cm
      JOIN users u ON cm.userId = u.id
      WHERE cm.clanId = ?
    ''', [clanId]);

    clan['members'] = memberRes.map((r) => _rowToMap(r)).toList();
    return clan;
  }

  List<Map<String, dynamic>> searchClans() {
    final ResultSet results = _db.select('''
      SELECT c.*, (SELECT COUNT(*) FROM clan_members WHERE clanId = c.id) as memberCount 
      FROM clans c
      ORDER BY seasonScore DESC, trophies DESC, totalScore DESC 
      LIMIT 50
    ''');
    return results.map((r) => _rowToMap(r)).toList();
  }

  String? getUserClanTag(String userId) {
    final ResultSet results = _db.select('''
      SELECT c.tag FROM clans c
      JOIN clan_members cm ON c.id = cm.clanId
      WHERE cm.userId = ?
    ''', [userId]);
    if (results.isEmpty) return null;
    return results.first['tag'] as String;
  }

  Map<String, dynamic>? getMyClan(String userId) {
    final ResultSet results = _db
        .select('SELECT clanId FROM clan_members WHERE userId = ?', [userId]);
    if (results.isEmpty) return null;
    String clanId = results.first['clanId'] as String;
    return getClanDetails(clanId);
  }

  // --- Friend Operations ---

  List<Map<String, dynamic>> getFriends(String userId) {
    final ResultSet results = _db.select('''
      SELECT f.*, u.avatar 
      FROM friends f
      LEFT JOIN users u ON f.friendUserId = u.id
      WHERE f.userId = ?
    ''', [userId]);

    return results
        .map((row) => {
              'userId': row['friendUserId'],
              'username': row['username'],
              'status': row['status'],
              'createdAt': row['createdAt'],
              'avatar': row['avatar']
            })
        .toList();
  }

  void addFriendRequest(
      String userId, String friendUserId, String friendUsername) {
    _db.execute('''
      INSERT OR IGNORE INTO friends (userId, friendUserId, username, status, createdAt)
      VALUES (?, ?, ?, ?, ?)
    ''', [
      userId,
      friendUserId,
      friendUsername,
      'pending',
      DateTime.now().toIso8601String()
    ]);
  }

  void acceptFriendRequest(String userId, String friendUserId) {
    _db.execute(
        'UPDATE friends SET status = ? WHERE userId = ? AND friendUserId = ?',
        ['accepted', userId, friendUserId]);
  }

  void removeFriend(String userId, String friendUserId) {
    _db.execute(
        'DELETE FROM friends WHERE (userId = ? AND friendUserId = ?) OR (userId = ? AND friendUserId = ?)',
        [userId, friendUserId, friendUserId, userId]);
  }

  // --- Feedback Operations ---

  void saveFeedback(Map<String, dynamic> data) {
    _db.execute('''
      INSERT INTO feedback (userId, username, message, type, timestamp)
      VALUES (?, ?, ?, ?, ?)
    ''', [
      data['userId'],
      data['username'],
      data['message'],
      data['type'],
      data['timestamp'] ?? DateTime.now().toIso8601String()
    ]);
  }

  List<Map<String, dynamic>> getAllFeedback() {
    final ResultSet results =
        _db.select('SELECT * FROM feedback ORDER BY timestamp DESC');
    return results.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  // --- Clan Chat ---

  void saveClanMessage(String clanId, String senderId, String senderName,
      String? senderAvatar, String message) {
    _db.execute('''
      INSERT INTO clan_messages (clanId, senderId, senderName, senderAvatar, message, timestamp)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      clanId,
      senderId,
      senderName,
      senderAvatar,
      message,
      DateTime.now().toIso8601String()
    ]);
  }

  List<Map<String, dynamic>> getClanMessageHistory(String clanId,
      {int limit = 50}) {
    final ResultSet results = _db.select('''
      SELECT senderId, senderName, senderAvatar, message, timestamp
      FROM clan_messages
      WHERE clanId = ?
      ORDER BY timestamp DESC
      LIMIT ?
    ''', [clanId, limit]);
    // Reverse so oldest is first
    return results
        .map((r) => {...Map<String, dynamic>.from(r), 'clanId': clanId})
        .toList()
        .reversed
        .toList();
  }

  // --- Helpers ---

  Map<String, dynamic> _rowToMap(Row row) {
    final map = Map<String, dynamic>.from(row);
    return map;
  }

  void close() {
    _db.dispose();
  }
}
