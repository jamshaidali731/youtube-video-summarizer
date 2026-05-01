import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_access.dart';
import '../admin_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  @override
  void initState() {
    super.initState();
    checkUser();
  }

  Future<void> checkUser() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    String role = AppAccess.isAdminEmail(user.email) ? 'admin' : 'user';
    bool isBlocked = false;

    try {
      final DocumentReference<Map<String, dynamic>> userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final DocumentSnapshot<Map<String, dynamic>> doc = await userRef.get();

      if (doc.exists) {
        final Map<String, dynamic>? data = doc.data();
        final String storedRole = data?['role']?.toString() ?? role;
        final bool adminByEmail = AppAccess.isAdminEmail(user.email);

        role = adminByEmail ? 'admin' : storedRole;
        isBlocked = data?['blocked'] == true;

        await userRef.set(
          <String, dynamic>{
            'username': data?['username'] ?? user.displayName ?? 'User',
            'email': user.email,
            'role': role,
          },
          SetOptions(merge: true),
        );
      } else {
        await userRef.set(
          <String, dynamic>{
            'username': user.displayName ?? 'User',
            'email': user.email,
            'role': role,
            'isPremium': false,
            'blocked': false,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {}

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', role);

    if (isBlocked) {
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Access Blocked'),
          content: const Text('Your account has been blocked by the admin.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      await FirebaseAuth.instance.signOut();
      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
      return;
    }

    if (!mounted) {
      return;
    }

    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
