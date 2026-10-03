import 'package:flutter/material.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import '../theme/nepali_typography.dart';

/// Interactive Six Ritus (६ ऋतु) season indicator widget for Siti Counter 3.0.
/// Visualizes the current Vedic/Nepali seasonal cycle with active produce cues.
class SixRitusIndicator extends StatefulWidget {
  final BsDate currentDate;
  final bool preferNepali;
  final ValueChanged<RituName>? onRituSelected;

  const SixRitusIndicator({
    super.key,
    required this.currentDate,
    this.preferNepali = true,
    this.onRituSelected,
  });

  @override
  State<SixRitusIndicator> createState() => _SixRitusIndicatorState();
}

class _SixRitusIndicatorState extends State<SixRitusIndicator> {
  late RituName _selectedRitu;

  @override
  void initState() {
    super.initState();
    _selectedRitu = NepaliCalendar.getRituForBsMonth(widget.currentDate.month).id;
  }

  Color _getRituColor(RituName ritu) {
    switch (ritu) {
      case RituName.basanta:
        return const Color(0xFFE91E63); // Blossom Pink
      case RituName.grishma:
        return const Color(0xFFFF9800); // Solar Amber
      case RituName.barsha:
        return const Color(0xFF00897B); // Monsoon Teal
      case RituName.sharad:
        return const Color(0xFFF57F17); // Autumn Harvest Gold
      case RituName.hemanta:
        return const Color(0xFF795548); // Earthy Dew Brown
      case RituName.shishir:
        return const Color(0xFF0288D1); // Winter Cyan
    }
  }

  IconData _getRituIcon(RituName ritu) {
    switch (ritu) {
      case RituName.basanta:
        return Icons.local_florist_rounded;
      case RituName.grishma:
        return Icons.wb_sunny_rounded;
      case RituName.barsha:
        return Icons.water_drop_rounded;
      case RituName.sharad:
        return Icons.grain_rounded;
      case RituName.hemanta:
        return Icons.spa_rounded;
      case RituName.shishir:
        return Icons.ac_unit_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRituInfo = NepaliCalendar.sixRitus[_selectedRitu]!;
    final formattedDate = NepaliCalendar.formatBs(
      widget.currentDate,
      preferNepali: widget.preferNepali,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date & Active Ritu Name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.preferNepali ? 'आजको मिति' : "Today's Date",
                    style: NepaliTypography.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: NepaliTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getRituColor(_selectedRitu).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getRituColor(_selectedRitu),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getRituIcon(_selectedRitu),
                      size: 16,
                      color: _getRituColor(_selectedRitu),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.preferNepali ? activeRituInfo.nameNe : activeRituInfo.nameEn,
                      style: NepaliTypography.labelLarge.copyWith(
                        color: _getRituColor(_selectedRitu),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Six Ritus Selector Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: RituName.values.map((ritu) {
                final isSelected = ritu == _selectedRitu;
                final info = NepaliCalendar.sixRitus[ritu]!;
                final color = _getRituColor(ritu);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedRitu = ritu;
                      });
                      widget.onRituSelected?.call(ritu);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? color : color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getRituIcon(ritu),
                            size: 14,
                            color: isSelected ? Colors.white : color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.preferNepali ? info.nameNe : info.nameEn.split(' ')[0],
                            style: NepaliTypography.bodyMedium.copyWith(
                              color: isSelected ? Colors.white : color,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Element / Season description
          Text(
            widget.preferNepali
                ? 'विशेषता: ${activeRituInfo.element} (महिना: ${activeRituInfo.bsMonths.map((m) => NepaliCalendar.nepaliMonthsNe[m - 1]).join(', ')})'
                : 'Signature: ${activeRituInfo.element} (Months: ${activeRituInfo.bsMonths.map((m) => NepaliCalendar.nepaliMonthsEn[m - 1]).join(', ')})',
            style: NepaliTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
