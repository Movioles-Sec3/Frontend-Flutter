import 'package:flutter/material.dart';
import 'strategy.dart';

/// UI theme data model
class UIThemeData {
  UIThemeData({
    required this.name,
    required this.colors,
    required this.typography,
    required this.spacing,
    required this.borderRadius,
  });

  final String name;
  final UIColors colors;
  final UITypography typography;
  final UISpacing spacing;
  final UIBorderRadius borderRadius;
}

/// UI colors configuration
class UIColors {
  UIColors({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.error,
    required this.onPrimary,
    required this.onSecondary,
    required this.onBackground,
    required this.onSurface,
    required this.onError,
  });

  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color error;
  final Color onPrimary;
  final Color onSecondary;
  final Color onBackground;
  final Color onSurface;
  final Color onError;
}

/// UI typography configuration
class UITypography {
  UITypography({
    required this.headline1,
    required this.headline2,
    required this.headline3,
    required this.body1,
    required this.body2,
    required this.caption,
    required this.button,
  });

  final TextStyle headline1;
  final TextStyle headline2;
  final TextStyle headline3;
  final TextStyle body1;
  final TextStyle body2;
  final TextStyle caption;
  final TextStyle button;
}

/// UI spacing configuration
class UISpacing {
  UISpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
}

/// UI border radius configuration
class UIBorderRadius {
  UIBorderRadius({
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  final double sm;
  final double md;
  final double lg;
  final double xl;
}

/// UI rendering result
class UIRenderingResult {
  UIRenderingResult({
    required this.success,
    this.widget,
    this.error,
  });

  final bool success;
  final Widget? widget;
  final String? error;

  factory UIRenderingResult.success(Widget widget) => 
      UIRenderingResult(success: true, widget: widget);
  factory UIRenderingResult.failure(String error) => 
      UIRenderingResult(success: false, error: error);
}

/// Base UI strategy interface
abstract class UIStrategy extends Strategy<UIThemeData, UIRenderingResult> {
  @override
  String get identifier;

  @override
  bool canHandle(UIThemeData input) => true;

  /// Create a themed widget
  Widget createThemedWidget(UIThemeData theme, Widget child);

  /// Apply theme to existing widget
  Widget applyTheme(UIThemeData theme, Widget widget);
}

/// Material Design UI strategy
class MaterialUIStrategy extends UIStrategy {
  @override
  String get identifier => 'material';

  @override
  Future<UIRenderingResult> execute(UIThemeData input) async {
    try {
      final theme = _createMaterialTheme(input);
      final widget = Theme(
        data: theme,
        child: Container(), // Placeholder widget
      );
      return UIRenderingResult.success(widget);
    } catch (e) {
      return UIRenderingResult.failure('Failed to create Material theme: $e');
    }
  }

  @override
  Widget createThemedWidget(UIThemeData theme, Widget child) {
    final materialTheme = _createMaterialTheme(theme);
    return Theme(data: materialTheme, child: child);
  }

  @override
  Widget applyTheme(UIThemeData theme, Widget widget) {
    final materialTheme = _createMaterialTheme(theme);
    return Theme(data: materialTheme, child: widget);
  }

  ThemeData _createMaterialTheme(UIThemeData uiTheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: uiTheme.colors.primary,
        onPrimary: uiTheme.colors.onPrimary,
        secondary: uiTheme.colors.secondary,
        onSecondary: uiTheme.colors.onSecondary,
        error: uiTheme.colors.error,
        onError: uiTheme.colors.onError,
        background: uiTheme.colors.background,
        onBackground: uiTheme.colors.onBackground,
        surface: uiTheme.colors.surface,
        onSurface: uiTheme.colors.onSurface,
      ),
      textTheme: TextTheme(
        headlineLarge: uiTheme.typography.headline1,
        headlineMedium: uiTheme.typography.headline2,
        headlineSmall: uiTheme.typography.headline3,
        bodyLarge: uiTheme.typography.body1,
        bodyMedium: uiTheme.typography.body2,
        bodySmall: uiTheme.typography.caption,
        labelLarge: uiTheme.typography.button,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: uiTheme.colors.surface,
        foregroundColor: uiTheme.colors.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(uiTheme.borderRadius.md),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: uiTheme.colors.primary,
          foregroundColor: uiTheme.colors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(uiTheme.borderRadius.md),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: uiTheme.spacing.lg,
            vertical: uiTheme.spacing.md,
          ),
        ),
      ),
    );
  }
}

/// Cupertino UI strategy
class CupertinoUIStrategy extends UIStrategy {
  @override
  String get identifier => 'cupertino';

