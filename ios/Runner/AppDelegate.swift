import Flutter
import UIKit
import UniformTypeIdentifiers

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HingeStatus") {
      HingeStatusStreamHandler.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IncomingFiles") {
      IncomingFilesStreamHandler.shared.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SongPicker") {
      SongPicker.shared.register(with: registrar)
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
      name: "dev.edbrsk.duoscore/vertical_bar_edge",
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

/// Streams the iPhone Duo hinge status (`UIHingeInteraction`, iOS 27.1) to
/// Dart, which shows a folded screen while the device is closed.
@MainActor  // Flutter invokes stream handlers on the platform (main) thread.
final class HingeStatusStreamHandler: NSObject, @preconcurrency FlutterStreamHandler {
  private weak var registrar: FlutterPluginRegistrar?
  private var eventSink: FlutterEventSink?
  private var interaction: UIHingeInteraction?

  static func register(with registrar: FlutterPluginRegistrar) {
    let handler = HingeStatusStreamHandler()
    handler.registrar = registrar
    FlutterEventChannel(
      name: "dev.edbrsk.duoscore/hinge_status",
      binaryMessenger: registrar.messenger()
    ).setStreamHandler(handler)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    guard let view = registrar?.viewController?.view else {
      events("unavailable")
      return nil
    }
    let interaction = UIHingeInteraction { [weak self] _, update in
      self?.send(update.hinge?.status)
    }
    view.addInteraction(interaction)
    self.interaction = interaction
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let interaction {
      interaction.view?.removeInteraction(interaction)
    }
    interaction = nil
    eventSink = nil
    return nil
  }

  private func send(_ status: UIHinge.Status?) {
    switch status {
    case .none: eventSink?("unavailable")
    case .closed: eventSink?("closed")
    case .partiallyOpen: eventSink?("partiallyOpen")
    case .fullyOpen: eventSink?("fullyOpen")
    default: eventSink?("unknown")
    }
  }
}

/// Streams files opened in DuoScore from other apps to Dart, copying them into
/// a staging folder first when they live outside Documents. Files that arrive
/// before Dart listens (a cold launch from Files) wait in `pending`.
@MainActor
final class IncomingFilesStreamHandler: NSObject, @preconcurrency FlutterStreamHandler {
  static let shared = IncomingFilesStreamHandler()

  private var eventSink: FlutterEventSink?
  private var pending: [String] = []

  func register(with registrar: FlutterPluginRegistrar) {
    FlutterEventChannel(
      name: "dev.edbrsk.duoscore/incoming_files",
      binaryMessenger: registrar.messenger()
    ).setStreamHandler(self)
  }

  func receive(_ urls: [URL]) {
    for url in urls {
      guard let staged = stage(url) else { continue }
      if let eventSink {
        eventSink(staged)
      } else {
        pending.append(staged)
      }
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    pending.forEach { events($0) }
    pending.removeAll()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  /// A JSON message for Dart: the original path, and a staged copy unless the
  /// file already lives in Documents (outside Documents/Inbox), in which case
  /// Dart opens it where it is. Dart decides what, if anything, to delete.
  private func stage(_ url: URL) -> String? {
    let fileManager = FileManager.default
    guard
      let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
      let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
    else { return nil }
    let original = url.standardizedFileURL.resolvingSymlinksInPath()
    let documentsPath = documents.standardizedFileURL.resolvingSymlinksInPath().path + "/"
    let inboxPath = documentsPath + "Inbox/"
    if original.path.hasPrefix(documentsPath) && !original.path.hasPrefix(inboxPath) {
      return message(original: original.path, staged: nil)
    }
    // Files opened in place from the Files app are security-scoped.
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let folder = caches.appendingPathComponent("incoming").appendingPathComponent(UUID().uuidString)
    let destination = folder.appendingPathComponent(url.lastPathComponent)
    do {
      try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
      try fileManager.copyItem(at: url, to: destination)
      return message(original: original.path, staged: destination.path)
    } catch {
      NSLog("DuoScore: could not stage \(url.lastPathComponent): \(error)")
      return nil
    }
  }

  private func message(original: String, staged: String?) -> String? {
    let payload: [String: Any] = ["original": original, "staged": staged ?? NSNull()]
    guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
    return String(data: data, encoding: .utf8)
  }
}

/// Shows the Files picker for songs. Chosen files go through
/// `IncomingFilesStreamHandler`, as files opened from other apps do.
@MainActor
final class SongPicker: NSObject, UIDocumentPickerDelegate {
  static let shared = SongPicker()

  /// The song types declared in Info.plist.
  private static let types: [UTType] = [
    "com.arobas-music.guitarpro.document",
    "com.arobas-music.guitarpro6.document",
    "com.arobas-music.guitarpro5.document",
    "com.arobas-music.guitarpro4.document",
    "com.arobas-music.guitarpro3.document",
    "com.recordare.musicxml.uncompressed",
    "com.recordare.musicxml",
  ].compactMap { UTType($0) } + [.xml]

  private weak var registrar: FlutterPluginRegistrar?
  private var pending: FlutterResult?

  func register(with registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    FlutterMethodChannel(
      name: "dev.edbrsk.duoscore/song_picker",
      binaryMessenger: registrar.messenger()
    ).setMethodCallHandler { [weak self] call, result in
      // Flutter calls method handlers on the platform (main) thread.
      MainActor.assumeIsolated {
        guard call.method == "pick" else { return result(FlutterMethodNotImplemented) }
        self?.present(result)
      }
    }
  }

  private func present(_ result: @escaping FlutterResult) {
    guard pending == nil, let viewController = registrar?.viewController else {
      return result(FlutterError(code: "unavailable", message: "picker already open or no view", details: nil))
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: Self.types, asCopy: true)
    picker.allowsMultipleSelection = true
    picker.delegate = self
    pending = result
    viewController.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    IncomingFilesStreamHandler.shared.receive(urls)
    // The picker's own copies; receive has staged its own.
    urls.forEach { try? FileManager.default.removeItem(at: $0) }
    pending?(urls.count)
    pending = nil
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(0)
    pending = nil
  }
}
