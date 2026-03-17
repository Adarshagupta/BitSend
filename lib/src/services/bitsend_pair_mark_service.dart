import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

class BitsendPairMarkService {
  const BitsendPairMarkService();

  static const int gridSize = 29;
  static const int markerSize = 5;
  static const int maxPayloadBytes = 87;
  static const List<int> amberMarker = <int>[242, 169, 56];
  static const List<int> blueMarker = <int>[51, 112, 232];
  static const List<int> emeraldMarker = <int>[31, 138, 97];
  static const List<int> coralMarker = <int>[223, 108, 70];

  List<List<bool>> encodePayload(Uint8List payloadBytes) {
    final Uint8List framed = _framePayload(payloadBytes);
    final List<bool> bits = _bytesToBits(framed);
    final List<List<bool>> matrix = List<List<bool>>.generate(
      gridSize,
      (_) => List<bool>.filled(gridSize, false),
      growable: false,
    );
    int bitIndex = 0;
    for (int y = 0; y < gridSize; y += 1) {
      for (int x = 0; x < gridSize; x += 1) {
        if (_isMarkerCell(x, y)) {
          continue;
        }
        matrix[y][x] = bitIndex < bits.length ? bits[bitIndex] : false;
        bitIndex += 1;
      }
    }
    return matrix;
  }

  Uint8List decodeImageBytes(Uint8List imageBytes) {
    final img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('Unable to decode the captured pair photo.');
    }
    final img.Image image = decoded.width > 1200
        ? img.copyResize(decoded, width: 1200)
        : decoded;

    final _Point? amber = _findMarkerCentroid(image, amberMarker);
    final _Point? blue = _findMarkerCentroid(image, blueMarker);
    final _Point? emerald = _findMarkerCentroid(image, emeraldMarker);
    final _Point? coral = _findMarkerCentroid(image, coralMarker);
    if (amber == null || blue == null || emerald == null || coral == null) {
      throw const FormatException(
        'Bitsend Pair markers were not detected. Fill the camera frame and try again.',
      );
    }

    final _Quad quad = _quadFromMarkers(
      topLeftMarker: amber,
      topRightMarker: blue,
      bottomLeftMarker: emerald,
      bottomRightMarker: coral,
    );

    final List<double> luminances = <double>[];
    final List<_CellSample> samples = <_CellSample>[];
    final double sampleRadius =
        math.max(2, math.min(image.width, image.height) / 220);

    for (int y = 0; y < gridSize; y += 1) {
      for (int x = 0; x < gridSize; x += 1) {
        if (_isMarkerCell(x, y)) {
          continue;
        }
        final double u = (x + 0.5) / gridSize;
        final double v = (y + 0.5) / gridSize;
        final _Point point = quad.map(u, v);
        final double luminance = _sampleLuminance(
          image,
          point,
          sampleRadius,
        );
        luminances.add(luminance);
        samples.add(_CellSample(x: x, y: y, luminance: luminance));
      }
    }

