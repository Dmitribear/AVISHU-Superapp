import 'package:flutter/material.dart';

import 'package:avishu/core/theme/colors.dart';
import 'package:avishu/features/orders/presentation/shared/desk_help/atoms/desk_help_section_label.dart';

Future<void> showDeskHelpSheet(
  BuildContext context, {
  required String eyebrow,
  required String title,
  required String description,
  required Widget child,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final screenHeight = MediaQuery.sizeOf(sheetContext).height;

      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight: screenHeight * 0.82,
          ),
          child: Material(
            color: AppColors.surfaceLowest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            clipBehavior: Clip.antiAlias,
            child: DeskHelpSheet(
              eyebrow: eyebrow,
              title: title,
              description: description,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

class DeskHelpSheet extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final Widget child;

  const DeskHelpSheet({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.black),
                  ),
                ),
                DeskHelpSectionLabel(label: eyebrow),
                const SizedBox(height: 10),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
