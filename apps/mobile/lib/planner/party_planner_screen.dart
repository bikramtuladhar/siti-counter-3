import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';

/// Screen providing Party Mode planning, scaled menu builder,
/// backwards T-minus prep timeline, equipment conflict warnings, and co-host delegation (Section 8.7).
class PartyPlannerScreen extends StatefulWidget {
  final PartyPlanInput? initialInput;
  final String currentLanguage;
  final ValueChanged<PartyPlanResult>? onPlanSaved;

  const PartyPlannerScreen({
    super.key,
    this.initialInput,
    this.currentLanguage = 'ne',
    this.onPlanSaved,
  });

  @override
  State<PartyPlannerScreen> createState() => _PartyPlannerScreenState();
}

class _PartyPlannerScreenState extends State<PartyPlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _guestCount;
  late String _serveTime;
  late int _burnerCount;
  late List<PartyMenuItem> _menuItems;
  late List<String> _availableEquipment;
  late List<String> _coHosts;
  late PartyPlanResult _planResult;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final input = widget.initialInput ?? _defaultFeastInput();
    _guestCount = input.guestCount;
    _serveTime = input.serveTime;
    _burnerCount = input.burnerCount;
    _menuItems = List.from(input.menuItems);
    _availableEquipment = List.from(input.availableEquipment);
    _coHosts = List.from(input.coHosts);

    _recalculatePlan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  PartyPlanInput _defaultFeastInput() {
    return const PartyPlanInput(
      titleEn: 'Dashain Family Feast',
      titleNe: 'दशैं पारिवारिक भोज',
      guestCount: 16,
      serveTime: '19:30',
      burnerCount: 3,
      availableEquipment: ['pressure_cooker_5l', 'kadai', 'rice_cooker', 'blender'],
      coHosts: ['Bikram', 'Sita', 'Aayush'],
      menuItems: [
        PartyMenuItem(
          recipeId: 'khasi_ko_masu',
          nameEn: 'Mutton Curry',
          nameNe: 'खसीको मासु',
          course: CourseType.main,
          prepDurationMinutes: 20,
          cookDurationMinutes: 45,
          marinateMinutes: 60,
          requiredEquipment: ['pressure_cooker_5l'],
          requiredBurners: 1,
          ingredients: [
            PartyIngredient(id: 'mutton', nameEn: 'Mutton', nameNe: 'खसीको मासु', baseGrams: 800),
            PartyIngredient(id: 'onion', nameEn: 'Onion', nameNe: 'प्याज', baseGrams: 300),
          ],
        ),
        PartyMenuItem(
          recipeId: 'dal_makhani',
          nameEn: 'Dal Makhani',
          nameNe: 'दाल मखनी',
          course: CourseType.main,
          prepDurationMinutes: 15,
          cookDurationMinutes: 40,
          requiredEquipment: ['pressure_cooker_5l'],
          requiredBurners: 1,
          ingredients: [
            PartyIngredient(id: 'black_lentils', nameEn: 'Black Lentils', nameNe: 'कालो दाल', baseGrams: 300),
            PartyIngredient(id: 'butter', nameEn: 'Butter / Ghee', nameNe: 'घ्यु / नौनी', baseGrams: 100),
          ],
        ),
        PartyMenuItem(
          recipeId: 'jeera_rice',
          nameEn: 'Jeera Rice',
          nameNe: 'जीरा राइस',
          course: CourseType.side,
          prepDurationMinutes: 10,
          cookDurationMinutes: 25,
          requiredEquipment: ['rice_cooker'],
          requiredBurners: 0,
          ingredients: [
            PartyIngredient(id: 'rice', nameEn: 'Basmati Rice', nameNe: 'बासमती चामल', baseGrams: 500),
          ],
        ),
        PartyMenuItem(
          recipeId: 'aloo_dum',
          nameEn: 'Dum Aloo',
          nameNe: 'दम आलु',
          course: CourseType.side,
          prepDurationMinutes: 15,
          cookDurationMinutes: 30,
          requiredEquipment: ['kadai'],
          requiredBurners: 1,
          ingredients: [
            PartyIngredient(id: 'potato', nameEn: 'Baby Potatoes', nameNe: 'सानो आलु', baseGrams: 600),
          ],
        ),
        PartyMenuItem(
          recipeId: 'mohi',
          nameEn: 'Mint Mohi',
          nameNe: 'पुदिना मोही',
          course: CourseType.drink,
          prepDurationMinutes: 15,
          cookDurationMinutes: 0,
          requiredEquipment: ['blender'],
          ingredients: [
            PartyIngredient(id: 'curd', nameEn: 'Curd / Dahi', nameNe: 'दही', baseGrams: 500),
          ],
        ),
      ],
    );
  }

  void _recalculatePlan() {
    final input = PartyPlanInput(
      titleEn: widget.initialInput?.titleEn ?? 'Dashain Family Feast',
      titleNe: widget.initialInput?.titleNe ?? 'दशैं पारिवारिक भोज',
      guestCount: _guestCount,
      serveTime: _serveTime,
      burnerCount: _burnerCount,
      availableEquipment: _availableEquipment,
      coHosts: _coHosts,
      menuItems: _menuItems,
    );

    setState(() {
      _planResult = PartyPlannerEngine.generatePlan(input);
    });
  }

  void _updateGuestCount(int delta) {
    final newCount = _guestCount + delta;
    if (newCount >= 2 && newCount <= 100) {
      _guestCount = newCount;
      _recalculatePlan();
    }
  }

  void _toggleTaskCompleted(String taskId) {
    setState(() {
      final task = _planResult.timeline.firstWhere((t) => t.id == taskId);
      final idx = _planResult.timeline.indexOf(task);
      _planResult.timeline[idx] = TMinusTask(
        id: task.id,
        recipeId: task.recipeId,
        recipeNameEn: task.recipeNameEn,
        recipeNameNe: task.recipeNameNe,
        titleEn: task.titleEn,
        titleNe: task.titleNe,
        tMinusMinutes: task.tMinusMinutes,
        targetTime: task.targetTime,
        durationMinutes: task.durationMinutes,
        equipmentUsed: task.equipmentUsed,
        burnersUsed: task.burnersUsed,
        assignedCoHost: task.assignedCoHost,
        isCompleted: !task.isCompleted,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNepali = _isNepali;

    return Scaffold(
      backgroundColor: SitiColors.dark,
      appBar: AppBar(
        backgroundColor: SitiColors.cardDark,
        elevation: 0,
        title: Text(
          isNepali ? 'पार्टी मोड योजनाकार' : 'Party Mode Planner',
          style: NepaliTypography.titleLarge.copyWith(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: SitiColors.terracotta,
          tabs: [
            Tab(
              icon: const Icon(Icons.timeline),
              text: isNepali ? 'समयतालिका' : 'T-Minus',
            ),
            Tab(
              icon: const Icon(Icons.restaurant_menu),
              text: isNepali ? 'मेनु र उपकरण' : 'Menu & Gear',
            ),
            Tab(
              icon: const Icon(Icons.shopping_cart),
              text: isNepali ? 'सामग्री सूची' : 'Groceries',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Guest Count & Serve Time Header
          _buildPartyHeader(isNepali),

          // Conflict Banner (if any)
          if (!_planResult.isFeasibleWithoutConflict)
            _buildConflictBanner(isNepali)
          else
            _buildFeasibleBanner(isNepali),

          // Tabs content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTimelineTab(isNepali),
                _buildMenuAndEquipmentTab(isNepali),
                _buildGroceriesTab(isNepali),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyHeader(bool isNepali) {
    return Container(
      color: SitiColors.cardDark,
      padding: const EdgeInsets.symmetric(horizontal: SitiSpacing.md, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Guest count stepper
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isNepali ? 'पाहुना संख्या' : 'Guest Count',
                style: NepaliTypography.bodySmall.copyWith(color: Colors.white60),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  InkWell(
                    key: const Key('guest_count_decrement'),
                    onTap: () => _updateGuestCount(-2),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.remove, color: Colors.white, size: 18),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '$_guestCount',
                      key: const Key('guest_count_text'),
                      style: NepaliTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  InkWell(
                    key: const Key('guest_count_increment'),
                    onTap: () => _updateGuestCount(2),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Scale factor badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: SitiColors.terracotta.withAlpha(50),
              borderRadius: SitiRadius.roundedSm,
              border: Border.all(color: SitiColors.terracotta),
            ),
            child: Text(
              '${_planResult.scaleFactor.toStringAsFixed(1)}x Scale',
              style: const TextStyle(
                color: SitiColors.terracotta,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),

          // Serve Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isNepali ? 'खाना खुवाउने समय' : 'Serving Time',
                style: NepaliTypography.bodySmall.copyWith(color: Colors.white60),
              ),
              const SizedBox(height: 4),
              Text(
                _serveTime,
                style: NepaliTypography.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConflictBanner(bool isNepali) {
    final conflictCount = _planResult.equipmentConflicts.length + _planResult.burnerConflicts.length;

    return Container(
      key: const Key('conflict_alert_banner'),
      margin: const EdgeInsets.all(SitiSpacing.sm),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SitiColors.warning.withAlpha(50),
        borderRadius: SitiRadius.roundedMd,
        border: Border.all(color: SitiColors.warning, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: SitiColors.warning, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isNepali
                      ? 'उपकरण वा चुल्हो द्वन्द्व पत्ता लाग्यो ($conflictCount)'
                      : 'Equipment / Burner Conflicts Detected ($conflictCount)',
                  style: NepaliTypography.bodyMedium.copyWith(
                    color: SitiColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._planResult.equipmentConflicts.map((c) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  isNepali ? '• ${c.resolutionSuggestionNe}' : '• ${c.resolutionSuggestionEn}',
                  style: NepaliTypography.bodySmall.copyWith(color: Colors.white70),
                ),
              )),
          ..._planResult.burnerConflicts.map((c) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  isNepali ? '• ${c.resolutionSuggestionNe}' : '• ${c.resolutionSuggestionEn}',
                  style: NepaliTypography.bodySmall.copyWith(color: Colors.white70),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFeasibleBanner(bool isNepali) {
    return Container(
      key: const Key('feasible_banner'),
      margin: const EdgeInsets.all(SitiSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SitiColors.freshGreen.withAlpha(50),
        borderRadius: SitiRadius.roundedSm,
        border: Border.all(color: SitiColors.freshGreen),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: SitiColors.freshGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isNepali
                  ? 'समयतालिका पूर्ण सुरक्षित: कुनै उपकरण द्वन्द्व छैन'
                  : 'Timeline Feasible: No Equipment Conflicts',
              style: NepaliTypography.bodySmall.copyWith(
                color: SitiColors.freshGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTab(bool isNepali) {
    final tasks = _planResult.timeline;

    return ListView.builder(
      padding: const EdgeInsets.all(SitiSpacing.md),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final hours = task.tMinusMinutes ~/ 60;
        final mins = task.tMinusMinutes % 60;
        final tMinusLabel = hours > 0
            ? (mins > 0 ? 'T-${hours}h ${mins}m' : 'T-${hours}h')
            : 'T-${mins}m';

        return Container(
          margin: const EdgeInsets.only(bottom: SitiSpacing.sm),
          decoration: BoxDecoration(
            color: task.isCompleted ? Colors.white12 : SitiColors.cardDark,
            borderRadius: SitiRadius.roundedMd,
            border: Border.all(
              color: task.isCompleted ? SitiColors.freshGreen : Colors.white12,
            ),
          ),
          child: ListTile(
            leading: Checkbox(
              activeColor: SitiColors.freshGreen,
              value: task.isCompleted,
              onChanged: (_) => _toggleTaskCompleted(task.id),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    isNepali ? task.titleNe : task.titleEn,
                    style: NepaliTypography.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SitiColors.terracotta.withAlpha(60),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tMinusLabel,
                    style: const TextStyle(
                      color: SitiColors.terracotta,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.white60),
                  const SizedBox(width: 4),
                  Text(
                    '${task.targetTime} (${task.durationMinutes} min)',
                    style: NepaliTypography.bodySmall.copyWith(color: Colors.white60),
                  ),
                  const Spacer(),
                  if (task.assignedCoHost != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '👤 ${task.assignedCoHost}',
                        style: NepaliTypography.bodySmall.copyWith(color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuAndEquipmentTab(bool isNepali) {
    return ListView(
      padding: const EdgeInsets.all(SitiSpacing.md),
      children: [
        Text(
          isNepali ? 'मेनुका परिकारहरू (${_menuItems.length})' : 'Menu Courses (${_menuItems.length})',
          style: NepaliTypography.titleMedium.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        ..._menuItems.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SitiColors.cardDark,
                borderRadius: SitiRadius.roundedSm,
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: SitiColors.terracotta.withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.course.name.toUpperCase(),
                      style: const TextStyle(color: SitiColors.terracotta, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isNepali ? item.nameNe : item.nameEn,
                      style: NepaliTypography.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${item.prepDurationMinutes + item.cookDurationMinutes} min',
                    style: NepaliTypography.bodySmall.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            )),
        const SizedBox(height: SitiSpacing.lg),
        Text(
          isNepali ? 'उपलब्ध भाँडाकुँडा र बर्नर' : 'Available Equipment & Burners',
          style: NepaliTypography.titleMedium.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SitiColors.cardDark,
            borderRadius: SitiRadius.roundedSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isNepali ? 'चुल्हो बर्नर: $_burnerCount बर्नर' : 'Stove Burners: $_burnerCount Burners',
                style: NepaliTypography.bodyMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _availableEquipment
                    .map((eq) => Chip(
                          backgroundColor: Colors.white12,
                          label: Text(
                            eq.replaceAll('_', ' '),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroceriesTab(bool isNepali) {
    final groceries = _planResult.combinedGroceries;

    return ListView(
      padding: const EdgeInsets.all(SitiSpacing.md),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isNepali ? 'कुल पार्टी सामग्री (${groceries.length})' : 'Combined Groceries (${groceries.length})',
              style: NepaliTypography.titleMedium.copyWith(color: Colors.white),
            ),
            Text(
              '$_guestCount guests',
              style: NepaliTypography.bodySmall.copyWith(color: SitiColors.terracotta, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...groceries.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: SitiColors.cardDark,
                borderRadius: SitiRadius.roundedSm,
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNepali ? item.nameNe : item.nameEn,
                    style: NepaliTypography.bodyMedium.copyWith(color: Colors.white),
                  ),
                  Text(
                    '${item.scaledGrams.toStringAsFixed(0)} ${item.unit}',
                    style: NepaliTypography.bodyMedium.copyWith(
                      color: SitiColors.freshGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
