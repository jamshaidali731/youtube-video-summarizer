import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class LocalSessionService {
  static const String onboardingKey = 'isFirstTime';
  static const String historyKey = 'history';
  static const String favoritesKey = 'favorites';
  static const String usageKey = 'usage';
  static const String latestSummaryKey = 'latestSummary';
  static const String latestSummaryIdKey = 'latestSummaryId';
  static const String summaryRecordsKey = 'summaryRecords';
  static const String themeModeKey = 'themeMode';
  static const String roleKey = 'role';

  static String profileImageKey(String uid) => 'profileImage_$uid';

  static Future<void> clearUserSession({String? uid}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? imagePath = uid == null ? null : prefs.getString(profileImageKey(uid));

    await prefs.remove(roleKey);
    if (uid != null) {
      await prefs.remove(profileImageKey(uid));
    }

    if (imagePath != null && imagePath.isNotEmpty) {
      final File file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
