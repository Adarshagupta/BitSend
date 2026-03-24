import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/app_models.dart';

class ChainLogo extends StatelessWidget {
  const ChainLogo({
    super.key,
    required this.chain,
    this.size = 20,
    this.fit = BoxFit.contain,
  });

  final ChainKind chain;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final String assetPath = chain.brandAssetPath;
    final Widget child = chain.brandAssetIsSvg
        ? SvgPicture.asset(assetPath, width: size, height: size, fit: fit)
        : Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: fit,
            filterQuality: FilterQuality.high,
          );
    return SizedBox(width: size, height: size, child: child);
  }
}
