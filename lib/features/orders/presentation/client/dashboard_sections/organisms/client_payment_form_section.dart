import 'package:flutter/material.dart';

import '../atoms/client_surface_card.dart';

class ClientPaymentFormSection extends StatelessWidget {
  final bool compact;
  final String title;
  final TextEditingController cardController;
  final String cardNumberLabel;
  final TextEditingController expiryController;
  final String expiryLabel;
  final TextEditingController cvvController;
  final String cvvLabel;

  const ClientPaymentFormSection({
    super.key,
    required this.compact,
    required this.title,
    required this.cardController,
    required this.cardNumberLabel,
    required this.expiryController,
    required this.expiryLabel,
    required this.cvvController,
    required this.cvvLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ClientSurfaceCard(
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: cardController,
            decoration: InputDecoration(labelText: cardNumberLabel),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: expiryController,
                  decoration: InputDecoration(labelText: expiryLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: cvvController,
                  decoration: InputDecoration(labelText: cvvLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
