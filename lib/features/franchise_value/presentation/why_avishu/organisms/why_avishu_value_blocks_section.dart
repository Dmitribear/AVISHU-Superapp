import 'package:flutter/material.dart';

import '../../../../../core/theme/typography.dart';
import '../../../../../shared/i18n/app_localization.dart';
import '../content/why_avishu_content.dart';
import '../molecules/why_avishu_value_card.dart';

class WhyAvishuValueBlocksSection extends StatelessWidget {
  final AppLanguage language;
  final List<WhyAvishuValueBlock> blocks;

  const WhyAvishuValueBlocksSection({
    super.key,
    required this.language,
    required this.blocks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(language, ru: 'БЛОКИ ЦЕННОСТИ', en: 'VALUE BLOCKS'),
          style: AppTypography.eyebrow,
        ),
        const SizedBox(height: 12),
        ...blocks.map(
          (block) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WhyAvishuValueCard(block: block),
          ),
        ),
      ],
    );
  }
}
