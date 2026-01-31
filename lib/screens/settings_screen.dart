import 'package:flutter/material.dart';
import '../services/sound_service.dart';
import '../services/custom_auth_service.dart';
import '../services/vps_game_service.dart'; 

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isMuted = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  
  String _currentName = "Loading...";

  @override
  void initState() {
    super.initState();
    try {
      _isMuted = SoundService.isMuted;
    } catch (e) {
      print("Sound Service Error: $e");
    }
    _loadCurrentName();
  }

  Future<void> _loadCurrentName() async {
    // Determine user based on CustomAuthService
    // Since VPS doesn't support changing nickname separately from username yet,
    // we just display the username.
    String? username = CustomAuthService().username;
    
    if (mounted) {
       setState(() {
         _currentName = username ?? "Guest Player";
         _nameController.text = _currentName;
       });
    }
  }

  Future<void> _saveNickname() async {
     // TODO: Implement /update_profile endpoint on VPS
     // For now, names are fixed to usernames on the VPS
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Changing display name is not supported yet."), backgroundColor: Colors.orange),
     );
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
          _buildSectionHeader("AUDIO"),
          Container(
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text("Mute Sound Effects", style: TextStyle(color: Colors.white)),
              secondary: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.amber),
              value: _isMuted,
              activeColor: Colors.amber,
              onChanged: (val) {
                setState(() => _isMuted = val);
                SoundService.toggleMute(val);
              },
            ),
          ),

          const SizedBox(height: 30),

          _buildSectionHeader("PROFILE"),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
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
                        readOnly: true, // Read-only for now
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: "Enter Name",
                          hintStyle: const TextStyle(color: Colors.white30),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _saveNickname,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey, // Greyed out
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: const Icon(Icons.lock, color: Colors.white),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text("Username cannot be changed in this version.", style: TextStyle(color: Colors.white30, fontSize: 10)),
              ],
            ),
          ),

          const SizedBox(height: 30),

          _buildSectionHeader("LEGAL"),
          Container(
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text("Terms and Conditions", style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                  onTap: () => _showTextDialog(context, "Terms & Conditions", _termsText),
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  title: const Text("Privacy Policy", style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                  onTap: () => _showTextDialog(context, "Privacy Policy", _privacyText),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          Center(
            child: Text("Kadi Ke v1.2.0 (VPS)", style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic)),
          ),
        ],
      ),
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