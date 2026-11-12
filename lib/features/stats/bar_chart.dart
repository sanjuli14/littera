import 'package:flutter/material.dart';

import '../../app/theme/littera_colors.dart';

const _weekdayInitials = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// Barras de una sola serie por día (sin leyenda: el título dice qué mide).
///
/// Barras finas con extremo redondeado de 4 px apoyado en la línea base,
/// 2 px de separación, eje discreto y valor al tocar cada barra.
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({
    super.key,
    required this.days,
    required this.values,
    required this.formatValue,
    required this.semanticsLabel,
    this.height = 120,
  });

  final List<DateTime> days;
  final List<int> values;

  /// `45` → `45 min`.
  final String Function(int value) formatValue;

  /// Resumen leído por lectores de pantalla.
  final String semanticsLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final barColor = dark
        ? LitteraColors.oroGraficaOscuro
        : LitteraColors.oroGrafica;
    final muted = theme.colorScheme.onSurfaceVariant;
    final maxValue = values.fold<int>(0, (a, b) => b > a ? b : a);
    final today = DateTime.now();

    return Semantics(
      label: semanticsLabel,
      container: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            maxValue == 0 ? 'Sin actividad' : 'Máx. ${formatValue(maxValue)}',
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      message:
                          '${days[i].day}/${days[i].month}: '
                          '${formatValue(values[i])}',
                      child: Container(
                        // Área de toque más grande que la barra.
                        color: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: maxValue == 0
                              ? 0
                              : (values[i] / maxValue).clamp(0.0, 1.0),
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: 2,
                              maxWidth: 18,
                            ),
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final d in days)
                Expanded(
                  child: Text(
                    _weekdayInitials[d.weekday - 1],
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _sameDay(d, today)
                          ? theme.colorScheme.onSurface
                          : muted,
                      fontWeight: _sameDay(d, today) ? FontWeight.w700 : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
