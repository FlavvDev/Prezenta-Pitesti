import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'package:intl/intl.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({Key? key}) : super(key: key);

  @override
  _TeamScreenState createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _members = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  // Încarcă membrii din Firestore, inclusiv data nașterii (opțional)
  Future<void> _loadMembers() async {
    QuerySnapshot snapshot = await _firebaseService.members.get();
    setState(() {
      _members = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'],
          'birthDate': data.containsKey('birthDate') ? data['birthDate'] : ""
        };
      }).toList();
    });
  }

  // Adaugă un membru nou; birthDate poate fi "" dacă nu este specificată.
  Future<void> _addMember(String name, String birthDate) async {
    if (name.isEmpty) return;
    try {
      await _firebaseService.addMember(name, birthDate); // asigură-te că metoda din firebase_service.dart este actualizată
      _loadMembers();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // Actualizează datele unui membru
  Future<void> _updateMember(String memberId, String name, String birthDate) async {
    await _firebaseService.updateMember(memberId, name, birthDate); // asigură-te că updateMember este implementat
    _loadMembers();
  }

  // Popup pentru adăugarea unui nou membru (nume + data nașterii opțional)
  Future<void> _showAddMemberDialog() async {
    TextEditingController nameController = TextEditingController();
    TextEditingController birthController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Adaugă membru"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: "Introdu numele membrului",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: birthController,
                readOnly: true,
                decoration: const InputDecoration(
                  hintText: "Data nașterii (opțional)",
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    // Formatează data; poți schimba formatul după preferință
                    birthController.text = DateFormat("yyyy-MM-dd").format(pickedDate);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await _addMember(nameController.text, birthController.text);
                Navigator.of(context).pop();
              },
              child: const Text("Adaugă membru"),
            ),
          ],
        );
      },
    );
  }

  // Popup care afișează detaliile unui membru:
  // nume, data nașterii (dacă există) și informații despre prezență,
  // plus un buton de Edit pentru a modifica numele și data nașterii.
  void _showMemberDetailsPopup(String memberId, String memberName, String birthDate) async {
    final attendance = await _calculateAttendance(memberId);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Detalii membru"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Nume: $memberName"),
              Text("Data nașterii: ${birthDate.isNotEmpty ? birthDate : "Nespecificată"}"),
              const SizedBox(height: 10),
              attendance['total'] > 0
                  ? Text("Total evenimente: ${attendance['total']}\nPrezențe: ${attendance['present']}\nRată de prezență: ${attendance['percentage'].toStringAsFixed(1)}%")
                  : const Text("Nu există înregistrări de prezență."),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Închide"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showEditMemberDialog(memberId, memberName, birthDate);
              },
              child: const Text("Edit"),
            ),
          ],
        );
      },
    );
  }

  // Popup pentru editarea detaliilor membrului (nume și data nașterii)
  void _showEditMemberDialog(String memberId, String currentName, String currentBirth) async {
    TextEditingController nameController = TextEditingController(text: currentName);
    TextEditingController birthController = TextEditingController(text: currentBirth);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Editează membru"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Nume membru",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: birthController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Data nașterii (opțional)",
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: currentBirth.isNotEmpty ? DateTime.parse(currentBirth) : DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    birthController.text = DateFormat("yyyy-MM-dd").format(pickedDate);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await _updateMember(memberId, nameController.text, birthController.text);
                Navigator.of(context).pop();
              },
              child: const Text("Salvează"),
            ),
          ],
        );
      },
    );
  }

  // Șterge un membru (cu confirmare)
  void _confirmDelete(String memberId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirmare ștergere"),
          content: const Text("Ești sigur că vrei să ștergi acest membru?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Anulează"),
            ),
            TextButton(
              onPressed: () {
                _deleteMember(memberId);
                Navigator.of(context).pop();
              },
              child: const Text("Șterge", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMember(String memberId) async {
    await _firebaseService.deleteMember(memberId);
    _loadMembers();
  }

  // Calculează prezența pentru un membru (la fel ca înainte)
  Future<Map<String, dynamic>> _calculateAttendance(String memberId) async {
    QuerySnapshot validSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('present', isEqualTo: true)
        .get();
    Set<String> validDates = {};
    for (var doc in validSnapshot.docs) {
      validDates.add(doc['date']);
    }
    QuerySnapshot memberSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('member_id', isEqualTo: memberId)
        .get();
    Map<String, bool> memberAttendanceMap = {};
    for (var doc in memberSnapshot.docs) {
      String date = doc['date'];
      bool present = doc['present'] == true;
      memberAttendanceMap[date] = present;
    }
    int totalEvents = validDates.length;
    int presentCount = 0;
    for (var date in validDates) {
      if (memberAttendanceMap[date] == true) {
        presentCount++;
      }
    }
    double percentage = totalEvents > 0 ? (presentCount / totalEvents) * 100 : 0;
    return {
      'total': totalEvents,
      'present': presentCount,
      'percentage': percentage,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Filtrarea membrilor în funcție de _searchQuery
    List<Map<String, dynamic>> filteredMembers = _searchQuery.isEmpty
        ? _members
        : _members.where((member) {
      String name = member['name'].toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Echipa",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Butonul de Adaugă membru (fără input direct pe ecran)
            ElevatedButton(
              onPressed: _showAddMemberDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Adaugă membru",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            // Bara de căutare pentru filtrarea membrilor după nume
            TextField(
              decoration: InputDecoration(
                labelText: "Caută după nume",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 20),
            // Lista de membri filtrată
            Expanded(
              child: filteredMembers.isEmpty
                  ? const Center(child: Text("Nu există membri în listă."))
                  : ListView.builder(
                itemCount: filteredMembers.length,
                itemBuilder: (context, index) {
                  final member = filteredMembers[index];
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        member['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: member['birthDate'] != null && member['birthDate'] != ""
                          ? Text("Data nașterii: ${member['birthDate']}")
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FutureBuilder<Map<String, dynamic>>(
                            future: _calculateAttendance(member['id']),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox(
                                  width: 40,
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                );
                              } else if (snapshot.hasError) {
                                return const Text(
                                  "0%",
                                  style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold),
                                );
                              }
                              final attendance = snapshot.data!;
                              double percentage = attendance['percentage'] as double;
                              Color percentageColor = percentage >= 50 ? Colors.green : Colors.red;
                              return Text(
                                "${percentage.toStringAsFixed(1)}%",
                                style: TextStyle(
                                    fontSize: 20,
                                    color: percentageColor,
                                    fontWeight: FontWeight.bold),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(member['id']),
                          ),
                        ],
                      ),
                      onTap: () => _showMemberDetailsPopup(
                          member['id'],
                          member['name'],
                          member['birthDate'] ?? ""),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
