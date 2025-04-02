import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'team_screen.dart';
import 'prezenta_screen.dart';
import 'history_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

void enableOfflinePersistence() {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ro_RO', null);
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyC4KS1XPSuBGkSGSgdemnNvscmwoJ2TnmA",
        authDomain: "prezenta-filia.firebaseapp.com",
        projectId: "prezenta-filia",
        storageBucket: "prezenta-filia.firebasestorage.app",
        messagingSenderId: "551860221613",
        appId: "1:551860221613:web:eac4469de5e190e5a77824",
        measurementId: "G-B2G7D7JB4H",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  runApp(const MaterialApp(
    title: 'Prezență Echipă Dans',
    home: LoginScreen(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  _MyAppState createState() => _MyAppState();
}
class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  final List<Widget> _pages = const [
    TeamScreen(),
    AttendanceScreen(),
    AttendanceHistoryScreen(),
  ];
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prezență Echipa Dans',
      home: Scaffold(
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: "Echipă",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.check),
              label: "Prezență",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: "Istoric",
            ),
          ],
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
