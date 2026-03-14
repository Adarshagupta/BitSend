import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/app/app.dart';
import 'src/state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final BitsendAppState appState = BitsendAppState();

  FlutterError.onError = FlutterError.presentError;

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FlutterError.presentError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'bitsend',
        context: ErrorDescription('while handling an uncaught platform error'),
      ),
    );
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _CompactErrorWidget(details: details);
  };

  runApp(BitsendApp(appState: appState));
}

class _CompactErrorWidget extends StatelessWidget {
  const _CompactErrorWidget({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final String message = kReleaseMode
        ? 'Something went wrong. Try that action again.'
        : details.exceptionAsString();

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF251313),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE18C7A)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.35,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFFC6B8),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'UI error',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
