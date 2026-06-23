import 'package:flutter/material.dart';
import 'kubely_colors.dart';

class KubelyShadows {
  KubelyShadows._();

  static List<BoxShadow> statusGlow(Color color) => [
        BoxShadow(
          color: color,
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ];

  static const accentButtonGlow = [
    BoxShadow(
      color: Color(0x4D2EE6C5), // rgba(46,230,197,.3)
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  static const heroInnerGlow = [
    BoxShadow(
      color: Color(0x0F3DDC84), // rgba(61,220,132,.06)
      blurRadius: 36,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> statusDotGlow(Color color) => [
        BoxShadow(
          color: color,
          blurRadius: 7,
          spreadRadius: 0,
        ),
      ];
}

class KubelyGradients {
  KubelyGradients._();

  static const heroCard = LinearGradient(
    begin: Alignment(-0.6, -0.8),
    end: Alignment(0.6, 0.8),
    colors: [Color(0xFF161B22), Color(0xFF12141B)],
  );

  static const cpuBar = LinearGradient(
    colors: [KubelyColors.accent, KubelyColors.info],
  );

  static const memoryBar = LinearGradient(
    colors: [KubelyColors.warning, Color(0xFFFF8A4C)],
  );

  static const appIconBg = RadialGradient(
    center: Alignment(0, -0.84),
    radius: 1.2,
    colors: [Color(0xFF161B22), KubelyColors.ink],
    stops: [0.0, 0.6],
  );
}
