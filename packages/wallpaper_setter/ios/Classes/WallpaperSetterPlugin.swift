import Flutter
import UIKit

public class WallpaperSetterPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.iamporag/wallpaper", binaryMessenger: registrar.messenger())
        let instance = WallpaperSetterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "useAsImage":
            if let args = call.arguments as? [String: Any],
               let path = args["path"] as? String {
                shareImage(path: path)
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing path", details: nil))
            }
        case "setWallpaper":
            if let args = call.arguments as? [String: Any],
               let path = args["path"] as? String {
                saveImageToPhotos(path: path) { success in
                    result(success)
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing path", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func saveImageToPhotos(path: String, completion: @escaping (Bool) -> Void) {
        guard let image = UIImage(contentsOfFile: path) else {
            completion(false)
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        completion(true)
    }

    private func shareImage(path: String) {
        guard let image = UIImage(contentsOfFile: path) else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
