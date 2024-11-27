import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Blind Assistant',
      home: TtsWithLocationAndSerial(),
    );
  }
}

class TtsWithLocationAndSerial extends StatefulWidget {
  const TtsWithLocationAndSerial({super.key});

  @override
  _TtsWithLocationAndSerialState createState() =>
      _TtsWithLocationAndSerialState();
}

class _TtsWithLocationAndSerialState extends State<TtsWithLocationAndSerial> {
  late FlutterTts flutterTts;
  String displayMessage = "Tap anywhere to get location.";
  bool isSpeaking = false; // Prevent overlapping TTS
  UsbPort? _port;
  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;
  UsbDevice? _device;

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    _checkPermissions();
    _initializeSerial();
  }

  Future<void> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }
  }

  Future<void> _initializeSerial() async {
    UsbSerial.usbEventStream!.listen((UsbEvent event) {
      _getPorts();
    });
    _getPorts();
  }

  void _getPorts() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (!devices.contains(_device)) {
      _connectTo(null);
    }

    if (devices.isNotEmpty) {
      _connectTo(devices[0]);
    }
  }

  Future<bool> _connectTo(device) async {
    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }

    if (_transaction != null) {
      _transaction!.dispose();
      _transaction = null;
    }

    if (_port != null) {
      _port!.close();
      _port = null;
    }

    if (device == null) {
      _device = null;
      return false;
    }

    _port = await device.create();
    if (await _port!.open() != true) {
      return false;
    }

    _device = device;

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
        115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(
        _port!.inputStream as Stream<Uint8List>, Uint8List.fromList([13, 10]));

    _subscription = _transaction!.stream.listen((String line) {
      _processSerialData(line);
    });

    return true;
  }

  void _processSerialData(String data) async {
    try {
      final parsed = json.decode(data) as Map<String, dynamic>;
      double distance = parsed['distance'] ?? 0.0;
      int heartRate = parsed['heartRate'] ?? 0;

      if (distance < 3.0 && !isSpeaking) {
        setState(() {
          isSpeaking = true;
          setState(() {
            displayMessage = "Hati-hati! Ada halangan dalam jarak $distance meter.";
          });
        });
        await flutterTts.setLanguage("id-ID");
        await flutterTts.speak(
            "Hati-hati! Ada halangan dalam jarak $distance meter.");
        await flutterTts.awaitSpeakCompletion(true);
        setState(() {
          isSpeaking = false;
        });
      }

      if (!isSpeaking) {
        setState(() {
          displayMessage = "Detak jantung saat ini adalah $heartRate bpm";
        });
      }
    } catch (e) {
      // Handle parsing error silently
    }
  }

  Future<void> _getNearbyField(double latitude, double longitude) async {
    final String url =
        'https://overpass-api.de/api/interpreter?data=[out:json];(node["sport"](around:10000,$latitude,$longitude););out body;';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['elements'].isNotEmpty) {
          String? nearestFacility = data['elements'][0]['tags']['name'] ??
              data['elements'][0]['tags']['sport'];
          double facilityLat = data['elements'][0]['lat'];
          double facilityLon = data['elements'][0]['lon'];

          double distance =
          _calculateDistance(latitude, longitude, facilityLat, facilityLon);
          String distanceStr = "${distance.toStringAsFixed(2)} km";

          List<Placemark> placemarks =
          await placemarkFromCoordinates(facilityLat, facilityLon);
          String address =
              "${placemarks[0].street}, ${placemarks[0].locality}, ${placemarks[0].country}";

          setState(() {
            displayMessage =
            "Fasilitas olahraga terdekat: $nearestFacility\nAlamat: $address\nJarak: $distanceStr";
          });

          if (!isSpeaking) {
            setState(() {
              isSpeaking = true;
            });
            await flutterTts.setLanguage("id-ID");
            await flutterTts.speak(
                "Fasilitas olahraga terdekat adalah $nearestFacility di $address, berjarak $distanceStr.");
            await flutterTts.awaitSpeakCompletion(true);
            setState(() {
              isSpeaking = false;
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        displayMessage = "Error: $e";
      });
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of the Earth in km
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLon = (lon2 - lon1) * (pi / 180);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> _getLocationAndSpeak() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address =
            "${place.street ?? 'Unknown street'}, ${place.locality ?? 'Unknown locality'}, ${place.country ?? 'Unknown country'}";

        setState(() {
          displayMessage = address;
        });

        if (!isSpeaking) {
          setState(() {
            isSpeaking = true;
          });
          await flutterTts.setLanguage("id-ID");
          await flutterTts.speak("Lokasi Anda saat ini adalah $address");
          await flutterTts.awaitSpeakCompletion(true);
          setState(() {
            isSpeaking = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        displayMessage = "Error: $e";
      });
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    _connectTo(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blind Assistant'),
        backgroundColor: Colors.red[100],
      ),
      body: GestureDetector(
        onTap: _getLocationAndSpeak,
        onDoubleTap: () async {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          _getNearbyField(position.latitude, position.longitude);
        },
        onLongPress: () async {
          if (!isSpeaking) {
            setState(() {
              isSpeaking = true;
            });
            await flutterTts.speak(displayMessage);
            await flutterTts.awaitSpeakCompletion(true);
            setState(() {
              isSpeaking = false;
            });
          }
        },
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
