import 'package:flutter/material.dart';

import '../atoms/client_section_heading.dart';
import '../molecules/client_delivery_method_card.dart';

class ClientCheckoutMethodSection extends StatelessWidget {
  final String title;
  final String methodLabel;
  final String courierLabel;
  final bool isCourierActive;
  final VoidCallback onCourierTap;
  final String pickupLabel;
  final bool isPickupActive;
  final VoidCallback onPickupTap;

  const ClientCheckoutMethodSection({
    super.key,
    required this.title,
    required this.methodLabel,
    required this.courierLabel,
    required this.isCourierActive,
    required this.onCourierTap,
    required this.pickupLabel,
    required this.isPickupActive,
    required this.onPickupTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientSectionHeading(label: title),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ClientDeliveryMethodCard(
                eyebrowLabel: methodLabel,
                label: courierLabel,
                isActive: isCourierActive,
                onTap: onCourierTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClientDeliveryMethodCard(
                eyebrowLabel: methodLabel,
                label: pickupLabel,
                isActive: isPickupActive,
                onTap: onPickupTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
