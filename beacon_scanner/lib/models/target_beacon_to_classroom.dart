class TargetBeaconToClassroom {
  final int? id;
  final int target_beacon_id;
  final int classroom_id;

  TargetBeaconToClassroom({
    this.id,
    required this.target_beacon_id,
    required this.classroom_id,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'target_beacon_id': target_beacon_id,
      'classroom_id': classroom_id,
    };
  }

  @override
  String toString() {
    return 'TargetBeaconToClassroom{id: $id, target_beacon_id: $target_beacon_id, classroom_id: $classroom_id}';
  }
}
