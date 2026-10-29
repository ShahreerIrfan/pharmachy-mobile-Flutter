// lib/ui/widgets/kpi_card.dart
// Architecture Decision: ADR-0007, ADR-0009 & ADR-0024

import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = AppTokens.primaryTeal,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: AppTokens.borderSubtle, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTokens.captionMuted,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppTokens.space8),
              Icon(icon, color: iconColor, size: 20.0),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          Text(value, style: AppTokens.kpiValue),
          if (subtitle != null) ...[
            const SizedBox(height: AppTokens.space4),
            Text(subtitle!, style: AppTokens.captionMuted),
          ],
        ],
      ),
    );
  }
}
