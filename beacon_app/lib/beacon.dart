class Beacon {
  final int id;
  final String uuid;
  final int major;
  final int minor;

  Beacon({
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
    return 'Beacon{id: $id, uuid: $uuid, major: $major, minor: $minor}';
  }
}
