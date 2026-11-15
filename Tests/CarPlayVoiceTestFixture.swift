#if os(iOS)
  import CarPlay

  @testable import Bruce

  @available(iOS 26.4, *)
  @MainActor
  struct CarPlayVoiceTestFixture {
    let client: VoiceClientDouble
    let system: VoiceSystemDouble
    let audio: VoiceAudioDouble
    let store: OpenClawVoiceStore
    let presenter: Presenter
    let coordinator: BruceCarPlayVoiceCoordinator

    init(
      agents: [OpenClawAgent], microphonePermission: @escaping () -> Bool = { true },
      loadAvatar: @escaping @MainActor (String) async -> CGImage? = { _ in nil }
    ) {
      client = VoiceClientDouble()
      client.roster = agents
      system = VoiceSystemDouble()
      audio = VoiceAudioDouble()
      let callAudio = audio
      store = OpenClawVoiceStore(client: client, systemCall: system, makeAudio: { callAudio })
      presenter = Presenter()
      let mode = BruceModeController(store: ModeStore(), iconApplier: IconApplier())
      coordinator = BruceCarPlayVoiceCoordinator(
        store: store, modeController: mode, interfaceController: presenter, displayScale: 2,
        hasMicrophonePermission: microphonePermission, loadAvatar: loadAvatar)
    }

    final class Presenter: BruceCarPlayPresenting {
      var automaticallyCompletes = true
      var templates: [CPTemplate] = []
      var onPresent: ((CPTemplate) -> Void)?
      private var completions: [@MainActor (Bool, (any Error)?) -> Void] = []

      func present(
        _ template: CPTemplate, completion: @escaping @MainActor (Bool, (any Error)?) -> Void
      ) {
        templates.append(template)
        onPresent?(template)
        if automaticallyCompletes { completion(true, nil) } else { completions.append(completion) }
      }

      func completeNext() {
        guard !completions.isEmpty else { return }
        completions.removeFirst()(true, nil)
      }
    }

    private final class ModeStore: BruceModeStoring {
      func loadMode() -> BruceMode? { .standard }
      func saveMode(_ mode: BruceMode) {}
    }

    private struct IconApplier: AppIconApplying {
      func apply(_ mode: BruceMode) async throws {}
    }
  }
#endif
