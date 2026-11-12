import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme/littera_colors.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../data/repositories/writing_repository.dart';
import '../library/widgets/book_cover.dart';
import '../writing/word_count.dart';
import '../writing/writing_screen.dart';
import 'bar_chart.dart';

const chartDays = 14;

/// `75` min → `1 h 15 min`.
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

String _days(int n) => n == 1 ? '1 día' : '$n días';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Se recalcula cuando cambian lecturas, escritura o libros.
    ref.watch(readingLogProvider);
    ref.watch(writingLogProvider);
    ref.watch(booksProvider);
    final settings = ref.watch(settingsProvider);
    final stats = ref.read(statsRepositoryProvider);

    final now = DateTime.now();
    final days = lastDays(chartDays, now);
    final readingByDay = stats.readingSecondsByDay();
    final wordsByDay = stats.wordsByDay();
    final minutes = [
      for (final d in days) (readingByDay[dayKey(d)] ?? 0) ~/ 60,
    ];
    final words = [for (final d in days) wordsByDay[dayKey(d)] ?? 0];
    final todayMinutes = minutes.last;
    final todayWords = words.last;
    final finished = stats.finishedInYear(now.year);
    final goal = settings.annualBookGoal;
    final dailyGoal = settings.dailyReadingMinutes;

    final theme = Theme.of(context);
    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Metas',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _GoalsDialog(),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          section('Lectura'),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.local_fire_department_outlined,
                    value: _days(stats.readingStreak(now)),
                    label: 'Racha de lectura',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.schedule,
                    value: formatMinutes(todayMinutes),
                    label: dailyGoal > 0
                        ? 'Hoy · meta ${formatMinutes(dailyGoal)}'
                        : 'Leído hoy',
                    progress: dailyGoal > 0 ? todayMinutes / dailyGoal : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Minutos leídos · últimos $chartDays días',
            child: DailyBarChart(
              days: days,
              values: minutes,
              formatValue: formatMinutes,
              semanticsLabel:
                  'Minutos leídos en los últimos $chartDays días: '
                  '${formatMinutes(minutes.fold(0, (a, b) => a + b))} en total, '
                  'hoy ${formatMinutes(todayMinutes)}.',
            ),
          ),
          const SizedBox(height: 12),
          _YearGoalCard(
            year: now.year,
            goal: goal,
            finished: finished.length,
            covers: [
              for (final b in finished.take(12))
                SizedBox(
                  width: 44,
                  child: GestureDetector(
                    onTap: () => context.push(Routes.book(b.id)),
                    child: BookCover(book: b, compact: true),
                  ),
                ),
            ],
            hoursThisYear: stats.readingSecondsInYear(now.year) ~/ 3600,
          ),
          section('Escritura'),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.local_fire_department_outlined,
                    value: _days(stats.writingStreak(now)),
                    label: 'Racha de escritura',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.edit_outlined,
                    value: formatWordCount(todayWords),
                    label: 'Escritas hoy',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Palabras escritas · últimos $chartDays días',
            child: DailyBarChart(
              days: days,
              values: words,
              formatValue: formatWordCount,
              semanticsLabel:
                  'Palabras escritas en los últimos $chartDays días: '
                  '${formatWordCount(words.fold(0, (a, b) => a + b))} en total.',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${formatWordCount(stats.wordsInYear(now.year))} en ${now.year}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.progress,
  });

  final IconData icon;
  final String value;
  final String label;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              maxLines: 2,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0, 1),
                  minHeight: 5,
                  color: LitteraColors.oro,
                  backgroundColor: theme.colorScheme.outlineVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _YearGoalCard extends StatelessWidget {
  const _YearGoalCard({
    required this.year,
    required this.goal,
    required this.finished,
    required this.covers,
    required this.hoursThisYear,
  });

  final int year;
  final int goal;
  final int finished;
  final List<Widget> covers;
  final int hoursThisYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reached = goal > 0 && finished >= goal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meta de $year',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              goal > 0
                  ? (reached
                        ? '¡Meta cumplida! $finished de $goal libros'
                        : '$finished de $goal libros terminados')
                  : '$finished ${finished == 1 ? 'libro terminado' : 'libros terminados'}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (goal > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (finished / goal).clamp(0, 1),
                  minHeight: 8,
                  color: LitteraColors.oro,
                  backgroundColor: theme.colorScheme.outlineVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              hoursThisYear == 0
                  ? 'Aún sin horas de lectura registradas este año'
                  : '$hoursThisYear ${hoursThisYear == 1 ? 'hora' : 'horas'} '
                        'de lectura este año',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (covers.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: covers),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalsDialog extends ConsumerStatefulWidget {
  const _GoalsDialog();

  @override
  ConsumerState<_GoalsDialog> createState() => _GoalsDialogState();
}

class _GoalsDialogState extends ConsumerState<_GoalsDialog> {
  late final _books = TextEditingController(
    text: ref.read(settingsProvider).annualBookGoal.toString(),
  );
  late final _minutes = TextEditingController(
    text: ref.read(settingsProvider).dailyReadingMinutes.toString(),
  );

  @override
  void dispose() {
    _books.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Metas'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _books,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Libros al año',
              helperText: '0 = sin meta',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minutos de lectura al día',
              helperText: 'La meta de palabras se fija en cada obra',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            ref
                .read(settingsProvider.notifier)
                .setGoals(
                  annualBookGoal: int.tryParse(_books.text.trim()),
                  dailyReadingMinutes: int.tryParse(_minutes.text.trim()),
                );
            Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
