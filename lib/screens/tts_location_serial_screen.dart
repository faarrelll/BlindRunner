import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../services/location_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/serial_service.dart';
import '../models/sensor_data.dart';
import '../utils/distance_calculator.dart';

class TtsLocationSerialScreen extends StatefulWidget {
  const TtsLocationSerialScreen({super.key});

  @override
  _TtsLocationSerialScreenState createState() => _TtsLocationSerialScreenState();
}

class _TtsLocationSerialScreenState extends State<TtsLocationSerialScreen> {
  final LocationService _locationService = LocationService();
  final TextToSpeechService _ttsService = TextToSpeechService();
  final SerialService _serialService = SerialService();

  String displayMessage = "Beri Ketukan Untuk Interaksi.";
  bool isSpeaking = false;
  bool isConnected = false;
  bool _initialConnectionCheck = true;
  bool _previousConnectionState = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _locationService.checkLocationPermissions();
    await _ttsService.initializeTts();
    _serialService.initializeSerial();

    _serialService.dataStream.listen((SensorData data) {
      _handleSensorData(data);
    });

    // Listen to connection status
    _serialService.connectionStatusStream.listen((bool connected) {
      setState(() {
        // Prevent initial TTS trigger when app first starts
        // Only speak if the connection state has actually changed
        if (!_initialConnectionCheck && connected != _previousConnectionState) {
          _handleDeviceConnectionSound(connected);
        }
        isConnected = connected;
        _previousConnectionState = connected; // Update previous state
        _initialConnectionCheck = false;
      });
    });
  }

  Future<void> _handleDeviceConnectionSound(bool connected) async {
    if (!isSpeaking) {
      setState(() {
        isSpeaking = true;
      });

      if (connected) {
        await _ttsService.speak("Alat Terhubung");
      } else {
        await _ttsService.speak("Alat Terputus");
      }

      setState(() {
        isSpeaking = false;
      });
    }
  }

  void _handleSensorData(SensorData data) {
    if ((data.distance < 100 && data.heartRate == -1) && !isSpeaking) {
      _speakObstacleWarning(data.distance);
    } else if (data.distance == -1 && data.heartRate > 0){
        _speakHeartRate(data.heartRate);
    }
    // if (!isSpeaking) {
    //   setState(() {
    //     displayMessage = "Detak jantung saat ini adalah ${data.heartRate} bpm";
    //   });
    // }
  }

  Future<void> _speakObstacleWarning(int distance) async {
    setState(() {
      isSpeaking = true;
      displayMessage = "Hati-hati! Ada halangan dalam jarak $distance sentimeter.";
    });

    await _ttsService.speak(
        "Hati-hati! Ada halangan dalam jarak $distance sentimeter."
    );

    setState(() {
      isSpeaking = false;
    });
  }

  Future<void> _speakHeartRate(int heartrate) async {
    setState(() {
      isSpeaking = true;
      displayMessage = "Mendeteksi Detak Jantung";
    });

    await _ttsService.speak("Beep!");

    setState(() {
      displayMessage = "Letakan jari pada sensor kurang lebih 10 detik!";
    });

    await _ttsService.speak("Letakan jari pada sensor kurang lebih 10 detik!");

    await Future.delayed(const Duration(seconds: 5));

    setState(() {
      displayMessage = "Detak jantung saat ini adalah ${heartrate} bpm";
    });

    await _ttsService.speak(
        "Detak jantung saat ini adalah ${heartrate} bpm"
    );

    setState(() {
      isSpeaking = false;
      displayMessage = "Beri Ketukan Untuk Interaksi.";
    });
  }

  Future<void> _getLocationAndSpeak() async {
    try {
      Position position = await _locationService.getCurrentLocation();
      String address = await _locationService.getAddressFromLocation(position);

      setState(() {
        displayMessage = address;
      });

      if (!isSpeaking) {
        setState(() {
          isSpeaking = true;
        });
        await _ttsService.speak("Lokasi Anda saat ini adalah $address");
        setState(() {
          isSpeaking = false;
          displayMessage = "Beri Ketukan Untuk Interaksi.";
        });
      }

    } catch (e) {
      setState(() {
        displayMessage = "Error: $e";
      });
    }
  }

  Future<void> _getNearbyField() async {
    try {
      Position position = await _locationService.getCurrentLocation();
      final String url =
          'https://overpass-api.de/api/interpreter?data=[out:json];'
          '(node["sport"](around:10000,${position.latitude},${position.longitude}););out body;';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['elements'].isNotEmpty) {
          _processNearestFacility(data['elements'][0], position);
        }
      }
    } catch (e) {
      setState(() {
        displayMessage = "Error: $e";
      });
    }
  }

  void _processNearestFacility(dynamic facility, Position currentPosition) async {
    String? nearestFacility = facility['tags']['name'] ?? facility['tags']['sport'];
    double facilityLat = facility['lat'];
    double facilityLon = facility['lon'];

    double distance = DistanceCalculator.calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        facilityLat,
        facilityLon
    );
    String distanceStr = "${distance.toStringAsFixed(2)} km";

    String address = await _locationService.getAddressFromLocation(
        Position(
          latitude: facilityLat,
          longitude: facilityLon,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        )
    );

    setState(() {
      displayMessage =
      "Fasilitas olahraga terdekat: $nearestFacility\n"
          "Alamat: $address\n"
          "Jarak: $distanceStr";
    });

    if (!isSpeaking) {
      setState(() {
        isSpeaking = true;
      });
      await _ttsService.speak(
          "Fasilitas olahraga terdekat adalah $nearestFacility di $address, berjarak $distanceStr."
      );
      setState(() {
        isSpeaking = false;
        displayMessage = "Beri Ketukan Untuk Interaksi.";
      });
    }
  }

  @override
  void dispose() {
    _ttsService.stop();
    _serialService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blind Assistant'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isConnected ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isConnected ? 'Connected' : 'Disconnected',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _getLocationAndSpeak,
        onDoubleTap: _getNearbyField,
        child: Container(
          color: Colors.white,
          child: Center(
            child: Text(
              displayMessage,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}