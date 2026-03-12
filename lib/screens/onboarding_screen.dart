import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'dart:convert';
import '../utils/image_helper.dart';

class OnboardingScreen extends StatefulWidget {
  final String name;
  const OnboardingScreen({super.key, required this.name});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int    _step      = 0;
  double _goalHours = 3;
  String _pomMode   = 'classic';
  bool   _saving    = false;
  String? _uploadError;

  final List<Map<String, dynamic>> _subjects = [];
  final _subjCtrl = TextEditingController();

  // ── Avatar / photo ──
  // These are the exact same 16 avatars used in profile_screen.dart
  static const List<String> kAvatars = [
    '🧑‍💻','👨‍🎓','👩‍🎓','🧠','👾','🦊','🐺','🔥',
    '💀','🤖','👑','⚡','🦁','🐉','🎯','🏆',
  ];

  String _selectedAvatar = '🧑‍💻';
  String _selectedTheme  = 'defaultBlue';
  File?  _profileImage;
  final  _picker = ImagePicker();

  final List<String> _suggestions = [
    'Biology', 'Chemistry', 'Physics', 'Maths',
    'Combined Maths', 'English', 'Anatomy', 'Economics',
  ];

  final List<Map<String, dynamic>> _pomModes = [
    {'id': 'classic', 'icon': '🍅', 'label': 'Classic Pomodoro',
      'desc': '25 min focus · 5 min break'},
    {'id': 'deep',    'icon': '🧠', 'label': 'Deep Work',
      'desc': '50 min focus · 10 min break'},
    {'id': 'sprint',  'icon': '⚡', 'label': 'Sprint',
      'desc': '15 min focus · 3 min break'},
  ];

  final List<String> _subjectColors = [
    '#5B8DEE', '#8B6CF6', '#34C77B', '#F07832',
    '#F0A500', '#E84040', '#E8744A', '#5555AA',
  ];

  final List<Map<String, dynamic>> _themes = [
    {'id': 'defaultBlue', 'emoji': '🔵', 'label': 'Default',
      'bg': 0xFFF0F4FF, 'accent': 0xFF5B8DEE, 'dark': false},
    {'id': 'soft',        'emoji': '🌸', 'label': 'Soft',
      'bg': 0xFFFDF6F0, 'accent': 0xFFE8744A, 'dark': false},
    {'id': 'minimal',     'emoji': '◻',  'label': 'Minimal',
      'bg': 0xFFF9F9F7, 'accent': 0xFF1A1A1A, 'dark': false},
    {'id': 'forest',      'emoji': '🌿', 'label': 'Forest',
      'bg': 0xFF0D1A0F, 'accent': 0xFF5DDB6F, 'dark': true},
    {'id': 'f1',          'emoji': '🏎',  'label': 'F1 Racer',
      'bg': 0xFF080402, 'accent': 0xFFE8001A, 'dark': true},
    {'id': 'manga',       'emoji': '✿',  'label': 'Manga',
      'bg': 0xFFEAF5FF, 'accent': 0xFF3A8FFF, 'dark': false},
    {'id': 'anime',       'emoji': '♡',  'label': 'Anime',
      'bg': 0xFFF8EEFF, 'accent': 0xFFAA44FF, 'dark': false},
    {'id': 'nature',      'emoji': '🍃', 'label': 'Nature',
      'bg': 0xFFF0F6EA, 'accent': 0xFF4A8C3A, 'dark': false},
    {'id': 'arcade',      'emoji': '🕹️', 'label': 'Arcade',
      'bg': 0xFF0A0015, 'accent': 0xFF00FF41, 'dark': true},
  ];

  void _addSubject(String name) {
    name = name.trim();
    if (name.isEmpty) return;
    if (_subjects.length >= 8) return;
    if (_subjects.any((s) =>
        s['name'].toString().toLowerCase() == name.toLowerCase())) return;
    setState(() {
      _subjects.add({
        'name':  name,
        'color': _subjectColors[_subjects.length % _subjectColors.length],
      });
      _subjCtrl.clear();
    });
  }

