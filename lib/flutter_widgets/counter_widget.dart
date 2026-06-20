import 'package:flutter/material.dart';

/// A minimal Flutter widget used to prove that multiple independent Flutter
/// app instances ([FlutterEmbedView]s) can run on the same Jaspr page.
class CounterWidget extends StatelessWidget {
  const CounterWidget({this.count = 0, required this.onChange, super.key});

  final int count;
  final void Function(int) onChange;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF5B8DEE),
      ),
      home: Material(
        type: MaterialType.transparency,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () => onChange(count - 1),
            ),
            SizedBox(
              width: 90,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Flutter counter', style: TextStyle(fontSize: 11)),
                  Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => onChange(count + 1),
            ),
          ],
        ),
      ),
    );
  }
}
