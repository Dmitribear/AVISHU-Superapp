import 'package:flutter/material.dart';

import '../../../../../../core/theme/colors.dart';

class DeliveryCourierMarker extends StatelessWidget {
  final bool isCompleted;

  const DeliveryCourierMarker({super.key, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    final haloColor = isCompleted
        ? const Color(0x40F4C46B)
        : const Color(0x3374D8C9);
    final coreColor = isCompleted
        ? const Color(0xFFF4C46B)
        : const Color(0xFF74D8C9);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: haloColor, shape: BoxShape.circle),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: coreColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 3),
            ),
          ),
          const Positioned(
            top: 4,
            child: Icon(
              Icons.local_shipping_rounded,
              size: 14,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
