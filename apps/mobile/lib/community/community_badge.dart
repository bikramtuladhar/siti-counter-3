import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

/// Reusable badge indicating "Verified" or "Community" contribution status.
/// Section 17 & 20.2: Human review and automated moderation status.
class CommunityBadge extends StatelessWidget {
  final VerificationBadge badge;
  final bool isNepali;
  final double fontSize;

  const CommunityBadge({
    super.key,
    required this.badge,
    this.isNepali = true,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final isVerified = badge == VerificationBadge.verified;

    final bgColor = isVerified
        ? const Color(0xFFE8F5E9) // Light green
        : const Color(0xFFE1F5FE); // Light cyan/blue

    final borderColor = isVerified
        ? const Color(0xFF81C784)
        : const Color(0xFF4FC3F7);

    final textColor = isVerified
        ? const Color(0xFF1B5E20)
        : const Color(0xFF0277BD);

    final icon = isVerified
        ? Icons.verified
        : Icons.groups_outlined;

    final label = isVerified
        ? (isNepali ? 'प्रमाणित (Verified)' : 'Verified')
        : (isNepali ? 'सामुदायिक (Community)' : 'Community');

    return Container(
      key: Key('badge_${badge.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 2, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
