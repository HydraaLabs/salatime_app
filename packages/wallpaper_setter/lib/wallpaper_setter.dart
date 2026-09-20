import 'package:flutter/widgets.dart';
import 'wallpaper_setter_platform_interface.dart';

class WallpaperPlugin {
  // ✅ 1. getPlatformVersion
  Future<String?> getPlatformVersion() {
    return WallpaperPluginPlatform.instance.getPlatformVersion();
  }

  // ✅ 2. setWallpaperFromRepaintBoundary
  static Future<bool> setWallpaperFromRepaintBoundary(
    GlobalKey boundaryKey,
    String target, {
    double pixelRatio = 2.5,
  }) {
    return WallpaperPluginPlatform.instance.setWallpaper(
      boundaryKey,
      target,
      pixelRatio: pixelRatio,
    );
  }

  // ✅ 3. useAsImageFromRepaintBoundary
  static Future<bool> useAsImageFromRepaintBoundary(
    GlobalKey boundaryKey, {
    double pixelRatio = 2.5,
  }) {
    return WallpaperPluginPlatform.instance.useAsImage(
      boundaryKey,
      pixelRatio: pixelRatio,
    );
  }
}
