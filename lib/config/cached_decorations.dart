import 'package:flutter/material.dart';

/// Pre-computed decorations to reduce GPU rasterization overhead.
/// Using const decorations prevents recreation on every build.
class CachedDecorations {
  // Private constructor to prevent instantiation
  CachedDecorations._();

  // ============ Card Decorations ============

  /// Standard product card decoration with shadow
  static const BoxDecoration productCard = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.all(Radius.circular(12)),
    boxShadow: [
      BoxShadow(
        color: Color(0x1A000000), // 10% opacity black
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ],
  );

  /// Elevated card decoration with stronger shadow
  static const BoxDecoration elevatedCard = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.all(Radius.circular(12)),
    boxShadow: [
      BoxShadow(
        color: Color(0x26000000), // 15% opacity black
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
  );

  /// Category card with gradient background
  static const BoxDecoration categoryCard = BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF6B63FF), Color(0xFF8E85FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );

  // ============ Border Radii (Reusable) ============

  static const BorderRadius radius4 = BorderRadius.all(Radius.circular(4));
  static const BorderRadius radius8 = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radius12 = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radius16 = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radius20 = BorderRadius.all(Radius.circular(20));

  // ============ Box Shadows (Reusable) ============

  /// Subtle shadow for cards
  static const List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Color(0x0D000000), // 5% opacity
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Standard card shadow
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x1A000000), // 10% opacity
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Strong shadow for floating elements
  static const List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Color(0x26000000), // 15% opacity
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  // ============ Common Borders ============

  /// Light border for dividers
  static const Border lightBorder = Border(
    bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
  );

  /// All-around light border
  static const BoxDecoration borderedBox = BoxDecoration(
    color: Colors.white,
    border: Border.fromBorderSide(
      BorderSide(color: Color(0xFFE0E0E0), width: 1),
    ),
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

  // ============ Gradient Decorations ============

  /// Primary gradient (blue to purple)
  static const BoxDecoration primaryGradient = BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF6B63FF), Color(0xFF8E85FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// Secondary gradient (teal to blue)
  static const BoxDecoration secondaryGradient = BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF00BCD4), Color(0xFF2196F3)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );
}

