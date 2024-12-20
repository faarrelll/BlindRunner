class SensorData {
  final int distance;
  final int heartRate;

  SensorData({
    required this.distance,
    required this.heartRate,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      distance: json['distance'] ?? 0,
      heartRate: json['heartRate'] ?? 0,
    );
  }
}