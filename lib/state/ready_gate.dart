import 'package:flutter/foundation.dart' show protected;

mixin ReadyGate {
  @protected
  Future<void> ready = Future.value();
}
