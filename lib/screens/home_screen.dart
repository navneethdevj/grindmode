import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'focus_screen.dart';
import 'leaderboard_screen.dart';
import 'groups_screen.dart';
import 'report_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    FocusScreen(),
    LeaderboardScreen(),
    GroupsScreen(),
    ReportScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    if (!doc.exists || !mounted) return;
    final savedTheme = doc.data()?['theme'] as String? ?? 'default';

    // Map onboarding theme ids → GrindTheme
    final map = {
      'clean':   GrindTheme.defaultBlue,
      'default': GrindTheme.defaultBlue,
      'soft':    GrindTheme.soft,
      'minimal': GrindTheme.minimal,
      'forest':  GrindTheme.forest,
      'f1':      GrindTheme.f1,
      'manga':   GrindTheme.manga,
      'anime':   GrindTheme.anime,
      'serene':  GrindTheme.nature,
      'arcade':  GrindTheme.arcade,
    };

    final theme = map[savedTheme] ?? GrindTheme.defaultBlue;
    if (mounted) GrindThemeRoot.changeTheme(context, theme);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: c.accent,
          unselectedItemColor: c.muted,
          selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 11, fontFamily: 'Nunito'),
          unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 11, fontFamily: 'Nunito'),
          items: const [
            BottomNavigationBarItem(
                icon: Text('⚡', style: TextStyle(fontSize: 22)), label: 'Focus'),
            BottomNavigationBarItem(
                icon: Text('🏆', style: TextStyle(fontSize: 22)), label: 'Ranks'),
            BottomNavigationBarItem(
                icon: Text('👥', style: TextStyle(fontSize: 22)), label: 'Groups'),
            BottomNavigationBarItem(
                icon: Text('📊', style: TextStyle(fontSize: 22)), label: 'Report'),
            BottomNavigationBarItem(
                icon: Text('👤', style: TextStyle(fontSize: 22)), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}