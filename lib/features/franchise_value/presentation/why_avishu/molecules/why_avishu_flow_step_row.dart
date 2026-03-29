import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';

class WhyAvishuFlowStepRow extends StatelessWidget {
  final String label;
  final bool isLast;

  const WhyAvishuFlowStepRow({
    super.key,
    required this.label,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (!isLast) ...[
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward, size: 18, color: AppColors.black),
          ],
        ],
      ),
    );
  }
}
