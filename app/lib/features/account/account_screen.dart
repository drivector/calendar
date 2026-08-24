import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/date_swipe_nav.dart';
import '../../shared/widgets/segmented_control.dart';
import '../../state/auth_providers.dart';
import '../../state/root_shell_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../log_activity/widgets/activities_list.dart';

enum _AccountTab { details, activities }

/// The former Activities tab — now "Account": account details (email, sign
/// out) by default, with a segmented control to switch to the same
/// day-by-day activity list that used to be the whole screen. Logging a new
/// activity by hand now happens from the Day view instead (see
/// `showLogActivitySheet` there), so this screen has no "+ LOG" action of
/// its own any more.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  _AccountTab _tab = _AccountTab.details;

  @override
  Widget build(BuildContext context) {
    void stepTab(int delta) {
      final next = (ref.read(currentTabIndexProvider) + delta).clamp(0, 3);
      ref.read(currentTabIndexProvider.notifier).state = next;
    }

    return DateSwipeNav(
      onPrevious: () => stepTab(-1),
      onNext: () => stepTab(1),
      child: ColoredBox(
        color: AppColors.bg,
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.text, width: 2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Account', style: AppTextStyles.title()),
                    SegmentedControl<_AccountTab>(
                      selected: _tab,
                      onChanged: (value) => setState(() => _tab = value),
                      options: const [
                        SegmentedOption(
                          value: _AccountTab.details,
                          label: 'Details',
                        ),
                        SegmentedOption(
                          value: _AccountTab.activities,
                          label: 'Activities',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: switch (_tab) {
                _AccountTab.details => const _AccountDetails(),
                _AccountTab.activities => const ActivitiesList(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDetails extends ConsumerWidget {
  const _AccountDetails();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authStateChangesProvider).valueOrNull?.email ?? '';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EMAIL', style: AppTextStyles.kicker()),
          const SizedBox(height: AppSpacing.s1),
          Text(email, style: AppTextStyles.mono()),
          const SizedBox(height: AppSpacing.s4),
          GestureDetector(
            onTap: () => ref.read(firebaseAuthProvider).signOut(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              constraints: const BoxConstraints(minHeight: 32),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.text, width: 1.5),
              ),
              child: Text(
                'SIGN OUT',
                style: AppTextStyles.small(color: AppColors.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
