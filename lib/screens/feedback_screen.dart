import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController feedbackController = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    feedbackController.dispose();
    super.dispose();
  }

  Future<void> sendFeedback() async {
    if (feedbackController.text.trim().isEmpty) {
      return;
    }

    setState(() => loading = true);
    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('feedbacks').add(<String, dynamic>{
      'email': user?.email,
      'uid': user?.uid,
      'message': feedbackController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (!mounted) {
      return;
    }

    setState(() => loading = false);
    feedbackController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Feedback sent successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback & Queries'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Card(
              child: ListTile(
                leading: Icon(Icons.support_agent_rounded),
                title: Text('Support Email'),
                subtitle: Text('support@yt-summarizer.com'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Share feedback or ask your question',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Write your feedback here...',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : sendFeedback,
                child: Text(loading ? 'Sending...' : 'Send Feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

