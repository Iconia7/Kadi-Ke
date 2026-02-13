import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.style,
      title: 'Welcome to Kadi KE',
      description: 'Experience the most exciting card game with friends online or locally!',
      color: Colors.deepPurple,
    ),
    OnboardingPage(
      icon: Icons.group,
      title: 'Play with Friends',
      description: 'Challenge friends in multiplayer mode, host LAN games, or play online with players worldwide.',
      color: Colors.purple,
    ),
    OnboardingPage(
      icon: Icons.emoji_events,
      title: 'Compete & Win',
      description: 'Climb the leaderboard, unlock achievements, and become the ultimate Kadi champion!',
      color: Colors.pink,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
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
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 1),
                    ),
                  ),
                ),
              ),
              
              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index], index == 0);
                  },
                ),
              ),
              
              // Page indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildDot(index),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Next/Get Started button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _pages.length - 1) {
                        _finish();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      shadowColor: Color(0xFF00E5FF).withOpacity(0.4),
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'GET STARTED' : 'CONTINUE',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, bool showLogo) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon or Logo with glow effect
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF00E5FF).withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: showLogo 
              ? Image.asset('assets/Kadi.png', fit: BoxFit.contain)
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color(0xFF00E5FF).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    page.icon,
                    size: 80,
                    color: Color(0xFF00E5FF),
                  ),
                ),
          ),
          const SizedBox(height: 60),
          
          // Title with glow
          Text(
            page.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Color(0xFF00E5FF).withOpacity(0.5),
                  blurRadius: 10,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Description
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      height: 8,
      width: isActive ? 32 : 8,
      decoration: BoxDecoration(
        color: isActive ? Color(0xFF00E5FF) : Colors.white24,
        borderRadius: BorderRadius.circular(4),
        boxShadow: isActive ? [
          BoxShadow(
            color: Color(0xFF00E5FF).withOpacity(0.5),
            blurRadius: 8,
          ),
        ] : [],
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
