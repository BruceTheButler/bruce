#if os(iOS)
  import CarPlay

  @available(iOS 26.4, *)
  @MainActor
  final class BruceCarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    private var coordinator: BruceCarPlayVoiceCoordinator?

    func templateApplicationScene(
      _ templateApplicationScene: CPTemplateApplicationScene,
      didConnect interfaceController: CPInterfaceController
    ) {
      let runtime = BruceVoiceRuntime.shared
      let coordinator = BruceCarPlayVoiceCoordinator(
        store: runtime.store, modeController: runtime.modeController,
        interfaceController: interfaceController,
        displayScale: interfaceController.carTraitCollection.displayScale)
      self.coordinator = coordinator
      let state = templateApplicationScene.activationState
      coordinator.connect(isVisible: state == .foregroundActive || state == .foregroundInactive)
    }

    func templateApplicationScene(
      _ templateApplicationScene: CPTemplateApplicationScene,
      didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
      coordinator?.disconnect()
      coordinator = nil
    }

    func sceneDidBecomeActive(_ scene: UIScene) { coordinator?.setVisible(true) }
    func sceneDidEnterBackground(_ scene: UIScene) { coordinator?.setVisible(false) }
  }
#endif
