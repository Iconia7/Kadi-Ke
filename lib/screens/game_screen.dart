import 'dart:async';
import 'dart:convert';
import 'dart:ui'; 
import 'package:card_game_ke/services/firebase_game_service.dart';
import 'package:card_game_ke/services/online_game_service.dart';
import 'package:card_game_ke/services/theme_service.dart';
import 'package:card_game_ke/services/progression_service.dart';
import 'package:flutter/services.dart'; // ADDED for Haptics
import 'package:flutter/material.dart';
import '../services/achievement_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:confetti/confetti.dart';
import 'package:in_app_update/in_app_update.dart'; 
import '../game_server.dart'; 
import '../widgets/playing_card_widget.dart';
import '../services/deck_service.dart';
import '../services/sound_service.dart';
import '../services/local_game_engine.dart';
import '../services/go_fish_engine.dart';
import '../widgets/flying_emoji.dart'; // Add Import

class GameScreen extends StatefulWidget {
  final bool isHost;
  final String hostAddress; // 'offline', 'localhost', '192...', or 'online'
  final int aiCount;
  final String? onlineGameCode;
  final String gameType; // 'kadi' or 'gofish'

  const GameScreen({super.key, 
    required this.isHost, 
    required this.hostAddress, 
    this.aiCount = 1,
    this.onlineGameCode,
    this.gameType = 'kadi', 
  });

  @override
  _GameScreenState createState() => _GameScreenState();
}

class PlayerInfo {
  final String id;
  final String name;
  final int index;

  PlayerInfo({required this.id, required this.name, required this.index});
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // --- CONNECTION ---
  WebSocketChannel? _channel;
  GameServer? _server;
  FirebaseHostEngine? _onlineHostEngine;
  StreamSubscription? _gameSubscription;
  StreamSubscription? _statusSubscription; // New subscription
  dynamic _localEngine;
  
  List<PlayerInfo> _players = [];

  List<PlayerInfo> get opponents {
    if (_players.isNotEmpty) {
      return _players.where((p) => p.index != _myPlayerId).toList();
    }
    return List.generate(_connectedPlayers - 1, (index) {
      int realIndex = index + 1; // Assuming host is 0
      return PlayerInfo(id: 'bot$realIndex', name: 'Bot $realIndex', index: realIndex);
    });
  }

  int _calculateDecks(int players) {
    if (players <= 7) return 1;
    if (players <= 12) return 2;
    return 3; 
  }

  // --- STATE ---
  bool _declaredNikoKadi = false;
  int _currentBombStack = 0; 
  bool _waitingForAnswer = false;
  bool _isMyTurn = false;
  int _myPlayerId = -1;
  int _activePlayerIndex = 0; 
  List<CardModel> _myHand = [];        
  CardModel? _topDiscardCard;          
  int _connectedPlayers = 1; 
  bool _gameHasStarted = false;
  String _currentThemeId = 'midnight_elite';
  String? _jokerColorConstraint; 

  // Go Fish State
  String? _selectedRankToAsk;
  int? _selectedOpponentIndex;
  List<int> _playerBooks = []; 
  
  // Chat
  String _myName = "Player"; 
  final List<Map<String, dynamic>> _chatMessages = []; 
  bool _chatDialogOpen = false;
  final TextEditingController _chatController = TextEditingController();
  bool _hasUnreadMessages = false; 
  Map<int, List<String>> _activeEmotes = {}; // Maps Player Index to list of active emoji strings 

  // --- ANIMATION CONTROLLERS ---
  late ConfettiController _confettiController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Card Throw Animation
  late AnimationController _cardThrowController;
  late Animation<Offset> _cardThrowAnimation;
  late Animation<double> _cardRotationAnimation;
  late Animation<double> _cardScaleAnimation;
  bool _isAnimatingCard = false;
  int? _animatingCardIndex;
  CardModel? _animatingCard;

  // Emote State


  // Getters
  bool get _isOffline => widget.hostAddress == 'offline';
  bool get _isOnline => widget.hostAddress == 'online';
  bool get _isGoFish => widget.gameType == 'gofish';

