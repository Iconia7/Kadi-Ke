import 'package:flutter/material.dart';
import 'dart:convert';
import 'game_screen.dart';
import 'home_screen.dart';
import '../services/vps_game_service.dart';
import '../services/custom_auth_service.dart';
import '../models/tournament_model.dart';
import '../widgets/custom_toast.dart';
import '../widgets/friend_invite_bottom_sheet.dart';
import '../services/progression_service.dart';
class TournamentScreen extends StatefulWidget {
  final String gameType;
  final String? tournamentId;
  final bool isHost;
  final Tournament? initialTournament;
  
  const TournamentScreen({
    super.key, 
    this.gameType = 'kadi',
    this.tournamentId,
    this.isHost = false,
    this.initialTournament,
  });

  @override
  _TournamentScreenState createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  // Offline State
  int _currentRound = 0; 
  final List<String> _rounds = ["Quarter Finals", "Semi Finals", "Grand Final"];
  final List<int> _opponents = [3, 1, 1]; 
  final List<String> _difficulties = ['easy', 'medium', 'hard'];
  bool _isRoundActive = false;
  String? _championMessage;

  // Online State
  Tournament? _tournament;
  String? _myUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _myUserId = CustomAuthService().userId;
    
    if (widget.initialTournament != null) {
       _tournament = widget.initialTournament;
       _isLoading = false;
       _setupTournamentStream();
    } else if (widget.tournamentId != null) {
       _setupTournamentStream();
    } else {
       // Offline mode - ready immediately
       setState(() => _isLoading = false);
    }
  }
  
  void _setupTournamentStream() {
    VPSGameService().gameStream.listen((message) {
       if (!mounted) return;
       
       if (message['type'] == 'TOURNAMENT_UPDATED' || 
           message['type'] == 'TOURNAMENT_STARTED' ||
           message['type'] == 'TOURNAMENT_ROUND_ADVANCED') {
           
           setState(() {
              _tournament = Tournament.fromJson(message['data']);
              _isLoading = false;
           });
           
           if (message['type'] == 'TOURNAMENT_STARTED' || message['type'] == 'TOURNAMENT_ROUND_ADVANCED') {
              // Automatically check if I have an active match and prompt me
              _checkMyActiveMatch();
           }
       } else if (message['type'] == 'TOURNAMENT_FINISHED') {
           setState(() {
              _tournament = Tournament.fromJson(message['data']['tournamentData']);
              _championMessage = "🏆 ${message['data']['championName']} WON! 🏆\nPrize: 🪙 ${message['data']['prizePool']}";
              _isLoading = false;
           });
       }
    });
  }

  void _checkMyActiveMatch() {
     if (_tournament == null || _myUserId == null) return;
     
     // Find if I have a pending match in the current highest round
     TournamentMatch? myMatch;
     int highestRound = 0;
     for (var m in _tournament!.matches) {
       if (m.round > highestRound) highestRound = m.round;
     }
     
     for (var m in _tournament!.matches) {
        if (m.round == highestRound && m.status != 'finished' && m.playerIds.contains(_myUserId)) {
           myMatch = m;
           break;
        }
     }
     
     if (myMatch != null && !_isRoundActive) {
        // I have a match to play!
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text("Your match is ready!"),
           backgroundColor: Colors.amber,
           duration: Duration(seconds: 4),
           action: SnackBarAction(label: "JOIN", textColor: Colors.black, onPressed: () => _joinMatch(myMatch!)),
        ));
     }
  }

  void _joinMatch(TournamentMatch match) async {
      if (!mounted) return;
      setState(() => _isRoundActive = true);
      
      // DESIGNATE HOST: The first player in the match list is the host
      // If the list is empty/player missing, effectively nobody is host (fallback)
      bool isMatchHost = match.playerIds.isNotEmpty && match.playerIds.first == _myUserId;

      final result = await Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => GameScreen(
             isHost: isMatchHost, 
             hostAddress: 'online',
             onlineGameCode: match.id, // The match ID is the GameRoom code
             gameType: _tournament!.gameMode,
             isTournament: true,
          )
        )
      );
      
      if (mounted) setState(() => _isRoundActive = false);
      
      // If the player won the match, explicitly report it to the backend to advance the bracket
      if (result == 'WON' && _tournament != null && _myUserId != null) {
          VPSGameService().reportTournamentMatch(
             _tournament!.id, 
             match.id, 
             _myUserId!
          );
      }
  }

  void _startHostTournament() {
     if (widget.tournamentId != null && widget.isHost) {
        VPSGameService().startTournament(widget.tournamentId!);
     }
  }

  // --- OFFLINE LOGIC ---
  void _startNextOfflineMatch() async {
    while (_currentRound < _rounds.length) {
      if (!mounted) return;
      setState(() => _isRoundActive = true);

      final result = await Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => GameScreen(
             isHost: true, 
             hostAddress: 'offline',
             aiCount: _opponents[_currentRound], 
             difficulty: _difficulties[_currentRound],
             gameType: widget.gameType,
             isTournament: true,
          )
        )
      );

      if (!mounted) return;
      setState(() => _isRoundActive = false);

      if (result == 'WON') {
         if (_currentRound == 2) {
            setState(() {
              _championMessage = "🏆 YOU ARE THE CHAMPION! 🏆";
              _currentRound++;
            });
            break;
         } else {
            setState(() => _currentRound++);
            _showVictoryOverlay();
            await Future.delayed(Duration(seconds: 2));
         }
      } else {
         _showLossDialog();
         break;
      }
    }
  }

  void _showVictoryOverlay() {
    CustomToast.show(context, "Round Cleared! Advancing to ${_rounds[_currentRound]}...");
  }

  void _showLossDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: Color(0xFF1E293B),
        title: Text("Eliminated!", style: TextStyle(color: Colors.redAccent)),
        content: Text("Better luck next time.", style: TextStyle(color: Colors.white)),
        actions: [
           TextButton(
             onPressed: () {
                Navigator.pop(c);
                Navigator.pop(context); // Exit tournament
             },
             child: Text("EXIT"),
           )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(child: CircularProgressIndicator(color: Colors.amber)),
       );
    }

    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(_tournament != null ? _tournament!.name : "🏆 ${widget.gameType.toUpperCase()} TOURNAMENT"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_tournament != null && _tournament!.status == 'recruiting') {
              _refundTournamentFee();
              CustomToast.show(context, "Tournament entry holding refunded.");
            }
            Navigator.pop(context);
          },
        ),
        actions: [
           if (_tournament != null)
             Center(child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Text("Prize: 🪙 ${_tournament!.prizePool}", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
             ))
        ],
      ),
      body: _tournament != null ? _buildOnlineView() : _buildOfflineView(),
    );
  }

  Widget _buildOnlineView() {
     if (_championMessage != null) return _buildChampionView();

     if (_tournament!.status == 'recruiting') {
        return _buildLobbyScreen();
     }
     
     return _buildInteractiveBracket();
  }

  Widget _buildLobbyScreen() {
     return Padding(
       padding: const EdgeInsets.all(24.0),
       child: Column(
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text("LOBBY: ${_tournament!.id}", style: TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 2, fontWeight: FontWeight.bold)),
                     Text("Share this code with friends", style: TextStyle(color: Colors.white54)),
                   ],
                 ),
                 if (widget.isHost)
                   IconButton(
                     icon: Icon(Icons.person_add, color: Colors.blueAccent, size: 30),
                     onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) => Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: FriendInviteBottomSheet(
                              roomCode: _tournament!.id,
                              gameMode: widget.gameType,
                            ),
                          ),
                        );
                     },
                     tooltip: "Invite Friends",
                   ),
               ],
             ),
             SizedBox(height: 30),
             
             Expanded(
                child: GridView.builder(
                   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 20),
                   itemCount: _tournament!.currentPlayers.length,
                   itemBuilder: (context, index) {
                      String pid = _tournament!.currentPlayers[index];
                      return Column(
                         children: [
                            CircleAvatar(radius: 30, backgroundColor: Colors.blueAccent, child: Icon(Icons.person, color: Colors.white)),
                            SizedBox(height: 8),
                            Text(pid == _myUserId ? "You" : "Player", style: TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
                         ],
                      );
                   },
                )
             ),
             
             Text("${_tournament!.currentPlayers.length} / ${_tournament!.maxPlayers} Players Joined", style: TextStyle(color: Colors.amber)),
             SizedBox(height: 20),
             
             if (widget.isHost)
               ElevatedButton(
                 onPressed: _tournament!.currentPlayers.length >= 2 ? _startHostTournament : null,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.greenAccent,
                   minimumSize: Size(double.infinity, 50)
                 ),
                 child: Text("START TOURNAMENT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
               )
             else
               Text("Waiting for host to start...", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic))
          ],
       ),
     );
  }

  Widget _buildInteractiveBracket() {
      // Group matches by round
      Map<int, List<TournamentMatch>> roundsMap = {};
      for (var m in _tournament!.matches) {
         if (!roundsMap.containsKey(m.round)) roundsMap[m.round] = [];
         roundsMap[m.round]!.add(m);
      }
      
      List<int> sortedRounds = roundsMap.keys.toList()..sort();

      return SingleChildScrollView(
         scrollDirection: Axis.horizontal,
         padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
         child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: sortedRounds.map((r) {
               bool isLastRound = r == sortedRounds.last;
               return Row(
                  children: [
                      Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                            Text("Round $r", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                            SizedBox(height: 16),
                            ...roundsMap[r]!.map((match) => _buildOnlineMatchNode(match)).toList()
                         ],
                      ),
                      if (!isLastRound)
                        Padding(
                           padding: EdgeInsets.symmetric(horizontal: 20),
                           child: Container(width: 40, height: 2, color: Colors.white24),
                        )
                  ],
               );
            }).toList()
         ),
      );
  }

  Widget _buildOnlineMatchNode(TournamentMatch match) {
     bool isMyMatch = match.playerIds.contains(_myUserId);
     bool isFinished = match.status == 'finished';
     bool isWin = match.winnerId == _myUserId;
     
     Color nodeColor = Colors.white10;
     Color borderColor = Colors.white12;
     
     if (isFinished) {
        nodeColor = isMyMatch ? (isWin ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)) : Colors.grey.withOpacity(0.2);
        borderColor = isMyMatch ? (isWin ? Colors.green : Colors.red) : Colors.grey;
     } else if (isMyMatch) {
        nodeColor = Colors.amber.withOpacity(0.2);
        borderColor = Colors.amber;
     }
     
     return Container(
         width: 180,
         margin: EdgeInsets.symmetric(vertical: 8),
         decoration: BoxDecoration(
            color: nodeColor,
            border: Border.all(color: borderColor, width: isMyMatch && !isFinished ? 2 : 1),
            borderRadius: BorderRadius.circular(12)
         ),
         child: Column(
            children: [
               Container(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                  child: Center(
                     child: Text(
                        isFinished ? (match.winnerId == null ? "DRAW" : "Winner ID: ${match.winnerId!.substring(0,min(4, match.winnerId!.length))}") : "Vs",
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)
                     ),
                  )
               ),
               Padding(
                  padding: EdgeInsets.all(8),
                  child: Wrap(
                     alignment: WrapAlignment.center,
                     spacing: 4, runSpacing: 4,
                     children: match.playerIds.map((id) => CircleAvatar(
                        radius: 12,
                        backgroundColor: id == _myUserId ? Colors.amber : Colors.blueAccent,
                        child: Text(id.substring(0,1), style: TextStyle(color: Colors.white, fontSize: 10)),
                     )).toList()
                  ),
               ),
               if (isMyMatch && !isFinished)
                 InkWell(
                    onTap: () => _joinMatch(match),
                    child: Container(
                       padding: EdgeInsets.symmetric(vertical: 6),
                       decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.vertical(bottom: Radius.circular(10))),
                       child: Center(child: Text("JOIN GAME", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))),
                    ),
                 )
            ],
         ),
     );
  }

  Widget _buildOfflineView() {
    return Center(
        child: _championMessage != null 
          ? _buildChampionView()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 _buildOfflineBracketNode("Quarter Finals", _currentRound >= 0, _currentRound > 0),
                 _buildConnector(),
                 _buildOfflineBracketNode("Semi Finals", _currentRound >= 1, _currentRound > 1),
                 _buildConnector(),
                 _buildOfflineBracketNode("Grand Final", _currentRound >= 2, _currentRound > 2),
                 
                 SizedBox(height: 60),

                 if (!_isRoundActive)
                   ElevatedButton(
                     onPressed: _startNextOfflineMatch,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.amber, 
                       padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                     ),
                     child: Text("PLAY ${_rounds[min(_currentRound, 2)].toUpperCase()}", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                   )
              ],
            ),
       );
  }

  Widget _buildChampionView() {
     return Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
          Icon(Icons.emoji_events, size: 100, color: Colors.amber),
          SizedBox(height: 20),
          Text(_championMessage!, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          SizedBox(height: 40),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text("RETURN TO HOME"))
       ],
     );
  }

  Widget _buildOfflineBracketNode(String title, bool unlocked, bool completed) {
     return Container(
        width: 200,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
           color: completed ? Colors.green.withOpacity(0.2) : (unlocked ? Colors.blue.withOpacity(0.2) : Colors.white10),
           border: Border.all(color: completed ? Colors.green : (unlocked ? Colors.blue : Colors.white12)),
           borderRadius: BorderRadius.circular(12)
        ),
        child: Center(
           child: Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
                if (completed) Icon(Icons.check_circle, color: Colors.green, size: 20),
                if (completed) SizedBox(width: 8),
                Text(title, style: TextStyle(color: unlocked ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
             ],
           )
        ),
     );
  }
  
  Widget _buildConnector() {
    return Container(height: 30, width: 2, color: Colors.white24);
  }
  
  @override
  void dispose() {
    // Safety refund if not already handled by back button
    if (_tournament != null && _tournament!.status == 'recruiting') {
      _refundTournamentFee();
    }
    super.dispose();
  }

  void _refundTournamentFee() {
    if (_tournament != null && _tournament!.entryFee > 0) {
      ProgressionService().addCoins(_tournament!.entryFee);
      print("Refunded ${_tournament!.entryFee} coins for tournament exit.");
    }
  }

  int min(int a, int b) => a < b ? a : b;
}

