import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/theme_decoration_layer.dart';
import 'dart:convert';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool   _loading = true;
  String _filter  = 'global';
  List<_LBEntry> _entries = [];
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      Query query;
      if (_filter == 'weekly') {
        query = FirebaseFirestore.instance
            .collection('users')
            .orderBy('weeklyXp', descending: true)
            .limit(50);
      } else {
        query = FirebaseFirestore.instance
            .collection('users')
            .orderBy('xp', descending: true)
            .limit(50);
      }

      final snap    = await query.get();
      final entries = <_LBEntry>[];
      int   rank    = 1;

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // FIX: filter out anonymous/nameless users
        final name = (data['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;

        final xp = _filter == 'weekly'
            ? ((data['weeklyXp'] ?? data['xp'] ?? 0) as int)
            : ((data['xp'] ?? 0) as int);
        final totalMins = (data['totalMinutes'] ?? 0) as int;

        entries.add(_LBEntry(
          uid:           doc.id,
          rank:          rank++,
          name:          name,
          avatar:        (data['avatar']    ?? '🧑‍💻') as String,
          avatarUrl:     (data['avatarUrl']     ?? '') as String,
          avatarBase64:  (data['avatarBase64']  ?? '') as String,
          xp:            xp,
          totalHours:    totalMins / 60,
          streak:        (data['streak']    ?? 0) as int,
          bio:           (data['bio']       ?? '') as String,
          isMe:          doc.id == _myUid,
          unlockedBadges: List<String>.from(
              data['unlockedBadges'] ?? []),
        ));
      }

      if (mounted) setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (_filter == 'weekly') {
        setState(() => _filter = 'global');
        _load();
      } else {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  String _title(double hrs) {
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

  // FIX: profile tap dialog
  void _showProfileDialog(_LBEntry e, AppColors c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(c.radius)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(mainAxisSize: MainAxisSize.min, children: [

          // Avatar
          _networkAvatar(e.avatarUrl, e.avatar, 72, 22, c, base64: e.avatarBase64),
          const SizedBox(height: 12),

          // Name
          Text(e.name, style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900,
            color: c.text, fontFamily: c.fontFamily)),
          const SizedBox(height: 4),

          // Title chip
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: c.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: c.accent.withOpacity(0.3))),
            child: Text(_title(e.totalHours), style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: c.accent, letterSpacing: 0.8))),

          // Bio
          if (e.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(e.bio, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.muted)),
          ],
          const SizedBox(height: 14),

          // Stats row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(c.radiusSm),
              border: Border.all(color: c.border)),
            child: Row(children: [
              _dStat('⚡ XP',   '${e.xp}',                       c),
              _dDivider(c),
              _dStat('🔥 Streak', '${e.streak}d',                c),
              _dDivider(c),
              _dStat('⏱️ Hours',
                  e.totalHours.toStringAsFixed(1), c),
            ])),
          const SizedBox(height: 12),

          // Rank
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: e.rank == 1
                  ? c.gold.withOpacity(0.12)
                  : c.surface2,
              borderRadius: BorderRadius.circular(c.radiusSm),
              border: Border.all(
                color: e.rank == 1
                    ? c.gold.withOpacity(0.4)
                    : c.border)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  e.rank <= 3
                    ? ['🥇','🥈','🥉'][e.rank - 1]
                    : '🏅',
                  style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('GLOBAL RANK #${e.rank}',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: e.rank == 1 ? c.gold : c.text,
                    letterSpacing: 0.5)),
              ])),

          // Badges
          if (e.unlockedBadges.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft,
              child: Text('BADGES', style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: c.muted, letterSpacing: 1.1))),
            const SizedBox(height: 6),
            _badgePills(
                e.unlockedBadges.take(8).toList(), c),
          ],
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(
                color: c.accent, fontWeight: FontWeight.w800))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🏆 Leaderboard', style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: c.text, fontFamily: c.fontFamily)),
                if (!_loading) ...[
                  () {
                    final me = _entries.where((e) => e.isMe).toList();
                    if (me.isEmpty) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: c.accent.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(c.radiusSm),
                        border: Border.all(color: c.accent)),
                      child: Text('YOU · #${me.first.rank}',
                        style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: c.accent)));
                  }(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Filter pills ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _filterBtn('🌍 Global',    'global', c),
              const SizedBox(width: 8),
              _filterBtn('📅 This Week', 'weekly', c),
            ]),
          ),
          const SizedBox(height: 16),

          // ── List ──
          Expanded(
            child: _loading
              ? Center(child: CircularProgressIndicator(
                  color: c.accent))
              : _entries.isEmpty
                ? Center(child: Text(
                    'No data yet. Be the first!',
                    style: TextStyle(
                        color: c.muted, fontSize: 14)))
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          20, 0, 20, 24),
                      itemCount: _entries.length,
                      itemBuilder: (_, i) {
                        final e      = _entries[i];
                        final maxXp  = _entries.first.xp
                            .toDouble().clamp(1.0, 999999.0);
                        if (i == 0) return _champCard(e, c);
                        return _rankRow(e, maxXp, c);
                      },
                    ),
                  ),
         ),
        ]),
          ),
          const ThemeDecorationLayer(screen: 'ranks'),
        ],
      ),
    );
  }

  // ── Champion card ──
  Widget _champCard(_LBEntry e, AppColors c) {
    return GestureDetector(
      onTap: () => _showProfileDialog(e, c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              c.gold.withOpacity(0.15),
              c.orange.withOpacity(0.08)],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight),
          borderRadius: BorderRadius.circular(c.radius),
          border: Border.all(
              color: c.gold.withOpacity(0.5), width: 1.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(children: [
            const Text('👑', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text('FOCUS CHAMP', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: c.gold, letterSpacing: 1.2)),
            const Spacer(),
            Text('Tap to view profile', style: TextStyle(
              fontSize: 9, color: c.muted,
              fontStyle: FontStyle.italic)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _networkAvatar(e.avatarUrl, e.avatar, 52, 28,
              c, borderColor: e.isMe ? c.accent : c.gold,
              bgColor: e.isMe
                  ? c.accent.withOpacity(0.2)
                  : c.gold.withOpacity(0.15),
              base64: e.avatarBase64),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(e.name, style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900,
                    color: c.text, fontFamily: c.fontFamily),
                    overflow: TextOverflow.ellipsis)),
                  if (e.isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(4)),
                      child: const Text('YOU', style: TextStyle(
                        fontSize: 8, fontWeight: FontWeight.w900,
                        color: Colors.white))),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(_title(e.totalHours), style: TextStyle(
                  fontSize: 9, color: c.gold,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text('🔥 ${e.streak}d streak',
                  style: TextStyle(fontSize: 10,
                    color: c.muted,
                    fontWeight: FontWeight.w600)),
              ])),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
              Text('${e.totalHours.toStringAsFixed(1)}h',
                style: TextStyle(fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: c.gold,
                  fontFamily: c.fontFamily)),
              Text('TOTAL', style: TextStyle(
                fontSize: 8, color: c.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
            ]),
          ]),
          if (e.unlockedBadges.isNotEmpty) ...[
            const SizedBox(height: 10),
            _badgePills(
                e.unlockedBadges.take(3).toList(), c),
          ],
        ]),
      ),
    );
  }

  // ── Rank row ──
  Widget _rankRow(_LBEntry e, double maxXp, AppColors c) {
    final frac = (e.xp / maxXp).clamp(0.0, 1.0);
    Color rankColor;
    if (e.rank == 2)      rankColor = const Color(0xFFAAAAAA);
    else if (e.rank == 3) rankColor = const Color(0xFFCD7F32);
    else                  rankColor = c.muted;

    return GestureDetector(
      onTap: () => _showProfileDialog(e, c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: e.isMe
              ? c.accent.withOpacity(0.08)
              : c.surface,
          borderRadius: BorderRadius.circular(c.radius),
          border: Border.all(
            color: e.isMe
                ? c.accent.withOpacity(0.4)
                : c.border,
            width: e.isMe ? 1.5 : 1)),
        child: Stack(children: [
          // Progress bar background
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(c.radius - 1),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(
                    decoration: BoxDecoration(
                      color: (e.isMe ? c.accent : c.muted)
                          .withOpacity(0.06))))))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              SizedBox(width: 32, child: Text(
                e.rank <= 3
                  ? ['🥇','🥈','🥉'][e.rank - 1]
                  : '#${e.rank}',
                style: TextStyle(
                  fontSize: e.rank <= 3 ? 18 : 12,
                  fontWeight: FontWeight.w800,
                  color: rankColor,
                  fontFamily: c.fontFamily))),
              _networkAvatar(e.avatarUrl, e.avatar, 36, 20,
                c, borderRadius: c.radiusSm.toDouble(),
                bgColor: e.isMe
                    ? c.accent.withOpacity(0.15)
                    : c.surface2,
                base64: e.avatarBase64),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(e.name, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: c.text,
                      fontFamily: c.fontFamily),
                      overflow: TextOverflow.ellipsis)),
                    if (e.isMe) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(3)),
                        child: const Text('YOU',
                          style: TextStyle(fontSize: 7,
                            fontWeight: FontWeight.w900,
                            color: Colors.white))),
                    ],
                  ]),
                  Text(_title(e.totalHours), style: TextStyle(
                    fontSize: 8, color: c.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
                  if (e.unlockedBadges.isNotEmpty)
                    _badgePills(
                      e.unlockedBadges.take(2).toList(), c,
                      small: true),
                ])),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                Text('${e.totalHours.toStringAsFixed(1)}h',
                  style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: c.text,
                    fontFamily: c.fontFamily)),
                Text('TOTAL', style: TextStyle(
                  fontSize: 8, color: c.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Shared: network avatar with emoji fallback ──
  Widget _networkAvatar(
    String url, String emoji,
    double size, double fontSize,
    AppColors c, {
    Color?  borderColor,
    Color?  bgColor,
    double? borderRadius,
    String  base64 = '',
  }) {
    final br  = borderRadius ?? (size / 2);
    final bg  = bgColor ?? c.surface2;
    final bc  = borderColor ?? c.border;

    Widget imageWidget;
    if (base64.isNotEmpty) {
      imageWidget = Image.memory(base64Decode(base64),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
              child: Text(emoji,
                  style: TextStyle(fontSize: fontSize))));
    } else if (url.isNotEmpty) {
      imageWidget = Image.network(url, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
              child: Text(emoji,
                  style: TextStyle(fontSize: fontSize))));
    } else {
      imageWidget = Center(child: Text(emoji,
          style: TextStyle(fontSize: fontSize)));
    }

    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(br),
        border: Border.all(color: bc, width: 1.5)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(br - 1.5),
        child: imageWidget));
  }

  Widget _badgePills(List<String> ids, AppColors c,
      {bool small = false}) {
    String emojiFor(String id) {
      if (id.startsWith('time_'))    return '⏱️';
      if (id.startsWith('streak_'))  return '🔥';
      if (id.startsWith('sess_'))    return '🍅';
      if (id.startsWith('subj_'))    return '🎓';
      if (id == 'special_rank1')     return '🥇';
      if (id == 'special_top10')     return '🏆';
      if (id == 'special_night')     return '🌙';
      if (id == 'special_early')     return '🌅';
      if (id == 'special_weekend')   return '📅';
      return '🏅';
    }
    return Padding(
      padding: EdgeInsets.only(top: small ? 2 : 4),
      child: Wrap(spacing: 4, children: ids.map((id) =>
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 4 : 6,
            vertical:   small ? 1 : 2),
          decoration: BoxDecoration(
            color: c.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: c.accent.withOpacity(0.3))),
          child: Text(emojiFor(id),
            style: TextStyle(
                fontSize: small ? 9 : 11)),
        )).toList()),
    );
  }

  Widget _filterBtn(String label, String val, AppColors c) {
    final active = _filter == val;
    return GestureDetector(
      onTap: () {
        if (_filter == val) return;
        setState(() => _filter = val);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(c.radiusSm + 4),
          border: Border.all(
              color: active ? c.accent : c.border)),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w800,
          color: active ? Colors.white : c.muted))));
  }

  Widget _dStat(String label, String val, AppColors c) =>
    Expanded(child: Column(children: [
      Text(val, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w900,
        color: c.text, fontFamily: c.fontFamily)),
      Text(label, style: TextStyle(
        fontSize: 9, color: c.muted,
        fontWeight: FontWeight.w600)),
    ]));

  Widget _dDivider(AppColors c) => Container(
    width: 1, height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: c.border);
}

// ── Data class ──
class _LBEntry {
  final String uid, name, avatar, avatarUrl, avatarBase64, bio;
  final int    rank, xp, streak;
  final double totalHours;
  final bool   isMe;
  final List<String> unlockedBadges;

  const _LBEntry({
    required this.uid,          required this.name,
    required this.avatar,       required this.avatarUrl,
    required this.avatarBase64, required this.bio,
    required this.rank,
    required this.xp,           required this.streak,
    required this.totalHours,   required this.isMe,
    required this.unlockedBadges,
  });
}