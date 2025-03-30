import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({Key? key}) : super(key: key);

  /// Încarcă istoricul prezenței: pentru fiecare dată, numără câte documente (cu present true) există.
  Future<Map<String, int>> _loadAttendanceHistory() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .get();

    Map<String, int> history = {};
    for (var doc in snapshot.docs) {
      bool present = doc['present'] == true;
      if (present) {
        String date = doc['date'];
        if (history.containsKey(date)) {
          history[date] = history[date]! + 1;
        } else {
          history[date] = 1;
        }
      }
    }
    return history;
  }

  /// Pentru o dată dată, obține lista documentelor de prezență cu present == true,
  /// apoi returnează lista membrilor (cu numele) prezenți.
  Future<List<Map<String, dynamic>>> _getPresentMembers(String date) async {
    // Interogăm colecția "attendance" pentru data respectivă, unde 'present' este true.
    QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('date', isEqualTo: date)
        .where('present', isEqualTo: true)
        .get();

    // Încarcă toate documentele din colecția "members".
    QuerySnapshot membersSnapshot =
    await FirebaseFirestore.instance.collection('members').get();

    // Creăm un map cu id-ul membrului și numele acestuia.
    Map<String, String> membersMap = {};
    for (var doc in membersSnapshot.docs) {
      membersMap[doc.id] = doc['name'];
    }

    // Pentru fiecare document de prezență, obținem numele membrului (sau "Membru șters" dacă nu există).
    List<Map<String, dynamic>> presentMembers = [];
    for (var doc in attendanceSnapshot.docs) {
      String memberId = doc['member_id'].toString();
      String name = membersMap.containsKey(memberId) ? membersMap[memberId]! : 'Membru șters';
      presentMembers.add({'id': memberId, 'name': name});
    }
    return presentMembers;
  }

  /// Formatează data (de tip String, format "YYYY-MM-DD") într-un format frumos, de exemplu "15 Martie 2024".
  String _formatDate(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr);
      // Utilizează locale românească. Dacă nu e disponibil, se va folosi implicit.
      return DateFormat("d MMMM y", "ro_RO").format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  /// Afișează un dialog popup cu lista membrilor prezenți pe data specificată.
  void _showPresentMembersPopup(BuildContext context, String date) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Prezenți pe ${_formatDate(date)}"),
          content: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getPresentMembers(date),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()));
              } else if (snapshot.hasError) {
                return Text("Eroare: ${snapshot.error}");
              }
              final presentMembers = snapshot.data ?? [];
              if (presentMembers.isEmpty) {
                return const Text("Niciun membru prezent.");
              }
              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: presentMembers.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(presentMembers[index]['name']),
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Închide"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Istoric Prezențe"),
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _loadAttendanceHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Eroare: ${snapshot.error}"));
          }
          final history = snapshot.data ?? {};
          // Sortăm datele descrescător, astfel încât cele mai recente să fie primele.
          final dates = history.keys.toList()..sort((a, b) => b.compareTo(a));
          if (dates.isEmpty) {
            return const Center(child: Text("Nu există prezențe înregistrate."));
          }
          return ListView.builder(
            itemCount: dates.length,
            itemBuilder: (context, index) {
              String date = dates[index];
              int count = history[date]!;
              String prettyDate = _formatDate(date);
              return ListTile(
                title: Text(prettyDate),
                trailing: Text(
                  "$count",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  _showPresentMembersPopup(context, date);
                },
              );
            },
          );
        },
      ),
    );
  }
}
