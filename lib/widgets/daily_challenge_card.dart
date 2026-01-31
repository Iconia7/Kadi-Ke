import 'package:flutter/material.dart';
import '../services/challenge_service.dart';

class DailyChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback onClaim;

  const DailyChallengeCard({
    Key? key,
    required this.challenge,
    required this.onClaim,
  }) : super(key: key);

  IconData _getChallengeIcon() {
    switch (challenge.type) {
      case 'wins':
        return Icons.emoji_events;
      case 'bombs_played':
        return Icons.whatshot;
      case 'cards_played':
        return Icons.style;
      case 'quick_win':
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
            Color(0xFF1E293B).withOpacity(0.8),
            Color(0xFF334155).withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: challenge.isCompleted
              ? Color(0xFF00E5FF)
              : Colors.white.withOpacity(0.1),
          width: challenge.isCompleted ? 2 : 1,
        ),
        boxShadow: challenge.isCompleted
            ? [
                BoxShadow(
                  color: Color(0xFF00E5FF).withOpacity(0.3),
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
                  ? Color(0xFF00E5FF).withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getChallengeIcon(),
              color: challenge.isCompleted ? Color(0xFF00E5FF) : Colors.white54,
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
                  style: TextStyle(
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
                      widthFactor: challenge.progressPercent,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
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
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Reward / Claim button
          if (challenge.isCompleted && !challenge.claimed)
            ElevatedButton(
              onPressed: onClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00E5FF),
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
                    '${challenge.coinReward} 🪙',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            )
          else if (challenge.claimed)
            Icon(Icons.check_circle, color: Color(0xFF00E5FF), size: 32)
          else
            Column(
              children: [
                Text(
                  '${challenge.coinReward}',
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
