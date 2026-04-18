import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfficerCasesKarmadScreen extends StatefulWidget {
  final String officerName;

  const OfficerCasesKarmadScreen({super.key, required this.officerName});

  @override
  State<OfficerCasesKarmadScreen> createState() =>
      _OfficerCasesKarmadScreenState();
}

class _OfficerCasesKarmadScreenState extends State<OfficerCasesKarmadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseClient supabase = Supabase.instance.client;

  static const String policeStation = 'करमाड';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // ---------------- FETCH CASES ----------------
  Future<List<Map<String, dynamic>>> fetchCases(String table) async {
    try {
      PostgrestFilterBuilder query = supabase
          .from(table)
          .select()
          .eq('investigation_officer', widget.officerName);

      // 🚫 ARJ does NOT have police_station
      if (table != 'arj') {
        query = query.eq('police_station', policeStation);
      }

      final response = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Fetch error [$table]: $e');
      return [];
    }
  }

  // ---------------- FETCH PROGRESS ----------------
  Future<Map<String, dynamic>> fetchProgress(int caseId, String table) async {
    try {
      final res = await supabase
          .from('case_progress')
          .select()
          .eq('case_id', caseId)
          .eq('case_table', table)
          .maybeSingle();

      return res == null ? {} : Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint('Progress error: $e');
      return {};
    }
  }

  // ---------------- CASE POPUP (PLUS/MINUS ONLY) ----------------
  void showCasePopup(int caseId, String table) async {
    final progress = await fetchProgress(caseId, table);

    final TextEditingController noteController = TextEditingController(
      text: progress['admin_note'] ?? '',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Case Progress'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _readOnlyCheckbox('FIR', progress['fir'] ?? false),
              _readOnlyCheckbox(
                'Ghatna Sthal',
                progress['ghatna_sthal'] ?? false,
              ),
              _readOnlyCheckbox(
                'Attack Aropi',
                progress['attack_aropi'] ?? false,
              ),
              _readOnlyCheckbox('Gapti', progress['gapti'] ?? false),
              _readOnlyCheckbox('Atim Avhal', progress['atim_avhal'] ?? false),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Admin Note',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),

          /// SAVE NOTE
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save Note'),
            onPressed: () async {
              await supabase.from('case_progress').upsert({
                'case_id': caseId,
                'case_table': table,
                'admin_note': noteController.text,
              }, onConflict: 'case_id,case_table');

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Note saved successfully')),
                );
              }
            },
          ),

          /// SEND REMINDER
          ElevatedButton.icon(
            icon: const Icon(Icons.alarm),
            label: const Text('Send Reminder'),
            onPressed: () async {
              await supabase.from('case_reminders').insert({
                'case_id': caseId,
                'case_table': table,
                'admin_note': noteController.text,
                'sent_at': DateTime.now().toIso8601String(),
              });

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reminder sent successfully')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------------- READ-ONLY CHECKBOX ----------------
  Widget _readOnlyCheckbox(String title, bool value) {
    return CheckboxListTile(
      value: value,
      onChanged: null,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  // ---------------- CASE LIST ----------------
  Widget caseList(String table) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchCases(table),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No cases found'));
        }

        final cases = snapshot.data!;

        return ListView.builder(
          itemCount: cases.length,
          itemBuilder: (context, index) {
            final item = cases[index];
            final caseId = item['id'];

            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(
                  table == 'arj'
                      ? item['topic'] ?? 'ARJ Case'
                      : 'cr_no: ${item['cr_no'] ?? caseId}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: item['section'] != null
                    ? Text('Section: ${item['section']}')
                    : null,
                trailing: table == 'arj'
                    ? const Icon(Icons.lock_outline, size: 18)
                    : const Icon(Icons.arrow_forward_ios, size: 16),

                // 🚫 NO POPUP FOR ARJ
                onTap: table == 'arj'
                    ? null
                    : () => showCasePopup(caseId, table),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EEF5),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.officerName, style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF1A237E),
        bottom: TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          controller: _tabController,
          tabs: const [
            Tab(text: 'PLUS 10'),
            Tab(text: 'MINUS 10'),
            Tab(text: 'ARJ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [caseList('plus10'), caseList('minus10'), caseList('arj')],
      ),
    );
  }
}
