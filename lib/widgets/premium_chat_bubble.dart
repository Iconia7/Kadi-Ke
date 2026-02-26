import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/app_config.dart';

class PremiumChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String? avatarUrl;
  final String senderName;
  final DateTime timestamp;

  const PremiumChatBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.senderName,
    required this.timestamp,
    this.avatarUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Server is UTC, local timezone is UTC+3 → add 3 hours to display correct local time
    final localTimestamp = timestamp.add(const Duration(hours: 2));
    final String timeStr = DateFormat('h:mm a').format(localTimestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: IntrinsicWidth(
              child: Container(
                constraints: const BoxConstraints(minWidth: 60),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? Colors.amber : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          senderName,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      message,
                      style: TextStyle(
                        color: isMe ? Colors.black87 : Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        timeStr,
                        style: TextStyle(
                          color: isMe ? Colors.black54 : Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            _buildAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final resolvedUrl = AppConfig.resolveAvatarUrl(avatarUrl);
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey.shade800,
      backgroundImage: resolvedUrl != null ? NetworkImage(resolvedUrl) : null,
      child: resolvedUrl == null
          ? const Icon(Icons.person, color: Colors.white, size: 20)
          : null,
    );
  }
}
