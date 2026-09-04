import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/dashed_border.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/derived_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_category_colors.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';
import 'unscheduled_dialog.dart';

/// Three items, plus a fourth shown only when relevant: a plain bordered
/// swatch for "tracked" (the user's own configured tracking window — see
/// `UserSettings` — not what's actually been logged), a dashed swatch for
/// "planned" (only blocks with a real clock time — see
/// [dayTotalsProvider]'s own doc comment), a tinted+edged swatch for
/// "registered" (real logged activity; this is what "tracked" itself used
/// to mean here, before the window took that name), and a filled neutral
/// swatch for "unscheduled" — goal-targeted time with no fixed slot yet,
/// which never counts toward "planned". Totals computed as real sums over
/// the visible days' data.
///
/// Day mode always shows the full "word value" label — one day's totals
/// are short enough to fit. 3 Day/Working week/Week show icon + value only
/// by default (the word prefixes are what reliably overflow a real phone
/// width once totals get long, e.g. "registered 7h 15m" — only caught live
/// on-device, not by the default wide test viewport); tap one to reveal
/// its own word too — except "unscheduled", which opens a breakdown
/// dialog instead (see [showUnscheduledDialog]), in every mode, Day
/// included.
class LegendRow extends ConsumerStatefulWidget {
  const LegendRow({super.key});

  @override
  ConsumerState<LegendRow> createState() => _LegendRowState();
}

class _LegendRowState extends ConsumerState<LegendRow> {
  int? _revealedIndex;

  @override
  Widget build(BuildContext context) {
    final (plannedTotal, trackedTotal, registeredTotal, unscheduledTotal) =
        ref.watch(dayTotalsProvider);
    final isDayMode = ref.watch(dayViewModeProvider) == DayViewMode.day;

    void openUnscheduledDialog() => showUnscheduledDialog(
      context,
      byGoal: ref.read(unscheduledByGoalProvider),
      goals: ref.read(goalsProvider),
      categories: ref.read(categoriesProvider),
    );

    final items = [
      (
        swatch: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral500),
          ),
          child: const SizedBox(width: 14, height: 10),
        ),
        word: 'tracked',
        value: formatDuration(trackedTotal),
      ),
      (
        swatch: DashedRectBorder(
          color: AppColors.ink(0.5),
          child: const SizedBox(width: 14, height: 10),
        ),
        word: 'planned',
        value: formatDuration(plannedTotal),
      ),
      (
        swatch: DecoratedBox(
          decoration: BoxDecoration(
            color: AppCategoryColors.blockFill(AppColors.accent),
            border: Border(
              left: BorderSide(color: AppColors.accent, width: 3),
            ),
          ),
          child: const SizedBox(width: 14, height: 10),
        ),
        word: 'registered',
        value: formatDuration(registeredTotal),
      ),
      // Only shown when there's actually a goal owed some time it hasn't
      // been given a fixed slot for yet — otherwise every account with
      // fully-scheduled goals (the common case) would carry a permanent
      // "unscheduled 0m" item for nothing.
      if (unscheduledTotal > Duration.zero)
        (
          swatch: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.neutral400),
            child: const SizedBox(width: 14, height: 10),
          ),
          word: 'unscheduled',
          value: formatDuration(unscheduledTotal),
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        // Day mode: Wrap, always showing the word — one day's totals are
        // short, but wrapping is a free safety net rather than risking
        // the original Row overflow this replaced. Other modes: a plain
        // Row showing icon + value only (word hidden unless tapped), so
        // its width stays bounded — no wrap needed there.
        child: isDayMode
            ? Wrap(
                spacing: AppSpacing.s3,
                runSpacing: AppSpacing.s1,
                children: [
                  for (final item in items)
                    _LegendItem(
                      swatch: item.swatch,
                      word: item.word,
                      value: item.value,
                      showWord: true,
                      onTap: item.word == 'unscheduled'
                          ? openUnscheduledDialog
                          : null,
                    ),
                ],
              )
            : Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.s3),
                    _LegendItem(
                      swatch: items[i].swatch,
                      word: items[i].word,
                      value: items[i].value,
                      showWord: _revealedIndex == i,
                      onTap: items[i].word == 'unscheduled'
                          ? openUnscheduledDialog
                          : () => setState(
                              () => _revealedIndex = _revealedIndex == i
                                  ? null
                                  : i,
                            ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.swatch,
    required this.word,
    required this.value,
    required this.showWord,
    required this.onTap,
  });

  final Widget swatch;
  final String word;
  final String value;
  final bool showWord;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 5),
        // The value (the actual time) always shows next to the icon; the
        // word ("tracked"/"planned"/"registered") is what toggles.
        Text(
          showWord ? '$word $value' : value,
          style: AppTextStyles.mono(),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // A real tap target even though the icon+value alone is small —
      // matches this app's own ≥32×32 convention for anything tappable.
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.centerLeft,
        child: content,
      ),
    );
  }
}
