import 'package:flutter/material.dart';
import 'kubely_colors.dart';

class KubelyTypography {
  KubelyTypography._();

  static const _uiFamily = 'SpaceGrotesk';
  static const _monoFamily = 'JetBrainsMono';

  // ── UI font (Space Grotesk) — all chrome ──

  static const screenTitle = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: KubelyColors.textPrimary,
  );

  static const appBarTitle = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: KubelyColors.textPrimary,
  );

  static const sectionLabel = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: KubelyColors.textPrimary,
  );

  static const body = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: KubelyColors.textSecondary,
  );

  static const bodyMuted = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: KubelyColors.textMuted,
  );

  static const caption = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: KubelyColors.textDim,
  );

  static const tabLabel = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w400,
    color: KubelyColors.textDim,
  );

  static const tabLabelActive = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: KubelyColors.accent,
  );

  static const eyebrow = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.32, // ~0.12em
    color: KubelyColors.textDim,
  );

  static const buttonText = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: KubelyColors.ink,
  );

  static const smallLabel = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    color: KubelyColors.textDim,
  );

  static const badgeText = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: KubelyColors.running,
  );

  // ── Machine font (JetBrains Mono) — all data ──

  static const monoHeroMetric = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: KubelyColors.textPrimary,
  );

  static const monoHeroLarge = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 46,
    fontWeight: FontWeight.w600,
    color: KubelyColors.textPrimary,
  );

  static const monoMetricLg = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    color: KubelyColors.textPrimary,
  );

  static const monoMetric = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: KubelyColors.textPrimary,
  );

  static const monoMetricSm = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: KubelyColors.textPrimary,
  );

  static const monoBody = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: KubelyColors.textPrimary,
  );

  static const monoBodySm = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: KubelyColors.textPrimary,
  );

  static const monoCaption = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: KubelyColors.textDim,
  );

  static const monoCaptionSm = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w400,
    color: KubelyColors.textDim,
  );

  static const monoTerminal = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    color: KubelyColors.textPrimary,
    height: 1.5,
  );

  static const monoSmall = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 9.5,
    fontWeight: FontWeight.w400,
    color: KubelyColors.textDim,
  );

  static const monoCount = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: KubelyColors.textDim,
  );

  static const monoRingPercent = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: KubelyColors.textPrimary,
  );
}
