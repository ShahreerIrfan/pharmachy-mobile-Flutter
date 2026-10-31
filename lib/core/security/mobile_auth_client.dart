/// Mobile Authentication Client & Token Session
/// Architecture Decision: ADR-0043
/// Manages mobile client JWT authentication tokens, automatic refresh, and bilingual errors.
library mobile_auth_client;

import 'package:pharmacy_mobile_manager/core/security/mobile_user_identity_service.dart';

class MobileAuthTokens {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final DateTime issuedAt;
  final MobileUserIdentity user;

  MobileAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    required this.expiresIn,
    required this.issuedAt,
    required this.user,
  });

  bool get isExpired => DateTime.now()
      .toUtc()
      .isAfter(issuedAt.add(Duration(seconds: expiresIn - 30)));

  Map<String, dynamic> toJson() => {
        'access': accessToken,
        'refresh': refreshToken,
        'token_type': tokenType,
        'expires_in': expiresIn,
        'user': user.toJson(),
      };
}

class MobileAuthError {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  const MobileAuthError({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  bool get isClientSafe =>
      errorCode.isNotEmpty && messageEn.isNotEmpty && messageBn.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'error_code': errorCode,
        'message_en': messageEn,
        'message_bn': messageBn,
      };
}
