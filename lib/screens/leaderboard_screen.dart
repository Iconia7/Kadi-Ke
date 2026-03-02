import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/vps_game_service.dart';
import '../services/custom_auth_service.dart';
import '../widgets/custom_avatar.dart';

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
          final myId = CustomAuthService().userId;
          final myUserEntry = users.any((u) => u['userId'] == myId) 
              ? users.firstWhere((u) => u['userId'] == myId) 
              : null;
          final myRank = myUserEntry != null ? users.indexOf(myUserEntry) + 1 : null;

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

          return Stack(
            children: [
              CustomScrollView(
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
                                      child: _buildPodium(topThree, myId),
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
                          final user = remaining[index];
                          final isMe = user['userId'] == myId;
                          return _buildRankCard(user, index + 4, isMe: isMe);
                        },
                        childCount: remaining.length,
                      ),
                    ),
                  ),
                  
                  // Bottom padding for sticky card
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),

              // Sticky "My Rank" Card
              if (myUserEntry != null)
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: _buildStickyMyRank(myUserEntry, myRank!),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> topThree, String? myId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          if (topThree.length > 1)
            Expanded(
              child: _buildPodiumColumn(topThree[1], 2, Colors.blueGrey[300]!, 120, "Elite", isMe: topThree[1]['userId'] == myId),
            ),
          
          // 1st Place
          if (topThree.isNotEmpty)
            Expanded(
              flex: 1, 
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildPodiumColumn(topThree[0], 1, Colors.amber, 160, "Grandmaster", isFirst: true, isMe: topThree[0]['userId'] == myId),
              ),
            ),
            
          // 3rd Place
          if (topThree.length > 2)
            Expanded(
              child: _buildPodiumColumn(topThree[2], 3, Colors.deepOrange[300]!, 100, "Rising Star", isMe: topThree[2]['userId'] == myId),
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(Map<String, dynamic> user, int rank, Color color, double height, String title, {bool isFirst = false, bool isMe = false}) {
    final avatar = user['avatar'];
    final name = user['username'] ?? 'Unknown';
    final wins = user['wins'] ?? 0;
    final mmr = user['mmr'] ?? 1000;
    final rankTier = user['rankTier'] ?? 'Bronze I';

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Avatar with Crown/Aura
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            CustomAvatar(
              overrideAvatarUrl: avatar,
              overrideFrameId: user['frameId'],
              radius: isFirst ? 40 : 32,
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
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            rankTier.toUpperCase(),
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
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
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
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
              const SizedBox(height: 12),
              Text(
                '$mmr',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: isFirst ? 18 : 14,
                ),
              ),
              const Text("MMR", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankCard(Map<String, dynamic> user, int rank, {bool isMe = false}) {
    final name = user['username'] ?? 'Unknown';
    final wins = user['wins'] ?? 0;
    final mmr = user['mmr'] ?? 1000;
    final rankTier = user['rankTier'] ?? 'Bronze I';
    final avatar = user['avatar'];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isMe ? Colors.amber.withOpacity(0.1) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMe ? Colors.amber.withOpacity(0.5) : Colors.white.withOpacity(0.05),
              width: isMe ? 2 : 1,
            ),
            boxShadow: isMe ? [BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 10)] : null,
          ),
          child: Row(
            children: [
              // Rank Number
              SizedBox(
                width: 30,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: isMe ? Colors.amber : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Avatar
              CustomAvatar(
                overrideAvatarUrl: avatar,
                overrideFrameId: user['frameId'],
                radius: 20,
              ),
              
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: isMe ? Colors.amber : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "YOU",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      rankTier.toUpperCase(), 
                      style: TextStyle(color: isMe ? Colors.amber.withOpacity(0.6) : Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
              
              // Wins & MMR
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$wins',
                    style: TextStyle(
                      color: isMe ? Colors.amber : Colors.greenAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const Text("WINS", style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '$mmr',
                    style: TextStyle(
                      color: isMe ? Colors.amber.withOpacity(0.8) : Colors.blueAccent.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Text("MMR", style: TextStyle(color: Colors.white24, fontSize: 7, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickyMyRank(Map<String, dynamic> user, int rank) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              CustomAvatar(
                overrideAvatarUrl: user['avatar'],
                overrideFrameId: user['frameId'],
                radius: 25,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("YOUR GLOBAL RANKING", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    Row(
                      children: [
                        Text(
                          "#$rank",
                          style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withOpacity(0.3)),
                          ),
                          child: Text(
                            (user['rankTier'] ?? 'Bronze I').toString().toUpperCase(),
                            style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${user['wins']}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const Text("WINS", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("${user['mmr'] ?? 1000}", style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                  const Text("MMR", style: TextStyle(color: Colors.white38, fontSize: 7, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
