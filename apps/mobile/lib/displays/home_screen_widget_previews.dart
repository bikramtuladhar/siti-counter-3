import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../theme/tokens.dart';

/// Previews native glanceable home screen widgets (iOS WidgetKit, Android Glance)
/// for Today's Meals, Active Siti Count, and Grocery Checklist.
class HomeScreenWidgetPreviews extends StatelessWidget {
  final TodaysMealsWidgetData? todaysMeals;
  final ActiveSitiWidgetData? activeSiti;
  final GroceryChecklistWidgetData? groceryChecklist;

  const HomeScreenWidgetPreviews({
    super.key,
    this.todaysMeals,
    this.activeSiti,
    this.groceryChecklist,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SitiSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Native Glanceable Home Widgets",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: SitiColors.terracotta,
                ),
          ),
          const SizedBox(height: SitiSpacing.xs),
          Text(
            "Live previews for iOS WidgetKit and Android Glance home screens",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: SitiSpacing.md),
          if (activeSiti != null) ...[
            ActiveSitiWidgetCard(data: activeSiti!),
            const SizedBox(height: SitiSpacing.md),
          ],
          if (todaysMeals != null) ...[
            TodaysMealsWidgetCard(data: todaysMeals!),
            const SizedBox(height: SitiSpacing.md),
          ],
          if (groceryChecklist != null) ...[
            GroceryChecklistWidgetCard(data: groceryChecklist!),
          ],
        ],
      ),
    );
  }
}

/// Glanceable widget card for Active Siti Counter (iOS medium / Android 4x2)
class ActiveSitiWidgetCard extends StatelessWidget {
  final ActiveSitiWidgetData data;

  const ActiveSitiWidgetCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('widget_active_siti'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: data.isAlarmActive ? SitiColors.alert : SitiColors.terracotta.withValues(alpha: 0.3),
          width: data.isAlarmActive ? 2 : 1,
        ),
      ),
      elevation: 3,
      color: data.isAlarmActive ? const Color(0xFFFFEBEE) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(SitiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 20,
                      color: data.isAlarmActive ? SitiColors.alert : SitiColors.terracotta,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SITI COUNTER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: data.isAlarmActive ? SitiColors.alert : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: data.isAlarmActive
                        ? SitiColors.alert
                        : (data.status == 'cooking' ? SitiColors.freshGreen : Colors.grey[400]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SitiSpacing.sm),
            Text(
              '${data.dishTitleEn} (${data.dishTitleNe})',
              key: const Key('widget_siti_dish_title'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: SitiSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  key: const Key('widget_siti_whistle_value'),
                  text: TextSpan(
                    text: '${data.currentWhistles}',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: data.isAlarmActive ? SitiColors.alert : SitiColors.terracotta,
                      fontFamily: 'monospace',
                    ),
                    children: [
                      TextSpan(
                        text: ' / ${data.targetWhistles} whistles',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${data.progressPercent}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: data.isAlarmActive ? SitiColors.alert : SitiColors.freshGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (data.progressPercent / 100.0).clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                data.isAlarmActive ? SitiColors.alert : SitiColors.terracotta,
              ),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            if (data.isAlarmActive) ...[
              const SizedBox(height: SitiSpacing.sm),
              Container(
                key: const Key('widget_siti_alarm_banner'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: SitiColors.alert,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Target Siti Reached! Turn off the burner now.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Glanceable widget card for Today's Meals (iOS medium / Android 4x2)
class TodaysMealsWidgetCard extends StatelessWidget {
  final TodaysMealsWidgetData data;

  const TodaysMealsWidgetCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('widget_todays_meals'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: SitiColors.freshGreen.withValues(alpha: 0.3)),
      ),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(SitiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant_menu, size: 20, color: SitiColors.freshGreen),
                    const SizedBox(width: 8),
                    Text(
                      "TODAY'S MEALS",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: SitiColors.freshGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${data.rituNameEn} (${data.rituNameNe})',
                    style: const TextStyle(
                      color: SitiColors.freshGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SitiSpacing.sm),
            Text(
              'Date: ${data.dateIso} • ${data.totalPlannedMeals} meals scheduled',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const Divider(height: 18),
            ...data.meals.map(
              (meal) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 68,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        meal.slotTitleEn,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.recipeTitleEn,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            meal.recipeTitleNe,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${meal.servings}p',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glanceable widget card for Grocery Checklist (iOS small/medium, Android 2x2/4x2)
class GroceryChecklistWidgetCard extends StatelessWidget {
  final GroceryChecklistWidgetData data;

  const GroceryChecklistWidgetCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('widget_grocery_checklist'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(SitiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_basket_outlined, size: 20, color: SitiColors.terracotta),
                    const SizedBox(width: 8),
                    Text(
                      'GROCERY CHECKLIST',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                Text(
                  '${data.completedItems}/${data.totalItems} done',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: data.pendingItems == 0 ? SitiColors.freshGreen : SitiColors.terracotta,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SitiSpacing.xs),
            Text(
              '${data.pendingItems} items pending purchase',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const Divider(height: 16),
            ...data.previewItems.map(
              (item) => Padding(
                key: Key('widget_grocery_item_${item.itemId}'),
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    Icon(
                      item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 18,
                      color: item.isCompleted ? SitiColors.freshGreen : Colors.grey[400],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.nameEn} (${item.nameNe})',
                        style: TextStyle(
                          fontSize: 13,
                          decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                          color: item.isCompleted ? Colors.grey[500] : Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      item.quantityStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
