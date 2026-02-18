import 'package:flutter/material.dart';
import '../models/challenge_model.dart';

class DailyChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final VoidCallback onClaim;

  const DailyChallengeCard({
    Key? key,
    required this.challenge,
    required this.onClaim,
  }) : super(key: key);

  IconData _getChallengeIcon() {
    switch (challenge.type) {
      case ChallengeType.winGames:
        return Icons.emoji_events;
      case ChallengeType.playGames:
        return Icons.style;
      case ChallengeType.playSpecialCards:
        return Icons.auto_awesome;
      case ChallengeType.sayNikoKadi:
        return Icons.record_voice_over;
      case ChallengeType.useEmote:
        return Icons.insert_emoticon;
      case ChallengeType.drawCards:
        return Icons.add_to_photos;
      case ChallengeType.bombStack:
        return Icons.whatshot;
      case ChallengeType.fastWin:
        return Icons.speed;
      default:
        return Icons.flag;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B).withOpacity(0.8),
            const Color(0xFF334155).withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: challenge.isCompleted
              ? const Color(0xFF00E5FF)
              : Colors.white.withOpacity(0.1),
          width: challenge.isCompleted ? 2 : 1,
        ),
        boxShadow: challenge.isCompleted
            ? [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.3),
                  blurRadius: 10,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: challenge.isCompleted
                  ? const Color(0xFF00E5FF).withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getChallengeIcon(),
              color: challenge.isCompleted ? const Color(0xFF00E5FF) : Colors.white54,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          
          // Challenge info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  challenge.description,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Progress bar
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: challenge.goal > 0 ? (challenge.progress / challenge.goal).clamp(0.0, 1.0) : 0,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E5FF), Color(0xFF0099CC)],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${challenge.progress}/${challenge.goal}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Reward / Claim button
          if (challenge.isCompleted && !challenge.isClaimed)
            ElevatedButton(
              onPressed: onClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'CLAIM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${challenge.reward} 🪙',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            )
          else if (challenge.isClaimed)
            const Icon(Icons.check_circle, color: Color(0xFF00E5FF), size: 32)
          else
            Column(
              children: [
                Text(
                  '${challenge.reward}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  '🪙',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
