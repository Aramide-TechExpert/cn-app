import Flutter
import UIKit
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Native Firebase init (from GoogleService-Info.plist) — must happen at
    // launch so firebase_messaging can register with APNs; Dart-only init
    // runs too late and the APNs device token is never requested.
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    // Ask iOS for the APNs token explicitly (safe before the user grants
    // notification permission — alerts are gated separately).
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
