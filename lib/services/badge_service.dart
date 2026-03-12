import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GrindBadge {
  final String id;
  final String category;
  final String emoji;
  final String name;
  final String desc;
  final bool unlocked;

  const GrindBadge({
    required this.id,
    required this.category,
    required this.emoji,
    required this.name,
    required this.desc,
    this.unlocked = false,
  });

  GrindBadge copyWith({bool? unlocked}) => GrindBadge(
    id: id, category: category, emoji: emoji,
    name: name, desc: desc,
    unlocked: unlocked ?? this.unlocked,
  );
}

class BadgeService {

  static const List<GrindBadge> allBadges = [
    // ── STUDY TIME
    GrindBadge(id: 'time_30m',  category: 'time', emoji: '⏱️', name: 'First Step',        desc: 'Study for 30 minutes total'),
    GrindBadge(id: 'time_1h',   category: 'time', emoji: '🕐', name: 'One Hour In',        desc: 'Reach 1 hour of total study time'),
    GrindBadge(id: 'time_5h',   category: 'time', emoji: '📚', name: 'Getting Serious',    desc: 'Reach 5 hours of total study time'),
    GrindBadge(id: 'time_10h',  category: 'time', emoji: '🔥', name: 'Grind Mode',         desc: 'Reach 10 hours of total study time'),
    GrindBadge(id: 'time_25h',  category: 'time', emoji: '💪', name: 'The Grinder',        desc: 'Reach 25 hours of total study time'),
    GrindBadge(id: 'time_50h',  category: 'time', emoji: '⚡', name: 'Elite Student',      desc: 'Reach 50 hours of total study time'),
    GrindBadge(id: 'time_100h', category: 'time', emoji: '🏆', name: 'Century Grinder',    desc: 'Reach 100 hours of total study time'),
    GrindBadge(id: 'time_200h', category: 'time', emoji: '💀', name: 'No Life. All Study.',desc: '200 hours. You\'re unwell. We respect it.'),
    GrindBadge(id: 'time_500h', category: 'time', emoji: '👑', name: 'THE LEGEND',         desc: '500 hours. Actual legend status.'),
    // ── STREAKS
    GrindBadge(id: 'streak_3',   category: 'streak', emoji: '🌱', name: 'Showing Up',      desc: '3 day streak — consistency begins'),
    GrindBadge(id: 'streak_7',   category: 'streak', emoji: '🔥', name: 'Week Warrior',    desc: '7 day streak — full week grind'),
    GrindBadge(id: 'streak_14',  category: 'streak', emoji: '💥', name: 'Two Week Terror', desc: '14 day streak — they see you working'),
    GrindBadge(id: 'streak_21',  category: 'streak', emoji: '🧠', name: 'Habit Locked',    desc: '21 days — it\'s a habit now'),
    GrindBadge(id: 'streak_30',  category: 'streak', emoji: '🌙', name: 'Month of Pain',   desc: '30 day streak — a full month'),
    GrindBadge(id: 'streak_60',  category: 'streak', emoji: '⚔️', name: 'Iron Discipline', desc: '60 day streak — seriously?'),
    GrindBadge(id: 'streak_100', category: 'streak', emoji: '👑', name: '100 Day Beast',   desc: '100 days straight. Certified grinder.'),
    // ── SESSIONS
    GrindBadge(id: 'sess_1',   category: 'sessions', emoji: '🍅', name: 'First Pomo',      desc: 'Complete your first focus session'),
    GrindBadge(id: 'sess_5',   category: 'sessions', emoji: '🎯', name: 'Finding the Zone',desc: 'Complete 5 focus sessions'),
    GrindBadge(id: 'sess_10',  category: 'sessions', emoji: '📖', name: 'Study Machine',   desc: 'Complete 10 focus sessions'),
    GrindBadge(id: 'sess_25',  category: 'sessions', emoji: '🚀', name: 'On a Roll',       desc: 'Complete 25 focus sessions'),
    GrindBadge(id: 'sess_50',  category: 'sessions', emoji: '💎', name: 'Diamond Focus',   desc: 'Complete 50 focus sessions'),
    GrindBadge(id: 'sess_100', category: 'sessions', emoji: '🔱', name: 'Centurion',       desc: '100 sessions. Absolute weapon.'),
    GrindBadge(id: 'sess_250', category: 'sessions', emoji: '🌌', name: 'Beyond Limits',   desc: '250 sessions. You\'ve ascended.'),
    GrindBadge(id: 'sess_500', category: 'sessions', emoji: '💀', name: 'No Days Off',     desc: '500 sessions. Seek help. Also congrats.'),
    // ── MASTERY
    GrindBadge(id: 'subj_1h',   category: 'mastery', emoji: '🔬', name: 'Subject Curious', desc: '1h in a single subject'),
    GrindBadge(id: 'subj_5h',   category: 'mastery', emoji: '📐', name: 'Subject Focused', desc: '5h in a single subject'),
    GrindBadge(id: 'subj_10h',  category: 'mastery', emoji: '🧪', name: 'Subject Serious', desc: '10h in a single subject'),
    GrindBadge(id: 'subj_25h',  category: 'mastery', emoji: '🎓', name: 'Subject Master',  desc: '25h in a single subject'),
    GrindBadge(id: 'subj_50h',  category: 'mastery', emoji: '🏅', name: 'Subject Expert',  desc: '50h in a single subject'),
    GrindBadge(id: 'subj_100h', category: 'mastery', emoji: '🧬', name: 'Specialist',      desc: '100h in one subject. A/L ready.'),
    // ── SPECIAL
    GrindBadge(id: 'special_night',   category: 'special', emoji: '🌙', name: 'Night Owl',       desc: 'Study after midnight'),
    GrindBadge(id: 'special_early',   category: 'special', emoji: '🌅', name: 'Early Bird',      desc: 'Study before 6am'),
    GrindBadge(id: 'special_weekend', category: 'special', emoji: '📅', name: 'Weekend Warrior', desc: 'Study on both Saturday and Sunday'),
    GrindBadge(id: 'special_rank1',   category: 'special', emoji: '🥇', name: 'Number One',      desc: 'Reach #1 on the leaderboard'),
    GrindBadge(id: 'special_top10',   category: 'special', emoji: '🏆', name: 'Top 10',          desc: 'Reach top 10 on the leaderboard'),
  ];

