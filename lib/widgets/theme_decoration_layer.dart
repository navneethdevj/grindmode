import 'package:flutter/material.dart';
import 'dart:math';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────
//  ThemeDecorationLayer
//  Drop this inside a Stack, as the LAST child
//  so it sits on top of the background but
//  behind your UI cards (use IgnorePointer so
//  taps pass through).
//
//  Usage:
//    Stack(children: [
//      YourScreenContent(),
//      const ThemeDecorationLayer(screen: 'focus'),
//    ])
// ─────────────────────────────────────────────

class ThemeDecorationLayer extends StatefulWidget {
  /// 'focus' or 'profile'
  final String screen;
  const ThemeDecorationLayer({super.key, required this.screen});

  @override
  State<ThemeDecorationLayer> createState() => _ThemeDecorationLayerState();
}

class _ThemeDecorationLayerState extends State<ThemeDecorationLayer>
    with TickerProviderStateMixin {

  // ── Shared rng ──
  final _rng = Random();

  // ── Nature: falling leaves ──
  late List<_Leaf> _leaves;
  late AnimationController _leafCtrl;

  // ── F1: speed lines ──
  late List<_SpeedLine> _lines;
  late AnimationController _lineCtrl;

  // ── Manga: floating kanji ──
  late List<_Kanji> _kanjis;
  late AnimationController _kanjiCtrl;

  // ── Anime: hearts & sparkles ──
  late List<_Particle> _particles;
  late AnimationController _particleCtrl;

  // ── Arcade: neon dots ──
  late List<_NeonDot> _dots;
  late AnimationController _dotCtrl;

  GrindTheme _currentTheme = GrindTheme.defaultBlue;

  @override
  void initState() {
    super.initState();
    _initNature();
    _initF1();
    _initManga();
    _initAnime();
    _initArcade();
  }

  // ── Nature ──
  void _initNature() {
    _leaves = List.generate(12, (_) => _Leaf(rng: _rng));
    _leafCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _leafCtrl.addListener(() {
      if (_currentTheme == GrindTheme.nature && mounted) {
        setState(() {
          for (final leaf in _leaves) leaf.update();
        });
      }
    });
  }

  // ── F1 ──
  void _initF1() {
    _lines = List.generate(8, (_) => _SpeedLine(rng: _rng));
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
    _lineCtrl.addListener(() {
      if (_currentTheme == GrindTheme.f1 && mounted) {
        setState(() {
          for (final line in _lines) line.update();
        });
      }
    });
  }

  // ── Manga ──
  void _initManga() {
    _kanjis = List.generate(10, (_) => _Kanji(rng: _rng));
    _kanjiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _kanjiCtrl.addListener(() {
      if (_currentTheme == GrindTheme.manga && mounted) {
        setState(() {
          for (final k in _kanjis) k.update();
        });
      }
    });
  }

  // ── Anime ──
  void _initAnime() {
    _particles = List.generate(14, (_) => _Particle(rng: _rng));
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    _particleCtrl.addListener(() {
      if (_currentTheme == GrindTheme.anime && mounted) {
        setState(() {
          for (final p in _particles) p.update();
        });
      }
    });
  }

  // ── Arcade ──
  void _initArcade() {
    _dots = List.generate(20, (_) => _NeonDot(rng: _rng));
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();
    _dotCtrl.addListener(() {
      if (_currentTheme == GrindTheme.arcade && mounted) {
        setState(() {
          for (final d in _dots) d.update();
        });
      }
    });
  }

  @override
  void dispose() {
    _leafCtrl.dispose();
    _lineCtrl.dispose();
    _kanjiCtrl.dispose();
    _particleCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = GrindThemeProvider.maybeOf(context);
    _currentTheme  = provider?.theme ?? GrindTheme.defaultBlue;

    // Only render for the 5 themed screens
    final hasDecor = [
      GrindTheme.nature, GrindTheme.f1, GrindTheme.manga,
      GrindTheme.anime,  GrindTheme.arcade,
    ].contains(_currentTheme);

    if (!hasDecor) return const SizedBox.shrink();

    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(children: [
          // ── Animations ──
          if (_currentTheme == GrindTheme.nature)   _buildNatureAnim(context),
          if (_currentTheme == GrindTheme.f1)       _buildF1Anim(context),
          if (_currentTheme == GrindTheme.manga)    _buildMangaAnim(context),
          if (_currentTheme == GrindTheme.anime)    _buildAnimeAnim(context),
          if (_currentTheme == GrindTheme.arcade)   _buildArcadeAnim(context),
          // ── Character / scenery image ──
          _buildImage(context),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  IMAGE OVERLAY
  // ─────────────────────────────────────────────
  Widget _buildImage(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final isCenter = _currentTheme == GrindTheme.nature ||
        (_currentTheme == GrindTheme.arcade && widget.screen == 'profile');

    String asset;
    // Only show images on focus and profile screens
    if (widget.screen != 'focus' && widget.screen != 'profile') {
      return const SizedBox.shrink();
    }

    switch (_currentTheme) {
      case GrindTheme.f1:
        asset = widget.screen == 'focus'
            ? 'assets/images/f1_1.png'
            : 'assets/images/f1_2.png';
      case GrindTheme.manga:
        asset = widget.screen == 'focus'
            ? 'assets/images/manga_1.png'
            : 'assets/images/manga_2.png';
      case GrindTheme.anime:
        asset = widget.screen == 'focus'
            ? 'assets/images/anime_1.png'
            : 'assets/images/anime_2.png';
      case GrindTheme.nature:
        asset = widget.screen == 'focus'
            ? 'assets/images/nature_1.png'
            : 'assets/images/nature_2.png';
      case GrindTheme.arcade:
        asset = widget.screen == 'focus'
            ? 'assets/images/arcade_1.png'
            : 'assets/images/arcade_2.png';
      default:
        return const SizedBox.shrink();
    }

    final imgWidth = size.width * 0.36;

    return Positioned(
      bottom: 0,
      right: isCenter ? null : 0,
      left:  isCenter ? (size.width / 2) - (imgWidth / 2) : null,
      child: Opacity(
        opacity: 0.82,
        child: Image.asset(
          asset,
          width: imgWidth,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  NATURE — falling leaves
  // ─────────────────────────────────────────────
  Widget _buildNatureAnim(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return CustomPaint(
      size: size,
      painter: _LeavesPainter(_leaves),
    );
  }

  // ─────────────────────────────────────────────
  //  F1 — speed lines
  // ─────────────────────────────────────────────
  Widget _buildF1Anim(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return CustomPaint(
      size: size,
      painter: _SpeedLinesPainter(_lines),
    );
  }

  // ─────────────────────────────────────────────
  //  MANGA — floating kanji
  // ─────────────────────────────────────────────
  Widget _buildMangaAnim(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return CustomPaint(
      size: size,
      painter: _KanjiPainter(_kanjis),
    );
  }

  // ─────────────────────────────────────────────
  //  ANIME — hearts & sparkles
  // ─────────────────────────────────────────────
  Widget _buildAnimeAnim(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return CustomPaint(
      size: size,
      painter: _ParticlePainter(_particles),
    );
  }

  // ─────────────────────────────────────────────
  //  ARCADE — neon dots
  // ─────────────────────────────────────────────
  Widget _buildArcadeAnim(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return CustomPaint(
      size: size,
      painter: _NeonDotsPainter(_dots),
    );
  }
}

// ═════════════════════════════════════════════
//  DATA CLASSES + PAINTERS
// ═════════════════════════════════════════════

// ── NATURE: Leaf ──
class _Leaf {
  late double x, y, size, speed, wobble, wobbleSpeed, opacity, rotation;
  final Random rng;

  _Leaf({required this.rng}) { _reset(fromTop: false); }

  void _reset({bool fromTop = true}) {
    x          = rng.nextDouble();
    y          = fromTop ? -0.05 : rng.nextDouble();
    size       = 8 + rng.nextDouble() * 10;
    speed      = 0.0008 + rng.nextDouble() * 0.0012;
    wobble     = 0;
    wobbleSpeed = 0.03 + rng.nextDouble() * 0.04;
    opacity    = 0.25 + rng.nextDouble() * 0.35;
    rotation   = rng.nextDouble() * pi * 2;
  }

  void update() {
    y       += speed;
    wobble  += wobbleSpeed;
    x       += sin(wobble) * 0.002;
    rotation += 0.02;
    if (y > 1.05) _reset(fromTop: true);
  }
}

class _LeavesPainter extends CustomPainter {
  final List<_Leaf> leaves;
  _LeavesPainter(this.leaves);

  @override
  void paint(Canvas canvas, Size size) {
    for (final leaf in leaves) {
      final paint = Paint()
        ..color = const Color(0xFF4A8C3A).withOpacity(leaf.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(leaf.x * size.width, leaf.y * size.height);
      canvas.rotate(leaf.rotation);

      // Simple leaf shape
      final path = Path()
        ..moveTo(0, -leaf.size)
        ..cubicTo(leaf.size * 0.6, -leaf.size * 0.6,
            leaf.size * 0.6, leaf.size * 0.2, 0, leaf.size * 0.4)
        ..cubicTo(-leaf.size * 0.6, leaf.size * 0.2,
            -leaf.size * 0.6, -leaf.size * 0.6, 0, -leaf.size);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LeavesPainter old) => true;
}

// ── F1: SpeedLine ──
class _SpeedLine {
  late double x, y, length, speed, opacity, thickness;
  final Random rng;

  _SpeedLine({required this.rng}) { _reset(fromLeft: false); }

  void _reset({bool fromLeft = true}) {
    x         = fromLeft ? -0.3 : rng.nextDouble() * 0.5;
    y         = 0.1 + rng.nextDouble() * 0.8;
    length    = 0.06 + rng.nextDouble() * 0.12;
    speed     = 0.018 + rng.nextDouble() * 0.025;
    opacity   = 0.15 + rng.nextDouble() * 0.25;
    thickness = 1.0 + rng.nextDouble() * 2.0;
  }

  void update() {
    x += speed;
    if (x > 1.2) _reset(fromLeft: true);
  }
}

class _SpeedLinesPainter extends CustomPainter {
  final List<_SpeedLine> lines;
  _SpeedLinesPainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      final paint = Paint()
        ..color = const Color(0xFFE8001A).withOpacity(line.opacity)
        ..strokeWidth = line.thickness
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(line.x * size.width, line.y * size.height),
        Offset((line.x + line.length) * size.width, line.y * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpeedLinesPainter old) => true;
}

// ── MANGA: Kanji ──
const _kanjiChars = ['集中', '勉強', '頑張', '合格', '努力', '天才', '最高', '勝利', '進歩', '知識'];

class _Kanji {
  late double x, y, speed, opacity, size;
  late String char;
  final Random rng;

  _Kanji({required this.rng}) { _reset(fromBottom: false); }

  void _reset({bool fromBottom = true}) {
    x       = 0.05 + rng.nextDouble() * 0.85;
    y       = fromBottom ? 1.05 : rng.nextDouble();
    speed   = 0.0005 + rng.nextDouble() * 0.0008;
    opacity = 0.08 + rng.nextDouble() * 0.14;
    size    = 14 + rng.nextDouble() * 14;
    char    = _kanjiChars[rng.nextInt(_kanjiChars.length)];
  }

  void update() {
    y -= speed;
    if (y < -0.05) _reset(fromBottom: true);
  }
}

class _KanjiPainter extends CustomPainter {
  final List<_Kanji> kanjis;
  _KanjiPainter(this.kanjis);

  @override
  void paint(Canvas canvas, Size size) {
    for (final k in kanjis) {
      final tp = TextPainter(
        text: TextSpan(
          text: k.char,
          style: TextStyle(
            fontSize: k.size,
            color: const Color(0xFF3A8FFF).withOpacity(k.opacity),
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(k.x * size.width, k.y * size.height));
    }
  }

  @override
  bool shouldRepaint(_KanjiPainter old) => true;
}

// ── ANIME: Particle (heart or sparkle) ──
class _Particle {
  late double x, y, size, speed, opacity, scale;
  late bool isHeart;
  late double scaleDir, scaleSpeed;
  final Random rng;

  _Particle({required this.rng}) { _reset(); }

  void _reset() {
    x          = rng.nextDouble();
    y          = rng.nextDouble();
    size       = 10 + rng.nextDouble() * 14;
    speed      = 0.002 + rng.nextDouble() * 0.003;
    opacity    = 0.0;
    scale      = 0.3 + rng.nextDouble() * 0.7;
    scaleDir   = 1;
    scaleSpeed = 0.008 + rng.nextDouble() * 0.012;
    isHeart    = rng.nextBool();
  }

  void update() {
    opacity += speed;
    scale   += scaleDir * scaleSpeed;
    if (scale > 1.3) scaleDir = -1;
    if (scale < 0.2) scaleDir = 1;
    if (opacity > 0.55) opacity = 0.0;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final cx = p.x * size.width;
      final cy = p.y * size.height;
      final s  = p.size * p.scale;

      if (p.isHeart) {
        // Heart shape
        final paint = Paint()
          ..color = const Color(0xFFFF6EB4).withOpacity(p.opacity)
          ..style = PaintingStyle.fill;
        final path = _heartPath(cx, cy, s);
        canvas.drawPath(path, paint);
      } else {
        // Sparkle — 4-point star
        final paint = Paint()
          ..color = const Color(0xFFFFAA44).withOpacity(p.opacity)
          ..style = PaintingStyle.fill;
        _drawSparkle(canvas, paint, cx, cy, s);
      }
    }
  }

  Path _heartPath(double cx, double cy, double size) {
    final s = size * 0.5;
    final path = Path();
    path.moveTo(cx, cy + s * 0.6);
    path.cubicTo(cx - s * 1.4, cy - s * 0.2, cx - s * 1.4, cy - s * 1.2, cx, cy - s * 0.4);
    path.cubicTo(cx + s * 1.4, cy - s * 1.2, cx + s * 1.4, cy - s * 0.2, cx, cy + s * 0.6);
    return path;
  }

  void _drawSparkle(Canvas canvas, Paint paint, double cx, double cy, double size) {
    final s = size * 0.5;
    final path = Path()
      ..moveTo(cx, cy - s)
      ..lineTo(cx + s * 0.2, cy - s * 0.2)
      ..lineTo(cx + s, cy)
      ..lineTo(cx + s * 0.2, cy + s * 0.2)
      ..lineTo(cx, cy + s)
      ..lineTo(cx - s * 0.2, cy + s * 0.2)
      ..lineTo(cx - s, cy)
      ..lineTo(cx - s * 0.2, cy - s * 0.2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// ── ARCADE: NeonDot ──
class _NeonDot {
  late double x, y, size, blinkSpeed, opacity, opacityDir;
  late Color color;
  final Random rng;

  static const _colors = [
    Color(0xFF00FF41), Color(0xFFFF00FF),
    Color(0xFFFFFF00), Color(0xFF00FFFF),
  ];

  _NeonDot({required this.rng}) {
    // Place dots along edges only
    final edge = rng.nextInt(4);
    switch (edge) {
      case 0: x = rng.nextDouble(); y = rng.nextDouble() * 0.08; break;       // top
      case 1: x = rng.nextDouble(); y = 0.92 + rng.nextDouble() * 0.08; break; // bottom
      case 2: x = rng.nextDouble() * 0.08; y = rng.nextDouble(); break;        // left
      default: x = 0.92 + rng.nextDouble() * 0.08; y = rng.nextDouble();       // right
    }
    size        = 3 + rng.nextDouble() * 5;
    blinkSpeed  = 0.025 + rng.nextDouble() * 0.04;
    opacity     = rng.nextDouble();
    opacityDir  = rng.nextBool() ? 1 : -1;
    color       = _colors[rng.nextInt(_colors.length)];
  }

  void update() {
    opacity += opacityDir * blinkSpeed;
    if (opacity >= 0.8) opacityDir = -1;
    if (opacity <= 0.0) opacityDir = 1;
  }
}

class _NeonDotsPainter extends CustomPainter {
  final List<_NeonDot> dots;
  _NeonDotsPainter(this.dots);

  @override
  void paint(Canvas canvas, Size size) {
    for (final dot in dots) {
      // Glow effect
      canvas.drawCircle(
        Offset(dot.x * size.width, dot.y * size.height),
        dot.size * 2.5,
        Paint()
          ..color = dot.color.withOpacity(dot.opacity * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Core dot
      canvas.drawCircle(
        Offset(dot.x * size.width, dot.y * size.height),
        dot.size,
        Paint()..color = dot.color.withOpacity(dot.opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_NeonDotsPainter old) => true;
}