import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'ai_assistant_service.dart';

class ChatMessage {
  final bool isUser;
  final String text;
  final AssistantResponse? response;
  final DateTime timestamp;

  ChatMessage({
    required this.isUser,
    required this.text,
    this.response,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Offline-first 3-tier AI assistant screen for Siti Counter.
///
/// Implements Section 13 & 22.2:
/// - 3-tier routing: Deterministic -> On-Device -> Cloud Gemini
/// - Explicit cloud consent toggle with pseudonymization guarantee
/// - Zero medical & pediatric calorie advice guardrails
/// - Strict deterministic allergen post-check
/// - Executable action buttons: Cook Now, Add to Plan, Add to List, Start Timer
class AiAssistantScreen extends StatefulWidget {
  final AiAssistantService service;
  final String currentLanguage;
  final VoidCallback? onOpenCookNow;

  const AiAssistantScreen({
    super.key,
    required this.service,
    this.currentLanguage = 'en',
    this.onOpenCookNow,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        isUser: false,
        text: _isNepali
            ? 'नमस्ते! म सिट्ठी काउन्टरको भान्सा सहयोगी हुँ। तपाईंलाई आज के पकाउन वा रूपान्तरण गर्न सहयोग चाहिन्छ?'
            : 'Namaste! I am your Siti Counter kitchen assistant. How can I help with recipes, conversions, or cooking timers today?',
        response: const AssistantResponse(
          tier: AiRoutingTier.deterministic,
          replyEn:
              'Namaste! I am your Siti Counter kitchen assistant. How can I help with recipes, conversions, or cooking timers today?',
          replyNe:
              'नमस्ते! म सिट्ठी काउन्टरको भान्सा सहयोगी हुँ। तपाईंलाई आज के पकाउन वा रूपान्तरण गर्न सहयोग चाहिन्छ?',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitPrompt(String prompt) async {
    final clean = prompt.trim();
    if (clean.isEmpty || _isLoading) return;

    _inputController.clear();
    setState(() {
      _messages.add(ChatMessage(isUser: true, text: clean));
      _isLoading = true;
    });
    _scrollToBottom();

    final response = await widget.service.ask(
      prompt: clean,
      language: widget.currentLanguage,
    );

    if (!mounted) return;

    final replyText = _isNepali && response.replyNe.isNotEmpty
        ? response.replyNe
        : response.replyEn;

    setState(() {
      _messages.add(
        ChatMessage(
          isUser: false,
          text: replyText,
          response: response,
        ),
      );
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleAction(ExecutableAction action) {
    String msg;
    switch (action.type) {
      case ActionType.cookNow:
        msg = _isNepali
            ? 'पकाउन सुरु गर्दै: ${action.recipeTitleNe ?? action.labelNe}'
            : 'Starting cooking session for ${action.recipeTitleEn ?? action.labelEn}';
        widget.onOpenCookNow?.call();
        break;
      case ActionType.addToPlan:
        msg = _isNepali
            ? 'साप्ताहिक तालिकामा थपियो: ${action.recipeTitleNe ?? action.labelNe}'
            : 'Added to weekly meal plan: ${action.recipeTitleEn ?? action.labelEn}';
        break;
      case ActionType.addToList:
        msg = _isNepali
            ? 'बजार सूचीमा सामग्री थपियो'
            : 'Ingredients added to grocery list';
        break;
      case ActionType.startTimer:
        msg = _isNepali
            ? 'टाइमर सुरु गरियो: ${action.timerMinutes} मिनेट'
            : 'Timer started: ${action.timerMinutes} minutes';
        break;
      case ActionType.viewRecipe:
        msg = _isNepali ? 'परिकार विवरण हेर्दै' : 'Viewing details';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: NepaliTypography.bodyMedium.copyWith(color: Colors.white)),
        backgroundColor: SitiColors.terracotta,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: SitiColors.warmWhite,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: SitiColors.terracotta.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: SitiColors.terracotta, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isNepali ? 'सिट्ठी एआई सहयोगी' : 'Siti AI Assistant',
                style: NepaliTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: SitiColors.dark,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Cloud Consent Status Badge & Switch
          IconButton(
            key: const Key('cloud_consent_toggle_button'),
            icon: Icon(
              widget.service.hasCloudConsent
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              color: widget.service.hasCloudConsent ? Colors.teal : Colors.grey.shade600,
            ),
            tooltip: widget.service.hasCloudConsent
                ? (_isNepali ? 'क्लाउड एआई सक्रिय छ' : 'Cloud AI enabled')
                : (_isNepali ? 'क्लाउड एआई बन्द छ' : 'Cloud AI disabled'),
            onPressed: () {
              setState(() {
                widget.service.setCloudConsent(!widget.service.hasCloudConsent);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    widget.service.hasCloudConsent
                        ? (_isNepali
                            ? 'क्लाउड जेमिनी अनुमति दिइयो (व्यक्तिगत विवरण नामरहित राखिन्छ)'
                            : 'Cloud Gemini AI enabled (personal data pseudonymized)')
                        : (_isNepali
                            ? 'क्लाउड जेमिनी बन्द गरियो (अफलाइन मोड सक्रिय)'
                            : 'Cloud Gemini AI disabled (offline engine active)'),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageItem(msg);
                },
              ),
            ),

            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: SitiColors.terracotta),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isNepali ? 'सोच्दैछ...' : 'Thinking...',
                      style: NepaliTypography.bodySmall.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

            // Quick suggestion chips
            _buildSuggestionChips(),

            // Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 8, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: SitiColors.terracotta,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: const Radius.circular(2),
            ),
          ),
          child: Text(
            msg.text,
            style: NepaliTypography.bodyMedium.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    final resp = msg.response;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8, right: 36),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: const Radius.circular(2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tier Badge
            if (resp != null) _buildTierBadge(resp.tier),

            const SizedBox(height: 8),

            // Main Answer Text
            Text(
              msg.text,
              style: NepaliTypography.bodyMedium.copyWith(
                color: SitiColors.dark,
                height: 1.45,
              ),
            ),

            // Safety Warning / Notes
            if (resp != null && resp.safetyNotes.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        resp.safetyNotes.join('\n'),
                        style: NepaliTypography.bodySmall.copyWith(
                          color: Colors.amber.shade900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Consent Prompt Card
            if (resp != null && resp.consentPromptRequired)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.privacy_tip_outlined, size: 18, color: Colors.purple.shade800),
                        const SizedBox(width: 8),
                        Text(
                          _isNepali ? 'क्लाउड एआई सहमति' : 'Cloud AI Consent',
                          style: NepaliTypography.titleSmall.copyWith(
                            color: Colors.purple.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isNepali
                          ? 'तपाईंको प्रश्नको विस्तृत र रचनात्मक जवाफ पाउन क्लाउड एआई अनुमति दिनुहोस्। नाम र व्यक्तिगत जानकारी सधैँ सुरक्षित र नामरहित बनाइन्छ।'
                          : 'To get creative advice from Cloud Gemini AI, explicit consent is required. Personal names and sensitive health info are automatically pseudonymized beforehand.',
                      style: NepaliTypography.bodySmall.copyWith(
                        color: Colors.purple.shade900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      key: const Key('enable_cloud_consent_button'),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: Text(
                        _isNepali ? 'क्लाउड एआई अनुमति दिनुहोस्' : 'Enable Cloud AI',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        setState(() {
                          widget.service.setCloudConsent(true);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isNepali
                                  ? 'क्लाउड एआई सक्रिय गरियो! अब प्रश्न पुनः सोध्न सक्नुहुन्छ।'
                                  : 'Cloud AI enabled! You can ask your question again.',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

            // Executable Action Buttons
            if (resp != null && resp.actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: resp.actions.map((act) {
                    final label = _isNepali && act.labelNe.isNotEmpty ? act.labelNe : act.labelEn;
                    final icon = _getActionIcon(act.type);
                    return OutlinedButton.icon(
                      key: Key('action_button_${act.type.name}_${act.recipeId ?? 'default'}'),
                      icon: Icon(icon, size: 16, color: SitiColors.terracotta),
                      label: Text(
                        label,
                        style: NepaliTypography.labelMedium.copyWith(
                          color: SitiColors.terracotta,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: SitiColors.terracotta, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _handleAction(act),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierBadge(AiRoutingTier tier) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (tier) {
      case AiRoutingTier.deterministic:
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade800;
        icon = Icons.bolt_rounded;
        label = _isNepali ? 'अफलाइन इन्जिन (Tier 1)' : 'Offline Engine (Tier 1)';
        break;
      case AiRoutingTier.onDevice:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        icon = Icons.phone_android_rounded;
        label = _isNepali ? 'डिभाइस एआई (Tier 2)' : 'On-Device AI (Tier 2)';
        break;
      case AiRoutingTier.cloudGemini:
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        icon = Icons.cloud_rounded;
        label = _isNepali ? 'क्लाउड जेमिनी (Tier 3)' : 'Cloud Gemini (Tier 3)';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: NepaliTypography.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(ActionType type) {
    switch (type) {
      case ActionType.cookNow:
        return Icons.soup_kitchen_rounded;
      case ActionType.addToPlan:
        return Icons.calendar_today_rounded;
      case ActionType.addToList:
        return Icons.shopping_basket_rounded;
      case ActionType.startTimer:
        return Icons.timer_rounded;
      case ActionType.viewRecipe:
        return Icons.menu_book_rounded;
    }
  }

  Widget _buildSuggestionChips() {
    final suggestions = _isNepali
        ? ['२ पाउ बराबर कति ग्राम?', 'काठमाडौँमा उम्लने तापक्रम?', 'दाल कति सिट्ठी लगाउने?']
        : ['How many grams in 2 pau?', 'Boiling point at Kathmandu altitude?', 'How long does cooked dal last?'];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final s = suggestions[index];
          return ActionChip(
            label: Text(s, style: NepaliTypography.bodySmall.copyWith(fontSize: 12)),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: () => _submitPrompt(s),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('ai_assistant_input_field'),
              controller: _inputController,
              decoration: InputDecoration(
                hintText: _isNepali ? 'प्रश्न सोध्नुहोस्...' : 'Ask about cooking, units, timers...',
                hintStyle: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: SitiColors.terracotta, width: 1.5),
                ),
              ),
              onSubmitted: _submitPrompt,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const Key('ai_assistant_send_button'),
            icon: const Icon(Icons.send_rounded, color: SitiColors.terracotta),
            onPressed: () => _submitPrompt(_inputController.text),
          ),
        ],
      ),
    );
  }
}
