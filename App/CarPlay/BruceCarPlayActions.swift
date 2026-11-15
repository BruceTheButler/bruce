#if os(iOS)
  import CarPlay

  /// CarPlay can invoke button blocks on its XPC queue rather than the main queue.
  enum BruceCarPlayActions {
    static func barButton(_ action: @escaping @MainActor @Sendable () -> Void)
      -> @Sendable (CPBarButton) -> Void
    {
      { _ in Task { @MainActor in action() } }
    }

    static func button(_ action: @escaping @MainActor @Sendable () -> Void)
      -> @Sendable (CPButton) -> Void
    {
      { _ in Task { @MainActor in action() } }
    }
  }
#endif