    final double threshold = _luminanceThreshold(luminances);
    final List<bool> bits = samples
        .map((sample) => sample.luminance < threshold)
        .toList(growable: false);
    final Uint8List framed = _bitsToBytes(bits);
    if (framed.isEmpty) {
      throw const FormatException('Captured pair mark did not contain data.');
    }
    final int payloadLength = framed.first;
    if (payloadLength <= 0 || payloadLength > maxPayloadBytes) {
      throw const FormatException('Captured pair mark payload length is invalid.');
    }
    if (framed.length < 1 + payloadLength + 4) {
      throw const FormatException('Captured pair mark data is truncated.');
    }
    final Uint8List payload = Uint8List.sublistView(
      framed,
      1,
      1 + payloadLength,
    );
    final Uint8List checksum = Uint8List.sublistView(
      framed,
      1 + payloadLength,
      1 + payloadLength + 4,
    );
    final Uint8List expected = Uint8List.fromList(
      sha256.convert(payload).bytes.sublist(0, 4),
    );
    if (!_listEquals(checksum, expected)) {
      throw const FormatException(
        'Captured pair mark checksum failed. Try another photo.',
      );
    }
    return Uint8List.fromList(payload);
  }

  Uint8List _framePayload(Uint8List payloadBytes) {
    if (payloadBytes.isEmpty) {
      throw const FormatException('Bitsend Pair payload cannot be empty.');
    }
    if (payloadBytes.length > maxPayloadBytes) {
      throw const FormatException('Bitsend Pair payload is too large.');
    }
    return Uint8List.fromList(<int>[
      payloadBytes.length,
      ...payloadBytes,
      ...sha256.convert(payloadBytes).bytes.sublist(0, 4),
    ]);
  }

  bool _isMarkerCell(int x, int y) {
    final bool top = y < markerSize;
    final bool left = x < markerSize;
    final bool right = x >= gridSize - markerSize;
    final bool bottom = y >= gridSize - markerSize;
    return (top && left) ||
        (top && right) ||
        (bottom && left) ||
        (bottom && right);
  }

  List<bool> _bytesToBits(Uint8List bytes) {
    final List<bool> bits = <bool>[];
    for (final int value in bytes) {
      for (int bit = 7; bit >= 0; bit -= 1) {
        bits.add(((value >> bit) & 1) == 1);
      }
    }
    return bits;
  }

  Uint8List _bitsToBytes(List<bool> bits) {
    final int byteCount = bits.length ~/ 8;
    final Uint8List bytes = Uint8List(byteCount);
    for (int index = 0; index < byteCount; index += 1) {
      int value = 0;
      for (int bit = 0; bit < 8; bit += 1) {
        if (bits[index * 8 + bit]) {
          value |= 1 << (7 - bit);
        }
      }
      bytes[index] = value;
    }
    return bytes;
  }

  _Point? _findMarkerCentroid(img.Image image, List<int> targetColor) {
    final int step = math.max(1, math.min(image.width, image.height) ~/ 320);
    double totalX = 0;
    double totalY = 0;
    int count = 0;
    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < image.width; x += step) {
        final img.Pixel pixel = image.getPixel(x, y);
        final double distance = _rgbDistance(
          pixel.r.toDouble(),
          pixel.g.toDouble(),
          pixel.b.toDouble(),
          targetColor[0].toDouble(),
          targetColor[1].toDouble(),
          targetColor[2].toDouble(),
        );
        final double saturation =
            math.max(pixel.r.toDouble(), math.max(pixel.g.toDouble(), pixel.b.toDouble())) -
            math.min(pixel.r.toDouble(), math.min(pixel.g.toDouble(), pixel.b.toDouble()));
        if (distance < 76 && saturation > 28) {
          totalX += x;
          totalY += y;
          count += 1;
        }
      }
    }
    if (count < 18) {
      return null;
    }
    return _Point(totalX / count, totalY / count);
  }

  _Quad _quadFromMarkers({
    required _Point topLeftMarker,
    required _Point topRightMarker,
    required _Point bottomLeftMarker,
    required _Point bottomRightMarker,
  }) {
    const double markerCenterOffset = 2.0 / 24.0;
    final _Point topLeftOuter = topLeftMarker
        .subtract(topRightMarker.subtract(topLeftMarker).scale(markerCenterOffset))
        .subtract(bottomLeftMarker.subtract(topLeftMarker).scale(markerCenterOffset));
    final _Point topRightOuter = topRightMarker
        .add(topRightMarker.subtract(topLeftMarker).scale(markerCenterOffset))
        .subtract(bottomRightMarker.subtract(topRightMarker).scale(markerCenterOffset));
    final _Point bottomLeftOuter = bottomLeftMarker
        .subtract(bottomRightMarker.subtract(bottomLeftMarker).scale(markerCenterOffset))
        .add(bottomLeftMarker.subtract(topLeftMarker).scale(markerCenterOffset));
    final _Point bottomRightOuter = bottomRightMarker
        .add(bottomRightMarker.subtract(bottomLeftMarker).scale(markerCenterOffset))
        .add(bottomRightMarker.subtract(topRightMarker).scale(markerCenterOffset));
    return _Quad(
      topLeft: topLeftOuter,
      topRight: topRightOuter,
      bottomLeft: bottomLeftOuter,
      bottomRight: bottomRightOuter,
    );
  }

  double _sampleLuminance(img.Image image, _Point point, double radius) {
    final int left = math.max(0, (point.x - radius).floor());
    final int top = math.max(0, (point.y - radius).floor());
    final int right = math.min(image.width - 1, (point.x + radius).ceil());
    final int bottom = math.min(image.height - 1, (point.y + radius).ceil());
    double total = 0;
    int count = 0;
    final double radiusSquared = radius * radius;
    for (int y = top; y <= bottom; y += 1) {
      for (int x = left; x <= right; x += 1) {
        final double dx = x - point.x;
        final double dy = y - point.y;
        if (dx * dx + dy * dy > radiusSquared) {
          continue;
        }
        final img.Pixel pixel = image.getPixel(x, y);
        total += pixel.luminanceNormalized;
        count += 1;
      }
    }
    return count == 0 ? 1 : total / count;
  }

  double _luminanceThreshold(List<double> values) {
    final List<double> sorted = List<double>.from(values)..sort();
    final double low = sorted[(sorted.length * 0.2).floor()];
    final double high = sorted[(sorted.length * 0.8).floor()];
    return (low + high) / 2;
  }

  double _rgbDistance(
    double r1,
    double g1,
    double b1,
    double r2,
    double g2,
    double b2,
  ) {
    final double dr = r1 - r2;
    final double dg = g1 - g2;
    final double db = b1 - b2;
    return math.sqrt(dr * dr + dg * dg + db * db);
  }
}

class _Quad {
  const _Quad({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  final _Point topLeft;
  final _Point topRight;
  final _Point bottomLeft;
  final _Point bottomRight;

  _Point map(double u, double v) {
    final _Point top = _Point.lerp(topLeft, topRight, u);
    final _Point bottom = _Point.lerp(bottomLeft, bottomRight, u);
    return _Point.lerp(top, bottom, v);
  }
}

class _Point {
  const _Point(this.x, this.y);

  final double x;
  final double y;

  _Point add(_Point other) => _Point(x + other.x, y + other.y);

  _Point subtract(_Point other) => _Point(x - other.x, y - other.y);

  _Point scale(double factor) => _Point(x * factor, y * factor);

  static _Point lerp(_Point left, _Point right, double t) {
    return _Point(
      left.x + (right.x - left.x) * t,
      left.y + (right.y - left.y) * t,
    );
  }
}

class _CellSample {
  const _CellSample({
    required this.x,
    required this.y,
    required this.luminance,
  });

  final int x;
  final int y;
  final double luminance;
}

bool _listEquals(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (int index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
