// Helper method to notify friends when user comes online
  void _notifyFriendsUserOnline(String userId, String username) {
    try {
      // Find the user's friends list
      String? userUsername;
      _users.forEach((uname, userData) {
        if (userData['id'] == userId) {
          userUsername = uname;
        }
      });
      
      if (userUsername == null) return;
      
      final friends = (_users[userUsername]!['friends'] ?? []) as List;
      
      // Notify each accepted friend who is online
      for (var friend in friends) {
        if (friend['status'] == 'accepted') {
          final friendUserId = friend['userId'];
          
          // Check if friend is online
          if (_onlineUsers.containsKey(friendUserId) && _userSockets.containsKey(friendUserId)) {
            // Send notification through WebSocket
            try {
              _userSockets[friendUserId]!.add(jsonEncode({
                'type': 'FRIEND_ONLINE',
                'data': {
                  'friendId': userId,
                  'friendName': username,
                }
              }));
              _log("Notified $friend Username about $username coming online");
            } catch (e) {
              _log("Error sending friend online notification: $e", level: 'ERROR');
            }
          }
        }
      }
    } catch (e) {
      _log("Error in _notifyFriendsUserOnline: $e", level: 'ERROR');
    }
  }
