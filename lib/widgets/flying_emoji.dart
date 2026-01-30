import 'package:flutter/material.dart';

class FlyingEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback onComplete;

  const FlyingEmoji({Key? key, required this.emoji, required this.onComplete}) : super(key: key);

  @override
  _FlyingEmojiState createState() => _FlyingEmojiState();
}

class _FlyingEmojiState extends State<FlyingEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: Duration(seconds: 2), vsync: this);

    _animation = Tween<double>(begin: 0, end: -150).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.7, 1.0)),
    );

    _scale = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward().whenComplete(() {
       widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Text(widget.emoji, style: TextStyle(fontSize: 40)),
            ),
          ),
        );
      },
    );
  }
}
