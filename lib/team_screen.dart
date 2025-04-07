import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'global_app_bar.dart';

enum SortOption { name, attendance }

class TeamScreen extends StatefulWidget {
  const TeamScreen({Key? key}) : super(key: key);

  @override
  TeamScreenState createState() => TeamScreenState();
}

class TeamScreenState extends State<TeamScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _members = [];
  String _searchQuery = "";
  SortOption _sortOption = SortOption.name;
  // Map care stochează procentajul de prezență pentru fiecare membru (cheia este id-ul membrului)
  Map<String, double> _attendancePercentages = {};

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

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
    await _computeAttendancePercentages();
  }

  // Calculăm procentajul de prezență pentru fiecare membru și actualizăm _attendancePercentages
  Future<void> _computeAttendancePercentages() async {
    Map<String, double> newPercentages = {};
    for (var member in _members) {
      String id = member['id'];
      try {
        Map<String, dynamic> attendance = await _calculateAttendance(id);
        double percentage = attendance['percentage'] as double;
        newPercentages[id] = percentage;
      } catch (e) {
        newPercentages[id] = 0;
      }
    }
    setState(() {
      _attendancePercentages = newPercentages;
    });
  }

  // Metodă de refresh publică
  void refresh() {
    _loadMembers();
  }

  Future<void> _addMember(String name, String birthDate) async {
    if (name.isEmpty) return;
    try {
      await _firebaseService.addMember(name, birthDate);
      _loadMembers();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _updateMember(String memberId, String name, String birthDate) async {
    await _firebaseService.updateMember(memberId, name, birthDate);
    _loadMembers();
  }

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
                    birthController.text =
                        DateFormat("yyyy-MM-dd").format(pickedDate);
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

  // Metodă care calculează istoricul de prezență pentru un membru
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

  // Afișează popup-ul de detalii pentru un membru, inclusiv un buton "Istoric"
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
              Text(
                  "Data nașterii: ${birthDate.isNotEmpty ? DateFormat("d MMMM yyyy", "ro_RO").format(DateTime.parse(birthDate)) : "Nespecificată"}"),
              const SizedBox(height: 10),
              attendance['total'] > 0
                  ? Text(
                  "Total evenimente: ${attendance['total']}\nPrezențe: ${attendance['present']}\nRată de prezență: ${attendance['percentage'].toStringAsFixed(1)}%")
                  : const Text("Nu există înregistrări de prezență."),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Închide"),
            ),
            // Butonul Istoric pentru a afișa lista de prezențe
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showAttendanceHistoryPopup(memberId, memberName);
              },
              child: const Text("Istoric"),
            ),
            if (currentUserRole == UserRole.admin || currentUserRole == UserRole.member)
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

  // Afișează popup-ul pentru istoria prezențelor unui membru
  void _showAttendanceHistoryPopup(String memberId, String memberName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Istoric prezențe pentru $memberName"),
          content: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getMemberAttendanceHistory(memberId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                    height: 100, child: Center(child: CircularProgressIndicator()));
              } else if (snapshot.hasError) {
                return Text("Eroare: ${snapshot.error}");
              }
              final history = snapshot.data ?? [];
              if (history.isEmpty) {
                return const Text("Nu există prezențe înregistrate.");
              }
              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    DateTime date = DateTime.parse(item['date']);
                    String formattedDate =
                    DateFormat("d MMMM y", "ro_RO").format(date);
                    bool present = item['present'];
                    return ListTile(
                      title: Text(formattedDate),
                      subtitle: Text(present ? "Prezent" : "Absent"),
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
                    birthController.text =
                        DateFormat("yyyy-MM-dd").format(pickedDate);
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

  // Metoda care preia istoricul de prezențe pentru un membru
  Future<List<Map<String, dynamic>>> _getMemberAttendanceHistory(String memberId) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('member_id', isEqualTo: memberId)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      return {
        'date': doc['date'],
        'present': doc['present'] == true,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Filtrare după nume
    List<Map<String, dynamic>> filteredMembers = _searchQuery.isEmpty
        ? _members
        : _members.where((member) {
      String name = member['name'].toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    // Aplicăm sortarea
    if (_sortOption == SortOption.name) {
      filteredMembers.sort((a, b) => a['name']
          .toString()
          .toLowerCase()
          .compareTo(b['name'].toString().toLowerCase()));
    } else if (_sortOption == SortOption.attendance) {
      filteredMembers.sort((a, b) {
        double aPerc = _attendancePercentages[a['id']] ?? 0;
        double bPerc = _attendancePercentages[b['id']] ?? 0;
        return bPerc.compareTo(aPerc); // cei cu procent mai mare apar primele
      });
    }

    return Scaffold(
      appBar: GlobalAppBar(
        title: "Echipă",
        onRefresh: refresh,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Butonul de "Adaugă membru"
            if (currentUserRole == UserRole.admin || currentUserRole == UserRole.member)
              ElevatedButton(
                onPressed: _showAddMemberDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Adaugă membru",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            const SizedBox(height: 10),
            // Buton de sortare: la apăsare se afișează opțiunile de sortare
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<SortOption>(
                onSelected: (SortOption newOption) {
                  setState(() {
                    _sortOption = newOption;
                  });
                },
                itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<SortOption>>[
                  const PopupMenuItem<SortOption>(
                    value: SortOption.name,
                    child: Text("Nume"),
                  ),
                  const PopupMenuItem<SortOption>(
                    value: SortOption.attendance,
                    child: Text("Prezență"),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text("Sortare",
                        style: TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold)),
                    Icon(Icons.arrow_drop_down, color: Colors.deepPurple),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
            Expanded(
              child: filteredMembers.isEmpty
                  ? const Center(child: Text("Nu există membri în listă."))
                  : ListView.builder(
                key: const PageStorageKey("team_list"),
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
                      subtitle: member['birthDate'] != null &&
                          member['birthDate'] != ""
                          ? Text(
                          "Data nașterii: ${DateFormat("d MMMM yyyy", "ro_RO").format(DateTime.parse(member['birthDate']))}")
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FutureBuilder<Map<String, dynamic>>(
                            future: _calculateAttendance(member['id']),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
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
                              double percentage =
                              attendance['percentage'] as double;
                              Color percentageColor =
                              percentage >= 50 ? Colors.green : Colors.red;
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
                          if (currentUserRole == UserRole.admin ||
                              currentUserRole == UserRole.member)
                            IconButton(
                              icon:
                              const Icon(Icons.edit, color: Colors.deepPurple),
                              onPressed: () => _showEditMemberDialog(
                                  member['id'],
                                  member['name'],
                                  member['birthDate'] ?? ""),
                            ),
                          const SizedBox(width: 8),
                          if (currentUserRole == UserRole.admin)
                            IconButton(
                              icon:
                              const Icon(Icons.delete, color: Colors.red),
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
