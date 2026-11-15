#if os(iOS)
  import CarPlay

  @available(iOS 26.4, *)
  @MainActor
  enum BruceCarPlayVoiceTemplates {
    static func voice(
      state: BruceCarPlayVoiceState, images: [String: BruceCarPlayAvatar],
      action: @escaping (BruceCarPlayVoiceState.Action) -> Void
    ) -> CPVoiceControlTemplate {
      let image =
        state.agent?.identity?.avatarUrl.flatMap { images[$0]?.voiceImage }
        ?? UIImage(systemName: "waveform")
      var titles = [state.title]
      if state.phase == .connected || state.phase == .connecting,
        let name = state.agent?.displayName
      {
        titles = [name + "\n" + state.title, name, state.title]
      }
      var seen = Set<String>()
      let controlState = CPVoiceControlState(
        identifier: "voice", titleVariants: titles.filter { seen.insert($0).inserted },
        image: image, repeats: false)
      controlState.actionButtons = state.actions.compactMap { item in
        button(item, state: state, action: action)
      }
      let template = CPVoiceControlTemplate(voiceControlStates: [controlState])
      if state.showsAgentControls {
        template.trailingNavigationBarButtons = [
          barButton(state.copy.agents) { action(.agents) },
          barButton(state.copy.refreshAgents) { action(.refresh) },
        ]
      }
      return template
    }

    static func agents(
      state: BruceCarPlayVoiceState, images: [String: BruceCarPlayAvatar],
      select: @escaping (OpenClawAgent) -> Void, back: @escaping () -> Void
    ) -> CPListTemplate {
      let items = state.agents.map { agent in
        let image =
          agent.identity?.avatarUrl.flatMap { images[$0]?.listImage }
          ?? UIImage(systemName: "person.crop.circle")
        let item = CPListItem(text: agent.displayName, detailText: nil, image: image)
        item.handler = { _, completion in
          select(agent)
          completion()
        }
        return item
      }
      let template = CPListTemplate(
        title: state.copy.chooseAgent, sections: [CPListSection(items: items)])
      template.leadingNavigationBarButtons = [barButton(state.copy.done, action: back)]
      return template
    }

    private static func barButton(_ title: String, action: @escaping () -> Void) -> CPBarButton {
      CPBarButton(title: title) { _ in action() }
    }

    private static func button(
      _ item: BruceCarPlayVoiceState.Action, state: BruceCarPlayVoiceState,
      action: @escaping (BruceCarPlayVoiceState.Action) -> Void
    ) -> CPButton? {
      let title: String
      let symbol: String
      switch item {
      case .start:
        (title, symbol) = (
          state.needsMicrophoneSetup ? state.copy.retry : state.copy.title, "mic.fill"
        )
      case .mute:
        (title, symbol) =
          state.isMuted ? (state.copy.unmute, "mic.slash.fill") : (state.copy.mute, "mic.fill")
      case .end: (title, symbol) = (state.copy.end, "phone.down.fill")
      case .cancel: (title, symbol) = (state.copy.done, "xmark")
      case .refresh: (title, symbol) = (state.copy.refreshAgents, "arrow.clockwise")
      case .retry: (title, symbol) = (state.copy.retry, "arrow.clockwise")
      case .agents, .back: return nil
      }
      guard let image = UIImage(systemName: symbol) else { return nil }
      let button = CPButton(image: image) { _ in action(item) }
      button.title = title
      return button
    }
  }
#endif
