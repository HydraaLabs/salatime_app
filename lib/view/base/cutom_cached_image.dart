import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../util/images.dart';

class CachedNetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double height;
  final double width;
  final BoxFit fit;
  final double borderRadius;

  const CachedNetworkImageWidget({
    super.key,
    required this.imageUrl,
    required this.height,
    required this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Image.asset(Images.placeholderImage, height: height, width: width);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        height: height,
        width: width,
        fit: fit,
        // Decode thumbnails at their display size, not at wallpaper resolution.
        memCacheWidth: width.isFinite && width > 0
            ? (width * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
                1,
                2048,
              )
            : null,
        // Set one decode dimension so the source aspect ratio is preserved.
        memCacheHeight:
            (!width.isFinite || width <= 0) && height.isFinite && height > 0
            ? (height * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
                1,
                2048,
              )
            : null,
        placeholder: (context, url) =>
            Image.asset(Images.placeholderImage, height: height, width: width),
        errorWidget: (context, url, error) =>
            Image.asset(Images.placeholderImage, height: height, width: width),
      ),
    );
  }
}
