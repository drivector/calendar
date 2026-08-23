import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock/dummy_data.dart';
import '../data/mock/mock_day_20aug.dart';
import '../models/planned_block.dart';
import '../models/tracked_block.dart';

/// Which columns the day view shows — mirrors the header's
/// "Day | Plan + actual" segmented control.
enum DayLayer { actual, planAndActual }

final selectedDateProvider = StateProvider<DateTime>((ref) => mockDay);

final dayLayerProvider =
    StateProvider<DayLayer>((ref) => DayLayer.planAndActual);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class PlannedBlocksNotifier extends StateNotifier<List<PlannedBlock>> {
  PlannedBlocksNotifier() : super([...mockPlannedBlocks, ...dummyPlannedBlocks]);

  void addBlock(PlannedBlock block) => state = [...state, block];
}

class TrackedBlocksNotifier extends StateNotifier<List<TrackedBlock>> {
  TrackedBlocksNotifier() : super([...mockTrackedBlocks, ...dummyTrackedBlocks]);

  void addBlock(TrackedBlock block) => state = [...state, block];
}

/// Every planned/tracked block across all days — the Day view filters these
/// down to the selected day; Goals sums them across the current week.
final allPlannedBlocksProvider =
    StateNotifierProvider<PlannedBlocksNotifier, List<PlannedBlock>>(
  (ref) => PlannedBlocksNotifier(),
);

final allTrackedBlocksProvider =
    StateNotifierProvider<TrackedBlocksNotifier, List<TrackedBlock>>(
  (ref) => TrackedBlocksNotifier(),
);

final plannedBlocksProvider = Provider<List<PlannedBlock>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final all = ref.watch(allPlannedBlocksProvider);
  return all.where((b) => isSameDay(b.start, selectedDate)).toList();
});

final trackedBlocksProvider = Provider<List<TrackedBlock>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final all = ref.watch(allTrackedBlocksProvider);
  return all.where((b) => isSameDay(b.start, selectedDate)).toList();
});
