class DetectedBeacon {
  double distance = 0.0;
  bool isCheck = false;
  DateTime lastTimeWhenNearest = DateTime.now();
  DateTime lastTimeWhenInScope = DateTime.now();

  DetectedBeacon({
    required this.distance,
  });
}
