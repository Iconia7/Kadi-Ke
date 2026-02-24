class TournamentMatch {
  final String id;
  final List<String> playerIds;
  final String status; // 'pending', 'active', 'finished'
  final String? winnerId;
  final int round; // e.g., 0 = Quarter finals, 1 = Semi, 2 = Final

  TournamentMatch({
    required this.id,
    required this.playerIds,
    required this.status,
    required this.round,
    this.winnerId,
  });

  factory TournamentMatch.fromJson(Map<String, dynamic> json) {
    return TournamentMatch(
      id: json['id'],
      playerIds: List<String>.from(json['playerIds'] ?? []),
      status: json['status'] ?? 'pending',
      winnerId: json['winnerId'],
      round: json['round'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playerIds': playerIds,
      'status': status,
      'winnerId': winnerId,
      'round': round,
    };
  }
}

class Tournament {
  final String id;
  final String hostId;
  final String name;
  final String gameMode; // 'kadi' or 'gofish'
  final int maxPlayers; // 4, 8, 16
  final int entryFee;
  final String status; // 'recruiting', 'in_progress', 'completed'
  final List<String> currentPlayers;
  final List<TournamentMatch> matches;
  final int prizePool;

  Tournament({
    required this.id,
    required this.hostId,
    required this.name,
    required this.gameMode,
    required this.maxPlayers,
    required this.entryFee,
    required this.status,
    required this.currentPlayers,
    required this.matches,
    required this.prizePool,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'],
      hostId: json['hostId'] ?? '',
      name: json['name'] ?? 'Tournament',
      gameMode: json['gameMode'] ?? 'kadi',
      maxPlayers: json['maxPlayers'] ?? 8,
      entryFee: json['entryFee'] ?? 0,
      status: json['status'] ?? 'recruiting',
      currentPlayers: List<String>.from(json['currentPlayers'] ?? []),
      matches: (json['matches'] as List<dynamic>?)
              ?.map((m) => TournamentMatch.fromJson(m))
              .toList() ??
          [],
      prizePool: json['prizePool'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostId': hostId,
      'name': name,
      'gameMode': gameMode,
      'maxPlayers': maxPlayers,
      'entryFee': entryFee,
      'status': status,
      'currentPlayers': currentPlayers,
      'matches': matches.map((m) => m.toJson()).toList(),
      'prizePool': prizePool,
    };
  }
}
