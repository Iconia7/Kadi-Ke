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
      backgroundColor: const Color(0xFF0F172A),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _leaderboardFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text("Error loading leaderboard\n${snapshot.error}",
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center));
          }
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.amber));
          }

          final users = snapshot.data!;
          if (users.isEmpty) {
            return Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline,
                    size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                const Text("No players found yet.\nBe the first to play!",
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _refresh, child: const Text("REFRESH"))
              ],
            ));
          }

          final topThree = users.take(3).toList();
          final remaining = users.skip(3).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Slivers AppBar
              SliverAppBar(
                backgroundColor: Colors.transparent,
                expandedHeight: topThree.isNotEmpty ? 360 : 100, // Make room for podium
                pinned: true,
                elevation: 0,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: FlexibleSpaceBar(
                      title: const Text("GLOBAL RANKINGS",
                          style: TextStyle(
                              letterSpacing: 4,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.white)),
                      centerTitle: true,
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          ),
                        ),
                        child: topThree.isNotEmpty
                            ? SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 60.0),
                                  child: _buildPodium(topThree),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.amber),
                      onPressed: _refresh),
                ],
              ),

              // The sleek list for rank 4+
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildRankCard(remaining[index], index + 4);
                    },
                    childCount: remaining.length,
                  ),
                ),
              ),
              
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> topThree) {
    // 2nd Place, 1st Place, 3rd Place Layout
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          if (topThree.length > 1)
            Expanded(
              child: _buildPodiumColumn(topThree[1], 2, Colors.blueGrey[300]!, 120, "Elite"),
            ),
          
          // 1st Place
          if (topThree.isNotEmpty)
            Expanded(
              flex: 1, // Give center slightly more presence implicitly due to sizes
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildPodiumColumn(topThree[0], 1, Colors.amber, 160, "Grandmaster", isFirst: true),
              ),
            ),
            
          // 3rd Place
          if (topThree.length > 2)
            Expanded(
              child: _buildPodiumColumn(topThree[2], 3, Colors.deepOrange[300]!, 100, "Rising Star"),
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(Map<String, dynamic> user, int rank, Color color, double height, String title, {bool isFirst = false}) {
    final avatar = user['avatar'];
    final name = user['username'] ?? 'Unknown';
    final wins = user['wins'] ?? 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Avatar with Crown/Aura
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: isFirst ? 80 : 64,
              height: isFirst ? 80 : 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: isFirst ? 3 : 2),
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: isFirst ? 20 : 10)],
                image: avatar != null
                    ? DecorationImage(
                        image: NetworkImage('${CustomAuthService().baseUrl}$avatar'),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.black45,
              ),
              child: avatar == null
                  ? Icon(Icons.person, size: isFirst ? 40 : 30, color: Colors.white54)
                  : null,
            ),
            // Crown/Medal icon on top
            Positioned(
              top: isFirst ? -20 : -15,
              child: Icon(
                isFirst ? Icons.workspace_premium : Icons.stars,
                color: color,
                size: isFirst ? 36 : 28,
              ),
            ),
            // Rank badge at bottom right
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text('#$rank', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(name, style: TextStyle(color: Colors.white, fontWeight: isFirst ? FontWeight.w900 : FontWeight.bold, fontSize: isFirst ? 16 : 14), overflow: TextOverflow.ellipsis),
        Text(title, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        
        // Podium Pillar
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.4),
                color.withOpacity(0.1),
                Colors.transparent
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(
              top: BorderSide(color: color, width: 2),
              left: BorderSide(color: color.withOpacity(0.5), width: 1),
              right: BorderSide(color: color.withOpacity(0.5), width: 1),
            )
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$wins',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: isFirst ? 28 : 22,
                ),
              ),
              const Text("WINS", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankCard(Map<String, dynamic> user, int rank) {
    final name = user['username'] ?? 'Unknown';
    final wins = user['wins'] ?? 0;
    final avatar = user['avatar'];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Rank Number
              SizedBox(
                width: 30,
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Avatar
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white10,
                  image: avatar != null
                      ? DecorationImage(
                          image: NetworkImage('${CustomAuthService().baseUrl}$avatar'),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatar == null
                    ? const Icon(Icons.person, color: Colors.white54)
                    : null,
              ),
              
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      "Veteran", // Placeholder for dynamic titles if needed for rank4+
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              
              // Wins
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$wins',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const Text("WINS", style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
