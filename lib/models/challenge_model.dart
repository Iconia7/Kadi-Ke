enum ChallengeType {
  winGames,
  playGames,
  collectCards, // For Go Fish
  playSpecialCards, // For Kadi (Aces, Jokers, etc)
  sayNikoKadi,
  useEmote,
  drawCards,
  bombStack,
  fastWin, // Win in under 2 minutes
}

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final int goal;
  int progress;
  final int reward;
  bool isClaimed;

  ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.goal,
    this.progress = 0,
    required this.reward,
    this.isClaimed = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.index,
    'goal': goal,
    'progress': progress,
    'reward': reward,
    'isClaimed': isClaimed,
  };

  factory ChallengeModel.fromJson(Map<String, dynamic> json) => ChallengeModel(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    type: ChallengeType.values[json['type']],
    goal: json['goal'],
    progress: json['progress'] ?? 0,
    reward: json['reward'],
    isClaimed: json['isClaimed'] ?? false,
  );

  bool get isCompleted => progress >= goal;
}
