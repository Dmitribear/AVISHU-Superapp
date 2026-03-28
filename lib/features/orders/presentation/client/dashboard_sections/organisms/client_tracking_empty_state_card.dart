import 'package:flutter/material.dart';

import '../atoms/client_surface_card.dart';

class ClientTrackingEmptyStateCard extends StatelessWidget {
  final bool compact;
  final String message;

  const ClientTrackingEmptyStateCard({
    super.key,
    required this.compact,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ClientSurfaceCard(
      compact: compact,
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
