import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  GRINDMODE THEME SYSTEM
// ─────────────────────────────────────────────

enum GrindTheme {
  defaultBlue, soft, minimal, forest, f1, manga, anime, nature, arcade,
}

extension GrindThemeInfo on GrindTheme {
  String get displayName {
    switch (this) {
      case GrindTheme.defaultBlue: return 'Default';
      case GrindTheme.soft:        return 'Soft';
      case GrindTheme.minimal:     return 'Minimal';
      case GrindTheme.forest:      return 'Forest';
      case GrindTheme.f1:          return 'F1';
      case GrindTheme.manga:       return 'Manga';
      case GrindTheme.anime:       return 'Anime';
      case GrindTheme.nature:      return 'Nature';
      case GrindTheme.arcade:      return 'Arcade';
    }
  }

  String get emoji {
    switch (this) {
      case GrindTheme.defaultBlue: return '🔵';
      case GrindTheme.soft:        return '🍑';
      case GrindTheme.minimal:     return '🖤';
      case GrindTheme.forest:      return '🌲';
      case GrindTheme.f1:          return '🏎️';
      case GrindTheme.manga:       return '📖';
      case GrindTheme.anime:       return '🌸';
      case GrindTheme.nature:      return '🍃';
      case GrindTheme.arcade:      return '🕹️';
    }
  }

  String get firestoreKey {
    switch (this) {
      case GrindTheme.defaultBlue: return 'default';
      case GrindTheme.soft:        return 'soft';
      case GrindTheme.minimal:     return 'minimal';
      case GrindTheme.forest:      return 'forest';
      case GrindTheme.f1:          return 'f1';
      case GrindTheme.manga:       return 'manga';
      case GrindTheme.anime:       return 'anime';
      case GrindTheme.nature:      return 'nature';
      case GrindTheme.arcade:      return 'arcade';
    }
  }

  static GrindTheme fromKey(String key) {
    return GrindTheme.values.firstWhere(
      (t) => t.firestoreKey == key,
      orElse: () => GrindTheme.defaultBlue,
    );
  }
}

// ─────────────────────────────────────────────
//  AppColors — single source of truth for ALL colors
// ─────────────────────────────────────────────

class AppColors {
  final Color bg, surface, surface2, border;
  final Color accent, accent2, gold, green, purple, orange, red;
  final Color text, muted, card;
  final double radius, radiusSm;
  final String fontFamily, fontBody;
  final bool isDark;

  const AppColors({
    required this.bg, required this.surface, required this.surface2,
    required this.border, required this.accent, required this.accent2,
    required this.gold, required this.green, required this.purple,
    required this.orange, required this.red, required this.text,
    required this.muted, required this.card,
    required this.radius, required this.radiusSm,
    required this.fontFamily, required this.fontBody, required this.isDark,
  });

  static AppColors of(BuildContext context) {
    final p = context.dependOnInheritedWidgetOfExactType<GrindThemeProvider>();
    return p?.colors ?? forTheme(GrindTheme.defaultBlue);
  }

