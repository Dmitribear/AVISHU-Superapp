import 'package:flutter/material.dart';

import 'package:avishu/features/orders/presentation/shared/order_panels.dart';
import 'package:avishu/shared/widgets/avishu_button.dart';

import 'client_order_info_section.dart';
import 'client_payment_form_section.dart';

class ClientPaymentSection extends StatelessWidget {
  final bool compact;
  final String formTitle;
  final TextEditingController cardController;
  final String cardNumberLabel;
  final TextEditingController expiryController;
  final String expiryLabel;
  final TextEditingController cvvController;
  final String cvvLabel;
  final String detailsTitle;
  final List<OrderInfoRowData> detailsRows;
  final String submitLabel;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const ClientPaymentSection({
    super.key,
    required this.compact,
    required this.formTitle,
    required this.cardController,
    required this.cardNumberLabel,
    required this.expiryController,
    required this.expiryLabel,
    required this.cvvController,
    required this.cvvLabel,
    required this.detailsTitle,
    required this.detailsRows,
    required this.submitLabel,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientPaymentFormSection(
          compact: compact,
          title: formTitle,
          cardController: cardController,
          cardNumberLabel: cardNumberLabel,
          expiryController: expiryController,
          expiryLabel: expiryLabel,
          cvvController: cvvController,
          cvvLabel: cvvLabel,
        ),
        const SizedBox(height: 12),
        ClientOrderInfoSection(title: detailsTitle, rows: detailsRows),
        const SizedBox(height: 18),
        AvishuButton(
          text: submitLabel,
          expanded: true,
          variant: AvishuButtonVariant.filled,
          onPressed: isSubmitting ? null : onSubmit,
        ),
      ],
    );
  }
}
