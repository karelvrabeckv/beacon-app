class Beacon {
  final String id;
  final String uuid;
  final String major;
  final String minor;
  final String mac;

  double distance;

  Beacon({
    required this.id,
    required this.uuid,
    required this.major,
    required this.minor,
    required this.mac,
    required this.distance,
  });
}
