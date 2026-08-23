import '../../models/category.dart';
import '../../theme/app_category_colors.dart';

const walkingCategoryId = 'walking';
const deepWorkCategoryId = 'deep_work';
const meetingsCategoryId = 'meetings';
const adminCategoryId = 'admin';
const screenTimeCategoryId = 'screen_time';

const mockCategories = [
  Category(
    id: walkingCategoryId,
    name: 'Walking',
    color: AppCategoryColors.walking,
  ),
  Category(
    id: deepWorkCategoryId,
    name: 'Deep work',
    color: AppCategoryColors.deepWork,
  ),
  Category(
    id: meetingsCategoryId,
    name: 'Meetings',
    color: AppCategoryColors.meetings,
  ),
  Category(
    id: adminCategoryId,
    name: 'Admin',
    color: AppCategoryColors.admin,
  ),
  Category(
    id: screenTimeCategoryId,
    name: 'Screen time',
    color: AppCategoryColors.screenTime,
  ),
];

Category categoryById(String id) =>
    mockCategories.firstWhere((category) => category.id == id);
