import 'package:flutter/material.dart';

class ThemeModel {
  final String id;
  final String name;
  final List<Color> gradientColors; // Background gradient
  final Color tableColor;           // Felt color
  final Color accentColor;          // Buttons/Highlights
  final Color cardBackColor;        // Fallback card back
  final String bgmPath;             // Path to music file
  final Color fxColor;              // Color for particles/effects
  final Color textColor;

  ThemeModel({
    required this.id,
    required this.name,
    required this.gradientColors,
    required this.tableColor,
    required this.accentColor,
    required this.cardBackColor,
    required this.bgmPath,
    required this.fxColor,
    this.textColor = Colors.white,
  });
}

class AvatarFrameModel {
  final String id;
  final String name;
  final List<Color> gradientColors;
  final Color glowColor;
  final double borderWidth;

  AvatarFrameModel({
    required this.id,
    required this.name,
    required this.gradientColors,
    required this.glowColor,
    this.borderWidth = 3.0,
  });
}

class CardSkinModel {
  final String id;
  final Color backGradientStart;
  final Color backGradientEnd;
  final String? assetPath; 

  CardSkinModel({
    required this.id, 
    required this.backGradientStart, 
    required this.backGradientEnd,
    this.assetPath
  });
}

class TableThemes {
  // --- PREDEFINED THEMES ---
  static final ThemeModel midnightElite = ThemeModel(
    id: 'midnight_elite',
    name: 'Midnight Elite',
    gradientColors: [Color(0xFF1A1F38), Color(0xFF0F111A)],
    tableColor: Color(0xFF232946).withOpacity(0.5),
    accentColor: Color(0xFF00E5FF),
    cardBackColor: Color(0xFF304FFE),
    bgmPath: 'midnight_loops',
    fxColor: Color(0xFF00E5FF).withOpacity(0.3),
  );

  static final ThemeModel greenTable = ThemeModel(
    id: 'green_table',
    name: 'Classic Green',
    gradientColors: [Color(0xFF1B5E20), Color(0xFF003300)],
    tableColor: Color(0xFF2E7D32).withOpacity(0.8),
    accentColor: Colors.amber,
    cardBackColor: Colors.red,
    bgmPath: 'casino_lounge',
    fxColor: Colors.amber.withOpacity(0.2),
  );

  static final ThemeModel oceanBlue = ThemeModel(
    id: 'ocean_blue',
    name: 'Ocean Blue',
    gradientColors: [Color(0xFF0277BD), Color(0xFF002F6C)],
    tableColor: Color(0xFF01579B).withOpacity(0.6),
    accentColor: Colors.lightBlueAccent,
    cardBackColor: Colors.blue,
    bgmPath: 'ocean_waves',
    fxColor: Colors.white.withOpacity(0.2),
  );

  static final ThemeModel sunset = ThemeModel(
    id: 'sunset',
    name: 'Sunset',
    gradientColors: [Color(0xFF6A1B9A), Color(0xFF283593)],
    tableColor: Color(0xFF4527A0).withOpacity(0.5),
    accentColor: Colors.orangeAccent,
    cardBackColor: Colors.deepOrange,
    bgmPath: 'synthwave_drive',
    fxColor: Colors.orangeAccent.withOpacity(0.3),
  );

  static final ThemeModel bloodMoon = ThemeModel(
    id: 'blood_moon',
    name: 'Blood Moon',
    gradientColors: [Color(0xFF3E0000), Color(0xFF1A0000)],
    tableColor: Color(0xFF5C0000).withOpacity(0.7),
    accentColor: Color(0xFFFF3D00),
    cardBackColor: Color(0xFFB71C1C),
    bgmPath: 'midnight_loops',
    fxColor: Color(0xFFFF3D00).withOpacity(0.35),
  );

  static final ThemeModel galaxy = ThemeModel(
    id: 'galaxy',
    name: 'Galaxy',
    gradientColors: [Color(0xFF0D0221), Color(0xFF110133)],
    tableColor: Color(0xFF1A0240).withOpacity(0.7),
    accentColor: Color(0xFFE040FB),
    cardBackColor: Color(0xFF4A148C),
    bgmPath: 'midnight_loops',
    fxColor: Color(0xFFE040FB).withOpacity(0.3),
  );

  static final ThemeModel cyberTokyo = ThemeModel(
    id: 'cyber_tokyo',
    name: 'Cyber Tokyo',
    gradientColors: [Color(0xFF001220), Color(0xFFF706CF).withOpacity(0.1)],
    tableColor: Color(0xFF0F172A).withOpacity(0.8),
    accentColor: Color(0xFF00F2FF),
    cardBackColor: Color(0xFF1E293B),
    bgmPath: 'synthwave_drive',
    fxColor: Color(0xFFF706CF).withOpacity(0.4),
  );

  static final ThemeModel etherealPlane = ThemeModel(
    id: 'ethereal_plane',
    name: 'Ethereal Plane',
    gradientColors: [Color(0xFFFFFFFF), Color(0xFFFFF176)],
    tableColor: Color(0xFFFAFAFA).withOpacity(0.9),
    accentColor: Colors.amber,
    cardBackColor: Colors.white,
    bgmPath: 'ocean_waves',
    fxColor: Colors.amber.withOpacity(0.3),
    textColor: Colors.blueGrey[900]!,
  );

