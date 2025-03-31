import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({Key? key}) : super(key: key);

  @override
  _AttendanceHistoryScreenState createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  // Set de evenimente extinse (pe bază de dată)
  final Set<String> _expandedEvents = {};

  // Încarcă istoricul prezenței: numără evenimentele (pe baza datei)
  Future<Map<String, int>> _loadAttendanceHistory() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('attendance').get();
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

  // Obține lista membrilor prezenți pentru o dată
  Future<List<Map<String, dynamic>>> _getPresentMembers(String date) async {
    QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('date', isEqualTo: date)
        .where('present', isEqualTo: true)
        .get();

    QuerySnapshot membersSnapshot =
    await FirebaseFirestore.instance.collection('members').get();
    Map<String, String> membersMap = {};
    for (var doc in membersSnapshot.docs) {
      membersMap[doc.id] = doc['name'];
    }
    List<Map<String, dynamic>> presentMembers = [];
    for (var doc in attendanceSnapshot.docs) {
      String memberId = doc['member_id'].toString();
      String name = membersMap.containsKey(memberId)
          ? membersMap[memberId]!
          : 'Membru șters';
      presentMembers.add({'id': memberId, 'name': name});
    }
    return presentMembers;
  }

  // Formatează data (de tip String) într-un format plăcut, ex. "15 Martie 2024"
  String _formatDate(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr);
      return DateFormat("d MMMM y", "ro_RO").format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  // Obține notița pentru un eveniment (din colecția "eventNotes", document id = data evenimentului)
  Future<String> _getEventNote(String date) async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('eventNotes')
        .doc(date)
        .get();
    if (doc.exists) {
      return doc['note'] ?? "";
    } else {
      return "";
    }
  }

  // Salvează notița pentru un eveniment
  Future<void> _saveEventNote(String date, String note) async {
    await FirebaseFirestore.instance
        .collection('eventNotes')
        .doc(date)
        .set({'note': note});
  }

  // Popup-ul pentru editarea și salvarea notiței unui eveniment
  void _showEventNotePopup(BuildContext context, String date) async {
    String currentNote = await _getEventNote(date);
    TextEditingController controller =
    TextEditingController(text: currentNote);
    bool isEditing = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Center(
                child: Text(
                  "Notiță pentru ${_formatDate(date)}",
                  style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 22),
                  textAlign: TextAlign.center,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    readOnly: !isEditing,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: "Adaugă o notiță...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (isEditing) {
                      // Renunță la editare și resetează textul
                      controller.text = currentNote;
                      setState(() {
                        isEditing = false;
                      });
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(isEditing ? "Renunță" : "Închide",
                      style: const TextStyle(color: Colors.deepPurple)),
                ),
                TextButton(
                  onPressed: () async {
                    if (!isEditing) {
                      // Activează modul de editare
                      setState(() {
                        isEditing = true;
                      });
                    } else {
                      // Salvează notița
                      await _saveEventNote(date, controller.text);
                      currentNote = controller.text;
                      setState(() {
                        isEditing = false;
                      });
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Notiță salvată")),
                      );
                    }
                  },
                  child: Text(isEditing ? "Salvează" : "Edit",
                      style: const TextStyle(color: Colors.deepPurple)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Funcție pentru ștergerea unui eveniment (cu confirmare și notificare)
  void _deleteEvent(BuildContext context, String date) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Confirmare",
              style: TextStyle(
                  color: Colors.deepPurple, fontWeight: FontWeight.bold)),
          content: const Text("Ești sigur că vrei să ștergi evenimentul?",
              style: TextStyle(color: Colors.deepPurple)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Anulează",
                  style: TextStyle(color: Colors.deepPurple)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Șterge",
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isEqualTo: date)
          .get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Eveniment șters cu succes")),
      );
      setState(() {
        _expandedEvents.remove(date);
      });
    }
  }

  // Popup-ul care afișează lista de membri prezenți și butonul de ștergere eveniment
  void _showPresentMembersPopup(BuildContext context, String date) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "Prezenți pe ${_formatDate(date)}",
            style: const TextStyle(
                color: Colors.deepPurple, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          content: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getPresentMembers(date),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()));
              } else if (snapshot.hasError) {
                return Text("Eroare: ${snapshot.error}",
                    style: const TextStyle(color: Colors.deepPurple));
              }
              final presentMembers = snapshot.data ?? [];
              if (presentMembers.isEmpty) {
                return const Text("Niciun membru prezent.",
                    style: TextStyle(color: Colors.deepPurple));
              }
              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: presentMembers.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(presentMembers[index]['name'],
                          style: const TextStyle(color: Colors.deepPurple)),
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Închide",
                  style: TextStyle(color: Colors.deepPurple)),
            ),
            TextButton(
              onPressed: () async {
                bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      title: const Text("Confirmare",
                          style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold)),
                      content: const Text("Ești sigur că vrei să ștergi evenimentul?",
                          style: TextStyle(color: Colors.deepPurple)),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop(false),
                          child: const Text("Anulează",
                              style: TextStyle(color: Colors.deepPurple)),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop(true),
                          child: const Text("Șterge",
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    );
                  },
                );
                if (confirm == true) {
                  QuerySnapshot snapshot = await FirebaseFirestore.instance
                      .collection('attendance')
                      .where('date', isEqualTo: date)
                      .get();
                  for (var doc in snapshot.docs) {
                    await doc.reference.delete();
                  }
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Eveniment șters cu succes")),
                  );
                  setState(() {
                    _expandedEvents.remove(date);
                  });
                }
              },
              child: const Text("Șterge eveniment",
                  style: TextStyle(color: Colors.red)),
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
        title: const Text(
          "Istoric Prezențe",
          style: TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
              fontSize: 24),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.deepPurple),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, int>>(
        future: _loadAttendanceHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text("Eroare: ${snapshot.error}",
                    style: const TextStyle(color: Colors.deepPurple)));
          }
          final history = snapshot.data ?? {};
          final dates = history.keys.toList()..sort((a, b) => b.compareTo(a));
          if (dates.isEmpty) {
            return const Center(
                child: Text("Nu există prezențe înregistrate.",
                    style: TextStyle(color: Colors.deepPurple)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dates.length,
            itemBuilder: (context, index) {
              String date = dates[index];
              int count = history[date]!;
              String prettyDate = _formatDate(date);
              bool isExpanded = _expandedEvents.contains(date);
              return InkWell(
                onTap: () => _showPresentMembersPopup(context, date),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.deepPurple,
                            child: Text(
                              "$count",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              prettyDate,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple),
                            ),
                          ),
                          // Butonul pentru notiță
                          IconButton(
                            icon: const Icon(Icons.note_add,
                                color: Colors.deepPurple),
                            onPressed: () {
                              _showEventNotePopup(context, date);
                            },
                          ),
                          // Butonul pentru extindere/colaps (gestionează doar notița)
                          IconButton(
                            icon: Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.arrow_forward_ios,
                              color: Colors.deepPurple,
                            ),
                            onPressed: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedEvents.remove(date);
                                } else {
                                  _expandedEvents.add(date);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (isExpanded)
                        FutureBuilder<String>(
                          future: _getEventNote(date),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: LinearProgressIndicator(),
                              );
                            } else if (snapshot.hasError) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text("Eroare la încărcarea notiței",
                                    style: TextStyle(color: Colors.deepPurple)),
                              );
                            }
                            String note = snapshot.data ?? "";
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                note.isNotEmpty ? note : "Fără notiță",
                                style: const TextStyle(
                                    color: Colors.deepPurple, fontSize: 16),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
