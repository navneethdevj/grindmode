import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' show max;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/badge_service.dart';
import '../widgets/theme_decoration_layer.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _loading      = true;
  bool _roastLoading = false;
  String _range = 'day'; // day | week | month

  int _todayMins    = 0;
  int _sessionCount = 0;
  int _streak       = 0;
  int _rank         = 0;
  int _todayXp      = 0;
  int _totalMins      = 0;
  int _dailyGoalMins  = 180;

  final Map<String, int>      _dailyMins = {};
  final Map<String, _SubjData> _subjMap  = {};
  final List<_Session> _sessions = [];
  final List<_Session> _done     = [];

  List<GrindBadge> _badges = [];

  String _roastText = '';
  String _motivText = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }

    final today    = DateTime.now().toIso8601String().substring(0, 10);
    final monthAgo = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String().substring(0, 10);

    final userDoc  = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final streak        = (userData['streak']           ?? 0)   as int;
    final totalMins     = (userData['totalMinutes']      ?? 0)   as int;
    final dailyGoalMins = (userData['dailyGoalMinutes']  ?? 180) as int;

    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('sessions')
        .where('date', isGreaterThanOrEqualTo: monthAgo)
        .orderBy('date', descending: true)
        .get();

    int todayMins = 0, todayXp = 0, sessionCount = 0;
    final dailyMins        = <String, int>{};
    final subjMap          = <String, _SubjData>{};
    final sessions         = <_Session>[];
    final done             = <_Session>[];
    final subjectTotalMins = <String, int>{};
    bool studiedSat = false, studiedSun = false;

    for (final doc in snap.docs) {
      final d      = doc.data();
      final mins   = (d['minutes']      as int?)    ?? 0;
      final date   = (d['date']         as String?) ?? '';
      final subj   = (d['subject']      as String?) ?? 'General';
      final color  = (d['subjectColor'] as String?) ?? '#5B8DEE';
      final task   = (d['task']         as String?) ?? '';
      final isDone = (d['done']         as bool?)   ?? false;

      dailyMins[date] = (dailyMins[date] ?? 0) + mins;

      subjMap[subj] ??= _SubjData(color: color, mins: 0);
      subjMap[subj]!.mins += mins;
      subjectTotalMins[subj] = (subjectTotalMins[subj] ?? 0) + mins;

      final docDate = DateTime.tryParse(date);
      if (docDate != null) {
        if (docDate.weekday == 6) studiedSat = true;
        if (docDate.weekday == 7) studiedSun = true;
      }

      if (date == today) {
        todayMins    += mins;
        todayXp      += mins * 2;
        sessionCount++;
      }

      final s = _Session(id: doc.id, subject: subj, color: color,
          task: task, mins: mins, date: date, done: isDone);
      if (isDone) done.add(s); else sessions.add(s);
    }

    // Rank — FIX: filter anonymous/nameless users
    final lb = await FirebaseFirestore.instance
        .collection('users').orderBy('xp', descending: true)
        .limit(100).get();
    final rank = lb.docs.indexWhere((d) => d.id == uid) + 1;

    final totalSessionCount =
        (userData['totalSessions'] ?? sessionCount) as int;
    final badges = await BadgeService.checkAndAward(
      totalMins:        totalMins,
      streak:           streak,
      sessionCount:     totalSessionCount,
      subjectMins:      subjectTotalMins,
      rank:             rank,
      currentHour:      DateTime.now().hour,
      studiedOnWeekend: studiedSat && studiedSun,
    );

    if (mounted) setState(() {
      _todayMins    = todayMins;
      _sessionCount = sessionCount;
      _streak       = streak;
      _rank         = rank;
      _todayXp      = todayXp;
      _totalMins      = totalMins;
      _dailyGoalMins  = dailyGoalMins;
      // FIX #9: ensure weeklyXp field exists for older users
      if (!userData.containsKey('weeklyXp')) {
        FirebaseFirestore.instance
            .collection('users').doc(uid)
            .update({'weeklyXp': 0});
      }
      _dailyMins..clear()..addAll(dailyMins);
      _subjMap..clear()..addAll(subjMap);
      _sessions..clear()..addAll(sessions);
      _done..clear()..addAll(done);
      _badges  = badges;
      _loading = false;
    });

    _loadRoastAndMotivation();
  }

  // ─────────────────────────────────────────────
  //  AI ROAST + MOTIVATION
  // ─────────────────────────────────────────────

  // Cache key: roast is cached per-user per-day to avoid redundant API calls.
  Future<void> _loadRoastAndMotivation() async {
    setState(() { _roastLoading = true; });

    // Check daily cache first
    final uid   = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    final cacheKey     = 'roast_cache_${uid}_$today';
    final cachedRoast  = prefs.getString('${cacheKey}_roast');
    final cachedMotiv  = prefs.getString('${cacheKey}_motiv');

    if (cachedRoast != null && cachedRoast.isNotEmpty) {
      if (mounted) setState(() {
        _roastText    = cachedRoast;
        _motivText    = cachedMotiv ?? '';
        _roastLoading = false;
      });
      return;
    }

    setState(() { _roastText = ''; _motivText = ''; });

    final unlockedCount = _badges.where((b) => b.unlocked).length;
    final topSubject    = _subjMap.isEmpty ? 'nothing'
        : _subjMap.entries
            .reduce((a, b) => a.value.mins > b.value.mins ? a : b).key;
    final totalHours = (_totalMins / 60).toStringAsFixed(1);

    final prompt = '''
You are a brutally sarcastic but secretly motivating AI study coach for students using an app called GrindMode.

User stats:
- Total study time: $totalHours hours
- Today: ${(_todayMins / 60).toStringAsFixed(1)} hours
- Streak: $_streak days
- Global rank: ${_rank > 0 ? '#$_rank' : 'unranked'}
- Sessions today: $_sessionCount
- Top subject: $topSubject
- Badges unlocked: $unlockedCount / ${BadgeService.allBadges.length}

Write TWO sections separated by the exact delimiter: ===MOTIV===

SECTION 1 — ROAST (exactly 4 lines):
- Each line starts with one emoji
- Be brutal, funny, specific to actual stats
- Reference relatable student struggles and exam culture
- Each line ends with a hidden sting

===MOTIV===

SECTION 2 — BUT ACTUALLY (exactly 3 lines):
- Each line starts with one emoji
- Genuine encouragement and motivation based on actual stats
- Acknowledge real effort, point to next milestone
- Warm but still has edge

Output ONLY the lines. No headers, no preamble, no extra text.
''';

    try {
      final response = await _callClaude(prompt);
      final parts    = response.split('===MOTIV===');
      final roast    = parts.isNotEmpty ? parts[0].trim() : '';
      final motiv    = parts.length > 1 ? parts[1].trim() : '';

      // Save to daily cache
      await prefs.setString('${cacheKey}_roast', roast);
      await prefs.setString('${cacheKey}_motiv', motiv);

      if (mounted) setState(() {
        _roastText    = roast;
        _motivText    = motiv;
        _roastLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _roastText = 'The roast machine is taking a break. Try again later.';
        _motivText = '';
        _roastLoading = false;
      });
    }
  }

  Future<String> _callClaude(String prompt) async {
    const apiKey = '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';
    final res = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'arcee-ai/trinity-large-preview:free',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 400,
        'temperature': 1.0,
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('${res.statusCode}: ${res.body}');
  }

  // FIX: toggleDone works in BOTH directions — session log ↔ completed
  Future<void> _toggleDone(_Session s) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('sessions').doc(s.id)
        .update({'done': !s.done});
    _load();
  }

  // ─────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────
  String _fmtMins(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60; final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _grade() {
    if (_dailyGoalMins == 0) return 'F';
    final pct = _todayMins / _dailyGoalMins;
    if (pct >= 1.0)  return 'S';
    if (pct >= 0.80) return 'A';
    if (pct >= 0.60) return 'B+';
    if (pct >= 0.40) return 'B';
    if (pct >= 0.20) return 'C';
    return 'F';
  }

  String _gradeTitle() {
    switch (_grade()) {
      case 'S':  return 'GOAL CRUSHED 🔥';
      case 'A':  return 'ALMOST THERE';
      case 'B+': return 'MORE THAN HALFWAY';
      case 'B':  return 'GETTING STARTED';
      case 'C':  return 'BARELY WARMING UP';
      default:   return 'START GRINDING';
    }
  }

  String _gradeQuote() {
    final goalStr = _fmtMins(_dailyGoalMins);
    final doneStr = _fmtMins(_todayMins);
    final pctStr  = (_dailyGoalMins > 0
        ? (_todayMins / _dailyGoalMins * 100) : 0)
        .toStringAsFixed(0);
    switch (_grade()) {
      case 'S':  return '"Goal: $goalStr. Done: $doneStr. You actually did it."';
      case 'A':  return '"$pctStr% there. So close. Don\'t stop now."';
      case 'B+': return '"Over halfway to $goalStr. Keep pushing."';
      case 'B':  return '"A start. $goalStr is the goal. Keep going."';
      case 'C':  return '"You showed up. Goal: $goalStr. Now do more."';
      default:   return '"Goal: $goalStr. Done: $doneStr. Do the math."';
    }
  }

  Color _gradeColor(AppColors c) {
    switch (_grade()) {
      case 'S':            return c.gold;
      case 'A':            return c.green;
      case 'B+': case 'B': return c.accent;
      case 'C':            return c.orange;
      default:             return c.red;
    }
  }

  String _todayDateStr() {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    const days   = ['Monday','Tuesday','Wednesday',
                    'Thursday','Friday','Saturday','Sunday'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  List<_DayPoint> _buildChartPoints() {
    final now = DateTime.now();
    if (_range == 'day') {
      final today = now.toIso8601String().substring(0, 10);
      return [_DayPoint(label: 'Today', mins: _dailyMins[today] ?? 0)];
    }
    final days   = _range == 'month' ? 30 : 7;
    final points = <_DayPoint>[];
    for (int i = days - 1; i >= 0; i--) {
      final d    = now.subtract(Duration(days: i));
      final key  = d.toIso8601String().substring(0, 10);
      final mins = _dailyMins[key] ?? 0;
      String label;
      if (_range == 'week') {
        const names = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
        label = names[d.weekday - 1];
      } else {
        label = '${d.day}';
      }
      points.add(_DayPoint(label: label, mins: mins));
    }
    return points;
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
            child: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : RefreshIndicator(
              color: c.accent,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📊 Daily Report', style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900,
                      color: c.text, fontFamily: c.fontFamily)),
                    const SizedBox(height: 2),
                    Text(_todayDateStr(),
                        style: TextStyle(fontSize: 12, color: c.muted)),
                    const SizedBox(height: 16),

                    _gradeCard(c),
                    const SizedBox(height: 12),
                    _statsGrid(c),
                    const SizedBox(height: 12),
                    _chartsSection(c),
                    const SizedBox(height: 12),

                    if (_subjMap.isNotEmpty) ...[
                      _sectionCard('📚 Subject Breakdown', c,
                        child: Column(children: _subjMap.entries
                          .map((e) => _subjBar(e.key, e.value, c))
                          .toList())),
                      const SizedBox(height: 12),
                    ],

                    _badgesSection(c),
                    const SizedBox(height: 12),

                    // Session log
                    _sectionCard('⏱️ Session Log', c,
                      trailing: Text('${_sessions.length} in progress',
                        style: TextStyle(fontSize: 10, color: c.muted,
                            fontWeight: FontWeight.w600)),
                      child: _sessions.isEmpty
                        ? Text('No sessions yet. Start studying!',
                            style: TextStyle(fontSize: 12, color: c.muted))
                        : Column(children: [
                            Text('Tap ✓ to mark done.',
                              style: TextStyle(fontSize: 10, color: c.muted)),
                            const SizedBox(height: 10),
                            ..._sessions.map((s) => _sessionTile(s, c)),
                          ])),
                    const SizedBox(height: 12),

                    // FIX: completed sessions now show uncheck button too
                    if (_done.isNotEmpty) ...[
                      _sectionCard('✅ Completed', c,
                        trailing: Text('${_done.length} done 🎉',
                          style: TextStyle(fontSize: 10, color: c.green,
                              fontWeight: FontWeight.w700)),
                        child: Column(children: [
                          Text('Tap ✓ to move back to in-progress.',
                            style: TextStyle(fontSize: 10, color: c.muted)),
                          const SizedBox(height: 10),
                          ..._done.map((s) => _sessionTile(s, c)),
                        ])),
                      const SizedBox(height: 12),
                    ],

                    _roastCard(c),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          const ThemeDecorationLayer(screen: 'report'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  CHARTS
  // ─────────────────────────────────────────────
  Widget _chartsSection(AppColors c) {
    final points  = _buildChartPoints();
    final maxMins = points.isEmpty
        ? 60.0
        : points.map((p) => p.mins).reduce(max)
            .toDouble().clamp(1.0, 9999.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(c.radius),
        border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('📈 Study Time', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: c.text, fontFamily: c.fontFamily)),
              Flexible(child: _rangePills(c)),
            ]),
          const SizedBox(height: 20),

          Text('TREND', style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800,
            color: c.muted, letterSpacing: 1.1)),
          const SizedBox(height: 8),

          ClipRect(child: SizedBox(
            height: 130,
            child: _range == 'day'
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_fmtMins(_todayMins), style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900,
                      color: c.accent, fontFamily: c.fontFamily)),
                    Text('studied today',
                      style: TextStyle(fontSize: 12, color: c.muted)),
                  ]))
              : LineChart(LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxMins / 4,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: c.border, strokeWidth: 1)),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,  // FIX: was 36, extra space prevents overflow
                        interval: maxMins / 4,
                        getTitlesWidget: (val, _) => Text(
                          _fmtMins(val.toInt()),
                          style: TextStyle(fontSize: 8, color: c.muted)),
                      )),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,  // FIX: explicit reserved height
                        interval: _range == 'month' ? 5 : 1,
                        getTitlesWidget: (val, _) {
                          final i = val.toInt();
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(points[i].label,
                              style: TextStyle(
                                  fontSize: 8, color: c.muted)));
                        },
                      )),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (points.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxMins * 1.2,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(points.length, (i) =>
                          FlSpot(i.toDouble(),
                              points[i].mins.toDouble())),
                      isCurved: true,
                      color: c.accent,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, __, ___, ____) =>
                            FlDotCirclePainter(
                              radius: 3,
                              color: c.accent,
                              strokeWidth: 0)),
                      belowBarData: BarAreaData(
                        show: true,
                        color: c.accent.withOpacity(0.12)),
                    ),
                  ],
                )),
          )),

          const SizedBox(height: 20),

          if (_subjMap.isNotEmpty) ...[
            Text('BY SUBJECT', style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: c.muted, letterSpacing: 1.1)),
            const SizedBox(height: 8),
            ClipRect(child: SizedBox(
              height: 140,
              child: BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _subjMap.values
                    .map((v) => v.mins.toDouble())
                    .reduce(max) * 1.3,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => c.surface2,
                    getTooltipItem: (group, _, rod, __) {
                      final subj =
                          _subjMap.keys.elementAt(group.x);
                      return BarTooltipItem(
                        '$subj\n${_fmtMins(rod.toY.toInt())}',
                        TextStyle(fontSize: 10, color: c.text,
                            fontWeight: FontWeight.w700));
                    })),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20, // FIX: prevents right overflow
                      getTitlesWidget: (val, _) {
                        final i = val.toInt();
                        if (i < 0 || i >= _subjMap.length) {
                          return const SizedBox.shrink();
                        }
                        final name = _subjMap.keys.elementAt(i);
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            name.length > 5
                                ? '${name.substring(0, 4)}…'
                                : name,
                            style: TextStyle(
                                fontSize: 8, color: c.muted)));
                      })),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40, // FIX: consistent with line chart
                      getTitlesWidget: (val, _) => Text(
                        _fmtMins(val.toInt()),
                        style: TextStyle(
                            fontSize: 8, color: c.muted)))),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: c.border, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: _subjMap.entries.toList()
                    .asMap().entries.map((entry) {
                  final i    = entry.key;
                  final subj = entry.value;
                  Color col;
                  try { col = Color(int.parse(
                      subj.value.color.replaceFirst('#', '0xFF'))); }
                  catch (_) { col = c.accent; }
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: subj.value.mins.toDouble(),
                      color: col,
                      width: 18,
                      borderRadius: BorderRadius.only(
                        topLeft:  Radius.circular(c.radiusSm / 2),
                        topRight: Radius.circular(c.radiusSm / 2))),
                  ]);
                }).toList(),
              )))),

            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 6,
              children: _subjMap.entries.map((e) {
                Color col;
                try { col = Color(int.parse(
                    e.value.color.replaceFirst('#', '0xFF'))); }
                catch (_) { col = c.accent; }
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: col, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(e.key, style: TextStyle(fontSize: 10,
                    color: c.muted, fontWeight: FontWeight.w600)),
                ]);
              }).toList()),
          ],
        ]),
    );
  }

  // ─────────────────────────────────────────────
  //  WIDGETS
  // ─────────────────────────────────────────────

  Widget _gradeCard(AppColors c) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: c.surface,
      borderRadius: BorderRadius.circular(c.radius),
      border: Border.all(color: c.border)),
    child: Row(children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(
          color: _gradeColor(c).withOpacity(0.15),
          borderRadius: BorderRadius.circular(c.radiusSm)),
        child: Center(child: Text(_grade(), style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w900,
          color: _gradeColor(c), fontFamily: c.fontFamily)))),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_gradeTitle(), style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w800, color: c.text,
            fontFamily: c.fontFamily)),
          const SizedBox(height: 4),
          Text(_gradeQuote(), style: TextStyle(fontSize: 11,
            color: c.muted, fontStyle: FontStyle.italic)),
        ])),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('TODAY XP', style: TextStyle(fontSize: 9,
          color: c.muted, fontWeight: FontWeight.w800,
          letterSpacing: 0.8)),
        Text('+$_todayXp', style: TextStyle(fontSize: 16,
          fontWeight: FontWeight.w900, color: c.gold,
          fontFamily: c.fontFamily)),
      ]),
    ]),
  );

  Widget _statsGrid(AppColors c) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: c.surface,
      borderRadius: BorderRadius.circular(c.radius),
      border: Border.all(color: c.border)),
    child: Row(children: [
      _statCell('⏱️', _fmtMins(_todayMins), 'Focus Time', c),
      _vDivider(c),
      _statCell('🔁', '$_sessionCount', 'Sessions', c),
      _vDivider(c),
      _statCell('🔥', '${_streak}d', 'Streak', c),
      _vDivider(c),
      _statCell('🌍', _rank > 0 ? '#$_rank' : '–', 'Rank', c),
    ]),
  );

  Widget _subjBar(String name, _SubjData data, AppColors c) {
    final maxM = _subjMap.values.map((v) => v.mins)
        .reduce(max).clamp(1, 9999);
    Color col;
    try { col = Color(int.parse(
        data.color.replaceFirst('#', '0xFF'))); }
    catch (_) { col = c.accent; }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: c.text)),
              Text(_fmtMins(data.mins), style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: col)),
            ]),
          const SizedBox(height: 6),
          Stack(children: [
            Container(height: 8, decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(4))),
            FractionallySizedBox(
              widthFactor: (data.mins / maxM).clamp(0.0, 1.0),
              child: Container(height: 8, decoration: BoxDecoration(
                color: col,
                borderRadius: BorderRadius.circular(4)))),
          ]),
        ]),
    );
  }

  Widget _badgesSection(AppColors c) {
    final unlocked = _badges.where((b) => b.unlocked).toList();
    const categories = ['time','streak','sessions','mastery','special'];
    const categoryNames = {
      'time':     '⏱️ Study Time',
      'streak':   '🔥 Streaks',
      'sessions': '🍅 Sessions',
      'mastery':  '🎓 Mastery',
      'special':  '⭐ Special',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface,
        borderRadius: BorderRadius.circular(c.radius),
        border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🏅 Badges', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: c.text, fontFamily: c.fontFamily)),
              Text('${unlocked.length}/${_badges.length}',
                style: TextStyle(fontSize: 11, color: c.accent,
                    fontWeight: FontWeight.w800)),
            ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _badges.isEmpty
                  ? 0 : unlocked.length / _badges.length,
              backgroundColor: c.surface2,
              color: c.accent,
              minHeight: 6)),
          const SizedBox(height: 16),
          ...categories.map((cat) {
            final catBadges =
                _badges.where((b) => b.category == cat).toList();
            if (catBadges.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(categoryNames[cat] ?? cat, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: c.muted, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8,
                  children: catBadges.map<Widget>(
                      (b) => _badgeTile(b, c)).toList()),
                const SizedBox(height: 16),
              ]);
          }),
        ]),
    );
  }

  Widget _badgeTile(GrindBadge b, AppColors c) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(c.radius)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(b.unlocked ? b.emoji : '🔒',
                style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(b.name, style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w900,
              color: b.unlocked ? c.accent : c.muted,
              fontFamily: c.fontFamily)),
            const SizedBox(height: 8),
            Text(b.desc, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.muted)),
            const SizedBox(height: 4),
            Text(b.unlocked ? '✅ UNLOCKED' : '🔒 LOCKED',
              style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.w800,
                color: b.unlocked ? c.green : c.muted,
                letterSpacing: 1)),
          ]),
          actions: [TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(
                color: c.accent, fontWeight: FontWeight.w800)))],
        )),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 64, height: 80,
        decoration: BoxDecoration(
          color: b.unlocked
              ? c.accent.withOpacity(0.12) : c.surface2,
          borderRadius: BorderRadius.circular(c.radiusSm),
          border: Border.all(
            color: b.unlocked ? c.accent : c.border,
            width: b.unlocked ? 1.5 : 1)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(b.unlocked ? b.emoji : '🔒',
              style: TextStyle(fontSize: 22,
                color: b.unlocked ? null : Colors.grey)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(b.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: b.unlocked ? c.text : c.muted))),
          ]),
      ),
    );
  }

  // FIX: single tile handles both in-progress AND completed — tap always toggles
  Widget _sessionTile(_Session s, AppColors c) {
    Color col;
    try { col = Color(int.parse(
        s.color.replaceFirst('#', '0xFF'))); }
    catch (_) { col = c.accent; }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.done ? c.green.withOpacity(0.05) : c.surface2,
        borderRadius: BorderRadius.circular(c.radiusSm),
        border: Border.all(
          color: s.done ? c.green.withOpacity(0.3) : c.border)),
      child: Row(children: [
        GestureDetector(
          onTap: () => _toggleDone(s),
          child: Container(
            width: 22, height: 22,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: s.done ? c.green : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: s.done ? c.green : c.muted, width: 2)),
            child: s.done
                ? const Icon(Icons.check, size: 14,
                    color: Colors.white)
                : null)),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.subject, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w800, color: col,
              fontFamily: c.fontFamily,
              decoration: s.done ? TextDecoration.lineThrough : null)),
            if (s.task.isNotEmpty)
              Text(s.task, style: TextStyle(fontSize: 12,
                color: c.text, fontWeight: FontWeight.w600,
                decoration: s.done ? TextDecoration.lineThrough : null)),
            Text('⏱ ${_fmtMins(s.mins)}', style: TextStyle(
              fontSize: 10, color: c.muted,
              fontWeight: FontWeight.w600)),
          ])),
      ]),
    );
  }

  // FIX: roast + motivation in one card, both refresh together
  Widget _roastCard(AppColors c) => Column(children: [
    // ── Roast ──
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface,
        borderRadius: BorderRadius.circular(c.radius),
        border: Border.all(color: c.red.withOpacity(0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text('AI ROAST REPORT', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w900,
                  color: c.red, letterSpacing: 0.8,
                  fontFamily: c.fontFamily)),
              ]),
              GestureDetector(
                onTap: _roastLoading ? null : _loadRoastAndMotivation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(color: c.surface2,
                    borderRadius: BorderRadius.circular(c.radiusSm),
                    border: Border.all(color: c.border)),
                  child: Text('↺ Refresh', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: c.muted)))),
            ]),
          const SizedBox(height: 12),
          if (_roastLoading)
            Center(child: Column(children: [
              CircularProgressIndicator(
                  color: c.red, strokeWidth: 2),
              const SizedBox(height: 8),
              Text('Cooking your roast... 🔥', style: TextStyle(
                fontSize: 11, color: c.muted,
                fontStyle: FontStyle.italic)),
            ]))
          else if (_roastText.isEmpty)
            Text('Roast failed. Even our AI gave up on you.',
              style: TextStyle(fontSize: 12, color: c.muted))
          else
            ..._roastText.trim().split('\n')
              .where((l) => l.trim().isNotEmpty)
              .map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(line.trim(), style: TextStyle(
                  fontSize: 12, color: c.muted,
                  fontWeight: FontWeight.w600, height: 1.4)))),
        ]),
    ),

    const SizedBox(height: 10),

    // ── Motivation ──
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface,
        borderRadius: BorderRadius.circular(c.radius),
        border: Border.all(color: c.green.withOpacity(0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('💚', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text('BUT ACTUALLY THOUGH...', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w900,
              color: c.green, letterSpacing: 0.8,
              fontFamily: c.fontFamily)),
          ]),
          const SizedBox(height: 12),
          if (_roastLoading)
            Center(child: Column(children: [
              CircularProgressIndicator(
                  color: c.green, strokeWidth: 2),
              const SizedBox(height: 8),
              Text('Finding your wins...', style: TextStyle(
                fontSize: 11, color: c.muted,
                fontStyle: FontStyle.italic)),
            ]))
          else if (_motivText.isEmpty)
            Text('Keep grinding. Good things are coming.',
              style: TextStyle(fontSize: 12, color: c.muted))
          else
            ..._motivText.trim().split('\n')
              .where((l) => l.trim().isNotEmpty)
              .map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(line.trim(), style: TextStyle(
                  fontSize: 12, color: c.muted,
                  fontWeight: FontWeight.w600, height: 1.4)))),
        ]),
    ),
  ]);

 Widget _rangePills(AppColors c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: ['Day','Week','Month'].map((l) {
      final active = _range == l.toLowerCase();
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: GestureDetector(
          onTap: () => setState(() => _range = l.toLowerCase()),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              color: active ? c.accent : c.surface2,
              borderRadius: BorderRadius.circular(c.radiusSm),
              border: Border.all(
                  color: active ? c.accent : c.border)),
            child: Text(l, style: TextStyle(fontSize: 9,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : c.muted)))));
    }).toList(),
  );

  Widget _sectionCard(String title, AppColors c,
      {required Widget child, Widget? trailing}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface,
        borderRadius: BorderRadius.circular(c.radius),
        border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w800, color: c.text,
                fontFamily: c.fontFamily)),
              if (trailing != null) trailing,
            ]),
          const SizedBox(height: 14),
          child,
        ]));

  Widget _statCell(String icon, String val, String label,
      AppColors c) =>
    Expanded(child: Column(children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(fontSize: 14,
        fontWeight: FontWeight.w900, color: c.text,
        fontFamily: c.fontFamily)),
      Text(label, style: TextStyle(fontSize: 9,
        color: c.muted, fontWeight: FontWeight.w600)),
    ]));

  Widget _vDivider(AppColors c) => Container(
    width: 1, height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: c.border);
}

// ── Data classes ──
class _SubjData {
  final String color;
  int mins;
  _SubjData({required this.color, required this.mins});
}

class _Session {
  final String id, subject, color, task, date;
  final int    mins;
  final bool   done;
  const _Session({
    required this.id,       required this.subject,
    required this.color,    required this.task,
    required this.mins,     required this.date,
    required this.done,
  });
}

class _DayPoint {
  final String label;
  final int    mins;
  const _DayPoint({required this.label, required this.mins});
}