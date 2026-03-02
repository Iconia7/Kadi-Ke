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

  // App palette — Midnight Elite
  static const _amber    = Color(0xFFFFB300);
  static const _amberDim = Color(0x33FFB300);
  static const _card     = Color(0xFF1E2540);
  static const _surface  = Color(0xFF1A1F38);

  @override
  Widget build(BuildContext context) {
    final localTimestamp = timestamp.add(const Duration(hours: 2));
    final String timeStr = DateFormat('h:mm a').format(localTimestamp);

    final bubbleColor = isMe ? _amberDim : _card;
    final borderColor = isMe ? _amber.withOpacity(0.45) : Colors.white.withOpacity(0.06);
    final nameColor   = isMe ? _amber : const Color(0xFF7C9AF0);
    final textColor   = isMe ? _amber : Colors.white;
    final timeColor   = isMe ? _amber.withOpacity(0.55) : Colors.white38;
    final glowColor   = isMe ? _amber.withOpacity(0.15) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: IntrinsicWidth(
              child: Container(
                constraints: const BoxConstraints(minWidth: 64, maxWidth: 260),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe
                        ? const Radius.circular(16)
                        : const Radius.circular(3),
                    bottomRight: isMe
                        ? const Radius.circular(3)
                        : const Radius.circular(16),
                  ),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: glowColor,
                        blurRadius: 12,
                        spreadRadius: 1),
                    const BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          senderName,
                          style: TextStyle(
                            color: nameColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    Text(
                      message,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: timeColor,
                        fontSize: 10,
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
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _amber.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: _amber.withOpacity(0.12), blurRadius: 8),
        ],
      ),
      child: CircleAvatar(
        radius: 17,
        backgroundColor: _surface,
        backgroundImage:
            resolvedUrl != null ? NetworkImage(resolvedUrl) : null,
        child: resolvedUrl == null
            ? const Icon(Icons.person, color: Colors.white54, size: 20)
            : null,
      ),
    );
  }
}
