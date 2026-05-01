import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/about_app_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/subscription_screen.dart';
import 'services/local_session_service.dart';
import 'services/local_summary_service.dart';
import 'services/theme_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ImagePicker imagePicker = ImagePicker();

  bool loading = true;
  String username = 'User';
  String email = '';
  int usageCount = 0;
  int summaryCount = 0;
  int favoritesCount = 0;
  String? planName;
  String? profileImagePath;

  User? get user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final User? currentUser = user;
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String fetchedUsername = currentUser?.displayName ?? 'User';
    String fetchedEmail = currentUser?.email ?? '';
    String? fetchedPlan;

    if (currentUser != null) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (doc.exists) {
          final Map<String, dynamic>? data = doc.data();
          fetchedUsername = data?['username']?.toString().trim().isNotEmpty == true
              ? data!['username'].toString()
              : fetchedUsername;
          fetchedPlan = data?['planName']?.toString();
        }
      } catch (_) {}
    }

    final records = await LocalSummaryService.getRecords();

    if (!mounted) {
      return;
    }

    setState(() {
      username = fetchedUsername;
      email = fetchedEmail;
      usageCount = prefs.getInt(LocalSessionService.usageKey) ?? 0;
      summaryCount = records.length;
      favoritesCount = records.where((record) => record.isFavorite).length;
      profileImagePath = currentUser == null
          ? null
          : prefs.getString(LocalSessionService.profileImageKey(currentUser.uid));
      planName = fetchedPlan;
      loading = false;
    });
  }

  Future<void> pickProfileImage() async {
    final User? currentUser = user;
    if (currentUser == null) {
      return;
    }

    final XFile? picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked == null) {
      return;
    }

    final Directory directory = await getApplicationDocumentsDirectory();
    final String savedPath = '${directory.path}/profile_${currentUser.uid}.png';
    final File existingFile = File(savedPath);
    if (await existingFile.exists()) {
      await existingFile.delete();
    }
    final File savedFile = await File(picked.path).copy(savedPath);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      LocalSessionService.profileImageKey(currentUser.uid),
      savedFile.path,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      profileImagePath = savedFile.path;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile picture updated')),
    );
  }

  Future<void> clearActivityData() async {
    final bool? shouldClear = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Activity Data'),
          content: const Text(
            'This will remove local history, favorites, and saved summary cache from this device.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) {
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await LocalSummaryService.clearAll();
    await prefs.remove(LocalSessionService.historyKey);
    await prefs.remove(LocalSessionService.favoritesKey);
    await prefs.remove(LocalSessionService.usageKey);
    await prefs.remove(LocalSessionService.latestSummaryKey);

    if (!mounted) {
      return;
    }

    setState(() {
      usageCount = 0;
      summaryCount = 0;
      favoritesCount = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local activity data cleared')),
    );
  }

  Future<void> logout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('You will be redirected to the login screen.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    await LocalSessionService.clearUserSession(uid: user?.uid);
    await FirebaseAuth.instance.signOut();

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> deleteAccount() async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text('This action cannot be undone. Continue?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).delete();
    } catch (_) {}

    await LocalSessionService.clearUserSession(uid: user?.uid);
    await user?.delete();

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Widget profileAvatar() {
    final String initials = username.isNotEmpty ? username[0].toUpperCase() : 'U';

    if (profileImagePath != null && File(profileImagePath!).existsSync()) {
      return CircleAvatar(
        radius: 36,
        backgroundImage: FileImage(File(profileImagePath!)),
      );
    }

    return CircleAvatar(
      radius: 36,
      backgroundColor: Colors.white24,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      tileColor: Theme.of(context).colorScheme.surface,
      leading: Icon(icon, color: iconColor ?? Theme.of(context).colorScheme.primary),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final int remainingUses = (10 - usageCount).clamp(0, 10);
    final ThemeController themeController = context.watch<ThemeController>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF111827), Color(0xFFDC2626)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: <Widget>[
              Stack(
                children: <Widget>[
                  profileAvatar(),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: pickProfileImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                email,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  Chip(
                    label: Text(
                      'Used: $usageCount',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.white24,
                  ),
                  Chip(
                    label: Text(
                      'Free left: $remainingUses',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.white24,
                  ),
                  Chip(
                    label: Text(
                      'Summaries: $summaryCount',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.white24,
                  ),
                  Chip(
                    label: Text(
                      'Favorites: $favoritesCount',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.white24,
                  ),
                  Chip(
                    label: Text(
                      planName == null ? 'Free Plan' : 'Plan: $planName',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.white24,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Account',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        tile(
          icon: Icons.workspace_premium_outlined,
          title: 'Subscription Plans',
          subtitle: 'Manage or upgrade your premium access',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        tile(
          icon: Icons.feedback_outlined,
          title: 'Feedback & Support',
          subtitle: 'Send your suggestions or questions',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        tile(
          icon: Icons.info_outline_rounded,
          title: 'About App',
          subtitle: 'Version, developer, and app information',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutAppScreen()),
            );
          },
        ),
        const SizedBox(height: 20),
        const Text(
          'Appearance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Theme Mode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose the look that feels best while using the app.',
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  multiSelectionEnabled: false,
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.settings_suggest_rounded),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_rounded),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_rounded),
                    ),
                  ],
                  selected: <ThemeMode>{themeController.themeMode},
                  onSelectionChanged: (Set<ThemeMode> selection) {
                    themeController.setThemeMode(selection.first);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Data',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        tile(
          icon: Icons.delete_sweep_outlined,
          title: 'Clear Activity Data',
          subtitle: 'Remove history, favorites, and local summary cache',
          onTap: clearActivityData,
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: logout,
          icon: const Icon(Icons.logout_rounded, color: Colors.red),
          label: const Text('Logout', style: TextStyle(color: Colors.red)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: deleteAccount,
          icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
          label: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
