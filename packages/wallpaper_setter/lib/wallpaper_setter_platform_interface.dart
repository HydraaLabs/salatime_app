import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'wallpaper_setter_method_channel.dart';

abstract class WallpaperPluginPlatform extends PlatformInterface {
  WallpaperPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static WallpaperPluginPlatform _instance = MethodChannelWallpaperPlugin();

  static WallpaperPluginPlatform get instance => _instance;

  static set instance(WallpaperPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // ✅ 1. getPlatformVersion
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  // ✅ 2. setWallpaper
  Future<bool> setWallpaper(
    GlobalKey boundaryKey,
    String target, {
    double pixelRatio = 2.5,
  }) {
    throw UnimplementedError('setWallpaper() has not been implemented.');
  }

  // ✅ 3. useAsImage
  Future<bool> useAsImage(GlobalKey boundaryKey, {double pixelRatio = 2.5}) {
    throw UnimplementedError('useAsImage() has not been implemented.');
  }
}
