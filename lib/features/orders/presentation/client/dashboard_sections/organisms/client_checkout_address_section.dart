import 'package:flutter/material.dart';

import '../atoms/client_surface_card.dart';

class ClientCheckoutAddressSection extends StatelessWidget {
  final bool compact;
  final String title;
  final List<Widget> presetChips;
  final TextEditingController cityController;
  final TextEditingController addressController;
  final TextEditingController apartmentController;
  final TextEditingController noteController;
  final String cityLabel;
  final String addressLabel;
  final String apartmentLabel;
  final String noteLabel;

  const ClientCheckoutAddressSection({
    super.key,
    required this.compact,
    required this.title,
    required this.presetChips,
    required this.cityController,
    required this.addressController,
    required this.apartmentController,
    required this.noteController,
    required this.cityLabel,
    required this.addressLabel,
    required this.apartmentLabel,
    required this.noteLabel,
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
          Wrap(spacing: 8, runSpacing: 8, children: presetChips),
          const SizedBox(height: 12),
          TextField(
            controller: cityController,
            decoration: InputDecoration(labelText: cityLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: addressController,
            decoration: InputDecoration(labelText: addressLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: apartmentController,
            decoration: InputDecoration(labelText: apartmentLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: InputDecoration(labelText: noteLabel),
          ),
        ],
      ),
    );
  }
}
