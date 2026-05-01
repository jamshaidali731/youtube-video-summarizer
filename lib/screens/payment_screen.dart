import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.planName,
    required this.price,
    required this.durationDays,
  });

  final String planName;
  final int price;
  final int durationDays;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController accountController = TextEditingController();
  final TextEditingController transactionController = TextEditingController();
  String paymentMethod = 'EasyPaisa';
  bool loading = false;

  @override
  void dispose() {
    accountController.dispose();
    transactionController.dispose();
    super.dispose();
  }

  Future<void> submitPayment() async {
    if (accountController.text.trim().isEmpty ||
        transactionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all payment fields')),
      );
      return;
    }

    setState(() => loading = true);

    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('payments').add(<String, dynamic>{
      'uid': user?.uid,
      'email': user?.email,
      'plan': widget.planName,
      'price': widget.price,
      'durationDays': widget.durationDays,
      'paymentMethod': paymentMethod,
      'accountNumber': accountController.text.trim(),
      'transactionId': transactionController.text.trim(),
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (!mounted) {
      return;
    }

    setState(() => loading = false);

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Payment Submitted'),
          content: const Text(
            'Your payment request has been sent for admin verification.',
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(this.context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Card(
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text(widget.planName),
                subtitle: Text('${widget.durationDays} days'),
                trailing: Text('Rs. ${widget.price}'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Methods',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: paymentMethod,
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'EasyPaisa', child: Text('EasyPaisa')),
                DropdownMenuItem(value: 'JazzCash', child: Text('JazzCash')),
                DropdownMenuItem(value: 'SadaPay', child: Text('SadaPay')),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => paymentMethod = value);
                }
              },
            ),
            const SizedBox(height: 14),
            const Card(
              child: ListTile(
                leading: Icon(Icons.account_balance_wallet_outlined),
                title: Text('Admin EasyPaisa Number'),
                subtitle: Text('03334295838'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: accountController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Your Account Number',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: transactionController,
              decoration: const InputDecoration(
                labelText: 'Transaction ID',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : submitPayment,
                child: Text(loading ? 'Submitting...' : 'Submit Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

