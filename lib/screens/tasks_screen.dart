import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Map<String, dynamic>> _planned = [];
  List<Map<String, dynamic>> _sessionLog = [];
  List<Map<String, dynamic>> _completed = [];
  List<Map<String, dynamic>> _subjects = [];
  bool _loading = true;
  String? _selSubj;
  String _taskDesc = '';
  String _targetTime = 'No target';
  final _taskCtrl = TextEditingController();

  final List<String> _targetOptions = [
    '30 min', '1 hour', '1.5 hours', '2 hours', '3 hours', 'No target'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDoc = await FirebaseFirestore.instance
      .collection('users').doc(uid).get();
    final subjects = List<Map<String, dynamic>>.from(
      userDoc.data()?['subjects'] ?? []);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final sessions = await FirebaseFirestore.instance
      .collection('users').doc(uid).collection('sessions')
      .where('date', isEqualTo: today).get();
    final log = <Map<String, dynamic>>[];
    final done = <Map<String, dynamic>>[];
    for (final s in sessions.docs) {
      final data = {...s.data(), 'id': s.id};
      if (data['done'] == true) {
        done.add(data);
      } else {
        log.add(data);
      }
    }
    if (mounted) setState(() {
      _subjects = subjects;
      if (subjects.isNotEmpty) _selSubj = subjects[0]['name'];
      _sessionLog = log;
      _completed = done;
      _loading = false;
    });
  }

  Future<void> _addPlannedTask() async {
    if (_taskDesc.trim().isEmpty) return;
    final task = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'subject': _selSubj ?? 'General',
      'desc': _taskDesc.trim(),
      'target': _targetTime,
      'done': false,
    };
    setState(() {
      _planned.add(task);
      _taskDesc = '';
      _taskCtrl.clear();
    });
  }

  Future<void> _toggleDone(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final idx = _sessionLog.indexWhere((s) => s['id'] == id);
    if (idx == -1) return;
    final item = _sessionLog[idx];
    await FirebaseFirestore.instance
      .collection('users').doc(uid)
      .collection('sessions').doc(id)
      .update({'done': true});
    setState(() {
      _sessionLog.removeAt(idx);
      _completed.add({...item, 'done': true});
    });
  }

  String _fmtMins(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
  