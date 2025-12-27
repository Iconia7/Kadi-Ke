import 'package:flutter/material.dart';
import '../services/progression_service.dart';
import '../services/theme_service.dart';

class PlayingCardWidget extends StatelessWidget {
  final String suit;
  final String rank;
  final bool isFaceDown;
  final double width;
  final double height;

  const PlayingCardWidget({
    required this.suit,
    required this.rank,
    this.isFaceDown = false,
    this.width = 80, 
    this.height = 120,
  });

  String _getImagePath() {
    if (rank.toLowerCase() == 'joker') return 'assets/cards/${suit.toLowerCase()}_joker.png';
    return 'assets/cards/${rank.toLowerCase()}_of_${suit.toLowerCase()}.png';
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Retrieve the active skin from ProgressionService dynamically
    String skinId = 'classic';
    try {
       // Safe call in case service not ready, though GameScreen inits it
       skinId = ProgressionService().getSelectedSkin();
    } catch(e) {
       // ignore
    }
    
    final skinData = CardSkins.getSkin(skinId);

    return Container(
      width: width,   
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child: isFaceDown
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  // FIX: Use colors from skinData
                  colors: [skinData.backGradientStart, skinData.backGradientEnd], 
                ),
                border: Border.all(color: Colors.white12, width: 2),
              ),
              child: Center(
                child: Icon(Icons.videogame_asset, color: Colors.white24, size: 30),
              ),
            )
          : Image.asset(
              _getImagePath(),
              fit: BoxFit.fill,
              errorBuilder: (context, error, stackTrace) {
                // High contrast fallback
                return Container(
                  color: Colors.white,
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          suit == 'hearts' || suit == 'diamonds' ? "♥" : "♠",
                          style: TextStyle(fontSize: 60, color: Colors.black12),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Text(rank.toUpperCase().substring(0,1), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
                            SizedBox(height: 4),
                            Icon(_getSuitIcon(suit), size: 14, color: _getSuitColor(suit)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }

  Color _getSuitColor(String suit) {
    if (suit == 'hearts' || suit == 'diamonds') return Colors.red[800]!;
    return Colors.black;
  }

  IconData _getSuitIcon(String suit) {
    switch (suit.toLowerCase()) {
      case 'hearts': return Icons.favorite;
      case 'diamonds': return Icons.diamond;
      case 'clubs': return Icons.yard; 
      case 'spades': return Icons.eco; 
      default: return Icons.help_outline;
    }
  }
}