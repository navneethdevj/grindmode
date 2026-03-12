import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/theme_decoration_layer.dart';
import 'dart:convert';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  bool   _loading = true;
  List<_Group> _groups = [];
  String? _myUid;
  String? _myName;
  String? _myAvatar;
  String? _myAvatarUrl;
  String? _myAvatarBase64;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _loading = true);
    if (_myUid == null) { setState(() => _loading = false); return; }

    final myDoc  = await FirebaseFirestore.instance
        .collection('users').doc(_myUid).get();
    final myData = myDoc.data() ?? {};
    _myName         = (myData['name']         ?? 'You')  as String;
    _myAvatar       = (myData['avatar']       ?? '🧑‍💻') as String;
    _myAvatarUrl    = (myData['avatarUrl']    ?? '')      as String;
    _myAvatarBase64 = (myData['avatarBase64'] ?? '')      as String;
    final snap = await FirebaseFirestore.instance
        .collection('groups')
        .orderBy('memberCount', descending: true)
        .limit(30)
        .get();

    final groups = <_Group>[];
    for (final doc in snap.docs) {
      final d         = doc.data();
      final memberIds = List<String>.from(d['memberIds'] ?? []);
      final joined    = memberIds.contains(_myUid);

      final members    = <_Member>[];
      final memberSnap = await FirebaseFirestore.instance
          .collection('groups').doc(doc.id)
          .collection('members')
          .orderBy('totalMinutes', descending: true)
          .limit(10)
          .get();

      for (int i = 0; i < memberSnap.docs.length; i++) {
        final m = memberSnap.docs[i].data();
        members.add(_Member(
          uid:          memberSnap.docs[i].id,
          name:         (m['name']         ?? 'Anonymous') as String,
          avatar:       (m['avatar']       ?? '🧑‍💻')     as String,
          avatarUrl:    (m['avatarUrl']     ?? '')          as String,
          avatarBase64: (m['avatarBase64']  ?? '')          as String,
          totalHours:   ((m['totalMinutes'] ?? 0) as int) / 60,
          streak:       (m['streak']        ?? 0) as int,
          xp:           (m['xp']            ?? 0) as int,
          bio:          (m['bio']            ?? '') as String,
          rank:         i + 1,
          isMe:         memberSnap.docs[i].id == _myUid,
        ));
      }

      groups.add(_Group(
        id:          doc.id,
        name:        (d['name']        ?? 'Unnamed Squad') as String,
        icon:        (d['icon']        ?? '⚡')            as String,
        bio:         (d['bio']         ?? '')              as String,
        isOpen:      ((d['access']     ?? 'open') as String) == 'open',
        memberCount: (d['memberCount'] ?? 0)  as int,
        memberLimit: (d['memberLimit'] ?? 20) as int,
        inviteCode:  (d['inviteCode']  ?? '')  as String,
        ownerId:     (d['ownerId']     ?? '')  as String,
        joined:      joined,
        members:     members,
      ));
    }

