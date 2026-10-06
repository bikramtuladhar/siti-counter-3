import 'package:flutter/material.dart';

import '../onboarding/language_toggle.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';
import 'social_auth_service.dart';
import '../telemetry/error_reporter.dart';

/// Offered at the end of onboarding, so a household's data lands in an account from the
/// start rather than having to migrate later.
///
/// Signing in passes the current guest household, and the API merges its synced entities
/// into the account, so nothing configured during onboarding is lost. The guest option stays
/// available: cooking must never be gated behind an account.
class SocialSignInSheet extends StatefulWidget {
  final SocialSignInService signInService;
  final bool preferNepali;

  /// Raised when the user switches language, so the caller can re-render the whole flow.
  final ValueChanged<bool>? onLanguageChanged;

  /// Called after a successful sign-in, with the account's household.
  final ValueChanged<SocialSignInResult>? onSignedIn;

  /// Called when the user chooses to keep using the app without an account.
  final VoidCallback? onContinueAsGuest;

  const SocialSignInSheet({
    super.key,
    required this.signInService,
    this.preferNepali = true,
    this.onLanguageChanged,
    this.onSignedIn,
    this.onContinueAsGuest,
  });

  @override
  State<SocialSignInSheet> createState() => _SocialSignInSheetState();
}

class _SocialSignInSheetState extends State<SocialSignInSheet> {
  SocialProvider? _busy;
  String? _error;

  bool get _isNe => widget.preferNepali;

  Future<void> _signIn(SocialProvider provider) async {
    setState(() {
      _busy = provider;
      _error = null;
    });

    try {
      final result = await widget.signInService.signIn(provider);
      if (!mounted) return;
      widget.onSignedIn?.call(result);
    } on SocialAuthUnavailable catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on SocialAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e, st) {
      if (!mounted) return;
      // A friendly message on screen; the exception detail goes to the scrubbed reporter.
      // Showing e.toString() leaked PlatformException internals into the UI.
      reportError(e, st, reason: 'social_sign_in.failed');
      setState(() => _error = _isNe
          ? 'साइन इन गर्न सकिएन। कृपया पुनः प्रयास गर्नुहोस्।'
          : 'Could not sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.signInService.availableProviders;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _isNe ? 'खाता बनाउनुहोस्' : 'Create your account',
                    style: NepaliTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: SitiColors.dark,
                    ),
                  ),
                ),
                LanguageToggle(
                  compact: true,
                  language: _isNe ? 'ne' : 'en',
                  onChanged: (code) => widget.onLanguageChanged?.call(code == 'ne'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isNe
                  ? 'खाता बनाएर आफ्ना योजना, किनारी र सिट्ठी इतिहास सुरक्षित रहन्छ। अहिलेकै जोडिन्छ भने तपाईंले हालसम्म गरेको सबै कुरा जोडिन्छ।'
                  : 'Keep your plans, groceries and whistle history safe. Sign in now and everything you have set up so far comes with you.',
              style: NepaliTypography.bodyMedium.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),

            if (available.isEmpty)
              _NoticeCard(
                text: _isNe
                    ? 'यस यन्त्रमा सोशल साइन इन मिल्दैन। अतिथि रूपमा जारी राख्नुहोस्।'
                    : 'Social sign-in is not available in this build. You can continue as a guest.',
              )
            else
              ...available.map(
                (provider) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProviderButton(
                    provider: provider,
                    isNepali: _isNe,
                    isBusy: _busy == provider,
                    isDisabled: _busy != null && _busy != provider,
                    onTap: () => _signIn(provider),
                  ),
                ),
              ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              _NoticeCard(text: _error!, isError: true),
            ],

            const SizedBox(height: 12),
            TextButton(
              key: const Key('continue_as_guest_button'),
              onPressed: _busy != null
                  ? null
                  : () => widget.onContinueAsGuest?.call(),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: Colors.grey.shade800,
              ),
              child: Text(
                _isNe ? 'अहिले अतिथि रूपमा जारी राख्नुहोस्' : 'Continue as guest for now',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final SocialProvider provider;
  final bool isNepali;
  final bool isBusy;
  final bool isDisabled;
  final VoidCallback onTap;

  const _ProviderButton({
    required this.provider,
    required this.isNepali,
    required this.isBusy,
    required this.isDisabled,
    required this.onTap,
  });

  IconData get _icon {
    switch (provider) {
      case SocialProvider.google:
        return Icons.g_mobiledata_rounded;
      case SocialProvider.apple:
        return Icons.apple_rounded;
      case SocialProvider.facebook:
        return Icons.facebook_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: Key('sign_in_${provider.wireValue}'),
      onPressed: isDisabled ? null : onTap,
      icon: isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_icon, size: 20),
      label: Text(
        isNepali ? '${provider.label} मा जारी राख्नुहोस्' : 'Continue with ${provider.label}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: SitiColors.dark,
        side: BorderSide(color: Colors.grey.shade400),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String text;
  final bool isError;

  const _NoticeCard({required this.text, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final background = isError
        ? SitiColors.alert.withValues(alpha: 0.08)
        : Colors.grey.shade100;
    final border = isError ? SitiColors.alert : Colors.grey.shade300;

    return Container(
      key: Key(isError ? 'sign_in_error' : 'sign_in_notice'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 18,
            color: isError ? SitiColors.alert : Colors.grey.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: NepaliTypography.bodySmall.copyWith(
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}