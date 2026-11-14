#if os(iOS)
  import CarPlay
  import Combine
  import XCTest

  @testable import Bruce

  @available(iOS 26.4, *)
  @MainActor
  final class BruceCarPlayAvatarTests: XCTestCase {
    func testLoadedAvatarReachesTheVoiceTemplate() async throws {
      let image = try image()
      let fixture = CarPlayVoiceTestFixture(
        agents: [agent(avatar: "avatar")], loadAvatar: { _ in image })
      let delivered = expectation(description: "Agent photo presented")
      var didDeliver = false
      fixture.presenter.onPresent = { [weak self] template in
        if !didDeliver, self?.photo(template) === image {
          didDeliver = true
          delivered.fulfill()
        }
      }
      await transition(fixture.store, to: .choosing) { fixture.coordinator.connect() }
      await fulfillment(of: [delivered], timeout: 3)
      XCTAssertTrue(photo(fixture.presenter.templates.last) === image)
      await transition(fixture.store, to: .idle) { fixture.coordinator.disconnect() }
    }

    func testBlockedOldAvatarCannotReplaceTheRefreshedAgentPhoto() async throws {
      let oldImage = try image()
      let newImage = try image()
      let requested = expectation(description: "Old avatar loading")
      let returned = expectation(description: "Cancelled loader returned")
      var oldLoad: CheckedContinuation<CGImage?, Never>?
      let fixture = CarPlayVoiceTestFixture(
        agents: [agent(avatar: "old")],
        loadAvatar: { url in
          if url != "old" { return newImage }
          let image = await withCheckedContinuation { continuation in
            oldLoad = continuation
            requested.fulfill()
          }
          returned.fulfill()
          return image
        })
      await transition(fixture.store, to: .choosing) { fixture.coordinator.connect() }
      await fulfillment(of: [requested], timeout: 3)
      let delivered = expectation(description: "New photo presented")
      var didDeliver = false
      fixture.presenter.onPresent = { [weak self] template in
        if !didDeliver, self?.photo(template) === newImage {
          didDeliver = true
          delivered.fulfill()
        }
      }
      fixture.client.roster = [agent(avatar: "new")]
      await transition(fixture.store, to: .choosing) { fixture.store.refreshAgents() }
      await fulfillment(of: [delivered], timeout: 3)
      let count = fixture.presenter.templates.count
      oldLoad?.resume(returning: oldImage)
      await fulfillment(of: [returned], timeout: 3)
      XCTAssertEqual(fixture.presenter.templates.count, count)
      XCTAssertTrue(photo(fixture.presenter.templates.last) === newImage)
      await transition(fixture.store, to: .idle) { fixture.coordinator.disconnect() }
    }

    func testDisconnectRejectsABlockedAvatarResult() async throws {
      let image = try image()
      let requested = expectation(description: "Avatar loading")
      let returned = expectation(description: "Disconnected loader returned")
      var load: CheckedContinuation<CGImage?, Never>?
      let fixture = CarPlayVoiceTestFixture(
        agents: [agent(avatar: "old")],
        loadAvatar: { _ in
          let image = await withCheckedContinuation { continuation in
            load = continuation
            requested.fulfill()
          }
          returned.fulfill()
          return image
        })
      await transition(fixture.store, to: .choosing) { fixture.coordinator.connect() }
      await fulfillment(of: [requested], timeout: 3)
      await transition(fixture.store, to: .idle) { fixture.coordinator.disconnect() }
      let count = fixture.presenter.templates.count
      load?.resume(returning: image)
      await fulfillment(of: [returned], timeout: 3)
      XCTAssertEqual(fixture.presenter.templates.count, count)
    }

    private func agent(avatar: String) -> OpenClawAgent {
      OpenClawAgent(
        id: "house", name: "Bruce — House",
        identity: .init(name: nil, avatarUrl: avatar, emoji: nil))
    }

    private func image() throws -> CGImage {
      try XCTUnwrap(
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
          UIColor.black.setFill()
          context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }.cgImage)
    }

    private func photo(_ template: CPTemplate?) -> CGImage? {
      (template as? CPVoiceControlTemplate)?.voiceControlStates.first?.image?.cgImage
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
