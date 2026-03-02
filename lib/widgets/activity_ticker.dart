import 'dart:async';
import 'package:flutter/material.dart';

class ActivityTicker extends StatefulWidget {
  final Stream<String> eventStream;
  final Color backgroundColor;
  final Color textColor;

  const ActivityTicker({
    Key? key,
    required this.eventStream,
    this.backgroundColor = Colors.black45,
    this.textColor = Colors.white70,
  }) : super(key: key);

  @override
  _ActivityTickerState createState() => _ActivityTickerState();
}

class _ActivityTickerState extends State<ActivityTicker> {
  final List<String> _messages = [
    "Welcome to Kadi KE Online! 🃏",
    "Join a Tournament to Win Big Prizes! 🏆",
    "Join a Clan today and Win Coins and Points for your Clan! 🏆",
    "Customize your Table in the Shop Menu. 🎨",
  ];
  late ScrollController _scrollController;
  late Timer _timer;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // Listen for new global events
    _subscription = widget.eventStream.listen((event) {
      if (mounted) {
        setState(() {
          _messages.add(event);
          if (_messages.length > 20) _messages.removeAt(0);
        });
      }
    });

    // Start auto-scroll after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  void _startScrolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;
        
        if (currentScroll >= maxScroll) {
          // Reset to start if we reached the end
          _scrollController.jumpTo(0);
        } else {
          _scrollController.animateTo(
            currentScroll + 1.5,
            duration: const Duration(milliseconds: 60),
            curve: Curves.linear,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: double.infinity,
      color: widget.backgroundColor,
      child: Center(
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  _messages[index],
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
