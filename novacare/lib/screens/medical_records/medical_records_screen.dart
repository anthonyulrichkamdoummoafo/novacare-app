// medical_records_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});
      static const routeName = '/medical_record';


  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> records = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchRecords();
  }

  Future<void> fetchRecords() async {
    final response =
        await supabase.from('medical_records').select().order('created_at', ascending: false);
    if (!mounted) return;
    setState(() {
      records = List<Map<String, dynamic>>.from(response);
      loading = false;
    });
  }

  Future<void> deleteRecord(int id) async {
    await supabase.from('medical_records').delete().eq('id', id);
    if (!mounted) return;
    fetchRecords();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record deleted')),
    );
  }

  Future<void> submitRecord({
    int? id,
    required List<TextEditingController> symptoms,
    required List<TextEditingController> conditions,
    required List<TextEditingController> medications,
  }) async {
    final symptomsList = symptoms.map((c) => c.text).where((e) => e.isNotEmpty).toList();
    final conditionsList = conditions.map((c) => c.text).where((e) => e.isNotEmpty).toList();
    final medicationsList = medications.map((c) => c.text).where((e) => e.isNotEmpty).toList();

    // Validate non-empty input
    if (symptomsList.isEmpty && conditionsList.isEmpty && medicationsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill at least one field')),
      );
      return;
    }

    final data = {
      'symptoms': symptomsList.join(', '),
      'conditions': conditionsList.join(', '),
      'medications': medicationsList.join(', '),
      'user_id': supabase.auth.currentUser?.id,
    };

    if (id != null) {
      await supabase.from('medical_records').update(data).eq('id', id);
    } else {
      await supabase.from('medical_records').insert(data);
    }

    if (!mounted) return;
    Navigator.pop(context);
    fetchRecords();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(id != null ? 'Record updated' : 'Record added')),
    );
  }

  void showRecordForm({Map<String, dynamic>? record}) {
    final symptoms = _initControllers(record?['symptoms']);
    final conditions = _initControllers(record?['conditions']);
    final medications = _initControllers(record?['medications']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: Text(record == null ? 'Add Medical Record' : 'Edit Medical Record'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                children: [
                  buildFieldList('Symptom', symptoms, setModalState),
                  buildFieldList('Condition', conditions, setModalState),
                  buildFieldList('Medication', medications, setModalState),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _disposeControllers(symptoms + conditions + medications);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => submitRecord(
              id: record?['id'],
              symptoms: symptoms,
              conditions: conditions,
              medications: medications,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  List<TextEditingController> _initControllers(String? data) {
    if (data == null || data.trim().isEmpty) return [TextEditingController()];
    return data.split(',').map((e) => TextEditingController(text: e.trim())).toList();
  }

  void _disposeControllers(List<TextEditingController> controllers) {
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  Widget buildFieldList(
    String label,
    List<TextEditingController> controllers,
    void Function(void Function()) setModalState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...controllers.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: entry.value,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: '$label ${entry.key + 1}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        controllers.removeAt(entry.key);
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              controllers.add(TextEditingController());
              setModalState(() {});
            },
            icon: const Icon(Icons.add),
            label: Text('Add $label'),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String formatDateTime(String rawDate) {
    try {
      final dateTime = DateTime.parse(rawDate);
      return DateFormat('yyyy-MM-dd – kk:mm').format(dateTime);
    } catch (_) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text("Medical Records")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Your Medical Records",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: records.isEmpty
                        ? const Center(child: Text('No medical records found.'))
                        : ListView.builder(
                            itemCount: records.length,
                            itemBuilder: (context, index) {
                              final record = records[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.medical_services),
                                  title: RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: [
                                        TextSpan(
                                            text: 'Symptoms: ',
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: '${record['symptoms'] ?? ''}\n'),
                                        TextSpan(
                                            text: 'Conditions: ',
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: '${record['conditions'] ?? ''}\n'),
                                        TextSpan(
                                            text: 'Medications: ',
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: '${record['medications'] ?? ''}'),
                                      ],
                                    ),
                                  ),
                                  subtitle: Text(formatDateTime(record['created_at'] ?? '')),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => showRecordForm(record: record),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => deleteRecord(record['id']),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => showRecordForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Record'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
