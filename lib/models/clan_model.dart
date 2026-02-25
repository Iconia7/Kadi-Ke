class ClanMember {
  final String userId;
  final String username;
  final String role; // 'owner', 'elder', 'member'
  final String joinedAt;
  final String? avatar;
  final int wins;
  final bool isOnline; // Can be derived if we pass online status, else default false

  ClanMember({
    required this.userId,
    required this.username,
    required this.role,
    required this.joinedAt,
    this.avatar,
    this.wins = 0,
    this.isOnline = false,
  });

  factory ClanMember.fromJson(Map<String, dynamic> json) {
    return ClanMember(
      userId: json['userId'] ?? '',
      username: json['username'] ?? 'Unknown',
      role: json['role'] ?? 'member',
      joinedAt: json['joinedAt'] ?? '',
      avatar: json['avatar'],
      wins: json['wins'] ?? 0,
    );
  }
}

class Clan {
  final String id;
  final String name;
  final String tag;
  final String description;
  final String ownerId;
  final int totalScore;
  final int capacity;
  final int memberCount; // Useful for search list
  final String createdAt;
  final List<ClanMember> members;

  Clan({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
    required this.ownerId,
    required this.totalScore,
    required this.capacity,
    this.memberCount = 0,
    required this.createdAt,
    this.members = const [],
  });

  factory Clan.fromJson(Map<String, dynamic> json) {
    var rawMembers = json['members'] as List? ?? [];
    List<ClanMember> parsedMembers = 
        rawMembers.map((m) => ClanMember.fromJson(m)).toList();

    return Clan(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      tag: json['tag'] ?? '',
      description: json['description'] ?? '',
      ownerId: json['ownerId'] ?? '',
      totalScore: json['totalScore'] ?? 0,
      capacity: json['capacity'] ?? 50,
      memberCount: json['memberCount'] ?? parsedMembers.length,
      createdAt: json['createdAt'] ?? '',
      members: parsedMembers,
    );
  }
}
