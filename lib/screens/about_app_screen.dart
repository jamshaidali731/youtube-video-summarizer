import 'package:flutter/material.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About App'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          Card(
            child: ListTile(
              leading: Icon(Icons.smart_toy_outlined),
              title: Text('YT Summarizer'),
              subtitle: Text('AI-powered video and study assistant app'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.verified_outlined),
              title: Text('Version'),
              subtitle: Text('1.0.0'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.person_outline_rounded),
              title: Text('Developer'),
              subtitle: Text('Muhammad Bilal Sheikh'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.email_outlined),
              title: Text('Contact Email'),
              subtitle: Text('muhammadbilalsheikh185@gmail.com'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.phone_outlined),
              title: Text('Contact Number'),
              subtitle: Text('+92 333 4295838'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.menu_book_rounded),
              title: Text('Description'),
              subtitle: Text(
                'Summarize YouTube videos, generate study material, manage favorites, and support a freemium learning flow.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
