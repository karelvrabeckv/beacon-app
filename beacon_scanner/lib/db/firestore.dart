import 'package:beacon_scanner/models/attendance.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class Firestore {
  FirebaseFirestore db = FirebaseFirestore.instance;

  Future<void> addAttendance(Attendance attendance) async {
    CollectionReference attendanceCollection = db.collection('attendance');
    await attendanceCollection.add(attendance.toJSON());
  }

  Future<List<Attendance>> getAttendanceByStudentId(int studentId) async {
    CollectionReference attendanceCollection = db.collection('attendance');
    QuerySnapshot result = await attendanceCollection.where('student_id', isEqualTo: studentId).get();

    List<Attendance> attendance = [];
    result.docs.forEach((document) {
      Map<String, dynamic> data = document.data() as Map<String, dynamic>;
      
      attendance.add(Attendance(
        student_id: data['student_id'],
        classroom_id: data['classroom_id'],
        date_time: data['date_time'],
      ));
    });

    return attendance;
  }
}
