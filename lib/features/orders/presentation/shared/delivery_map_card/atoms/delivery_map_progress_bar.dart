import 'package:flutter/material.dart';

class DeliveryMapProgressBar extends StatelessWidget {
  final double progress;

  const DeliveryMapProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF74D8C9),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}
