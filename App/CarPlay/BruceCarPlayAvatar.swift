#if os(iOS)
  import CarPlay

  /// Each template has its own image limits; both use the car display's pixel scale.
  @MainActor
  struct BruceCarPlayAvatar {
    let voiceImage: UIImage
    let listImage: UIImage

    init(image: CGImage, displayScale: CGFloat) {
      let source = UIImage(cgImage: image, scale: displayScale, orientation: .up)
      voiceImage = Self.resize(source, toFit: CGSize(width: 150, height: 150))
      listImage = Self.resize(source, toFit: CPListItem.maximumImageSize)
    }

    private static func resize(_ image: UIImage, toFit limit: CGSize) -> UIImage {
      let ratio = min(1, limit.width / image.size.width, limit.height / image.size.height)
      guard ratio < 1 else { return image }
      let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
      let format = UIGraphicsImageRendererFormat()
      format.scale = image.scale
      return UIGraphicsImageRenderer(size: size, format: format).image { _ in
        image.draw(in: CGRect(origin: .zero, size: size))
      }
    }
  }
#endif
