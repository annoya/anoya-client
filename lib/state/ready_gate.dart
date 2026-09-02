import 'package:flutter/foundation.dart' show protected;

/// The load gate every persisted notifier waits on.
///
/// A notifier that reads its state off disk starts with a default and swaps
/// the real value in a moment later. A mutation that lands in between would
/// win the race and then be overwritten by the load — or, worse, be persisted
/// on top of the default, wiping what was stored. So every mutation awaits
/// [ready] first.
///
/// Already complete until `build` replaces it, which is the truth for a
/// notifier that never scheduled a load: its state is the default, and there
/// is nothing to wait for.
mixin ReadyGate {
  @protected
  Future<void> ready = Future.value();
}
