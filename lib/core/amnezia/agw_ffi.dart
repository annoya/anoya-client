import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

final class _Bindings {
  _Bindings(DynamicLibrary lib)
    : abiVersion = lib.lookupFunction<Uint32 Function(), int Function()>(
        'agw_abi_version',
      ),
      clientCreate = lib
          .lookupFunction<
            UintPtr Function(Pointer<Utf8>, Pointer<Void>),
            int Function(Pointer<Utf8>, Pointer<Void>)
          >('agw_client_create'),
      clientDestroy = lib
          .lookupFunction<Void Function(UintPtr), void Function(int)>(
            'agw_client_destroy',
          ),
      post = lib
          .lookupFunction<
            AgwResult Function(
              UintPtr,
              Pointer<Utf8>,
              Pointer<Utf8>,
              Pointer<Utf8>,
              UintPtr,
            ),
            AgwResult Function(
              int,
              Pointer<Utf8>,
              Pointer<Utf8>,
              Pointer<Utf8>,
              int,
            )
          >('agw_post'),
      resultFree = lib
          .lookupFunction<
            Void Function(Pointer<AgwResult>),
            void Function(Pointer<AgwResult>)
          >('agw_result_free'),
      cancelCreate = lib.lookupFunction<UintPtr Function(), int Function()>(
        'agw_cancel_create',
      ),
      cancelCancel = lib
          .lookupFunction<Void Function(UintPtr), void Function(int)>(
            'agw_cancel_cancel',
          ),
      cancelDestroy = lib
          .lookupFunction<Void Function(UintPtr), void Function(int)>(
            'agw_cancel_destroy',
          ),
      exportState = lib
          .lookupFunction<
            Pointer<Utf8> Function(UintPtr),
            Pointer<Utf8> Function(int)
          >('agw_export_state'),
      importState = lib
          .lookupFunction<
            Int32 Function(UintPtr, Pointer<Utf8>),
            int Function(int, Pointer<Utf8>)
          >('agw_import_state'),
      stringFree = lib
          .lookupFunction<
            Void Function(Pointer<Utf8>),
            void Function(Pointer<Utf8>)
          >('agw_string_free');

  final int Function() abiVersion;
  final int Function(Pointer<Utf8>, Pointer<Void>) clientCreate;
  final void Function(int) clientDestroy;
  final AgwResult Function(
    int,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    int,
  )
  post;
  final void Function(Pointer<AgwResult>) resultFree;
  final int Function() cancelCreate;
  final void Function(int) cancelCancel;
  final void Function(int) cancelDestroy;
  final Pointer<Utf8> Function(int) exportState;
  final int Function(int, Pointer<Utf8>) importState;
  final void Function(Pointer<Utf8>) stringFree;

  static DynamicLibrary _open() {
    final override = Platform.environment['AGW_LIBRARY'] ?? '';
    if (override.isNotEmpty) return DynamicLibrary.open(override);
    // dlopen by name searches the Flutter engine's rpath, not ours.
    if (Platform.isAndroid) return DynamicLibrary.open('libagw.so');
    if (Platform.isWindows) return DynamicLibrary.open('libagw.dll');
    if (Platform.isLinux) {
      final dir = File(Platform.resolvedExecutable).parent.path;
      return DynamicLibrary.open('$dir/lib/libagw.so');
    }
    return DynamicLibrary.process();
  }

  static _Bindings? _cached;
  static _Bindings get instance => _cached ??= _Bindings(_open());
}

final class AgwResult extends Struct {
  @Int32()
  external int code;
  external Pointer<Uint8> body;
  @Size()
  external int bodyLen;
}

class AgwStatus {
  static const ok = 0;

  static const cancelled = 1;

  static const invalidArgument = 2;

  static const config = 3;
  static const timeout = 4;

  static const ssl = 5;

  static const network = 6;

  static const decrypt = 7;

  static String describe(int code) => switch (code) {
    ok => 'ok',
    cancelled => 'cancelled',
    invalidArgument => 'invalid argument',
    config => 'gateway public key missing or invalid',
    timeout => 'request timed out',
    ssl => 'tls error',
    network => 'gateway unreachable',
    decrypt => 'response decryption failed',
    _ => 'unknown error',
  };
}

class AgwResponse {
  const AgwResponse(this.code, this.body);

  final int code;
  final String body;

  bool get ok => code == AgwStatus.ok && httpStatus < 300;

  int get httpStatus {
    final v = json['http_status'];
    return v is int ? v : 0;
  }

  String get message {
    final v = json['message'];
    return v is String ? v.trim() : '';
  }

  Map<String, dynamic> get json {
    if (body.isEmpty) return const {};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }
}

