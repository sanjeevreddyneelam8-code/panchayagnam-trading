import 'package:easy_trade_web/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc/auth_event.dart';
import '../bloc/auth_bloc/auth_state.dart';
import '../bloc/auth_bloc/authbloc.dart';
import '../ui_screens/web_screens/web_login_screen/web_login_screen.dart';

class WebResetMpinScreen extends StatefulWidget {
  final String phoneNumber;
  final String? initialOtp;

  const WebResetMpinScreen({
    super.key,
    required this.phoneNumber,
    this.initialOtp,
  });

  @override
  State<WebResetMpinScreen> createState() => _WebResetMpinScreenState();
}

class _WebResetMpinScreenState extends State<WebResetMpinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  final _mpinCtrl = TextEditingController();
  final _confirmMpinCtrl = TextEditingController();
  bool _obscureMpin = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialOtp != null && widget.initialOtp!.trim().isNotEmpty) {
      _otpCtrl.text = widget.initialOtp!.trim();
    }
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _mpinCtrl.dispose();
    _confirmMpinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 850;
    final cleanPhone = widget.phoneNumber.trim();
    final maskedPhone = cleanPhone.length >= 4
        ? '******${cleanPhone.substring(cleanPhone.length - 4)}'
        : cleanPhone;

    final formPanel = BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is ResetMpinSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          // Navigate back to login with registered mobile pre-filled
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (_) => AuthBloc(),
                child: SignInScreen(initialPhone: cleanPhone),
              ),
            ),
            (route) => false,
          );
        } else if (state is AuthError) {
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
        final isLoading = state is AuthLoading;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : 56, vertical: isMobile ? 24 : 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back button
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_ios_new_rounded,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lock_reset_outlined,
                              color: Color(0xFF7C3AED),
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 20),

                          const Text(
                            'Reset MPIN',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1B4B),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Show masked phone
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFF6B7280)),
                              children: [
                                const TextSpan(text: 'OTP sent to '),
                                TextSpan(
                                  text: maskedPhone,
                                  style: const TextStyle(
                                    color: Color(0xFF1E1B4B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 36),

                          _fieldLabel('ENTER OTP'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _otpCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1E1B4B),
                                letterSpacing: 4,
                                fontWeight: FontWeight.w700),
                            decoration: _inputDecoration(
                              hint: '• • • • • •',
                              icon: Icons.sms_outlined,
                            ).copyWith(counterText: ''),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'OTP is required';
                              if (v.length != 6) return 'Enter 6-digit OTP';
                              if (!RegExp(r'^[0-9]+$').hasMatch(v))
                                return 'Only numbers allowed';
                              return null;
                            },
                          ),
                          if (widget.initialOtp != null &&
                              widget.initialOtp!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFC4B5FD)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      size: 15, color: Color(0xFF6D28D9)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Verification OTP auto-filled: ${widget.initialOtp} (SMS Gateway in Trial Mode)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF5B21B6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          _fieldLabel('NEW MPIN'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _mpinCtrl,
                            obscureText: _obscureMpin,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF1E1B4B)),
                            decoration: _inputDecoration(
                              hint: 'Enter new 4-digit MPIN',
                              icon: _obscureMpin
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              iconTap: () =>
                                  setState(() => _obscureMpin = !_obscureMpin),
                            ).copyWith(counterText: ''),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'New MPIN is required';
                              if (v.trim().length != 4)
                                return 'MPIN must be exactly 4 digits';
                              if (!RegExp(r'^[0-9]+$').hasMatch(v))
                                return 'Only numbers allowed';
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          _fieldLabel('CONFIRM NEW MPIN'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmMpinCtrl,
                            obscureText: _obscureConfirm,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF1E1B4B)),
                            decoration: _inputDecoration(
                              hint: 'Re-enter 4-digit MPIN',
                              icon: _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              iconTap: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                            ).copyWith(counterText: ''),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Please confirm your MPIN';
                              if (v != _mpinCtrl.text)
                                return 'MPINs do not match';
                              return null;
                            },
                          ),

                          const SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                if (_formKey.currentState!.validate()) {
                                  context.read<AuthBloc>().add(
                                    ResetMpinRequested(
                                      phoneNumber: widget.phoneNumber,
                                      otp: _otpCtrl.text.trim(),
                                      newMpin: _mpinCtrl.text.trim(),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                AppColors.primary.withOpacity(0.6),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isLoading
                                  ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                                  : const Text(
                                'Reset MPIN',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F0FB),
      body: isMobile
          ? SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PANCHAYAGNAM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                          Text(
                            'Create your new 4-digit trading MPIN',
                            style: TextStyle(
                              color: Color(0xFFEDE9FE),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    formPanel,
                  ],
                ),
              ),
            )
          : Row(
              children: [
                Expanded(flex: 55, child: _LeftPanel()),
                Expanded(flex: 45, child: formPanel),
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
          borderSide:
          const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
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
              colors: [Color(0xFF7C3AED), Color(0xFF5B21B6), Color(0xFF4C1D95)],
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
                'Almost there!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    height: 1.2),
              ),
              const SizedBox(height: 20),
              const Text(
                'Enter the OTP and set your\nnew secure MPIN to regain access.',
                style: TextStyle(
                    color: Color(0xFFC4B5FD), fontSize: 14, height: 1.8),
              ),
              const SizedBox(height: 40),
              _tip(Icons.timer_outlined,
                  'OTP expires in 10 minutes'),
              const SizedBox(height: 16),
              _tip(Icons.security_outlined,
                  'Use a unique MPIN not shared elsewhere'),
              const SizedBox(height: 16),
              _tip(Icons.check_circle_outline_rounded,
                  'You will be redirected to login after reset'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tip(IconData icon, String label) {
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
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFFEDE9FE), fontSize: 13)),
        ),
      ],
    );
  }
}