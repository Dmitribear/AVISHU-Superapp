import 'package:flutter/foundation.dart';

class DeskHelpGuidePoint {
  final String title;
  final String description;

  const DeskHelpGuidePoint({required this.title, required this.description});
}

class DeskHelpFlowStep {
  final String title;
  final String details;

  const DeskHelpFlowStep({required this.title, required this.details});
}

class DeskHelpSupportAction {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  const DeskHelpSupportAction({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });
}
