import '../models/app_models.dart';

typedef EnvelopeHandler = Future<TransportReceiveResult> Function(OfflineEnvelope envelope);
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
