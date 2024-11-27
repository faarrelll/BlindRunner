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
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.red[100],
        ),
      ),
      home: const TtsLocationSerialScreen(),
    );
  }
}