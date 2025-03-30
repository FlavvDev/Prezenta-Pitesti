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

  // Lista de membri încărcată din colecția "members"
  List<Map<String, dynamic>> _members = [];
  // Variabila locală pentru prezență (modificările efectuate de utilizator)
  Map<String, bool> _localAttendance = {};

  // Controlul modului de editare
  bool _isEditing = true;
  // Flag care reține dacă utilizatorul a solicitat editare chiar dacă prezența e salvată
  bool _userRequestedEdit = false;
  int _presentCount = 0;

  // Conectivitate: status și abonament
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

  // Funcție care formatează un DateTime în formatul "15 martie 2024"
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
    // Cheia folosită în Firestore rămâne în format "yyyy-MM-dd"
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

    // Indicatorul de conectivitate: verde când online, roșu când offline
    Color connectivityColor = _connectionStatus == "Online" ? Colors.green[200]! : Colors.red[200]!;
    Widget connectivityIndicator = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      color: connectivityColor,
      child: Text(
        "Connection Status: $_connectionStatus",
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prezență"),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () async {
              String formattedDateKey = DateFormat("yyyy-MM-dd").format(_selectedDate);
              if (_isEditing) {
                // Salvează modificările dacă suntem în modul edit
                await _saveAttendance();
              } else {
                // Dacă nu suntem în modul edit, reîncarcă datele din Firestore și activează editarea
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
                Text("Data: $prettyDate"),
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

                  // Combină lista de membri încărcată din Firebase cu cei care apar în _localAttendance dar nu se găsesc în _members
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
                          child: Text("Total membri prezenți: $_presentCount"),
                        ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: unionMembers.length,
                          itemBuilder: (context, index) {
                            String memberId = unionMembers[index]['id'];
                            bool isPresent = _localAttendance[memberId] ?? false;
                            return CheckboxListTile(
                              title: Text(unionMembers[index]['name']),
                              value: isPresent,
                              onChanged: _isEditing
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
                      if (_isEditing)
                        ElevatedButton(
                          onPressed: _saveAttendance,
                          child: const Text("Salvează prezența"),
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
