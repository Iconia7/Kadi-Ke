import 'package:flutter/material.dart';
import '../models/challenge_model.dart';
import '../services/progression_service.dart';

class ChallengeDialog extends StatefulWidget {
  const ChallengeDialog({super.key});

  @override
  State<ChallengeDialog> createState() => _ChallengeDialogState();
}

class _ChallengeDialogState extends State<ChallengeDialog> {
  late List<ChallengeModel> _challenges;

  @override
  void initState() {
    super.initState();
    _challenges = ProgressionService().getChallenges();
  }

  void _claimReward(ChallengeModel challenge) async {
    final success = await ProgressionService().claimChallengeReward(challenge.id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Claimed ${challenge.reward} Coins!"),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _challenges = ProgressionService().getChallenges();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "DAILY CHALLENGES",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ..._challenges.map((c) => _buildChallengeItem(c)).toList(),
            if (_challenges.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text("No challenges available today.", style: TextStyle(color: Colors.white70)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeItem(ChallengeModel challenge) {
    double progress = challenge.progress / challenge.goal;
    bool isCompleted = challenge.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCompleted ? Colors.amber.withOpacity(0.3) : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                challenge.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                "${challenge.reward} 🪙",
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            challenge.description,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.amber : Colors.blueAccent),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (challenge.isClaimed)
                const Icon(Icons.check_circle, color: Colors.green, size: 24)
              else if (isCompleted)
                ElevatedButton(
                  onPressed: () => _claimReward(challenge),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text("CLAIM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else
                Text(
                  "${challenge.progress}/${challenge.goal}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
