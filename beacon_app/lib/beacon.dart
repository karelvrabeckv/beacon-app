class Beacon {
  final String uuid;
  final int major;
  final int minor;

  Beacon({
    required this.uuid,
    required this.major,
    required this.minor,
  });

  Map<String, Object?> toMap() {
    return {
      'uuid': uuid,
      'major': major,
      'minor': minor,
    };
  }

  @override
  String toString() {
    return 'Beacon{uuid: $uuid, major: $major, minor: $minor}';
  }
}
