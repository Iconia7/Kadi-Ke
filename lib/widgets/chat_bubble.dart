import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;

  const ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    // App palette — "Midnight Elite" theme
    const _amber = Color(0xFFFFB300);
    const _amberDim = Color(0x33FFB300);
    const _surface = Color(0xFF1A1F38);
    const _card = Color(0xFF1E2540);

    final bubbleColor = isMe ? _amberDim : _card;
    final textColor = isMe ? _amber : Colors.white70;
    final borderColor = isMe ? _amber.withOpacity(0.5) : Colors.white.withOpacity(0.06);
    final glowColor = isMe ? _amber.withOpacity(0.2) : Colors.transparent;

    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: isMe ? const Radius.circular(14) : const Radius.circular(2),
          bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(14),
        ),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 8, spreadRadius: 1),
          const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
          letterSpacing: 0.2,
          height: 1.3,
        ),
        textAlign: isMe ? TextAlign.right : TextAlign.left,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
