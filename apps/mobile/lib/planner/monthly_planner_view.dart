import 'package:flutter/material.dart';

import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';
import 'planner_models.dart';

/// Month-at-a-glance view of the meal plan.
///
/// The week view answers "what am I cooking this week", which stops working over a month:
/// scrolling a 4-5 week grid of slots is slower than just checking what is already planned.
/// This shows only what exists, so an empty cell costs nothing to read.
class MonthlyPlannerView extends StatelessWidget {
  final DateTime month;
  final List<PlannedMeal> meals;
  final bool preferNepali;

  /// Total slot count per day, so a day can report coverage as well as a count.
  final int slotsPerDay;

  const MonthlyPlannerView({
    super.key,
    required this.month,
    required this.meals,
    required this.preferNepali,
    this.slotsPerDay = 3,
  });

  /// Meals grouped by ISO date, in one pass.
  Map<String, List<PlannedMeal>> _byDate() {
    final grouped = <String, List<PlannedMeal>>{};
    for (final meal in meals) {
      grouped.putIfAbsent(meal.dateIso, () => []).add(meal);
    }
    return grouped;
  }

  /// The grid's first cell: the Sunday on or before the 1st.
  DateTime _gridStart() {
    final first = DateTime(month.year, month.month, 1);
    final daysToSubtract = first.weekday == 7 ? 0 : first.weekday;
    return first.subtract(Duration(days: daysToSubtract));
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _byDate();
    final gridStart = _gridStart();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // Always render whole weeks so the columns stay aligned.
    final cellCount = ((daysInMonth + gridStart.weekday % 7) / 7).ceil() * 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _weekdayHeader(),
        const SizedBox(height: 6),
        for (var week = 0; week < cellCount / 7; week++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var day = 0; day < 7; day++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final cellIndex = week * 7 + day;
                        final date = gridStart.add(Duration(days: cellIndex));
                        final inMonth = date.month == month.month;
                        return _DayCell(
                          key: Key('month_cell_${date.toIso8601String().substring(0, 10)}'),
                          date: date,
                          inMonth: inMonth,
                          preferNepali: preferNepali,
                          isToday: _isToday(date),
                          meals: grouped[_isoDate(date)] ?? const [],
                          slotsPerDay: slotsPerDay,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Widget _weekdayHeader() {
    const nepali = ['आइत', 'सोम', 'मंगल', 'बुध', 'बिही', 'शुक्र', 'शनि'];
    const english = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Row(
      children: [
        for (var day = 0; day < 7; day++)
          Expanded(
            child: Center(
              child: Text(
                preferNepali ? nepali[day] : english[day],
                style: NepaliTypography.labelSmall.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool inMonth;
  final bool preferNepali;
  final bool isToday;
  final List<PlannedMeal> meals;
  final int slotsPerDay;

  const _DayCell({
    super.key,
    required this.date,
    required this.inMonth,
    required this.preferNepali,
    required this.isToday,
    required this.meals,
    required this.slotsPerDay,
  });

  @override
  Widget build(BuildContext context) {
    // Out-of-month days render empty rather than being hidden, so the grid keeps its shape.
    if (!inMonth) {
      // Blank but space-preserving, so the weekday columns stay aligned.
      return const SizedBox(height: 76);
    }

    final isFull = meals.length >= slotsPerDay;

    return Container(
      // Tall enough for two titles, an overflow count and the completeness dot. A shorter
      // cell overflowed on a fully booked day; the height must stay fixed because the grid
      // sits in a scroll view, leaving no upper bound for Expanded to divide.
      height: 76,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        color: isToday
            ? SitiColors.terracotta.withValues(alpha: 0.10)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isToday ? SitiColors.terracotta : Colors.grey.shade200,
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${date.day}',
            style: NepaliTypography.labelSmall.copyWith(
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: isToday ? SitiColors.terracotta : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: meals.isEmpty
                ? Center(
                    child: Icon(
                      Icons.add,
                      size: 12,
                      color: Colors.grey.shade300,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final meal in meals.take(2))
                        Container(
                          margin: const EdgeInsets.only(bottom: 1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: SitiColors.freshGreen.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            preferNepali ? meal.recipeTitleNe : meal.recipeTitleEn,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 8, height: 1.15),
                          ),
                        ),
                      if (meals.length > 2)
                        Text(
                          '+${meals.length - 2}',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
          ),
          if (meals.isNotEmpty)
            Container(
              width: 6,
              height: 3,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: isFull ? SitiColors.freshGreen : SitiColors.terracotta,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}