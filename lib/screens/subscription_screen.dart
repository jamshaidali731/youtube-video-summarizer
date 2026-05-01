import 'package:flutter/material.dart';

import 'payment_screen.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  List<Map<String, dynamic>> get plans => const <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Basic',
          'days': 7,
          'price': 500,
          'description': 'Good for quick exam preparation.',
        },
        <String, dynamic>{
          'name': 'Standard',
          'days': 15,
          'price': 1000,
          'description': 'Balanced plan for routine study.',
        },
        <String, dynamic>{
          'name': 'Monthly',
          'days': 30,
          'price': 2000,
          'description': 'Unlimited access for 30 days.',
        },
        <String, dynamic>{
          'name': 'Yearly Mega Offer',
          'days': 365,
          'price': 5000,
          'description': 'Best value for long-term use.',
        },
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: plans.length,
        itemBuilder: (_, int index) {
          final plan = plans[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        plan['name'] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text('Rs. ${plan['price']}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${plan['days']} Days'),
                  const SizedBox(height: 6),
                  Text(plan['description'] as String),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(
                              planName: plan['name'] as String,
                              price: plan['price'] as int,
                              durationDays: plan['days'] as int,
                            ),
                          ),
                        );
                      },
                      child: const Text('Choose Plan'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

