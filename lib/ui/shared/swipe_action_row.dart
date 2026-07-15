import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';
import '../../core/utils/haptics.dart';

class SwipeActionRow extends StatefulWidget {
  const SwipeActionRow({
    super.key,
    required this.child,
    this.onRestart,
    this.onDelete,
  });

  final Widget child;
  final VoidCallback? onRestart;
  final VoidCallback? onDelete;

  @override
  State<SwipeActionRow> createState() => _SwipeActionRowState();
}

class _SwipeActionRowState extends State<SwipeActionRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  bool _isOpen = false;

  static const _actionWidth = 120.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-_actionWidth, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(SwipeActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      _controller.value = 0;
      _isOpen = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_isOpen) {
      _controller.reverse();
    } else {
      KubelyHaptics.light();
      _controller.forward();
    }
    _isOpen = !_isOpen;
  }

  void _close() {
    if (_isOpen) {
      _controller.reverse();
      _isOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx < -4 && !_isOpen) _toggle();
        if (details.delta.dx > 4 && _isOpen) _toggle();
      },
      onTap: _isOpen ? _close : null,
      child: Stack(
        children: [
          // Action buttons (behind)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _actionWidth,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _close();
                      widget.onRestart?.call();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: KubelyColors.info,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.refreshCw,
                              size: 18, color: Colors.white),
                          const SizedBox(height: 4),
                          Text('Restart',
                              style: KubelyTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _close();
                      widget.onDelete?.call();
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: KubelyColors.critical,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.trash2,
                              size: 18, color: Colors.white),
                          const SizedBox(height: 4),
                          Text('Delete',
                              style: KubelyTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Foreground content (slides left)
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: _slideAnimation.value,
                child: child,
              );
            },
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
