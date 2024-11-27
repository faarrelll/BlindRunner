import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';
import '../models/sensor_data.dart';

class SerialService {
  UsbPort? _port;
  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;
  UsbDevice? _device;
  final _dataController = StreamController<SensorData>.broadcast();

  Stream<SensorData> get dataStream => _dataController.stream;

  Future<void> initializeSerial() async {
    UsbSerial.usbEventStream!.listen((_) => _getPorts());
    _getPorts();
  }

  void _getPorts() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (devices.isNotEmpty) {
      _connectTo(devices[0]);
    }
  }

  Future<bool> _connectTo(device) async {
    _disconnect();

    if (device == null) return false;

    _port = await device.create();
    if (await _port!.open() != true) return false;

    _device = device;

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE
    );

    _transaction = Transaction.stringTerminated(
        _port!.inputStream as Stream<Uint8List>,
        Uint8List.fromList([13, 10])
    );

    _subscription = _transaction!.stream.listen(_processSerialData);

    return true;
  }

  void _processSerialData(String data) {
    try {
      final parsed = json.decode(data) as Map<String, dynamic>;
      final sensorData = SensorData.fromJson(parsed);
      _dataController.add(sensorData);
    } catch (e) {
      // Silent error handling
    }
  }

  void _disconnect() {
    _subscription?.cancel();
    _transaction?.dispose();
    _port?.close();
    _port = null;
    _device = null;
  }

  void dispose() {
    _dataController.close();
    _disconnect();
  }
}