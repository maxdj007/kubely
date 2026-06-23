import 'package:flutter/material.dart';

class KubelyRadii {
  KubelyRadii._();

  static final r8 = BorderRadius.circular(8);
  static final r11 = BorderRadius.circular(11);
  static final r12 = BorderRadius.circular(12);
  static final r13 = BorderRadius.circular(13);
  static final r14 = BorderRadius.circular(14);
  static final r16 = BorderRadius.circular(16);
  static final r18 = BorderRadius.circular(18);
  static final r20 = BorderRadius.circular(20);
  static final r24 = BorderRadius.circular(24);
  static final r26 = BorderRadius.circular(26);

  // Segmented control
  static final segmentedTrack = BorderRadius.circular(11);
  static final segmentedPill = BorderRadius.circular(8);

  // Chip/input
  static final chip = BorderRadius.circular(8);
  static final input = BorderRadius.circular(14);

  // Hero card
  static final heroCard = BorderRadius.circular(20);
  static final standardCard = BorderRadius.circular(16);

  // Bottom sheet
  static const sheet = BorderRadius.only(
    topLeft: Radius.circular(26),
    topRight: Radius.circular(26),
  );
}
