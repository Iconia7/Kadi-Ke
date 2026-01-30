import 'package:flutter/material.dart';
import '../services/firebase_game_service.dart';

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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseGameService().getLeaderboard(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error loading stats", style: TextStyle(color: Colors.red)));
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Colors.amber));

          final users = snapshot.data!;
          if (users.isEmpty) return Center(child: Text("No data yet.", style: TextStyle(color: Colors.white54)));

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final name = user['name'] ?? 'Unknown';
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
                           color: isTop3 ? rankColor : Colors.white10,
                           shape: BoxShape.circle
                        ),
                        child: Text(
                          "#${index + 1}", 
                          style: TextStyle(
                            color: isTop3 ? Colors.black : Colors.white, 
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(name, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                           Text("$wins WINS", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        ],
                      )
                   ],
                 ),
              );
            },
          );
        },
      )
    );
  }
}
