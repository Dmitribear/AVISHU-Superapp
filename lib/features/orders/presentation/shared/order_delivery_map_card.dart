import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class OrderDeliveryMapCard extends StatelessWidget {
  final String eyebrow;
  final String badge;
  final String statusLabel;
  final String statusValue;
  final String etaLabel;
  final String etaValue;
  final String locationLabel;
  final String locationValue;
  final String amountLabel;
  final String amountValue;
  final String note;
  final String footer;
  final String modeTag;
  final String cityTag;
  final String originLabel;
  final String destinationLabel;
  final double progress;
  final bool live;
  final bool pickup;
  final bool completed;

  const OrderDeliveryMapCard({
    super.key,
    required this.eyebrow,
    required this.badge,
    required this.statusLabel,
    required this.statusValue,
    required this.etaLabel,
    required this.etaValue,
    required this.locationLabel,
    required this.locationValue,
    required this.amountLabel,
    required this.amountValue,
    required this.note,
    required this.footer,
    required this.modeTag,
    required this.cityTag,
    required this.originLabel,
    required this.destinationLabel,
    required this.progress,
    required this.live,
    required this.pickup,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(eyebrow, style: AppTypography.eyebrow)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: live ? AppColors.black : AppColors.surfaceHigh,
                  border: Border.all(
                    color: live ? AppColors.black : AppColors.outlineVariant,
                  ),
                ),
                child: Text(
                  badge,
                  style: AppTypography.eyebrow.copyWith(
                    color: live ? AppColors.white : AppColors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1.08,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final courierOffset = _routeOffset(size, clampedProgress);
                final startOffset = _routeOffset(size, 0);
                final destinationOffset = _routeOffset(size, 1);

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    border: Border.all(color: AppColors.black),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _OrderDeliveryMapPainter(
                            progress: clampedProgress,
                            muted: !live && !completed,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _MapTag(label: modeTag, filled: true),
                      ),
                      Positioned(
                        top: 46,
                        left: 12,
                        child: _MapTag(label: cityTag),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: _MapTag(label: originLabel),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _MapTag(label: destinationLabel),
                      ),
                      Positioned(
                        left: startOffset.dx - 8,
                        top: startOffset.dy - 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppColors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        left: destinationOffset.dx - 14,
                        top: destinationOffset.dy - 28,
                        child: Icon(
                          pickup ? Icons.storefront : Icons.location_on,
                          size: 30,
                          color: AppColors.black,
                        ),
                      ),
                      if (!pickup || completed)
                        Positioned(
                          left: courierOffset.dx - 15,
                          top: courierOffset.dy - 15,
                          child: _CourierPulse(
                            muted: !live && !completed,
                            completed: completed,
                          ),
                        ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Text(
                          footer,
                          style: AppTypography.code.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _MapMetricRow(label: statusLabel, value: statusValue),
          const SizedBox(height: 10),
          _MapMetricRow(label: etaLabel, value: etaValue),
          const SizedBox(height: 10),
          _MapMetricRow(label: locationLabel, value: locationValue),
          const SizedBox(height: 10),
          _MapMetricRow(label: amountLabel, value: amountValue),
          const SizedBox(height: 12),
          Text(
            note,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _MapMetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MapMetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: AppTypography.eyebrow)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _MapTag extends StatelessWidget {
  final String label;
  final bool filled;

  const _MapTag({required this.label, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? AppColors.black : AppColors.surfaceLowest,
        border: Border.all(color: AppColors.black),
      ),
      child: Text(
        label,
        style: AppTypography.eyebrow.copyWith(
          color: filled ? AppColors.white : AppColors.black,
        ),
      ),
    );
  }
}

class _CourierPulse extends StatelessWidget {
  final bool muted;
  final bool completed;

  const _CourierPulse({required this.muted, required this.completed});

  @override
  Widget build(BuildContext context) {
    final coreColor = completed ? AppColors.black : AppColors.black;
    final haloColor = muted ? AppColors.outlineVariant : AppColors.surfaceDim;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: haloColor, shape: BoxShape.circle),
        ),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: coreColor,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surfaceLowest, width: 3),
          ),
        ),
      ],
    );
  }
}

class _OrderDeliveryMapPainter extends CustomPainter {
  final double progress;
  final bool muted;

  const _OrderDeliveryMapPainter({required this.progress, required this.muted});

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.surfaceHighest, AppColors.surfaceLow],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final gridPaint = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    const gridSize = 34.0;
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final blockPaint = Paint()
      ..color = AppColors.surface.withValues(alpha: 0.95);
    final borderPaint = Paint()
      ..color = AppColors.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final rect in _streetBlocks(size)) {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rrect, blockPaint);
      canvas.drawRRect(rrect, borderPaint);
    }

    final routePath = _routePath(size);
    final routeMetric = routePath.computeMetrics().first;
    final routeBasePaint = Paint()
      ..color = AppColors.outline.withValues(alpha: 0.4)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(routePath, routeBasePaint);

    final activePath = routeMetric.extractPath(
      0,
      routeMetric.length * progress.clamp(0.0, 1.0),
    );
    final activePaint = Paint()
      ..color = muted ? AppColors.secondary : AppColors.black
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(activePath, activePaint);
  }

  @override
  bool shouldRepaint(covariant _OrderDeliveryMapPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.muted != muted;
  }
}

Path _routePath(Size size) {
  return Path()
    ..moveTo(size.width * 0.14, size.height * 0.8)
    ..lineTo(size.width * 0.26, size.height * 0.66)
    ..lineTo(size.width * 0.48, size.height * 0.58)
    ..lineTo(size.width * 0.66, size.height * 0.46)
    ..lineTo(size.width * 0.8, size.height * 0.26);
}

Offset _routeOffset(Size size, double progress) {
  final metric = _routePath(size).computeMetrics().first;
  final tangent = metric.getTangentForOffset(
    metric.length * progress.clamp(0.0, 1.0),
  );
  return tangent?.position ?? Offset(size.width * 0.8, size.height * 0.26);
}

List<Rect> _streetBlocks(Size size) {
  return [
    Rect.fromLTWH(size.width * 0.08, size.height * 0.12, 72, 54),
    Rect.fromLTWH(size.width * 0.58, size.height * 0.1, 88, 52),
    Rect.fromLTWH(size.width * 0.16, size.height * 0.42, 92, 64),
    Rect.fromLTWH(size.width * 0.58, size.height * 0.54, 104, 72),
    Rect.fromLTWH(size.width * 0.28, size.height * 0.72, 90, 44),
  ];
}
