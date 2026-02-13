import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;

  const ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 140),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.blueAccent : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomLeft: isMe ? Radius.circular(12) : Radius.circular(0),
          bottomRight: isMe ? Radius.circular(0) : Radius.circular(12),
        ),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Text(
        message, 
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87, 
          fontSize: 10, 
          fontWeight: FontWeight.bold
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
