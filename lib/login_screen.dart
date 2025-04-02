import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

// Definirea tipurilor de roluri
enum UserRole { admin, member }

// Variabilă globală pentru a reține rolul utilizatorului (implicit, membru)
UserRole currentUserRole = UserRole.member;

// Funcție pentru a prelua parola stocată în baza de date (din colecția "settings", documentul "admin")
Future<String> getStoredAdminPassword() async {
  DocumentSnapshot doc = await FirebaseFirestore.instance.collection('settings').doc('admin').get();
  if (doc.exists) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return data['password'] ?? '';
  }
  return '';
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  Future<void> _login(BuildContext context, UserRole role) async {
    if (role == UserRole.admin) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isAdminLogged = prefs.getBool('isAdminLogged') ?? false;
      if (isAdminLogged) {
        currentUserRole = role;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyApp()),
        );
        return;
      }
      TextEditingController passwordController = TextEditingController();
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Introdu parola administratorului"),
            content: TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: "Parola"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Anulează"),
              ),
              TextButton(
                onPressed: () async {
                  String storedPassword = await getStoredAdminPassword();
                  if (passwordController.text == storedPassword) {
                    await prefs.setBool('isAdminLogged', true);
                    Navigator.of(context).pop(); // Închide dialogul
                    currentUserRole = role;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MyApp()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Parola incorectă!")),
                    );
                  }
                },
                child: const Text("Login"),
              ),
            ],
          );
        },
      );
    } else {
      // Pentru membru, autentificarea se face direct
      currentUserRole = role;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyApp()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Autentificare", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _login(context, UserRole.admin),
              child: const Text("Login ca Administrator"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _login(context, UserRole.member),
              child: const Text("Login ca Membru"),
            ),
          ],
        ),
      ),
    );
  }
}
