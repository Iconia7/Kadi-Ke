import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';
import '../services/deck_service.dart';
import '../widgets/playing_card_widget.dart';
import 'home_screen.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      TutorialService().setCurrentStep(_currentStep);
    } else {
      _completeTutorial();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      TutorialService().setCurrentStep(_currentStep);
    }
  }

  void _skipTutorial() {
    _completeTutorial();
  }

  void _completeTutorial() async {
    await TutorialService().markTutorialComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with Skip button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tutorial',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: _skipTutorial,
                      child: Text(
                        'Skip',
                        style: TextStyle(color: Color(0xFF00E5FF)),
                      ),
                    ),
                  ],
                ),
              ),

              // Progress Indicator
              _buildProgressIndicator(),

              // Page View
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => setState(() => _currentStep = index),
                  children: [
                    _buildStep1Welcome(),
                    _buildStep2CardMeanings(),
                    _buildStep3PlayingCards(),
                    _buildStep4NikoKadi(),
                    _buildStep5WinningConditions(),
                  ],
                ),
              ),

              // Navigation Buttons
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            width: index == _currentStep ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: index <= _currentStep ? Color(0xFF00E5FF) : Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1Welcome() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Image.asset(
              'assets/Kadi.png',
              width: 120,
              height: 120,
            ),
          ),
          SizedBox(height: 32),
          Text(
            'Welcome to Kadi! 🇰🇪',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          _buildInfoCard(
            '🎯 Goal',
            'Be the first to get rid of all your cards!',
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            '🃏 How to Play',
            'Match the suit OR rank of the top card. Play special cards to change the game.',
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            '⚠️ Important',
            'Say "Niko Kadi" when you have ONE card left, or pick 2 penalty cards!',
          ),
          SizedBox(height: 24),
          Text(
            'Let\'s learn the basics →',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2CardMeanings() {
    final cardMeanings = [
      {'card': 'J (Jack)', 'rank': 'jack', 'suit': 'spades', 'effect': '⏭️ Skip next player. Can be used to block bombs!', 'color': Colors.orange},
      {'card': 'K (King)', 'rank': 'king', 'suit': 'hearts', 'effect': '🔄 Reverse turn direction. Returns bombs to sender!', 'color': Colors.purple},
      {'card': 'Q (Queen)', 'rank': 'queen', 'suit': 'diamonds', 'effect': '❓ Question! Player must answer or pick cards. You keep your turn.', 'color': Colors.pink},
      {'card': '8 (Eight)', 'rank': '8', 'suit': 'clubs', 'effect': '❓ Question! Works like Queen but with different suits.', 'color': Colors.pink},
      {'card': '2 (Two)', 'rank': '2', 'suit': 'spades', 'effect': '💣 Bomb! Adds +2 cards to the next player. Can be stacked!', 'color': Colors.red},
      {'card': '3 (Three)', 'rank': '3', 'suit': 'hearts', 'effect': '💣 Super Bomb! Adds +3 cards. Stacks with Twos and Jokers!', 'color': Colors.red},
      {'card': 'A (Ace)', 'rank': 'ace', 'suit': 'spades', 'effect': '🎯 Request: Change suit/rank. Spades Ace LOCKS the game if it is your second-to-last card!', 'color': Colors.blue},
      {'card': 'Joker', 'rank': 'joker', 'suit': 'red', 'effect': '🃏 Mega Bomb! +5 cards. Next player must pick OR match the Joker\'s color!', 'color': Colors.amber},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🃏 Special Cards',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'These cards have special powers:',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 24),
          ...cardMeanings.map((meaning) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (meaning['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (meaning['color'] as Color).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Actual Card Preview
                      PlayingCardWidget(
                        rank: meaning['rank'] as String,
                        suit: meaning['suit'] as String,
                        width: 60,
                        height: 84,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meaning['card'] as String,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              meaning['effect'] as String,
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStep3PlayingCards() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎮 How to Play',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),
          _buildInfoCard(
            '1️⃣ Your Turn',
            'When it\'s your turn, you can play any card that matches the top card\'s suit OR rank.',
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            '2️⃣ No Match?',
            'If you don\'t have a matching card, tap the "PICK" button to draw from the deck.',
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            '3️⃣ Multi-Drop & Chaining',
            'Play multiple cards of the same rank! You can also CHAIN Questions (Q or 8) to keep your turn.',
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            '4️⃣ Defense & Stacking',
            'Aces block bombs. Kings & Jacks pass/return them. Bombs (2, 3, Joker) stack up for massive penalties!',
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF00E5FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFF00E5FF).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Color(0xFF00E5FF)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: Watch the top card closely! It shows what you need to match.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4NikoKadi() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔔 Niko Kadi Rule',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),
          Center(
            child: Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent, width: 3),
              ),
              child: Text(
                '⚠️',
                style: TextStyle(fontSize: 64),
              ),
            ),
          ),
          SizedBox(height: 32),
          _buildInfoCard(
            '📢 When to Say It',
            'You MUST say "Niko Kadi" when you have exactly ONE card left in your hand.',
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            '⏰ How to Say It',
            'Tap the "Niko Kadi" button at the bottom before playing your second-to-last card.',
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            '💥 Penalty',
            'Forget to say it? You\'ll have to pick 2 penalty cards!',
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.withOpacity(0.3), Colors.orange.withOpacity(0.3)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 32),
                SizedBox(height: 8),
                Text(
                  'This is the most important rule in Kadi!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5WinningConditions() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🏆 How to Win',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),
          _buildInfoCard(
            '✅ Win Condition',
            'Get rid of all your cards before anyone else!',
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            '❌ Power Card Rule',
            'You CANNOT win by playing a power card (J, K, Q, 8, 2, 3, A, Joker) as your last card.',
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            '🎯 Valid Winning Cards',
            'Only number cards (4, 5, 6, 7, 9, 10) can be used to win the game.',
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF00E5FF).withOpacity(0.2),
                  Colors.green.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF00E5FF)),
            ),
            child: Column(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 48),
                SizedBox(height: 16),
                Text(
                  'You\'re Ready to Play!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Master these rules and dominate the table! 🇰🇪',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String description) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Color(0xFF00E5FF),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: _previousStep,
              icon: Icon(Icons.arrow_back),
              label: Text('Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white24),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            )
          else
            SizedBox(width: 100),
          ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Row(
              children: [
                Text(
                  _currentStep == 4 ? 'Start Playing' : 'Next',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(width: 8),
                Icon(_currentStep == 4 ? Icons.check : Icons.arrow_forward),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
