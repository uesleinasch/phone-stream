import 'package:flutter/material.dart';

import 'home_page.dart';

void main() => runApp(const PhoneStreamApp());

class PhoneStreamApp extends StatelessWidget {
  const PhoneStreamApp({super.key});

  static const _seed = Color(0xFFE0492F);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'phone-stream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      home: const HomePage(),
    );
  }
}
