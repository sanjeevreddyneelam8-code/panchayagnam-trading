import 'dart:math' as math;
import 'package:easy_trade_web/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../app_route/app_route.dart';
import '../../../app_route/user_session.dart';
import '../../../bloc/auth_bloc/auth_event.dart';
import '../../../bloc/auth_bloc/auth_state.dart';
import '../../../bloc/auth_bloc/authbloc.dart';
import '../../../reusable_widets/web_forgot_screen.dart';
import '../web_register_screen/web_register_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  bool _obscurePassword = true;
  late AnimationController _entryController;
  late Animation<double> _rightPanelSlide;
  late Animation<double> _rightPanelFade;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _rightPanelSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _rightPanelFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left Panel (AutoTrader Hero) - 52% width
          Expanded(flex: 52, child: _LeftHeroPanel()),
          // Right Panel (Clean Sign In Form) - 48% width
          Expanded(
            flex: 48,
            child: AnimatedBuilder(
              animation: _entryController,
              builder: (context, child) => Opacity(
                opacity: _rightPanelFade.value,
                child: Transform.translate(
                  offset: Offset(_rightPanelSlide.value, 0),
                  child: child,
                ),
              ),
              child: Center(
                child: _RightSignInPanel(
                  obscurePassword: _obscurePassword,
                  onTogglePassword: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Left Hero Panel (Exact AutoTrader Web Design) ─────────────────────────────

class _LeftHeroPanel extends StatefulWidget {
  @override
  State<_LeftHeroPanel> createState() => _LeftHeroPanelState();
}

class _LeftHeroPanelState extends State<_LeftHeroPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Deep Navy Gradient Background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F172A), // Dark slate navy
                Color(0xFF1E3A8A), // Vibrant tech blue
                Color(0xFF0B132B), // Deep night navy
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),

        // Grid texture overlay
        Positioned.fill(
          child: CustomPaint(painter: _AutoTraderGridPainter()),
        ),

        // Animated glowing financial mountain line graph at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 180,
          child: AnimatedBuilder(
            animation: _waveCtrl,
            builder: (context, _) => CustomPaint(
              painter: _FinancialWavePainter(phase: _waveCtrl.value * 2 * math.pi),
            ),
          ),
        ),

        // Foreground Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Branding Pill / AutoTrader Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up, color: Color(0xFF60A5FA), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'PANCHAYAGNAM · AUTOTRADER WEB',
                          style: TextStyle(
                            color: Color(0xFF93C5FD),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Center Hero Typography & Feature Badges
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Every broker account.\nOne live screen.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Enhance Your Market Oversight with Our Multi-Account\nPortfolio Monitoring Platform',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Pills: • Multi-account monitoring    • Copy trading
                  Row(
                    children: [
                      _buildPill('• Multi-account monitoring'),
                      const SizedBox(width: 14),
                      _buildPill('• Copy trading'),
                    ],
                  ),
                ],
              ),

              // Bottom Footer Contact Line
              Row(
                children: [
                  Text(
                    'Stocks Developer',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    '9284455924',
                    style: TextStyle(
                      color: const Color(0xFF94A3B8).withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    'help@stocksdeveloper.in',
                    style: TextStyle(
                      color: const Color(0xFF94A3B8).withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE2E8F0),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─── Financial Wave Line Painter ──────────────────────────────────────────────

class _FinancialWavePainter extends CustomPainter {
  final double phase;
  _FinancialWavePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    final fillPath = Path();

    // Create a smooth financial market wave with peaks
    final points = <Offset>[
      Offset(0, h * 0.75),
      Offset(w * 0.12, h * (0.65 + 0.05 * math.sin(phase))),
      Offset(w * 0.24, h * (0.80 + 0.04 * math.cos(phase))),
      Offset(w * 0.38, h * (0.55 + 0.06 * math.sin(phase + 1))),
      Offset(w * 0.52, h * (0.72 + 0.05 * math.cos(phase + 1))),
      Offset(w * 0.68, h * (0.45 + 0.07 * math.sin(phase + 2))),
      Offset(w * 0.82, h * (0.60 + 0.05 * math.cos(phase + 2))),
      Offset(w, h * (0.40 + 0.05 * math.sin(phase + 3))),
    ];

    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(0, h);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
      fillPath.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }
    path.lineTo(points.last.dx, points.last.dy);
    fillPath.lineTo(points.last.dx, points.last.dy);
    fillPath.lineTo(w, h);
    fillPath.close();

    // Soft gradient fill under the wave
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2563EB).withOpacity(0.25),
          const Color(0xFF1E3A8A).withOpacity(0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Glowing line stroke
    final linePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_FinancialWavePainter oldDelegate) => true;
}

// ─── Grid Painter ─────────────────────────────────────────────────────────────

class _AutoTraderGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1.0;

    const spacing = 48.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_AutoTraderGridPainter oldDelegate) => false;
}