  @override
  void initState() {
    super.initState();
    _myPlayerId = widget.isHost ? 0 : 1; 
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    _pulseController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    _cardThrowController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _cardThrowAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(_cardThrowController);
    _cardRotationAnimation = Tween<double>(begin: 0.0, end: 0.2).animate(CurvedAnimation(parent: _cardThrowController, curve: Curves.easeOut));
    _cardScaleAnimation = Tween<double>(begin: 1.0, end: 0.6).animate(CurvedAnimation(parent: _cardThrowController, curve: Curves.easeIn));
    
    _cardThrowController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() { _isAnimatingCard = false; _animatingCardIndex = null; _animatingCard = null; });
        _cardThrowController.reset();
      }
    });
    
    // Check for updates when entering the game screen
    _checkForUpdate();
    
    _initializeConnection();
    
    // Listen to Connection Status
    if (_isOnline) {
       _statusSubscription = OnlineGameService().connectionStatus.listen((status) {
          if (!mounted) return;
          if (status == ConnectionStatus.disconnected) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(children: [Icon(Icons.wifi_off, color: Colors.white), SizedBox(width: 10), Text("Disconnected! Reconnecting...")]),
                backgroundColor: Colors.red,
                duration: Duration(days: 1), // Persistent
             ));
          } else if (status == ConnectionStatus.connected) {
             ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("Connected!"), backgroundColor: Colors.green, duration: Duration(seconds: 2)
             ));
          }
       });
    }

    // Start Pulse Controller for Intense Mode
    _pulseController.repeat(reverse: true);
  }

  // --- INTENSE MODE STATE ---
  bool _isIntenseMode = false;
  CardModel? _lastPlayedCard; // Track for Achievements
  int _entryFee = 0; // Betting Stakes
  bool _hasPaidEntry = false; // Ensure we pay only once



  void _updateIntenseMode() {
     bool intense = false;
     // Intense if bomb stack is high
     if (_currentBombStack > 0) intense = true;
     // Intense if any player (including me) has 1 card
     if (_myHand.length == 1) intense = true;
     for(var p in _players) {
        // We need to know opponent hand size. 
        // Currently _players stores PlayerInfo but not hand size directly unless we sync it.
        // We do have 'UPDATE_TABLE' but usually hand counts are synced or we assume based on something else.
        // For now, let's just use bomb stack or if *I* have 1 card.
     }
     
     if (_isIntenseMode != intense) {
        setState(() => _isIntenseMode = intense);
        if (intense) SoundService.play('heartbeat'); // Loop this? For now just one cue.
     }
  }


  // --- IN-APP UPDATE CHECK ---
  Future<void> _checkForUpdate() async {
    try {
      AppUpdateInfo info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable &&
          info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      print("InAppUpdate failed: $e");
    }
  }

  Future<void> _loadTheme() async {
    // We assume ProgressionService is already initialized correctly in _initializeConnection
    if(mounted) {
       setState(() {
           _currentThemeId = ProgressionService().getSelectedTheme();
       });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(AssetImage('assets/cards/back_blue.png'), context);
  }

  Future<void> _initializeConnection() async {
    // 1. Initialize Firebase first to get the User ID
    await FirebaseGameService().initialize();
    String uId = FirebaseGameService().currentUserId;

    // 2. Initialize Progression with this User ID (to load their specific profile/skins/stats)
    await ProgressionService().initialize(userId: uId);
    
    // 3. Load theme after progression is ready
    _loadTheme();

    // Inside _initializeConnection()
if (_isOnline) {
       // Join the room
       OnlineGameService().joinGame(widget.onlineGameCode!, _myName);

       // LISTEN TO THE STREAM
       _gameSubscription = OnlineGameService().gameStream.listen(
          (data) {
             _handleGameMessage(data);
          },
          // ✅ ADD THIS: Handle Disconnection
          onDone: () {
             if (mounted) {
               _showDisconnectDialog("Connection Lost", "You were disconnected from the server.");
             }
          },
          onError: (error) {
             if (mounted) {
               _showDisconnectDialog("Connection Error", "Error: $error");
             }
          },
       );
    } else if (_isOffline) {
      if (_isGoFish) {
        _localEngine = GoFishEngine();
      } else {
        _localEngine = LocalGameEngine();
      }
      _gameSubscription = _localEngine!.gameStream.listen((data) { _handleGameMessage(data); });
      
      setState(() {
        _connectedPlayers = widget.aiCount + 1;
        _myPlayerId = 0; 
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startGame(); 
      });
    } else {
      if (widget.isHost) {
        _server = GameServer();
        await _server!.start();
        _connectToServer("localhost"); 
      } else {
        _connectToServer(widget.hostAddress);
      }
    }
  }

  void _showDisconnectDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E293B),
        title: Text(title, style: TextStyle(color: Colors.redAccent)),
        content: Text(message, style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close Dialog
              Navigator.pop(context); // Go back to Home
            },
            child: Text("EXIT TO MENU"),
          )
        ],
      ),
    );
  }

  void _showAchievementSnackbar(String text) {
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
           content: Row(children: [Icon(Icons.emoji_events, color: Colors.amber), SizedBox(width: 8), Text(text)]),
           backgroundColor: Colors.purple.withOpacity(0.9),
           behavior: SnackBarBehavior.floating,
           duration: Duration(seconds: 4),
        )
     );
  }


  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          decoration: BoxDecoration(
            color: Color(0xFF1E293B), // Dark slate blue background
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.gavel_rounded, color: Colors.amber, size: 28),
                    SizedBox(width: 12),
                    Text("GAME RULES", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    Spacer(),
                    IconButton(icon: Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context))
                  ],
                ),
              ),
              
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRuleSection("🏆 Objective", 
                        "Be the first to finish your cards. You MUST end on a valid 'Answer' card. You cannot win with a Power Card."),
                      
                      _buildRuleSection("💣 The Bombs", 
                        "• 2 (+2 Cards)\n"
                        "• 3 (+3 Cards)\n"
                        "• Joker (+5 Cards)\n"
                        "• Bombs can be stacked on each other."),

                      _buildRuleSection("🛡️ Defense", 
                        "• Ace: Blocks the bomb (Resets to 0).\n"
                        "• King: Reverses bomb to previous player.\n"
                        "• Jack: Passes bomb to next player (No penalty for you)."),

                      _buildRuleSection("❓ Questions (Q & 8)", 
                        "• If you play a Q or 8, YOU keep the turn.\n"
                        "• You can 'Chain' questions (e.g., Q♥ -> 8♥ -> 8♣).\n"
                        "• You must finish the chain with an 'Answer' card (4,5,6,7,9,10) of the matching suit.\n"
                        "• If you cannot answer, you must pick a card."),

                      _buildRuleSection("🔒 The Ace Lock", 
                        "• Ace of Spades Strategy: If you play Ace ♠ and have 1 card left, the game LOCKS the next move.\n"
                        "• Opponents can ONLY play that specific Rank & Suit.\n"
                        "• Exception: Any Ace breaks the lock."),

                      _buildRuleSection("📢 Niko Kadi", 
                        "• You must press 'NIKO KADI' when you have 1 card left.\n"
                        "• If combining (e.g. Q -> Answer), press it before the last card.\n"
                        "• Penalty: +2 Cards if caught forgetting."),
                        
                      _buildRuleSection("🚫 Winning Restrictions", 
                        "• You CANNOT win with: 2, 3, 8, J, Q, K, A, Joker.\n"
                        "• You CAN win with: 4, 5, 6, 7, 9, 10.\n"
                        "• Combo Win: Q -> 8 -> 5 is a valid win because it ends on a 5."),
                    ],
                  ),
                ),
              ),
              
              // Footer
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white10))),
                child: Center(child: Text("Good Luck!", style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic))),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(content, style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Future<int?> _showDeckChoiceDialog(int players) async {
    final requiredDecks = _calculateDecks(players);

    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E293B),
        title: Text("Deck Setup", style: TextStyle(color: Colors.white)),
        content: Text(
          players > 6
              ? "$players players detected.\nRecommended decks: $requiredDecks"
              : "Standard 1 deck will be used.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          if (players > 6)
            TextButton(
              onPressed: () => Navigator.pop(context, requiredDecks),
              child: Text("USE $requiredDecks DECKS"),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, 1),
            child: Text("FORCE 1 DECK"),
          ),
        ],
      ),
    );
  }

  void _handleGameMessage(Map<String, dynamic> data) async {
    if (!mounted) return;
    String type = data['type'];
    
    if (type == 'PLAYER_COUNT_UPDATE') {
        setState(() => _connectedPlayers = data['data']);
    }
    else if (type == 'PLAYER_INFO') {
      final dataMap = data['data'];
      final playersRaw = dataMap['players'] as List;
      final myId = dataMap['myId'];

      final parsedPlayers = <PlayerInfo>[];
      for (int i = 0; i < playersRaw.length; i++) {
        final p = playersRaw[i];
        parsedPlayers.add(PlayerInfo(
          id: p['id'],
          name: p['name'] ?? 'Player ${i + 1}',
          index: i, 
        ));
      }

      PlayerInfo? me;
      try {
        me = parsedPlayers.firstWhere((p) => p.id == myId);
      } catch (e) { }
       
      int fee = 0;
      if (dataMap['entryFee'] != null) {
          fee = dataMap['entryFee'];
      }

      setState(() {
        _players = parsedPlayers;
        _entryFee = fee;
        
        // Deduct Entry Fee if not Host (Host paid in Home Screen)
        // Only if I'm online and haven't paid yet
        if (_entryFee > 0 && !_hasPaidEntry && !widget.isHost && _isOnline) {
             _payEntryFee();
        }
        if (widget.isHost) _hasPaidEntry = true;
        
        if (me != null) {
          _myPlayerId = me.index;
          _myName = me.name;
        }
        _connectedPlayers = parsedPlayers.length;
      });
    }
    else if (type == 'DEAL_HAND') {
      setState(() {
        _gameHasStarted = true;
        var list = data['data'] as List;
        var newHand = list.map((i) => CardModel.fromJson(i)).toList();
        if (newHand.length > _myHand.length) SoundService.play('deal');
        _myHand = newHand;
      });
    } 
    else if (type == 'UPDATE_TABLE') {
      setState(() => _topDiscardCard = CardModel.fromJson(data['data']));
      SoundService.play('place'); 
    }
    else if (type == 'GO_FISH_STATE') {
      setState(() => _playerBooks = List<int>.from(data['data']['books']));
    }
    else if (type == 'TURN_UPDATE') {
      setState(() {
        int activePlayer = data['data']['playerIndex'];
        _activePlayerIndex = activePlayer;
        _currentBombStack = data['data']['bombStack'] ?? 0;
        _waitingForAnswer = data['data']['waitingForAnswer'] ?? false;
        _jokerColorConstraint = data['data']['jokerColorConstraint']; // Sync constraint
        
        bool wasMyTurn = _isMyTurn;
        _isMyTurn = (activePlayer == _myPlayerId);

        if (_isOnline && _myPlayerId == -1) {
           if (widget.isHost) _myPlayerId = 0;
           else _myPlayerId = 1; 
           _isMyTurn = (activePlayer == _myPlayerId);
        }

        if (_isMyTurn && !wasMyTurn) {
           SoundService.play('turn'); 
           HapticFeedback.mediumImpact(); // Turn Alert
           _selectedRankToAsk = null;
           _selectedOpponentIndex = null;
        }
      });
    }
    else if (type == 'CHAT') {
       setState(() {
         _chatMessages.add(data['data']);
         _hasUnreadMessages = true;
       });
       if (data['data']['message'].toString().contains('Win')) SoundService.play('win');
       _showChatSnackbar(data['data']);
    }
    else if (type == 'GAME_OVER') {
      _handleGameOver(data['data']);
    }
    else if (type == 'EMOTE') {
       int senderId = -1;
       // Find player index by sender ID
       String sid = data['data']['senderId'];
       var p = _players.firstWhere((pl) => pl.id == sid, orElse: () => PlayerInfo(id: '', name: '', index: -1));
       if (p.index != -1) {
          _triggerEmote(p.index, data['data']['emote']);
       }
    }
    else if (type == 'ERROR') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['data']), backgroundColor: Colors.red));
    }
    
  }

  void _onCardTap(int index) {
    if (!_isMyTurn) return;
    if (_isGoFish) {
      setState(() {
        if (_selectedRankToAsk == _myHand[index].rank) {
          _selectedRankToAsk = null;
        } else {
          _selectedRankToAsk = _myHand[index].rank;
        }
      });
    } else {
      _playCardKadi(index);
    }
  }

