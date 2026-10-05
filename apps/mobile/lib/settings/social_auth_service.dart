import 'dart:convert';
import 'dart:io';

/// Providers offered at sign-in.
enum SocialProvider {
  google('google', 'Google'),
  apple('apple', 'Apple'),
  facebook('facebook', 'Facebook');

  const SocialProvider(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static SocialProvider fromWire(String? value) {
    return SocialProvider.values.firstWhere(
      (p) => p.wireValue == value,
      orElse: () => SocialProvider.google,
    );
  }
}

/// Result of a successful sign-in.
class SocialSignInResult {
  final String accessToken;
  final String refreshToken;
  final String householdId;
  final String? email;
  final bool mergedFromGuest;

  const SocialSignInResult({
    required this.accessToken,
    required this.refreshToken,
    required this.householdId,
    this.email,
    this.mergedFromGuest = false,
  });

  factory SocialSignInResult.fromJson(Map<String, dynamic> json) {
    final tokens = (json['tokens'] ?? const {}) as Map<String, dynamic>;
    final user = (json['user'] ?? const {}) as Map<String, dynamic>;
    return SocialSignInResult(
      accessToken: tokens['accessToken'] as String? ?? '',
      refreshToken: tokens['refreshToken'] as String? ?? '',
      householdId: user['householdId'] as String? ?? '',
      email: user['email'] as String?,
      mergedFromGuest: json['mergedFromGuest'] as bool? ?? false,
    );
  }
}

/// Thrown when a provider is unavailable or the platform is not configured for it.
class SocialAuthUnavailable implements Exception {
  final SocialProvider provider;
  final String message;

  const SocialAuthUnavailable(this.provider, this.message);

  @override
  String toString() =>
      'SocialAuthUnavailable(${provider.wireValue}): $message';
}

/// Supplies a provider's freshly minted identity token.
///
/// Abstracted so the sign-in UI, the account merge and the API contract can all be built and
/// tested without the platform SDKs. Each provider's SDK call lives behind this interface;
/// the production implementations must return a token the API can verify, and the API
/// rejects anything it cannot verify, so a stub can never authenticate.
abstract class SocialAuthProvider {
  /// Whether this provider can be attempted on the current platform and build.
  ///
  /// False when the SDK is not linked or the provider is not configured, so the UI can hide
  /// the button rather than failing after the user taps it.
  bool isAvailable();

  /// Obtains an identity/access token by prompting the user.
  Future<String> requestToken();
}

/// Coordinates social sign-in against the API, and the guest -> account merge.
class SocialSignInService {
  final String apiBaseUrl;
  final Map<SocialProvider, SocialAuthProvider> providers;

  /// Resolved at sign-in time so a late attempt still sees current values. Async because
  /// both come from the local SQLite store.
  final Future<String?> Function()? deviceId;
  final Future<String?> Function()? guestHouseholdId;

  SocialSignInService({
    this.apiBaseUrl = 'https://api.siticounter.app',
    this.providers = const {},
    this.deviceId,
    this.guestHouseholdId,
  });

  /// Endpoint per provider.
  ///
  /// Google uses the token-verified route: the legacy `/v1/auth/google` trusts a
  /// client-supplied email, which would let anyone claim an existing account.
  static String endpointFor(SocialProvider provider) {
    switch (provider) {
      case SocialProvider.google:
        return '/v1/auth/google/verified';
      case SocialProvider.apple:
        return '/v1/auth/apple';
      case SocialProvider.facebook:
        return '/v1/auth/facebook';
    }
  }

  bool isAvailable(SocialProvider provider) =>
      providers[provider]?.isAvailable() ?? false;

  List<SocialProvider> get availableProviders =>
      SocialProvider.values.where(isAvailable).toList();

  /// Signs in, passing the current guest household so the API merges its data.
  ///
  /// The guest household is only cleared on success; if sign-in fails the local data and
  /// its identifier are left alone so nothing is orphaned.
  Future<SocialSignInResult> signIn(SocialProvider provider) async {
    final impl = providers[provider];
    if (impl == null || !impl.isAvailable()) {
      throw SocialAuthUnavailable(
        provider,
        '${provider.label} sign-in is not configured on this build.',
      );
    }

    final token = await impl.requestToken();
    if (token.isEmpty) {
      throw SocialAuthUnavailable(provider, 'No token was returned.');
    }

    final guestId = await guestHouseholdId?.call();

    final body = <String, dynamic>{};
    switch (provider) {
      case SocialProvider.google:
      case SocialProvider.apple:
        body[provider == SocialProvider.google ? 'idToken' : 'identityToken'] =
            token;
      case SocialProvider.facebook:
        body['accessToken'] = token;
    }
    if (guestId != null && guestId.isNotEmpty) {
      body['guestHouseholdId'] = guestId;
    }
    final id = await deviceId?.call();
    if (id != null && id.isNotEmpty) {
      body['deviceId'] = id;
    }

    final response = await _post(endpointFor(provider), body);
    return SocialSignInResult.fromJson(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$apiBaseUrl$path'));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(body));

      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();

      Map<String, dynamic> decoded;
      try {
        decoded = jsonDecode(text) as Map<String, dynamic>;
      } on FormatException {
        throw SocialAuthUnavailable(
          SocialProvider.values.first,
          'Unexpected response from the server.',
        );
      }

      if (response.statusCode >= 400) {
        throw SocialAuthException(
          decoded['error']?.toString() ?? 'HTTP_${response.statusCode}',
          decoded['message']?.toString() ?? 'Sign-in failed.',
        );
      }

      return decoded;
    } on SocketException {
      throw const SocialAuthUnavailable(
        SocialProvider.google,
        'Device is offline.',
      );
    } finally {
      client.close(force: true);
    }
  }
}

/// The server refused the provider's token.
class SocialAuthException implements Exception {
  final String code;
  final String message;

  const SocialAuthException(this.code, this.message);

  @override
  String toString() => 'SocialAuthException($code): $message';
}