import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

class KubernetesLogStream {
  KubernetesLogStream({
    required this.dio,
    required this.namespace,
    required this.pod,
    this.container,
    this.follow = true,
    this.tailLines = 100,
    this.timestamps = false,
  });

  final Dio dio;
  final String namespace;
  final String pod;
  final String? container;
  final bool follow;
  final int tailLines;
  final bool timestamps;

  CancelToken? _cancelToken;
  final _lines = StreamController<String>.broadcast();

  Stream<String> get lines => _lines.stream;

  Future<void> start() async {
    _cancelToken = CancelToken();

    final queryParams = {
      'follow': '$follow',
      'tailLines': '$tailLines',
      'timestamps': '$timestamps',
      if (container != null) 'container': container!,
    };

    try {
      final response = await dio.get(
        '/api/v1/namespaces/$namespace/pods/$pod/log',
        queryParameters: queryParams,
        options: Options(responseType: ResponseType.stream),
        cancelToken: _cancelToken,
      );

      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        while (buffer.contains('\n')) {
          final idx = buffer.indexOf('\n');
          _lines.add(buffer.substring(0, idx));
          buffer = buffer.substring(idx + 1);
        }
      }

      if (buffer.isNotEmpty) {
        _lines.add(buffer);
      }
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) {
        _lines.addError('Log stream error: ${e.message}');
      }
    }
  }

  void stop() {
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  void dispose() {
    stop();
    _lines.close();
  }
}
