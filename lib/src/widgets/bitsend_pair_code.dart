import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../services/bitsend_pair_mark_service.dart';

class BitsendPairMarkView extends StatelessWidget {
  BitsendPairMarkView({
    super.key,
    required this.payloadBytes,
    this.size = 220,
    this.semanticsLabel = 'Bitsend Pair code',
  }) : _matrix = const BitsendPairMarkService().encodePayload(payloadBytes);

  final Uint8List payloadBytes;
  final double size;
  final String semanticsLabel;
  final List<List<bool>> _matrix;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      image: true,
      label: semanticsLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _BitsendPairMarkPainter(_matrix),
        ),
      ),
    );
  }
}

class BitsendPairCodeView extends StatelessWidget {
  const BitsendPairCodeView({
    super.key,
    required this.data,
    this.size = 220,
    this.semanticsLabel = 'Bitsend Pair code',
  });

  final String data;
  final double size;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final _BitsendPairVisualSeed seed = _BitsendPairVisualSeed.fromData(data);
    final String fingerprint = _hexFingerprint(seed.bytes);
    final double coreSize = size * 0.56;
    return Semantics(
      container: true,
      image: true,
      label: semanticsLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CustomPaint(
              size: Size.square(size),
              painter: _BitsendPairPainter(seed),
            ),
            Container(
              width: coreSize,
              height: coreSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(coreSize * 0.28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.98),
                    seed.highlight.withValues(alpha: 0.18),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.92),
                  width: 2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: seed.primary.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(coreSize * 0.2),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: coreSize * 0.14,
                    vertical: coreSize * 0.12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: coreSize * 0.34,
                        height: coreSize * 0.34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              seed.primary.withValues(alpha: 0.92),
                              seed.secondary.withValues(alpha: 0.84),
                            ],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: seed.primary.withValues(alpha: 0.2),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.link_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'courier',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.ink,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.canvasWarm,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: seed.highlight.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Text(
                          fingerprint,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.ink,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BitsendPairMarkPainter extends CustomPainter {
  const _BitsendPairMarkPainter(this.matrix);

  final List<List<bool>> matrix;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final double outerRadius = size.shortestSide * 0.14;
    final RRect shell = RRect.fromRectAndRadius(
      bounds.deflate(size.shortestSide * 0.02),
      Radius.circular(outerRadius),
    );
    final Paint base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white,
          AppColors.canvasWarm,
          AppColors.blueTint.withValues(alpha: 0.5),
        ],
      ).createShader(bounds);
    canvas.drawRRect(shell, base);

    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.ink.withValues(alpha: 0.08);
    canvas.drawRRect(shell, border);

    final Rect panel = bounds.deflate(size.shortestSide * 0.1);
    final double cellSize = panel.width / BitsendPairMarkService.gridSize;
    final Paint guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.line.withValues(alpha: 0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, Radius.circular(size.shortestSide * 0.08)),
      guide,
    );

    final double dotRadius = cellSize * 0.22;
    final Paint offDot = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.line.withValues(alpha: 0.24);
    final Paint onDot = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.ink;

    for (int y = 0; y < BitsendPairMarkService.gridSize; y += 1) {
      for (int x = 0; x < BitsendPairMarkService.gridSize; x += 1) {
        if (_isMarkerCell(x, y)) {
          continue;
        }
        final Offset center = Offset(
          panel.left + (x + 0.5) * cellSize,
          panel.top + (y + 0.5) * cellSize,
        );
        canvas.drawCircle(center, dotRadius, matrix[y][x] ? onDot : offDot);
      }
    }

    _paintMarker(
      canvas,
      panel,
      cellSize,
      const Color.fromARGB(255, 242, 169, 56),
      Alignment.topLeft,
    );
    _paintMarker(
      canvas,
      panel,
      cellSize,
      const Color.fromARGB(255, 51, 112, 232),
      Alignment.topRight,
    );
    _paintMarker(
      canvas,
      panel,
      cellSize,
      const Color.fromARGB(255, 31, 138, 97),
      Alignment.bottomLeft,
    );
    _paintMarker(
      canvas,
      panel,
      cellSize,
      const Color.fromARGB(255, 223, 108, 70),
      Alignment.bottomRight,
    );

    final Paint orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2
      ..color = AppColors.amber.withValues(alpha: 0.22);
    canvas.drawArc(
      Rect.fromCenter(
        center: bounds.center,
        width: size.width * 0.9,
        height: size.height * 0.9,
      ),
      -0.2,
      0.8,
      false,
      orbit,
    );
    orbit.color = AppColors.blue.withValues(alpha: 0.18);
    canvas.drawArc(
      Rect.fromCenter(
        center: bounds.center,
        width: size.width * 0.78,
        height: size.height * 0.78,
      ),
      2.7,
      0.65,
      false,
      orbit,
    );
  }

  void _paintMarker(
    Canvas canvas,
    Rect panel,
    double cellSize,
    Color color,
    Alignment alignment,
  ) {
    final double markerSize =
        cellSize * BitsendPairMarkService.markerSize;
    final Offset center = alignment.withinRect(
      Rect.fromLTWH(
        panel.left + markerSize / 2,
        panel.top + markerSize / 2,
        panel.width - markerSize,
        panel.height - markerSize,
      ),
    );
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.9
      ..color = color.withValues(alpha: 0.95);
    canvas.drawCircle(center, markerSize * 0.34, ring);
    final Paint inner = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.ink;
    canvas.drawCircle(center, markerSize * 0.12, inner);
    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.32
      ..color = color.withValues(alpha: 0.24);
    canvas.drawCircle(center, markerSize * 0.52, glow);
  }

  bool _isMarkerCell(int x, int y) {
    final bool top = y < BitsendPairMarkService.markerSize;
    final bool left = x < BitsendPairMarkService.markerSize;
    final bool right =
        x >= BitsendPairMarkService.gridSize - BitsendPairMarkService.markerSize;
    final bool bottom =
        y >= BitsendPairMarkService.gridSize - BitsendPairMarkService.markerSize;
    return (top && left) ||
        (top && right) ||
        (bottom && left) ||
        (bottom && right);
  }

  @override
  bool shouldRepaint(covariant _BitsendPairMarkPainter oldDelegate) {
    return oldDelegate.matrix != matrix;
  }
}

