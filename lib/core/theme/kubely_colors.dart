import 'package:flutter/material.dart';

class KubelyColors {
  KubelyColors._();

  // ── Backgrounds ──
  static const ink = Color(0xFF0A0B0F);
  static const inkDeep = Color(0xFF06070A);
  static const surface = Color(0xFF14161D);
  static const surfaceAlt = Color(0xFF1B1E27);
  static const surfaceStrip = Color(0xFF101218);

  // ── Text ──
  static const textPrimary = Color(0xFFECEFF4);
  static const textSecondary = Color(0xFFC7CCD8);
  static const textMuted = Color(0xFF9AA1B0);
  static const textDim = Color(0xFF5C6373);
  static const textFaint = Color(0xFF3A4150);

  // ── Accent ──
  static const accent = Color(0xFF2EE6C5);
  static const accentOnLight = Color(0xFF0BB6A0);

  // ── Status ──
  static const running = Color(0xFF3DDC84);
  static const warning = Color(0xFFFFB020);
  static const critical = Color(0xFFFF5C5C);
  static const info = Color(0xFF4DA3FF);

  // ── Status text variants (lighter tints for sub-labels) ──
  static const criticalText = Color(0xFFFF7878);
  static const warningText = Color(0xFFFFC861);

  // ── Provider badges ──
  static const providerEks = Color(0xFFFF9D4D);
  static const providerGke = Color(0xFF4DA3FF);

  // ── Syntax highlighting ──
  static const yamlKey = Color(0xFF8B7BFF);

  // ── Borders & hairlines ──
  static final hairline = Colors.white.withValues(alpha: 0.07);
  static final hairlineLight = Colors.white.withValues(alpha: 0.05);
  static final hairlineStrong = Colors.white.withValues(alpha: 0.08);
  static final hairlineInput = Colors.white.withValues(alpha: 0.10);

  // ── Status-tinted borders ──
  static final criticalBorder = critical.withValues(alpha: 0.22);
  static final warningBorder = warning.withValues(alpha: 0.20);
  static final runningBorder = running.withValues(alpha: 0.18);
  static final infoBorder = info.withValues(alpha: 0.20);

  // ── Status-tinted row backgrounds ──
  static final criticalRowBg = critical.withValues(alpha: 0.05);
  static final warningRowBg = warning.withValues(alpha: 0.05);

  // ── Tab bar ──
  static final tabBarBg = ink.withValues(alpha: 0.85);

  // ── Sheet ──
  static const sheetBackground = Color(0xFF16181F);

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'running':
      case 'healthy':
      case 'active':
      case 'bound':
      case 'deployed':
      case 'ready':
        return running;
      case 'pending':
      case 'warning':
      case 'degraded':
      case 'cordoned':
        return warning;
      case 'crashloopbackoff':
      case 'error':
      case 'failed':
      case 'critical':
      case 'imagepullbackoff':
      case 'superseded':
        return critical;
      case 'completed':
      case 'succeeded':
      case 'info':
        return info;
      default:
        return textDim;
    }
  }

  static Color statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'crashloopbackoff':
      case 'error':
      case 'failed':
      case 'critical':
      case 'imagepullbackoff':
        return criticalText;
      case 'pending':
      case 'warning':
      case 'degraded':
        return warningText;
      default:
        return statusColor(status);
    }
  }

  static Color statusBorderColor(String status) {
    switch (status.toLowerCase()) {
      case 'crashloopbackoff':
      case 'error':
      case 'failed':
      case 'critical':
        return criticalBorder;
      case 'pending':
      case 'warning':
      case 'degraded':
        return warningBorder;
      default:
        return hairline;
    }
  }
}
