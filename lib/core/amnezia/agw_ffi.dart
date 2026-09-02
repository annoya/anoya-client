import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

/// The Amnezia gateway's C ABI (`native/libagw`, upstream `cabi/agw.h`).
///
/// Only the transport is native, and only because of what it carries: the
/// library sends one encrypted request and, when the answer looks like
/// interference rather than a reply, resolves a pool of bypass proxies from S3
/// and walks it until one is accepted. That machinery is the reason this is a
/// linked library instead of a page of Dart — the envelope crypto alone would
/// not be worth a native dependency.
///
/// Lives in the *app* process on every platform: on Apple the engine runs in
/// the extension, on Android in `:tunnel`, and two Go runtimes cannot share
/// one process. A gateway call is ordinary HTTPS the app makes on its own
/// behalf, so it belongs here, next to where a subscription is fetched.
final class _Bindings {
  _Bindings(DynamicLibrary lib)
      : abiVersion = lib.lookupFunction<Uint32 Function(), int Function()>(
            'agw_abi_version'),
        clientCreate = lib.lookupFunction<
            UintPtr Function(Pointer<Utf8>, Pointer<Void>),
            int Function(Pointer<Utf8>, Pointer<Void>)>('agw_client_create'),
        clientDestroy =
            lib.lookupFunction<Void Function(UintPtr), void Function(int)>(
                'agw_client_destroy'),
        post = lib.lookupFunction<
            AgwResult Function(UintPtr, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, UintPtr),
            AgwResult Function(int, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int)>('agw_post'),
        resultFree = lib.lookupFunction<Void Function(Pointer<AgwResult>),
            void Function(Pointer<AgwResult>)>('agw_result_free'),
        cancelCreate =
            lib.lookupFunction<UintPtr Function(), int Function()>('agw_cancel_create'),
        cancelCancel =
            lib.lookupFunction<Void Function(UintPtr), void Function(int)>('agw_cancel_cancel'),
        cancelDestroy =
            lib.lookupFunction<Void Function(UintPtr), void Function(int)>('agw_cancel_destroy'),
        exportState = lib.lookupFunction<Pointer<Utf8> Function(UintPtr),
            Pointer<Utf8> Function(int)>('agw_export_state'),
        importState = lib.lookupFunction<Int32 Function(UintPtr, Pointer<Utf8>),
            int Function(int, Pointer<Utf8>)>('agw_import_state'),
        stringFree = lib.lookupFunction<Void Function(Pointer<Utf8>),
            void Function(Pointer<Utf8>)>('agw_string_free');

  final int Function() abiVersion;
  final int Function(Pointer<Utf8>, Pointer<Void>) clientCreate;
  final void Function(int) clientDestroy;
  final AgwResult Function(int, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int) post;
  final void Function(Pointer<AgwResult>) resultFree;
  final int Function() cancelCreate;
  final void Function(int) cancelCancel;
  final void Function(int) cancelDestroy;
  final Pointer<Utf8> Function(int) exportState;
  final int Function(int, Pointer<Utf8>) importState;
  final void Function(Pointer<Utf8>) stringFree;

  /// On Apple the archive is linked into the app binary, so the symbols are
  /// already in this process; on Android the library is its own .so.
  ///
  /// `AGW_LIBRARY` points at a locally built shared library instead. It is how
  /// the transport gets exercised against the real gateway without launching
  /// the app — the alternative being to trust an untested binding until a user
  /// hits it.
  static DynamicLibrary _open() {
    final override = Platform.environment['AGW_LIBRARY'] ?? '';
    if (override.isNotEmpty) return DynamicLibrary.open(override);
    return Platform.isAndroid
        ? DynamicLibrary.open('libagw.so')
        : DynamicLibrary.process();
  }

  static _Bindings? _cached;
  static _Bindings get instance => _cached ??= _Bindings(_open());
}

/// The library's callbacks are deliberately not installed.
///
/// They hand out a `const char*` that Go frees as soon as the callback
/// returns, and Go calls them from its own threads — so a Dart callback has to
/// be a `NativeCallable.listener`, which runs *later*, on the isolate's event
/// loop, by which time the pointer is freed memory. Reading it produced
/// garbage and a stream of unhandled decode failures. A synchronous callback
/// would copy in time but would be invoked on a thread with no Dart isolate,
/// which is a crash rather than an exception.
///
/// The account of each request comes from the Go side instead (see
/// `native/libagw/libagw.go`), where the string is still alive.

/// `agw_result` — a struct returned by value.
final class AgwResult extends Struct {
  @Int32()
  external int code;
  external Pointer<Uint8> body;
  @Size()
  external int bodyLen;
}

