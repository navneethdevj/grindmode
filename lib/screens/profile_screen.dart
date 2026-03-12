import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../services/badge_service.dart';
import 'login_screen.dart';
import '../widgets/theme_decoration_layer.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../utils/image_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
static const List<String> _avatars = [
    '🧑‍💻','👨‍🎓','👩‍🎓','🧠','👾','🦊','🐺','🔥',
    '💀','🤖','👑','⚡','🦁','🐉','🎯','🏆',
  ];

  String _name       = '';
  String _avatar     = '🧑‍💻';
  String _avatarUrl    = '';   // FIX: photo URL from Firebase Storage
  String _avatarBase64 = '';
  String _bio          = '';

  int _totalMins     = 0;
  int _xp            = 0;
  int _streak        = 0;
  int _rank          = 0;
  int _totalSessions = 0;

  List<GrindBadge> _badges = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }

    final doc  = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    final data = doc.data() ?? {};

    final lb = await FirebaseFirestore.instance
        .collection('users').orderBy('xp', descending: true)
        .limit(100).get();
    // FIX #6: apply same anonymous filter as leaderboard screen
    final rank = lb.docs.where((d) {
      final name = ((d.data() as Map)['name'] as String? ?? '').trim();
      return name.isNotEmpty;
    }).toList().indexWhere((d) => d.id == uid) + 1;

    final badges = await BadgeService.loadBadges();

    if (mounted) setState(() {
      _name          = (data['name']          ?? '') as String;
      _avatar        = (data['avatar']        ?? '🧑‍💻') as String;
      _avatarUrl     = (data['avatarUrl']     ?? '') as String;  // FIX
      _avatarBase64  = (data['avatarBase64']  ?? '') as String;
      _bio           = (data['bio']           ?? '') as String;
      _totalMins     = (data['totalMinutes']  ?? 0)  as int;
      _xp            = (data['xp']            ?? 0)  as int;
      _streak        = (data['streak']        ?? 0)  as int;
      _totalSessions = (data['totalSessions'] ?? 0)  as int;
      _rank          = rank;
      _badges        = badges;
      _loading       = false;
    });
  }

  String _titleFor(double hrs) {
    if (hrs >= 500) return 'THE LEGEND';
    if (hrs >= 200) return 'NO LIFE. ALL STUDY.';
    if (hrs >= 100) return 'CENTURY GRINDER';
    if (hrs >= 50)  return 'ELITE STUDENT';
    if (hrs >= 25)  return 'THE GRINDER';
    if (hrs >= 10)  return 'GRIND MODE';
    if (hrs >= 5)   return 'GETTING SERIOUS';
    if (hrs >= 1)   return 'ONE HOUR IN';
    return 'JUST STARTED';
  }

  String _fmtMins(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60; final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

 Widget _avatarWidget(double size, {double fontSize = 34,
      double borderRadius = 20, AppColors? c}) {
    final bc = c != null
        ? c.accent.withOpacity(0.4)
        : AppColors.staticAccent.withOpacity(0.4);
    final bg = c != null
        ? c.accent.withOpacity(0.12)
        : AppColors.staticAccent.withOpacity(0.12);

    Widget imageWidget;
    if (_avatarBase64.isNotEmpty) {
      final bytes = base64Decode(_avatarBase64);
      imageWidget = Image.memory(bytes, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Center(child: Text(_avatar,
                  style: TextStyle(fontSize: fontSize))));
    } else if (_avatarUrl.isNotEmpty) {
      imageWidget = Image.network(_avatarUrl, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Center(child: Text(_avatar,
                  style: TextStyle(fontSize: fontSize))));
    } else {
      imageWidget = Center(child: Text(_avatar,
          style: TextStyle(fontSize: fontSize)));
    }

    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: bc, width: 2)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 2),
        child: imageWidget));
  }

  void _showEditSheet() {
    final c          = AppColors.of(context);
    final nameCtrl   = TextEditingController(text: _name);
    final bioCtrl    = TextEditingController(text: _bio);
    String tempAvatar    = _avatar;
    String tempAvatarUrl = _avatarUrl;
    File?  tempImage;
    final  picker = ImagePicker();

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
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Profile ✏️', style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: c.text, fontFamily: c.fontFamily)),
                      const SizedBox(height: 20),

                      // ── Photo preview + upload ──
                      Text('PROFILE PHOTO', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: c.muted, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      Center(child: Stack(children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: c.surface2,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: c.accent, width: 2)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: tempImage != null
                              ? Image.file(tempImage!,
                                  fit: BoxFit.cover)
                              : tempAvatarUrl.isNotEmpty
                                ? Image.network(tempAvatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                      Center(child: Text(tempAvatar,
                                        style: const TextStyle(
                                            fontSize: 38))))
                                : Center(child: Text(tempAvatar,
                                    style: const TextStyle(
                                        fontSize: 38))))),
                        Positioned(bottom: 0, right: 0,
                          child: GestureDetector(
                            onTap: () async {
                              final picked =
                                  await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 70);
                              if (picked != null) {
                                setSheet(() {
                                  tempImage = File(picked.path);
                                });
                              }
                            },
                            child: Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                color: c.accent,
                                borderRadius:
                                    BorderRadius.circular(8)),
                              child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 14)))),
                      ])),

                      if (tempImage != null ||
                          tempAvatarUrl.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Center(child: GestureDetector(
                          onTap: () => setSheet(() {
                            tempImage    = null;
                            tempAvatarUrl = '';
                          }),
                          child: Text('Remove photo',
                            style: TextStyle(
                              fontSize: 11, color: c.muted,
                              decoration:
                                  TextDecoration.underline)))),
                      ],
                      const SizedBox(height: 16),

                      // ── Avatar grid ──
                      Text('OR PICK AN AVATAR', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: c.muted, letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8),
                        itemCount: _avatars.length,
                        itemBuilder: (_, i) {
                          final av  = _avatars[i];
                          final sel = tempAvatar == av &&
                              tempImage == null &&
                              tempAvatarUrl.isEmpty;
                          return GestureDetector(
                            onTap: () => setSheet(() {
                              tempAvatar    = av;
                              tempImage     = null;
                              tempAvatarUrl = '';
                            }),
                            child: Container(
                              decoration: BoxDecoration(
                                color: sel
                                    ? c.accent.withOpacity(0.15)
                                    : c.surface2,
                                borderRadius: BorderRadius.circular(
                                    c.radiusSm),
                                border: Border.all(
                                  color: sel
                                      ? c.accent
                                      : c.border)),
                              child: Center(child: Text(av,
                                style: const TextStyle(
                                    fontSize: 22)))));
                        }),
                      const SizedBox(height: 16),

                      // ── Name ──
                      Text('NAME', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: c.muted, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      _textField(nameCtrl, 'Your name', c),
                      const SizedBox(height: 14),

                      // ── Bio ──
                      Text('BIO', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: c.muted, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      _textField(bioCtrl,
                        'Tell the world who you are...', c,
                        maxLines: 3),
                      const SizedBox(height: 20),

                      // ── Save ──
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final uid = FirebaseAuth.instance
                                .currentUser?.uid;
                            if (uid == null) return;

                            final Map<String, dynamic> updates = {
                              'name':   nameCtrl.text.trim(),
                              'bio':    bioCtrl.text.trim(),
                              'avatar': tempAvatar,
                            };

                            if (tempImage != null) {
                              final base64 = await ImageHelper
                                  .toBase64(tempImage!);
                              if (base64 != null) {
                                updates['avatarBase64'] = base64;
                                updates['avatarUrl']    = '';
                              }
                            } else if (tempAvatarUrl.isEmpty) {
                              updates['avatarBase64'] = '';
                              updates['avatarUrl']    = '';
                            }

                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .update(updates);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load();
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
                          child: Text('Save Changes',
                            style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w800,
                              fontFamily: c.fontFamily)),
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

  void _showThemePicker() {
    final c = AppColors.of(context);
    showModalBottomSheet(
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
    );
  }

  Future<void> _logout() async {
    final c = AppColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(c.radius)),
        title: Text('Log Out', style: TextStyle(
          fontWeight: FontWeight.w900, color: c.text,
          fontFamily: c.fontFamily)),
        content: Text('Are you sure you want to log out?',
          style: TextStyle(color: c.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: c.muted))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Log Out', style: TextStyle(
                color: c.red, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (_) => false,
      );
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(
            child: CircularProgressIndicator(color: c.accent)));
    }

    final totalHours = _totalMins / 60;
    final unlocked   = _badges.where((b) => b.unlocked).toList();
    final locked     = _badges.where((b) => !b.unlocked).toList();

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
          color: c.accent,
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Profile header ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(c.radius),
                    border: Border.all(color: c.border)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // FIX: use unified avatar widget
                    _avatarWidget(64,
                      fontSize: 34,
                      borderRadius: c.radiusSm + 4,
                      c: c),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name.isEmpty ? 'You' : _name,
                          style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: c.text,
                            fontFamily: c.fontFamily)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: c.accent.withOpacity(0.3))),
                          child: Text(_titleFor(totalHours),
                            style: TextStyle(fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: c.accent,
                              letterSpacing: 0.8))),
                        if (_bio.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(_bio, style: TextStyle(
                            fontSize: 12, color: c.muted,
                            fontWeight: FontWeight.w500)),
                        ],
                      ])),
                    GestureDetector(
                      onTap: _showEditSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.surface2,
                          borderRadius: BorderRadius.circular(
                              c.radiusSm),
                          border: Border.all(color: c.border)),
                        child: Text('✏️ Edit', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: c.muted)))),
                  ])),
                const SizedBox(height: 12),

                // ── Stats grid ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(c.radius),
                    border: Border.all(color: c.border)),
                  child: Column(children: [
                    Row(children: [
                      _statCell('Total Hrs',
                        totalHours.toStringAsFixed(1), c),
                      _vDivider(c),
                      _statCell('Global Rank',
                        _rank > 0 ? '#$_rank' : '–', c,
                        color: c.orange),
                      _vDivider(c),
                      _statCell('XP',
                        _xp.toString(), c, color: c.gold),
                    ]),
                    Divider(color: c.border, height: 24),
                    Row(children: [
                      _statCell('Streak',
                        '🔥 $_streak', c, color: c.orange),
                      _vDivider(c),
                      _statCell('Sessions',
                        _totalSessions.toString(), c),
                      _vDivider(c),
                      _statCell('Badges',
                        '${unlocked.length}', c,
                        color: c.purple),
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Earned badges ──
                if (unlocked.isNotEmpty) ...[
                  _sectionLabel('⚡ Earned Badges', c),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8,
                    children: unlocked.map((b) =>
                        _badgeTile(b, c)).toList()),
                  const SizedBox(height: 20),
                ],

                // ── Locked badges ──
                if (locked.isNotEmpty) ...[
                  _sectionLabel('🔒 Locked Badges', c),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8,
                    children: locked.map((b) =>
                        _badgeTile(b, c)).toList()),
                  const SizedBox(height: 24),
                ],

                // ── Settings ──
                _sectionLabel('⚙️ Settings', c),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(c.radius),
                    border: Border.all(color: c.border)),
                  child: Column(children: [
                    _settingRow('🎨 Change Theme', 'Change',
                        c.accent, _showThemePicker, c),
                    Divider(color: c.border, height: 0),
                    _settingRow('🚪 Log Out', 'Log Out',
                        c.red, _logout, c, danger: true),
                  ]),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
          ),
          const ThemeDecorationLayer(screen: 'profile'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  HELPER WIDGETS
  // ─────────────────────────────────────────────

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
                color: c.accent,
                fontWeight: FontWeight.w800)))],
        )),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 64, height: 80,
        decoration: BoxDecoration(
          color: b.unlocked
              ? c.accent.withOpacity(0.12)
              : c.surface2,
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

  Widget _sectionLabel(String text, AppColors c) =>
    Text(text, style: TextStyle(
      fontSize: 13, fontWeight: FontWeight.w800,
      color: c.text, fontFamily: c.fontFamily));

  Widget _settingRow(String label, String btnLabel,
      Color btnColor, VoidCallback onTap,
      AppColors c, {bool danger = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: c.text)),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: danger
                    ? c.red.withOpacity(0.1)
                    : c.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(c.radiusSm),
                border: Border.all(
                  color: danger
                      ? c.red.withOpacity(0.4)
                      : c.accent.withOpacity(0.4))),
              child: Text(btnLabel, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800,
                color: danger ? c.red : c.accent)))),
        ]));
  }

  Widget _statCell(String label, String val, AppColors c,
      {Color? color}) =>
    Expanded(child: Column(children: [
      Text(val, style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w900,
        color: color ?? c.text, fontFamily: c.fontFamily)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(
        fontSize: 9, color: c.muted,
        fontWeight: FontWeight.w600)),
    ]));

  Widget _vDivider(AppColors c) => Container(
    width: 1, height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: c.border);

  Widget _textField(TextEditingController ctrl, String hint,
      AppColors c, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(fontSize: 14, color: c.text),
      decoration: InputDecoration(
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
            horizontal: 14, vertical: 12)));
  }
}