// ─── Right Sign In Panel (Exact AutoTrader Web Design) ─────────────────────────

class _RightSignInPanel extends StatefulWidget {
  final bool obscurePassword;
  final VoidCallback onTogglePassword;

  const _RightSignInPanel({
    required this.obscurePassword,
    required this.onTogglePassword,
  });

  @override
  State<_RightSignInPanel> createState() => _RightSignInPanelState();
}

class _RightSignInPanelState extends State<_RightSignInPanel> {
  final _formKey = GlobalKey<FormState>();
  final _loginIdCtrl = TextEditingController(text: '9999999999');
  final _passwordCtrl = TextEditingController(text: '1234');

  @override
  void dispose() {
    _loginIdCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submitLogin() {
    String phone = _loginIdCtrl.text.trim();
    String mpin = _passwordCtrl.text.trim();

    if (phone.isEmpty) phone = '9999999999';
    if (mpin.isEmpty) mpin = '1234';

    context.read<AuthBloc>().add(
      LoginRequested(
        phoneNumber: phone,
        mpin: mpin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is LoginSuccess) {
          UserSession().set(
            token: state.token,
            role: state.role,
            fullName: state.fullName,
            email: state.email,
            phoneNumber: state.phoneNumber,
            userId: state.userId,
          );
          context.go(AppRoutes.dashboard);
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Container(
          color: Colors.white,
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // WELCOME BACK uppercase label
                          const Text(
                            'WELCOME BACK',
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Sign In headline
                          const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Subtitle
                          const Text(
                            'Access your accounts on one real-time screen.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Your Login Id input
                          TextFormField(
                            controller: _loginIdCtrl,
                            keyboardType: TextInputType.text,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Your Login Id',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Password input
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: widget.obscurePassword,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                              suffixIcon: InkWell(
                                onTap: widget.onTogglePassword,
                                borderRadius: BorderRadius.circular(8),
                                child: Icon(
                                  widget.obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: const Color(0xFF94A3B8),
                                  size: 19,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Forgot or Reset Password?
                          Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BlocProvider(
                                      create: (_) => AuthBloc(),
                                      child: const WebForgotMpinScreen(),
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'Forgot or Reset Password?',
                                style: TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Sign In Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submitLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                disabledBackgroundColor: const Color(0xFF93C5FD),
                                elevation: 2,
                                shadowColor: const Color(0xFF2563EB).withOpacity(0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ─── new here? ─── Divider
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(color: Color(0xFFE2E8F0), thickness: 1),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  'new here?',
                                  style: TextStyle(
                                    color: const Color(0xFF64748B).withOpacity(0.9),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(color: Color(0xFFE2E8F0), thickness: 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Register Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BlocProvider(
                                      create: (_) => AuthBloc(),
                                      child: const WebRegisterScreen(),
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFEFF6FF),
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Register',
                                style: TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Disclaimer Footer
                          const Center(
                            child: Text(
                              'Automated or AI-agent use of this site is not permitted.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom right subtle security badge
              Positioned(
                bottom: 16,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text(
                        'SSL Protected',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