bool _validateLocalMove(CardModel card) {
    if (_topDiscardCard == null) return true;
    
    // 1. Joker Constraint
    if (_jokerColorConstraint != null) {
      bool isBomb = ['2', '3', 'joker'].contains(card.rank);
      if (isBomb) return true;
      String cardColor = (card.suit == 'hearts' || card.suit == 'diamonds' || card.suit == 'red') ? 'red' : 'black';
      return cardColor == _jokerColorConstraint;
    }

    if (['2', '3', 'joker'].contains(card.rank)) return true;

    // 2. Bomb Stack Logic
    if (_currentBombStack > 0) {
      if (card.rank == 'ace') return true; 
      if (card.rank == 'king') return true; 
      if (card.rank == 'jack') return true; 
      return false; 
    }

    // 3. Question Mode (Self-Answering & Chaining)
    // The UI must allow you to tap Q/8 or the matching Answer suit
    if (_waitingForAnswer) {
       // Chain Q/8
       if (card.rank == 'queen' || card.rank == '8') {
           return card.suit == _topDiscardCard!.suit || card.rank == _topDiscardCard!.rank;
       }
       // Answer (Must be non-power card matching suit)
       if (['4','5','6','7','9','10'].contains(card.rank)) {
           return card.suit == _topDiscardCard!.suit;
       }
       return false;
    }

    // 4. Ace Counter-Play
    if (card.rank == 'ace') return true;

    // 5. Standard Play
    if (card.suit == _topDiscardCard!.suit) return true;
    if (card.rank == _topDiscardCard!.rank) return true;
    
    return false;
  }

  void _playCardKadi(int index) async {
    if (_isAnimatingCard) return; 
    CardModel card = _myHand[index];

    if (!_validateLocalMove(card)) {
       SoundService.play('error');
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
         content: Text("Invalid move! Check Kadi rules.", style: TextStyle(color: Colors.white)),
         backgroundColor: Colors.red.withOpacity(0.8),
         behavior: SnackBarBehavior.floating,
       ));
       return;
    }

    String? reqSuit;
    String? reqRank;

    if (card.rank == 'ace') {
       if (_currentBombStack == 0) {
         var result = await _showAceDialog(card.suit);
         if (result == null) return;
         reqSuit = result['suit'];
         reqRank = result['rank'];
       }
    }

    // Capture state before animation resets it
    bool capturedNikoState = _declaredNikoKadi; 

    final Size size = MediaQuery.of(context).size;
    double totalHandWidth = (_myHand.length * 50.0);
    double startX = (size.width / 2) - (totalHandWidth / 2) + (index * 50.0);
    double startY = size.height - 120; 
    double endX = (size.width / 2) - 40; 
    double endY = size.height * 0.4; 

    setState(() {
      _isAnimatingCard = true;
      _animatingCardIndex = index;
      _animatingCard = card;
      
      _cardThrowAnimation = Tween<Offset>(
        begin: Offset(startX, startY),
        end: Offset(endX, endY), 
      ).animate(CurvedAnimation(parent: _cardThrowController, curve: Curves.easeInOutQuart));
    });
    
    SoundService.play('throw'); 
    HapticFeedback.lightImpact(); // Card Thrown
    
    _lastPlayedCard = card;
    
    // Achievement: Bomb Squad
    if (['2','3','joker'].contains(card.rank) && _currentBombStack > 0) {
       AchievementService().unlock('bomb_squad').then((unlocked) {
          if (unlocked) _showAchievementSnackbar("Bomb Squad Unlocked! 💣");
       });
    }

    try {
      await _cardThrowController.forward();
    } catch (e) {
      print("Animation error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isAnimatingCard = false;
          _animatingCardIndex = null;
          _animatingCard = null;
          _declaredNikoKadi = false; // This reset happens here
        });
        _cardThrowController.reset();
      }
    }

    Map<String, dynamic> payload = {
      "cardIndex": index,
      "requestedSuit": reqSuit,
      "requestedRank": reqRank,
      "saidNikoKadi": capturedNikoState // Use captured value
    };

    if (_isOnline) {
      OnlineGameService().sendAction("PLAY_CARD", payload);
    } else if (_isOffline) {_localEngine!.playCard(index, requestedSuit: reqSuit, requestedRank: reqRank, saidNikoKadi: capturedNikoState);}
    else {_channel?.sink.add(jsonEncode({"type": "PLAY_CARD", ...payload}));}
  }

  void _pickCard() {
    if (!_isMyTurn) return;
    HapticFeedback.selectionClick(); // Interaction
    if (_isOnline) {
        OnlineGameService().sendAction("PICK_CARD", {});
    } else if (_isOffline) {_localEngine!.pickCard();}
    else {_channel?.sink.add(jsonEncode({"type": "PICK_CARD"}));}
  }

  Future<void> _payEntryFee() async {
     bool success = await ProgressionService().spendCoins(_entryFee);
     if (success) {
        _hasPaidEntry = true;
        _showAchievementSnackbar("Paid $_entryFee Coins Entry");
     } else {
        // Not enough money
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Not enough coins for this room! Entry: $_entryFee"), backgroundColor: Colors.red));
     }
  }

  void _startGame() async {
    int decks = 1;
    if (!_isOffline && widget.isHost && _connectedPlayers > 6) {
      final choice = await _showDeckChoiceDialog(_connectedPlayers);
      if (choice == null) return;
      decks = choice;
    }

    if (_isOffline) {
      // ✅ SAFETY CHECK: Prevent crash if engine isn't ready
      if (_localEngine != null) {
         _localEngine.start(widget.aiCount, "Medium", decks: decks); 
      } else {
         print("Error: Local Engine not initialized yet");
      }
    } 
    else if (_isOnline && widget.isHost) {
      OnlineGameService().sendAction("START_GAME", {"decks": decks});
    } 
    else if (!_isOnline) {
      _channel?.sink.add(jsonEncode({"type": "START_GAME", "decks": decks}));
    }
    
    SoundService.play('deal');
  }



  @override
  Widget build(BuildContext context) {
    final theme = TableThemes.getTheme(_currentThemeId);
    
    // Dynamic Gradient for Intense Mode
    List<Color> bgColors = theme.gradientColors;
    if (_isIntenseMode) {
       // Oscillate slightly red/darker
       bgColors = [
         Color.lerp(theme.gradientColors[0], Colors.red.shade900, _pulseController.value * 0.5)!,
         Color.lerp(theme.gradientColors[1], Colors.black, _pulseController.value * 0.5)!
       ];
    }

    return AnimatedBuilder(
      animation: _pulseController, // Rebuild on pulse
      builder: (context, child) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: bgColors,
              ),
            ),
            child: child,
          ),
        );
      },
      child: Stack(
          children: [ // Content Stack
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Image.asset("assets/images/pattern.png", repeat: ImageRepeat.repeat, errorBuilder: (c,e,s)=>SizedBox()),
              ),
            ),
            
            Column(
              children: [
                 _buildTopBar(theme),
                 Expanded(
                   child: _gameHasStarted 
                     ? _buildTableArea(theme)
                     : _buildLobby(theme),
                 ),
                 _buildHandArea(theme),
              ],
            ),
            
            if (_isAnimatingCard && _animatingCard != null)
               _buildFlyingCard(),

            _buildEmoteLayer(), // ADDED: Emote Layer

            _buildChatButton(theme),
            Align(alignment: Alignment.topCenter, child: ConfettiWidget(confettiController: _confettiController, shouldLoop: false)),
          ],
        ),
      );
  }

  Widget _buildChatButton(ThemeModel theme) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emote Button
          GestureDetector(
             onTap: _showEmoteMenu,
             child: Container(
               padding: EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: Colors.amber,
                 shape: BoxShape.circle,
                 boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))],
               ),
               child: Icon(Icons.emoji_emotions, color: Colors.black, size: 28),
             ),
          ),
          SizedBox(width: 16),
          // Chat Button
          Stack(
            children: [
              FloatingActionButton(
                backgroundColor: theme.accentColor,
                onPressed: () => _showChatDialog(),
                child: Icon(Icons.chat_bubble, color: Colors.black),
              ),
              if (_hasUnreadMessages)
                Positioned(
                  right: 0, top: 0,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: BoxConstraints(minWidth: 12, minHeight: 12),
                  ),
                )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ThemeModel theme) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
            SizedBox(width: 12),

            GestureDetector(
            onTap: () => _showRulesDialog(),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(Icons.menu_book_rounded, color: Colors.blueAccent, size: 20),
            ),
          ),
          SizedBox(width: 12),
            
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    height: 56,
                    color: Colors.white.withOpacity(0.05),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                         if (_isOnline && widget.onlineGameCode != null)
                           Text("ROOM: ${widget.onlineGameCode}", style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.bold, fontSize: 10)),
                         Expanded(
                           child: ListView.builder(
                             scrollDirection: Axis.horizontal,
                             itemCount: opponents.length,
                             itemBuilder: (context, index) {
                               final player = opponents[index];
                               final pIndex = player.index;
                               
                               bool isTurn = pIndex == _activePlayerIndex;
                               bool isSelected = _isGoFish && _selectedOpponentIndex == pIndex;
                               int bookCount = (_isGoFish && _playerBooks.length > pIndex) ? _playerBooks[pIndex] : 0;
                               
                               return GestureDetector(
                                 onTap: () => setState(() => _selectedOpponentIndex = pIndex),
                                 child: Container(
                                   margin: EdgeInsets.only(left: 12),
                                   child: Column(
                                     mainAxisAlignment: MainAxisAlignment.center,
                                     children: [
                                       Container(
                                         padding: EdgeInsets.all(2),
                                         decoration: BoxDecoration(
                                            shape: BoxShape.circle, 
                                            border: Border.all(
                                              color: isSelected ? theme.accentColor : (isTurn ? Colors.green : Colors.white24), 
                                              width: 2
                                            )
                                         ),
                                         child: CircleAvatar(
                                           radius: 14, 
                                           backgroundColor: Colors.black38,
                                           child: Icon(Icons.person, size: 16, color: Colors.white70),
                                         ),
                                       ),
                                       Row(
                                          children: [
                                            Text(player.name, style: TextStyle(color: Colors.white54, fontSize: 10)),
                                            if(_isGoFish)
                                               Text(" ($bookCount)", style: TextStyle(color: theme.accentColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                       )
                                     ],
                                   ),
                                 ),
                               );
                             },
                           ),
                         ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTableArea(ThemeModel theme) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: theme.tableColor,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: -5)
        ]
      ),
      child: Center(
        child: _isGoFish 
          ? _buildGoFishTable() 
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCardSlot("DECK", null, isDeck: true),
                SizedBox(width: 40),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildCardSlot("PILE", _topDiscardCard),
                    if (_currentBombStack > 0)
                      Positioned(
                        top: -10,
                        right: -10,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.6), blurRadius: 10)],
                          ),
                          child: Text("+${_currentBombStack}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
      ),
    );
  }
  
  Widget _buildCardSlot(String label, CardModel? card, {bool isDeck = false}) {
     return Column(
       mainAxisSize: MainAxisSize.min,
       children: [
         Container(
           width: 90, height: 130,
           decoration: BoxDecoration(
             borderRadius: BorderRadius.circular(10),
             border: Border.all(color: Colors.white10, width: 2),
             color: Colors.black12,
           ),
           child: isDeck 
             ? PlayingCardWidget(suit: 'back', rank: 'deck', isFaceDown: true, width: 90, height: 130)
             : (card != null 
                 ? PlayingCardWidget(suit: card.suit, rank: card.rank, width: 90, height: 130)
                 : Center(child: Icon(Icons.layers_clear, color: Colors.white10, size: 40))),
         ),
         SizedBox(height: 10),
         Text(label, style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 10))
       ],
     );
  }

  Widget _buildGoFishTable() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.water, size: 40, color: Colors.blue.withOpacity(0.3)),
        SizedBox(height: 10),
        Text("THE POND", style: TextStyle(color: Colors.blue.withOpacity(0.5), fontWeight: FontWeight.bold, letterSpacing: 3)),
        SizedBox(height: 20),
        Stack(
          clipBehavior: Clip.none,
          children: [
             Transform.translate(offset: Offset(-10, -5), child: Transform.rotate(angle: -0.1, child: _buildCardSlot("", null, isDeck: true))),
             Transform.translate(offset: Offset(10, 5), child: Transform.rotate(angle: 0.1, child: _buildCardSlot("", null, isDeck: true))),
             _buildCardSlot("", null, isDeck: true),
          ],
        )
      ],
    );
  }

  Widget _buildHandArea(ThemeModel theme) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.8)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: _isMyTurn
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_isGoFish) ...[
                        _buildGameButton(
                          _currentBombStack > 0 ? "PICK $_currentBombStack" : "PICK",
                          Icons.add,
                          Colors.orange,
                          _pickCard,
                        ),
                        SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => setState(() => _declaredNikoKadi = !_declaredNikoKadi),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: _declaredNikoKadi ? Colors.redAccent : Colors.grey[800],
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: _declaredNikoKadi ? [BoxShadow(color: Colors.redAccent, blurRadius: 10)] : [],
                            ),
                            child: Text("NIKO KADI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ] else ...[
                        if (_selectedRankToAsk != null && _selectedOpponentIndex != null) ...[
                          Builder(builder: (context) {
                             String name = "P${_selectedOpponentIndex! + 1}";
                             if (_players.isNotEmpty) {
                               try {
                                 final opponent = _players.firstWhere((p) => p.index == _selectedOpponentIndex);
                                 name = opponent.name;
                               } catch (e) { }
                             }
                             return _buildGameButton("ASK $name", Icons.check, Colors.green, _confirmAsk);
                          }),
                        ] else
                          Text("Select a card and opponent", style: TextStyle(color: Colors.white54)),
                      ]
                    ],
                  )
                : Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                    child: Text("WAITING FOR OPPONENT...", style: TextStyle(color: Colors.white38, letterSpacing: 1)),
                  ),
          ),

          SizedBox(
            height: 160,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              clipBehavior: Clip.none, 
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: (_myHand.length > 0) ? (_myHand.length * 40.0) + 90.0 : MediaQuery.of(context).size.width,
                child: Stack(
                  clipBehavior: Clip.none, 
                  children: _myHand.asMap().entries.map((entry) {
                    int index = entry.key;
                    CardModel card = entry.value;
                    bool isSelected = _isGoFish && _selectedRankToAsk == card.rank;

                    if (_isAnimatingCard && _animatingCardIndex == index) return SizedBox();

                    double overlap = 40.0; 
                    double left = index * overlap.toDouble();

                    return Positioned(
                      left: left,
                      bottom: 0, 
                      child: GestureDetector(
                        onTap: _isMyTurn ? () => _onCardTap(index) : null,
                        child: Opacity(
                          opacity: _isMyTurn ? 1.0 : 0.5,
                          child: Transform.translate(
                            offset: Offset(0, isSelected ? -20 : 0),
                            child: PlayingCardWidget(suit: card.suit, rank: card.rank, width: 90, height: 130),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobby(ThemeModel theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.gamepad, size: 60, color: Colors.white24),
        SizedBox(height: 20),
        Text("LOBBY", style: TextStyle(color: theme.accentColor, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
        SizedBox(height: 10),
        Text("$_connectedPlayers Players Ready", style: TextStyle(color: Colors.white54)),
        SizedBox(height: 10),
        if (_isOnline && widget.onlineGameCode != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
            child: Text("ROOM CODE: ${widget.onlineGameCode}", style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.bold)),
          ),
        SizedBox(height: 40),
        if (widget.isHost || _isOffline)
          ScaleTransition(
            scale: _pulseAnimation,
            child: _buildGameButton("START GAME", Icons.play_arrow, Colors.green, _startGame),
          ),
      ],
    );
  }
  
  Widget _buildGameButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: StadiumBorder(),
        elevation: 10,
        shadowColor: color.withOpacity(0.5),
      ),
    );
  }
  
  Widget _buildFlyingCard() {
    return AnimatedBuilder(
      animation: _cardThrowController,
      builder: (context, child) {
        return Positioned(
          left: _cardThrowAnimation.value.dx,
          top: _cardThrowAnimation.value.dy,
          child: Transform.rotate(
            angle: _cardRotationAnimation.value,
            child: Transform.scale(
              scale: _cardScaleAnimation.value,
              child: PlayingCardWidget(suit: _animatingCard!.suit, rank: _animatingCard!.rank, width: 90, height: 130),
            ),
          ),
        );
      },
    );
  }
  
Future<void> _handleGameOver(String msg) async {
    bool didIWin = msg.contains("You") || msg.contains(_myName);
    int coinsEarned = 0;

    // 1. Handle Stats & Coins
    if (didIWin) {
      coinsEarned = 100;
      if (_isOnline) {
         int totalWins = await ProgressionService().getTotalWins();
         await FirebaseGameService().updateHighscore(_myName, totalWins);
         
         if (_entryFee > 0) {
            int winnings = _entryFee * _players.length;
            await ProgressionService().addCoins(winnings);
            _showAchievementSnackbar("won $winnings Coins!");
         }
      }
      
      // Achievement: First Win & Sniper & Rich Kid
      await AchievementService().unlock('first_win').then((u) { if(u) _showAchievementSnackbar("First Blood 🩸"); });
      
      if (_lastPlayedCard?.rank == 'ace') {
         await AchievementService().unlock('sniper').then((u) { if(u) _showAchievementSnackbar("Sniper 🎯"); });
      }
      
      int coins = await ProgressionService().getCoins();
      if (coins >= 1000) {
         await AchievementService().unlock('rich_kid').then((u) { if(u) _showAchievementSnackbar("Rich Kid 💰"); });
      }

      _confettiController.play();
      SoundService.play('win');
      HapticFeedback.heavyImpact(); // VICTORY!
    } else {
      await ProgressionService().recordGameResult(false);
      SoundService.play('error'); // or a 'defeat' sound
      HapticFeedback.heavyImpact(); // DEFEAT :(
    }

    // 2. Show Dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to click a button
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // --- MAIN CARD ---
            Container(
              padding: EdgeInsets.fromLTRB(24, 60, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: didIWin 
                    ? [Color(0xFF1E293B), Color(0xFF0F172A)] // Victory Blue/Black
                    : [Color(0xFF2C1E1E), Color(0xFF1A1111)], // Defeat Red/Black
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: didIWin ? Colors.amber.withOpacity(0.5) : Colors.red.withOpacity(0.3), 
                  width: 2
                ),
                boxShadow: [
                  BoxShadow(
                    color: didIWin ? Colors.amber.withOpacity(0.2) : Colors.black45, 
                    blurRadius: 30, 
                    spreadRadius: 5
                  )
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // TITLE
                  Text(
                    didIWin ? "VICTORY!" : "GAME OVER", 
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.w900, 
                      color: didIWin ? Colors.amber : Colors.grey, 
                      letterSpacing: 2, 
                      shadows: [Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0,2))]
                    )
                  ),
                  
                  SizedBox(height: 12),
                  
                  // MESSAGE (e.g., "Player 2 Wins!")
                  Text(
                    msg, 
                    textAlign: TextAlign.center, 
                    style: TextStyle(color: Colors.white70, fontSize: 16)
                  ),
                  
                  SizedBox(height: 24),
                  
                  // COINS REWARD (Only for Winner)
                  if (didIWin)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(16), 
                        border: Border.all(color: Colors.amber.withOpacity(0.3))
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                          SizedBox(width: 10),
                          Text(
                            "+$coinsEarned Coins", 
                            style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ),
                    
                  SizedBox(height: 32),
                  
                  // BUTTONS ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // --- EXIT BUTTON (Goes to Home) ---
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); 
                          Navigator.pop(context, didIWin ? 'WON' : 'LOST'); 
                        }, 
                        child: Text(
                          "EXIT", 
                          style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)
                        )
                      ),
                      
                      // --- PLAY AGAIN BUTTON ---
                      ElevatedButton.icon(
                        onPressed: () {
                           Navigator.pop(context); // Close Dialog
                           
                           if (widget.isHost || _isOffline) {
                             // Host/Offline: Actually restarts the game logic
                             _startGame(); 
                           } else {
                             // Client: Just closes dialog to wait for Host
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text("Waiting for Host to restart..."))
                             );
                           }
                        }, 
                        icon: Icon(Icons.refresh),
                        label: Text("PLAY AGAIN"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: didIWin ? Colors.green : Colors.grey[700], 
                          foregroundColor: Colors.white, 
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12), 
                          shape: StadiumBorder()
                        )
                      )
                    ],
                  )
                ],
              ),
            ),
            
            // --- TOP ICON (Trophy vs Sad Face) ---
            Positioned(
              top: -40,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: didIWin 
                      ? [Colors.amber, Colors.orange] 
                      : [Colors.grey[700]!, Colors.grey[900]!]
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: didIWin ? Colors.amber.withOpacity(0.4) : Colors.black45, 
                      blurRadius: 15, 
                      offset: Offset(0, 5)
                    )
                  ],
                  border: Border.all(color: Colors.white24, width: 4)
                ),
                child: Icon(
                  didIWin ? Icons.emoji_events_rounded : Icons.sentiment_very_dissatisfied, 
                  size: 40, 
                  color: Colors.white
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _confirmAsk() {
    if (_selectedRankToAsk == null || _selectedOpponentIndex == null) return;
    Map<String, dynamic> payload = {"targetIndex": _selectedOpponentIndex, "rank": _selectedRankToAsk};
    if (_isOnline) {
      OnlineGameService().sendAction("ASK_CARD", payload);
    } else if (_isOffline) {_localEngine.askForCard(_selectedOpponentIndex!, _selectedRankToAsk!);}
    setState(() { _selectedRankToAsk = null; _selectedOpponentIndex = null; });
  }

  void _connectToServer(String ip) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://$ip:8080'));
      _channel!.stream.listen((message) => _handleGameMessage(jsonDecode(message)));
    } catch (e) { print(e); }
  }
  


  Widget _chatBubble(Map<String, dynamic> msg) {
    final bool isMe = msg['sender'] == _myName;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe) Text(msg['sender'], style: TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
            Text(msg['message'], style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  void _showChatDialog() {
    _chatDialogOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.5, // 50% height
            decoration: BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                Padding(padding: EdgeInsets.all(12), child: Text("GAME CHAT", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 2))),
                Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _chatMessages.length,
                    itemBuilder: (c, i) => _chatBubble(_chatMessages[_chatMessages.length - 1 - i]),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: TextField(
                        controller: _chatController,
                        style: TextStyle(color: Colors.white),
                        cursorColor: Colors.blueAccent, // Added visible cursor
                        decoration: InputDecoration(
                          hintText: "Type message...", 
                          hintStyle: TextStyle(color: Colors.white38), 
                          filled: true, 
                          fillColor: Colors.black26, 
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)
                        ),
                        onSubmitted: (_) => _sendChat(),
                      )),
                      SizedBox(width: 8),
                      IconButton(icon: Icon(Icons.send, color: Colors.blueAccent), onPressed: _sendChat),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) => _chatDialogOpen = false);
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    if (_isOnline) {
      OnlineGameService().sendAction("CHAT", {"senderName": _myName, "message": text});
    } else if (_isOffline) {
       // Local play: just add to list, bots don't chat back usually in this setup yet
       setState(() {
         _chatMessages.add({"sender": _myName, "message": text});
       });
    } else {
      // LAN
      _channel?.sink.add(jsonEncode({
        "type": "CHAT", 
        "senderName": _myName, 
        "message": text
      }));
    }

    _chatController.clear();
  }

  // --- VOICE LOGIC ---
  void _playVoiceLine(String type) {
     // Placeholder for voice lines.
     // e.g. SoundService.play('voice_$type');
     // 'win', 'lose', 'uno', 'pick'
  }

  // --- EMOTE LOGIC ---
  void _triggerEmote(int playerIndex, String emote) {
      if (!_activeEmotes.containsKey(playerIndex)) _activeEmotes[playerIndex] = [];
      setState(() {
         _activeEmotes[playerIndex]!.add(emote);
      });
      SoundService.play('pop'); // Reuse a sound or add 'pop'
  }

  Widget _buildEmoteLayer() {
     // Overlay that maps players to positions
     List<Widget> emojis = [];
     
     _activeEmotes.forEach((pIndex, emoteList) {
        // Determine position
        bool isMe = pIndex == _myPlayerId;
        // Simple mapping: Me = Bottom Center. Others = Top Center (for now)
        // Ideally we map to the exact avatar position, but simpler is fine.
        double top = isMe ? MediaQuery.of(context).size.height - 200 : 100;
        double left = MediaQuery.of(context).size.width / 2;

        if (!isMe && opponents.isNotEmpty) {
           // Try to find specific opponent index visual
           int screenIdx = opponents.indexWhere((p) => p.index == pIndex);
           if (screenIdx != -1) {
              // Distribute along top based on list index
              double step = MediaQuery.of(context).size.width / (opponents.length + 1);
              left = step * (screenIdx + 1);
              top = 80; // Near top bar
           }
        }

        for (var emote in emoteList) {
           emojis.add(
             Positioned(
               top: top, left: left - 20, // Center it
               child: FlyingEmoji(
                 emoji: emote, 
                 onComplete: () {
                    if (mounted) {
                      setState(() {
                         _activeEmotes[pIndex]?.remove(emote);
                      });
                    }
                 }
               )
             )
           );
        }
     });
     
     return IgnorePointer(child: Stack(children: emojis));
  }

  void _showEmoteMenu() {
     showModalBottomSheet(
       context: context, 
       backgroundColor: Colors.transparent,
       builder: (c) => Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
             color: Color(0xFF1E293B),
             borderRadius: BorderRadius.vertical(top: Radius.circular(24))
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Text("SEND EMOTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
               SizedBox(height: 20),
               Wrap(
                 spacing: 20, runSpacing: 20,
                 children: ['😂','😎','😡','😭','❤️','👍','👋','🤔'].map((e) => 
                    GestureDetector(
                       onTap: () {
                          Navigator.pop(context);
                          _sendEmote(e);
                       },
                       child: Text(e, style: TextStyle(fontSize: 40)),
                    )
                 ).toList(),
               )
            ],
          ),
       )
     );
  }

  void _sendEmote(String emote) {
     if (_isOffline) {
        _triggerEmote(_myPlayerId, emote);
     } else if (_isOnline) {
        OnlineGameService().sendAction("EMOTE", {"emote": emote});
     }
     AchievementService().unlock('social_butterfly').then((u) { if(u) _showAchievementSnackbar("Social Butterfly 🦋"); });
  }

  void _showChatSnackbar(dynamic data) {
    if (_chatDialogOpen) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${data['sender']}: ${data['message']}"), duration: Duration(seconds: 2)));
  }
  
  Future<Map<String, String?>?> _showAceDialog(String currentSuit) async {
    String selectedSuit = currentSuit;
    String? selectedRank;
    bool isSpades = currentSuit == 'spades';

    return await showDialog<Map<String, String?>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF1E3A5F).withOpacity(0.9), Color(0xFF2E5077).withOpacity(0.9)]),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("CHOOSE SUIT",
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 20),
                      Wrap(
                        spacing: 15,
                        runSpacing: 15,
                        alignment: WrapAlignment.center,
                        children: ['hearts', 'diamonds', 'clubs', 'spades'].map((suit) {
                          bool isSelected = selectedSuit == suit;
                          return GestureDetector(
                            onTap: () => setState(() => selectedSuit = suit),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.amber : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isSelected ? Colors.amber : Colors.white12, width: 2),
                              ),
                              child: PlayingCardWidget(
                                suit: suit,
                                rank: 'ace',
                                width: 50,
                                height: 75,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (isSpades) ...[
                         SizedBox(height: 20),
                         // Simple Rank Dropdown for Spades
                         Container(
                           padding: EdgeInsets.symmetric(horizontal: 12),
                           decoration: BoxDecoration(
                             color: Colors.white10,
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: DropdownButton<String>(
                             value: selectedRank,
                             hint: Text("Request Rank (Optional)", style: TextStyle(color: Colors.white70)),
                             dropdownColor: Color(0xFF1E3A5F),
                             underline: SizedBox(),
                             icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                             style: TextStyle(color: Colors.white),
                             items: ['4','5','6','7','9','10','jack','queen','king']
                                 .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                             onChanged: (val) => setState(() => selectedRank = val),
                           ),
                         ),
                      ],
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, {"suit": selectedSuit, "rank": selectedRank});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                        child: Text("CONFIRM", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _gameSubscription?.cancel();
    if (_isOnline) OnlineGameService().disconnect();
    _onlineHostEngine?.stop();
    FirebaseGameService().leaveGame();
    _localEngine?.dispose();
    _channel?.sink.close();
    _server?.stop(); 
    _confettiController.dispose();
    _pulseController.dispose();
    _cardThrowController.dispose();
    super.dispose();
  }
}