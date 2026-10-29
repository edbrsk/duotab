abstract interface class EngineTransport {
  Future<void> send(String json);

  Stream<String> get incoming;
}
