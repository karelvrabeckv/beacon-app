class Attendance {
  final int student_id;
  final int classroom_id;
  final String date_time;

  Attendance({
    required this.student_id,
    required this.classroom_id,
    required this.date_time,
  });

  Map<String, dynamic> toJSON() {
    return {
      'student_id': student_id,
      'classroom_id': classroom_id,
      'date_time': date_time,
    };
  }
}
