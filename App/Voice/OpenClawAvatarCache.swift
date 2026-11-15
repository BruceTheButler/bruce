import CryptoKit
import Foundation
import ImageIO

/// Decode away from the UI executor and reuse the same small image in picker and call views.
actor OpenClawAvatarCache {
  static let shared = OpenClawAvatarCache()
  private var images: [String: CGImage] = [:]
  private var insertionOrder: [String] = []

  func image(for value: String?) -> CGImage? {
    guard let value, value.hasPrefix("data:image/"), value.utf8.count <= 8_000_000 else {
      return nil
    }
    guard let separator = value.range(of: ";base64,"),
      let data = Data(base64Encoded: String(value[separator.upperBound...]))
    else { return nil }
    return image(data: data)
  }

  /// Remote CarPlay avatars use the same bounded decoder as embedded phone avatars.
  func remoteImage(for url: URL, session: URLSession = .shared) async throws -> CGImage? {
    guard url.scheme == "https" else { return nil }
    let (bytes, response) = try await session.bytes(from: url)
    defer { bytes.task.cancel() }
    guard let response = response as? HTTPURLResponse,
      response.url?.scheme == "https", (200..<300).contains(response.statusCode),
      response.expectedContentLength <= 8_000_000
    else { throw OpenClawVoiceError.unavailable }
    return try await withTaskCancellationHandler {
      var data = Data()
      for try await byte in bytes {
        try Task.checkCancellation()
        guard data.count < 8_000_000 else { throw OpenClawVoiceError.unavailable }
        data.append(byte)
      }
      return image(data: data)
    } onCancel: {
      bytes.task.cancel()
    }
  }

  private func image(data: Data) -> CGImage? {
    let key = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    if let image = images[key] { return image }
    guard
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceThumbnailMaxPixelSize: 384,
          kCGImageSourceCreateThumbnailWithTransform: true,
        ] as CFDictionary)
    else { return nil }
    if insertionOrder.count == 16 {
      images.removeValue(forKey: insertionOrder.removeFirst())
    }
    insertionOrder.append(key)
    images[key] = image
    return image
  }
}
