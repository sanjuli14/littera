/// Cuenta el tiempo de lectura activa.
///
/// Solo suma mientras el lector está visible, y deja de contar si pasan
/// [idleLimit] sin actividad (pasar página, desplazarse), para no anotar
/// horas si el libro se queda abierto.
class ReadingTracker {
  ReadingTracker({
    required this.onFlush,
    this.idleLimit = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    final now = _clock();
    _since = now;
    _lastActivity = now;
  }

  /// Recibe los segundos acumulados y el momento en que se anotan.
  final void Function(int seconds, DateTime at) onFlush;
  final Duration idleLimit;
  final DateTime Function() _clock;

  late DateTime _since;
  late DateTime _lastActivity;
  bool _paused = false;

  /// El usuario hizo algo (pasar página, desplazarse).
  void activity() {
    final now = _clock();
    if (_paused) return;
    // Si estuvo inactivo demasiado, lo anterior ya se cerró: empieza de nuevo.
    if (now.difference(_lastActivity) > idleLimit) {
      flush();
      _since = now;
    }
    _lastActivity = now;
  }

  /// Anota el tiempo acumulado hasta ahora (o hasta que se quedó inactivo).
  void flush() {
    if (_paused) return;
    final now = _clock();
    final limit = _lastActivity.add(idleLimit);
    final end = now.isAfter(limit) ? limit : now;
    final seconds = end.difference(_since).inSeconds;
    if (seconds > 0) onFlush(seconds, now);
    _since = end.isAfter(_since) ? end : _since;
  }

  /// La app pasó a segundo plano.
  void pause() {
    flush();
    _paused = true;
  }

  /// La app volvió al primer plano.
  void resume() {
    if (!_paused) return;
    _paused = false;
    final now = _clock();
    _since = now;
    _lastActivity = now;
  }
}
