import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/commerce/paywall_screen.dart';
import 'package:siti_counter/commerce/subscription_service.dart';

void main() {
  testWidgets('PaywallScreen renders Nepal PPP pricing, guarantees, and completes purchase',
      (tester) async {
    final service = SubscriptionService(
      householdId: 'household-ktm-001',
      countryCode: 'NP',
    );

    bool onSuccessCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PaywallScreen(
          subscriptionService: service,
          currentLanguage: 'ne',
          onSubscriptionSuccess: () => onSuccessCalled = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify title and localized Nepal price
    expect(find.text('सिट्ठी काउन्टर प्रिमियम'), findsOneWidget);
    expect(find.text('रु ९९९ / वर्ष'), findsOneWidget);

    // 2. Verify Free tier guarantee banner is visible
    expect(find.textContaining('सिट्ठी काउन्टर, आधारभूत रेसिपी र साप्ताहिक प्लान सधैं १००% निःशुल्क रहनेछ'),
        findsOneWidget);

    // 3. Verify premium features listed
    expect(find.text('असीमित एआई भान्सा सहायक'), findsOneWidget);
    expect(find.text('कालिमाटी दैनिक बजार भाउ'), findsOneWidget);
    expect(find.text('पार्टी मोड भोज प्लानर (१५-५० जना)'), findsOneWidget);

    // 4. Tap Subscribe button
    final subscribeBtn = find.text('७ दिन निःशुल्क सुरु गर्नुहोस्');
    expect(subscribeBtn, findsOneWidget);
    await tester.ensureVisible(subscribeBtn);
    await tester.tap(subscribeBtn);
    await tester.pump(); // Start async progress indicator

    // Advance time past simulated store delay (600ms)
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // 5. Verify entitlement is now premium
    expect(service.isPremium, isTrue);
    expect(onSuccessCalled, isTrue);
    expect(find.text('सदस्यता सक्रिय छ'), findsOneWidget);
    expect(find.textContaining('अफलाइन मान्य टोकन'), findsOneWidget);
  });

  testWidgets('PaywallScreen renders US pricing when countryCode is US and restores purchases',
      (tester) async {
    final service = SubscriptionService(
      householdId: 'household-nyc-002',
      countryCode: 'US',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PaywallScreen(
          subscriptionService: service,
          currentLanguage: 'en',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify US price
    expect(find.text(r'$14.99 / year'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);

    // 2. Tap Restore button
    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(service.isPremium, isTrue);
    expect(find.text('Subscription Active'), findsOneWidget);
  });
}