  @override
  Future<UIRenderingResult> execute(UIThemeData input) async {
    try {
      final theme = _createCupertinoTheme(input);
      final widget = Theme(
        data: theme,
        child: Container(), // Placeholder widget
      );
      return UIRenderingResult.success(widget);
    } catch (e) {
      return UIRenderingResult.failure('Failed to create Cupertino theme: $e');
    }
  }

  @override
  Widget createThemedWidget(UIThemeData theme, Widget child) {
    final cupertinoTheme = _createCupertinoTheme(theme);
    return Theme(data: cupertinoTheme, child: child);
  }

  @override
  Widget applyTheme(UIThemeData theme, Widget widget) {
    final cupertinoTheme = _createCupertinoTheme(theme);
    return Theme(data: cupertinoTheme, child: widget);
  }

  ThemeData _createCupertinoTheme(UIThemeData uiTheme) {
    return ThemeData(
      useMaterial3: false,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: uiTheme.colors.primary,
        onPrimary: uiTheme.colors.onPrimary,
        secondary: uiTheme.colors.secondary,
        onSecondary: uiTheme.colors.onSecondary,
        error: uiTheme.colors.error,
        onError: uiTheme.colors.onError,
        background: uiTheme.colors.background,
        onBackground: uiTheme.colors.onBackground,
        surface: uiTheme.colors.surface,
        onSurface: uiTheme.colors.onSurface,
      ),
      textTheme: TextTheme(
        headlineLarge: uiTheme.typography.headline1,
        headlineMedium: uiTheme.typography.headline2,
        headlineSmall: uiTheme.typography.headline3,
        bodyLarge: uiTheme.typography.body1,
        bodyMedium: uiTheme.typography.body2,
        bodySmall: uiTheme.typography.caption,
        labelLarge: uiTheme.typography.button,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: uiTheme.colors.surface,
        foregroundColor: uiTheme.colors.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(uiTheme.borderRadius.sm),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: uiTheme.colors.primary,
          foregroundColor: uiTheme.colors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(uiTheme.borderRadius.sm),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: uiTheme.spacing.lg,
            vertical: uiTheme.spacing.md,
          ),
        ),
      ),
    );
  }
}

/// Custom UI strategy
class CustomUIStrategy extends UIStrategy {
  CustomUIStrategy({
    required this.customThemeBuilder,
  });

  @override
  String get identifier => 'custom';

  final ThemeData Function(UIThemeData) customThemeBuilder;

  @override
  Future<UIRenderingResult> execute(UIThemeData input) async {
    try {
      final theme = customThemeBuilder(input);
      final widget = Theme(
        data: theme,
        child: Container(), // Placeholder widget
      );
      return UIRenderingResult.success(widget);
    } catch (e) {
      return UIRenderingResult.failure('Failed to create custom theme: $e');
    }
  }

  @override
  Widget createThemedWidget(UIThemeData theme, Widget child) {
    final customTheme = customThemeBuilder(theme);
    return Theme(data: customTheme, child: child);
  }

  @override
  Widget applyTheme(UIThemeData theme, Widget widget) {
    final customTheme = customThemeBuilder(theme);
    return Theme(data: customTheme, child: widget);
  }
}

/// UI context for managing UI strategies
class UIContext {
  UIContext({
    required this.defaultStrategy,
    this.strategies = const [],
  });

  final UIStrategy defaultStrategy;
  final List<UIStrategy> strategies;

  /// Apply theme using the appropriate strategy
  Widget applyTheme(UIThemeData theme, Widget widget, {String? strategyId}) {
    final strategy = strategyId != null 
        ? _getStrategyById(strategyId)
        : _selectStrategy(theme);
    return strategy.applyTheme(theme, widget);
  }

  /// Create themed widget using the appropriate strategy
  Widget createThemedWidget(UIThemeData theme, Widget child, {String? strategyId}) {
    final strategy = strategyId != null 
        ? _getStrategyById(strategyId)
        : _selectStrategy(theme);
    return strategy.createThemedWidget(theme, child);
  }

  /// Select UI strategy based on theme
  UIStrategy _selectStrategy(UIThemeData theme) {
    for (final strategy in strategies) {
      if (strategy.canHandle(theme)) {
        return strategy;
      }
    }
    return defaultStrategy;
  }

  /// Get strategy by identifier
  UIStrategy _getStrategyById(String id) {
    return strategies.firstWhere(
      (s) => s.identifier == id,
      orElse: () => defaultStrategy,
    );
  }

  /// Add a UI strategy
  void addStrategy(UIStrategy strategy) {
    strategies.add(strategy);
  }

  /// Get available UI strategies
  List<String> getAvailableStrategies() {
    return strategies.map((s) => s.identifier).toList();
  }
}