  static AppColors forTheme(GrindTheme t) =>
      _themes[t] ?? _themes[GrindTheme.defaultBlue]!;
// ── Legacy static shortcuts (keeps old screens working) ──
  static const Color bgLight       = Color(0xFFF0F4FF);
  static const Color surfaceLight  = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0xFFE8EEFF);
  static const Color borderLight   = Color(0xFFD0D8F0);
  static const Color textLight     = Color(0xFF1E2340);
  static const Color mutedLight    = Color(0xFF8892B0);
  static const Color staticAccent  = Color(0xFF5B8DEE);
  static const Color staticRed     = Color(0xFFE84040);
  static const Map<GrindTheme, AppColors> _themes = {

    GrindTheme.defaultBlue: AppColors(
      bg: Color(0xFFF0F4FF), surface: Color(0xFFFFFFFF), surface2: Color(0xFFE8EEFF),
      border: Color(0xFFD0D8F0), accent: Color(0xFF5B8DEE), accent2: Color(0xFFE8744A),
      gold: Color(0xFFF0A500), green: Color(0xFF34C77B), purple: Color(0xFF8B6CF6),
      orange: Color(0xFFF07832), red: Color(0xFFE84040),
      text: Color(0xFF1E2340), muted: Color(0xFF8892B0), card: Color(0xFFFFFFFF),
      radius: 14, radiusSm: 10, fontFamily: 'Nunito', fontBody: 'Nunito', isDark: false,
    ),

    GrindTheme.soft: AppColors(
      bg: Color(0xFFFDF6F0), surface: Color(0xFFFFF8F3), surface2: Color(0xFFFFF0E8),
      border: Color(0xFFF0DDD0), accent: Color(0xFFE8744A), accent2: Color(0xFFD94F6E),
      gold: Color(0xFFC8962A), green: Color(0xFF4CAF86), purple: Color(0xFF9B7FC8),
      orange: Color(0xFFE8944A), red: Color(0xFFD94F6E),
      text: Color(0xFF3A2820), muted: Color(0xFFB89080), card: Color(0xFFFFF8F3),
      radius: 18, radiusSm: 12, fontFamily: 'Nunito', fontBody: 'Nunito', isDark: false,
    ),

    GrindTheme.minimal: AppColors(
      bg: Color(0xFFF9F9F7), surface: Color(0xFFFFFFFF), surface2: Color(0xFFF2F2F0),
      border: Color(0xFFE0E0DC), accent: Color(0xFF1A1A1A), accent2: Color(0xFFE63946),
      gold: Color(0xFFB5871A), green: Color(0xFF2D7A4F), purple: Color(0xFF5A4FCF),
      orange: Color(0xFFD4621A), red: Color(0xFFE63946),
      text: Color(0xFF1A1A1A), muted: Color(0xFF888880), card: Color(0xFFFFFFFF),
      radius: 4, radiusSm: 3, fontFamily: 'Nunito', fontBody: 'Nunito', isDark: false,
    ),

    GrindTheme.forest: AppColors(
      bg: Color(0xFF0D1A0F), surface: Color(0xFF111F13), surface2: Color(0xFF162819),
      border: Color(0xFF1E3A22), accent: Color(0xFF5DDB6F), accent2: Color(0xFFF4A738),
      gold: Color(0xFFF4C842), green: Color(0xFF5DDB6F), purple: Color(0xFF88C86E),
      orange: Color(0xFFF4A738), red: Color(0xFFF4A738),
      text: Color(0xFFD4F0D8), muted: Color(0xFF4A7A52), card: Color(0xFF0A150C),
      radius: 4, radiusSm: 3, fontFamily: 'Nunito', fontBody: 'Nunito', isDark: true,
    ),

    GrindTheme.f1: AppColors(
      bg: Color(0xFF080402), surface: Color(0xFF100806), surface2: Color(0xFF180C08),
      border: Color(0xFF2A1208), accent: Color(0xFFE8001A), accent2: Color(0xFFFFD700),
      gold: Color(0xFFFFD700), green: Color(0xFF00CC44), purple: Color(0xFFDD44FF),
      orange: Color(0xFFFF6600), red: Color(0xFFE8001A),
      text: Color(0xFFF0E8E0), muted: Color(0xFF6A4030), card: Color(0xFF0C0604),
      radius: 2, radiusSm: 1, fontFamily: 'Nunito', fontBody: 'Nunito', isDark: true,
    ),

    GrindTheme.manga: AppColors(
      bg: Color(0xFFEAF5FF), surface: Color(0xFFFFFFFF), surface2: Color(0xFFD8EEFF),
      border: Color(0xFFB0D4F8), accent: Color(0xFF3A8FFF), accent2: Color(0xFFFF6EB4),
      gold: Color(0xFFFFAA00), green: Color(0xFF44CC88), purple: Color(0xFFAA6EFF),
      orange: Color(0xFFFF8844), red: Color(0xFFFF4488),
      text: Color(0xFF1A2A4A), muted: Color(0xFF7A9ABB), card: Color(0xFFFFFFFF),
      radius: 22, radiusSm: 14, fontFamily: 'Nunito', fontBody: 'Nunito', isDark: false,
    ),

    GrindTheme.anime: AppColors(
      bg: Color(0xFFF8EEFF), surface: Color(0xFFFFFFFF), surface2: Color(0xFFF0DDFF),
      border: Color(0xFFDDB8F8), accent: Color(0xFFAA44FF), accent2: Color(0xFFFF6EB4),
      gold: Color(0xFFFFAA44), green: Color(0xFF66DDAA), purple: Color(0xFFAA44FF),
      orange: Color(0xFFFF8855), red: Color(0xFFFF4499),
      text: Color(0xFF2A1A3A), muted: Color(0xFF9A7ABB), card: Color(0xFFFFFFFF),
      radius: 20, radiusSm: 12, fontFamily: 'Nunito', fontBody: 'Nunito', isDark: false,
    ),

    GrindTheme.nature: AppColors(
      bg: Color(0xFFF0F6EA), surface: Color(0xFFFFFFFF), surface2: Color(0xFFE4F0DA),
      border: Color(0xFFC0D8A8), accent: Color(0xFF4A8C3A), accent2: Color(0xFFE88C30),
      gold: Color(0xFFD4A820), green: Color(0xFF4A8C3A), purple: Color(0xFF7A6A9A),
      orange: Color(0xFFE88C30), red: Color(0xFFCC4444),
      text: Color(0xFF2A3A22), muted: Color(0xFF7A9A6A), card: Color(0xFFFFFFFF),
      radius: 16, radiusSm: 10, fontFamily: 'Nunito', fontBody: 'Nunito', isDark: false,
    ),

    GrindTheme.arcade: AppColors(
      bg: Color(0xFF0A0015), surface: Color(0xFF110022), surface2: Color(0xFF1A0033),
      border: Color(0xFF330066), accent: Color(0xFF00FF41), accent2: Color(0xFFFF00FF),
      gold: Color(0xFFFFFF00), green: Color(0xFF00FF41), purple: Color(0xFFFF00FF),
      orange: Color(0xFFFF8800), red: Color(0xFFFF0044),
      text: Color(0xFFE0FFE0), muted: Color(0xFF446644), card: Color(0xFF080012),
      radius: 3, radiusSm: 2, fontFamily: 'Nunito', fontBody: 'Nunito', isDark: true,
    ),
  };
}

