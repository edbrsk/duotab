import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  EngineHost._(this.controller, this.transport);

  factory EngineHost(Uri engineUri) {
    final transport = WebViewTransport();
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.paper)
      ..addJavaScriptChannel(
        'DuoTab',
        onMessageReceived: (m) => transport._incoming.add(m.message),
      );
    transport._controller = controller;
    unawaited(controller.loadRequest(engineUri));
    return EngineHost._(controller, transport);
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
