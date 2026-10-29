/// Flutter Mobile Secure Secret Vault Abstraction (ADR-0037)
class MobileSecretVault {
  final String tenantId;
  final Map<String, String> _secrets = {};

  MobileSecretVault({required this.tenantId});

  void storeSecret(String key, String value) {
    if (key.isEmpty || value.isEmpty) {
      throw ArgumentError('Key and value must not be empty');
    }
    _secrets[key] = value;
  }

  String? getSecret(String key) => _secrets[key];

  bool hasSecret(String key) => _secrets.containsKey(key);

  String getMaskedPreview(String key) {
    final val = _secrets[key];
    if (val == null || val.isEmpty) return '';
    if (val.length <= 8) return '********';
    return '${val.substring(0, 4)}-****-${val.substring(val.length - 4)}';
  }
}

