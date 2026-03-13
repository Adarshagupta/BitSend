import '../models/app_models.dart';

typedef EnvelopeHandler = Future<TransportReceiveResult> Function(OfflineEnvelope envelope);

class TransportReceiveResult {
  const TransportReceiveResult({
    required this.accepted,
    required this.message,
  });

  final bool accepted;
  final String message;
}
