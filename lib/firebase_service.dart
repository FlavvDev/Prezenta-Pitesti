import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Colecția de membri
  CollectionReference get members => _db.collection('members');

  // Colecția de prezență
  CollectionReference get attendance => _db.collection('attendance');

  // Adaugă un membru (verificare case-insensitive, dacă dorești poți modifica și aici)
  Future<void> addMember(String name, [String birthDate = ""]) async {
    QuerySnapshot querySnapshot = await members.where('name', isEqualTo: name).get();
    if (querySnapshot.docs.isNotEmpty) {
      throw Exception('Numele există deja.');
    }
    await members.add({'name': name, 'birthDate': birthDate});
  }

  // Actualizează un membru (nume și data nașterii)
  Future<void> updateMember(String memberId, String name, String birthDate) async {
    await members.doc(memberId).update({
      'name': name,
      'birthDate': birthDate,
    });
  }

  // Șterge un membru
  Future<void> deleteMember(String docId) async {
    await members.doc(docId).delete();
  }

  // Obține lista de membri
  Stream<QuerySnapshot> getMembersStream() {
    return members.snapshots();
  }

  // Salvează sau actualizează prezența pentru un membru la o anumită dată
  Future<void> saveAttendance(String date, Map<String, bool> attendanceMap) async {
    for (var entry in attendanceMap.entries) {
      String docId = "${date}_${entry.key}";
      await attendance.doc(docId).set({
        'member_id': entry.key,
        'date': date,
        'present': entry.value,
      });
    }
  }

  Stream<Map<String, bool>> getAttendanceStream(String date) {
    return FirebaseFirestore.instance
        .collection('attendance')
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) {
      final Map<String, bool> attendanceMap = {};
      for (var doc in snapshot.docs) {
        attendanceMap[doc['member_id'].toString()] = doc['present'] == true;
      }
      return attendanceMap;
    });
  }

  Future<Map<String, bool>> getAttendance(String date) async {
    QuerySnapshot snapshot =
    await attendance.where('date', isEqualTo: date).get();
    Map<String, bool> attendanceMap = {};
    for (var doc in snapshot.docs) {
      String memberId = doc['member_id'].toString();
      bool present = doc['present'] == true;
      attendanceMap[memberId] = present;
    }
    return attendanceMap;
  }
}
