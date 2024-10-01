class DetectedBeacon {
  int currCheck = 0;
  double distance = 0.0;
  bool isCheck = false;
  DateTime lastTimeWhenNearest = DateTime.now();
  DateTime lastTimeWhenInScope = DateTime.now();

  DetectedBeacon({
    required this.distance,
  });

  void resetCurrCheck() {
    currCheck = 0;
  }

  void incrementCurrCheck() {
    currCheck += 1;
  }
}
