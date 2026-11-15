#if os(iOS)
  import CarPlay
  import Combine
  import XCTest

  @testable import Bruce

  @available(iOS 26.4, *)
  @MainActor
  final class BruceCarPlayVoiceTests: XCTestCase {
    private let agent = OpenClawAgent(id: "house", name: "Bruce — House", identity: nil)

    func testCarPlayControlsTheSameConversationAndReusesAgents() async {
      let fixture = fixture()
      await transition(fixture.store, to: .choosing) { fixture.coordinator.connect() }
      await transition(fixture.store, to: .connected) { fixture.coordinator.handle(.start) }
      XCTAssertEqual(fixture.client.startedAgents, ["house"])
      fixture.coordinator.handle(.mute)
      XCTAssertTrue(fixture.store.isMuted)
      XCTAssertEqual(fixture.audio.mutedValues, [true])
      await transition(fixture.store, to: .choosing) { fixture.coordinator.handle(.end) }
      XCTAssertEqual(fixture.client.rosterCount, 1)
      await transition(fixture.store, to: .idle) { fixture.coordinator.disconnect() }
    }

    func testBackgroundAndDisconnectPreserveActiveAudioWithoutReloadingHiddenAgents() async {
      let fixture = fixture()
      await transition(fixture.store, to: .choosing) { fixture.coordinator.connect() }
      await transition(fixture.store, to: .connected) { fixture.coordinator.handle(.start) }
      fixture.coordinator.setVisible(false)
      XCTAssertEqual(fixture.store.phase, .connected)
      XCTAssertFalse(fixture.audio.isClosed)
      await transition(fixture.store, to: .idle) { fixture.system.onEnd?() }
      XCTAssertEqual(fixture.client.rosterCount, 1)
      fixture.coordinator.setVisible(true)
      XCTAssertEqual(fixture.store.phase, .choosing)
      XCTAssertEqual(fixture.client.rosterCount, 1)
      await transition(fixture.store, to: .connected) { fixture.coordinator.handle(.start) }
      fixture.coordinator.disconnect()
      XCTAssertEqual(fixture.store.phase, .connected)
      await transition(fixture.store, to: .idle) { fixture.system.onEnd?() }
    }

    func testMicrophoneSetupStaysOnPhoneBeforeAnySystemCallStarts() async {
      var permission = false
      let fixture = fixture(microphonePermission: { permission })
      await transition(fixture.store, to: .choosing) { fixture.coordinator.connect() }
      fixture.coordinator.handle(.start)
      XCTAssertEqual(fixture.store.phase, .choosing)
      XCTAssertTrue(fixture.system.agents.isEmpty)
      let list = fixture.presenter.templates.last as? CPListTemplate
      XCTAssertTrue(
        list?.emptyViewTitleVariants.contains(
          VoiceCopy(mode: .standard).setupRequired) == true)
      fixture.coordinator.handle(.retry)
      let denied = fixture.presenter.templates.last as? CPListTemplate
      XCTAssertEqual(denied?.itemCount, 0)
      XCTAssertEqual(
        denied?.trailingNavigationBarButtons.map(\.title), [VoiceCopy(mode: .standard).retry])
      XCTAssertEqual(denied?.emptyViewTitleVariants, [VoiceCopy(mode: .standard).setupRequired])
      XCTAssertTrue(fixture.system.agents.isEmpty)
      permission = true
      await transition(fixture.store, to: .connected) { fixture.coordinator.handle(.retry) }
      await transition(fixture.store, to: .choosing) { fixture.coordinator.handle(.end) }
      await transition(fixture.store, to: .idle) { fixture.coordinator.disconnect() }
    }

    func testTemplatesStayWithinVoiceCategoryAndButtonLimits() {
      let phases: [OpenClawVoiceStore.Phase] = [
        .idle, .loading, .choosing, .signingIn, .connecting, .connected, .ending, .failed,
      ]
      for phase in phases {
        let state = state(phase: phase)
        let template = BruceCarPlayVoiceTemplates.voice(state: state, images: [:], action: { _ in })
        XCTAssertEqual(template.voiceControlStates.count, 1)
        XCTAssertLessThanOrEqual(template.voiceControlStates[0].actionButtons.count, 2)
        XCTAssertFalse(state.title.isEmpty)
      }
      let list = BruceCarPlayVoiceTemplates.agents(
        state: state(phase: .choosing), images: [:], select: { _ in }, action: { _ in })
      XCTAssertEqual(list.sections.first?.items.first?.text, agent.displayName)
      XCTAssertEqual(list.sections.first?.items.count, 1)
    }

    func testTemplateUpdatesAreSerializedAndOldCompletionsIgnoreDisconnect() async {
      let fixture = fixture()
      fixture.presenter.automaticallyCompletes = false
      await transition(fixture.store, to: .choosing) { fixture.coordinator.connect() }
      fixture.coordinator.setVisible(true)
      XCTAssertEqual(fixture.presenter.templates.count, 1)
      fixture.presenter.completeNext()
      XCTAssertEqual(fixture.presenter.templates.count, 2)
      let latest = fixture.presenter.templates.last as? CPListTemplate
      XCTAssertEqual(latest?.sections.first?.items.first?.text, agent.displayName)
      await transition(fixture.store, to: .idle) {
        fixture.coordinator.disconnect()
        fixture.presenter.completeNext()
      }
      XCTAssertEqual(fixture.presenter.templates.count, 2)
    }

    func testCarPlaySceneIsDeclaredInTheAppManifest() throws {
      let manifest = try XCTUnwrap(
        Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") as? [String: Any])
      let roles = try XCTUnwrap(manifest["UISceneConfigurations"] as? [String: Any])
      let carPlay = try XCTUnwrap(
        roles["CPTemplateApplicationSceneSessionRoleApplication"] as? [[String: Any]])
      XCTAssertEqual(carPlay.first?["UISceneClassName"] as? String, "CPTemplateApplicationScene")
      XCTAssertTrue(
        (carPlay.first?["UISceneDelegateClassName"] as? String)?.hasSuffix(
          ".BruceCarPlaySceneDelegate") == true)
    }

    func testBackgroundRetiresPendingRendersAndForegroundShowsTheLatestCall() async {
      let fixture = fixture()
      fixture.presenter.automaticallyCompletes = false
      await transition(fixture.store, to: .choosing) { fixture.coordinator.connect() }
      await transition(fixture.store, to: .idle) { fixture.coordinator.setVisible(false) }
      fixture.store.presentPicker(id: UUID())
      fixture.store.prepare()
      await transition(fixture.store, to: .connected) { fixture.store.start(self.agent) }
      fixture.presenter.completeNext()
      XCTAssertEqual(fixture.presenter.templates.count, 1)
      fixture.coordinator.setVisible(true)
      XCTAssertEqual(fixture.presenter.templates.count, 2)
      let latest = fixture.presenter.templates.last as? CPVoiceControlTemplate
      XCTAssertTrue(
        latest?.voiceControlStates.first?.titleVariants?.contains(
          VoiceCopy(mode: .standard).connected) == true)
      fixture.coordinator.disconnect()
      await transition(fixture.store, to: .idle) { fixture.store.end(returnToPicker: false) }
    }

    func testCallTitleFallsBackToTheAgentNameBeforeTheStatus() {
      for phase in [OpenClawVoiceStore.Phase.connecting, .connected] {
        let state = state(phase: phase)
        let template = BruceCarPlayVoiceTemplates.voice(state: state, images: [:], action: { _ in })
        XCTAssertEqual(
          template.voiceControlStates.first?.titleVariants,
          [
            agent.displayName + "\n" + state.title, agent.displayName, state.title,
          ])
      }
    }

    func testEmptyRosterOffersRefreshWithoutAnEmptyAgentList() {
      let state = BruceCarPlayVoiceState(
        phase: .choosing, agents: [], agent: nil, isMuted: false, problem: nil,
        mode: .standard, needsMicrophoneSetup: false)
      let template = BruceCarPlayVoiceTemplates.agents(
        state: state, images: [:], select: { _ in }, action: { _ in })
      XCTAssertEqual(template.emptyViewTitleVariants, [state.copy.empty])
      XCTAssertEqual(template.trailingNavigationBarButtons.map(\.title), [state.copy.refreshAgents])
      XCTAssertEqual(template.itemCount, 0)
      XCTAssertTrue(state.showsAgentList)
    }

    private func state(phase: OpenClawVoiceStore.Phase) -> BruceCarPlayVoiceState {
      BruceCarPlayVoiceState(
        phase: phase, agents: [agent], agent: agent, isMuted: false, problem: nil,
        mode: .standard, needsMicrophoneSetup: false)
    }

    private func fixture(microphonePermission: @escaping () -> Bool = { true })
      -> CarPlayVoiceTestFixture
    {
      CarPlayVoiceTestFixture(agents: [agent], microphonePermission: microphonePermission)
    }

    private func transition(
      _ store: OpenClawVoiceStore, to phase: OpenClawVoiceStore.Phase, action: () -> Void
    ) async {
      let reached = expectation(description: "Voice reaches \(phase)")
      let subscription = store.$phase.dropFirst().first(where: { $0 == phase }).sink { _ in
        reached.fulfill()
      }
      action()
      await fulfillment(of: [reached], timeout: 3)
      withExtendedLifetime(subscription) {}
    }
  }

#endif
