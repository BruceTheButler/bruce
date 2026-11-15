import XCTest

@testable import Bruce

final class OpenClawAvatarCacheTests: XCTestCase {
  func testHTTPSAvatarIsDecodedAndReusedByTheEmbeddedImageCache() async throws {
    let session = session()
    defer { session.invalidateAndCancel() }
    let cache = OpenClawAvatarCache()
    let url = try XCTUnwrap(URL(string: "https://avatars.example/avatar.png"))
    let remote = try await cache.remoteImage(for: url, session: session)
    XCTAssertEqual(remote?.width, 1)
    let embedded = await cache.image(
      for: "data:image/png;base64," + AvatarURLProtocol.png.base64EncodedString())
    XCTAssertTrue(remote === embedded)
  }

  func testFailedHTTPSAvatarDoesNotBecomeAnImage() async throws {
    let session = session()
    defer { session.invalidateAndCancel() }
    let url = try XCTUnwrap(URL(string: "https://avatars.example/unauthorized"))
    do {
      _ = try await OpenClawAvatarCache().remoteImage(for: url, session: session)
      XCTFail("An unauthorized avatar must fail")
    } catch OpenClawVoiceError.unavailable {
      // HTTP failures remain distinguishable from an absent avatar.
    }
  }

  func testInsecureAvatarURLIsNotLoaded() async throws {
    let url = try XCTUnwrap(URL(string: "http://avatars.example/avatar.png"))
    let image = try await OpenClawAvatarCache().remoteImage(for: url)
    XCTAssertNil(image)
  }

  func testOverLimitChunkedAvatarCancelsBeforeTheServerFinishes() async throws {
    let session = session()
    defer { session.invalidateAndCancel() }
    let stopped = expectation(forNotification: .init("AvatarTransferStopped"), object: nil)
    let url = try XCTUnwrap(URL(string: "https://avatars.example/oversized-chunked"))
    do {
      _ = try await OpenClawAvatarCache().remoteImage(for: url, session: session)
      XCTFail("An over-limit stream must fail before the server finishes")
    } catch OpenClawVoiceError.unavailable {}
    await fulfillment(of: [stopped], timeout: 3)
  }

  func testOversizedContentLengthCancelsBeforeReadingTheBody() async throws {
    let session = session()
    defer { session.invalidateAndCancel() }
    let stopped = expectation(forNotification: .init("AvatarKnownLengthStopped"), object: nil)
    let url = try XCTUnwrap(URL(string: "https://avatars.example/oversized-length"))
    do {
      _ = try await OpenClawAvatarCache().remoteImage(for: url, session: session)
      XCTFail("Oversized Content-Length must be rejected without waiting for the body")
    } catch OpenClawVoiceError.unavailable {}
    await fulfillment(of: [stopped], timeout: 3)
  }

  func testCancellingAvatarLoadStopsTheUnderlyingTransfer() async throws {
    let session = session()
    defer { session.invalidateAndCancel() }
    let started = expectation(forNotification: .init("AvatarTransferWaiting"), object: nil)
    let stopped = expectation(forNotification: .init("AvatarWaitingStopped"), object: nil)
    let url = try XCTUnwrap(URL(string: "https://avatars.example/waiting"))
    let loading = Task { try await OpenClawAvatarCache().remoteImage(for: url, session: session) }
    await fulfillment(of: [started], timeout: 3)
    loading.cancel()
    do {
      _ = try await loading.value
      XCTFail("A cancelled avatar load must not succeed")
    } catch is CancellationError {
    } catch {
      XCTAssertEqual((error as? URLError)?.code, .cancelled)
    }
    await fulfillment(of: [stopped], timeout: 3)
  }

  func testAvatarResponseDowngradedToHTTPIsRejected() async throws {
    let session = session()
    defer { session.invalidateAndCancel() }
    let url = try XCTUnwrap(URL(string: "https://avatars.example/downgraded"))
    do {
      _ = try await OpenClawAvatarCache().remoteImage(for: url, session: session)
      XCTFail("An HTTPS avatar must not accept an HTTP response")
    } catch OpenClawVoiceError.unavailable {}
  }

  private func session() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 5
    configuration.timeoutIntervalForResource = 5
    configuration.protocolClasses = [AvatarURLProtocol.self]
    return URLSession(configuration: configuration)
  }
}

private final class AvatarURLProtocol: URLProtocol, @unchecked Sendable {
  static let png =
    Data(
      base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
    ) ?? Data()

  override static func canInit(with request: URLRequest) -> Bool { true }
  override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url,
      let response = HTTPURLResponse(
        url: url.path == "/downgraded" ? URL(string: "http://avatars.example/avatar.png")! : url,
        statusCode: url.path == "/unauthorized" ? 401 : 200,
        httpVersion: nil,
        headerFields: url.path == "/oversized-length"
          ? ["Content-Type": "image/png", "Content-Length": "8000001"]
          : ["Content-Type": "image/png"])
    else { return }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    if url.path == "/waiting" {
      client?.urlProtocol(self, didLoad: Data([0]))
      NotificationCenter.default.post(name: .init("AvatarTransferWaiting"), object: nil)
      return
    }
    if url.path == "/oversized-length" {
      // Flush URLProtocol’s header delivery, leaving the declared body unfinished.
      client?.urlProtocol(self, didLoad: Data(repeating: 0, count: 65_536))
      return
    }
    if url.path == "/oversized-chunked" {
      client?.urlProtocol(self, didLoad: Data(repeating: 0, count: 8_000_001))
      return
    }
    client?.urlProtocol(self, didLoad: Self.png)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {
    if request.url?.path == "/waiting" {
      NotificationCenter.default.post(name: .init("AvatarWaitingStopped"), object: nil)
    }
    if request.url?.path == "/oversized-length" {
      NotificationCenter.default.post(name: .init("AvatarKnownLengthStopped"), object: nil)
    }
    if request.url?.path == "/oversized-chunked" {
      NotificationCenter.default.post(name: .init("AvatarTransferStopped"), object: nil)
    }
  }
}
