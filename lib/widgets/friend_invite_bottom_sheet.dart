import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../services/friend_service.dart';
import '../services/notification_service.dart';

/// Bottom sheet for inviting friends to a game
/// Supports both Online (room code) and LAN (IP address) modes
class FriendInviteBottomSheet extends StatefulWidget {
  final String? roomCode;
  final String? ipAddress;
  final String gameMode;

  const FriendInviteBottomSheet({
    Key? key,
    this.roomCode,
    this.ipAddress,
    this.gameMode = 'Kadi',
  }) : super(key: key);

  @override
  State<FriendInviteBottomSheet> createState() => _FriendInviteBottomSheetState();
}

class _FriendInviteBottomSheetState extends State<FriendInviteBottomSheet> {
  List<Friend> _friends = [];
  Set<String> _selectedFriendIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await FriendService().getFriendsList();
      setState(() {
        _friends = friends;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading friends: $e')),
        );
      }
    }
  }

  Future<void> _sendInvites() async {
    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one friend')),
      );
      return;
    }

    try {
      final selectedFriends = _friends.where((f) => _selectedFriendIds.contains(f.userId)).toList();
      
      for (final friend in selectedFriends) {
        if (widget.roomCode != null) {
          // Online mode - send room code
          await NotificationService().showGameInviteNotification(
            friend.username,
            widget.roomCode!,
          );
        } else if (widget.ipAddress != null) {
          // LAN mode - send IP address
          await NotificationService().showGameInviteNotification(
            friend.username,
            widget.ipAddress!,
            ipAddress: widget.ipAddress,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent ${_selectedFriendIds.length} invite(s)!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending invites: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.person_add, color: Color(0xFF00E5FF)),
              const SizedBox(width: 12),
              const Text(
                'Invite Friends',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Game info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(
                  widget.roomCode != null ? Icons.cloud_outlined : Icons.wifi,
                  color: const Color(0xFF00E5FF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.roomCode != null
                      ? 'Room: ${widget.roomCode}'
                      : 'LAN: ${widget.ipAddress}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Loading or friend list
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            )
          else if (_friends.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.group_off, size: 48, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    'No friends yet',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add friends from the Friends screen',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _friends.length,
                itemBuilder: (context, index) {
                  final friend = _friends[index];
                  final isSelected = _selectedFriendIds.contains(friend.userId);
                  
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedFriendIds.add(friend.userId);
                        } else {
                          _selectedFriendIds.remove(friend.userId);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        Text(
                          friend.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (friend.isOnline)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      friend.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: friend.isOnline ? Colors.greenAccent : Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    activeColor: const Color(0xFF00E5FF),
                    checkColor: Colors.black,
                    tileColor: isSelected ? Colors.white.withOpacity(0.05) : null,
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          // Send button
          if (_friends.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sendInvites,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _selectedFriendIds.isEmpty
                      ? 'Select Friends'
                      : 'Send Invites (${_selectedFriendIds.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