/// The codes the gateway answers with. Numbering is the Amnezia client's own
/// 1100-series and must not be renumbered — it is the shared vocabulary
/// between their gateway, their client and ours.
class AgwStatus {
  static const ok = 0;
  static const cancelled = 1;
  static const downloadError = 1100;
  static const alreadyAdded = 1101;
  static const emptyConfig = 1102;
  static const timeout = 1103;
  static const sslError = 1104;
  static const missingPublicKey = 1105;
  static const decryptionError = 1106;
  static const servicesMissing = 1107;
  static const configLimit = 1108;
  static const notFound = 1109;
  static const migration = 1110;
  static const updateRequired = 1111;
  static const subscriptionExpired = 1112;
  static const purchaseError = 1113;
  static const subscriptionNotActive = 1114;
  static const noPurchasedSubscriptions = 1115;
  static const trialAlreadyUsed = 1116;
  static const captchaRequired = 1117;
  static const captchaInvalid = 1118;
  static const captchaRefresh = 1119;
  static const rateLimit = 1120;
}

/// What one gateway call produced: a code, and whatever body came with it.
///
/// The body is meaningful even when the code is not [AgwStatus.ok] — a refusal
/// carries the reason, and a captcha challenge carries the image.
class AgwResponse {
  const AgwResponse(this.code, this.body);

  final int code;
  final String body;

  bool get ok => code == AgwStatus.ok;

  Map<String, dynamic> get json {
    if (body.isEmpty) return const {};
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }
}

/// How a client is configured. Every value is a build-time secret except the
/// timeouts (see `AmneziaEnv`); none of it is derivable at runtime.
class AgwConfig {
  const AgwConfig({
    required this.endpoint,
    required this.publicKeyPem,
    this.s3Primary = const [],
  });

  final String endpoint;
  final String publicKeyPem;
  final List<String> s3Primary;

  Map<String, dynamic> toJson() => {
        'gateway_endpoint': endpoint,
        // Real newlines, byte for byte as shipped: the same PEM text is the
        // SHA-512 input that unlocks the S3 proxy lists, so reformatting it
        // silently disables the bypass path.
        'public_key_pem': publicKeyPem,
        if (s3Primary.isNotEmpty) 's3_primary_endpoints': s3Primary,
      };
}

/// One gateway call, executed off the platform thread.
///
/// [post] blocks for the whole failover sweep — the library has per-request
/// timeouts but no overall deadline, and a long proxy pool can run for
/// minutes. So every call runs in its own isolate and carries a deadline of
/// our own, enforced through the library's cancel handle rather than by
/// abandoning the isolate.
class AgwClient {
  AgwClient(this.config, {this.timeout = const Duration(seconds: 45)});

  final AgwConfig config;
  final Duration timeout;

  /// Bypass state (the working proxy and the pools it came from) as an opaque
  /// blob. Worth persisting so a user who needed a proxy once does not pay the
  /// discovery sweep again; worth protecting, because it names the bypass
  /// endpoints.
  String state = '';

  Future<AgwResponse> post(
    String endpoint,
    Map<String, dynamic> payload, {
    String serviceType = '',
    String userCountryCode = '',
  }) async {
    // The deadline the library does not have, armed here rather than inside
    // the worker: `post` blocks its isolate's only thread, so a timer sharing
    // that isolate would never get to run. A cancel handle is a plain integer
    // and safe to poke from anywhere, and cancellation is checked between
    // attempts — so the sweep stops within one in-flight request instead of
    // running to the end of the proxy pool.
    final b = _Bindings.instance;
    final cancel = b.cancelCreate();
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
    final watchdog = Timer(timeout, () => b.cancelCancel(cancel));
    try {
      final result = await Isolate.run(() => _postSync(call));
      if (result.state.isNotEmpty) state = result.state;
      return AgwResponse(result.code, result.body);
    } finally {
      watchdog.cancel();
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

  /// Created and destroyed by the caller, so the deadline can outlive the
  /// blocked worker.
  final int cancel;
}

class _AgwOutcome {
  const _AgwOutcome(this.code, this.body, this.state);
  final int code;
  final String body;
  final String state;
}

/// The blocking half, running in a fresh isolate with its own view of the
/// library. Every allocation here is freed here: the C side hands back
/// malloc'd memory and nothing else will release it.
_AgwOutcome _postSync(_AgwCall call) {
  final b = _Bindings.instance;
  final configPtr = call.configJson.toNativeUtf8();
  final client = b.clientCreate(configPtr, nullptr);
  calloc.free(configPtr);
  if (client == 0) {
    // Refused before any request: malformed config, or no endpoint/key. A
    // missing key is the one the user could plausibly hit (a build without
    // the gateway secrets), so it gets that code rather than a generic one.
    return const _AgwOutcome(AgwStatus.missingPublicKey, '', '');
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
    holder.ref = b.post(client, endpointPtr, payloadPtr, optionsPtr, call.cancel);
    final r = holder.ref;
    final body = r.body == nullptr
        ? ''
        : utf8.decode(r.body.asTypedList(r.bodyLen), allowMalformed: true);
    final code = r.code;
    b.resultFree(holder);

    // Only worth carrying forward when a sweep actually happened; exporting is
    // cheap, so it is done on every call rather than guessed at.
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
