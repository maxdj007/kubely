import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'kubely_colors.dart';

class KubelyTheme {
  KubelyTheme._();

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: KubelyColors.ink,
        fontFamily: 'SpaceGrotesk',
        colorScheme: ColorScheme.dark(
          surface: KubelyColors.surface,
          primary: KubelyColors.accent,
          secondary: KubelyColors.accent,
          error: KubelyColors.critical,
          onPrimary: KubelyColors.ink,
          onSurface: KubelyColors.textPrimary,
          onError: KubelyColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: KubelyColors.textPrimary,
          ),
          iconTheme: IconThemeData(color: KubelyColors.textSecondary),
        ),
        dividerColor: KubelyColors.hairline,
        splashColor: KubelyColors.accent.withValues(alpha: 0.08),
        highlightColor: KubelyColors.accent.withValues(alpha: 0.04),
      );
}
