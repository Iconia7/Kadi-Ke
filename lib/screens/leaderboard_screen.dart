import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/vps_game_service.dart';
import '../services/custom_auth_service.dart';

class LeaderboardScreen extends StatefulWidget {
  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<Map<String, dynamic>>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = VPSGameService().getLeaderboard();
  }

  void _refresh() {
    setState(() {
      _leaderboardFuture = VPSGameService().getLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("GLOBAL RANKINGS", style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: Colors.amber), onPressed: _refresh),
        ],
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _leaderboardFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error loading leaderboard\n${snapshot.error}", style: TextStyle(color: Colors.red), textAlign: TextAlign.center));
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Colors.amber));

          final users = snapshot.data!;
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.people_outline, size: 64, color: Colors.white24),
                   SizedBox(height: 16),
                   Text("No players found yet.\nBe the first to play!", style: TextStyle(color: Colors.white54, fontSize: 18), textAlign: TextAlign.center),
                   SizedBox(height: 24),
                   ElevatedButton(onPressed: _refresh, child: Text("REFRESH"))
                ],
              )
            );
          }

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 120, 16, 16),
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

              return ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: isTop3 ? rankColor!.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isTop3 ? rankColor!.withOpacity(0.5) : Colors.white.withOpacity(0.05),
                        width: isTop3 ? 2 : 1
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isTop3 
                              ? LinearGradient(colors: [rankColor!, rankColor.withOpacity(0.6)])
                              : null,
                            color: isTop3 ? null : Colors.white10,
                            image: user['avatar'] != null 
                               ? DecorationImage(
                                   image: NetworkImage('${CustomAuthService().baseUrl}${user['avatar']}'),
                                   fit: BoxFit.cover
                                 )
                               : null,
                            boxShadow: isTop3 ? [BoxShadow(color: rankColor!.withOpacity(0.4), blurRadius: 12)] : [],
                          ),
                          child: user['avatar'] != null ? null : (isTop3 && index == 0
                            ? Icon(Icons.emoji_events, color: Colors.black, size: 24)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isTop3 ? Colors.black : Colors.white60,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20
                                ),
                              )),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: isTop3 ? FontWeight.w900 : FontWeight.bold,
                                  letterSpacing: 0.5
                                ),
                              ),
                              if (isTop3)
                                Text(
                                  index == 0 ? "Grandmaster" : (index == 1 ? "Elite Player" : "Rising Star"),
                                  style: TextStyle(color: rankColor!.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$wins',
                              style: TextStyle(
                                color: isTop3 ? rankColor : Colors.greenAccent,
                                fontWeight: FontWeight.w900,
                                fontSize: 24
                              ),
                            ),
                            Text("WINS", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
        },
      ),
    );
  }
}
