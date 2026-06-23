import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../shared/kubely_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: KubelyColors.ink,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glow behind mark
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    KubelyColors.accent.withValues(alpha: 0.10),
                    KubelyColors.accent.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: const Center(
                child: KubelyLogo(size: 92, showHex: true),
              ),
            )
                .animate(
                    autoPlay: !reduceMotion,
                    value: reduceMotion ? 1.0 : 0.0,
                )
                .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: 800.ms,
                    curve: Curves.easeOut),
            const SizedBox(height: 24),
            Text('Kubely',
                    style: KubelyTypography.screenTitle.copyWith(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ))
                .animate(
                    delay: 300.ms,
                    autoPlay: !reduceMotion,
                    value: reduceMotion ? 1.0 : 0.0,
                )
                .fadeIn(duration: 600.ms),
            const SizedBox(height: 8),
            Text('KUBERNETES · ON DEVICE',
                    style: KubelyTypography.monoSmall.copyWith(
                      letterSpacing: 2.0,
                      color: KubelyColors.textDim,
                    ))
                .animate(
                    delay: 500.ms,
                    autoPlay: !reduceMotion,
                    value: reduceMotion ? 1.0 : 0.0,
                )
                .fadeIn(duration: 600.ms),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 32,
        ),
        child: Text(
          '100% on device',
          textAlign: TextAlign.center,
          style: KubelyTypography.caption.copyWith(
            color: KubelyColors.textDim,
            fontSize: 11,
          ),
        ).animate(
            delay: 700.ms,
            autoPlay: !reduceMotion,
            value: reduceMotion ? 1.0 : 0.0,
        ).fadeIn(duration: 600.ms),
      ),
    );
  }
}