  static ThemeModel get defaultTheme => midnightElite;

  static ThemeModel getTheme(String id) {
    switch (id) {
      case 'green_table': return greenTable;
      case 'ocean_blue': return oceanBlue;
      case 'sunset': return sunset;
      case 'blood_moon': return bloodMoon;
      case 'galaxy': return galaxy;
      case 'cyber_tokyo': return cyberTokyo;
      case 'ethereal_plane': return etherealPlane;
      case 'midnight_elite':
      default: return midnightElite;
    }
  }
}

class AvatarFrames {
  static final AvatarFrameModel defaultFrame = AvatarFrameModel(
    id: 'default',
    name: 'Standard',
    gradientColors: [Colors.white24, Colors.white12],
    glowColor: Colors.transparent,
    borderWidth: 1.0,
  );

  static final AvatarFrameModel neonFlare = AvatarFrameModel(
    id: 'neon_flare',
    name: 'Neon Flare',
    gradientColors: [Color(0xFF00F2FF), Color(0xFFF706CF)],
    glowColor: Color(0xFF00F2FF).withOpacity(0.5),
  );

  static final AvatarFrameModel royalGold = AvatarFrameModel(
    id: 'royal_gold',
    name: 'Royal Gold',
    gradientColors: [Color(0xFFFFD700), Color(0xFFFFA000)],
    glowColor: Color(0xFFFFD700).withOpacity(0.4),
    borderWidth: 4.0,
  );

  static final AvatarFrameModel obsidianVoid = AvatarFrameModel(
    id: 'obsidian_void',
    name: 'Obsidian Void',
    gradientColors: [Color(0xFF000000), Color(0xFF4A148C)],
    glowColor: Color(0xFF4A148C).withOpacity(0.6),
    borderWidth: 5.0,
  );

  static final AvatarFrameModel galaxyPulse = AvatarFrameModel(
    id: 'galaxy_pulse',
    name: 'Galaxy Pulse',
    gradientColors: [Color(0xFF6A1B9A), Color(0xFF00E5FF)],
    glowColor: Color(0xFF00E5FF).withOpacity(0.4),
  );

  static AvatarFrameModel getFrame(String id) {
    switch (id) {
      case 'neon_flare': return neonFlare;
      case 'royal_gold': return royalGold;
      case 'obsidian_void': return obsidianVoid;
      case 'galaxy_pulse': return galaxyPulse;
      default: return defaultFrame;
    }
  }
}

class CardSkins {
  static CardSkinModel getSkin(String id) {
    switch (id) {
      case 'classic':
        return CardSkinModel(id: 'classic', backGradientStart: Colors.blue[800]!, backGradientEnd: Colors.blue[900]!);
      case 'cyberpunk':
        return CardSkinModel(id: 'cyberpunk', backGradientStart: Color(0xFFD500F9), backGradientEnd: Color(0xFF651FFF));
      case 'royal_gold':
        return CardSkinModel(id: 'royal_gold', backGradientStart: Color(0xFFFFD700), backGradientEnd: Color(0xFFFFA000));
      case 'matrix':
        return CardSkinModel(id: 'matrix', backGradientStart: Colors.black, backGradientEnd: Color(0xFF00C853));
      case 'midnight':
        return CardSkinModel(id: 'midnight', backGradientStart: Color(0xFF212121), backGradientEnd: Color(0xFF424242));
      case 'rainbow':
        return CardSkinModel(id: 'rainbow', backGradientStart: Colors.red, backGradientEnd: Colors.blue);
      case 'volcanic':
        return CardSkinModel(id: 'volcanic', backGradientStart: Color(0xFFB71C1C), backGradientEnd: Color(0xFFFF6D00));
      case 'arctic':
        return CardSkinModel(id: 'arctic', backGradientStart: Color(0xFF80DEEA), backGradientEnd: Color(0xFF0D47A1));
      case 'golden_kadi':
        return CardSkinModel(id: 'golden_kadi', backGradientStart: Color(0xFFFFD700), backGradientEnd: Color(0xFFFF6F00));
      case 'obsidian_shard':
        return CardSkinModel(id: 'obsidian_shard', backGradientStart: Color(0xFF000000), backGradientEnd: Color(0xFF4A148C));
      case 'holographic_chrome':
        return CardSkinModel(id: 'holographic_chrome', backGradientStart: Color(0xFFE0E0E0), backGradientEnd: Color(0xFF00E5FF));
      case 'inferno':
        return CardSkinModel(id: 'inferno', backGradientStart: Color(0xFF3E0000), backGradientEnd: Color(0xFFFF3D00));
      case 'nebula_swirl':
        return CardSkinModel(id: 'nebula_swirl', backGradientStart: Color(0xFF000428), backGradientEnd: Color(0xFF004E92));
      case 'neon_geometric':
      default:
        return CardSkinModel(id: 'neon_geometric', backGradientStart: Color(0xFF2E3192), backGradientEnd: Color(0xFF1BFFFF));
    }
  }
}