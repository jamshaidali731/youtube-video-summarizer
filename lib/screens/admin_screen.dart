import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/local_session_service.dart';
import 'auth/login_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  String userSearch = '';
  String paymentSearch = '';
  String feedbackSearch = '';

  User? get currentUser => FirebaseAuth.instance.currentUser;

  Future<void> logout(BuildContext context) async {
    await LocalSessionService.clearUserSession(uid: currentUser?.uid);
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> toggleUserBlock({
    required String userId,
    required bool block,
  }) async {
    await firestore.collection('users').doc(userId).set(
      <String, dynamic>{
        'blocked': block,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    await firestore.collection('users').doc(userId).set(
      <String, dynamic>{
        'role': role,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> reviewPayment({
    required String paymentId,
    required String userId,
    required String status,
    required String planName,
    required int durationDays,
  }) async {
    await firestore.collection('payments').doc(paymentId).set(
      <String, dynamic>{
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (status == 'approved' && userId.isNotEmpty) {
      final DateTime expiry = DateTime.now().add(Duration(days: durationDays));
      await firestore.collection('users').doc(userId).set(
        <String, dynamic>{
          'isPremium': true,
          'planName': planName,
          'planExpiry': Timestamp.fromDate(expiry),
        },
        SetOptions(merge: true),
      );
    }
  }

  Widget statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(title),
        ],
      ),
    );
  }

  Widget searchField({
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  bool matchesSearch(String source, String query) {
    return source.toLowerCase().contains(query.toLowerCase().trim());
  }

  Widget buildHeaderHero() {
    final String displayName = currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!
        : 'Super Admin';
    final String email = currentUser?.email ?? 'admin@yt-summarizer.com';

    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                child: Text(
                  displayName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => logout(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Premium Admin Workspace',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage users, monitor payments, approve subscriptions, and keep the platform healthy.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget buildOverviewTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('users').snapshots(),
      builder: (context, usersSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('payments').snapshots(),
          builder: (context, paymentsSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore.collection('feedbacks').snapshots(),
              builder: (context, feedbackSnapshot) {
                final List<QueryDocumentSnapshot<Map<String, dynamic>>> users =
                    usersSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final List<QueryDocumentSnapshot<Map<String, dynamic>>> payments =
                    paymentsSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final List<QueryDocumentSnapshot<Map<String, dynamic>>> feedbacks =
                    feedbackSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                final int feedbackCount = feedbacks.length;
                final int blockedUsers =
                    users.where((doc) => doc.data()['blocked'] == true).length;
                final int premiumUsers =
                    users.where((doc) => doc.data()['isPremium'] == true).length;
                final int activeUsers = users.length - blockedUsers;
                final int pendingPayments = payments
                    .where((doc) => (doc.data()['status'] ?? 'pending') == 'pending')
                    .length;
                final int revenue = payments
                    .where((doc) => (doc.data()['status'] ?? '') == 'approved')
                    .fold<int>(0, (int total, doc) {
                  final dynamic raw = doc.data()['price'];
                  final int amount = raw is int ? raw : int.tryParse('$raw') ?? 0;
                  return total + amount;
                });

                final List<QueryDocumentSnapshot<Map<String, dynamic>>> recentPayments = payments
                    .where((doc) => (doc.data()['status'] ?? 'pending') == 'pending')
                    .take(3)
                    .toList();
                final List<QueryDocumentSnapshot<Map<String, dynamic>>> recentFeedbacks =
                    feedbacks.take(3).toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      buildHeaderHero(),
                      const SizedBox(height: 18),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.18,
                        children: <Widget>[
                          statCard(
                            title: 'Total Users',
                            value: '${users.length}',
                            icon: Icons.people_alt_rounded,
                            color: Colors.blue,
                          ),
                          statCard(
                            title: 'Active Users',
                            value: '$activeUsers',
                            icon: Icons.person_pin_circle_rounded,
                            color: Colors.green,
                          ),
                          statCard(
                            title: 'Premium Users',
                            value: '$premiumUsers',
                            icon: Icons.workspace_premium_rounded,
                            color: Colors.teal,
                          ),
                          statCard(
                            title: 'Blocked Users',
                            value: '$blockedUsers',
                            icon: Icons.block_rounded,
                            color: Colors.red,
                          ),
                          statCard(
                            title: 'Pending Payments',
                            value: '$pendingPayments',
                            icon: Icons.payments_rounded,
                            color: Colors.orange,
                          ),
                          statCard(
                            title: 'Revenue',
                            value: 'Rs. $revenue',
                            icon: Icons.bar_chart_rounded,
                            color: Colors.purple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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
                              'Quick Insights',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Text('Feedback received: $feedbackCount'),
                            const SizedBox(height: 6),
                            Text('Pending payment reviews: $pendingPayments'),
                            const SizedBox(height: 6),
                            Text('Blocked accounts needing attention: $blockedUsers'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Pending Payment Snapshot',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      if (recentPayments.isEmpty)
                        const Card(
                          child: ListTile(
                            title: Text('No pending payments right now'),
                          ),
                        )
                      else
                        ...recentPayments.map((doc) {
                          final data = doc.data();
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.receipt_long_rounded),
                              title: Text('${data['plan'] ?? 'Plan'} - Rs. ${data['price'] ?? 0}'),
                              subtitle: Text(data['email']?.toString() ?? 'Unknown user'),
                            ),
                          );
                        }),
                      const SizedBox(height: 20),
                      const Text(
                        'Recent Feedback Snapshot',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      if (recentFeedbacks.isEmpty)
                        const Card(
                          child: ListTile(
                            title: Text('No feedback found'),
                          ),
                        )
                      else
                        ...recentFeedbacks.map((doc) {
                          final data = doc.data();
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.feedback_rounded),
                              title: Text(data['email']?.toString() ?? 'Unknown user'),
                              subtitle: Text(
                                data['message']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget buildUsersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs = docs.where((doc) {
          final data = doc.data();
          final String searchable =
              '${data['username'] ?? ''} ${data['email'] ?? ''} ${data['role'] ?? ''}';
          return userSearch.trim().isEmpty || matchesSearch(searchable, userSearch);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: searchField(
                  hint: 'Search users by name, email, or role',
                  onChanged: (String value) {
                    setState(() {
                      userSearch = value;
                    });
                  },
                ),
              ),
              const Expanded(child: Center(child: Text('No matching users found'))),
            ],
          );
        }

        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: searchField(
                hint: 'Search users by name, email, or role',
                onChanged: (String value) {
                  setState(() {
                    userSearch = value;
                  });
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filteredDocs.length,
                itemBuilder: (_, int index) {
                  final doc = filteredDocs[index];
                  final data = doc.data();
                  final bool blocked = data['blocked'] == true;
                  final bool premium = data['isPremium'] == true;
                  final String role = data['role']?.toString() ?? 'user';
                  final String username = data['username']?.toString() ?? 'User';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: <Widget>[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Text(username.isNotEmpty ? username[0].toUpperCase() : 'U'),
                            ),
                            title: Text(username),
                            subtitle: Text(data['email']?.toString() ?? 'No email'),
                            trailing: PopupMenuButton<String>(
                              onSelected: (String value) {
                                updateUserRole(userId: doc.id, role: value);
                              },
                              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'user',
                                  child: Text('Set as User'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'admin',
                                  child: Text('Set as Admin'),
                                ),
                              ],
                              child: Chip(label: Text(role)),
                            ),
                          ),
                          Row(
                            children: <Widget>[
                              Chip(
                                label: Text(premium ? 'Premium' : 'Free'),
                                backgroundColor: premium
                                    ? Colors.green.withOpacity(0.12)
                                    : Colors.grey.withOpacity(0.12),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(blocked ? 'Blocked' : 'Active'),
                                backgroundColor: blocked
                                    ? Colors.red.withOpacity(0.12)
                                    : Colors.blue.withOpacity(0.12),
                              ),
                              const Spacer(),
                              const Text('Block'),
                              Switch(
                                value: blocked,
                                onChanged: (bool value) {
                                  toggleUserBlock(userId: doc.id, block: value);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildPaymentsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('payments').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs = docs.where((doc) {
          final data = doc.data();
          final String searchable =
              '${data['email'] ?? ''} ${data['plan'] ?? ''} ${data['transactionId'] ?? ''} ${data['status'] ?? ''}';
          return paymentSearch.trim().isEmpty || matchesSearch(searchable, paymentSearch);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: searchField(
                  hint: 'Search payments by email, plan, transaction, or status',
                  onChanged: (String value) {
                    setState(() {
                      paymentSearch = value;
                    });
                  },
                ),
              ),
              const Expanded(child: Center(child: Text('No matching payments found'))),
            ],
          );
        }

        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: searchField(
                hint: 'Search payments by email, plan, transaction, or status',
                onChanged: (String value) {
                  setState(() {
                    paymentSearch = value;
                  });
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filteredDocs.length,
                itemBuilder: (_, int index) {
                  final doc = filteredDocs[index];
                  final data = doc.data();
                  final String status = data['status']?.toString() ?? 'pending';
                  final String planName = data['plan']?.toString() ?? 'Plan';
                  final int durationDays = data['durationDays'] is int
                      ? data['durationDays'] as int
                      : int.tryParse('${data['durationDays']}') ?? 30;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: <Widget>[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.receipt_long_rounded),
                            title: Text('$planName - Rs. ${data['price'] ?? 0}'),
                            subtitle: Text(
                              'User: ${data['email'] ?? 'Unknown'}\nTxn: ${data['transactionId'] ?? '-'}\nAccount: ${data['accountNumber'] ?? '-'}',
                            ),
                            isThreeLine: true,
                            trailing: Chip(label: Text(status)),
                          ),
                          if (status == 'pending')
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      reviewPayment(
                                        paymentId: doc.id,
                                        userId: data['uid']?.toString() ?? '',
                                        status: 'approved',
                                        planName: planName,
                                        durationDays: durationDays,
                                      );
                                    },
                                    icon: const Icon(Icons.check_circle_outline_rounded),
                                    label: const Text('Approve'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      reviewPayment(
                                        paymentId: doc.id,
                                        userId: data['uid']?.toString() ?? '',
                                        status: 'rejected',
                                        planName: planName,
                                        durationDays: durationDays,
                                      );
                                    },
                                    icon: const Icon(Icons.cancel_outlined),
                                    label: const Text('Reject'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildFeedbackTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('feedbacks')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs = docs.where((doc) {
          final data = doc.data();
          final String searchable = '${data['email'] ?? ''} ${data['message'] ?? ''}';
          return feedbackSearch.trim().isEmpty || matchesSearch(searchable, feedbackSearch);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: searchField(
                  hint: 'Search feedback by email or message',
                  onChanged: (String value) {
                    setState(() {
                      feedbackSearch = value;
                    });
                  },
                ),
              ),
              const Expanded(child: Center(child: Text('No matching feedback found'))),
            ],
          );
        }

        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: searchField(
                hint: 'Search feedback by email or message',
                onChanged: (String value) {
                  setState(() {
                    feedbackSearch = value;
                  });
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filteredDocs.length,
                itemBuilder: (_, int index) {
                  final data = filteredDocs[index].data();
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.feedback_rounded),
                      title: Text(data['email']?.toString() ?? 'Unknown user'),
                      subtitle: Text(data['message']?.toString() ?? ''),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Overview'),
              Tab(text: 'Users'),
              Tab(text: 'Payments'),
              Tab(text: 'Feedback'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            buildOverviewTab(),
            buildUsersTab(),
            buildPaymentsTab(),
            buildFeedbackTab(),
          ],
        ),
      ),
    );
  }
}
