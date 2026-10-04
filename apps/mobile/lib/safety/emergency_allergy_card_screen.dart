import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';

/// Screen presenting an offline, bilingual emergency allergy card for restaurants, travel, and emergencies.
class EmergencyAllergyCardScreen extends StatefulWidget {
  final EmergencyAllergyCard card;
  final String currentLanguage;

  const EmergencyAllergyCardScreen({
    super.key,
    required this.card,
    this.currentLanguage = 'ne',
  });

  @override
  State<EmergencyAllergyCardScreen> createState() => _EmergencyAllergyCardScreenState();
}

class _EmergencyAllergyCardScreenState extends State<EmergencyAllergyCardScreen> {
  bool _isFullscreenMode = false;

  bool get _isNepali => widget.currentLanguage == 'ne';

  void _copyCardText() {
    final markdown = widget.card.generateMarkdownCard();
    Clipboard.setData(ClipboardData(text: markdown));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isNepali ? 'अलर्जी कार्ड कपी गरियो' : 'Allergy card copied to clipboard',
        ),
        backgroundColor: SitiColors.terracotta,
      ),
    );
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreenMode = !_isFullscreenMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreenMode) {
      return Scaffold(
        backgroundColor: Colors.red.shade900,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                      onPressed: _toggleFullscreen,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SingleChildScrollView(
                      child: _buildCardContent(isHighContrast: true),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _toggleFullscreen,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(_isNepali ? 'बन्द गर्नुहोस्' : 'Exit Restaurant Mode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNepali ? 'आकस्मिक एलर्जी कार्ड' : 'Emergency Allergy Card',
          style: NepaliTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: _isNepali ? 'कार्ड कपी गर्नुहोस्' : 'Copy Card Text',
            onPressed: _copyCardText,
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen_rounded),
            tooltip: _isNepali ? 'रेस्टुरेन्ट पूर्ण स्क्रिन मोड' : 'Restaurant Mode',
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.offline_pin_rounded, color: Colors.blue.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isNepali
                          ? 'यो कार्ड १००% अफलाइन उपलब्ध छ। यात्रा र रेस्टुरेन्टमा देखाउनुहोस्।'
                          : '100% offline card. Show to restaurant servers or chefs when dining out.',
                        style: NepaliTypography.bodySmall.copyWith(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main emergency card container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.red.shade400, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: _buildCardContent(isHighContrast: false),
              ),
              const SizedBox(height: 20),

              // Action buttons: Copy & Fullscreen
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyCardText,
                      icon: const Icon(Icons.share_rounded),
                      label: Text(_isNepali ? 'कपी / सेयर' : 'Share / Copy'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleFullscreen,
                      icon: const Icon(Icons.restaurant_rounded),
                      label: Text(_isNepali ? 'रेस्टुरेन्ट मोड' : 'Restaurant Mode'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent({required bool isHighContrast}) {
    final c = widget.card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EMERGENCY ALLERGY CARD',
                    style: TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.red.shade900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'आकस्मिक एलर्जी कार्ड',
                    style: NepaliTypography.titleSmall.copyWith(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Member Name & Age
        Text(
          '${c.memberName}${c.memberAge != null ? ' (Age: ${c.memberAge})' : ''}',
          style: NepaliTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.w800,
            color: SitiColors.dark,
          ),
        ),
        const Divider(height: 24, thickness: 1.5),

        // Attention Chef Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ATTENTION CHEF / SERVER:',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'I have severe, life-threatening food allergies. Please ensure food, cookware, utensils, and surfaces do not come into contact with:',
                style: NepaliTypography.bodySmall.copyWith(
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...c.severeAllergens.map((allergen) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🛑 ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(
                            '${EmergencyAllergyCard.allergenNameEn(allergen)} (${EmergencyAllergyCard.allergenNameNe(allergen)})',
                            style: NepaliTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 10),
              Text(
                'शेफ / भान्से / वेटरको ध्यानाकर्षण:',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'मलाई माथि उल्लेखित परिकारबाट ज्यान जोखिममा पर्न सक्ने गम्भीर एलर्जी छ। कृपया खाना, भाँडा र तेल पटक्कै लसपस हुन नदिनुहोला।',
                style: NepaliTypography.bodySmall.copyWith(
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Hidden ingredients & cross-contact warnings
        if (c.hiddenSourceWarningsEn.isNotEmpty) ...[
          Text(
            _isNepali ? 'लुकेका सामग्रीहरू (Watch out for):' : 'Hidden Ingredients & Cross-Contact:',
            style: NepaliTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ...c.hiddenSourceWarningsEn.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.w700)),
                    Expanded(
                      child: Text(
                        w,
                        style: NepaliTypography.bodySmall.copyWith(color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
        ],

        // EpiPen Alert
        if (c.carriesEpiPen) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.purple.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.medication_rounded, color: Colors.purple.shade800, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CARRIES EPINEPHRINE (EpiPen)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Colors.purple.shade900,
                        ),
                      ),
                      Text(
                        _isNepali
                            ? 'सास फेर्न गाह्रो भएमा तुरुन्त बाहिरी तिघ्रामा एपिपेन इन्जेक्सन दिनुहोस् र एम्बुलेन्स (१०२) बोलाउनुहोस्।'
                            : 'If anaphylaxis occurs, inject into outer thigh immediately and call emergency ambulance (102 / 911).',
                        style: NepaliTypography.bodySmall.copyWith(
                          color: Colors.purple.shade900,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Emergency Contacts
        if (c.emergencyContacts.isNotEmpty) ...[
          Text(
            _isNepali ? 'आकस्मिक सम्पर्क (Emergency Contacts):' : 'Emergency Contacts:',
            style: NepaliTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...c.emergencyContacts.map((contact) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${contact.name} (${contact.relationship})',
                          style: NepaliTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          contact.phone,
                          style: NepaliTypography.bodySmall.copyWith(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone_rounded, color: Colors.green),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: contact.phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Phone number ${contact.phone} copied'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              )),
        ],

        // Doctor info
        if (c.doctorName != null) ...[
          const SizedBox(height: 8),
          Text(
            'Physician / चिकित्सक: ${c.doctorName}${c.doctorPhone != null ? ' (${c.doctorPhone})' : ''}',
            style: NepaliTypography.labelSmall.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }
}
