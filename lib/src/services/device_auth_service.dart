import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class DeviceAuthSupport {
  const DeviceAuthSupport({
    required this.isAvailable,
    required this.hasBiometricOption,
  });

  const DeviceAuthSupport.unavailable()
    : isAvailable = false,
      hasBiometricOption = false;

  final bool isAvailable;
  final bool hasBiometricOption;
}

class DeviceAuthService {
  DeviceAuthService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  Future<DeviceAuthSupport> loadSupport() async {
    try {
      final bool isSupported = await _localAuthentication.isDeviceSupported();
      final bool canCheckBiometrics =
          await _localAuthentication.canCheckBiometrics;
      if (!isSupported && !canCheckBiometrics) {
        return const DeviceAuthSupport.unavailable();
      }
      final List<BiometricType> biometrics = canCheckBiometrics
          ? await _localAuthentication.getAvailableBiometrics()
          : const <BiometricType>[];
      return DeviceAuthSupport(
        isAvailable: isSupported || canCheckBiometrics,
        hasBiometricOption: biometrics.isNotEmpty,
      );
    } on PlatformException {
      return const DeviceAuthSupport.unavailable();
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return _localAuthentication.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (error) {
      throw FormatException(
        error.message ?? 'Device authentication is not available.',
      );
    }
  }
}
