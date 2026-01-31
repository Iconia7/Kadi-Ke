import 'package:flutter/material.dart';
import '../services/vps_game_service.dart';

class LeaderboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      appBar: AppBar(
        title: Text("GLOBAL LEADERBOARD", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: VPSGameService().getLeaderboard(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error loading leaderboard\n${snapshot.error}", style: TextStyle(color: Colors.red), textAlign: TextAlign.center));
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Colors.amber));

          final users = snapshot.data!;
          if (users.isEmpty) return Center(child: Text("No players yet.\nBe the first to play!", style: TextStyle(color: Colors.white54, fontSize: 18), textAlign: TextAlign.center));

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final name = user['username'] ?? 'Unknown';
              final wins = user['wins'] ?? 0;
              final isTop3 = index < 3;
              
              Color? rankColor;
              if (index == 0) rankColor = Colors.amber;
              if (index == 1) rankColor = Colors.grey[300];
              if (index == 2) rankColor = Colors.orange[300];

              return Container(
                 margin: EdgeInsets.only(bottom: 12),
                 padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                 decoration: BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: isTop3 ? Border.all(color: rankColor!, width: 2) : Border.all(color: Colors.white10),
                    boxShadow: isTop3 ? [BoxShadow(color: rankColor!.withValues(alpha: 0.3), blurRadius: 10)] : []
                 ),
                 child: Row(
                   children: [
                      Container(
                        width: 40, height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           color: isTop3 ? rankColor : Colors.white10,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                             color: isTop3 ? Colors.black : Colors.white,
                             fontWeight: FontWeight.bold,
                             fontSize: 18
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                             color: Colors.white,
                             fontSize: 18,
                             fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                           color: Colors.green.withValues(alpha: 0.2),
                           borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$wins wins',
                          style: TextStyle(
                             color: Colors.greenAccent,
                             fontWeight: FontWeight.bold,
                             fontSize: 14
                          ),
                        ),
                      )
                   ],
                 ),
              );
            },
          );
        },
      ),
    );
  }
}