class _BitsendPairVisualSeed {
  const _BitsendPairVisualSeed({
    required this.primary,
    required this.secondary,
    required this.highlight,
    required this.bytes,
  });

  factory _BitsendPairVisualSeed.fromData(String data) {
    final Uint8List bytes = Uint8List.fromList(
      sha256.convert(utf8.encode(data)).bytes,
    );
    const List<Color> palette = <Color>[
      AppColors.emerald,
      AppColors.blue,
      AppColors.amber,
      Color(0xFF0E9C97),
      Color(0xFFDF6C46),
    ];
    final Color primary = palette[bytes[0] % palette.length];
    final Color secondary = palette[(bytes[3] + 2) % palette.length];
    final Color highlight = palette[(bytes[9] + 1) % palette.length];
    return _BitsendPairVisualSeed(
      primary: primary,
      secondary: secondary,
      highlight: highlight,
      bytes: bytes,
    );
  }

  final Color primary;
  final Color secondary;
  final Color highlight;
  final Uint8List bytes;
}

class _BitsendPairPainter extends CustomPainter {
  const _BitsendPairPainter(this.seed);

  final _BitsendPairVisualSeed seed;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    final Rect circleBounds = Rect.fromCircle(center: center, radius: radius);

    final Paint base = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.98),
          AppColors.canvasWarm,
          seed.primary.withValues(alpha: 0.08),
        ],
        stops: const <double>[0.08, 0.72, 1],
      ).createShader(circleBounds);
    canvas.drawCircle(center, radius, base);

    final Paint outerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.ink.withValues(alpha: 0.08);
    canvas.drawCircle(center, radius - 1, outerRing);

    final List<double> radii = <double>[
      radius * 0.9,
      radius * 0.78,
      radius * 0.66,
    ];
    for (int ringIndex = 0; ringIndex < radii.length; ringIndex += 1) {
      final double ringRadius = radii[ringIndex];
      final Paint ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = ringIndex == 0 ? 3 : 2.2;
      final int segmentCount = 3 + seed.bytes[ringIndex] % 3;
      final double startOffset =
          seed.bytes[ringIndex + 5] / 255 * math.pi * 2;
      for (int index = 0; index < segmentCount; index += 1) {
        final double start = startOffset + index * (math.pi * 2 / segmentCount);
        final double sweep = 0.42 + (seed.bytes[ringIndex + index + 8] / 255) * 0.4;
        ringPaint.color = (index.isEven ? seed.primary : seed.secondary)
            .withValues(alpha: 0.18 + 0.16 * (ringIndex + 1));
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: ringRadius),
          start,
          sweep,
          false,
          ringPaint,
        );
      }
    }

    final Paint dotPaint = Paint()..style = PaintingStyle.fill;
    final int dotCount = 18;
    for (int index = 0; index < dotCount; index += 1) {
      final double angle =
          (math.pi * 2 / dotCount) * index + seed.bytes[index] / 255;
      final double distance =
          radius * (0.82 + (seed.bytes[index + 10] % 8) / 100);
      final Offset point = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      dotPaint.color = (index % 3 == 0 ? seed.highlight : seed.primary)
          .withValues(alpha: 0.45);
      canvas.drawCircle(
        point,
        2.2 + (seed.bytes[index + 4] % 4) * 0.55,
        dotPaint,
      );
    }

    final Paint spokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = seed.secondary.withValues(alpha: 0.18);
    for (int index = 0; index < 6; index += 1) {
      final double angle =
          (math.pi * 2 / 6) * index + seed.bytes[index + 20] / 255 * 0.5;
      final Offset start = Offset(
        center.dx + math.cos(angle) * radius * 0.34,
        center.dy + math.sin(angle) * radius * 0.34,
      );
      final Offset end = Offset(
        center.dx + math.cos(angle) * radius * 0.57,
        center.dy + math.sin(angle) * radius * 0.57,
      );
      canvas.drawLine(start, end, spokePaint);
    }

    final Paint innerGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          seed.highlight.withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius * 0.46),
      );
    canvas.drawCircle(center, radius * 0.46, innerGlow);
  }

  @override
  bool shouldRepaint(covariant _BitsendPairPainter oldDelegate) {
    return oldDelegate.seed.bytes != seed.bytes;
  }
}

String _hexFingerprint(Uint8List bytes) {
  final StringBuffer buffer = StringBuffer();
  for (int index = 0; index < 4; index += 1) {
    if (index > 0) {
      buffer.write('-');
    }
    buffer.write(bytes[index].toRadixString(16).padLeft(2, '0').toUpperCase());
  }
  return buffer.toString();
}
