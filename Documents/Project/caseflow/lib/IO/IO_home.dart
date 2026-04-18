import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvestigationOfficerHome extends StatefulWidget {
  const InvestigationOfficerHome({super.key});

  @override
  State<InvestigationOfficerHome> createState() =>
      _InvestigationOfficerHomeState();
}

class _InvestigationOfficerHomeState extends State<InvestigationOfficerHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String officerName = '';
  int reminderCount = 0;
  List<Map<String, dynamic>> reminders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _init();
  }

  Future<void> _init() async {
    await _fetchOfficerName();
    await _fetchReminderCount();
  }

  // ---------------- FETCH OFFICER NAME ----------------
  Future<void> _fetchOfficerName() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final res = await supabase
        .from('investigation_officer')
        .select('name')
        .eq('iid', user.id)
        .single();

    officerName = res['name'] ?? '';
    setState(() {});
  }

  // ---------------- FETCH REMINDER COUNT ----------------
  Future<void> _fetchReminderCount() async {
    if (officerName.isEmpty) return;

    final supabase = Supabase.instance.client;

    final res = await supabase
        .from('case_reminders')
        .select('id')
        .eq('investigation_officer', officerName)
        .eq('is_read', false);

    reminderCount = (res as List).length;
    setState(() {});
  }

  // ---------------- FETCH REMINDERS ----------------
  Future<void> _fetchReminders() async {
    if (officerName.isEmpty) return;

    final supabase = Supabase.instance.client;

    final res = await supabase
        .from('case_reminders')
        .select('id, case_id, case_table, admin_note, sent_at, is_read')
        .eq('investigation_officer', officerName)
        .order('sent_at', ascending: false);

    reminders = List<Map<String, dynamic>>.from(res);
    setState(() {});
  }

  // ---------------- MARK AS READ ----------------
  Future<void> _markAsRead(int id) async {
    print("MARK READ PRESSED FOR ID = $id");
    final supabase = Supabase.instance.client;

    await supabase
        .from('case_reminders')
        .update({'is_read': true})
        .eq('id', id);

    await _fetchReminderCount(); // refresh badge count from DB
    await _fetchReminders(); // refresh reminder list
  }

  // ---------------- REMINDER POPUP ----------------
  void _showReminderPopup() async {
    await _fetchReminders();
    await _fetchReminderCount(); // ensure badge sync when opening
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reminders'),
        content: reminders.isEmpty
            ? const Text('No reminders found')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: reminders.length,
                  itemBuilder: (context, i) {
                    final r = reminders[i];
                    final read = r['is_read'] == true;
                    final isRed = r['admin_note'].toString().contains('🔴');

                    return Card(
                      color: read
                          ? Colors.grey.shade200
                          : (isRed ? Colors.red.shade50 : Colors.white),
                      child: ListTile(
                        leading: Icon(
                          Icons.notifications_active,
                          color: read
                              ? Colors.grey
                              : (isRed ? Colors.red : Colors.orange),
                        ),
                        title: Text(
                          'Case ${r['case_table'].toUpperCase()} - ID ${r['case_id']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: read
                                ? Colors.grey
                                : (isRed ? Colors.red : Colors.black),
                          ),
                        ),
                        subtitle: Text(r['admin_note'] ?? ''),
                        trailing: read
                            ? const Icon(Icons.done, color: Colors.green)
                            : TextButton(
                                onPressed: () => _markAsRead(r['id']),
                                child: const Text('Mark Read'),
                              ),
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _fetchReminderCount(); // refresh badge after closing popup
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ---------------- FETCH CASES ----------------
  Future<List<Map<String, dynamic>>> _fetchCases(String table) async {
    final supabase = Supabase.instance.client;

    final res = await supabase
        .from(table)
        .select(
          table == 'arj'
              ? 'id, topic, date, created_at'
              : 'id, cr_no, created_at',
        )
        .eq('investigation_officer', officerName)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  // ---------------- FETCH CASE PROGRESS ----------------
  Future<Map<String, dynamic>?> _fetchProgress(int caseId, String table) async {
    final supabase = Supabase.instance.client;

    return await supabase
        .from('case_progress')
        .select()
        .eq('case_id', caseId)
        .eq('case_table', table)
        .maybeSingle();
  }

  // ---------------- CASE LIST ----------------
  Widget _caseList(String table) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchCases(table),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('No cases found'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final item = snapshot.data![index];

            return Card(
              margin: const EdgeInsets.all(10),
              color: Colors.white, // card color
              elevation: 3,
              shadowColor: Colors.grey.shade300,
              child: ListTile(
                title: Text(
                  table == 'arj' ? item['topic'] ?? '' : item['cr_no'] ?? '',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showCasePopup(context, table, item['id']),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------- CASE PROGRESS POPUP ----------------
  void _showCasePopup(BuildContext context, String table, int caseId) async {
    final progress = await _fetchProgress(caseId, table);

    bool fir = progress?['fir'] ?? false;
    bool ghatna = progress?['ghatna_sthal'] ?? false;
    bool attack = progress?['attack_aropi'] ?? false;
    bool gapti = progress?['gapti'] ?? false;
    bool atim = progress?['atim_avhal'] ?? false;

    final desc = TextEditingController(text: progress?['description'] ?? '');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Case Progress'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _check('FIR', fir, (v) => setState(() => fir = v)),
                _check(
                  'Ghatna Sthal',
                  ghatna,
                  (v) => setState(() => ghatna = v),
                ),
                _check(
                  'Attack Aropi',
                  attack,
                  (v) => setState(() => attack = v),
                ),
                _check('Gapti', gapti, (v) => setState(() => gapti = v)),
                _check('Atim Avhal', atim, (v) => setState(() => atim = v)),
                const SizedBox(height: 10),
                TextField(
                  controller: desc,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
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
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () async {
                final data = {
                  'case_id': caseId,
                  'case_table': table,
                  'investigation_officer': officerName,
                  'description': desc.text,
                  'fir': fir,
                  'ghatna_sthal': ghatna,
                  'attack_aropi': attack,
                  'gapti': gapti,
                  'atim_avhal': atim,
                };

                final supabase = Supabase.instance.client;

                if (progress != null) {
                  await supabase
                      .from('case_progress')
                      .update(data)
                      .eq('id', progress['id']);
                } else {
                  await supabase.from('case_progress').insert(data);
                }

                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _check(String t, bool v, Function(bool) c) =>
      CheckboxListTile(title: Text(t), value: v, onChanged: (x) => c(x!));

  // ---------------- LOGOUT ----------------
  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    context.go('/role');
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EEF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A237E),
        title: Text(
          officerName.isEmpty ? 'Investigation Officer' : officerName,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                color: Colors.white,
                onPressed: _showReminderPopup,
              ),
              if (reminderCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: Colors.red,
                    child: Text(
                      reminderCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            color: Colors.white,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, // selected tab text white
          unselectedLabelColor:
              Colors.white70, // unselected tab text slightly transparent white
          indicatorColor: Color(0xFF1A237E), // underline indicator color
          tabs: const [
            Tab(text: 'PLUS 10'),
            Tab(text: 'MINUS 10'),
            Tab(text: 'ARJ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_caseList('plus10'), _caseList('minus10'), _caseList('arj')],
      ),
    );
  }
}
