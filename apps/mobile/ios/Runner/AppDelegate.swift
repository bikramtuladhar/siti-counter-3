import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let messenger = controller?.binaryMessenger {
      setupMethodChannels(messenger: messenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupMethodChannels(messenger: FlutterBinaryMessenger) {
    let activityChannel = FlutterMethodChannel(name: "com.siticounter.app/live_activity", binaryMessenger: messenger)
    activityChannel.setMethodCallHandler { (call, result) in
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
        return
      }
      #if canImport(ActivityKit)
      if #available(iOS 16.1, *) {
        switch call.method {
        case "startLiveActivity":
          let dishName = args["dishName"] as? String ?? "Dish"
          let cookerType = args["cookerType"] as? String ?? "Pressure Cooker"
          let currentSiti = args["currentSiti"] as? Int ?? 0
          let targetSiti = args["targetSiti"] as? Int ?? 4
          let currentStep = args["currentStep"] as? String ?? "Cooking"
          SitiActivityManager.shared.start(
            dishName: dishName,
            cookerType: cookerType,
            currentSiti: currentSiti,
            targetSiti: targetSiti,
            currentStep: currentStep
          )
          result(true)
        case "updateLiveActivity":
          let currentSiti = args["currentSiti"] as? Int ?? 0
          let targetSiti = args["targetSiti"] as? Int ?? 4
          let currentStep = args["currentStep"] as? String ?? "Cooking"
          SitiActivityManager.shared.update(currentSiti: currentSiti, targetSiti: targetSiti, currentStep: currentStep)
          result(true)
        case "endLiveActivity":
          SitiActivityManager.shared.end()
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      } else {
        result(false)
      }
      #else
      result(false)
      #endif
    }

    let audioChannel = FlutterMethodChannel(name: "com.siticounter.app/audio_session", binaryMessenger: messenger)
    audioChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "configureAudioSession":
        do {
          try SitiAudioSessionManager.shared.configureAudioSession()
          result(true)
        } catch {
          result(FlutterError(code: "AUDIO_CONFIG_FAILED", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
