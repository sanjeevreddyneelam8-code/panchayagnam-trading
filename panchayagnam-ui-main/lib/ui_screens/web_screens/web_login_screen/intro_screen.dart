import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_route/app_route.dart';


class _T {
  // Radiant Institutional Forest & Emerald Green Palette
  static const bg = Color(0xFF032E24); // Rich vibrant emerald forest background (distinctly green!)
  static const surface = Color(0xFF064E3B); // Forest green surface
  static const surfaceCard = Color(0xFF065F46); // Deep rich emerald card
  static const surfaceHover = Color(0xFF047857); // Elevated emerald hover

  // Emerald & Mint accents
  static const gold = Color(0xFF10B981); // Radiant emerald jade
  static const goldLight = Color(0xFF34D399); // Vibrant light mint
  static const goldDim = Color(0xFF059669); // Rich institutional green
  static const goldGlow = Color(0xFF10B981); // Emerald glow

  // Text
  static const textPrimary = Color(0xFFFFFFFF); // Pure crisp white
  static const textSecondary = Color(0xFFA7F3D0); // Soft mint jade
  static const textMuted = Color(0xFF6EE7B7); // Vibrant muted emerald

  // Borders
  static const border = Color(0xFF065F46); // Forest emerald border
  static const borderGold = Color(0xFF10B981); // Radiant emerald border

  // Semantic
  static const positive = Color(0xFF34D399);
  static const negative = Color(0xFFEF4444);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class WebLandingScreen extends StatefulWidget {
  const WebLandingScreen({super.key});

  @override
  State<WebLandingScreen> createState() => _WebLandingScreenState();
}

class _WebLandingScreenState extends State<WebLandingScreen>
    with TickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  double _scrollOffset = 0;

  late AnimationController _heroCtrl;
  late AnimationController _orb1Ctrl;
  late AnimationController _orb2Ctrl;
  late AnimationController _shimmerCtrl;

  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _orb1Anim;
  late Animation<double> _orb2Anim;
  late Animation<double> _shimmerAnim;

  final _keyPlatform = GlobalKey();
  final _keyFeatures = GlobalKey();
  final _keyFaq = GlobalKey();
  final _keyContact = GlobalKey();

