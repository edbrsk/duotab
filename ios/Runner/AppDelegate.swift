import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VerticalBarEdge") {
      VerticalBarEdgeStreamHandler.register(with: registrar)
    }
  }
}

/// Streams `UITraitCollection.verticalBarEdge` to Dart so Flutter can place its
/// navigation in the iPhone Duo's vertical bar, as UIKit does for native bars.
@MainActor  // Flutter invokes stream handlers on the platform (main) thread.
final class VerticalBarEdgeStreamHandler: NSObject, @preconcurrency FlutterStreamHandler {
  private weak var registrar: FlutterPluginRegistrar?
  private var eventSink: FlutterEventSink?
  private var traitRegistration: UITraitChangeRegistration?

  static func register(with registrar: FlutterPluginRegistrar) {
    let handler = VerticalBarEdgeStreamHandler()
    handler.registrar = registrar
    FlutterEventChannel(
      name: "me.withedgar.duotab/vertical_bar_edge",
      binaryMessenger: registrar.messenger()
    ).setStreamHandler(handler)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    guard let viewController = registrar?.viewController else {
      events("unspecified")
      return nil
    }
    traitRegistration = viewController.registerForTraitChanges(
      UITraitCollection.systemTraitsAffectingVerticalBarEdge
    ) { [weak self] (viewController: UIViewController, _: UITraitCollection) in
      self?.send(viewController.traitCollection)
    }
    send(viewController.traitCollection)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let traitRegistration {
      registrar?.viewController?.unregisterForTraitChanges(traitRegistration)
    }
    traitRegistration = nil
    eventSink = nil
    return nil
  }

  private func send(_ traitCollection: UITraitCollection) {
    switch traitCollection.verticalBarEdge {
    case .leading: eventSink?("leading")
    case .trailing: eventSink?("trailing")
    default: eventSink?("unspecified")
    }
  }
}
