import 'package:flutter/material.dart';

class DailyRewardDialog extends StatelessWidget {
  final int streak;
  final int reward;
  final VoidCallback onClose;

  const DailyRewardDialog({
    Key? key,
    required this.streak,
    required this.reward,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Glow
          Container(
            width: 300,
            height: 400,
            decoration: BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amber, width: 2),
              boxShadow: [
                 BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 40, spreadRadius: 5)
              ]
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange, size: 60),
                SizedBox(height: 10),
                Text("DAILY STREAK", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                SizedBox(height: 5),
                Text("$streak Days", style: TextStyle(color: Colors.orange, fontSize: 32, fontWeight: FontWeight.bold)),
                
                SizedBox(height: 30),
                
                Text("REWARD", style: TextStyle(color: Colors.white54, fontSize: 14)),
                SizedBox(height: 10),
                Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                      Icon(Icons.monetization_on, color: Colors.amber, size: 30),
                      SizedBox(width: 10),
                      Text("+$reward", style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                   ],
                ),
                
                SizedBox(height: 40),
                
                ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                  ),
                  child: Text("CLAIM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                )
              ],
            ),
          ),
          
          // Confetti (Simplified manual particles or just rely on Lottie/Confetti widget if available globally. 
          // Since we used Confetti in GameScreen, we might need a controller here, but let's keep it static for now to avoid complexity)
        ],
      ),
    );
  }
}
