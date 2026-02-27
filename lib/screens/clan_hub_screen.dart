import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/clan_model.dart';
import '../services/app_config.dart';
import '../services/clan_service.dart';
import '../services/custom_auth_service.dart';
import '../services/vps_game_service.dart';
import '../services/progression_service.dart';
import '../widgets/custom_toast.dart';
import '../widgets/premium_chat_bubble.dart';
import 'dart:async';

// ─── App Palette ────────────────────────────────────────────────────
const _bg       = Color(0xFF0F111A);
const _surface  = Color(0xFF1A1F38);
const _card     = Color(0xFF1E2540);
const _amber    = Color(0xFFFFB300);
const _amberDim = Color(0x33FFB300);
const _glow     = Color(0xAAFFB300);

class ClanHubScreen extends StatefulWidget {
  @override
  _ClanHubScreenState createState() => _ClanHubScreenState();
}

class _ClanHubScreenState extends State<ClanHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  Clan? _myClan;
  List<Clan> _topClans = [];

  StreamSubscription? _chatSub;
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _chatHistoryLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    VPSGameService().connect();

    _chatSub = VPSGameService().clanChatStream.listen((data) {
      if (mounted) {
        // Just trigger a rebuild — the singleton cache is the single source of truth
        setState(() {});
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut);
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
        // Load history if in a clan
        if (myClan != null) {
          _loadChatHistory(myClan.id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomToast.show(context, "Failed to load clans", isError: true);
      }
    }
  }

  Future<void> _loadChatHistory(String clanId) async {
    // Fetch from server (merges into singleton cache — dedup handled there)
    await VPSGameService().fetchClanChatHistory(clanId);
    if (mounted) {
      setState(() => _chatHistoryLoaded = true);
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      });
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

  // ─── Dialogs ────────────────────────────────────────────────────────

  void _showCreateClanDialog() {
    final nameCtrl = TextEditingController();
    final tagCtrl  = TextEditingController();
    final descCtrl = TextEditingController();
    double _entryFee = 0;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _amberDim, width: 1.5),
              boxShadow: [BoxShadow(color: _glow.withOpacity(0.2), blurRadius: 24)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.shield, color: _amber, size: 22),
                  const SizedBox(width: 8),
                  const Text("Create a Clan",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: _amberDim, borderRadius: BorderRadius.circular(8)),
                  child: const Text("Cost: 2000 Coins",
                      style: TextStyle(color: _amber, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(height: 16),
              _dialogField(nameCtrl, "Clan Name (3–20 chars)", Icons.group),
              const SizedBox(height: 10),
              _dialogField(tagCtrl, "Clan Tag (4 letters)", Icons.tag,
                  caps: TextCapitalization.characters, maxLen: 4),
              const SizedBox(height: 10),
              _dialogField(descCtrl, "Description", Icons.info_outline),
                const SizedBox(height: 16),
                const Text("Entry Fee (Coins)",
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Text("0", style: TextStyle(color: Colors.white38, fontSize: 12)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _amber,
                          inactiveTrackColor: _amberDim.withOpacity(0.2),
                          thumbColor: _amber,
                          overlayColor: _amber.withOpacity(0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _entryFee,
                          min: 0,
                          max: 1000,
                          divisions: 20,
                          label: "${_entryFee.toInt()}",
                          onChanged: (val) {
                            setDialogState(() => _entryFee = val);
                          },
                        ),
                      ),
                    ),
                    Text("1000", style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                Center(
                  child: Text("${_entryFee.toInt()} Coins",
                      style: const TextStyle(color: _amber, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      if (nameCtrl.text.trim().length < 3) {
                        CustomToast.show(context, "Name must be at least 3 chars", isError: true); 
                        return;
                      }
                      if (tagCtrl.text.trim().length != 4) {
                        CustomToast.show(context, "Tag must be exactly 4 chars", isError: true); 
                        return;
                      }
                      if (ProgressionService().getCoins() < 2000) {
                        CustomToast.show(context, "Insufficient Coins! 2000 required.", isError: true); 
                        return;
                      }
                      try {
                        Navigator.pop(c);
                        setState(() => _isLoading = true);
                        await ClanService().createClan(
                            nameCtrl.text.trim(),
                            tagCtrl.text.toUpperCase().trim(),
                            descCtrl.text.trim(),
                            _entryFee.toInt());
                        await ProgressionService().addCoins(-2000);
                        CustomToast.show(context, "Clan Created! ⚔️");
                        await _loadData();
                      } catch (e) {
                        setState(() => _isLoading = false);
                        CustomToast.show(context, e.toString().replaceAll("Exception: ", ""), isError: true);
                      }
                    },
                    child: const Text("Create"),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon,
      {TextCapitalization caps = TextCapitalization.none, int? maxLen}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      textCapitalization: caps,
      maxLength: maxLen,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _amber, size: 18),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        filled: true,
        fillColor: _card,
        counterStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _amberDim)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _amberDim)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _amber, width: 1.5)),
      ),
    );
  }

  void _joinClan(String clanId) async {
    try {
      setState(() => _isLoading = true);
      await ClanService().joinClan(clanId);
      if (!mounted) return;
      CustomToast.show(context, "Successfully joined clan! ⚔️");
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomToast.show(context, e.toString().replaceAll("Exception: ", ""), isError: true);
    }
  }

  void _leaveClan() async {
    try {
      setState(() => _isLoading = true);
      await ClanService().leaveClan();
      if (!mounted) return;
      CustomToast.show(context, "You have left the clan.");
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomToast.show(context, e.toString().replaceAll("Exception: ", ""), isError: true);
    }
  }

  void _kickMember(ClanMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F38),
        title: const Text('Kick Member', style: TextStyle(color: Colors.white)),
        content: Text('Remove ${member.username} from the clan?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kick', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      setState(() => _isLoading = true);
      await ClanService().kickMember(member.userId);
      if (!mounted) return;
      CustomToast.show(context, "${member.username} has been removed.");
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomToast.show(context, e.toString().replaceAll("Exception: ", ""), isError: true);
    }
  }

  void _deleteClan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F38),
        title: const Text('Delete Clan', style: TextStyle(color: Colors.redAccent)),
        content: const Text(
          'This will permanently delete your clan and remove all members. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      setState(() => _isLoading = true);
      await ClanService().deleteClan();
      if (!mounted) return;
      CustomToast.show(context, "Clan disbanded.");
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomToast.show(context, e.toString().replaceAll("Exception: ", ""), isError: true);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            expandedHeight: 56,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield, color: _amber, size: 16),
                      const SizedBox(width: 6),
                      const Text("CLAN HUB",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              letterSpacing: 3,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A1F38), _bg],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: _surface.withOpacity(0.8),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: _amber,
                  indicatorWeight: 3,
                  labelColor: _amber,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  tabs: const [
                    Tab(text: "MY CLAN", icon: Icon(Icons.shield, size: 16)),
                    Tab(text: "BROWSE", icon: Icon(Icons.search, size: 16)),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _amber))
            : RefreshIndicator(
                color: _amber,
                backgroundColor: _surface,
                onRefresh: _loadData,
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildMyClanTab(), _buildBrowseTab()],
                ),
              ),
      ),
    );
  }

  // ─── MY CLAN TAB ─────────────────────────────────────────────────────

  Widget _buildMyClanTab() {
    if (_myClan == null) return _buildNoClanView();

    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              _buildClanHeroHeader(),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 20),
              _buildSectionLabel(Icons.people, "Roster",
                  trailing: "${_myClan!.members.length}/${_myClan!.capacity}"),
              ..._myClan!.members.map(_buildMemberCard).toList(),
              const SizedBox(height: 20),
              _buildSectionLabel(Icons.chat_bubble_rounded, "Clan Chat"),
              _buildChatArea(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Clan Hero Header ─────────────────────────────────────────────

  Widget _buildClanHeroHeader() {
    return Stack(
      children: [
        // Background gradient banner
        Container(
          height: 170,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1F38), Color(0xFF0D111F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Radial amber glow
        Positioned(
          top: -40, right: -40,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _amber.withOpacity(0.05)),
          ),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Glowing Shield Badge
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: _amberDim,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _amber, width: 2),
                      boxShadow: [
                        BoxShadow(color: _glow.withOpacity(0.4),
                            blurRadius: 20, spreadRadius: 2)
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shield, color: _amber, size: 18),
                        const SizedBox(height: 2),
                        Text(_myClan!.tag,
                            style: const TextStyle(
                                color: _amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_myClan!.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_myClan!.description,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // Leave button (non-owners) / Delete button (owner)
                  if (_myClan!.ownerId != CustomAuthService().userId)
                    InkWell(
                      onTap: () => showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          backgroundColor: _surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: const Text("Leave Clan?",
                              style: TextStyle(color: Colors.white)),
                          content: Text(
                              "Are you sure you want to leave ${_myClan!.name}?",
                              style: const TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text("Cancel")),
                            TextButton(
                                onPressed: () {
                                  Navigator.pop(c);
                                  _leaveClan();
                                },
                                child: const Text("Leave",
                                    style: TextStyle(color: Colors.redAccent))),
                          ],
                        ),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.redAccent.withOpacity(0.4))),
                        child: const Icon(Icons.exit_to_app,
                            color: Colors.redAccent, size: 20),
                      ),
                    )
                  else
                    // Owner: Delete clan
                    InkWell(
                      onTap: _deleteClan,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.redAccent.withOpacity(0.4))),
                        child: const Icon(Icons.delete_forever,
                            color: Colors.redAccent, size: 20),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        // Bottom fade
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, _bg],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Stats Row ───────────────────────────────────────────────────

  Widget _buildStatsRow() {
    int rankIndex = _topClans.indexWhere((c) => c.id == _myClan!.id);
    String rankText = rankIndex != -1 ? "#${rankIndex + 1}" : "Unranked";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statChip(Icons.emoji_events_rounded, "${_myClan!.totalScore}",
              "Total Score", const Color(0xFFFFD700)),
          const SizedBox(width: 10),
          _statChip(Icons.people_rounded,
              "${_myClan!.members.length}/${_myClan!.capacity}",
              "Members", Colors.lightBlueAccent),
          const SizedBox(width: 10),
          _statChip(Icons.military_tech_rounded,
              rankText, "Rank", Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ─── Section Label ────────────────────────────────────────────────

  Widget _buildSectionLabel(IconData icon, String label,
      {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Icon(icon, color: _amber, size: 16),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5)),
          const Spacer(),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: _amberDim,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(trailing,
                  style: const TextStyle(
                      color: _amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ─── Member Card ───────────────────────────────────────────────────

  Color _getRankColor(String title) {
    switch (title) {
      case 'Champion': return Colors.purpleAccent;
      case 'Elite': return Colors.cyanAccent;
      case 'Veteran': return Colors.orangeAccent;
      case 'Fighter': return Colors.greenAccent;
      default: return Colors.blueGrey;
    }
  }

  Widget _buildMemberCard(ClanMember member) {
    final isOwner = member.role == 'owner';
    final isElder = member.role == 'elder';
    final roleColor = isOwner ? _amber : isElder ? Colors.purpleAccent : Colors.white38;
    final roleIcon = isOwner ? Icons.military_tech : isElder ? Icons.star : Icons.person;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _card.withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isOwner
                      ? _amber.withOpacity(0.4)
                      : Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _surface,
                      backgroundImage: member.avatar != null
                          ? NetworkImage(AppConfig.resolveAvatarUrl(member.avatar)!)
                          : null,
                      child: member.avatar == null
                          ? Icon(Icons.person, color: Colors.white54, size: 24)
                          : null,
                    ),
                    if (isOwner)
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(
                              color: _amber, shape: BoxShape.circle),
                          child: const Icon(Icons.military_tech,
                              size: 10, color: Colors.black),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.username,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(roleIcon, color: roleColor, size: 11),
                          const SizedBox(width: 4),
                          Text(member.role.toUpperCase(),
                              style: TextStyle(
                                  color: roleColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                          const SizedBox(width: 8),
                          // Rank Title Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRankColor(member.rankTitle).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _getRankColor(member.rankTitle).withOpacity(0.5)),
                            ),
                            child: Text(
                              member.rankTitle.toUpperCase(),
                              style: TextStyle(
                                  color: _getRankColor(member.rankTitle),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${member.wins} W",
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.orangeAccent.withOpacity(0.3)),
                          ),
                          child: Text(
                              "🔥 ${member.seasonPoints} WP",
                              style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.greenAccent.withOpacity(0.3)),
                          ),
                          child: Text(
                              "${member.winRate.toStringAsFixed(0)}% WR",
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
                // Kick button — owner only, can't kick self
                if (_myClan?.ownerId == CustomAuthService().userId &&
                    member.userId != CustomAuthService().userId) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _kickMember(member),
                    icon: const Icon(Icons.person_remove,
                        color: Colors.redAccent, size: 18),
                    tooltip: 'Kick member',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Chat Area ────────────────────────────────────────────────────

  Widget _buildChatArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 340,
            decoration: BoxDecoration(
              color: const Color(0xFF0D111F).withOpacity(0.85),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _amber.withOpacity(0.15), width: 1),
            ),
            child: Column(
              children: [
                // Chat header strip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _amberDim,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_rounded,
                          color: _amber, size: 14),
                      const SizedBox(width: 6),
                      const Text("CLAN CHAT",
                          style: TextStyle(
                              color: _amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 2)),
                      const Spacer(),
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      const Text("LIVE",
                          style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // Messages
                Expanded(
                  child: Builder(builder: (context) {
                    final msgs = _myClan != null
                        ? VPSGameService().getCachedMessages(_myClan!.id)
                        : const [];
                    if (msgs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.chat_bubble_outline,
                                color: Colors.white12, size: 36),
                            SizedBox(height: 8),
                            Text("No messages yet.\nSay something to your clan!",
                                style: TextStyle(
                                    color: Colors.white24, fontSize: 13),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(10),
                      itemCount: msgs.length,
                      itemBuilder: (c, i) {
                        final msg = msgs[i];
                        final isMe =
                            msg['senderId'] == CustomAuthService().userId;
                        final ts = msg['timestamp'] != null
                            ? DateTime.tryParse(msg['timestamp']) ??
                                DateTime.now()
                            : DateTime.now();
                        return PremiumChatBubble(
                          message: msg['message'] ?? '',
                          isMe: isMe,
                          senderName: msg['senderName'] ?? "Unknown",
                          avatarUrl: msg['senderAvatar'],
                          timestamp: ts,
                        );
                      },
                    );
                  }),
                ),
                // Input bar
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: BoxDecoration(
                    color: _surface.withOpacity(0.6),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(18)),
                    border: Border(
                        top: BorderSide(
                            color: Colors.white.withOpacity(0.05))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatCtrl,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Message your clan...",
                            hintStyle: const TextStyle(
                                color: Colors.white24, fontSize: 13),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              VPSGameService()
                                  .sendClanChat(_myClan!.id, val.trim());
                              _chatCtrl.clear();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (_chatCtrl.text.trim().isNotEmpty) {
                            VPSGameService().sendClanChat(
                                _myClan!.id, _chatCtrl.text.trim());
                            _chatCtrl.clear();
                          }
                        },
                        child: Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: _amber.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          child: const Icon(Icons.send_rounded,
                              color: Colors.black, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── No Clan View ─────────────────────────────────────────────────

  Widget _buildNoClanView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _amberDim,
              boxShadow: [
                BoxShadow(
                    color: _glow.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5)
              ],
            ),
            child: const Icon(Icons.shield_outlined,
                size: 56, color: _amber),
          ),
          const SizedBox(height: 24),
          const Text("No Clan Yet",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Join or create a clan to compete\nwith friends!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.search),
              label: const Text("Browse Clans",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _amber,
              side: const BorderSide(color: _amberDim, width: 1.5),
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _showCreateClanDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Create a Clan (2000 Coins)",
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── BROWSE TAB ──────────────────────────────────────────────────

  Widget _buildBrowseTab() {
    if (_topClans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 60, color: Colors.white12),
            const SizedBox(height: 14),
            const Text("No clans found.",
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 24),
            if (_myClan == null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _amber, foregroundColor: Colors.black),
                onPressed: _showCreateClanDialog,
                icon: const Icon(Icons.add),
                label: const Text("Create First Clan (2000 Coins)"),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _topClans.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Create Clan CTA at top
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _myClan == null
                ? OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _amber,
                      side: const BorderSide(color: _amberDim),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _showCreateClanDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Create a New Clan (2000 Coins)"),
                  )
                : const SizedBox.shrink(),
          );
        }

        final clan = _topClans[index - 1];
        final isMyClan = _myClan?.id == clan.id;
        final isFull = clan.memberCount >= clan.capacity;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _card.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMyClan
                        ? _amber.withOpacity(0.5)
                        : Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Row(
                  children: [
                    // Tag badge
                    Container(
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                        color: isMyClan
                            ? _amberDim
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isMyClan
                                ? _amber
                                : Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield,
                              color: isMyClan
                                  ? _amber
                                  : Colors.white38,
                              size: 14),
                          const SizedBox(height: 2),
                          Text(clan.tag,
                              style: TextStyle(
                                  color: isMyClan
                                      ? _amber
                                      : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Clan info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(clan.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              if (isMyClan) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _amberDim,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text("MINE",
                                      style: TextStyle(
                                          color: _amber,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (clan.entryFee > 0)
                                Row(
                                  children: [
                                    const Icon(Icons.monetization_on, color: _amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text("${clan.entryFee}", style: const TextStyle(color: _amber, fontSize: 13, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 12),
                                  ],
                                ),
                              const Icon(Icons.people_alt_outlined,
                                  color: Colors.white24, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                  "${clan.memberCount}/${clan.capacity}",
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12)),
                              const SizedBox(width: 10),
                              const Icon(Icons.local_fire_department,
                                  size: 12, color: Colors.orangeAccent),
                              const SizedBox(width: 4),
                              Text("${clan.seasonScore} WP",
                                  style: const TextStyle(
                                      color: Colors.orangeAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              if (clan.trophies > 0) ...[
                                const SizedBox(width: 10),
                                const Icon(Icons.emoji_events,
                                    size: 13, color: _amber),
                                const SizedBox(width: 2),
                                Text("${clan.trophies}",
                                    style: const TextStyle(
                                        color: _amber,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Join / indicator
                    if (isMyClan)
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.greenAccent, size: 24)
                    else if (!isFull && _myClan == null)
                      GestureDetector(
                        onTap: () => _joinClan(clan.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFB300),
                                Color(0xFFFF8F00)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                  color: _amber.withOpacity(0.3),
                                  blurRadius: 8)
                            ],
                          ),
                          child: const Text("JOIN",
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1)),
                        ),
                      )
                    else if (isFull)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text("FULL",
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
