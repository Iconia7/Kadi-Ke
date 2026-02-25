import 'package:flutter/material.dart';
import '../models/clan_model.dart';
import '../services/clan_service.dart';
import '../services/custom_auth_service.dart';
import '../services/vps_game_service.dart';
import '../widgets/custom_toast.dart';
import 'dart:async';

class ClanHubScreen extends StatefulWidget {
  @override
  _ClanHubScreenState createState() => _ClanHubScreenState();
}

class _ClanHubScreenState extends State<ClanHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  Clan? _myClan;
  List<Clan> _topClans = [];

  StreamSubscription? _chatSub;
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();

    // Ensure VPS connection is alive so we can receive chat
    VPSGameService().connect();
    
    _chatSub = VPSGameService().clanChatStream.listen((data) {
      if (mounted) {
        setState(() => _chatMessages.add(data));
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          }
        });
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final myClan = await ClanService().getMyClan();
      final topClans = await ClanService().searchClans();
      
      if (mounted) {
        setState(() {
          _myClan = myClan;
          _topClans = topClans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomToast.show(context, "Failed to load clans", isError: true);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatSub?.cancel();
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _showCreateClanDialog() {
    final nameCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Create a Clan", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Cost: 500 Coins", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'Clan Name (3-20 chars)', labelStyle: TextStyle(color: Colors.white54)),
            ),
            TextField(
              controller: tagCtrl,
              style: TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.characters,
              maxLength: 4,
              decoration: InputDecoration(labelText: 'Clan Tag (4 letters)', labelStyle: TextStyle(color: Colors.white54)),
            ),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () async {
              try {
                Navigator.pop(c);
                setState(() => _isLoading = true);
                
                await ClanService().createClan(
                  nameCtrl.text.trim(),
                  tagCtrl.text.toUpperCase().trim(),
                  descCtrl.text.trim(),
                );
                
                CustomToast.show(context, "Clan Created!");
                await _loadData();
              } catch (e) {
                setState(() => _isLoading = false);
                CustomToast.show(context, e.toString().replaceAll("Exception: ", ""), isError: true);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _joinClan(String clanId) async {
    try {
      setState(() => _isLoading = true);
      await ClanService().joinClan(clanId);
      CustomToast.show(context, "Successfully joined clan!");
      await _loadData();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      CustomToast.show(context, e.toString().replaceAll("Exception: ", ""), isError: true);
    }
  }

  void _leaveClan() async {
    try {
      setState(() => _isLoading = true);
      await ClanService().leaveClan();
      CustomToast.show(context, "You left the clan.");
      await _loadData();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      CustomToast.show(context, e.toString().replaceAll("Exception: ", ""), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Clan Hub', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "MY CLAN", icon: Icon(Icons.shield)),
            Tab(text: "BROWSE", icon: Icon(Icons.search)),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMyClanTab(),
                _buildBrowseTab(),
              ],
            ),
    );
  }

  Widget _buildMyClanTab() {
    if (_myClan == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 80, color: Colors.white24),
            SizedBox(height: 20),
            Text(
              "You are not in a Clan",
              style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () => _tabController.animateTo(1),
              child: Text("Browse Clans"),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: _showCreateClanDialog,
              child: Text("Create a Clan (500 Coins)", style: TextStyle(color: Colors.amberAccent)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: Center(
                  child: Text(
                    _myClan!.tag,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_myClan!.name, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text("Total Score: ${_myClan!.totalScore}", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text("Description", style: TextStyle(color: Colors.white54, fontSize: 12)),
          SizedBox(height: 4),
          Text(_myClan!.description, style: TextStyle(color: Colors.white, fontSize: 16)),
          SizedBox(height: 30),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Members (${_myClan!.members.length}/${_myClan!.capacity})", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              if (_myClan!.ownerId != CustomAuthService().userId)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  onPressed: () {
                     showDialog(
                       context: context,
                       builder: (c) => AlertDialog(
                         title: Text("Leave Clan?"),
                         content: Text("Are you sure you want to leave ${_myClan!.name}?"),
                         actions: [
                           TextButton(onPressed: () => Navigator.pop(c), child: Text("Cancel")),
                           TextButton(onPressed: () { Navigator.pop(c); _leaveClan(); }, child: Text("Leave", style: TextStyle(color: Colors.red))),
                         ]
                     ));
                  },
                  child: Text("Leave"),
                ),
            ],
          ),
          SizedBox(height: 10),
          ..._myClan!.members.map((member) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: member.avatar != null ? NetworkImage(member.avatar!) : null,
                  backgroundColor: Colors.grey.shade800,
                  child: member.avatar == null ? Icon(Icons.person, color: Colors.white) : null,
                ),
                title: Text(member.username, style: TextStyle(color: Colors.white)),
                subtitle: Text(member.role.toUpperCase(), style: TextStyle(color: member.role == 'owner' ? Colors.amber : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                trailing: Text("${member.wins} W", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              )).toList(),
          
          SizedBox(height: 20),
          Divider(color: Colors.white24, thickness: 2),
          SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: Colors.amber),
              SizedBox(width: 8),
              Text("Clan Chat", style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 10),
          Container(
            height: 300,
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                 Expanded(
                   child: ListView.builder(
                     controller: _scrollCtrl,
                     padding: EdgeInsets.all(8),
                     itemCount: _chatMessages.length,
                     itemBuilder: (c, i) {
                       final msg = _chatMessages[i];
                       bool isMe = msg['senderId'] == CustomAuthService().userId;
                       return Align(
                         alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                         child: Container(
                           margin: EdgeInsets.only(bottom: 8),
                           padding: EdgeInsets.all(10),
                           decoration: BoxDecoration(
                             color: isMe ? Colors.amber : Colors.blueGrey.shade800,
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                if (!isMe) Text(msg['senderName'] ?? "Unknown", style: TextStyle(color: Colors.white54, fontSize: 10)),
                                Text(msg['message'], style: TextStyle(color: isMe ? Colors.black : Colors.white)),
                             ]
                           )
                         )
                       );
                     }
                   )
                 ),
                 Padding(
                   padding: EdgeInsets.all(8),
                   child: Row(
                     children: [
                       Expanded(
                         child: TextField(
                           controller: _chatCtrl,
                           style: TextStyle(color: Colors.white),
                           decoration: InputDecoration(
                             hintText: "Type a message...",
                             hintStyle: TextStyle(color: Colors.white54),
                             filled: true,
                             fillColor: Colors.black45,
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                             contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                           ),
                           onSubmitted: (val) {
                             if (val.trim().isNotEmpty) {
                               VPSGameService().sendClanChat(_myClan!.id, val.trim());
                               _chatCtrl.clear();
                             }
                           },
                         )
                       ),
                       SizedBox(width: 8),
                       CircleAvatar(
                         backgroundColor: Colors.amber,
                         child: IconButton(
                           icon: Icon(Icons.send, color: Colors.black, size: 20),
                           onPressed: () {
                             if (_chatCtrl.text.trim().isNotEmpty) {
                               VPSGameService().sendClanChat(_myClan!.id, _chatCtrl.text.trim());
                               _chatCtrl.clear();
                             }
                           }
                         )
                       )
                     ]
                   )
                 )
              ]
            )
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBrowseTab() {
    if (_topClans.isEmpty) {
       return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.white24),
            SizedBox(height: 10),
            Text("No clans found.", style: TextStyle(color: Colors.white54)),
            SizedBox(height: 20),
            if (_myClan == null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                onPressed: _showCreateClanDialog,
                child: Text("Create First Clan (500 Coins)"),
              )
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _topClans.length,
      itemBuilder: (context, index) {
        final clan = _topClans[index];
        final isMyClan = _myClan?.id == clan.id;
        final isFull = clan.memberCount >= clan.capacity;

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Center(
                child: Text(clan.tag, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              ),
            ),
            title: Text(clan.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text("${clan.memberCount}/${clan.capacity} Members • ${clan.totalScore} Score", style: TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: isMyClan 
                ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                : (_myClan != null || isFull)
                    ? null
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.amber,
                          side: BorderSide(color: Colors.amber),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        ),
                        onPressed: () => _joinClan(clan.id),
                        child: Text("JOIN", style: TextStyle(fontSize: 12)),
                      ),
          ),
        );
      },
    );
  }
}
