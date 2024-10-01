class TargetBeacon {
  final int? id;
  final String mac;
  final String uuid;
  final int major;
  final int minor;

  TargetBeacon({
    this.id,
    required this.mac,
    required this.uuid,
    required this.major,
    required this.minor,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'mac': mac,
      'uuid': uuid,
      'major': major,
      'minor': minor,
    };
  }
}
