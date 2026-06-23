import 'dart:async';
import 'package:dio/dio.dart';

/// Google OAuth2 Device Authorization Grant for GKE clusters.
///
/// Flow:
/// 1. App requests a device code from Google
/// 2. User visits a URL and enters the code on their browser
/// 3. App polls until the user approves
/// 4. App receives an access token to use as K8s bearer token
class GcpDeviceAuth {
  GcpDeviceAuth({
    required this.clientId,
    this.clientSecret,
  }) : _dio = Dio();

  final String clientId;
  final String? clientSecret;
  final Dio _dio;

  // Google Cloud's K8s Engine scope
  static const _scopes = 'https://www.googleapis.com/auth/cloud-platform';
  static const _deviceCodeUrl =
      'https://oauth2.googleapis.com/device/code';
  static const _tokenUrl = 'https://oauth2.googleapis.com/token';

  /// Step 1: Request a device code. Returns the verification URI and user code.
  Future<DeviceCodeResponse> requestDeviceCode() async {
    final response = await _dio.post(
      _deviceCodeUrl,
      data: {
        'client_id': clientId,
        'scope': _scopes,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final data = response.data as Map<String, dynamic>;
    return DeviceCodeResponse(
      deviceCode: data['device_code'] as String,
      userCode: data['user_code'] as String,
      verificationUrl: data['verification_url'] as String,
      expiresIn: data['expires_in'] as int,
      interval: data['interval'] as int? ?? 5,
    );
  }

  /// Step 2: Poll for the token after the user has approved.
  /// Returns the access token when approved, or throws on timeout/denial.
  Future<GcpTokenResponse> pollForToken(DeviceCodeResponse deviceCode) async {
    final deadline =
        DateTime.now().add(Duration(seconds: deviceCode.expiresIn));
    final interval = Duration(seconds: deviceCode.interval);

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(interval);

      try {
        final response = await _dio.post(
          _tokenUrl,
          data: {
            'client_id': clientId,
            if (clientSecret != null) 'client_secret': clientSecret,
            'device_code': deviceCode.deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );

        final data = response.data as Map<String, dynamic>;

        if (data.containsKey('access_token')) {
          return GcpTokenResponse(
            accessToken: data['access_token'] as String,
            refreshToken: data['refresh_token'] as String?,
            expiresIn: data['expires_in'] as int? ?? 3600,
            tokenType: data['token_type'] as String? ?? 'Bearer',
          );
        }
      } on DioException catch (e) {
        final errorData = e.response?.data;
        if (errorData is Map<String, dynamic>) {
          final error = errorData['error'] as String?;
          if (error == 'authorization_pending') continue;
          if (error == 'slow_down') {
            await Future.delayed(const Duration(seconds: 5));
            continue;
          }
          if (error == 'access_denied') {
            throw GcpAuthException('User denied access');
          }
          if (error == 'expired_token') {
            throw GcpAuthException('Device code expired');
          }
        }
      }
    }

    throw GcpAuthException('Device code expired — user did not approve in time');
  }

  /// Refresh an expired access token using the refresh token.
  Future<GcpTokenResponse> refreshAccessToken(String refreshToken) async {
    final response = await _dio.post(
      _tokenUrl,
      data: {
        'client_id': clientId,
        if (clientSecret != null) 'client_secret': clientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final data = response.data as Map<String, dynamic>;
    return GcpTokenResponse(
      accessToken: data['access_token'] as String,
      refreshToken: refreshToken,
      expiresIn: data['expires_in'] as int? ?? 3600,
      tokenType: data['token_type'] as String? ?? 'Bearer',
    );
  }

  void dispose() {
    _dio.close();
  }
}

class DeviceCodeResponse {
  const DeviceCodeResponse({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.expiresIn,
    this.interval = 5,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUrl;
  final int expiresIn;
  final int interval;
}

class GcpTokenResponse {
  const GcpTokenResponse({
    required this.accessToken,
    this.refreshToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
  });

  final String accessToken;
  final String? refreshToken;
  final int expiresIn;
  final String tokenType;

  DateTime get expiresAt =>
      DateTime.now().add(Duration(seconds: expiresIn));

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        if (refreshToken != null) 'refreshToken': refreshToken,
        'expiresIn': expiresIn,
        'tokenType': tokenType,
      };

  factory GcpTokenResponse.fromJson(Map<String, dynamic> json) =>
      GcpTokenResponse(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        expiresIn: json['expiresIn'] as int? ?? 3600,
        tokenType: json['tokenType'] as String? ?? 'Bearer',
      );
}

class GcpAuthException implements Exception {
  const GcpAuthException(this.message);
  final String message;

  @override
  String toString() => 'GcpAuthException: $message';
}
