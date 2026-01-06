import 'package:flutter/material.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '$title module is scaffolded. Next step: wire ERPNext doctype APIs.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

