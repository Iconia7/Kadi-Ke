import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/battle_pass_service.dart';
import '../services/theme_service.dart';
import '../services/progression_service.dart';
import '../services/iap_service.dart';
import '../widgets/custom_toast.dart';

class BattlePassScreen extends StatefulWidget {
  @override
  _BattlePassScreenState createState() => _BattlePassScreenState();
}

class _BattlePassScreenState extends State<BattlePassScreen> {
  final BattlePassService _bpService = BattlePassService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _bpService.initialize();
    
    // Listen for IAP results
    IAPService().onPurchaseResult = (message, success) {
      if (mounted) {
        CustomToast.show(context, message, isError: !success);
        if (success) {
           _bpService.initialize().then((_) => setState(() {}));
        }
      }
    };

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator(color: Colors.amber)));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("KADI PASS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 18)),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: kToolbarHeight + 40),
            
            // Header: Current Level & Progress
            _buildHeader(),

            SizedBox(height: 20),

            // Tier List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                physics: BouncingScrollPhysics(),
                itemCount: _bpService.tiers.length,
                itemBuilder: (context, index) {
                  final tier = _bpService.tiers[index];
                  return _buildTierRow(tier);
                },
              ),
            ),
            
            // Premium CTA if not premium
            if (!_bpService.isPremium) _buildPremiumCTA(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    int level = _bpService.currentLevel;
    double progress = _bpService.progressToNextLevel;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("SEASON 1", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  Text("KING OF KADI", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber,
                  boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 15)]
                ),
                child: Text("$level", style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              color: Colors.amber,
              minHeight: 12,
            ),
          ),
          SizedBox(height: 8),
          Text("${(progress * 100).toInt()}% TO LEVEL ${level + 1}", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTierRow(BattlePassTier tier) {
    bool isLocked = tier.level > _bpService.currentLevel;
    bool freeClaimed = _bpService.isTierClaimed(tier.level, false);
    bool premiumClaimed = _bpService.isTierClaimed(tier.level, true);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      height: 100,
      child: Row(
        children: [
          // Level Indicator
          Container(
            width: 40,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("${tier.level}", style: TextStyle(color: isLocked ? Colors.white24 : Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.amber.withOpacity(0.5), blurRadius: 4)])),
                if (!isLocked) Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
              ],
            ),
          ),
          
          // Free Reward
          Expanded(
            child: _buildRewardCard(
              title: "FREE",
              reward: tier.freeReward,
              isPremium: false,
              isClaimed: freeClaimed,
              isLocked: isLocked,
              type: tier.freeType,
              onClaim: () => _claim(tier.level, false),
            ),
          ),
          
          SizedBox(width: 8),

          // Premium Reward
          Expanded(
            child: _buildRewardCard(
              title: "PREMIUM",
              reward: tier.premiumReward,
              isPremium: true,
              isClaimed: premiumClaimed,
              isLocked: isLocked || !_bpService.isPremium,
              type: tier.premiumType,
              onClaim: () => _claim(tier.level, true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard({
    required String title,
    required String reward,
    required bool isPremium,
    required bool isClaimed,
    required bool isLocked,
    required RewardType type,
    required VoidCallback onClaim,
  }) {
    Color accentColor = isPremium ? Colors.purpleAccent : Colors.blueAccent;
    if (isClaimed) accentColor = Colors.grey;
    if (isLocked) accentColor = Colors.white12;

    return GestureDetector(
      onTap: (!isLocked && !isClaimed) ? onClaim : null,
      child: Container(
        decoration: BoxDecoration(
          color: isPremium ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(color: isPremium ? Colors.purpleAccent : Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  SizedBox(height: 4),
                  _getRewardIcon(type, isLocked),
                  SizedBox(height: 4),
                  Text(reward, textAlign: TextAlign.center, style: TextStyle(color: isLocked ? Colors.white24 : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (isClaimed) 
              Positioned.fill(child: Container(color: Colors.black54, child: Icon(Icons.check, color: Colors.greenAccent))),
            if (isLocked && isPremium && !_bpService.isPremium)
              Positioned(top: 8, right: 8, child: Icon(Icons.lock, size: 12, color: Colors.purpleAccent)),
          ],
        ),
      ),
    );
  }

  Widget _getRewardIcon(RewardType type, bool isLocked) {
    IconData icon;
    Color color = isLocked ? Colors.white24 : Colors.amber;
    switch (type) {
      case RewardType.coins: icon = Icons.monetization_on; break;
      case RewardType.xp: icon = Icons.star; break;
      case RewardType.skin: icon = Icons.style; color = Colors.purpleAccent; break;
      case RewardType.theme: icon = Icons.dashboard_customize; color = Colors.orangeAccent; break;
      case RewardType.emote: icon = Icons.emoji_emotions; color = Colors.greenAccent; break;
      case RewardType.title: icon = Icons.badge; color = Colors.blueAccent; break;
      case RewardType.frame: icon = Icons.verified_user; color = Colors.cyanAccent; break;
    }
    return Icon(icon, color: color, size: 28);
  }

  Widget _buildPremiumCTA() {
    if (_bpService.isPremium) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildCTAButton(
                    title: "PREMIUM",
                    price: "KES 400",
                    isUltra: false,
                    color: Colors.blueAccent,
                    onPressed: () => IAPService().purchasePass(ultra: false),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildCTAButton(
                    title: "ULTRA BUNDLE",
                    price: "KES 900",
                    isUltra: true,
                    color: Colors.purpleAccent,
                    onPressed: () => IAPService().purchasePass(ultra: true),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              "Ultra Bundle includes +10 Tiers instantly!",
              style: TextStyle(color: Colors.purpleAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCTAButton({
    required String title,
    required String price,
    required bool isUltra,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 5,
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
          Text(price, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.9))),
        ],
      ),
    );
  }

  void _claim(int level, bool premium) async {
    bool success = await _bpService.claimTier(level, premium);
    if (success) {
      if (mounted) {
        setState(() {});
        CustomToast.show(context, "Reward Unlocked! Check your collection.");
      }
    }
  }
}
