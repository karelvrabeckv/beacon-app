class Attendance {
  final int id;
  final int student_id;
  final int classroom_id;
  final DateTime date_time;

  Attendance({
    required this.id,
    required this.student_id,
    required this.classroom_id,
    required this.date_time,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'student_id': student_id,
      'classroom_id': classroom_id,
      'date_time': date_time,
    };
  }

  @override
  String toString() {
    return 'Attendance{id: $id, student_id: $student_id, classroom_id: $classroom_id, date_time: $date_time}';
  }
}
