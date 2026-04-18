import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfficerCasesScreen extends StatefulWidget {
  final String officerName;
  final String policeStation;

  const OfficerCasesScreen({
    super.key,
    required this.officerName,
    required this.policeStation,
  });

  @override
  State<OfficerCasesScreen> createState() => _OfficerCasesScreenState();
}

class _OfficerCasesScreenState extends State<OfficerCasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseClient supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // ================= FETCH CASES =================
  Future<List<Map<String, dynamic>>> fetchCases(String table) async {
    try {
      PostgrestFilterBuilder query = supabase
          .from(table)
          .select()
          .eq('investigation_officer', widget.officerName);

      // ARJ has no police_station
      if (table != 'arj') {
        query = query.ilike('police_station', '${widget.policeStation}%');
      }

      final res = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Case fetch error [$table]: $e');
      return [];
    }
  }

  // ================= FETCH PROGRESS =================
  Future<Map<String, dynamic>?> fetchProgress(int caseId, String table) async {
    return await supabase
        .from('case_progress')
        .select()
        .eq('case_id', caseId)
        .eq('case_table', table)
        .maybeSingle();
  }

  // ================= CASE POPUP =================
  void showCasePopup(BuildContext context, int caseId, String table) async {
    final progress = await fetchProgress(caseId, table);

    bool fir = progress?['fir'] ?? false;
    bool ghatna = progress?['ghatna_sthal'] ?? false;
    bool attack = progress?['attack_aropi'] ?? false;
    bool gapti = progress?['gapti'] ?? false;
    bool atim = progress?['atim_avhal'] ?? false;

    final noteController = TextEditingController(
      text: progress?['admin_note'] ?? '',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Case Progress'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _readonlyCheckbox('FIR', fir),
              _readonlyCheckbox('Ghatna Sthal', ghatna),
              _readonlyCheckbox('Attack Aropi', attack),
              _readonlyCheckbox('Gapti', gapti),
              _readonlyCheckbox('Atim Avhal', atim),
              const SizedBox(height: 15),
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
            child: const Text('Cancel'),
          ),

          // -------- SAVE NOTE --------
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save Note'),
            onPressed: () async {
              await supabase.from('case_progress').upsert({
                'case_id': caseId,
                'case_table': table,
                'investigation_officer': widget.officerName,
                'admin_note': noteController.text,
                'fir': fir,
                'ghatna_sthal': ghatna,
                'attack_aropi': attack,
                'gapti': gapti,
                'atim_avhal': atim,
              }, onConflict: 'case_id,case_table');

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Note saved')));
              }
            },
          ),

          // -------- SEND REMINDER --------
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Reminder sent')));
              }
            },
          ),
        ],
      ),
    );
  }

  // ================= READONLY CHECKBOX =================
  Widget _readonlyCheckbox(String title, bool value) {
    return CheckboxListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      value: value,
      onChanged: null,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  // ================= CASE LIST =================
  Widget caseList(String table) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchCases(table),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data ?? [];

        if (data.isEmpty) {
          return const Center(child: Text('No cases found'));
        }

        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) {
            final item = data[index];
            final caseId = item['id'];

            String title = table == 'arj'
                ? (item['topic'] ?? 'ARJ Case')
                : 'cr_no: ${item['cr_no'] ?? caseId}';

            String subtitle = table == 'arj'
                ? 'Date: ${item['date'] ?? ''}'
                : (item['section'] != null
                      ? 'Section: ${item['section']}'
                      : '');

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: subtitle.isEmpty ? null : Text(subtitle),
                trailing: table == 'arj'
                    ? const Icon(Icons.lock_outline, size: 18)
                    : const Icon(Icons.arrow_forward_ios, size: 16),

                // ❌ ARJ = NO POPUP
                onTap: table == 'arj'
                    ? null
                    : () => showCasePopup(context, caseId, table),
              ),
            );
          },
        );
      },
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EEF5),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Color(0xFF1A237E),
        title: Text(widget.officerName, style: TextStyle(color: Colors.white)),

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