  void _removeSubject(int index) =>
      setState(() => _subjects.removeAt(index));

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
        // Clear emoji selection when photo is picked
      });
    }
  }

  // FIX: upload photo to Firebase Storage and save avatarUrl to Firestore
  Future<void> _finish() async {
    setState(() { _saving = true; _uploadError = null; });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      String? avatarUrl;

      if (_profileImage != null) {
        try {
          final base64 = await ImageHelper.toBase64(_profileImage!);
          if (base64 != null) {
            await FirebaseFirestore.instance
                .collection('users').doc(uid)
                .update({'avatarBase64': base64});
          }
        } catch (e) {
          setState(() {
            _uploadError = 'Photo upload failed. You can add it later in your profile.';
            _profileImage = null;
          });
        }
      }

      await FirebaseFirestore.instance
          .collection('users').doc(uid).update({
        'dailyGoalMinutes': (_goalHours * 60).round(),
        'pomodoroMode':     _pomMode,
        'subjects':         _subjects,
        'avatar':           _selectedAvatar,
        'avatarUrl':        avatarUrl ?? '',
        'theme':            _selectedTheme,
        'onboardingDone':   true,
      });

      if (mounted) Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (mounted) setState(() {
        _saving = false;
        _uploadError = 'Something went wrong. Please try again.';
      });
    }
  }

  String _goalText() {
    final h = _goalHours.floor();
    final m = ((_goalHours - h) * 60).round();
    if (m == 0) return '${h}h 00m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String _goalDesc() {
    if (_goalHours <= 1) return "Light session. Better than nothing I guess.";
    if (_goalHours <= 2) return "Decent. Don't bail after 30 mins though.";
    if (_goalHours <= 3) return "Solid plan. 6 Pomodoros. You've got this.";
    if (_goalHours <= 5) return "Ambitious. We respect the grind.";
    if (_goalHours <= 7) return "Are you okay? That's a lot. Mad respect.";
    return "Bro thinks they're a studying machine. Prove it.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(children: [
          LinearProgressIndicator(
            value: (_step + 1) / 5,
            backgroundColor: AppColors.surface2Light,
            color: AppColors.staticAccent,
            minHeight: 4),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _step == 0 ? _stepGoal()
                   : _step == 1 ? _stepSubjects()
                   : _step == 2 ? _stepPomodoro()
                   : _step == 3 ? _stepProfile()
                   : _stepHowTo(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : () {
                  if (_step < 4) setState(() => _step++);
                  else _finish();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.staticAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
                child: _saving
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(_step < 4 ? 'Next →' : "Let's Grind 🔥",
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito')),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  STEP 1 — Goal
  // ─────────────────────────────────────────────
  Widget _stepGoal() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text('Hey ${widget.name}! 👋',
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
            color: AppColors.textLight, fontFamily: 'Nunito')),
      const SizedBox(height: 8),
      const Text('Set your daily study goal',
        style: TextStyle(fontSize: 16, color: AppColors.mutedLight)),
      const SizedBox(height: 32),
      Center(child: Text(_goalText(),
        style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900,
            color: AppColors.staticAccent, fontFamily: 'Nunito'))),
      const SizedBox(height: 8),
      Center(child: Text(_goalDesc(),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.mutedLight))),
      const SizedBox(height: 24),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor:   AppColors.staticAccent,
          inactiveTrackColor: AppColors.surface2Light,
          thumbColor:         AppColors.staticAccent,
          overlayColor: AppColors.staticAccent.withOpacity(0.1)),
        child: Slider(
          value: _goalHours, min: 0.5, max: 10, divisions: 19,
          onChanged: (v) => setState(() => _goalHours = v)),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text('30 min', style: TextStyle(
              color: AppColors.mutedLight, fontSize: 12)),
          Text('10 hrs', style: TextStyle(
              color: AppColors.mutedLight, fontSize: 12)),
        ]),
    ]);
  }

  // ─────────────────────────────────────────────
  //  STEP 2 — Subjects
  // ─────────────────────────────────────────────
  Widget _stepSubjects() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      const Text('Your subjects', style: TextStyle(fontSize: 26,
          fontWeight: FontWeight.w900, color: AppColors.textLight,
          fontFamily: 'Nunito')),
      const SizedBox(height: 8),
      const Text('Add up to 8 subjects you study',
        style: TextStyle(fontSize: 16, color: AppColors.mutedLight)),
      const SizedBox(height: 24),
      if (_subjects.isNotEmpty) ...[
        Wrap(spacing: 8, runSpacing: 8,
          children: _subjects.asMap().entries.map((e) => Chip(
            label: Text(e.value['name'], style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700,
                fontSize: 13)),
            backgroundColor: Color(int.parse(
                (e.value['color'] as String).replaceFirst('#', '0xFF'))),
            deleteIconColor: Colors.white,
            onDeleted: () => _removeSubject(e.key),
          )).toList()),
        const SizedBox(height: 16),
      ],
      Row(children: [
        Expanded(
          child: TextField(
            controller: _subjCtrl,
            style: const TextStyle(
                fontSize: 15, color: AppColors.textLight),
            onSubmitted: _addSubject,
            decoration: InputDecoration(
              hintText: 'Type a subject and press Add',
              hintStyle: const TextStyle(
                  color: AppColors.mutedLight, fontSize: 13),
              filled: true, fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.borderLight)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.borderLight)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.staticAccent, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14)),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => _addSubject(_subjCtrl.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.staticAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
          child: const Text('+ Add', style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8,
        children: _suggestions
          .where((s) => !_subjects.any((sub) => sub['name'] == s))
          .map((s) => GestureDetector(
            onTap: () => _addSubject(s),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface2Light,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight)),
              child: Text(s, style: const TextStyle(fontSize: 13,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600))),
          )).toList()),
    ]);
  }

  // ─────────────────────────────────────────────
  //  STEP 3 — Pomodoro
  // ─────────────────────────────────────────────
  Widget _stepPomodoro() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      const Text('Pick your style', style: TextStyle(fontSize: 26,
          fontWeight: FontWeight.w900, color: AppColors.textLight,
          fontFamily: 'Nunito')),
      const SizedBox(height: 8),
      const Text('How do you like to focus?',
        style: TextStyle(fontSize: 16, color: AppColors.mutedLight)),
      const SizedBox(height: 32),
      ..._pomModes.map((mode) {
        final selected = _pomMode == mode['id'];
        return GestureDetector(
          onTap: () => setState(() => _pomMode = mode['id'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.staticAccent.withOpacity(0.1)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.staticAccent
                    : AppColors.borderLight,
                width: selected ? 2 : 1)),
            child: Row(children: [
              Text(mode['icon'] as String,
                  style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode['label'] as String, style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: selected
                        ? AppColors.staticAccent
                        : AppColors.textLight,
                    fontFamily: 'Nunito')),
                  Text(mode['desc'] as String,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedLight)),
                ])),
              if (selected) const Icon(Icons.check_circle,
                  color: AppColors.staticAccent, size: 24),
            ]),
          ),
        );
      }),
    ]);
  }

  // ─────────────────────────────────────────────
  //  STEP 5 — How To Use
  // ─────────────────────────────────────────────
  Widget _stepHowTo() {
    final features = [
      {
        'icon': '⚡',
        'title': 'Focus Timer',
        'desc': 'Start a session. Pick your subject. Actually study.\nNo, scrolling doesn\'t count.',
      },
      {
        'icon': '🏆',
        'title': 'Ranks',
        'desc': 'Global leaderboard based on XP.\nYou earn 2 XP per minute studied. Yes, cheating is pointless.',
      },
      {
        'icon': '👥',
        'title': 'Groups',
        'desc': 'Study with friends. Or enemies.\nNothing like watching someone else grind to get you off your phone.',
      },
      {
        'icon': '📊',
        'title': 'Daily Report',
        'desc': 'See how much you studied, your grade, and get roasted by AI.\nDaily. Personally. Specifically.',
      },
      {
        'icon': '🔥',
        'title': 'Streaks & Badges',
        'desc': 'Study every day to keep your streak alive.\nMiss one day and watch it die. Tragic.',
      },
      {
        'icon': '🎯',
        'title': 'Daily Goal',
        'desc': 'You set ${_goalText()} as your daily goal.\nYour grade in Reports is based on how close you get. F is not a vibe.',
      },
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      const Text('How this works', style: TextStyle(
        fontSize: 26, fontWeight: FontWeight.w900,
        color: AppColors.textLight, fontFamily: 'Nunito')),
      const SizedBox(height: 4),
      const Text('Read this. Or don\'t. You\'ll figure it out eventually.',
        style: TextStyle(fontSize: 13, color: AppColors.mutedLight)),
      const SizedBox(height: 24),

      ...features.map((f) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.staticAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(f['icon']!,
                style: const TextStyle(fontSize: 22)))),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f['title']!, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: AppColors.textLight, fontFamily: 'Nunito')),
                const SizedBox(height: 4),
                Text(f['desc']!, style: const TextStyle(
                  fontSize: 12, color: AppColors.mutedLight,
                  height: 1.5)),
              ])),
          ])),
      ),

      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.staticAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.staticAccent.withOpacity(0.3))),
        child: const Text(
          '💡 Pro tip: The grind doesn\'t care about your mood.\n   Show up anyway.',
          style: TextStyle(fontSize: 12, color: AppColors.mutedLight,
            fontWeight: FontWeight.w600, height: 1.5)),
      ),
      const SizedBox(height: 8),
    ]);
  }

  // ─────────────────────────────────────────────
  //  STEP 4 — Profile + Theme
  // ─────────────────────────────────────────────
  Widget _stepProfile() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      const Text('Pick your vibe', style: TextStyle(
        fontSize: 26, fontWeight: FontWeight.w900,
        color: AppColors.textLight, fontFamily: 'Nunito')),
      const SizedBox(height: 8),
      const Text('Avatar, photo and theme',
        style: TextStyle(fontSize: 16, color: AppColors.mutedLight)),
      const SizedBox(height: 24),

      // ── Profile photo preview ──
      const Text('PROFILE PHOTO', style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w800,
        color: AppColors.mutedLight, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      Center(child: Stack(children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: AppColors.surface2Light,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: AppColors.staticAccent, width: 2)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: _profileImage != null
              ? Image.file(_profileImage!, fit: BoxFit.cover)
              : Center(child: Text(_selectedAvatar,
                  style: const TextStyle(fontSize: 44))))),
        Positioned(bottom: 0, right: 0,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.staticAccent,
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 16)))),
      ])),

      // Remove photo button
      if (_profileImage != null) ...[
        const SizedBox(height: 8),
        Center(child: GestureDetector(
          onTap: () => setState(() => _profileImage = null),
          child: Text('Remove photo',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mutedLight,
              decoration: TextDecoration.underline)),
        )),
      ],
      if (_uploadError != null) ...[
        const SizedBox(height: 8),
        Center(child: Text(
          _uploadError!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        )),
      ],
      const SizedBox(height: 20),

      // ── Avatar grid ──
      const Text('OR PICK AN AVATAR', style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w800,
        color: AppColors.mutedLight, letterSpacing: 1.2)),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8),
        itemCount: kAvatars.length,
        itemBuilder: (_, i) {
          final sel = _selectedAvatar == kAvatars[i] &&
              _profileImage == null;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedAvatar = kAvatars[i];
              _profileImage   = null;
            }),
            child: Container(
              decoration: BoxDecoration(
                color: sel
                  ? AppColors.staticAccent.withOpacity(0.15)
                  : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sel
                      ? AppColors.staticAccent
                      : AppColors.borderLight)),
              child: Center(child: Text(kAvatars[i],
                  style: const TextStyle(fontSize: 22)))));
        }),
      const SizedBox(height: 28),

      // ── Theme picker ──
      const Text('THEME', style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w800,
        color: AppColors.mutedLight, letterSpacing: 1.2)),
      const SizedBox(height: 4),
      const Text('These are the exact themes available in the app.',
        style: TextStyle(fontSize: 11, color: AppColors.mutedLight)),
      const SizedBox(height: 14),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95),
        itemCount: _themes.length,
        itemBuilder: (_, i) {
          final t      = _themes[i];
          final sel    = _selectedTheme == t['id'];
          final bg     = Color(t['bg'] as int);
          final ac     = Color(t['accent'] as int);
          final isDark = t['dark'] as bool;
          return GestureDetector(
            onTap: () =>
                setState(() => _selectedTheme = t['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: sel
                      ? AppColors.staticAccent
                      : AppColors.borderLight,
                  width: sel ? 2.5 : 1)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t['emoji'] as String,
                      style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 6),
                  Text(t['label'] as String, style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: isDark
                        ? Colors.white70
                        : AppColors.textLight)),
                  const SizedBox(height: 6),
                  Container(width: 20, height: 4,
                    decoration: BoxDecoration(
                      color: ac,
                      borderRadius: BorderRadius.circular(2))),
                  if (sel) ...[
                    const SizedBox(height: 4),
                    const Icon(Icons.check_circle,
                        color: AppColors.staticAccent, size: 14),
                  ],
                ],
              ),
            ),
          );
        }),
      const SizedBox(height: 8),
    ]);
  }
}