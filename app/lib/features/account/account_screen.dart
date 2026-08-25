import 'package:intl/intl.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/date_swipe_nav.dart';
import '../../shared/widgets/segmented_control.dart';
import '../../state/auth_providers.dart';
import '../../state/root_shell_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../log_activity/widgets/activities_list.dart';
import 'capacity_view.dart';

enum _AccountTab { details, activities, capacity }

/// The former Activities tab — now "Account": account details (email,
/// creation date, sign out) by default, with a segmented control to switch
/// between that, the day-by-day activity list, and the weekly Capacity
/// view — all three are menu items on the same screen, not separate
/// pushed routes. Logging a new activity by hand happens from the Day view
/// instead (see `showLogActivitySheet` there), so this screen has no
/// "+ LOG" action of its own.
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
      final next = (ref.read(currentTabIndexProvider) + delta).clamp(0, 2);
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
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account', style: AppTextStyles.title()),
                    const SizedBox(height: AppSpacing.s2),
                    SegmentedControl<_AccountTab>(
                      selected: _tab,
                      stretch: true,
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
                        SegmentedOption(
                          value: _AccountTab.capacity,
                          label: 'Capacity',
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
                _AccountTab.capacity => const CapacityView(),
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
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final email = user?.email ?? '';
    // A Firebase user with no real creation timestamp reports the epoch
    // (0ms) rather than null — the test fixtures' MockUser never sets one,
    // so this is what tells "no real value" apart from "1 Jan 1970".
    final rawCreatedAt = user?.metadata.creationTime;
    final createdAt =
        rawCreatedAt != null && rawCreatedAt.millisecondsSinceEpoch > 0
        ? rawCreatedAt
        : null;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EMAIL', style: AppTextStyles.kicker()),
          const SizedBox(height: AppSpacing.s1),
          Text(email, style: AppTextStyles.mono()),
          if (createdAt != null) ...[
            const SizedBox(height: AppSpacing.s3),
            Text('MEMBER SINCE', style: AppTextStyles.kicker()),
            const SizedBox(height: AppSpacing.s1),
            Text(
              // Firebase's creation timestamp comes back UTC — .toLocal()
              // so the calendar day matches what the user actually saw
              // when they signed up, not whatever day it was in UTC.
              DateFormat('d MMMM y').format(createdAt.toLocal()),
              style: AppTextStyles.mono(),
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
          GestureDetector(
            onTap: () => ref.read(firebaseAuthProvider).signOut(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              constraints: const BoxConstraints(minHeight: 32),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.neutral500),
                borderRadius: AppShapes.small,
              ),
              child: Text(
                'Sign out',
                style: AppTextStyles.small(color: AppColors.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