  static Future<List<GrindBadge>> checkAndAward({
    required int totalMins,
    required int streak,
    required int sessionCount,
    required Map<String, int> subjectMins,
    required int rank,
    required int currentHour,
    required bool studiedOnWeekend,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final userDoc = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    final data = userDoc.data() ?? {};
    final List<String> unlockedIds =
        List<String>.from(data['unlockedBadges'] ?? []);

    final newlyUnlocked = <String>[];
    final totalHours = totalMins / 60;
    final maxSubjMins = subjectMins.values.isEmpty
        ? 0
        : subjectMins.values.reduce((a, b) => a > b ? a : b);
    final maxSubjHours = maxSubjMins / 60;

    for (final badge in allBadges) {
      if (unlockedIds.contains(badge.id)) continue;
      bool earned = false;
      switch (badge.id) {
        case 'time_30m':  earned = totalMins >= 30; break;
        case 'time_1h':   earned = totalHours >= 1; break;
        case 'time_5h':   earned = totalHours >= 5; break;
        case 'time_10h':  earned = totalHours >= 10; break;
        case 'time_25h':  earned = totalHours >= 25; break;
        case 'time_50h':  earned = totalHours >= 50; break;
        case 'time_100h': earned = totalHours >= 100; break;
        case 'time_200h': earned = totalHours >= 200; break;
        case 'time_500h': earned = totalHours >= 500; break;
        case 'streak_3':   earned = streak >= 3; break;
        case 'streak_7':   earned = streak >= 7; break;
        case 'streak_14':  earned = streak >= 14; break;
        case 'streak_21':  earned = streak >= 21; break;
        case 'streak_30':  earned = streak >= 30; break;
        case 'streak_60':  earned = streak >= 60; break;
        case 'streak_100': earned = streak >= 100; break;
        case 'sess_1':   earned = sessionCount >= 1; break;
        case 'sess_5':   earned = sessionCount >= 5; break;
        case 'sess_10':  earned = sessionCount >= 10; break;
        case 'sess_25':  earned = sessionCount >= 25; break;
        case 'sess_50':  earned = sessionCount >= 50; break;
        case 'sess_100': earned = sessionCount >= 100; break;
        case 'sess_250': earned = sessionCount >= 250; break;
        case 'sess_500': earned = sessionCount >= 500; break;
        case 'subj_1h':   earned = maxSubjHours >= 1; break;
        case 'subj_5h':   earned = maxSubjHours >= 5; break;
        case 'subj_10h':  earned = maxSubjHours >= 10; break;
        case 'subj_25h':  earned = maxSubjHours >= 25; break;
        case 'subj_50h':  earned = maxSubjHours >= 50; break;
        case 'subj_100h': earned = maxSubjHours >= 100; break;
        case 'special_night':   earned = currentHour >= 0 && currentHour < 4; break;
        case 'special_early':   earned = currentHour >= 4 && currentHour < 6; break;
        case 'special_weekend': earned = studiedOnWeekend; break;
        case 'special_rank1':   earned = rank == 1; break;
        case 'special_top10':   earned = rank > 0 && rank <= 10; break;
      }
      if (earned) newlyUnlocked.add(badge.id);
    }

    if (newlyUnlocked.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users').doc(uid).update({
        'unlockedBadges': FieldValue.arrayUnion(newlyUnlocked),
      });
    }

    final allUnlocked = {...unlockedIds, ...newlyUnlocked};
    return allBadges.map((b) =>
        b.copyWith(unlocked: allUnlocked.contains(b.id))).toList();
  }

  static Future<List<GrindBadge>> loadBadges() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return allBadges;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    final List<String> unlockedIds =
        List<String>.from(doc.data()?['unlockedBadges'] ?? []);
    return allBadges.map((b) =>
        b.copyWith(unlocked: unlockedIds.contains(b.id))).toList();
  }
}