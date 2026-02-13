import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../services/friend_service.dart';

class FriendInviteDialog extends StatefulWidget {
  final String gameType; // 'kadi' or 'gofish'
  final String? roomCode; // If room already exists
  final Function(String friendUserId, String friendUsername)? onInviteSent;

  const FriendInviteDialog({
    super.key,
    required this.gameType,
    this.roomCode,
    this.onInviteSent,
  });

  @override
  State<FriendInviteDialog> createState() => _FriendInviteDialogState();
}

class _FriendInviteDialogState extends State<FriendInviteDialog> {
  List<Friend> _onlineFriends = [];
  bool _isLoading = true;
  Set<String> _sentInvites = {};

  @override
  void initState() {
    super.initState();
    _loadOnlineFriends();
  }

  Future<void> _loadOnlineFriends() async {
    setState(() => _isLoading = true);
    try {
      final friends = await FriendService().getOnlineFriends();
      if (mounted) {
        setState(() {
          _onlineFriends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load friends: $e')),
        );
      }
    }
  }

  void _sendInvite(Friend friend) {
    // Mark as sent
    setState(() => _sentInvites.add(friend.userId));
    
    // Call callback if provided
    widget.onInviteSent?.call(friend.userId, friend.username);
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invitation sent to ${friend.username}!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 500, maxWidth: 400),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.group_add, color: Color(0xFF00E5FF), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite Friends',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'to ${widget.gameType.toUpperCase()} game',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(color: Colors.white12),
            SizedBox(height: 16),

            // Online Friends List
            if (_isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                ),
              )
            else if (_onlineFriends.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off_outlined, size: 48, color: Colors.white24),
                      SizedBox(height: 12),
                      Text(
                        'No friends online',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Invite friends to join Kadi!',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _onlineFriends.length,
                  itemBuilder: (context, index) {
                    final friend = _onlineFriends[index];
                    final hasInvited = _sentInvites.contains(friend.userId);

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasInvited 
                              ? Colors.green.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Avatar with online indicator
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Color(0xFF00E5FF),
                                child: Text(
                                  friend.username.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Color(0xFF1E293B), width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 12),
                          
                          // Friend info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  friend.username,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.emoji_events, size: 12, color: Colors.amber),
                                    SizedBox(width: 4),
                                    Text(
                                      '${friend.wins} wins',
                                      style: TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Invite button
                          ElevatedButton(
                            onPressed: hasInvited ? null : () => _sendInvite(friend),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasInvited ? Colors.green : Color(0xFF00E5FF),
                              foregroundColor: Colors.black,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasInvited ? Icons.check : Icons.send,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  hasInvited ? 'Sent' : 'Invite',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Info footer
            if (_onlineFriends.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF00E5FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF00E5FF).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF00E5FF), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Friends will receive a notification',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
