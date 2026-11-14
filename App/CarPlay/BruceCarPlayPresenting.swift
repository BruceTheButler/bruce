#if os(iOS)
  import CarPlay

  /// Keeps template transitions serialized and permits deterministic scene-lifecycle tests.
  @MainActor
  protocol BruceCarPlayPresenting: AnyObject {
    func present(
      _ template: CPTemplate, completion: @escaping @MainActor (Bool, (any Error)?) -> Void)
  }

  extension CPInterfaceController: BruceCarPlayPresenting {
    func present(
      _ template: CPTemplate, completion: @escaping @MainActor (Bool, (any Error)?) -> Void
    ) {
      setRootTemplate(template, animated: false) { success, error in
        Task { @MainActor in completion(success, error) }
      }
    }
  }
#endif
