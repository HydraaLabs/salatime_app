import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'wallpaper_setter_platform_interface.dart';

class MethodChannelWallpaperPlugin extends WallpaperPluginPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('com.iamporag/wallpaper');

  // ✅ 1. getPlatformVersion
  @override
  Future<String?> getPlatformVersion() async {
    return await methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  // ✅ 2. setWallpaper
  @override
  Future<bool> setWallpaper(
    GlobalKey boundaryKey,
    String target, {
    double pixelRatio = 2.5,
  }) async {
    try {
      final bytes = await _captureWidget(boundaryKey, pixelRatio);
      if (bytes == null) return false;

      final filePath = await _saveTempFile(bytes, 'wallpaper');

      final bool success =
          await methodChannel.invokeMethod('setWallpaper', {
            'path': filePath,
            'target': target,
          }) ??
          false;

      // Cleanup
      await File(filePath).delete().catchError((_) => File(filePath));

      return success;
    } on PlatformException catch (e) {
      debugPrint('setWallpaper error: ${e.message}');
      return false;
    }
  }

  // ✅ 3. useAsImage
  @override
  Future<bool> useAsImage(
    GlobalKey boundaryKey, {
    double pixelRatio = 2.5,
  }) async {
    try {
      final bytes = await _captureWidget(boundaryKey, pixelRatio);
      if (bytes == null) return false;

      final filePath = await _saveTempFile(bytes, 'use_as_temp');

      await methodChannel.invokeMethod('useAsImage', {'path': filePath});

      return true;
    } on PlatformException catch (e) {
      debugPrint('useAsImage error: ${e.message}');
      return false;
    }
  }

  // ✅ Helper: widget capture করা
  Future<Uint8List?> _captureWidget(GlobalKey key, double pixelRatio) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) return null;

      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Widget capture error: $e');
      return null;
    }
  }

  // ✅ Helper: temp file save করা
  Future<String> _saveTempFile(Uint8List bytes, String name) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$name.png';
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }
}
