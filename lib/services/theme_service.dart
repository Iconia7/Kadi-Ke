import 'package:flutter/material.dart';

class ThemeModel {
  final String id;
  final String name;
  final List<Color> gradientColors; // Background gradient
  final Color tableColor;           // Felt color
  final Color accentColor;          // Buttons/Highlights
  final Color cardBackColor;        // Fallback card back
  final Color textColor;

  ThemeModel({
    required this.id,
    required this.name,
    required this.gradientColors,
    required this.tableColor,
    required this.accentColor,
    required this.cardBackColor,
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
  );

  static final ThemeModel greenTable = ThemeModel(
    id: 'green_table',
    name: 'Classic Green',
    gradientColors: [Color(0xFF1B5E20), Color(0xFF003300)],
    tableColor: Color(0xFF2E7D32).withOpacity(0.8),
    accentColor: Colors.amber,
    cardBackColor: Colors.red,
  );

  static final ThemeModel oceanBlue = ThemeModel(
    id: 'ocean_blue',
    name: 'Ocean Blue',
    gradientColors: [Color(0xFF0277BD), Color(0xFF002F6C)],
    tableColor: Color(0xFF01579B).withOpacity(0.6),
    accentColor: Colors.lightBlueAccent,
    cardBackColor: Colors.blue,
  );

  static final ThemeModel sunset = ThemeModel(
    id: 'sunset',
    name: 'Sunset',
    gradientColors: [Color(0xFF6A1B9A), Color(0xFF283593)],
    tableColor: Color(0xFF4527A0).withOpacity(0.5),
    accentColor: Colors.orangeAccent,
    cardBackColor: Colors.deepOrange,
  );

  // Added missing getter
  static ThemeModel get defaultTheme => midnightElite;

  static ThemeModel getTheme(String id) {
    switch (id) {
      case 'green_table': return greenTable;
      case 'ocean_blue': return oceanBlue;
      case 'sunset': return sunset;
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
      case 'neon_geometric':
      default:
        return CardSkinModel(id: 'neon_geometric', backGradientStart: Color(0xFF2E3192), backGradientEnd: Color(0xFF1BFFFF));
    }
  }
}