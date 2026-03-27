import 'storage_service.dart';

enum ContractType {
  serviceAgreement('service_agreement'),
  nurseOnboarding('nurse_onboarding');

  final String value;
  const ContractType(this.value);
}

class ContractService {
  ContractService._();

  static final ContractService instance = ContractService._();

  String _key(ContractType type, int userId) =>
      'contract_${type.value}_user_$userId';

  Future<void> sign({
    required ContractType type,
    required int userId,
    required String signer,
  }) async {
    final now = DateTime.now().toIso8601String();
    await StorageService.instance.saveCache(_key(type, userId), {
      'signed': true,
      'signer': signer,
      'signedAt': now,
    });
  }

  Map<String, dynamic>? getSignature({
    required ContractType type,
    required int userId,
  }) {
    final raw = StorageService.instance.getCache(_key(type, userId));
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  bool hasSigned({required ContractType type, required int userId}) {
    final data = getSignature(type: type, userId: userId);
    return data?['signed'] == true;
  }
}
