import '../models/app_models.dart';

typedef TransportPayloadHandler =
    Future<TransportReceiveResult> Function(OfflineTransportPayload payload);
typedef TransportActivityHandler =
    void Function(TransportActivityNotice notice);

class TransportReceiveResult {
  const TransportReceiveResult({
    required this.accepted,
    required this.message,
  });

  final bool accepted;
  final String message;
}

class TransportActivityNotice {
  const TransportActivityNotice({
    required this.transport,
    required this.message,
  });

  final TransportKind transport;
  final String message;
}
