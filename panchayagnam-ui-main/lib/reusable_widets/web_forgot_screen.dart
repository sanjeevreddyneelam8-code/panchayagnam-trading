import 'dart:async';
import 'package:easy_trade_web/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc/auth_event.dart';
import '../bloc/auth_bloc/auth_state.dart';
import '../bloc/auth_bloc/authbloc.dart';
import 'web_reset_mpin_screen.dart';

enum _ForgotLoadingAction { none, otp }

class WebForgotMpinScreen extends StatefulWidget {
  const WebForgotMpinScreen({super.key});

  @override
  State<WebForgotMpinScreen> createState() => _WebForgotMpinScreenState();
}

class _WebForgotMpinScreenState extends State<WebForgotMpinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();

  _ForgotLoadingAction _loadingAction = _ForgotLoadingAction.none;

  bool _otpSent = false;
  bool _canResend = false;
  int _timerSeconds = 60;
  Timer? _timer;

  bool _phoneValid = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final isValid = _phoneCtrl.text.length == 10 &&
        RegExp(r'^[0-9]+$').hasMatch(_phoneCtrl.text);
    if (isValid != _phoneValid) {
      setState(() => _phoneValid = isValid);
    }
  }

  void _sendOtp(BuildContext blocContext) {
    setState(() => _loadingAction = _ForgotLoadingAction.otp);
    blocContext.read<AuthBloc>().add(
      SendOtpRequested(
        phoneNumber: _phoneCtrl.text.trim(),
        codeReqFor: 'Reset',
      ),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timerSeconds = 60;
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
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F0FB),
      body: Row(
        children: [
          Expanded(flex: 55, child: _LeftPanel()),
          Expanded(
            flex: 45,
            child: BlocConsumer<AuthBloc, AuthState>(
              listener: (context, state) {
                // ── OTP sent successfully ──────────────────────────────────
                if (state is OtpSentSuccess) {
                  setState(() {
                    _otpSent = true;
                    _canResend = false;
                    _loadingAction = _ForgotLoadingAction.none;
                  });
                  _startTimer();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: const Color(0xFF7C3AED),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  // Navigate to reset screen once OTP is sent
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider(
                        create: (_) => AuthBloc(),
                        child: WebResetMpinScreen(
                          phoneNumber: _phoneCtrl.text.trim(),
                        ),
                      ),
                    ),
                  );
                }
                // ── Auth error ─────────────────────────────────────────────
                else if (state is AuthError) {
                  setState(() => _loadingAction = _ForgotLoadingAction.none);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              builder: (context, state) {
                final isOtpLoading = state is AuthLoading &&
                    _loadingAction == _ForgotLoadingAction.otp;

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 56, vertical: 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Back button ──────────────────────────────────
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_ios_new_rounded,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Back to Login',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── Icon ─────────────────────────────────────────
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.smartphone_outlined,
                              color: Color(0xFF7C3AED),
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Title ────────────────────────────────────────
                          const Text(
                            'Forgot MPIN?',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1B4B),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Enter your registered phone number.\nWe'll send an OTP to reset your MPIN.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // ── Phone field ──────────────────────────────────
                          _fieldLabel('PHONE NUMBER'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF1E1B4B)),
                            decoration: _inputDecoration(
                              hint: 'Enter your phone number',
                              icon: Icons.phone_outlined,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Phone number is required';
                              if (v.length != 10)
                                return 'Enter valid 10-digit phone number';
                              if (!RegExp(r'^[0-9]+$').hasMatch(v))
                                return 'Only numbers allowed';
                              return null;
                            },
                          ),

                          // ── Send OTP / Timer / Resend row ─────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isOtpLoading)
                                Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF7C3AED),
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
                                        color: Color(0xFF7C3AED),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Resend in $_timerLabel',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF7C3AED),
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
                                      color: Color(0xFF7C3AED),
                                    ),
                                    label: const Text(
                                      'Resend OTP',
                                      style: TextStyle(
                                        color: Color(0xFF7C3AED),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                    ),
                                  )
                                else
                                  TextButton(
                                    onPressed: _phoneValid
                                        ? () => _sendOtp(context)
                                        : null,
                                    style: TextButton.styleFrom(
                                      foregroundColor: _phoneValid
                                          ? const Color(0xFF7C3AED)
                                          : const Color(0xFFD1D5DB),
                                    ),
                                    child: Text(
                                      'Send OTP',
                                      style: TextStyle(
                                        color: _phoneValid
                                            ? const Color(0xFF7C3AED)
                                            : const Color(0xFFD1D5DB),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
      color: Color(0xFF6B7280),
    ),
  );

  InputDecoration _inputDecoration(
      {required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
      suffixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
      filled: true,
      fillColor: const Color(0xFFFAF9FF),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444))),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
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
              colors: [
                Color(0xFF7C3AED),
                Color(0xFF5B21B6),
                Color(0xFF4C1D95)
              ],
              stops: [0.0, 0.55, 1.0],
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
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_graph_rounded,
                        color: Colors.white, size: 20),
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
                                fontWeight: FontWeight.w700)),
                        TextSpan(
                            text: 'YAGNAM',
                            style: TextStyle(
                                color: Color(0xFFDDD6FE),
                                fontWeight: FontWeight.w300)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60),
              const Text(
                'Secure &\nSimple.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    height: 1.2),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your account is protected with\na 4–6 digit MPIN for quick, secure access.',
                style: TextStyle(
                    color: Color(0xFFC4B5FD), fontSize: 14, height: 1.8),
              ),
              const SizedBox(height: 40),
              _step(Icons.smartphone_outlined, 'Enter your phone number'),
              const SizedBox(height: 16),
              _step(Icons.mail_outline_rounded,
                  'Receive OTP on registered number'),
              const SizedBox(height: 16),
              _step(Icons.lock_reset_outlined, 'Set your new MPIN'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _step(IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFDDD6FE), size: 18),
        ),
        const SizedBox(width: 14),
        Text(label,
            style: const TextStyle(color: Color(0xFFEDE9FE), fontSize: 14)),
      ],
    );
  }
}