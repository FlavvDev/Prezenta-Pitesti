import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({Key? key}) : super(key: key);

  @override
  _TeamScreenState createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  // Încarcă membrii din Firestore
  Future<void> _loadMembers() async {
    QuerySnapshot snapshot = await _firebaseService.members.get();
    setState(() {
      _members = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'],
        };
      }).toList();
    });
  }

  // Funcție de adăugare a unui membru (cu verificare pentru nume necompletat sau duplicate, dacă dorești)
  Future<void> _addMember(String name) async {
    if (name.isEmpty) return;
    try {
      await _firebaseService.addMember(name);
      _controller.clear();
      _loadMembers();
    } catch (e) {
      // Poți afișa un mesaj de eroare în caz de duplicat sau altă problemă
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // Funcție pentru ștergerea unui membru
  Future<void> _deleteMember(String memberId) async {
    await _firebaseService.deleteMember(memberId);
    _loadMembers();
  }

  // Afișează popup-ul de confirmare
  void _confirmDelete(String memberId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmare ștergere"),
          content: const Text("Ești sigur că vrei să ștergi acest membru?"),
          actions: [
            TextButton(
              child: const Text("Anulează"),
              onPressed: () {
                Navigator.of(context).pop(); // Închide dialogul
              },
            ),
            TextButton(
              child: const Text("Șterge"),
              onPressed: () {
                _deleteMember(memberId);
                Navigator.of(context).pop(); // Închide dialogul după ștergere
              },
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
        title: const Text("Echipa"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // TextField pentru adăugarea unui nou membru
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Nume membru",
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _addMember(_controller.text),
              child: const Text("Adaugă membru"),
            ),
            const SizedBox(height: 20),
            // Lista de membri
            Expanded(
              child: ListView.builder(
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final member = _members[index];
                  return ListTile(
                    title: Text(member['name']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _confirmDelete(member['id']),
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
