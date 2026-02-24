import 'package:flutter/material.dart';

class CustomToast {
  static void show(BuildContext context, String message, {bool isError = false, IconData? icon}) {
    if (!context.mounted) return;
    
    // Fallback if no overlay available (unlikely but safe)
    if (Overlay.maybeOf(context) == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.teal));
      return;
    }

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        isError: isError,
        icon: icon,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final IconData? icon;
  final VoidCallback onDismiss;

  const _ToastWidget({
    Key? key,
    required this.message, 
    this.isError = false, 
    this.icon, 
    required this.onDismiss
  }) : super(key: key);

  @override
  __ToastWidgetState createState() => __ToastWidgetState();
}

class __ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _offset = Tween<Offset>(begin: const Offset(0, -1.0), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 20,
      right: 20,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: _offset,
            child: FadeTransition(
              opacity: _opacity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.isError ? Colors.redAccent.shade700.withOpacity(0.95) : const Color(0xFF1E293B).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isError ? Colors.red.withOpacity(0.4) : Colors.black54,
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                  border: Border.all(
                    color: widget.isError ? Colors.red.shade300 : Colors.tealAccent.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isError ? Colors.red.shade900 : Colors.teal.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon ?? (widget.isError ? Icons.error_outline : Icons.check_circle_outline),
                        color: widget.isError ? Colors.white : Colors.tealAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
