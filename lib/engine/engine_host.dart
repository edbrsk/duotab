import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../core/dependency_injection.dart';
import '../core/design/design_tokens.dart';
import 'engine_transport.dart';

class WebViewTransport implements EngineTransport {
  // Lives as long as the app's single web view, so it is never closed.
  // ignore: close_sinks
  final _incoming = StreamController<String>.broadcast();
  late final WebViewController _controller;

  @override
  Future<void> send(String json) =>
      // jsonEncode turns the message into a safely quoted JS string literal.
      _controller.runJavaScript('window.duotab.handle(${jsonEncode(json)})');

  @override
  Stream<String> get incoming => _incoming.stream;
}

/// The one web view running the alphaTab engine for the app's lifetime.
class EngineHost {
  final WebViewController controller;
  final WebViewTransport transport;

  /// Called after iOS killed the page's process (memory pressure, often in
  /// the background) and the page started reloading.
  void Function()? onRestart;

  EngineHost._(this.controller, this.transport);

  factory EngineHost(Uri engineUri) {
    final transport = WebViewTransport();
    // Lets audio start from Flutter's play button, which is outside the page
    // and so never counts as a user gesture for WebKit.
    final controller = WebViewController.fromPlatformCreationParams(
      WebKitWebViewControllerCreationParams(
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        allowsInlineMediaPlayback: true,
      ),
    );
    final host = EngineHost._(controller, transport);
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.paper)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (error.errorType ==
                WebResourceErrorType.webContentProcessTerminated) {
              // Reset the bridge first, so the reloaded page's ready is not missed.
              host.onRestart?.call();
              unawaited(controller.reload());
            }
          },
        ),
      )
      ..setOnConsoleMessage((m) {
        // The page's own warnings and errors, in the device log while developing.
        if (kDebugMode) debugPrint('engine ${m.level.name}: ${m.message}');
      })
      ..addJavaScriptChannel(
        'DuoTab',
        onMessageReceived: (m) => transport._incoming.add(m.message),
      );
    transport._controller = controller;
    unawaited(controller.loadRequest(engineUri));
    return host;
  }
}

/// Shows the engine's web view where it sits.
class EngineView extends StatelessWidget {
  final EngineHost? host;

  const EngineView({this.host, super.key});

  @override
  Widget build(BuildContext context) =>
      WebViewWidget(controller: (host ?? getIt<EngineHost>()).controller);
}
