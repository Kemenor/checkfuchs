/// The injected clock. The whole domain engine reads "now" through this, so the
/// time-travel tests (jump 3 days → the right Misses appear) are deterministic.
/// Production uses [SystemClock]; tests use [FixedClock].
abstract interface class Clock {
  DateTime now();
}

/// Real wall-clock time.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A controllable clock for tests.
class FixedClock implements Clock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime value) => _now = value;
  void advance(Duration by) => _now = _now.add(by);
}
