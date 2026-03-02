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

  static ThemeModel get defaultTheme => midnightElite;

  static ThemeModel getTheme(String id) {
    switch (id) {
      case 'green_table': return greenTable;
      case 'ocean_blue': return oceanBlue;
      case 'sunset': return sunset;
      case 'blood_moon': return bloodMoon;
      case 'galaxy': return galaxy;
      case 'midnight_elite':
      default: return midnightElite;
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
      case 'neon_geometric':
      default:
        return CardSkinModel(id: 'neon_geometric', backGradientStart: Color(0xFF2E3192), backGradientEnd: Color(0xFF1BFFFF));
    }
  }
}