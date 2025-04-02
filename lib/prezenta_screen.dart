import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'login_screen.dart';
import 'global_app_bar.dart';

Future<DateTime?> showMonthPickerDialog(BuildContext context) async {
  final List<String> monthNames = [
    "Ianuarie", "Februarie", "Martie", "Aprilie", "Mai", "Iunie",
    "Iulie", "August", "Septembrie", "Octombrie", "Noiembrie", "Decembrie"
  ];
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  List<int> years = List.generate(20, (index) => DateTime.now().year - index);
  return showDialog<DateTime>(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Selectează luna"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: selectedMonth,
                  items: List.generate(12, (index) {
                    return DropdownMenuItem<int>(
                      value: index + 1,
                      child: Text(monthNames[index]),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedMonth = value;
                      });
                    }
                  },
                ),
                DropdownButton<int>(
                  value: selectedYear,
                  items: years.map((year) {
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedYear = value;
                      });
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
                onPressed: () {
                  Navigator.of(context).pop(DateTime(selectedYear, selectedMonth, 1));
                },
                child: const Text("Export"),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<Uint8List> generateMonthlyAttendancePdf(String yearMonth) async {
  QuerySnapshot snapshot = await FirebaseFirestore.instance
      .collection('attendance')
      .where('date', isGreaterThanOrEqualTo: "$yearMonth-01")
      .where('date', isLessThan: "$yearMonth-32")
      .get();
  Map<String, List<DocumentSnapshot>> events = {};
  for (var doc in snapshot.docs) {
    String date = doc['date'];
    if (events.containsKey(date)) {
      events[date]!.add(doc);
    } else {
      events[date] = [doc];
    }
  }
  QuerySnapshot membersSnapshot = await FirebaseFirestore.instance.collection('members').get();
  Map<String, String> membersMap = {};
  for (var doc in membersSnapshot.docs) {
    membersMap[doc.id] = doc['name'];
  }
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        List<pw.Widget> widgets = [];
        DateTime dateForDisplay = DateTime.parse("$yearMonth-01");
        String displayMonth = DateFormat("MMMM yyyy", "ro_RO").format(dateForDisplay);
        widgets.add(
          pw.Text(
            "Raport de prezență pentru $displayMonth",
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
        );
        widgets.add(pw.SizedBox(height: 20));
        events.forEach((date, docs) {
          List<DocumentSnapshot> presentDocs = docs.where((doc) => doc['present'] == true).toList();
          if (presentDocs.isEmpty) return;
          List<List<String>> tableData = [];
          tableData.add(["Membru"]);
          for (var doc in presentDocs) {
            String memberId = doc['member_id'].toString();
            String name = membersMap[memberId] ?? memberId;
            tableData.add([name]);
          }
          String formattedDate = DateFormat("d MMMM y", "ro_RO").format(DateTime.parse(date));
          widgets.add(
            pw.Text(
              "Data: $formattedDate",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          );
          widgets.add(pw.SizedBox(height: 10));
          widgets.add(
            pw.Table.fromTextArray(
              headers: tableData.first,
              data: tableData.sublist(1),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          );
          widgets.add(pw.SizedBox(height: 20));
        });
        return widgets;
      },
    ),
  );
  return pdf.save();
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);
  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}
class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _members = [];
  Map<String, bool> _localAttendance = {};
  bool _isEditing = true;
  bool _userRequestedEdit = false;
  int _presentCount = 0;

  // ScrollController pentru a păstra poziția de scroll
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }
  Future<void> _loadMembers() async {
    QuerySnapshot membersSnapshot = await _firebaseService.members.get();
    setState(() {
      _members = membersSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'],
        };
      }).toList();
    });
  }
  Future<void> _saveAttendance() async {
    String formattedDateKey = DateFormat("yyyy-MM-dd").format(_selectedDate);
    await _firebaseService.saveAttendance(formattedDateKey, _localAttendance);
    setState(() {
      _isEditing = false;
      _userRequestedEdit = false;
      _presentCount = _localAttendance.values.where((present) => present).length;
      _localAttendance = {}; // Reset după salvare
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Prezență salvată pentru ${DateFormat("d MMMM y", "ro_RO").format(_selectedDate)}")),
    );
  }
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isEditing = true;
        _userRequestedEdit = false;
        _presentCount = 0;
        // Nu resetăm _localAttendance aici pentru a păstra modificările curente
      });
    }
  }
  Future<void> _downloadMonthlyPdf() async {
    DateTime? pickedMonth = await showMonthPickerDialog(context);
    if (pickedMonth != null) {
      String yearMonth = DateFormat("yyyy-MM").format(pickedMonth);
      Uint8List pdfData = await generateMonthlyAttendancePdf(yearMonth);
      await Printing.sharePdf(bytes: pdfData, filename: "raport_prezență_$yearMonth.pdf");
    }
  }
  // Funcție de refresh pentru AttendanceScreen
  void _refreshAttendance() {
    setState(() {
      // Resetăm _localAttendance pentru a reîncărca datele din stream
      _localAttendance = {};
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(title: "Prezență", onRefresh: _refreshAttendance),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Text("Data: ${DateFormat("d MMMM y", "ro_RO").format(_selectedDate)}",
                    style: const TextStyle(fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<Map<String, bool>>(
                stream: _firebaseService.getAttendanceStream(DateFormat("yyyy-MM-dd").format(_selectedDate)),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  final attendanceData = snapshot.data ?? {};
                  if (_localAttendance.isEmpty && attendanceData.isNotEmpty) {
                    _localAttendance = Map<String, bool>.from(attendanceData);
                  }
                  _presentCount = _localAttendance.values.where((present) => present).length;
                  return Column(
                    children: [
                      if (currentUserRole == UserRole.admin && !_isEditing)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("Total membri prezenți: $_presentCount",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      Expanded(
                        child: ListView.builder(
                          key: const PageStorageKey("attendance_list"),
                          controller: _scrollController,
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            String memberId = _members[index]['id'];
                            bool isPresent = _localAttendance[memberId] ?? false;
                            return CheckboxListTile(
                              title: Text(_members[index]['name']),
                              value: isPresent,
                              activeColor: Colors.deepPurple,
                              onChanged: currentUserRole == UserRole.admin
                                  ? (bool? value) {
                                setState(() {
                                  _localAttendance[memberId] = value ?? false;
                                });
                              }
                                  : null,
                            );
                          },
                        ),
                      ),
                      if (currentUserRole == UserRole.admin && _isEditing)
                        ElevatedButton(
                          onPressed: _saveAttendance,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text("Salvează prezența", style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.picture_as_pdf, color: Colors.white),
        onPressed: _downloadMonthlyPdf,
      ),
    );
  }
}
