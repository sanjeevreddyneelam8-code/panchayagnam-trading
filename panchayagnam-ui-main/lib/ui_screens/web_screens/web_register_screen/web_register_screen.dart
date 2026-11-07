import 'dart:async';
import 'package:easy_trade_web/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/auth_bloc/auth_event.dart';
import '../../../bloc/auth_bloc/auth_state.dart';
import '../../../bloc/auth_bloc/authbloc.dart';
import '../web_login_screen/web_login_screen.dart';

// Tracks which button triggered the AuthLoading state
enum _LoadingAction { none, otp, register }

class WebRegisterScreen extends StatefulWidget {
  const WebRegisterScreen({super.key});

  @override
  State<WebRegisterScreen> createState() => _WebRegisterScreenState();
}

class _WebRegisterScreenState extends State<WebRegisterScreen> {
  bool _obscureMpin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: Row(
        children: [
          Expanded(flex: 55, child: _LeftPanel()),
          Expanded(
            flex: 45,
            child: Center(
              child: _RightPanel(
                obscureMpin: _obscureMpin,
                onToggleMpin: () =>
                    setState(() => _obscureMpin = !_obscureMpin),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Left Panel ───────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF031E18)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accentViolet.withOpacity(0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -40,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.sidebarHover.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 36, 32, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/favicon.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_graph_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 20, letterSpacing: 0.5),
                      children: [
                        TextSpan(
                          text: 'PANCHA',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'YAGNAM',
                          style: TextStyle(
                            color: Color(0xFFDDD6FE),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              const Text(
                'Smart Trading.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const Text(
                'Smarter Returns.',
                style: TextStyle(
                  color: Color(0xFFDDD6FE),
                  fontSize: 34,
                  fontWeight: FontWeight.w300,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Manage NSE & BSE portfolios with institutional-grade\n'
                'tools, real-time analytics, and multi-broker',
                style: TextStyle(
                  color: Color(0xFFC4B5FD),
                  fontSize: 13,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  _statChip(
                    Icons.trending_up_rounded,
                    '₹4.8Cr',
                    'DAILY VOLUME',
                  ),
                  const SizedBox(width: 12),
                  _statChip(Icons.bolt_rounded, '12ms', 'AVG EXECUTION'),
                  const SizedBox(width: 12),
                  _statChip(Icons.verified_rounded, '99.9%', 'UPTIME'),
                ],
              ),
            ],
          ),
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SizedBox(height: 160, child: AnimatedCandlestickChart()),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFDDD6FE), size: 16),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC4B5FD),
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Right Panel ──────────────────────────────────────────────────────────────

class _RightPanel extends StatefulWidget {
  final bool obscureMpin;
  final VoidCallback onToggleMpin;

  const _RightPanel({required this.obscureMpin, required this.onToggleMpin});

  @override
  State<_RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<_RightPanel> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _mpinCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();

  // ─── Tracks which button is currently loading ──────────────────────────────
  _LoadingAction _loadingAction = _LoadingAction.none;

  // ─── OTP Timer State ───────────────────────────────────────────────────────
  bool _otpSent = false;
  bool _canResend = false;
  int _timerSeconds = 60;
  Timer? _timer;

  // ─── Live field validity flags ─────────────────────────────────────────────
  bool _nameValid = false;
  bool _emailValid = false;
  bool _phoneValid = false;

  bool get _canSendOtp => _nameValid && _emailValid && _phoneValid;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onFieldsChanged);
    _emailCtrl.addListener(_onFieldsChanged);
    _phoneCtrl.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text;

    final nameOk = name.length >= 3 && RegExp(r'^[a-zA-Z ]+$').hasMatch(name);
    final emailOk = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
    final phoneOk = phone.length == 10;

    if (nameOk != _nameValid ||
        emailOk != _emailValid ||
        phoneOk != _phoneValid) {
      setState(() {
        _nameValid = nameOk;
        _emailValid = emailOk;
        _phoneValid = phoneOk;
      });
    }
  }

  void _sendOtp(BuildContext blocContext) {
    setState(() => _loadingAction = _LoadingAction.otp);
    blocContext.read<AuthBloc>().add(
      SendOtpRequested(
        phoneNumber: _phoneCtrl.text.trim(),
        codeReqFor: 'Registration',
      ),
    );///
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerSeconds <= 1) {
        t.cancel();
        setState(() {
          _timerSeconds = 0;
          _canResend = true;
        });
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  String get _timerLabel {
    final m = _timerSeconds ~/ 60;
    final s = _timerSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _mpinCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        // ── OTP sent successfully ────────────────────────────────────────────
        if (state is OtpSentSuccess) {
          setState(() {
            _otpSent = true;
            _canResend = false;
            _timerSeconds = 60;
            _loadingAction = _LoadingAction.none; // reset loader
            // Keep OTP input field clean and empty for the real SMS code from mobile
            _otpCtrl.clear();
          });
          _startTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        // ── Registration success ─────────────────────────────────────────────
        else if (state is RegisterSuccess) {
          setState(() => _loadingAction = _LoadingAction.none); // reset loader
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (_) => AuthBloc(),
                child: const SignInScreen(),
              ),
            ),
          );
        }
        // ── Any error ────────────────────────────────────────────────────────
        else if (state is AuthError) {
          setState(() => _loadingAction = _LoadingAction.none); // reset loader
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isOtpLoading =
            state is AuthLoading && _loadingAction == _LoadingAction.otp;
        final isRegisterLoading =
            state is AuthLoading && _loadingAction == _LoadingAction.register;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                _fieldLabel("FULL NAME"),
                const SizedBox(height: 8),
                _nameField(),
                const SizedBox(height: 20),

                _fieldLabel("EMAIL"),
                const SizedBox(height: 8),
                _emailField(),
                const SizedBox(height: 20),

                _fieldLabel("PHONE"),
                const SizedBox(height: 8),
                _phoneField(),

                // ── Send OTP / Countdown / Resend row ─────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isOtpLoading)
                      // Show spinner ONLY next to Send OTP
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF059669),
                          ),
                        ),
                      )
                    else if (_otpSent && !_canResend)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: Color(0xFF059669),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Resend in $_timerLabel',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_otpSent && _canResend)
                      TextButton.icon(
                        onPressed: () => _sendOtp(context),
                        icon: const Icon(
                          Icons.refresh_rounded,
                          size: 15,
                          color: Color(0xFF059669),
                        ),
                        label: const Text(
                          'Resend OTP',
                          style: TextStyle(
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _canSendOtp ? () => _sendOtp(context) : null,
                        style: TextButton.styleFrom(
                          foregroundColor: _canSendOtp
                              ? const Color(0xFF059669)
                              : const Color(0xFFD1D5DB),
                        ),
                        child: Text(
                          'Send OTP',
                          style: TextStyle(
                            color: _canSendOtp
                                ? const Color(0xFF059669)
                                : const Color(0xFFD1D5DB),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),

                _fieldLabel("OTP"),
                const SizedBox(height: 8),
                _otpField(),
                const SizedBox(height: 20),

                _fieldLabel("MPIN"),
                const SizedBox(height: 8),
                _mpinField(),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isRegisterLoading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              // Mark register as the active loading action
                              setState(
                                () => _loadingAction = _LoadingAction.register,
                              );
                              context.read<AuthBloc>().add(
                                RegisterRequested(
                                  fullName: _nameCtrl.text.trim(),
                                  email: _emailCtrl.text.trim(),
                                  phoneNumber: _phoneCtrl.text.trim(),
                                  mpin: _mpinCtrl.text.trim(),
                                  otp: _otpCtrl.text.trim(),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF059669).withOpacity(
                        0.6,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    // Show spinner ONLY on the Register button
                    child: isRegisterLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an Account? ',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        WidgetSpan(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider(
                                    create: (_) => AuthBloc(),
                                    child: const SignInScreen(),
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Field helpers ──────────────────────────────────────────────────────────

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
      color: Color(0xFF6B7280),
    ),
  );

  Widget _nameField() {
    return TextFormField(
      controller: _nameCtrl,
      keyboardType: TextInputType.name,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
      ],
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: _inputDecoration(
        hint: 'Enter your full name',
        icon: Icons.person_outline,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Full name is required';
        if (v.trim().length < 3) return 'Name must be at least 3 characters';
        return null;
      },
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: _inputDecoration(
        hint: 'Enter your email',
        icon: Icons.email_outlined,
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Email is required';
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v))
          return 'Enter valid email address';
        return null;
      },
    );
  }

  Widget _phoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: _inputDecoration(
        hint: 'Enter your phone number',
        icon: Icons.phone_outlined,
      ).copyWith(counterText: ''),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Phone number is required';
        if (v.length != 10) return 'Enter valid 10-digit phone number';
        return null;
      },
    );
  }

  Widget _otpField() {
    return TextFormField(
      controller: _otpCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: _inputDecoration(
        hint: 'Enter 6 digit OTP',
        icon: Icons.lock_outline,
      ).copyWith(counterText: ''),
      validator: (v) {
        if (v == null || v.isEmpty) return 'OTP is required';
        if (v.length < 6) return 'OTP must be 6 digits';
        return null;
      },
    );
  }

  Widget _mpinField() {
    return TextFormField(
      controller: _mpinCtrl,
      obscureText: widget.obscureMpin,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: _inputDecoration(
        hint: 'Create your MPIN (4 digits)',
        icon: widget.obscureMpin
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        iconTap: widget.onToggleMpin,
      ).copyWith(counterText: ''),
      validator: (v) {
        if (v == null || v.isEmpty) return 'MPIN is required';
        if (v.length < 4) return 'MPIN must be 4 digits';
        return null;
      },
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    VoidCallback? iconTap,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
      suffixIcon: InkWell(
        onTap: iconTap,
        child: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
      ),
      filled: true,
      fillColor: const Color(0xFFFAF9FF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}

// ─── Candlestick Chart ────────────────────────────────────────────────────────

class CandleData {
  final double open, close, high, low;
  const CandleData({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
  });
  bool get isBullish => close >= open;
}

class AnimatedCandlestickChart extends StatefulWidget {
  const AnimatedCandlestickChart({super.key});
  @override
  State<AnimatedCandlestickChart> createState() =>
      _AnimatedCandlestickChartState();
}

class _AnimatedCandlestickChartState extends State<AnimatedCandlestickChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _reveal;
  late Animation<double> _line;

  static const _candles = [
    CandleData(open: 20, close: 30, high: 35, low: 16),
    CandleData(open: 30, close: 24, high: 33, low: 21),
    CandleData(open: 24, close: 37, high: 41, low: 22),
    CandleData(open: 37, close: 31, high: 40, low: 28),
    CandleData(open: 31, close: 45, high: 49, low: 29),
    CandleData(open: 45, close: 39, high: 48, low: 36),
    CandleData(open: 39, close: 52, high: 57, low: 37),
    CandleData(open: 52, close: 46, high: 55, low: 43),
    CandleData(open: 46, close: 60, high: 65, low: 44),
    CandleData(open: 60, close: 54, high: 63, low: 51),
    CandleData(open: 54, close: 68, high: 73, low: 52),
    CandleData(open: 68, close: 63, high: 71, low: 59),
    CandleData(open: 63, close: 76, high: 81, low: 61),
    CandleData(open: 76, close: 70, high: 79, low: 66),
    CandleData(open: 70, close: 84, high: 89, low: 68),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    _reveal = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
    );
    _line = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _CandlePainter(
          candles: _candles,
          reveal: _reveal.value,
          line: _line.value,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  final List<CandleData> candles;
  final double reveal, line;
  _CandlePainter({
    required this.candles,
    required this.reveal,
    required this.line,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    const minVal = 8.0;
    const maxVal = 96.0;
    final range = maxVal - minVal;
    double toY(double v) =>
        size.height - ((v - minVal) / range) * size.height * 1.5 - 4;
    final n = candles.length;
    final spacing = size.width / (n + 0.5);
    final cw = spacing * 0.25;
    final visible = (n * reveal).ceil().clamp(0, n);

    if (visible >= 2) {
      final pts = <Offset>[];
      for (int i = 0; i < visible; i++) {
        final mid = (candles[i].open + candles[i].close) / 2;
        pts.add(Offset(spacing * (i + 1), toY(mid)));
      }
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 0; i < pts.length - 1; i++) {
        final mx = (pts[i].dx + pts[i + 1].dx) / 2;
        path.cubicTo(
          mx,
          pts[i].dy,
          mx,
          pts[i + 1].dy,
          pts[i + 1].dx,
          pts[i + 1].dy,
        );
      }
      final metrics = path.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final ex = metrics.first.extractPath(0, metrics.first.length * line);
        canvas.drawPath(
          ex,
          Paint()
            ..color = const Color(0xFFDDD6FE)
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    for (int i = 0; i < visible; i++) {
      final c = candles[i];
      final x = spacing * (i + 1);
      final prog = i < visible - 1 ? 1.0 : (reveal * n - i).clamp(0.0, 1.0);
      final col = c.isBullish ? Colors.greenAccent : const Color(0xFFEF4444);
      final bodyTop = toY(c.isBullish ? c.close : c.open);
      final bodyBottom = toY(c.isBullish ? c.open : c.close);
      final highY = toY(c.high);
      final lowY = toY(c.low);
      final animTop = bodyBottom - (bodyBottom - bodyTop) * prog;
      final animHigh = bodyTop - (bodyTop - highY) * prog;
      canvas.drawLine(
        Offset(x, animHigh),
        Offset(x, lowY),
        Paint()
          ..color = col
          ..strokeWidth = 1.4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - cw / 2, animTop, x + cw / 2, bodyBottom),
          const Radius.circular(2),
        ),
        Paint()..color = col,
      );
    }
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.reveal != reveal || old.line != line;
}