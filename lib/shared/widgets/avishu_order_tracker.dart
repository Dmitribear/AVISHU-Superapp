import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/colors.dart';
import '../../features/orders/domain/enums/order_status.dart';

/// A data class describing a single step in the client-facing order tracker.
class _TrackerStep {
  final String title;
  final String? subtitle;

  const _TrackerStep({required this.title, this.subtitle});
}

/// Brutalist-minimalist vertical order tracker for the B2C client flow.
///
/// Renders three steps — ОФОРМЛЕН → ПОШИВ → ГОТОВ — connected by thin 1px
/// vertical lines. The active step indicator pulses (opacity 1.0 → 0.4).
/// When status is [OrderStatus.inProduction], a sub-text is shown.
///
/// Reactivity: wrap in a Riverpod `Consumer` / `ConsumerWidget` and pass
/// the watched [OrderStatus]. To trigger haptic feedback on status changes,
/// use the static [triggerHapticIfChanged] helper inside a `ref.listen`.
class AvishuOrderTracker extends StatelessWidget {
  const AvishuOrderTracker({super.key, required this.status});

  final OrderStatus status;

  /// The three client-visible steps, derived from [OrderStatus.clientStage].
  ///   stage 0 → ОФОРМЛЕН
  ///   stage 1 → ПОШИВ  (+ sub-text when active)
  ///   stage 2 → ГОТОВ
  static List<_TrackerStep> _steps(OrderStatus status) => [
    const _TrackerStep(title: 'ОФОРМЛЕН'),
    _TrackerStep(
      title: 'ПОШИВ',
      subtitle: status == OrderStatus.inProduction
          ? 'МАСТЕР ПРИСТУПИЛ К РАБОТЕ'
          : null,
    ),
    const _TrackerStep(title: 'ГОТОВ'),
  ];

  /// Call inside `ref.listen<OrderStatus>` to fire a light haptic tap whenever
  /// the order status visibly changes for the client.
  static void triggerHapticIfChanged(
    OrderStatus? previous,
    OrderStatus next,
  ) {
    if (previous != null && previous.clientStage != next.clientStage) {
      HapticFeedback.lightImpact();
    }
  }

  // ─── typography ──────────────────────────────────────────────────────

  static final TextStyle _titleStyle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.5,
    height: 1.2,
    color: AppColors.black,
  );

  static final TextStyle _titleDimStyle = _titleStyle.copyWith(
    color: AppColors.outlineVariant,
  );

  static final TextStyle _subtitleStyle = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.6,
    height: 1.4,
    color: AppColors.secondary,
  );

  // ─── geometry ────────────────────────────────────────────────────────

  static const double _indicatorSize = 10.0;
  static const double _lineWidth = 1.0;
  static const double _stepSpacing = 32.0;

  @override
  Widget build(BuildContext context) {
    final steps = _steps(status);
    final currentIndex = status.clientStage;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _buildStep(steps[i], i, currentIndex),
            if (i < steps.length - 1)
              _buildConnector(i, currentIndex),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(_TrackerStep step, int index, int currentIndex) {
    final bool isCompleted = index < currentIndex;
    final bool isActive = index == currentIndex;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── indicator column ──
        SizedBox(
          width: _indicatorSize,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: isActive
                ? _PulseIndicator(size: _indicatorSize)
                : _StaticIndicator(
                    size: _indicatorSize,
                    filled: isCompleted,
                  ),
          ),
        ),
        const SizedBox(width: 16),
        // ── text column ──
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: (isCompleted || isActive)
                    ? _titleStyle
                    : _titleDimStyle,
              ),
              if (isActive && step.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(step.subtitle!, style: _subtitleStyle),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(int index, int currentIndex) {
    final bool passed = index < currentIndex;

    return Padding(
      padding: EdgeInsets.only(
        left: (_indicatorSize - _lineWidth) / 2,
        top: 6,
        bottom: 6,
      ),
      child: Container(
        width: _lineWidth,
        height: _stepSpacing,
        color: passed ? AppColors.black : AppColors.outlineVariant,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Indicators
// ═══════════════════════════════════════════════════════════════════════════

/// A hollow or filled circle for completed / future steps (no animation).
class _StaticIndicator extends StatelessWidget {
  const _StaticIndicator({required this.size, required this.filled});

  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.black : AppColors.white,
        border: Border.all(color: AppColors.black, width: 1),
      ),
    );
  }
}

/// A filled circle that pulses opacity between 1.0 and 0.4.
class _PulseIndicator extends StatefulWidget {
  const _PulseIndicator({required this.size});

  final double size;

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: child,
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.black,
          border: Border.all(color: AppColors.black, width: 1),
        ),
      ),
    );
  }
}
