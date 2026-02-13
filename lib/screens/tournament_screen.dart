import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'home_screen.dart';

class TournamentScreen extends StatefulWidget {
  final String gameType;
  const TournamentScreen({super.key, this.gameType = 'kadi'});

  @override
  _TournamentScreenState createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  int _currentRound = 0; // 0: Quarter, 1: Semi, 2: Final, 3: Champion
  final List<String> _rounds = ["Quarter Finals", "Semi Finals", "Grand Final"];
  final List<int> _opponents = [3, 1, 1]; // Opponent count for each round
  final List<String> _difficulties = ['easy', 'medium', 'hard'];
  
  bool _isRoundActive = false;
  String? _championMessage;

  void _startNextMatch() async {
    while (_currentRound < _rounds.length) {
      if (!mounted) return;
      setState(() => _isRoundActive = true);

      // Push GameScreen and wait for result
      final result = await Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => GameScreen(
             isHost: false, 
             hostAddress: 'offline',
             aiCount: _opponents[_currentRound], 
             difficulty: _difficulties[_currentRound],
             gameType: widget.gameType,
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
            // Loop continues to next match
         }
      } else {
         _showLossDialog();
         break;
      }
    }
  }

  void _showVictoryOverlay() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Round Cleared! Advancing to ${_rounds[_currentRound]}..."),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      )
    );
  }

  void _showVictoryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: Color(0xFF1E293B),
        title: Text("Round Cleared!", style: TextStyle(color: Colors.greenAccent)),
        content: Text("You advanced to the ${_rounds[_currentRound]}.", style: TextStyle(color: Colors.white)),
        actions: [
           TextButton(
             onPressed: () => Navigator.pop(c),
             child: Text("NEXT MATCH"),
           )
        ],
      )
    );
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
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      appBar: AppBar(
        title: Text("🏆 ${widget.gameType.toUpperCase()} TOURNAMENT"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: _championMessage != null 
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Icon(Icons.emoji_events, size: 100, color: Colors.amber),
                 SizedBox(height: 20),
                 Text(_championMessage!, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                 SizedBox(height: 40),
                 ElevatedButton(onPressed: () => Navigator.pop(context), child: Text("RETURN HOME"))
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 // Bracket Visualizer (Simplified)
                 _buildBracketNode("Quarter Finals", _currentRound >= 0, _currentRound > 0),
                 _buildConnector(),
                 _buildBracketNode("Semi Finals", _currentRound >= 1, _currentRound > 1),
                 _buildConnector(),
                 _buildBracketNode("Grand Final", _currentRound >= 2, _currentRound > 2),
                 
                 SizedBox(height: 60),

                 if (!_isRoundActive)
                   ElevatedButton(
                     onPressed: _startNextMatch,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.amber, 
                       padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                     ),
                     child: Text("PLAY ${_rounds[min(_currentRound, 2)].toUpperCase()}", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                   )
              ],
            ),
       ),
    );
  }

  Widget _buildBracketNode(String title, bool unlocked, bool completed) {
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
    return Container(
       height: 30,
       width: 2,
       color: Colors.white24,
    );
  }
  
  int min(int a, int b) => a < b ? a : b;
}
