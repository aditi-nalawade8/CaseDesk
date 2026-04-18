import 'package:casedesk/admin/policestation/vadod_officer_case.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VadodbazarOfficerListScreen extends StatefulWidget {
  const VadodbazarOfficerListScreen({super.key});

  @override
  State<VadodbazarOfficerListScreen> createState() =>
      _VadodbazarOfficerListScreenState();
}

class _VadodbazarOfficerListScreenState
    extends State<VadodbazarOfficerListScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  /// 🔹 Fetch all officers of वडोदबाजार
  Future<List<Map<String, dynamic>>> fetchOfficers() async {
    try {
      final List<dynamic> res = await supabase
          .from('investigation_officer')
          .select('iid, name')
          .ilike('police_station', 'वडोदबाजार%')
          .order('name');

      return res
          .where(
            (row) => row['name'] != null && row['name'].toString().isNotEmpty,
          )
          .map<Map<String, dynamic>>(
            (row) => {'id': row['iid'], 'name': row['name']},
          )
          .toList();
    } catch (e) {
      debugPrint('Vadodbazar officer fetch error: $e');
      return [];
    }
  }

  /// ===============================
  /// ADD IO POPUP
  /// ===============================
  void _showAddIoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Investigation Officer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: 'वडोदबाजार',
                enabled: false,
                decoration: const InputDecoration(labelText: 'Police Station'),
              ),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(onPressed: _createIo, child: const Text('Add IO')),
        ],
      ),
    );
  }

  /// ===============================
  /// CREATE IO
  /// ===============================
  Future<void> _createIo() async {
    try {
      await supabase.functions.invoke(
        'create-io',
        body: {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text.trim(),
          'police_station': 'वडोदबाजार',
        },
      );

      _nameCtrl.clear();
      _emailCtrl.clear();
      _passwordCtrl.clear();

      Navigator.pop(context);
      setState(() {});

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('IO added successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// ===============================
  /// DELETE CONFIRMATION
  /// ===============================
  void _confirmDelete(String userId, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Officer'),
        content: Text('Delete $name permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _deleteIo(userId),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// ===============================
  /// DELETE IO
  /// ===============================
  Future<void> _deleteIo(String userId) async {
    try {
      await supabase.functions.invoke('delete-io', body: {'user_id': userId});

      Navigator.pop(context);
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Officer deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EEF5),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF1A237E),
        title: const Text(
          'Vadodbazar Police Station',
          style: TextStyle(color: Colors.white),
        ),

        // ✅ ADD BUTTON MOVED TO APPBAR
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Add IO',
            onPressed: _showAddIoDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchOfficers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final officers = snapshot.data ?? [];

          if (officers.isEmpty) {
            return const Center(child: Text('No officers found'));
          }

          return ListView.builder(
            itemCount: officers.length,
            itemBuilder: (context, index) {
              final officer = officers[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF1A237E),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    officer['name'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        child: const Text(
                          'View Cases',
                          style: TextStyle(color: Color(0xFF1A237E)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VadodbazarOfficerCaseScreen(
                                officerName: officer['name'],
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _confirmDelete(officer['id'], officer['name']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
