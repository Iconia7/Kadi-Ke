import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; // Import this
import '../services/sound_service.dart';
import '../services/firebase_game_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isMuted = false;
  final TextEditingController _nameController = TextEditingController();
  
  // 1. CHANGE: Make _db nullable and remove immediate initialization
  FirebaseFirestore? _db; 
  
  String _currentName = "Loading...";

  @override
  void initState() {
    super.initState();
    
    // 2. FIX: Safely initialize DB only if Firebase is actually running
    try {
      if (Firebase.apps.isNotEmpty) {
        _db = FirebaseFirestore.instance;
      }
    } catch (e) {
      print("Settings: Firebase not available - $e");
    }

    try {
      _isMuted = SoundService.isMuted;
    } catch (e) {
      print("Sound Service Error: $e");
    }
    _loadCurrentName();
  }

  Future<void> _loadCurrentName() async {
    // 3. FIX: Check if DB is available before using it
    if (_db == null) {
      setState(() => _currentName = "Offline Player");
      return;
    }

    String uid = FirebaseGameService().currentUserId;
    if (uid == "unknown") return;

    try {
      DocumentSnapshot doc = await _db!.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() {
          _currentName = doc.get('name') ?? "Player";
          _nameController.text = _currentName;
        });
      } else {
        setState(() => _currentName = "Player");
      }
    } catch (e) {
      print("Error loading name: $e");
    }
  }

  Future<void> _saveNickname() async {
    // 4. FIX: Check if DB is available before saving
    if (_db == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cannot save: Offline Mode"), backgroundColor: Colors.grey),
      );
      return;
    }

    String newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    String uid = FirebaseGameService().currentUserId;
    if (uid == "unknown") return;

    try {
      await _db!.collection('users').doc(uid).set({
        'name': newName,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Nickname saved as '$newName'"), backgroundColor: Colors.green),
      );
      FocusScope.of(context).unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving name"), backgroundColor: Colors.red),
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: _db == null ? "Offline" : "Enter Name",
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
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: const Icon(Icons.check, color: Colors.white),
                    ),
                  ],
                ),
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
            child: Text("Kadi Ke v1.0.0", style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic)),
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
We store your nickname, win/loss record, coin balance, and skins inventory.

2. Usage
This data is used solely to maintain your game progression across devices.

3. Third Parties
We use Firebase (Google) for secure data storage. We do not sell your data.
  """;
}