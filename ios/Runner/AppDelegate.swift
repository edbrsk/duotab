import Flutter
import PDFKit
import UIKit
import UniformTypeIdentifiers
import WebKit

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SongExport") {
      SongExport.shared.register(with: registrar)
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
      // A file that can't be staged is still reported, so Dart can say so.
      guard let event = stage(url) ?? failure(url.lastPathComponent) else { continue }
      if let eventSink {
        eventSink(event)
      } else {
        pending.append(event)
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
      // A coordinated read waits for iCloud to download a file not yet on the phone.
      var coordination: NSError?
      var copying: Error?
      NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordination) { readable in
        do {
          try fileManager.copyItem(at: readable, to: destination)
        } catch {
          copying = error
        }
      }
      if let failure = coordination ?? copying { throw failure }
      return message(original: original.path, staged: destination.path)
    } catch {
      NSLog("DuoScore: could not stage \(url.lastPathComponent): \(error)")
      return nil
    }
  }

  private func failure(_ name: String) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: ["error": name]) else { return nil }
    return String(data: data, encoding: .utf8)
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

/// Renders the engine's page documents, one HTML document per A4 page, into
/// one PDF, and shares files through the share sheet.
@MainActor
final class SongExport: NSObject, WKNavigationDelegate {
  static let shared = SongExport()

  private static let page = CGRect(x: 0, y: 0, width: 595, height: 842)

  private static let pageLoadLimit: Duration = .seconds(20)

  private weak var registrar: FlutterPluginRegistrar?
  private var rendering = false
  private var loading: CheckedContinuation<Void, Error>?
  private var navigation: WKNavigation?
  private var loads = 0

  func register(with registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    FlutterMethodChannel(
      name: "dev.edbrsk.duoscore/export",
      binaryMessenger: registrar.messenger()
    ).setMethodCallHandler { [weak self] call, result in
      // Flutter calls method handlers on the platform (main) thread.
      MainActor.assumeIsolated {
        guard let self, let arguments = call.arguments as? [String: Any] else {
          return result(FlutterMethodNotImplemented)
        }
        switch call.method {
        case "pdf": self.pdf(arguments, result)
        case "share": self.share(arguments, result)
        default: result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  private func pdf(_ arguments: [String: Any], _ result: @escaping FlutterResult) {
    guard
      !rendering,
      let pages = arguments["pages"] as? [String],
      let baseUrl = arguments["baseUrl"] as? String,
      let path = arguments["path"] as? String,
      let view = registrar?.viewController?.view
    else {
      return result(FlutterError(code: "unavailable", message: "a PDF is being made, or no view", details: nil))
    }
    rendering = true
    Task {
      defer { rendering = false }
      do {
        try await render(pages, baseURL: URL(string: baseUrl), to: URL(fileURLWithPath: path), in: view)
        result(nil)
      } catch {
        result(FlutterError(code: "pdf_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func render(_ pages: [String], baseURL: URL?, to url: URL, in view: UIView) async throws {
    // In the window, so WebKit lays it out, but off screen.
    let webView = WKWebView(frame: Self.page.offsetBy(dx: -10_000, dy: 0))
    webView.isUserInteractionEnabled = false
    webView.navigationDelegate = self
    view.addSubview(webView)
    defer { webView.removeFromSuperview() }
    let document = PDFDocument()
    for page in pages {
      try await load(page, baseURL: baseURL, in: webView)
      // The music glyphs are text in Bravura; a page captured before the font
      // arrives shows boxes.
      // fonts.load resolves empty, not with an error, when the font is missing.
      let fontReady = try await webView.callAsyncJavaScript(
        "await document.fonts.load(\"34px alphaTab\"); await document.fonts.ready; return document.fonts.check(\"34px alphaTab\");",
        contentWorld: .page
      )
      guard fontReady as? Bool == true else { throw ExportError.fontMissing }
      // Exactly one A4 page; a part taller than the page is clipped, not stretched.
      let configuration = WKPDFConfiguration()
      configuration.rect = Self.page
      let data = try await webView.pdf(configuration: configuration)
      guard let rendered = PDFDocument(data: data)?.page(at: 0) else { throw ExportError.emptyPage }
      document.insert(rendered, at: document.pageCount)
    }
    guard document.write(to: url) else { throw ExportError.notWritten }
  }

  /// Fails after `pageLoadLimit`, so a load that never reports back cannot
  /// hold the export, and every later one, forever.
  private func load(_ page: String, baseURL: URL?, in webView: WKWebView) async throws {
    loads += 1
    let current = loads
    try await withCheckedThrowingContinuation { continuation in
      loading = continuation
      navigation = webView.loadHTMLString(page, baseURL: baseURL)
      Task { [weak self] in
        try? await Task.sleep(for: Self.pageLoadLimit)
        if self?.loads == current { self?.finishLoading(ExportError.pageTimedOut) }
      }
    }
  }

  /// Only the load this export started finishes it; a report for another
  /// navigation (a reload, an earlier page) is ignored.
  private func finishLoading(_ error: Error?, for navigation: WKNavigation? = nil) {
    guard let loading else { return }
    if let navigation, navigation !== self.navigation { return }
    self.loading = nil
    self.navigation = nil
    if let error { loading.resume(throwing: error) } else { loading.resume() }
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    finishLoading(nil, for: navigation)
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    finishLoading(error, for: navigation)
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error
  ) {
    finishLoading(error, for: navigation)
  }

  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    finishLoading(ExportError.webViewEnded)
  }

  private func share(_ arguments: [String: Any], _ result: @escaping FlutterResult) {
    guard let paths = arguments["paths"] as? [String], let viewController = registrar?.viewController else {
      return result(FlutterError(code: "unavailable", message: "no view", details: nil))
    }
    // UIKit silently refuses to present from a controller that is already
    // presenting, such as the Files picker, and would never complete.
    var presenter: UIViewController = viewController
    while let presented = presenter.presentedViewController { presenter = presented }
    if presenter is UIActivityViewController {
      return result(FlutterError(code: "unavailable", message: "share sheet already open", details: nil))
    }
    let anchor = CGRect(
      x: arguments["x"] as? Double ?? 0,
      y: arguments["y"] as? Double ?? 0,
      width: arguments["width"] as? Double ?? 0,
      height: arguments["height"] as? Double ?? 0
    )
    let sheet = UIActivityViewController(
      activityItems: paths.map { URL(fileURLWithPath: $0) },
      applicationActivities: nil
    )
    // In regular width the sheet is a popover, which UIKit refuses to show
    // without an anchor; the anchor is in the Flutter view's coordinates.
    sheet.popoverPresentationController?.sourceView = viewController.view
    sheet.popoverPresentationController?.sourceRect = anchor
    // It also fires when a cancelled activity such as Mail returns to the
    // sheet; Flutter takes one reply.
    var replied = false
    sheet.completionWithItemsHandler = { _, completed, _, _ in
      guard !replied else { return }
      replied = true
      result(completed)
    }
    presenter.present(sheet, animated: true)
  }
}

enum ExportError: LocalizedError {
  case emptyPage, notWritten, pageTimedOut, webViewEnded, fontMissing

  var errorDescription: String? {
    switch self {
    case .emptyPage: "WebKit made an empty page"
    case .notWritten: "the PDF could not be written"
    case .pageTimedOut: "a page took too long to load"
    case .webViewEnded: "the page renderer stopped"
    case .fontMissing: "the music font didn't load"
    }
  }
}
