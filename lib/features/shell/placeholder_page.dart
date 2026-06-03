import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// Consistent "coming in a later phase" surface for not-yet-built tabs.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.phase,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String phase;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.x2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.brandSoft,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                  child: Icon(icon, size: 34, color: c.brand),
                ),
                const SizedBox(height: AppSpace.xl),
                Text(title, style: AppText.title.copyWith(color: c.text)),
                const SizedBox(height: AppSpace.sm),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: AppSpace.xl),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(phase,
                      style: AppText.micro.copyWith(color: c.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
