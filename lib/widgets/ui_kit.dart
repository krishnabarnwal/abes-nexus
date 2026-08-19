import 'dart:ui';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ABES Nexus — Shared UI Kit
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Glass Card ──────────────────────────────────────────────────────────────
/// A Glassmorphism card: blurred, semi-transparent, with a hairline white border.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;
  final List<BoxShadow>? boxShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
    this.color,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? const Color(0xFF1E293B).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.0,
              ),
              boxShadow: boxShadow ??
                  [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─── Squish Card ─────────────────────────────────────────────────────────────
/// Wraps any child in a spring-physics tap-down scale effect.
class SquishCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const SquishCard({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.95,
  });

  @override
  State<SquishCard> createState() => _SquishCardState();
}

class _SquishCardState extends State<SquishCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ─── Staggered Item ──────────────────────────────────────────────────────────
/// Fades and slides up with a configurable delay for staggered list entrances.
class StaggeredItem extends StatefulWidget {
  final Widget child;
  final int index;
  final int delayMs;

  const StaggeredItem({
    super.key,
    required this.child,
    required this.index,
    this.delayMs = 60,
  });

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── Premium Toast ───────────────────────────────────────────────────────────
/// Shows a floating pill-shaped top-drop notification.
void showToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.success,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _ToastWidget(
      message: message,
      type: type,
      onDismiss: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}

enum ToastType { success, error, info, cyan }

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _opacity;

  Color get _accent {
    switch (widget.type) {
      case ToastType.success: return const Color(0xFF39FF14);
      case ToastType.error:   return const Color(0xFFFF3333);
      case ToastType.cyan:    return const Color(0xFF00F0FF);
      case ToastType.info:    return Colors.blueAccent;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case ToastType.success: return Icons.check_circle_outline;
      case ToastType.error:   return Icons.error_outline;
      case ToastType.cyan:    return Icons.wifi_tethering;
      case ToastType.info:    return Icons.info_outline;
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Positioned(
      top: mq.padding.top + 12,
      left: 24,
      right: 24,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: _accent.withValues(alpha: 0.7), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: _accent.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 1),
                      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(_icon, color: _accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
