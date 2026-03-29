import 'package:flutter/material.dart';

import '../../../../../../shared/widgets/avishu_button.dart';
import '../../../../domain/models/order_model.dart';
import '../../../shared/order_digital_twin_card.dart';
import '../../../shared/order_panels.dart';
import '../atoms/production_info_chip.dart';
import '../atoms/production_status_badge.dart';
import '../atoms/production_surface_card.dart';

class ProductionOrderDetailSection extends StatelessWidget {
  final OrderModel order;
  final String clientDisplayName;
  final String orderLabel;
  final String statusLabel;
  final String statusSummary;
  final String noteFieldLabel;
  final String technicalSheetTitle;
  final String clientNoteTitle;
  final String franchiseeNoteTitle;
  final String noteRowLabel;
  final String readyLabel;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final bool compact;
  final bool isSubmitting;
  final TextEditingController noteController;
  final List<OrderInfoRowData> summaryRows;

  const ProductionOrderDetailSection({
    super.key,
    required this.order,
    required this.clientDisplayName,
    required this.orderLabel,
    required this.statusLabel,
    required this.statusSummary,
    required this.noteFieldLabel,
    required this.technicalSheetTitle,
    required this.clientNoteTitle,
    required this.franchiseeNoteTitle,
    required this.noteRowLabel,
    required this.readyLabel,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.compact,
    required this.isSubmitting,
    required this.noteController,
    required this.summaryRows,
  });

  @override
  Widget build(BuildContext context) {
    final keyFacts = <String>[
      clientDisplayName,
      order.sizeLabel,
      order.formattedAddress,
    ].where((item) => item.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductionSurfaceCard(
          compact: compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      orderLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: ProductionStatusBadge(label: statusLabel)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                order.productName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                statusSummary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (keyFacts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: keyFacts
                      .map((fact) => ProductionInfoChip(label: fact))
                      .toList(),
                ),
              ],
              if (primaryActionLabel != null && onPrimaryAction != null) ...[
                const SizedBox(height: 18),
                AvishuButton(
                  text: primaryActionLabel!,
                  expanded: true,
                  variant: AvishuButtonVariant.filled,
                  onPressed: isSubmitting ? null : onPrimaryAction,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrderDigitalTwinCard(
          order: order,
          clientDisplayName: clientDisplayName,
        ),
        const SizedBox(height: 12),
        ProductionSurfaceCard(
          compact: compact,
          child: TextField(
            controller: noteController,
            maxLines: 3,
            decoration: InputDecoration(labelText: noteFieldLabel),
          ),
        ),
        const SizedBox(height: 12),
        OrderInfoCard(title: technicalSheetTitle, rows: summaryRows),
        if (order.clientNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OrderInfoCard(
            title: clientNoteTitle,
            rows: [
              OrderInfoRowData(label: noteRowLabel, value: order.clientNote),
            ],
          ),
        ],
        if (order.franchiseeNote.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OrderInfoCard(
            title: franchiseeNoteTitle,
            rows: [
              OrderInfoRowData(
                label: noteRowLabel,
                value: order.franchiseeNote,
              ),
            ],
          ),
        ],
        if (primaryActionLabel == null) ...[
          const SizedBox(height: 12),
          ProductionSurfaceCard(
            compact: compact,
            child: Text(
              readyLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ],
    );
  }
}
