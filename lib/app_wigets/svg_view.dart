import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class AssetSvgImage extends StatelessWidget {
  const AssetSvgImage({
    super.key,
    required this.fileName,
    required this.folderName,
    this.width = 24,
    this.height = 24,
    this.iconColor,
  });

  final String fileName;
  final String folderName;
  final double? width;
  final double? height;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? 24,
      height: height ?? 24,
      child: SvgPicture.asset(
        "assets/$folderName/$fileName.svg",
        color: iconColor,
      ),
    );
  }
}
