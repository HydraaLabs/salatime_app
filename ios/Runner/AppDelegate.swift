import UIKit
import Flutter
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var salaTimeBridge: SalaTimePlatformBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    Self.clearApplicationBadge(application)
    PrayerNotificationHistory.retainLatestDelivered()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    salaTimeBridge = SalaTimePlatformBridge(messenger: engineBridge.applicationRegistrar.messenger())
  }

  static func clearApplicationBadge(_ application: UIApplication) {
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0) { error in
        if error != nil { NSLog("Unable to clear application badge") }
      }
    } else {
      application.applicationIconBadgeNumber = 0
    }
  }
}
