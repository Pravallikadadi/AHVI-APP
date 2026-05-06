import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/services/offline_cache.dart';

class OfflineImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final WidgetBuilder? errorBuilder;
  final WidgetBuilder? placeholderBuilder;
  final Duration fadeInDuration;

  const OfflineImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.high,
    this.errorBuilder,
    this.placeholderBuilder,
    this.fadeInDuration = const Duration(milliseconds: 120),
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildError(context);
    }

    final cache = context.watch<OfflineCache>();
    final localFile = cache.localImageFile(imageUrl);

    if (localFile != null) {
      return Image.file(
        localFile,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        errorBuilder: (_, __, ___) => _buildError(context),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      fadeInDuration: fadeInDuration,
      errorWidget: (_, __, ___) => _buildError(context),
      placeholder: placeholderBuilder == null
          ? null
          : (ctx, _) => placeholderBuilder!(ctx),
    );
  }

  Widget _buildError(BuildContext context) {
    if (errorBuilder != null) return errorBuilder!(context);
    return const ColoredBox(
      color: Color(0xFFF1ECE3),
      child: Center(
        child: Icon(Icons.image_not_supported, color: Colors.black38, size: 18),
      ),
    );
  }
}
