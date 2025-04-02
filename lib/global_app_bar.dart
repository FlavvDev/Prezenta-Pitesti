import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onRefresh; // Callback pentru refresh, opțional
  const GlobalAppBar({Key? key, required this.title, this.onRefresh})
      : super(key: key);

  Future<void> _logout(BuildContext context) async {
    if (currentUserRole == UserRole.admin) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('isAdminLogged');
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    TextEditingController newPasswordController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Schimbă parola"),
          content: TextField(
            controller: newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: "Noua parolă"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Anulează"),
            ),
            TextButton(
              onPressed: () async {
                String newPassword = newPasswordController.text.trim();
                if (newPassword.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('settings').doc('admin').update({
                    'password': newPassword,
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Parola a fost actualizată")),
                  );
                }
              },
              child: const Text("Schimbă"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Setăm tema pentru iconițe:
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.deepPurple,
      elevation: 4,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      actions: [
        // Butonul de refresh, afișat doar dacă se furnizează un callback
        if (onRefresh != null)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurple.withOpacity(0.3), // fundal semi-transparent
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 30),
            ),
            onPressed: onRefresh,
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.settings, color: Colors.white),
          onSelected: (value) {
            if (value == 'logout') {
              _logout(context);
            } else if (value == 'changePassword') {
              _changePassword(context);
            }
          },
          itemBuilder: (BuildContext context) {
            List<PopupMenuEntry<String>> entries = [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text("Logout"),
              ),
            ];
            if (currentUserRole == UserRole.admin) {
              entries.insert(
                0,
                const PopupMenuItem<String>(
                  value: 'changePassword',
                  child: Text("Schimbă parola"),
                ),
              );
            }
            return entries;
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
