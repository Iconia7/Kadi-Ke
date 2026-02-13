import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/friend_model.dart';
import '../services/friend_service.dart';
import '../services/custom_auth_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<Friend> _friends = [];
  List<Friend> _pendingRequests = [];
  List<Map<String, dynamic>> _searchResults = [];
  
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriends();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    try {
      final friends = await FriendService().getFriendsList(forceRefresh: true);
      final pending = await FriendService().getPendingRequests();
      
      if (mounted) {
        setState(() {
          _friends = friends.where((f) => f.status == 'accepted').toList();
          _pendingRequests = pending;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading friends: $e')),
        );
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await FriendService().searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(String username) async {
    try {
      await FriendService().sendFriendRequest(username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent to $username!')),
        );
        _searchController.clear();
        setState(() => _searchResults = []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    }
  }

  Future<void> _acceptRequest(Friend friend) async {
    final success = await FriendService().acceptFriendRequest(friend.userId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${friend.username} is now your friend!')),
      );
      _loadFriends();
    }
  }

  Future<void> _removeFriend(Friend friend) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E293B),
        title: Text('Remove Friend?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove ${friend.username} from your friends?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await FriendService().removeFriend(friend.userId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${friend.username}')),
        );
        _loadFriends();
      }
    }
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
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Friends',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: _loadFriends,
                      icon: Icon(Icons.refresh, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Color(0xFF00E5FF).withOpacity(0.2),
                    border: Border.all(color: Color(0xFF00E5FF).withOpacity(0.5)),
                  ),
                  labelColor: Color(0xFF00E5FF),
                  unselectedLabelColor: Colors.white38,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: [
                    Tab(text: 'FRIENDS'),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('REQUESTS'),
                          if (_pendingRequests.isNotEmpty) ...[
                            SizedBox(width: 4),
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${_pendingRequests.length}',
                                style: TextStyle(fontSize: 10, color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(text: 'FIND'),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFriendsTab(),
                    _buildRequestsTab(),
                    _buildFindTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'No friends yet',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Search for users in the FIND tab',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return _buildFriendCard(friend);
      },
    );
  }

  Widget _buildFriendCard(Friend friend) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFF00E5FF),
                child: Text(
                  friend.username.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              if (friend.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFF1E293B), width: 2),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.username,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.emoji_events, size: 14, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      '${friend.wins} wins',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    if (!friend.isOnline && friend.lastSeen != null) ...[
                      SizedBox(width: 12),
                      Text(
                        _getLastSeenText(friend.lastSeen!),
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white54),
            color: Color(0xFF1E293B),
            onSelected: (value) {
              if (value == 'remove') {
                _removeFriend(friend);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'invite',
                enabled: false, // Will implement with game invite dialog
                child: Row(
                  children: [
                    Icon(Icons.videogame_asset, color: Colors.white54, size: 20),
                    SizedBox(width: 8),
                    Text('Invite to Game', style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.person_remove, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Remove Friend', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    }

    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'No pending requests',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final friend = _pendingRequests[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFF00E5FF).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.orange,
                child: Text(
                  friend.username.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.username,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Friend request',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _acceptRequest(friend),
                    icon: Icon(Icons.check_circle, color: Colors.green),
                  ),
                  IconButton(
                    onPressed: () => _removeFriend(friend),
                    icon: Icon(Icons.cancel, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFindTab() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.white54),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search username...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                    onChanged: _searchUsers,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchResults = []);
                    },
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),

        // Search Results
        Expanded(
          child: _isSearching
              ? Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
              : _searchResults.isEmpty && _searchController.text.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search, size: 64, color: Colors.white24),
                          SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(color: Colors.white54, fontSize: 18),
                          ),
                        ],
                      ),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group_add, size: 64, color: Colors.white24),
                              SizedBox(height: 16),
                              Text(
                                'Find Friends',
                                style: TextStyle(color: Colors.white54, fontSize: 18),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Search by username to add friends',
                                style: TextStyle(color: Colors.white38, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            final currentUserId = CustomAuthService().userId;
                            final isSelf = user['userId'] == currentUserId;
                            final alreadyFriend = _friends.any((f) => f.userId == user['userId']);

                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.blueAccent,
                                    child: Text(
                                      user['username'].toString().substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user['username'].toString(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '${user['wins'] ?? 0} wins',
                                          style: TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelf)
                                    Chip(
                                      label: Text('You', style: TextStyle(color: Colors.white)),
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                    )
                                  else if (alreadyFriend)
                                    Icon(Icons.check_circle, color: Colors.green)
                                  else
                                    ElevatedButton.icon(
                                      onPressed: () => _sendFriendRequest(user['username']),
                                      icon: Icon(Icons.person_add, size: 18),
                                      label: Text('Add'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF00E5FF),
                                        foregroundColor: Colors.black,
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  String _getLastSeenText(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
