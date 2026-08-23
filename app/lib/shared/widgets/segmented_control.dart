import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class SegmentedOption<T> {
  const SegmentedOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// The "Day | Plan + actual" style control: 1px ink border, active option
/// filled ink with a white label, flush 3-line padding.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<SegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.text, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 24, color: AppColors.text),
            _SegmentedOptionButton(
              option: options[i],
              active: options[i].value == selected,
              onTap: () => onChanged(options[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentedOptionButton<T> extends StatelessWidget {
  const _SegmentedOptionButton({
    required this.option,
    required this.active,
    required this.onTap,
  });

  final SegmentedOption<T> option;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: active ? AppColors.text : const Color(0x00000000),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            option.label,
            style: AppTextStyles.small(
              color: active ? AppColors.bg : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