  @override
  void initState() {
    super.initState();

    _scroll.addListener(() => setState(() => _scrollOffset = _scroll.offset));

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _heroFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _heroCtrl,
        curve: const Interval(0, 0.65, curve: Curves.easeOut),
      ),
    );
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _heroCtrl,
            curve: const Interval(0, 0.75, curve: Curves.easeOutCubic),
          ),
        );

    _orb1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
    _orb1Anim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));

    _orb2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat(reverse: true);
    _orb2Anim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _shimmerAnim = Tween<double>(
      begin: -1.5,
      end: 2.5,
    ).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _heroCtrl.forward();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _heroCtrl.dispose();
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: Stack(
        children: [
          // Animated background orbs
          AnimatedBuilder(
            animation: Listenable.merge([_orb1Anim, _orb2Anim]),
            builder: (_, __) =>
                _AmbientOrbs(orb1: _orb1Anim.value, orb2: _orb2Anim.value),
          ),

          // Content
          SingleChildScrollView(
            controller: _scroll,
            child: Column(
              children: [
                const SizedBox(height: 40),
                _HeroSection(
                  fade: _heroFade,
                  slide: _heroSlide,
                  shimmer: _shimmerAnim,
                  onGetStarted: () => _scrollTo(_keyContact),
                  onLearnMore: () => _scrollTo(_keyPlatform),
                ),
                _PlatformSection(key: _keyPlatform),
                _FeaturesSection(key: _keyFeatures),
                _FaqSection(key: _keyFaq),
                _CtaBand(onGetStarted: () => _scrollTo(_keyContact)),
                _ContactSection(key: _keyContact),
                const _Footer(),
              ],
            ),
          ),

          // Fixed nav
          _NavBar(
            scrollOffset: _scrollOffset,
            onPlatform: () => _scrollTo(_keyPlatform),
            onFeatures: () => _scrollTo(_keyFeatures),
            onFaq: () => _scrollTo(_keyFaq),
            onContact: () => _scrollTo(_keyContact),
            onSignIn: () => context.go(AppRoutes.login),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AMBIENT ORBS
// ═══════════════════════════════════════════════════════════════════════════════

class _AmbientOrbs extends StatelessWidget {
  final double orb1, orb2;
  const _AmbientOrbs({required this.orb1, required this.orb2});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -100 + orb1 * 60,
            left: w * 0.6 + orb1 * 40,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFF10B981).withOpacity(0.18), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            top: 200 + orb2 * 80,
            left: -100 + orb2 * 30,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B2A7A).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NAV BAR
// ═══════════════════════════════════════════════════════════════════════════════

class _NavBar extends StatelessWidget {
  final double scrollOffset;
  final VoidCallback onPlatform, onFeatures, onFaq, onContact, onSignIn;

  const _NavBar({
    required this.scrollOffset,
    required this.onPlatform,
    required this.onFeatures,
    required this.onFaq,
    required this.onContact,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final elevated = scrollOffset > 30;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 80,
      decoration: BoxDecoration(
        color: elevated ? const Color(0xFF043E31).withOpacity(0.95) : const Color(0xFF032E24).withOpacity(0.85),
        border: Border(
          bottom: BorderSide(
            color: elevated ? _T.border : Colors.transparent,
            width: 1,
          ),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: ClipRect(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 64),
          child: Row(
            children: [
              // Logo
              _Logo(),

              const Spacer(),

              // Nav links
              ...[
                ('Platform', onPlatform),
                ('Features', onFeatures),
                ('FAQ', onFaq),
                ('Contact', onContact),
              ].map(
                (e) => Padding(
                  padding: const EdgeInsets.only(right: 36),
                  child: _NavLink(label: e.$1, onTap: e.$2),
                ),
              ),

              _GoldButton(label: 'Get Started', onTap: onSignIn, small: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,

              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/login_logo.png',
                width: 68,
                height: 68,
                fit: BoxFit.cover, // ← use cover, not contain
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, letterSpacing: 2.5),
            children: [
              TextSpan(
                text: 'PANCHA',
                style: TextStyle(
                  color: _T.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: 'YAGNAM',
                style: TextStyle(color: _T.gold, fontWeight: FontWeight.w300),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink({required this.label, required this.onTap});

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: _hovered ? _T.textPrimary : _T.textSecondary,
              ),
              child: Text(widget.label),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _hovered ? 20 : 0,
              height: 1.5,
              decoration: BoxDecoration(
                color: _T.gold,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HERO SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _HeroSection extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  final Animation<double> shimmer;
  final VoidCallback onGetStarted, onLearnMore;

  const _HeroSection({
    required this.fade,
    required this.slide,
    required this.shimmer,
    required this.onGetStarted,
    required this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 100),
      child: Stack(
        children: [
          // Fine grid pattern
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // Horizontal rule
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    _T.gold.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Badge
                  _PillBadge(
                    label: 'NSE · BSE · STOCKS · FUTURES · OPTIONS',
                    shimmer: shimmer,
                  ),

                  const SizedBox(height: 48),

                  // Headline
                  Column(
                    children: [
                      Text(
                        'Where Capital Meets',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -3,
                          color: _T.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: shimmer,
                        builder: (_, __) => ShaderMask(
                          shaderCallback: (rect) => LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            stops: [
                              (shimmer.value - 0.5).clamp(0.0, 1.0),
                              shimmer.value.clamp(0.0, 1.0),
                              (shimmer.value + 0.5).clamp(0.0, 1.0),
                            ],
                            colors: const [
                              Color(0xFFC9A84C),
                              Color(0xFFFFE5A0),
                              Color(0xFFC9A84C),
                            ],
                          ).createShader(rect),
                          child: Text(
                            'Conviction.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              letterSpacing: -3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: 560,
                    child: Text(
                      'Institutional-grade trading intelligence for Indian Equities, F&O, and MCX Commodities. '
                      '35+ brokers connected permanently on one live terminal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: _T.textSecondary,
                        height: 1.9,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 52),

                  // CTA Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GoldButton(
                        label: 'Start Trading',
                        onTap: onGetStarted,
                        icon: Icons.arrow_forward_rounded,
                      ),
                      const SizedBox(width: 16),
                      _GhostDarkButton(label: 'Learn More', onTap: onLearnMore),
                    ],
                  ),

                  const SizedBox(height: 64),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final Animation<double> shimmer;
  const _PillBadge({required this.label, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _T.borderGold, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _T.positive,
              boxShadow: [
                BoxShadow(
                  color: _T.positive.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: _T.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  final String label;
  const _TrustPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: _T.textMuted,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _TrustDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _T.textMuted),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return _RevealOnScroll(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: _T.goldLight,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: _T.textMuted,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLATFORM SECTION ("What We Do")
// ═══════════════════════════════════════════════════════════════════════════════

class _PlatformSection extends StatelessWidget {
  const _PlatformSection({super.key});

  static const _cards = [
    (
      Icons.candlestick_chart_rounded,
      'Intraday Trading',
      'Capitalise on short-term price movements lasting minutes to hours. Precision entry and exit signals reduce noise and maximise edge.',
    ),
    (
      Icons.swap_horiz_rounded,
      'Swing Trading',
      'Capture multi-day price swings with intelligent screeners that surface setups before they break out.',
    ),
    (
      Icons.account_balance_rounded,
      'Positional Trading',
      'Build wealth over weeks and months. Fundamental-driven insights combined with technical timing for conviction trades.',
    ),
    (
      Icons.bolt_rounded,
      'Buy / Sell Signals',
      'Institution-grade signals across Stocks, Futures & Options — cutting analysis time and removing emotional bias.',
    ),
    (
      Icons.people_rounded,
      'Multi-Client Management',
      'Handle multiple client portfolios and broker accounts from one unified command centre without losing context.',
    ),
    (
      Icons.search_rounded,
      'Smart Stock Screener',
      'Surface momentum across NSE & BSE in real time. Filter by sector, market cap, and technical pattern.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionEyebrow(text: 'Platform'),
          const SizedBox(height: 16),
          const _SectionHeadline(
            prefix: 'One Platform for ',
            accent: 'Every Trade',
          ),
          const SizedBox(height: 64),
          _StaggeredGrid(
            children: _cards
                .map((c) => _DarkCard(icon: c.$1, title: c.$2, body: c.$3))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StaggeredGrid extends StatelessWidget {
  final List<Widget> children;
  const _StaggeredGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 3) {
      rows.add(
        Row(
          children: [
            for (var j = i; j < i + 3 && j < children.length; j++) ...[
              if (j > i) const SizedBox(width: 20),
              Expanded(child: children[j]),
            ],
          ],
        ),
      );
      if (i + 3 < children.length) const SizedBox(height: 20);
      rows.add(const SizedBox(height: 20));
    }
    return Column(children: rows);
  }
}

class _DarkCard extends StatefulWidget {
  final IconData icon;
  final String title, body;
  const _DarkCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  State<_DarkCard> createState() => _DarkCardState();
}

class _DarkCardState extends State<_DarkCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _glow = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
        _ctrl.forward();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _ctrl.reverse();
      },
      child: AnimatedBuilder(
        animation: _glow,
        builder: (_, child) => Container(
          transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _hovered ? _T.surfaceHover : _T.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered ? _T.goldDim.withOpacity(0.6) : _T.border,
              width: 1,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: _T.gold.withOpacity(0.08 * _glow.value),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : [],
          ),
          child: child,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _hovered ? _T.gold.withOpacity(0.15) : _T.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _hovered ? _T.goldDim : _T.border,
                  width: 1,
                ),
              ),
              child: Icon(
                widget.icon,
                color: _hovered ? _T.goldLight : _T.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _T.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.body,
              style: TextStyle(
                fontSize: 13,
                color: _T.textSecondary,
                height: 1.75,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURES SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _FeaturesSection extends StatefulWidget {
  const _FeaturesSection({super.key});

  @override
  State<_FeaturesSection> createState() => _FeaturesSectionState();
}

class _FeaturesSectionState extends State<_FeaturesSection> {
  int _active = 0;

  static const _items = [
    (
      'User-Friendly Interface',
      'Clean, intuitive design engineered to reduce cognitive load. Whether you are a first-time investor or a seasoned trader, you will feel at home from day one.',
      Icons.touch_app_rounded,
    ),
    (
      'Simplicity & Versatility',
      'One platform for Stocks, F&O, and MCX/NSE Commodities (Crude Oil, Gold, Silver, Natural Gas) with live Option Chains and AI Trade Market.',
      Icons.tune_rounded,
    ),
    (
      '35+ Brokers Connected',
      'Connect 35+ Indian brokers including Zerodha, Angel One, Dhan, Upstox, Groww, Fyers, Kotak Neo, Alice Blue & Motilal on one screen.',
      Icons.hub_rounded,
    ),
    (
      'Comprehensive Training',
      'After purchasing a subscription, attend our in-office training at Visakhapatnam to master every feature of the platform.',
      Icons.school_rounded,
    ),
  ];

  static const _mockPanels = [
    _MockPanelData(
      title: 'Live Portfolio View',
      rows: [
        ('RELIANCE', 'NSE', '₹2,914.50'),
        ('TCS', 'NSE', '₹3,671.20'),
        ('HDFCBANK', 'BSE', '₹1,528.90'),
        ('INFY', 'NSE', '₹1,432.60'),
      ],
    ),
    _MockPanelData(
      title: 'Market Overview',
      rows: [
        ('NIFTY 50', 'INDEX', '22,340'),
        ('BANK NIFTY', 'INDEX', '47,820'),
        ('SENSEX', 'INDEX', '73,650'),
        ('NIFTY IT', 'INDEX', '33,100'),
      ],
    ),
    _MockPanelData(
      title: '35+ Connected Brokers',
      rows: [
        ('DhanHQ / Angel One', 'CONNECTED', 'Sub-12ms'),
        ('Zerodha / Upstox', 'CONNECTED', 'Synced'),
        ('Groww / Fyers / Kotak', 'CONNECTED', 'Active Pool'),
        ('+29 Other Indian Brokers', 'PERMANENT', '35+ Ready'),
      ],
    ),
    _MockPanelData(
      title: 'Training Progress',
      rows: [
        ('Module 1', 'BASICS', 'Completed'),
        ('Module 2', 'TECHNICAL', 'Completed'),
        ('Module 3', 'OPTIONS', 'In Progress'),
        ('Module 4', 'ADVANCED', 'Locked'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 100),
      color: _T.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionEyebrow(text: 'Why Choose Us'),
          const SizedBox(height: 16),
          const _SectionHeadline(
            prefix: 'Built for ',
            accent: 'Serious Traders',
          ),
          const SizedBox(height: 64),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: List.generate(
                    _items.length,
                    (i) => _FeatureTab(
                      number: '0${i + 1}',
                      title: _items[i].$1,
                      desc: _items[i].$2,
                      icon: _items[i].$3,
                      isActive: _active == i,
                      onTap: () => setState(() => _active = i),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                flex: 5,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.03, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _MockPanel(
                    key: ValueKey(_active),
                    data: _mockPanels[_active],
                    activeIndex: _active,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureTab extends StatefulWidget {
  final String number, title, desc;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _FeatureTab({
    required this.number,
    required this.title,
    required this.desc,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_FeatureTab> createState() => _FeatureTabState();
}

class _FeatureTabState extends State<_FeatureTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: active
                ? _T.surfaceCard
                : _hovered
                ? _T.surfaceCard.withOpacity(0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? _T.goldDim.withOpacity(0.7) : _T.border,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Indicator bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 3,
                height: active ? 52 : 0,
                decoration: BoxDecoration(
                  color: _T.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 20),
              // Number
              Text(
                widget.number,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: active ? _T.gold : _T.border,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: active ? _T.textPrimary : _T.textSecondary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.desc,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _T.textSecondary,
                          height: 1.65,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                widget.icon,
                color: active ? _T.gold : _T.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockPanelData {
  final String title;
  final List<(String, String, String)> rows;
  const _MockPanelData({required this.title, required this.rows});
}

class _MockPanel extends StatelessWidget {
  final _MockPanelData data;
  final int activeIndex;
  const _MockPanel({super.key, required this.data, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: _T.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(bottom: BorderSide(color: _T.border, width: 1)),
            ),
            child: Row(
              children: [
                ...List.generate(
                  3,
                  (i) => Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: [
                        const Color(0xFFFC6058),
                        const Color(0xFFFEC02F),
                        const Color(0xFF2DC840),
                      ][i],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'PANCHAYAGNAM — ${data.title}',
                  style: TextStyle(fontSize: 11, color: _T.textMuted),
                ),
              ],
            ),
          ),

          // Rows
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: data.rows.asMap().entries.map((e) {
                final i = e.key;
                final r = e.value;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 300 + i * 80),
                  curve: Curves.easeOut,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - v)),
                      child: child,
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: _T.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _T.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        Text(
                          r.$1,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _T.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _T.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _T.border, width: 1),
                          ),
                          child: Text(
                            r.$2,
                            style: TextStyle(
                              fontSize: 9,
                              color: _T.textMuted,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          r.$3,
                          style: TextStyle(
                            fontSize: 13,
                            color: _T.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Bottom bars
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                _DarkBar(label: 'Portfolio Health', percent: 0.82),
                const SizedBox(height: 10),
                _DarkBar(label: "Today's P&L", percent: 0.64, isGreen: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkBar extends StatelessWidget {
  final String label;
  final double percent;
  final bool isGreen;
  const _DarkBar({
    required this.label,
    required this.percent,
    this.isGreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: _T.textMuted)),
            Text(
              '${(percent * 100).toInt()}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _T.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 5, color: _T.surface),
              FractionallySizedBox(
                widthFactor: percent,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isGreen
                          ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
                          : [_T.goldLight, _T.gold],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FAQ SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _FaqSection extends StatelessWidget {
  const _FaqSection({super.key});

  static const _faqs = [
    (
      'What is PANCHAYAGNAM INVESTMENTS?',
      'India\'s Multi-Client, 35+ Broker Copy Trading, Algo Execution & Commodity Derivatives Platform supporting NSE, BSE, and MCX from one unified dashboard.',
    ),
    (
      'Which segments are supported?',
      'Supports Equities, Index/Stock Futures & Options across NSE & BSE, plus MCX/NSE Commodities including Crude Oil, Natural Gas, Gold, Silver, Copper & Zinc.',
    ),
    (
      'Can I use it for Intraday, Swing & Positional trading?',
      'Yes. Engineered for Intraday scalping, Swing setups, MCX Commodity hedging, and automated Positional Algo strategies with 1-click multi-broker copy.',
    ),
    (
      'Is the platform available on Mobile?',
      'Yes! Our responsive web terminal adapts cleanly across Desktop workstations, Tablets, and Mobile browsers.',
    ),
    (
      'Is stock market training provided?',
      'Yes. After purchasing a subscription, a comprehensive Training Module is conducted at our Visakhapatnam office to help you master the platform.',
    ),
    (
      'How can I discover moving stocks?',
      'The built-in intelligent Stock Screener filters NSE & BSE symbols by momentum, sector, market cap, and technical pattern in real time.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionEyebrow(text: 'FAQ'),
          const SizedBox(height: 16),
          const _SectionHeadline(prefix: 'Common ', accent: 'Questions'),
          const SizedBox(height: 64),
          _RevealOnScroll(
            child: Column(
              children: List.generate((_faqs.length / 2).ceil(), (rowIdx) {
                final a = _faqs[rowIdx * 2];
                final bIdx = rowIdx * 2 + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _FaqItem(q: a.$1, a: a.$2),
                      ),
                      const SizedBox(width: 14),
                      if (bIdx < _faqs.length)
                        Expanded(
                          child: _FaqItem(q: _faqs[bIdx].$1, a: _faqs[bIdx].$2),
                        )
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String q, a;
  const _FaqItem({required this.q, required this.a});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: _open ? _T.surfaceCard : _T.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _open ? _T.goldDim.withOpacity(0.5) : _T.border,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.q,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _open ? _T.textPrimary : _T.textSecondary,
                        height: 1.4,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _open
                          ? _T.goldDim.withOpacity(0.3)
                          : _T.surfaceCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _open ? _T.goldDim : _T.border,
                        width: 1,
                      ),
                    ),
                    child: AnimatedRotation(
                      turns: _open ? 0.125 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.add_rounded,
                        color: _open ? _T.goldLight : _T.textMuted,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expand,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              child: Text(
                widget.a,
                style: TextStyle(
                  fontSize: 13,
                  color: _T.textSecondary,
                  height: 1.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CTA BAND
// ═══════════════════════════════════════════════════════════════════════════════

class _CtaBand extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _CtaBand({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 64),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _T.borderGold, width: 1),
        gradient: const LinearGradient(
          colors: [Color(0xFF022C22), Color(0xFF042822)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative glow
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_T.gold.withOpacity(0.12), Colors.transparent],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 80),
            child: Column(
              children: [
                Text(
                  'Ready to Elevate Your Trading?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: _T.textPrimary,
                    letterSpacing: -2,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Join PANCHAYAGNAM INVESTMENTS and experience a more\nprofitable, confident journey across Indian markets.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: _T.textSecondary,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 44),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GoldButton(
                      label: 'Get Started Now',
                      onTap: onGetStarted,
                      icon: Icons.arrow_forward_rounded,
                    ),
                    const SizedBox(width: 14),
                    _GhostDarkButton(
                      label: 'Contact Us →',
                      onTap: onGetStarted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTACT SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _ContactSection extends StatelessWidget {
  const _ContactSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionEyebrow(text: 'Contact'),
          const SizedBox(height: 16),
          const _SectionHeadline(prefix: "We're Here to ", accent: 'Help You'),
          const SizedBox(height: 64),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _ContactTile(
                      icon: Icons.phone_rounded,
                      label: 'PHONE',
                      content: '+91 93900 76827\n+91 97013 48639',
                    ),
                    const SizedBox(height: 14),
                    _ContactTile(
                      icon: Icons.email_outlined,
                      label: 'EMAIL',
                      content: 'customersupport@panchayagnam.com',
                      isGold: true,
                    ),
                    const SizedBox(height: 14),
                    _ContactTile(
                      icon: Icons.business_rounded,
                      label: 'OFFICE',
                      content:
                          'Plot No. 404, Fourth Floor, Opp. D-Mart,\nSrinagar, Gajuwaka, Visakhapatnam,\nAndhra Pradesh — 530046',
                      badge: 'GSTIN: 37NPOPS5428Q1ZF',
                    ),
                    const SizedBox(height: 14),
                    _ContactTile(
                      icon: Icons.access_time_rounded,
                      label: 'HOURS',
                      content:
                          'Mon – Fri: 9:00 AM – 3:30 PM IST\nClosed on NSE/BSE Market Holidays',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              Expanded(flex: 5, child: _OfficeCard()),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatefulWidget {
  final IconData icon;
  final String label, content;
  final String? badge;
  final bool isGold;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.content,
    this.badge,
    this.isGold = false,
  });

  @override
  State<_ContactTile> createState() => _ContactTileState();
}

class _ContactTileState extends State<_ContactTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _hovered ? _T.surfaceCard : _T.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered ? _T.goldDim.withOpacity(0.5) : _T.border,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _T.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _T.border, width: 1),
              ),
              child: Icon(widget.icon, color: _T.gold, size: 19),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: _T.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.content,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.isGold ? _T.goldLight : _T.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  if (widget.badge != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _T.goldDim.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _T.goldDim.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.badge!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _T.gold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border, width: 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _T.surfaceCard,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(bottom: BorderSide(color: _T.border, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _T.positive,
                    boxShadow: [
                      BoxShadow(
                        color: _T.positive.withOpacity(0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'OFFICE LOCATION — VISAKHAPATNAM, AP',
                  style: TextStyle(
                    fontSize: 10,
                    color: _T.textMuted,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              children: [
                SizedBox(
                  height: 110,
                  child: CustomPaint(
                    size: const Size(70, 110),
                    painter: _GoldPinPainter(),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Plot No. 404, Fourth Floor\nOpp. D-Mart, Srinagar\nGajuwaka, Visakhapatnam — 530046\nAndhra Pradesh, India',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _T.textSecondary,
                    height: 1.9,
                  ),
                ),
                const SizedBox(height: 28),
                Container(height: 1, color: _T.border),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _DarkChip(
                      icon: Icons.directions_rounded,
                      label: 'Near D-Mart',
                    ),
                    _DarkChip(icon: Icons.elevator_rounded, label: '4th Floor'),
                    _DarkChip(
                      icon: Icons.local_parking_rounded,
                      label: 'Parking Available',
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DarkChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _T.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _T.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _T.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _T.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FOOTER
// ═══════════════════════════════════════════════════════════════════════════════

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 28),
      decoration: BoxDecoration(
        color: _T.surface,
        border: Border(top: BorderSide(color: _T.border, width: 1)),
      ),
      child: Row(
        children: [
          _Logo(),
          const Spacer(),
          Text(
            '© 2025 PANCHAYAGNAM INVESTMENTS  ·  GSTIN: 37NPOPS5428Q1ZF  ·  Visakhapatnam, AP',
            style: TextStyle(fontSize: 11, color: _T.textMuted),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED BUTTONS & COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

class _GoldButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool small;

  const _GoldButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.small = false,
  });

  @override
  State<_GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<_GoldButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
          padding: EdgeInsets.symmetric(
            horizontal: widget.small ? 20 : 28,
            vertical: widget.small ? 10 : 15,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovered
                  ? [const Color(0xFFE8C97A), const Color(0xFFC9A84C)]
                  : [const Color(0xFFC9A84C), const Color(0xFF8B6914)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(widget.small ? 10 : 12),
            boxShadow: [
              BoxShadow(
                color: _T.gold.withOpacity(_hovered ? 0.35 : 0.18),
                blurRadius: _hovered ? 28 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: const Color(0xFF021B17),
                  fontSize: widget.small ? 12 : 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              if (widget.icon != null) ...[
                const SizedBox(width: 8),
                Icon(
                  widget.icon,
                  color: const Color(0xFF021B17),
                  size: widget.small ? 15 : 17,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostDarkButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostDarkButton({required this.label, required this.onTap});

  @override
  State<_GhostDarkButton> createState() => _GhostDarkButtonState();
}

class _GhostDarkButtonState extends State<_GhostDarkButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          decoration: BoxDecoration(
            color: _hovered ? _T.surfaceHover : _T.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? _T.gold.withOpacity(0.4) : _T.border,
              width: 1,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? _T.goldLight : _T.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION TYPOGRAPHY
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionEyebrow extends StatelessWidget {
  final String text;
  const _SectionEyebrow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 1.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_T.gold, _T.goldDim]),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: _T.gold,
          ),
        ),
      ],
    );
  }
}

class _SectionHeadline extends StatelessWidget {
  final String prefix, accent;
  const _SectionHeadline({required this.prefix, required this.accent});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w900,
          color: _T.textPrimary,
          letterSpacing: -1.5,
          height: 1.1,
        ),
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: accent,
            style: TextStyle(color: _T.gold),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REVEAL ANIMATION WRAPPER
// ═══════════════════════════════════════════════════════════════════════════════

class _RevealOnScroll extends StatefulWidget {
  final Widget child;
  const _RevealOnScroll({required this.child});

  @override
  State<_RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<_RevealOnScroll>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(
      const Duration(milliseconds: 100),
      () => mounted ? _ctrl.forward() : null,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════════════════════════════

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9A84C).withOpacity(0.04)
      ..strokeWidth = 0.5;
    const spacing = 48.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

class _GoldPinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // Glow shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height - 8),
        width: size.width * 0.8,
        height: 14,
      ),
      Paint()..color = _T.gold.withOpacity(0.12),
    );

    // Pin path
    final path = Path()
      ..moveTo(cx, size.height - 12)
      ..cubicTo(
        cx - 5,
        size.height - 18,
        cx - size.width / 2,
        size.height * 0.52,
        cx - size.width / 2,
        size.height * 0.35,
      )
      ..arcToPoint(
        Offset(cx + size.width / 2, size.height * 0.35),
        radius: Radius.circular(size.width / 2),
        clockwise: false,
      )
      ..cubicTo(
        cx + size.width / 2,
        size.height * 0.52,
        cx + 5,
        size.height - 18,
        cx,
        size.height - 12,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = _T.goldDim.withOpacity(0.3));
    canvas.drawPath(
      path,
      Paint()
        ..color = _T.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final center = Offset(cx, size.height * 0.35);
    canvas.drawCircle(center, size.width * 0.2, Paint()..color = _T.gold);
    canvas.drawCircle(
      center,
      size.width * 0.1,
      Paint()..color = const Color(0xFF021B17),
    );
  }

  @override
  bool shouldRepaint(_GoldPinPainter old) => false;
}
