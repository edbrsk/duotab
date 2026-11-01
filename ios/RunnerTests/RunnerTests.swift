import AVFoundation
import Flutter
import UIKit
import XCTest

@testable import Runner

@MainActor
class RunnerTests: XCTestCase {

  func testListeningTwiceSendsOneLatencyPerRouteChange() {
    let handler = OutputLatencyStreamHandler()
    var sent = 0
    _ = handler.onListen(withArguments: nil) { _ in sent += 1 }
    _ = handler.onListen(withArguments: nil) { _ in sent += 1 }
    sent = 0

    NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    XCTAssertEqual(sent, 1)
    _ = handler.onCancel(withArguments: nil)
  }

}
