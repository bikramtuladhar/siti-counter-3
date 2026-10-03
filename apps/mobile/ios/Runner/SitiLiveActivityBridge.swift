import Foundation
import AVFoundation
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
@available(iOS 16.1, *)
public struct SitiActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    public var currentSiti: Int
    public var targetSiti: Int
    public var currentStep: String
    public var remainingSeconds: Int?

    public init(currentSiti: Int, targetSiti: Int, currentStep: String, remainingSeconds: Int? = nil) {
      self.currentSiti = currentSiti
      self.targetSiti = targetSiti
      self.currentStep = currentStep
      self.remainingSeconds = remainingSeconds
    }
  }

  public var dishName: String
  public var cookerType: String

  public init(dishName: String, cookerType: String) {
    self.dishName = dishName
    self.cookerType = cookerType
  }
}
#endif

/// Manages background audio session and interruption notifications.
public class SitiAudioSessionManager: NSObject {
  public static let shared = SitiAudioSessionManager()

  public var onInterruptionBegan: (() -> Void)?
  public var onInterruptionEnded: ((Bool) -> Void)?

  public func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playAndRecord,
      mode: .measurement,
      options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth]
    )
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterruption),
      name: AVAudioSession.interruptionNotification,
      object: session
    )
  }

  @objc private func handleInterruption(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
      return
    }

    switch type {
    case .began:
      onInterruptionBegan?()
    case .ended:
      guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
      let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
      let shouldResume = options.contains(.shouldResume)
      onInterruptionEnded?(shouldResume)
    @unknown default:
      break
    }
  }
}
