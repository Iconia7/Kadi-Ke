class Friend {
  final String userId;
  final String username;
  final String status; // 'pending', 'accepted', 'blocked'
  final bool isOnline;
  final DateTime? lastSeen;
  final int wins;
  final DateTime createdAt;

  Friend({
    required this.userId,
    required this.username,
    required this.status,
    this.isOnline = false,
    this.lastSeen,
    this.wins = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert Friend to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'status': status,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'wins': wins,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create Friend from JSON
  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      userId: json['userId'] as String,
      username: json['username'] as String,
      status: json['status'] as String? ?? 'pending',
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null 
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
      wins: json['wins'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  // Copy with helper for updates
  Friend copyWith({
    String? userId,
    String? username,
    String? status,
    bool? isOnline,
    DateTime? lastSeen,
    int? wins,
    DateTime? createdAt,
  }) {
    return Friend(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      wins: wins ?? this.wins,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
