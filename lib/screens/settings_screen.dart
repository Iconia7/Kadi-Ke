import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sound_service.dart';
import '../services/custom_auth_service.dart';
import '../services/vps_game_service.dart'; 
import '../services/progression_service.dart';
import '../services/notification_service.dart';
import '../widgets/notification_test_dialog.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isMuted = false;
  bool _notificationsEnabled = true;
  
  // Notification Preferences
  bool _notifChallenges = true;
  bool _notifFriendActivity = true;
  bool _notifGameInvites = true;
  bool _notifTournaments = false;
  bool _notifStreaks = true;
  
  final TextEditingController _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isSaving = false;
  
  String _currentName = "Loading...";

  @override
  void initState() {
    super.initState();
    _isMuted = SoundService.isMuted;
    _notificationsEnabled = ProgressionService().areNotificationsEnabled();
    _loadCurrentName();
  }

  Future<void> _loadCurrentName() async {
    String? username = CustomAuthService().username;
    if (mounted) {
       setState(() {
         _currentName = username ?? "Guest Player";
         _nameController.text = _currentName;
       });
    }
  }

  Future<void> _saveNickname() async {
    if (_nameController.text.trim().isEmpty) return;
    if (_nameController.text.trim() == _currentName) {
      setState(() => _isEditingName = false);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await CustomAuthService().updateProfile(_nameController.text.trim());
      await _loadCurrentName();
      setState(() => _isEditingName = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Username updated successfully!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Color(0xFF1E293B),
        title: Text("Logout", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to logout?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(c, true), 
            child: Text("LOGOUT", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CustomAuthService().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not launch $url")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("SETTINGS", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("AUDIO & ALERTS"),
          _buildSettingsContainer([
            _buildSwitchTile(
              "Mute Sound Effects", 
              _isMuted, 
              _isMuted ? Icons.volume_off : Icons.volume_up,
              (val) {
                setState(() => _isMuted = val);
                SoundService.toggleMute(val);
              }
            ),
            const Divider(height: 1, color: Colors.white10),
            _buildSwitchTile(
              "Daily Notifications", 
              _notificationsEnabled, 
              Icons.notifications_active,
              (val) async {
                setState(() => _notificationsEnabled = val);
                await ProgressionService().setNotificationsEnabled(val);
                if (val) {
                  await NotificationService().requestPermission();
                  await NotificationService().scheduleDailyRewardReminder(TimeOfDay(hour: 10, minute: 0));
                } else {
                  // In a real app, you might want a cancelAll method in NotificationService
                }
              }
            ),
          ]),

          const SizedBox(height: 30),

          // Notification Preferences Section
          _buildSectionHeader("NOTIFICATION PREFERENCES"),
          _buildSettingsContainer([
            _buildSwitchTile(
              "Daily Challenges",
              _notifChallenges,
              Icons.emoji_events_outlined,
              (val) async {
                setState(() => _notifChallenges = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notif_pref_challenges', val);
              }
            ),
            const Divider(height: 1, color: Colors.white10),
            _buildSwitchTile(
              "Friend Activity",
              _notifFriendActivity,
              Icons.people_outline,
              (val) async {
                setState(() => _notifFriendActivity = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notif_pref_friend_activity', val);
              }
            ),
            const Divider(height: 1, color: Colors.white10),
            _buildSwitchTile(
              "Game Invites",
              _notifGameInvites,
              Icons.sports_esports_outlined,
              (val) async {
                setState(() => _notifGameInvites = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notif_pref_game_invites', val);
              }
            ),
            const Divider(height: 1, color: Colors.white10),
            _buildSwitchTile(
              "Tournament Alerts",
              _notifTournaments,
              Icons.emoji_events,
              (val) async {
                setState(() => _notifTournaments = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notif_pref_tournaments', val);
              }
            ),
            const Divider(height: 1, color: Colors.white10),
            _buildSwitchTile(
              "Streak Reminders",
              _notifStreaks,
              Icons.local_fire_department_outlined,
              (val) async {
                setState(() => _notifStreaks = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notif_pref_streaks', val);
              }
            ),
          ]),

          const SizedBox(height: 30),

          _buildSectionHeader("PROFILE"),
          _buildSettingsContainer([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Display Name", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          enabled: _isEditingName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: _isEditingName ? Colors.black45 : Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: _isEditingName ? BorderSide(color: Colors.amber, width: 1) : BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_isSaving)
                        SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                      else if (_isEditingName)
                        IconButton(
                          icon: Icon(Icons.check_circle, color: Colors.green, size: 30),
                          onPressed: _saveNickname,
                        )
                      else
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.amber, size: 24),
                          onPressed: () => setState(() => _isEditingName = true),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 30),

          _buildSectionHeader("SUPPORT & INFO"),
          _buildSettingsContainer([
            _buildListTile("How to Play", Icons.help_outline, () => _showHowToPlay()),
            const Divider(height: 1, color: Colors.white10),
            _buildListTile("Contact Support", Icons.email_outlined, () => _launchURL("mailto:support@kadike.com")),
            const Divider(height: 1, color: Colors.white10),
            _buildListTile("Terms & Privacy", Icons.gavel_outlined, () => _showTextDialog(context, "Legal", _legalText)),
            const Divider(height: 1, color: Colors.white10),
            _buildListTile("About Kadi Ke", Icons.info_outline, () => _showAbout()),
          ]),

          const SizedBox(height: 40),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("LOGOUT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
          ),

          const SizedBox(height: 20),
          Center(
            child: Text("Version 4.2.26+39 (VPS)", style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(String title, bool value, IconData icon, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: TextStyle(color: Colors.white, fontSize: 15)),
      secondary: Icon(icon, color: Colors.amber, size: 22),
      value: value,
      activeColor: Colors.amber,
      onChanged: onChanged,
    );
  }

  Widget _buildListTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.amber, size: 22),
      title: Text(title, style: TextStyle(color: Colors.white, fontSize: 15)),
      trailing: Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }

  Future<void> _testNotification() async {
    await NotificationService().requestPermission();
    await NotificationService().showGameVictoryNotification(500);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Notification sent! (Check status bar)"), backgroundColor: Colors.green),
    );
  }

  void _showHowToPlay() {
    _showTextDialog(context, "How to Play", """
Kadi is a popular East African card game.

1. Goal: Be the first to empty your hand.
2. Matching: Play a card that matches the rank or suit of the top card.
3. Power Cards:
   - Ace: Changes the suit.
   - 2: Next player picks 2 cards.
   - 3: Next player picks 3 cards.
   - Joker: Next player picks 5 cards.
   - King: Reverses the direction.
   - Jack/Queen: Skip or Ask.
4. Niko Kadi: You must say 'Niko Kadi' when you have 1 card left!
""");
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: "Kadi Ke",
      applicationVersion: "4.2.26",
      applicationIcon: CircleAvatar(
        backgroundColor: Colors.transparent,
        child: Image.asset("assets/Kadi.png", fit: BoxFit.contain),
      ),
      children: [
        Text("The ultimate multiplayer Kadi experience. Play online or offline with friends."),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12),
      ),
    );
  }

  void _showTextDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(color: Colors.white24, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(content, style: const TextStyle(color: Colors.white70, height: 1.5)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  child: const Text("CLOSE", style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _legalText => "$_termsText\n\n$_privacyText";

  final String _termsText = """
1. Acceptance
By playing Kadi Ke, you agree to fair play rules.

2. Conduct
Harassment, cheating, or hacking will result in an immediate ban.

3. Assets
All card designs and game assets are property of Kadi Ke developers.
  """;

  final String _privacyText = """
1. Data We Collect
We store your nickname, win/loss record, coin balance, and skins inventory on our private server.

2. Usage
This data is used solely to maintain your game progression across devices.

3. Third Parties
We do not share your data with third parties.
  """;
}