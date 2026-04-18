import 'dart:typed_data';
import 'dart:ui';
import 'package:casedesk/admin/policestation/chikalthana.dart';
import 'package:casedesk/admin/policestation/karmad.dart';
import 'package:casedesk/admin/policestation/phulambri.dart';
import 'package:casedesk/admin/policestation/vadodbazar.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart'; // ✅ ADDED

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  // ---------------- LOGIC ----------------
  String getBucketName(String type) {
    switch (type) {
      case 'plus10':
        return 'plus10';
      case 'minus10':
        return 'minus10';
      default:
        return 'application';
    }
  }

  Future<void> pickAndUploadExcel(String type, BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null) return;

      final Uint8List bytes = result.files.single.bytes!;
      final fileName = "${DateTime.now().millisecondsSinceEpoch}_$type.xlsx";

      final supabase = Supabase.instance.client;
      final bucket = getBucketName(type);

      await supabase.storage
          .from(bucket)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          );

      await supabase.functions.invoke(
        'excel-to-table',
        body: {
          'record': {'bucket_id': bucket, 'name': fileName},
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.blue,
            content: Text("$type Excel uploaded successfully"),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Error: $e")),
        );
      }
    }
  }

  void showUploadMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _uploadTile(
              context,
              "+10 Cases",
              Icons.add_circle_outline,
              'plus10',
            ),
            _uploadTile(
              context,
              "-10 Cases",
              Icons.remove_circle_outline,
              'minus10',
            ),
            _uploadTile(
              context,
              "ARJ Cases",
              Icons.description_outlined,
              'arj',
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadTile(
    BuildContext context,
    String title,
    IconData icon,
    String type,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context);
        pickAndUploadExcel(type, context);
      },
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EEF5),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
          ),

          Column(
            children: [
              // -------- HEADER --------
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                decoration: const BoxDecoration(color: Color(0xFF1A237E)),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Text(
                        "A",
                        style: TextStyle(
                          color: Color(0xFF1A237E),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hey, Admin 👋",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Good Morning",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ LOGOUT BUTTON (UPDATED)
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (context.mounted) {
                          context.go('/role'); // 👈 GoRouter navigation
                        }
                      },
                    ),
                  ],
                ),
              ),

              // -------- GRID --------
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _StationCard(
                        title: "Chikhalthana",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ChikhalthanaOfficerListScreen(),
                            ),
                          );
                        },
                      ),
                      _StationCard(
                        title: "Karmad",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const KarmadOfficerListScreen(),
                            ),
                          );
                        },
                      ),
                      _StationCard(
                        title: "Phulambri",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FulambriOfficerListScreen(),
                            ),
                          );
                        },
                      ),
                      _StationCard(
                        title: "VadodBazar",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const VadodbazarOfficerListScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () => showUploadMenu(context),
      ),
    );
  }
}

// ---------------- STATION CARD ----------------
class _StationCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _StationCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Card(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1A237E),
              ),
              child: const Icon(
                Icons.local_police,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
