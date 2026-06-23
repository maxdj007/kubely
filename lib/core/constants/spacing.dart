import 'package:flutter/material.dart';

class KubelySpacing {
  KubelySpacing._();

  static const double screenPadding = 18;
  static const screenH = EdgeInsets.symmetric(horizontal: screenPadding);
  static const screenAll = EdgeInsets.all(screenPadding);

  static const double cardPadding = 14;
  static const double heroPadding = 18;

  static const double cardGap = 14;
  static const double sectionGap = 14;
  static const double rowGapSm = 9;
  static const double rowGapMd = 11;
  static const double rowGapLg = 14;

  static const double rowPaddingV = 12;
  static const double rowPaddingH = 14;
  static const rowPadding = EdgeInsets.symmetric(
    vertical: rowPaddingV,
    horizontal: rowPaddingH,
  );

  static const double tabBarHeight = 78;
  static const double appBarHeight = 52;
}