// ─────────────────────────────────────────────
//  Theme Provider (passes theme down the widget tree)
// ─────────────────────────────────────────────

class GrindThemeProvider extends InheritedWidget {
  final AppColors colors;
  final GrindTheme theme;
  final ValueChanged<GrindTheme> onThemeChanged;

  const GrindThemeProvider({
    super.key,
    required this.colors,
    required this.theme,
    required this.onThemeChanged,
    required super.child,
  });

  @override
  bool updateShouldNotify(GrindThemeProvider old) => old.theme != theme;

  static GrindThemeProvider? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GrindThemeProvider>();
}

// ─────────────────────────────────────────────
//  GrindThemeRoot — wrap your app in this once
// ─────────────────────────────────────────────

class GrindThemeRoot extends StatefulWidget {
  final Widget child;
  final GrindTheme initialTheme;

  const GrindThemeRoot({
    super.key,
    required this.child,
    this.initialTheme = GrindTheme.defaultBlue,
  });

  @override
  State<GrindThemeRoot> createState() => _GrindThemeRootState();

  static void changeTheme(BuildContext context, GrindTheme theme) {
    GrindThemeProvider.maybeOf(context)?.onThemeChanged(theme);
  }
}

class _GrindThemeRootState extends State<GrindThemeRoot> {
  late GrindTheme _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialTheme;
  }

  void _setTheme(GrindTheme t) => setState(() => _current = t);

  @override
  Widget build(BuildContext context) {
    return GrindThemeProvider(
      colors: AppColors.forTheme(_current),
      theme: _current,
      onThemeChanged: _setTheme,
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────
//  ThemePickerSheet — use this in Profile screen
//  Call: showModalBottomSheet(context: context,
//          builder: (_) => const ThemePickerSheet());
// ─────────────────────────────────────────────

class ThemePickerSheet extends StatelessWidget {
  const ThemePickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = GrindThemeProvider.maybeOf(context);
    final current = provider?.theme ?? GrindTheme.defaultBlue;
    final c = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          Text('CHOOSE THEME', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800,
            color: c.muted, letterSpacing: 1.5, fontFamily: c.fontFamily,
          )),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: GrindTheme.values.map((t) {
              final tc = AppColors.forTheme(t);
              final isSelected = t == current;
              return GestureDetector(
                onTap: () {
                  provider?.onThemeChanged(t);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? tc.accent : tc.surface2,
                    borderRadius: BorderRadius.circular(tc.radius),
                    border: Border.all(
                      color: isSelected ? tc.accent : tc.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(t.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(t.displayName, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : tc.text,
                      fontFamily: tc.fontFamily,
                    )),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}