#if os(iOS)
  /// UIKit can launch the CarPlay scene without ever creating the SwiftUI phone window.
  /// Both entry points resolve the same app-lifetime call and presentation mode here.
  @MainActor
  final class BruceVoiceRuntime {
    static let shared = BruceVoiceRuntime()
    let store = OpenClawVoiceStore()
    let modeController = BruceModeController()
    private init() {}
  }
#endif