// Auto-sync user stats in all joined groups
    for (final doc in snap.docs) {
      final memberIds = List<String>.from(
          (doc.data())['memberIds'] ?? []);
      if (memberIds.contains(_myUid)) {
        FirebaseFirestore.instance
            .collection('groups').doc(doc.id)
            .collection('members').doc(_myUid)
            .update({
          'name':         (_myName?.isNotEmpty == true)
              ? _myName : 'Anonymous',
          'avatar':       _myAvatar,
          'avatarUrl':    _myAvatarUrl    ?? '',
          'avatarBase64': _myAvatarBase64 ?? '',
          'totalMinutes': myData['totalMinutes'] ?? 0,
          'xp':           myData['xp']           ?? 0,
          'streak':       myData['streak']        ?? 0,
          'bio':          myData['bio']           ?? '',
        }).catchError((_) {}); // ignore if not member yet
      }
    }
   // FIX #4: hide invite-only groups the user hasn't joined
    final filtered = groups.where((g) => g.isOpen || g.joined).toList();

    if (mounted) setState(() {
      _groups  = filtered;
      _loading = false;
    });
  }

  Future<void> _joinGroup(_Group g) async {
    if (_myUid == null) return;
    final myDoc  = await FirebaseFirestore.instance
        .collection('users').doc(_myUid).get();
    final myData = myDoc.data() ?? {};
    final batch  = FirebaseFirestore.instance.batch();

    final groupRef = FirebaseFirestore.instance
        .collection('groups').doc(g.id);
    batch.update(groupRef, {
      'memberIds':   FieldValue.arrayUnion([_myUid]),
      'memberCount': FieldValue.increment(1),
    });

    final memberRef = groupRef.collection('members').doc(_myUid);
    batch.set(memberRef, {
      'name':         (_myName?.isNotEmpty == true) ? _myName : 'Anonymous',
      'avatar':       _myAvatar,
      'avatarUrl':    _myAvatarUrl    ?? '',
      'avatarBase64': _myAvatarBase64 ?? '',
      'totalMinutes': myData['totalMinutes'] ?? 0,
      'xp':           myData['xp']           ?? 0,
      'streak':       myData['streak']        ?? 0,
      'bio':          myData['bio']           ?? '',
      'joinedAt':     FieldValue.serverTimestamp(),
    });

    await batch.commit();
    _loadGroups();
  }

  Future<void> _createGroup({
    required String name,
    required String icon,
    required String bio,
    required bool   isOpen,
    required int    limit,
  }) async {
    if (_myUid == null) return;
    final code = DateTime.now().millisecondsSinceEpoch
        .toRadixString(36).toUpperCase().substring(4);

    final myDoc  = await FirebaseFirestore.instance
        .collection('users').doc(_myUid).get();
    final myData = myDoc.data() ?? {};

    final groupRef = await FirebaseFirestore.instance
        .collection('groups').add({
      'name':        name,
      'icon':        icon,
      'bio':         bio.isEmpty ? 'A new squad. Let\'s grind.' : bio,
      'access':      isOpen ? 'open' : 'invite',
      'memberLimit': limit,
      'memberCount': 1,
      'memberIds':   [_myUid],
      'ownerId':     _myUid,
      'inviteCode':  code,
      'createdAt':   FieldValue.serverTimestamp(),
    });

    await groupRef.collection('members').doc(_myUid).set({
      'name':         (_myName?.isNotEmpty == true) ? _myName : 'Anonymous',
      'avatar':       _myAvatar,
      'avatarUrl':    _myAvatarUrl    ?? '',
      'avatarBase64': _myAvatarBase64 ?? '',
      'totalMinutes': myData['totalMinutes'] ?? 0,
      'xp':           myData['xp']           ?? 0,
      'streak':       myData['streak']        ?? 0,
      'bio':          myData['bio']           ?? '',
      'joinedAt':     FieldValue.serverTimestamp(),
    });

    _loadGroups();
  }

  // FIX: profile dialog for any member
  void _showMemberProfile(_Member m, AppColors c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(c.radius)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(mainAxisSize: MainAxisSize.min, children: [

          _networkAvatar(m.avatarUrl, m.avatar, 72, 22, c, base64: m.avatarBase64),
          const SizedBox(height: 12),

          Text(m.name, style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900,
            color: c.text, fontFamily: c.fontFamily)),
          const SizedBox(height: 4),

          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: c.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: c.accent.withOpacity(0.3))),
            child: Text(_title(m.totalHours), style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: c.accent, letterSpacing: 0.8))),

          if (m.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(m.bio, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.muted)),
          ],
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(c.radiusSm),
              border: Border.all(color: c.border)),
            child: Row(children: [
              _dStat('⚡ XP',    '${m.xp}',                    c),
              _dDivider(c),
              _dStat('🔥 Streak', '${m.streak}d',              c),
              _dDivider(c),
              _dStat('⏱️ Hours',
                  m.totalHours.toStringAsFixed(1), c),
            ])),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: m.rank == 1
                  ? c.gold.withOpacity(0.12)
                  : c.surface2,
              borderRadius: BorderRadius.circular(c.radiusSm),
              border: Border.all(
                color: m.rank == 1
                    ? c.gold.withOpacity(0.4)
                    : c.border)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  m.rank <= 3
                    ? ['🥇','🥈','🥉'][m.rank - 1]
                    : '🏅',
                  style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('SQUAD RANK #${m.rank}',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: m.rank == 1 ? c.gold : c.text,
                    letterSpacing: 0.5)),
              ])),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(
                color: c.accent,
                fontWeight: FontWeight.w800))),
          ),
        ],
      ),
    );
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

  void _showCreateSheet() {
    final c        = AppColors.of(context);
    final nameCtrl = TextEditingController();
    final bioCtrl  = TextEditingController();
    String selIcon = '⚡';
    bool   isOpen  = true;
    int    limit   = 20;

    final icons = ['⚡','🔥','💀','🧠','🏆','👑','🐉','🦁',
                   '🚀','💎','⚔️','🎯','📚','🌙','☀️','🌊'];

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
                    Text('Create a Squad ⚡', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900,
                      color: c.text, fontFamily: c.fontFamily)),
                    const SizedBox(height: 20),

                    Text('SQUAD ICON', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: c.muted, letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8,
                      children: icons.map((ic) {
                        final sel = selIcon == ic;
                        return GestureDetector(
                          onTap: () => setSheet(() => selIcon = ic),
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: sel
                                  ? c.accent.withOpacity(0.15)
                                  : c.surface2,
                              borderRadius: BorderRadius.circular(
                                  c.radiusSm),
                              border: Border.all(
                                color: sel ? c.accent : c.border,
                                width: sel ? 2 : 1)),
                            child: Center(child: Text(ic,
                              style: const TextStyle(
                                  fontSize: 22)))));
                      }).toList()),
                    const SizedBox(height: 16),

                    Text('SQUAD NAME', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: c.muted, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    _textField(nameCtrl,
                        'e.g. A/L Grinders 2026', c),
                    const SizedBox(height: 14),

                    Text('BIO (optional)', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: c.muted, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    _textField(bioCtrl,
                        'What\'s your squad about?', c,
                        maxLines: 2),
                    const SizedBox(height: 14),

                    Text('ACCESS', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: c.muted, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Row(children: [
                      _toggleChip('🌍 Open',   true,  isOpen,
                          (v) => setSheet(() => isOpen = v), c),
                      const SizedBox(width: 8),
                      _toggleChip('🔒 Invite', false, isOpen,
                          (v) => setSheet(() => isOpen = v), c),
                    ]),
                    const SizedBox(height: 14),

                    Text('MEMBER LIMIT: $limit', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: c.muted, letterSpacing: 1.2)),
                    SliderTheme(
                      data: SliderTheme.of(ctx).copyWith(
                        activeTrackColor:   c.accent,
                        inactiveTrackColor: c.surface2,
                        thumbColor:         c.accent,
                        overlayColor: c.accent.withOpacity(0.1)),
                      child: Slider(
                        value: limit.toDouble(),
                        min: 5, max: 50, divisions: 9,
                        onChanged: (v) =>
                            setSheet(() => limit = v.round()))),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty) return;
                          Navigator.pop(ctx);
                          _createGroup(
                            name:   nameCtrl.text.trim(),
                            icon:   selIcon,
                            bio:    bioCtrl.text.trim(),
                            isOpen: isOpen,
                            limit:  limit,
                          );
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
                        child: Text('Create Squad ⚡',
                          style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w800,
                            fontFamily: c.fontFamily)),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showInviteSheet(_Group g) {
    final c    = AppColors.of(context);
    final code = g.inviteCode;
    bool copied = false;

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
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2)))),
            Text('Invite to ${g.name}', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900,
              color: c.text, fontFamily: c.fontFamily)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(c.radiusSm),
                border: Border.all(color: c.border)),
              child: Text('grindmode.app/join/$code',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  fontFamily: c.fontFamily))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                      text: 'grindmode.app/join/$code'));
                  setSheet(() => copied = true);
                  Future.delayed(const Duration(seconds: 2), () {
                    if (ctx.mounted) setSheet(() => copied = false);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: copied ? c.green : c.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(c.radius)),
                  elevation: 0),
                child: Text(copied ? 'COPIED ✓' : 'COPY INVITE LINK',
                  style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: c.fontFamily)),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    final sorted = [..._groups]
      ..sort((a, b) {
        if (a.joined && !b.joined) return -1;
        if (!a.joined && b.joined) return 1;
        return b.memberCount.compareTo(a.memberCount);
      });

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Your Squads ⚡', style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: c.text, fontFamily: c.fontFamily)),
                GestureDetector(
                  onTap: _showCreateSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(
                          c.radiusSm + 4)),
                    child: Text('+ Create', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: c.fontFamily))),
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
              ? Center(child: CircularProgressIndicator(
                  color: c.accent))
              : sorted.isEmpty
                ? _emptyState(c)
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _loadGroups,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          20, 0, 20, 24),
                      itemCount: sorted.length,
                      itemBuilder: (_, i) =>
                          _groupCard(sorted[i], c),
                    ),
                  ),
          ),
        ]),
          ),
          const ThemeDecorationLayer(screen: 'groups'),
        ],
      ),
    );
  }

  Widget _groupCard(_Group g, AppColors c) {
    final isOwner = g.ownerId == _myUid;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(c.radius),
        border: Border.all(
          color: g.joined
              ? c.accent.withOpacity(0.4)
              : c.border,
          width: g.joined ? 1.5 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: c.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(c.radiusSm)),
              child: Center(child: Text(g.icon,
                  style: const TextStyle(fontSize: 24)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(g.name, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900,
                    color: c.text, fontFamily: c.fontFamily),
                    overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 6),
                  if (isOwner) _pill('👑 Owner', c.gold, c),
                  if (g.joined && !isOwner)
                    _pill('✓ Joined', c.green, c),
                ]),
                const SizedBox(height: 2),
                Text(
                  '${g.isOpen ? "🌍 Open" : "🔒 Invite"} · ${g.memberCount}/${g.memberLimit} members',
                  style: TextStyle(fontSize: 10,
                    color: c.muted,
                    fontWeight: FontWeight.w600)),
              ])),
            if (g.joined)
              GestureDetector(
                onTap: () => _showInviteSheet(g),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(c.radiusSm),
                    border: Border.all(color: c.border)),
                  child: Text('INVITE', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: c.muted)))),
          ])),

        if (g.bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(g.bio, style: TextStyle(
              fontSize: 12, color: c.muted,
              fontWeight: FontWeight.w500))),

        if (g.members.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text('⚡ GROUP RANKINGS', style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: c.muted, letterSpacing: 1.1))),
          // FIX: tap member row to see profile
          ...g.members.map((m) => GestureDetector(
            onTap: () => _showMemberProfile(m, c),
            child: _memberRow(m, c))),
        ],

        if (!g.joined) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _joinGroup(g),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          c.radiusSm)),
                  elevation: 0),
                child: Text('+ JOIN SQUAD', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  fontFamily: c.fontFamily)),
              ),
            ),
          ),
        ] else
          const SizedBox(height: 14),
      ]),
    );
  }

  Widget _memberRow(_Member m, AppColors c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: m.isMe
            ? c.accent.withOpacity(0.08)
            : c.surface2,
        borderRadius: BorderRadius.circular(c.radiusSm),
        border: Border.all(
          color: m.isMe
              ? c.accent.withOpacity(0.3)
              : Colors.transparent)),
      child: Row(children: [
        SizedBox(width: 24, child: Text('#${m.rank}',
          style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w800,
            color: m.rank == 1 ? c.gold : c.muted))),
         _networkAvatar(m.avatarUrl, m.avatar, 32, 18, c, base64: m.avatarBase64),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(child: Text(m.name, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800,
                color: c.text, fontFamily: c.fontFamily),
                overflow: TextOverflow.ellipsis)),
              if (m.isMe) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(3)),
                  child: const Text('YOU', style: TextStyle(
                    fontSize: 7, fontWeight: FontWeight.w900,
                    color: Colors.white))),
              ],
            ]),
            Text('🔥 ${m.streak}d streak',
              style: TextStyle(fontSize: 9, color: c.muted)),
          ])),
        Row(children: [
          Text('${m.totalHours.toStringAsFixed(1)}h',
            style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w900,
              color: c.text, fontFamily: c.fontFamily)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 14, color: c.muted),
        ]),
      ]),
    );
  }

  // ── Shared avatar widget ──
  Widget _networkAvatar(
    String url, String emoji,
    double size, double fontSize,
    AppColors c, {
    Color?  bgColor,
    Color?  borderColor,
    double? borderRadius,
    String  base64 = '',
  }) {
    final br = borderRadius ?? (size / 4);
    final bg = bgColor     ?? c.surface2;
    final bc = borderColor ?? c.border;

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

  Widget _emptyState(AppColors c) {
    return RefreshIndicator(
      color: c.accent,
      onRefresh: _loadGroups,
      child: ListView(
        padding: const EdgeInsets.all(40),
        children: [
          Center(child: Column(children: [
            const Text('⚡', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No squads yet', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900,
              color: c.text, fontFamily: c.fontFamily)),
            const SizedBox(height: 8),
            Text('Create one or check back later.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.muted)),
          ])),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color, AppColors c) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4))),
      child: Text(label, style: TextStyle(
        fontSize: 8, fontWeight: FontWeight.w800, color: color)));

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

  Widget _toggleChip(String label, bool val, bool current,
      ValueChanged<bool> onTap, AppColors c) {
    final active = val == current;
    return GestureDetector(
      onTap: () => onTap(val),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface2,
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

// ── Data classes ──
class _Group {
  final String id, name, icon, bio, inviteCode, ownerId;
  final bool   isOpen, joined;
  final int    memberCount, memberLimit;
  final List<_Member> members;
  const _Group({
    required this.id,          required this.name,
    required this.icon,        required this.bio,
    required this.isOpen,      required this.joined,
    required this.memberCount, required this.memberLimit,
    required this.inviteCode,  required this.ownerId,
    required this.members,
  });
}

class _Member {
  final String uid, name, avatar, avatarUrl, avatarBase64, bio;
  final double totalHours;
  final int    streak, rank, xp;
  final bool   isMe;
  const _Member({
    required this.uid,          required this.name,
    required this.avatar,       required this.avatarUrl,
    required this.avatarBase64, required this.bio,
    required this.totalHours,
    required this.streak,    required this.rank,
    required this.xp,        required this.isMe,
  });
}