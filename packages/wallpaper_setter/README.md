# wallpaper_setter

`wallpaper_setter` is a Flutter plugin that allows you to set wallpapers from a URL or asset on Android devices.  
It uses the **default Android system wallpaper picker UI** to set wallpapers for:

### ANDROID
- Home screen
- Lock screen
- Or both

### IOS
- Only Use "Use As..."

# Demo

![Demo Animation](https://raw.githubusercontent.com/iamporag/wallpaper_setter/main/assets/demo.gif)


## 🚀 Getting Started


1) For using System Wallpaper you will need to add file_paths.xml in xml folder
   android\app\src\main\res\xml\file_paths.xml where downloaded image will be stored. 
   and Code is Here...

``` dart


   <?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <cache-path
        name="cache"
        path="." />
    <external-path
        name="external_files"
        path="." />
    <external-files-path
        name="external_files"
        path="." />
    <files-path
        name="files"
        path="." />
</paths>



 ```

2) include this permission in your manifest

``` dart

  <uses-permission android:name="android.permission.SET_WALLPAPER"/>
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
  <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />

```

3) Inside of Android
   
       <application
       ...old code
    
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
            android:name="android.support.FILE_PROVIDER_PATHS"
            android:resource="@xml/file_paths" />
        </provider>

        ...old code
    </application>


4) also make sure you have internet connection on device.
### Example


``` dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:wallpaper_setter/wallpaper_setter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper App',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<Map<String, String>> dummyImageList = const [
    {
      "id": "1",
      "title": "Nature",
      "url": "https://picsum.photos/seed/1/800/1200",
    },
    {
      "id": "2",
      "title": "City",
      "url": "https://picsum.photos/seed/2/800/1200",
    },
    {
      "id": "3",
      "title": "Mountains",
      "url": "https://picsum.photos/seed/3/800/1200",
    },
    {
      "id": "4",
      "title": "Beach",
      "url": "https://picsum.photos/seed/4/800/1200",
    },
    {
      "id": "5",
      "title": "Forest",
      "url": "https://picsum.photos/seed/5/800/1200",
    },
    {
      "id": "6",
      "title": "Desert",
      "url": "https://picsum.photos/seed/6/800/1200",
    },
    {
      "id": "7",
      "title": "Snow",
      "url": "https://picsum.photos/seed/7/800/1200",
    },
    {
      "id": "8",
      "title": "River",
      "url": "https://picsum.photos/seed/8/800/1200",
    },
    {
      "id": "9",
      "title": "Sunset",
      "url": "https://picsum.photos/seed/9/800/1200",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select a Dummy Image")),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 images per row
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.75, // taller images for full-screen feel
        ),
        itemCount: dummyImageList.length,
        itemBuilder: (context, index) {
          final item = dummyImageList[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PreviewScreen(imagePath: item['url']!),
                ),
              );
            },
            child: GridTile(
              footer: GridTileBar(
                backgroundColor: Colors.black54,
                title: Text(item['title']!),
              ),
              child: Image.network(
                item['url']!,
                fit: BoxFit.cover, // fill the grid tile
              ),
            ),
          );
        },
      ),
    );
  }
}

class PreviewScreen extends StatefulWidget {
  final String imagePath;

  const PreviewScreen({super.key, required this.imagePath});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final GlobalKey previewContainer = GlobalKey();

  Future<void> _handleSetWallpaper(String target) async {
    final success = await WallpaperPlugin.setWallpaperFromRepaintBoundary(
      previewContainer,
      target,
    );
    _showSnack(success ? 'Wallpaper set!' : 'Failed to set wallpaper');
  }

  Future<void> _handleUseAs() async {
    final success = await WallpaperPlugin.useAsImageFromRepaintBoundary(
      previewContainer,
    );
    _showSnack(success ? 'Sharing launched!' : 'Use As failed');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          RepaintBoundary(
            key: previewContainer,
            child: SizedBox.expand(
              child: PhotoView(
                imageProvider:
                    widget.imagePath.startsWith("http")
                        ? NetworkImage(widget.imagePath)
                        : FileImage(File(widget.imagePath)) as ImageProvider,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!Platform.isIOS) ...[
                  ElevatedButton(
                    onPressed: () => _handleSetWallpaper("home"),
                    child: const Text("Set as Home Screen"),
                  ),
                  ElevatedButton(
                    onPressed: () => _handleSetWallpaper("lock"),
                    child: const Text("Set as Lock Screen"),
                  ),
                  ElevatedButton(
                    onPressed: () => _handleSetWallpaper("both"),
                    child: const Text("Set Both"),
                  ),
                  const SizedBox(height: 10),
                ],
                ElevatedButton.icon(
                  onPressed: () => _handleUseAs(),
                  icon: const Icon(Icons.share),
                  label: const Text("Use As..."),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}



```
## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.io/developing-packages/),
a specialized package that includes platform-specific implementation code for
Android.

For help getting started with Flutter, view our
[online documentation](https://flutter.io/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.