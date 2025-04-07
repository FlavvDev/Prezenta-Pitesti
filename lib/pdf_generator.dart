import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> generateMonthlyAttendancePdf(String yearMonth) async {
  // Convertim yearMonth (ex: "2025-03") într-un DateTime pentru a obține numele lunii
  DateTime monthDate = DateTime.parse("$yearMonth-01");
  String formattedMonth = DateFormat("MMMM yyyy", "ro_RO").format(monthDate);

  // Obține toate documentele din colecția 'attendance' pentru luna respectivă.
  QuerySnapshot snapshot = await FirebaseFirestore.instance
      .collection('attendance')
      .where('date', isGreaterThanOrEqualTo: "$yearMonth-01")
      .where('date', isLessThan: "$yearMonth-32")
      .get();

  // Grupăm documentele după data evenimentului.
  Map<String, List<DocumentSnapshot>> events = {};
  for (var doc in snapshot.docs) {
    String date = doc['date'];
    if (events.containsKey(date)) {
      events[date]!.add(doc);
    } else {
      events[date] = [doc];
    }
  }

  // Obține lista membrilor pentru a mapa memberId la nume.
  QuerySnapshot membersSnapshot =
  await FirebaseFirestore.instance.collection('members').get();
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
        widgets.add(
          pw.Text(
            "Raport de prezenta pentru $formattedMonth",
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 20));

        // Pentru fiecare eveniment din lună, adaugă un titlu și un tabel.
        events.forEach((date, docs) {
          // Filtrăm documentele pentru care 'present' este true.
          List<DocumentSnapshot> presentDocs =
          docs.where((doc) => doc['present'] == true).toList();

          // Dacă nu există niciun document valid pentru eveniment, sărim peste el.
          if (presentDocs.isEmpty) return;

          // Construim datele pentru tabel: doar membrii care au fost prezenți.
          List<List<String>> tableData = [];
          tableData.add(["Membru"]); // Headerul tabelului.
          for (var doc in presentDocs) {
            String memberId = doc['member_id'].toString();
            String name = membersMap[memberId] ?? memberId;
            tableData.add([name]);
          }

          // Formatăm data evenimentului într-un format plăcut
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