import 'package:flutter/material.dart';
import '../screens/tts_location_serial_screen.dart';

class BlindAssistantApp extends StatelessWidget {
  const BlindAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Blind Assistant',
      theme: ThemeData(
        primarySwatch: Colors.red,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
        ),
      ),
      home: const TtsLocationSerialScreen(),
    );
  }
}