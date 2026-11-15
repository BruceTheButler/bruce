#if os(iOS)
  /// CarPlay exposes conversation controls and agent selection, never house panels or AI replies.
  @MainActor
  struct BruceCarPlayVoiceState {
    enum Action: Sendable { case start, refresh, mute, end, cancel, retry }
    let phase: OpenClawVoiceStore.Phase
    let agents: [OpenClawAgent]
    let agent: OpenClawAgent?
    let isMuted: Bool
    let problem: OpenClawVoiceStore.Problem?
    let mode: BruceMode
    let needsMicrophoneSetup: Bool
    var copy: VoiceCopy { VoiceCopy(mode: mode) }

    var title: String {
      if needsMicrophoneSetup { return copy.setupRequired }
      switch phase {
      case .idle: return copy.title
      case .choosing: return agents.isEmpty ? copy.empty : (agent?.displayName ?? copy.chooseAgent)
      case .loading: return copy.loading
      case .signingIn: return copy.setupRequired
      case .connecting: return copy.connecting
      case .connected: return isMuted ? copy.muted : copy.connected
      case .ending: return copy.ending
      case .failed: return problem == .microphone ? copy.setupRequired : copy.message(problem)
      }
    }

    var actions: [Action] {
      if needsMicrophoneSetup { return [.start, .cancel] }
      switch phase {
      case .idle: return [.start]
      case .choosing: return agent == nil ? [.refresh] : [.start]
      case .loading, .signingIn: return [.cancel]
      case .connecting: return [.end]
      case .connected: return [.mute, .end]
      case .ending: return []
      case .failed: return [.retry, .cancel]
      }
    }

    var showsAgentList: Bool { ![.connecting, .connected, .ending].contains(phase) }
  }
#endif
