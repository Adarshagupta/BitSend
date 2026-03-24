import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HomeScreenWidgetSnapshot {
  const HomeScreenWidgetSnapshot({
    required this.chainLabel,
    required this.networkLabel,
    required this.primaryValue,
    required this.supportingLabel,
    required this.primaryDetail,
    required this.secondaryDetail,
    required this.statusLabel,
    required this.statusTone,
    required this.walletLabel,
  });

  final String chainLabel;
  final String networkLabel;
  final String primaryValue;
  final String supportingLabel;
  final String primaryDetail;
  final String secondaryDetail;
  final String statusLabel;
  final String statusTone;
  final String walletLabel;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'chainLabel': chainLabel,
      'networkLabel': networkLabel,
      'primaryValue': primaryValue,
      'supportingLabel': supportingLabel,
      'primaryDetail': primaryDetail,
      'secondaryDetail': secondaryDetail,
      'statusLabel': statusLabel,
      'statusTone': statusTone,
      'walletLabel': walletLabel,
    };
  }
}

class HomeScreenWidgetService {
  HomeScreenWidgetService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName) {
    if (!kIsWeb) {
      _channel.setMethodCallHandler(_handleMethodCall);
    }
  }

  static const String _channelName = 'bitsend/home_widget';

  final MethodChannel _channel;
  final StreamController<String> _launchRoutesController =
      StreamController<String>.broadcast();

  Stream<String> get launchRoutes => _launchRoutesController.stream;

  Future<void> syncSnapshot(HomeScreenWidgetSnapshot snapshot) async {
    if (kIsWeb) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('syncWidgets', snapshot.toMap());
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<String?> consumePendingLaunchRoute() async {
    if (kIsWeb) {
      return null;
    }
    try {
      final String? route = await _channel.invokeMethod<String>(
        'consumeLaunchRoute',
      );
      if (route == null || route.trim().isEmpty) {
        return null;
      }
      return route;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'widgetLaunchRoute') {
      return;
    }
    final String? route = call.arguments as String?;
    if (route == null || route.trim().isEmpty) {
      return;
    }
    _launchRoutesController.add(route);
  }
}
