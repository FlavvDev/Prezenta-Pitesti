import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_service.dart';

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
  String _connectionStatus = "Unknown";
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          (List<ConnectivityResult> results) {
        final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
        setState(() {
          _connectionStatus = (result == ConnectivityResult.none) ? "Offline" : "Online";
        });
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    QuerySnapshot membersSnapshot = await _firebaseService.members.get();
    setState(() {
      _members = membersSnapshot.docs.map((doc) {
        return {'id': doc.id, 'name': doc['name']};
      }).toList();
    });
  }

  // Formatează data într-un format plăcut, de ex. "15 Martie 2024"
  String _formatDateFromDateTime(DateTime dt) {
    return DateFormat("d MMMM y", "ro_RO").format(dt);
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
        _localAttendance.clear();
      });
    }
  }

  Future<void> _saveAttendance() async {
    String formattedDateDisplay = _formatDateFromDateTime(_selectedDate);
    String formattedDateKey = DateFormat("yyyy-MM-dd").format(_selectedDate);
    await _firebaseService.saveAttendance(formattedDateKey, _localAttendance);
    setState(() {
      _isEditing = false;
      _userRequestedEdit = false;
      _presentCount = _localAttendance.values.where((present) => present).length;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Prezență salvată pentru $formattedDateDisplay")),
    );
  }

  @override
  Widget build(BuildContext context) {
    String prettyDate = _formatDateFromDateTime(_selectedDate);
    Color connectivityColor = _connectionStatus == "Online" ? Colors.green[200]! : Colors.red[200]!;
    Widget connectivityIndicator = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      color: connectivityColor,
      child: Text(
        "Connection Status: $_connectionStatus",
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Prezență",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit, color: Colors.white),
            onPressed: () async {
              String formattedDateKey = DateFormat("yyyy-MM-dd").format(_selectedDate);
              if (_isEditing) {
                await _saveAttendance();
              } else {
                Map<String, bool> currentData = await _firebaseService.getAttendanceStream(formattedDateKey).first;
                setState(() {
                  _localAttendance = Map<String, bool>.from(currentData);
                  _isEditing = true;
                  _userRequestedEdit = true;
                });
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            connectivityIndicator,
            Row(
              children: [
                Text("Data: $prettyDate", style: const TextStyle(fontSize: 16)),
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
                  if (_localAttendance.isEmpty) {
                    _localAttendance = Map<String, bool>.from(attendanceData);
                  }
                  if (attendanceData.isNotEmpty && !_userRequestedEdit) {
                    if (_isEditing) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _isEditing = false;
                          });
                        }
                      });
                    }
                  }
                  _presentCount = _localAttendance.values.where((present) => present).length;
                  List<Map<String, dynamic>> unionMembers = List.from(_members);
                  for (var memberId in _localAttendance.keys) {
                    bool exists = unionMembers.any((member) => member['id'] == memberId);
                    if (!exists) {
                      unionMembers.add({'id': memberId, 'name': 'Membru șters'});
                    }
                  }
                  return Column(
                    children: [
                      if (!_isEditing)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("Total membri prezenți: $_presentCount", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: unionMembers.length,
                          itemBuilder: (context, index) {
                            String memberId = unionMembers[index]['id'];
                            bool isPresent = _localAttendance[memberId] ?? false;
                            return Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: CheckboxListTile(
                                title: Text(unionMembers[index]['name']),
                                value: isPresent,
                                activeColor: Colors.green,
                                onChanged: _isEditing
                                    ? (bool? value) {
                                  setState(() {
                                    _localAttendance[memberId] = value ?? false;
                                  });
                                }
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                      if (_isEditing)
                        ElevatedButton(
                          onPressed: _saveAttendance,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "Salvează prezența",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                    ],
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
