#if os(iOS)
  import AVFoundation
  import CarPlay
  import Combine
  import OSLog

  @available(iOS 26.4, *)
  @MainActor
  final class BruceCarPlayVoiceCoordinator {
    private let store: OpenClawVoiceStore
    private let modeController: BruceModeController
    private weak var interfaceController: (any BruceCarPlayPresenting)?
    private let loadAvatar: @MainActor (String) async -> CGImage?
    private let hasMicrophonePermission: () -> Bool
    private var observations: Set<AnyCancellable> = []
    private var modeTask: Task<Void, Never>?
    private var avatarTask: Task<Void, Never>?
    private var avatarURLs: Set<String> = []
    private var images: [String: UIImage] = [:]
    private let presenterID = UUID()
    private var generation = UUID()
    private var isConnected = false
    private var isVisible = false
    private var isPresenting = false
    private var needsRender = false
    private var showsAgents = false
    private var selectedAgentID: String?
    private var needsMicrophoneSetup = false
    private let logger = Logger(subsystem: "net.symphonious.bruce", category: "CarPlayVoice")

    init(
      store: OpenClawVoiceStore, modeController: BruceModeController,
      interfaceController: any BruceCarPlayPresenting,
      hasMicrophonePermission: @escaping () -> Bool = {
        AVAudioApplication.shared.recordPermission == .granted
      },
      loadAvatar: @escaping @MainActor (String) async -> CGImage? = cachedAvatar
    ) {
      self.loadAvatar = loadAvatar
      self.hasMicrophonePermission = hasMicrophonePermission
      self.store = store
      self.modeController = modeController
      self.interfaceController = interfaceController
    }

    private static func cachedAvatar(_ value: String) async -> CGImage? {
      await OpenClawAvatarCache.shared.image(for: value)
    }

    func connect(isVisible: Bool = true) {
      guard !isConnected else { return }
      isConnected = true
      // objectWillChange precedes published mutations. Reconcile on the next main-actor turn.
      store.objectWillChange.sink { [weak self] in
        Task { @MainActor [weak self] in self?.render() }
      }.store(in: &observations)
      modeController.objectWillChange.sink { [weak self] in
        Task { @MainActor [weak self] in self?.render() }
      }.store(in: &observations)
      modeTask = Task { [modeController] in await modeController.restore() }
      setVisible(isVisible)
    }

    func setVisible(_ visible: Bool) {
      guard isConnected else { return }
      isVisible = visible
      if visible {
        store.presentPicker(id: presenterID)
        if store.phase == .idle { store.prepare() }
        render()
      } else {
        avatarTask?.cancel()
        avatarTask = nil
        avatarURLs = []
        BruceVoicePresentation.dismissPicker(store, presenterID: presenterID)
      }
    }

    func disconnect() {
      isConnected = false
      isVisible = false
      generation = UUID()
      observations.removeAll()
      modeTask?.cancel()
      avatarTask?.cancel()
      BruceVoicePresentation.dismissPicker(store, presenterID: presenterID)
      interfaceController = nil
    }

    private var state: BruceCarPlayVoiceState {
      let selected = store.agents.first { $0.id == selectedAgentID } ?? store.agents.first
      return BruceCarPlayVoiceState(
        phase: store.phase, agents: store.agents,
        agent: store.hasCall || store.phase == .ending ? store.agent : selected,
        isMuted: store.isMuted, problem: store.problem, mode: modeController.mode,
        needsMicrophoneSetup: needsMicrophoneSetup && !store.hasCall)
    }

    func handle(_ action: BruceCarPlayVoiceState.Action) {
      guard isConnected, isVisible else { return }
      switch action {
      case .start: startConversation()
      case .agents: showsAgents = true
      case .back: showsAgents = false
      case .refresh: store.refreshAgents()
      case .retry:
        needsMicrophoneSetup = false
        store.prepare()
      case .mute: store.toggleMute()
      case .end: store.end()
      case .cancel:
        needsMicrophoneSetup = false
        showsAgents = false
        store.end(returnToPicker: false)
      }
      render()
    }

    private func startConversation() {
      guard store.phase == .choosing, let agent = state.agent else {
        if store.phase == .idle { store.prepare() }
        return
      }
      guard hasMicrophonePermission() else {
        needsMicrophoneSetup = true
        render()
        return
      }
      needsMicrophoneSetup = false
      showsAgents = false
      store.start(agent)
    }

    private func render() {
      guard isConnected, isVisible, let interfaceController else { return }
      if hasMicrophonePermission() { needsMicrophoneSetup = false }
      if store.hasCall { selectedAgentID = store.agent?.id }
      loadAvatars()
      if isPresenting {
        needsRender = true
        return
      }
      let state = state
      let template: CPTemplate
      if showsAgents, state.showsAgentControls {
        let select: (OpenClawAgent) -> Void = { [weak self] agent in
          guard let self, self.store.phase == .choosing,
            self.store.agents.contains(where: { $0.id == agent.id })
          else { return }
          self.selectedAgentID = agent.id
          self.handle(.start)
        }
        template = BruceCarPlayVoiceTemplates.agents(
          state: state, images: images, select: select,
          back: { [weak self] in self?.handle(.back) })
      } else {
        showsAgents = false
        template = BruceCarPlayVoiceTemplates.voice(state: state, images: images) { [weak self] in
          self?.handle($0)
        }
      }
      isPresenting = true
      needsRender = false
      let generation = generation
      interfaceController.present(template) { [weak self] success, error in
        guard let self, self.isConnected, self.generation == generation else { return }
        self.isPresenting = false
        if !success {
          self.logger.error(
            "CarPlay presentation failed: \(String(describing: error), privacy: .private)")
        }
        if self.needsRender { self.render() }
      }
    }

    private func loadAvatars() {
      let urls = Set(store.agents.compactMap { $0.identity?.avatarUrl })
      guard urls != avatarURLs else { return }
      avatarURLs = urls
      avatarTask?.cancel()
      images = images.filter { urls.contains($0.key) }
      let generation = generation
      let loadAvatar = loadAvatar
      avatarTask = Task { [weak self] in
        for url in urls {
          guard !Task.isCancelled else { return }
          guard let image = await loadAvatar(url) else { continue }
          guard let self, !Task.isCancelled, self.generation == generation else { return }
          self.images[url] = UIImage(cgImage: image, scale: 3, orientation: .up)
          self.render()
        }
      }
    }
  }
#endif
