class TargetBeacon {
  final int id;
  final String uuid;
  final int major;
  final int minor;

  TargetBeacon({
    required this.id,
    required this.uuid,
    required this.major,
    required this.minor,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'major': major,
      'minor': minor,
    };
  }

  @override
  String toString() {
    return 'TargetBeacon{id: $id, uuid: $uuid, major: $major, minor: $minor}';
  }
}
