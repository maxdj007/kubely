import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

class KubernetesExecSession {
  KubernetesExecSession({
    required this.server,
    required this.namespace,
    required this.pod,
    required this.container,
    this.token,
    this.command = '/bin/sh',
  });

  final String server;
  final String namespace;
  final String pod;
  final String container;
  final String? token;
  final String command;

  WebSocketChannel? _channel;
  final _stdout = StreamController<String>.broadcast();
  final _stderr = StreamController<String>.broadcast();
  bool _connected = false;

  Stream<String> get stdout => _stdout.stream;
  Stream<String> get stderr => _stderr.stream;
  bool get isConnected => _connected;

  Future<void> connect() async {
    final wsScheme = server.startsWith('https') ? 'wss' : 'ws';
    final host = server.replaceAll(RegExp(r'https?://'), '');
    final uri = Uri.parse(
      '$wsScheme://$host/api/v1/namespaces/$namespace/pods/$pod/exec'
      '?container=$container'
      '&stdin=true&stdout=true&stderr=true&tty=true'
      '&command=${Uri.encodeComponent(command)}',
    );

    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['v4.channel.k8s.io'],
      );
      _connected = true;

      _channel!.stream.listen(
        (data) {
          if (data is List<int> && data.isNotEmpty) {
            final channel = data[0];
            final payload = utf8.decode(data.sublist(1), allowMalformed: true);
            switch (channel) {
              case 1:
                _stdout.add(payload);
              case 2:
                _stderr.add(payload);
              case 3:
                // resize response — ignore
                break;
            }
          } else if (data is String) {
            _stdout.add(data);
          }
        },
        onError: (error) {
          _stderr.add('Connection error: $error');
          _connected = false;
        },
        onDone: () {
          _connected = false;
          _stdout.add('\n[connection closed]');
        },
      );
    } catch (e) {
      _stderr.add('Failed to connect: $e');
      _connected = false;
    }
  }

  void sendStdin(String input) {
    if (_channel == null || !_connected) return;
    // Channel 0 = stdin
    final payload = Uint8List(input.length + 1);
    payload[0] = 0; // stdin channel
    payload.setRange(1, payload.length, utf8.encode(input));
    _channel!.sink.add(payload);
  }

  void sendResize(int cols, int rows) {
    if (_channel == null || !_connected) return;
    // Channel 3 = resize
    final json = '{"Width":$cols,"Height":$rows}';
    final payload = Uint8List(json.length + 1);
    payload[0] = 3; // resize channel
    payload.setRange(1, payload.length, utf8.encode(json));
    _channel!.sink.add(payload);
  }

  Future<void> disconnect() async {
    _connected = false;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _stdout.close();
    _stderr.close();
  }
}
