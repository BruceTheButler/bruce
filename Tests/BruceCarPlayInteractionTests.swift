#if os(iOS)
  import CarPlay
  import Combine
  import XCTest

  @testable import Bruce

  @available(iOS 26.4, *)
  @MainActor
  final class BruceCarPlayInteractionTests: XCTestCase {
    func testSelectingAnyAgentDialsImmediatelyAndHangupReturnsToTheFullList() async throws {
      let agents = ["adrian", "family", "house"].map {
        OpenClawAgent(id: $0, name: $0.capitalized, identity: nil)
      }
      let fixture = CarPlayVoiceTestFixture(agents: agents)
      let loaded = expectation(description: "All agents listed")
      var didLoad = false
      fixture.presenter.onPresent = { template in
        if !didLoad, let list = template as? CPListTemplate, list.itemCount == 3 {
          didLoad = true
          loaded.fulfill()
        }
      }
      fixture.coordinator.connect()
      await fulfillment(of: [loaded], timeout: 3)
      fixture.presenter.onPresent = nil
      let list = try XCTUnwrap(fixture.presenter.templates.last as? CPListTemplate)
      XCTAssertEqual(list.sections[0].items.map(\.text), agents.map(\.displayName))
      let selected = try XCTUnwrap(list.sections[0].items[1] as? CPListItem)
      let connected = expectation(description: "Selected agent connected")
      let subscription = fixture.store.$phase.first(where: { $0 == .connected }).sink { _ in
        connected.fulfill()
      }
      let acknowledged = expectation(description: "Selection acknowledged")
      selected.handler?(selected) { acknowledged.fulfill() }
      await fulfillment(of: [acknowledged, connected], timeout: 3)
      XCTAssertEqual(fixture.client.startedAgents, ["family"])

      let returned = expectation(description: "All agents listed after hangup")
      var didReturn = false
      fixture.presenter.onPresent = { template in
        if !didReturn, let list = template as? CPListTemplate, list.itemCount == 3 {
          didReturn = true
          returned.fulfill()
        }
      }
      fixture.coordinator.handle(.end)
      await fulfillment(of: [returned], timeout: 3)
      fixture.presenter.onPresent = nil
      XCTAssertEqual(fixture.client.rosterCount, 1)
      XCTAssertEqual(fixture.store.phase, .choosing)
      fixture.coordinator.disconnect()
      withExtendedLifetime(subscription) {}
    }

    func testBarButtonCallbackFromTheCarPlayQueueRunsOnTheMainActor() async {
      let handled = expectation(description: "Refresh handled on main actor")
      let callback = BruceCarPlayActions.barButton {
        MainActor.assertIsolated()
        handled.fulfill()
      }
      await Task.detached {
        callback(CPBarButton(title: "Refresh", handler: nil))
      }.value
      await fulfillment(of: [handled], timeout: 3)
    }

    func testVoiceButtonCallbackFromTheCarPlayQueueRunsOnTheMainActor() async throws {
      let image = try XCTUnwrap(UIImage(systemName: "mic"))
      let handled = expectation(description: "Voice button handled on main actor")
      let callback = BruceCarPlayActions.button {
        MainActor.assertIsolated()
        handled.fulfill()
      }
      await Task.detached {
        callback(CPButton(image: image, handler: nil))
      }.value
      await fulfillment(of: [handled], timeout: 3)
    }
  }
#endif
