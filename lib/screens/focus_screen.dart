import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';
import '../theme/app_theme.dart';
import '../widgets/theme_decoration_layer.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with SingleTickerProviderStateMixin {

  // ── Timer ──
  bool _running = false;
  bool _onBreak = false;
  int _totalSecs      = 25 * 60;
  int _remSecs        = 25 * 60;
  int _secsAtLastSave = 25 * 60;
  Timer? _timer;
  Timer? _tickerTimer;
  int _tickerIndex = 0;
  String _modeName    = 'POMODORO';
  int    _modeMinutes = 25;

  // ── Session ──
  Map<String, dynamic>? _curSubj;
  String _taskNote = '';
  List<Map<String, dynamic>> _subjects = [];

  // ── Tasks ──
  List<_Task> _tasks = [];

  // ── Stats ──
  int _pomCount  = 0;
  int _todayMins = 0;
  int _weekMins  = 0;
  int _streak    = 0;
  int _rank      = 0;

  // ── Sound ──
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _soundChoice = 'bell';

  // ── Ticker ──
  final List<String> _tickers = [
    '🔥 Your future self is watching. Don\'t embarrass them.',
    '💀 Every minute you waste, someone else is studying.',
    '⚡ Pain is temporary. L results are forever.',
    '🧠 You didn\'t come this far to only come this far.',
    '😤 The grind doesn\'t care about your mood.',
    '🏆 Mediocrity is always comfortable. That\'s the trap.',
    '📚 Stop checking your phone. It won\'t study for you.',
    '🔥 Your streak is on the line. Don\'t be that person.',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startTicker();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tickerTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTicker() {
    _tickerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() =>
          _tickerIndex = (_tickerIndex + 1) % _tickers.length);
    });
  }

  // ─────────────────────────────────────────────
  //  LOAD DATA
  // ─────────────────────────────────────────────
  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // FIX: retry up to 5 times with 800ms delay to handle onboarding write lag
    for (int attempt = 0; attempt < 5; attempt++) {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      if (doc.exists) {
        final data     = doc.data()!;
        final subjects = List<Map<String, dynamic>>.from(
            data['subjects'] ?? []);

        if (subjects.isNotEmpty || attempt == 4) {
          if (mounted) setState(() {
            _subjects    = subjects;
            if (_subjects.isNotEmpty && _curSubj == null) {
              _curSubj = _subjects[0];
            }
            _streak      = (data['streak'] ?? 0) as int;
            _pomCount    = (data['totalSessions'] ?? 0) as int;
            _soundChoice = (data['soundChoice'] ?? 'bell') as String;

            final mode = data['pomodoroMode'] ?? 'classic';
            if (mode == 'deep')        { _modeMinutes = 50; _modeName = 'DEEP WORK'; }
            else if (mode == 'sprint') { _modeMinutes = 15; _modeName = 'SPRINT'; }
            else                       { _modeMinutes = 25; _modeName = 'POMODORO'; }
            _totalSecs      = _modeMinutes * 60;
            _remSecs        = _totalSecs;
            _secsAtLastSave = _totalSecs;
          });
          break;
        }
      }
      await Future.delayed(const Duration(milliseconds: 800));
    }

    await _loadStats();
    await _loadTasks();
  }

  Future<void> _loadStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final today   = DateTime.now().toIso8601String().substring(0, 10);
    final weekAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String().substring(0, 10);

    final sessions = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('sessions')
        .where('date', isGreaterThanOrEqualTo: weekAgo).get();

    int todayM = 0, weekM = 0;
    for (final s in sessions.docs) {
      final m = (s['minutes'] as int? ?? 0);
      weekM += m;
      if (s['date'] == today) todayM += m;
    }

    final lb = await FirebaseFirestore.instance
        .collection('users').orderBy('xp', descending: true)
        .limit(100).get();
    final rank = lb.docs.indexWhere((d) => d.id == uid) + 1;

    if (mounted) setState(() {
      _todayMins = todayM;
      _weekMins  = weekM;
      _rank      = rank;
    });
  }

  Future<void> _loadTasks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('tasks')
        .orderBy('createdAt', descending: false)
        .get();
    if (mounted) setState(() {
      _tasks = snap.docs.map((d) => _Task(
        id:          d.id,
        subject:     (d['subject']     ?? '') as String,
        description: (d['description'] ?? '') as String,
        targetMins:  (d['targetMins']  ?? 0)  as int,
        done:        (d['done']        ?? false) as bool,
      )).toList();
    });
  }

  // ─────────────────────────────────────────────
  //  TIMER LOGIC
  // ─────────────────────────────────────────────
  void _setMode(int mins, String name) {
    if (_running) return;
    _timer?.cancel();
    setState(() {
      _modeMinutes    = mins;
      _modeName       = name;
      _totalSecs      = mins * 60;
      _remSecs        = mins * 60;
      _secsAtLastSave = mins * 60;
      _running        = false;
      _onBreak        = name == 'BREAK';
    });
  }

  void _handleStart() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      if (!_onBreak) _logSession(fromPause: true);
    } else if (_remSecs < _totalSecs) {
      _startCountdown();
    } else if (_onBreak) {
      _showBreakStartDialog();
    } else {
      _showSubjectPicker();
    }
  }

  void _startCountdown() {
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remSecs <= 0) {
        t.cancel();
        _onComplete();
      } else {
        setState(() => _remSecs--);
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _running        = false;
      _remSecs        = _totalSecs;
      _secsAtLastSave = _totalSecs;
    });
  }

  void _quitEarly() {
    if (_remSecs == _totalSecs && !_running) return;
    _timer?.cancel();
    setState(() => _running = false);
    _logSession(fromPause: false);
    _resetTimer();
  }

  void _onComplete() {
    if (!_onBreak) _logSession(fromPause: false);
    _playSound();
    setState(() {
      _pomCount++;
      _running        = false;
      _remSecs        = _totalSecs;
      _secsAtLastSave = _totalSecs;
    });
    _showCompleteDialog();
  }

  // ─────────────────────────────────────────────
  //  SOUND
  // ─────────────────────────────────────────────
  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$_soundChoice.mp3'));
    } catch (_) {
      // Sound files not yet added — silently skip
    }
  }

  // ─────────────────────────────────────────────
  //  FIRESTORE: LOG SESSION + STREAK
  // ─────────────────────────────────────────────
  Future<void> _logSession({required bool fromPause}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final spent = _secsAtLastSave - _remSecs;
    if (spent < 30) return;
    final mins = (spent / 60).round();

    if (mounted) setState(() => _secsAtLastSave = _remSecs);

    final subjName = _curSubj?['name'] as String? ?? 'General';
    final key      = '${subjName}_${_taskNote.isEmpty ? 'general' : _taskNote}';
    final today    = DateTime.now().toIso8601String().substring(0, 10);
    final userRef  = FirebaseFirestore.instance.collection('users').doc(uid);
    final sessRef  = userRef.collection('sessions');

    // Upsert session
    final existing = await sessRef
        .where('key', isEqualTo: key)
        .where('date', isEqualTo: today)
        .limit(1).get();

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference
          .update({'minutes': FieldValue.increment(mins)});
    } else {
      await sessRef.add({
        'key':          key,
        'subject':      subjName,
        'subjectColor': _curSubj?['color'] ?? '#5B8DEE',
        'task':         _taskNote,
        'minutes':      mins,
        'date':         today,
        'done':         false,
        'createdAt':    FieldValue.serverTimestamp(),
      });
    }

    // ── FIX: Streak logic ──
    final userDoc  = await userRef.get();
    final userData = userDoc.data() ?? {};
    final lastDate = (userData['lastStudyDate'] as String?) ?? '';
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String().substring(0, 10);

    int newStreak = (userData['streak'] ?? 0) as int;
    if (lastDate == today) {
      // Already counted today — don't change streak
    } else if (lastDate == yesterday) {
      // Consecutive day — increment
      newStreak++;
    } else {
      // Gap of 2+ days — reset to 1
      newStreak = 1;
    }

    // ── Update user totals ──
    await userRef.update({
      'totalMinutes':  FieldValue.increment(mins),
      'totalSessions': FieldValue.increment(1),
      'xp':            FieldValue.increment(mins * 2),
      'weeklyXp':      FieldValue.increment(mins * 2), // FIX: powers weekly leaderboard
      'streak':        newStreak,
      'lastStudyDate': today,
    });

    if (mounted) setState(() {
      _todayMins += mins;
      _weekMins  += mins;
      _streak     = newStreak;
    });
  }

  // ─────────────────────────────────────────────
  //  TASKS
  // ─────────────────────────────────────────────
  Future<void> _addTask(String subject, String desc, int targetMins) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('tasks').add({
      'subject':     subject,
      'description': desc,
      'targetMins':  targetMins,
      'done':        false,
      'createdAt':   FieldValue.serverTimestamp(),
    });
    _loadTasks();
  }

  Future<void> _toggleTask(_Task t) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('tasks').doc(t.id)
        .update({'done': !t.done});
    _loadTasks();
  }

  Future<void> _deleteTask(_Task t) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('tasks').doc(t.id)
        .delete();
    _loadTasks();
  }

  // ─────────────────────────────────────────────
  //  BOTTOM SHEETS
  // ─────────────────────────────────────────────
  void _showSubjectPicker() {
    final c = AppColors.of(context);
    Map<String, dynamic>? tempSubj = _curSubj;
    final taskCtrl   = TextEditingController(text: _taskNote);
    final customCtrl = TextEditingController();
    bool showCustom  = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          // FIX: keyboard padding
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(c.radius + 4))),
            // FIX: constrain height + scroll so keyboard doesn't overflow
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2)))),
              // FIX: Flexible + SingleChildScrollView prevents 98px overflow
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What are you studying? 📚',
                        style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: c.text,
                          fontFamily: c.fontFamily)),
                      const SizedBox(height: 20),

                      Text('SUBJECT', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: c.muted, letterSpacing: 1.2)),
                      const SizedBox(height: 10),

                      if (_subjects.isNotEmpty)
                        Wrap(spacing: 8, runSpacing: 8,
                          children: _subjects.map((s) {
                            final sel = tempSubj?['name'] == s['name'];
                            Color col;
                            try { col = Color(int.parse(
                                (s['color'] as String)
                                    .replaceFirst('#', '0xFF'))); }
                            catch (_) { col = c.accent; }
                            return GestureDetector(
                              onTap: () => setSheet(() {
                                tempSubj   = s;
                                showCustom = false;
                                customCtrl.clear();
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? col
                                      : col.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(
                                      c.radiusSm + 4),
                                  border: Border.all(
                                    color: col,
                                    width: sel ? 0 : 1)),
                                child: Text(s['name'] as String,
                                  style: TextStyle(
                                    color: sel ? Colors.white : col,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    fontFamily: c.fontFamily))));
                          }).toList()),

                      const SizedBox(height: 10),

                      if (showCustom) ...[
                        TextField(
                          controller: customCtrl,
                          autofocus: true,
                          style: TextStyle(fontSize: 14, color: c.text),
                          decoration: _inputDeco(
                              'e.g. Art History, Tamil...', c)),
                        const SizedBox(height: 12),
                      ],

                      Row(children: [
                        Text('TASK ', style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: c.muted, letterSpacing: 1.2)),
                        Text('(optional)', style: TextStyle(
                          fontSize: 10, color: c.muted)),
                      ]),
                      const SizedBox(height: 8),
                      TextField(
                        controller: taskCtrl,
                        style: TextStyle(fontSize: 14, color: c.text),
                        decoration: _inputDeco(
                            'e.g. Plant form pg 35', c)),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final custom = customCtrl.text.trim();
                            if (custom.isNotEmpty) {
                              final colors = ['#5B8DEE','#8B6CF6',
                                '#34C77B','#F07832','#F0A500','#E84040'];
                              tempSubj = {
                                'name':  custom,
                                'color': colors[DateTime.now()
                                    .millisecond % colors.length],
                              };
                            }
                            setState(() {
                              if (tempSubj != null) _curSubj = tempSubj;
                              _taskNote       = taskCtrl.text.trim();
                              _secsAtLastSave = _remSecs;
                            });
                            Navigator.pop(ctx);
                            _startCountdown();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    c.radius)),
                            elevation: 0),
                          child: Text('Start Session ⚡',
                            style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w800,
                              fontFamily: c.fontFamily)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => setSheet(() {
                            showCustom = !showCustom;
                            if (showCustom) tempSubj = null;
                          }),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.accent,
                            side: BorderSide(color: c.accent),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    c.radius))),
                          child: Text('+ Use a different subject',
                            style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: c.fontFamily)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _taskNote       = '';
                              _secsAtLastSave = _remSecs;
                            });
                            Navigator.pop(ctx);
                            _startCountdown();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: c.muted,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14)),
                          child: const Text('Skip — just start',
                            style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showTasksSheet() {
    final c           = AppColors.of(context);
    final descCtrl    = TextEditingController();
    final subjCtrl    = TextEditingController();
    int   targetMins  = 30;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(c.radius + 4))),
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.88),
            child: Column(children: [
              Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('📋 Task Planner', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900,
                      color: c.text, fontFamily: c.fontFamily)),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Done', style: TextStyle(
                        color: c.accent,
                        fontWeight: FontWeight.w800))),
                  ])),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Add task form
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.surface2,
                          borderRadius: BorderRadius.circular(
                              c.radiusSm),
                          border: Border.all(color: c.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ADD TASK', style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              color: c.muted, letterSpacing: 1.1)),
                            const SizedBox(height: 10),

                            // Quick subject chips
                            if (_subjects.isNotEmpty) ...[
                              Wrap(spacing: 6, runSpacing: 6,
                                children: _subjects.map((s) {
                                  Color col;
                                  try { col = Color(int.parse(
                                      (s['color'] as String)
                                          .replaceFirst('#', '0xFF'))); }
                                  catch (_) { col = c.accent; }
                                  final sel =
                                      subjCtrl.text == s['name'];
                                  return GestureDetector(
                                    onTap: () => setSheet(() =>
                                        subjCtrl.text =
                                            s['name'] as String),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? col
                                            : col.withOpacity(0.1),
                                        borderRadius:
                                        BorderRadius.circular(
                                            c.radiusSm + 2),
                                        border: Border.all(
                                            color: col,
                                            width: sel ? 0 : 1)),
                                      child: Text(
                                          s['name'] as String,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: sel
                                                ? Colors.white
                                                : col))));
                                }).toList()),
                              const SizedBox(height: 10),
                            ],

                            TextField(
                              controller: subjCtrl,
                              style: TextStyle(
                                  fontSize: 13, color: c.text),
                              decoration: _inputDeco('Subject', c)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: descCtrl,
                              style: TextStyle(
                                  fontSize: 13, color: c.text),
                              decoration: _inputDeco(
                                  'Task description', c)),
                            const SizedBox(height: 10),

                            Text('TARGET TIME', style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w800,
                              color: c.muted, letterSpacing: 1.1)),
                            const SizedBox(height: 6),
                            Wrap(spacing: 6, runSpacing: 6,
                              children: [30, 60, 90, 120, 180].map((m) {
                                final sel = targetMins == m;
                                return GestureDetector(
                                  onTap: () =>
                                      setSheet(() => targetMins = m),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? c.accent
                                          : c.surface,
                                      borderRadius:
                                      BorderRadius.circular(
                                          c.radiusSm),
                                      border: Border.all(
                                        color: sel
                                            ? c.accent
                                            : c.border)),
                                    child: Text(
                                      m < 60
                                          ? '${m}m'
                                          : '${m ~/ 60}h',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: sel
                                            ? Colors.white
                                            : c.muted))));
                              }).toList()),
                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (descCtrl.text.trim().isEmpty) return;
                                  _addTask(
                                    subjCtrl.text.trim().isEmpty
                                        ? 'General'
                                        : subjCtrl.text.trim(),
                                    descCtrl.text.trim(),
                                    targetMins,
                                  );
                                  descCtrl.clear();
                                  setSheet(() {});
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          c.radiusSm)),
                                  elevation: 0),
                                child: Text('Add Task ✓',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: c.fontFamily)),
                              ),
                            ),
                          ])),
                      const SizedBox(height: 20),

                      if (_tasks.isEmpty)
                        Center(child: Text(
                          'No tasks yet. Add one above!',
                          style: TextStyle(
                              fontSize: 13, color: c.muted)))
                      else ...[
                        if (_tasks.any((t) => !t.done)) ...[
                          Text('PENDING', style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: c.muted, letterSpacing: 1.1)),
                          const SizedBox(height: 8),
                          ..._tasks.where((t) => !t.done).map(
                              (t) => _taskTile(t, c, setSheet)),
                        ],
                        if (_tasks.any((t) => t.done)) ...[
                          const SizedBox(height: 14),
                          Text('COMPLETED ✅', style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: c.green, letterSpacing: 1.1)),
                          const SizedBox(height: 8),
                          ..._tasks.where((t) => t.done).map(
                              (t) => _taskTile(t, c, setSheet)),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showSoundPicker() {
    final c = AppColors.of(context);
    final sounds = [
      {'id': 'bell',  'emoji': '🔔', 'label': 'Bell'},
      {'id': 'chime', 'emoji': '🎵', 'label': 'Chime'},
      {'id': 'alarm', 'emoji': '⏰', 'label': 'Alarm'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(c.radius + 4))),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2)))),
            Text('Session Complete Sound 🔔', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900,
              color: c.text, fontFamily: c.fontFamily)),
            const SizedBox(height: 4),
            Text('Tap to preview', style: TextStyle(
              fontSize: 10, color: c.muted)),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.4),
              child: SingleChildScrollView(
                child: Column(children: sounds.map((s) {
              final sel = _soundChoice == s['id'];
              return GestureDetector(
                onTap: () async {
                  setSheet(() => _soundChoice = s['id']!);
                  setState(() => _soundChoice = s['id']!);
                  try {
                    await _audioPlayer.play(
                        AssetSource('sounds/${s['id']}.mp3'));
                  } catch (_) {}
                  final uid =
                      FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .update({'soundChoice': s['id']});
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel
                        ? c.accent.withOpacity(0.1)
                        : c.surface2,
                    borderRadius: BorderRadius.circular(c.radiusSm),
                    border: Border.all(
                      color: sel ? c.accent : c.border,
                      width: sel ? 2 : 1)),
                  child: Row(children: [
                    Text(s['emoji']!,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 14),
                    Text(s['label']!, style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: sel ? c.accent : c.text,
                      fontFamily: c.fontFamily)),
                    const Spacer(),
                    if (sel)
                      Icon(Icons.check_circle,
                          color: c.accent, size: 22),
                  ])));
            }).toList()))),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ]),
        ),
      ),
    );
  }

  void _showCompleteDialog() {
    final c = AppColors.of(context);
    if (_onBreak) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(c.radius)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('💪', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('BREAK OVER', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900,
              color: c.green, fontFamily: c.fontFamily)),
            const SizedBox(height: 8),
            Text('Every champion needs recovery.\nNow get back to work.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.muted)),
          ]),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(c.radiusSm))),
                child: Text('BACK TO GRIND ⚡', style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontFamily: c.fontFamily)),
              ),
            ),
          ],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(c.radius)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🔥', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('SESSION COMPLETE', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900,
            color: c.text, fontFamily: c.fontFamily)),
          const SizedBox(height: 8),
          Text('You locked in. That\'s the whole game.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.muted)),
          const SizedBox(height: 8),
          FittedBox(child: Text('+${_modeMinutes * 2} XP', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w900,
            color: c.gold, fontFamily: c.fontFamily))),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(c.radiusSm))),
              child: Text('NEXT ROUND', style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: c.fontFamily)),
            ),
          ),
        ],
      ),
    );
  }

  void _showBreakStartDialog() {
    final c = AppColors.of(context);
    final messages = [
      'Taking a break? Bold move.\nYour competitors aren\'t.',
      'Fine. Rest. But make it quick.\nThe leaderboard waits for no one.',
      'Even the best need recovery.\nDon\'t make it a habit though.',
      'Break time. Your brain says thanks.\nYour rank says hurry up.',
      'Resting is part of the grind.\nJust don\'t forget to come back.',
    ];
    final msg = messages[DateTime.now().second % messages.length];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(c.radius)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('😮‍💨', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('BREAK TIME', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900,
            color: c.green, fontFamily: c.fontFamily)),
          const SizedBox(height: 8),
          Text(msg,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.muted)),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _secsAtLastSave = _remSecs);
                _startCountdown();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: c.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(c.radiusSm))),
              child: Text('START BREAK', style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: c.fontFamily)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── TOP ROW ──
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.surface2,
                      borderRadius: BorderRadius.circular(c.radiusSm),
                      border: Border.all(color: c.border)),
                    child: Row(children: [
                      const Text('🏆', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Flexible(child: Text(
                        _rank > 0
                            ? 'RANK #$_rank · THE GRINDER'
                            : 'UNRANKED · START GRINDING',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: c.accent, letterSpacing: 0.5,
                          fontFamily: c.fontFamily))),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                // Sound picker
                GestureDetector(
                  onTap: _showSoundPicker,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(c.radiusSm),
                      border: Border.all(color: c.border)),
                    child: const Center(child: Text('🔔',
                        style: TextStyle(fontSize: 18))),
                  ),
                ),
                const SizedBox(width: 8),
                // Theme picker
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (_) => GrindThemeProvider(
                      colors: c,
                      theme: GrindThemeProvider.maybeOf(context)?.theme
                          ?? GrindTheme.defaultBlue,
                      onThemeChanged: GrindThemeProvider.maybeOf(context)
                          ?.onThemeChanged ?? (_) {},
                      child: const ThemePickerSheet(),
                    ),
                  ),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(c.radiusSm),
                      border: Border.all(color: c.border)),
                    child: const Center(child: Text('🎨',
                        style: TextStyle(fontSize: 18))),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // ── TICKER ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  key: ValueKey(_tickerIndex),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(c.radiusSm),
                    border: Border.all(color: c.border)),
                  child: Text(_tickers[_tickerIndex],
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: c.muted,
                      fontWeight: FontWeight.w600,
                      fontFamily: c.fontBody)),
                ),
              ),
              const SizedBox(height: 16),

              // ── MODE PILLS ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _modePill('25 MIN', 25, 'POMODORO', c),
                  const SizedBox(width: 8),
                  _modePill('50 MIN', 50, 'DEEP WORK', c),
                  const SizedBox(width: 8),
                  _modePill('15 MIN', 15, 'SPRINT', c),
                  const SizedBox(width: 8),
                  _modePill('BREAK',   5, 'BREAK',    c),
                ]),
              ),
              const SizedBox(height: 28),

              // ── TIMER RING ──
              Center(
                child: SizedBox(
                  width: 220, height: 220,
                  child: Stack(alignment: Alignment.center, children: [
                    CustomPaint(
                      size: const Size(220, 220),
                      painter: _RingPainter(
                        _progress,
                        _onBreak ? c.green : c.accent,
                        c.surface2)),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_formatTime(), style: TextStyle(
                        fontSize: 48, fontWeight: FontWeight.w900,
                        color: c.text, fontFamily: c.fontFamily)),
                      const SizedBox(height: 4),
                      Text(
                        _running
                          ? '$_modeName · RUNNING'
                          : _remSecs == _totalSecs
                            ? '$_modeName · READY'
                            : '$_modeName · PAUSED',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: c.muted, letterSpacing: 1.2,
                          fontFamily: c.fontFamily)),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 20),

              // ── SUBJECT + TASK LABEL ──
              Center(
                child: GestureDetector(
                  onTap: _running ? null : _showSubjectPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _curSubj != null ? (() {
                        try {
                          return Color(int.parse(
                              (_curSubj!['color'] as String)
                                  .replaceFirst('#', '0xFF')))
                              .withOpacity(0.12);
                        } catch (_) { return c.surface2; }
                      })() : c.surface2,
                      borderRadius: BorderRadius.circular(c.radiusSm + 4),
                      border: Border.all(color: c.border)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_curSubj != null ? '📚' : '⚡',
                          style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Flexible(child: Text(
                        (_curSubj?['name'] as String?) ?? 'Tap to pick subject',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                          fontFamily: c.fontFamily))),
                      if (_taskNote.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('·', style: TextStyle(color: c.muted)),
                        const SizedBox(width: 6),
                        Flexible(child: Text(_taskNote,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12,
                            color: c.muted,
                            fontWeight: FontWeight.w600))),
                      ],
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── CONTROLS ──
              // FIX: LayoutBuilder prevents RESUME button right overflow
              LayoutBuilder(builder: (ctx, constraints) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ctrlBtn('Reset', c.surface2, c.muted,
                        _resetTimer, c),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.44),
                      child: _ctrlBtn(
                        _running
                          ? 'PAUSE'
                          : _remSecs < _totalSecs
                            ? 'RESUME'
                            : 'START',
                        _running ? c.orange : c.accent,
                        Colors.white,
                        _handleStart, c, big: true)),
                    const SizedBox(width: 8),
                    _ctrlBtn('Quit', c.surface2, c.red,
                        _quitEarly, c),
                  ],
                );
              }),
              const SizedBox(height: 16),

              // ── TASK PLANNER BUTTON ──
              GestureDetector(
                onTap: _showTasksSheet,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(c.radiusSm),
                    border: Border.all(color: c.border)),
                  child: Row(children: [
                    const Text('📋', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Task Planner', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: c.text, fontFamily: c.fontFamily)),
                        Text(
                          _tasks.isEmpty
                            ? 'No tasks yet — tap to plan'
                            : '${_tasks.where((t) => !t.done).length} pending · ${_tasks.where((t) => t.done).length} done',
                          style: TextStyle(
                              fontSize: 11, color: c.muted)),
                      ])),
                    Icon(Icons.chevron_right, color: c.muted, size: 20),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // ── STATS GRID ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(c.radius),
                  border: Border.all(color: c.border)),
                child: Row(children: [
                  _statCell('⏱️', _fmtMins(_todayMins), 'Today',    c),
                  _statDivider(c),
                  _statCell('📅', _fmtMins(_weekMins),  'Week',     c),
                  _statDivider(c),
                  _statCell('🔥', '$_streak',            'Streak',   c),
                  _statDivider(c),
                  _statCell('🍅', '$_pomCount',          'Sessions', c),
                ]),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
          ),
          const ThemeDecorationLayer(screen: 'focus'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  HELPER WIDGETS
  // ─────────────────────────────────────────────

  Widget _taskTile(_Task t, AppColors c, StateSetter setSheet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.done ? c.green.withOpacity(0.06) : c.surface2,
        borderRadius: BorderRadius.circular(c.radiusSm),
        border: Border.all(
          color: t.done ? c.green.withOpacity(0.3) : c.border)),
      child: Row(children: [
        GestureDetector(
          onTap: () { _toggleTask(t); setSheet(() {}); },
          child: Container(
            width: 22, height: 22,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: t.done ? c.green : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: t.done ? c.green : c.muted, width: 2)),
            child: t.done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null)),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (t.subject.isNotEmpty)
              Text(t.subject, style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: c.accent)),
            Text(t.description, style: TextStyle(
              fontSize: 12,
              color: t.done ? c.muted : c.text,
              decoration: t.done ? TextDecoration.lineThrough : null,
              fontWeight: FontWeight.w600)),
            if (t.targetMins > 0)
              Text(
                '🎯 ${t.targetMins < 60 ? '${t.targetMins}m' : '${t.targetMins ~/ 60}h'} target',
                style: TextStyle(fontSize: 9, color: c.muted)),
          ])),
        GestureDetector(
          onTap: () { _deleteTask(t); setSheet(() {}); },
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(Icons.close, size: 16, color: c.muted))),
      ]),
    );
  }

  InputDecoration _inputDeco(String hint, AppColors c) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.muted, fontSize: 13),
      filled: true, fillColor: c.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(c.radiusSm),
        borderSide: BorderSide(color: c.border)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(c.radiusSm),
        borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(c.radiusSm),
        borderSide: BorderSide(color: c.accent, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12));

  Widget _modePill(String label, int mins, String name, AppColors c) {
    final active = _modeMinutes == mins && _modeName == name;
    return GestureDetector(
      onTap: () => _setMode(mins, name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(c.radiusSm + 10),
          border: Border.all(
            color: active ? c.accent : c.border,
            width: active ? 0 : 1)),
        child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800,
          color: active ? Colors.white : c.muted,
          letterSpacing: 0.5, fontFamily: c.fontFamily)),
      ),
    );
  }

  Widget _ctrlBtn(String label, Color bg, Color fg,
      VoidCallback onTap, AppColors c, {bool big = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: big ? 24 : 16,
          vertical:   big ? 14 : 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(c.radius),
          boxShadow: big ? [BoxShadow(
              color: bg.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4))] : null),
        child: Text(label, style: TextStyle(
          fontSize: big ? 14 : 12,
          fontWeight: FontWeight.w800,
          color: fg, fontFamily: c.fontFamily)),
      ),
    );
  }

  Widget _statCell(String icon, String val, String label,
      AppColors c) =>
    Expanded(child: Column(children: [
      Text(icon, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(fontSize: 15,
        fontWeight: FontWeight.w900, color: c.text,
        fontFamily: c.fontFamily)),
      Text(label, style: TextStyle(fontSize: 10,
        color: c.muted, fontWeight: FontWeight.w600)),
    ]));

  Widget _statDivider(AppColors c) => Container(
    width: 1, height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: c.border);

  String _formatTime() {
    final m = (_remSecs ~/ 60).toString().padLeft(2, '0');
    final s = (_remSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtMins(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60; final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  double get _progress => 1 - (_remSecs / _totalSecs);
}

// ── Task data class ──
class _Task {
  final String id, subject, description;
  final int    targetMins;
  final bool   done;
  const _Task({
    required this.id,          required this.subject,
    required this.description, required this.targetMins,
    required this.done,
  });
}

// ── Ring painter ──
class _RingPainter extends CustomPainter {
  final double progress;
  final Color  color;
  final Color  bgColor;
  _RingPainter(this.progress, this.color, this.bgColor);

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final radius = size.width  / 2 - 12;

    canvas.drawCircle(Offset(cx, cy), radius, Paint()
      ..color       = bgColor
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 12);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        -pi / 2, 2 * pi * progress, false,
        Paint()
          ..color       = color.withOpacity(0.3)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 20
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        -pi / 2, 2 * pi * progress, false,
        Paint()
          ..color       = color
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap   = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}