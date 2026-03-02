import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/custom_auth_service.dart';
import '../services/progression_service.dart';

class CustomAvatar extends StatelessWidget {
  static const String _useSelf = "__USE_SELF__";

  final double size;
  final double? radius;
  final String? overrideAvatarUrl;
  final String? overrideFrameId;
  final bool showGlow;

  const CustomAvatar({
    Key? key,
    this.size = 60,
    this.radius,
    this.overrideAvatarUrl = _useSelf,
    this.overrideFrameId = _useSelf,
    this.showGlow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double effectiveSize = radius != null ? radius! * 2 : size;
    
    // Logic: If explicitly passed as null, we DON'T use self. 
    // If not passed at all (default to _useSelf), we use self.
    final frameId = overrideFrameId == _useSelf 
        ? ProgressionService().getSelectedFrame() 
        : overrideFrameId;
        
    final frame = AvatarFrames.getFrame(frameId ?? 'default');
    
    final avatarUrl = overrideAvatarUrl == _useSelf 
        ? CustomAuthService().avatar 
        : overrideAvatarUrl;
        
    final baseUrl = CustomAuthService().baseUrl;

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          if (showGlow && frame.glowColor != Colors.transparent)
            BoxShadow(
              color: frame.glowColor,
              blurRadius: effectiveSize * 0.2,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The Border/Frame
          Container(
            width: effectiveSize,
            height: effectiveSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: frame.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // The Inner Cutout (Background for Avatar)
          Container(
            width: effectiveSize - (frame.borderWidth * 2),
            height: effectiveSize - (frame.borderWidth * 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1E293B), // Same as typical background
            ),
          ),

          // The Actual Avatar
          ClipOval(
            child: Container(
              width: effectiveSize - (frame.borderWidth * 2) - 2, // Slight gap
              height: effectiveSize - (frame.borderWidth * 2) - 2,
              color: Colors.black26,
              child: avatarUrl != null
                  ? Image.network(
                      "$baseUrl$avatarUrl",
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Icon(Icons.person, size: effectiveSize * 0.5, color: Colors.white24),
                    )
                  : Icon(Icons.person, size: effectiveSize * 0.5, color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }
}