class AgwConfig {
  const AgwConfig({
    required this.endpoint,
    required this.publicKeyPem,
    this.s3Primary = const [],
    this.s3Fallback = const [],
  });

  final String endpoint;
  final String publicKeyPem;
  final List<String> s3Primary;

  final List<String> s3Fallback;

  Map<String, dynamic> toJson() => {
    'gateway_endpoint': endpoint,
    // The exact PEM bytes are the SHA-512 key to the proxy lists; do not reformat.
    'public_key_pem': publicKeyPem,
    if (s3Primary.isNotEmpty) 's3_primary_endpoints': s3Primary,
    if (s3Fallback.isNotEmpty) 's3_fallback_endpoints': s3Fallback,
  };
}

class AgwClient {
  AgwClient(this.config);

  final AgwConfig config;

  String state = '';

  Future<void> _tail = Future.value();
  int _generation = 0;
  int? _running;

  void cancelAll() {
    _generation++;
    final running = _running;
    if (running != null) _Bindings.instance.cancelCancel(running);
  }

  Future<AgwResponse> post(
    String endpoint,
    Map<String, dynamic> payload, {
    String serviceType = '',
    String userCountryCode = '',
  }) {
    final generation = _generation;
    final turn = _tail.then(
      (_) => _post(
        endpoint,
        payload,
        serviceType: serviceType,
        userCountryCode: userCountryCode,
        generation: generation,
      ),
    );
    _tail = turn.then((_) {}, onError: (_) {});
    return turn;
  }

  Future<AgwResponse> _post(
    String endpoint,
    Map<String, dynamic> payload, {
    required String serviceType,
    required String userCountryCode,
    required int generation,
  }) async {
    if (generation != _generation) {
      return const AgwResponse(AgwStatus.cancelled, '');
    }
    // `post` blocks the worker isolate's only thread, so only this isolate can cancel it.
    final b = _Bindings.instance;
    final cancel = b.cancelCreate();
    _running = cancel;
    final call = _AgwCall(
      configJson: jsonEncode(config.toJson()),
      state: state,
      endpoint: endpoint,
      payloadJson: jsonEncode(payload),
      optionsJson: jsonEncode({
        if (serviceType.isNotEmpty) 'service_type': serviceType,
        if (userCountryCode.isNotEmpty) 'user_country_code': userCountryCode,
      }),
      cancel: cancel,
    );
    try {
      final result = await Isolate.run(() => _postSync(call));
      if (result.state.isNotEmpty) state = result.state;
      return AgwResponse(result.code, result.body);
    } finally {
      _running = null;
      b.cancelDestroy(cancel);
    }
  }
}

class _AgwCall {
  const _AgwCall({
    required this.configJson,
    required this.state,
    required this.endpoint,
    required this.payloadJson,
    required this.optionsJson,
    required this.cancel,
  });

  final String configJson;
  final String state;
  final String endpoint;
  final String payloadJson;
  final String optionsJson;

  final int cancel;
}

class _AgwOutcome {
  const _AgwOutcome(this.code, this.body, this.state);
  final int code;
  final String body;
  final String state;
}

_AgwOutcome _postSync(_AgwCall call) {
  final b = _Bindings.instance;
  final configPtr = call.configJson.toNativeUtf8();
  final client = b.clientCreate(configPtr, nullptr);
  calloc.free(configPtr);
  if (client == 0) {
    return const _AgwOutcome(AgwStatus.config, '', '');
  }

  final endpointPtr = call.endpoint.toNativeUtf8();
  final payloadPtr = call.payloadJson.toNativeUtf8();
  final optionsPtr = call.optionsJson.toNativeUtf8();
  final holder = calloc<AgwResult>();
  try {
    if (call.state.isNotEmpty) {
      final statePtr = call.state.toNativeUtf8();
      b.importState(client, statePtr);
      calloc.free(statePtr);
    }
    holder.ref = b.post(
      client,
      endpointPtr,
      payloadPtr,
      optionsPtr,
      call.cancel,
    );
    final r = holder.ref;
    final body = r.body == nullptr
        ? ''
        : utf8.decode(r.body.asTypedList(r.bodyLen), allowMalformed: true);
    final code = r.code;
    b.resultFree(holder);

    var exported = '';
    final statePtr = b.exportState(client);
    if (statePtr != nullptr) {
      exported = statePtr.toDartString();
      b.stringFree(statePtr);
    }
    return _AgwOutcome(code, body, exported);
  } finally {
    calloc.free(holder);
    calloc.free(endpointPtr);
    calloc.free(payloadPtr);
    calloc.free(optionsPtr);
    b.clientDestroy(client);
  }
}
