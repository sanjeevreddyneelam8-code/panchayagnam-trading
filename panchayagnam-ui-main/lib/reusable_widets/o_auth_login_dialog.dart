import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/broker_o_auth_dilogue_bloc/broker_o_auth_bloc.dart';
import '../bloc/broker_o_auth_dilogue_bloc/broker_o_auth_event.dart';
import '../bloc/broker_o_auth_dilogue_bloc/broker_o_auth_state.dart';

enum OAuthBroker { profitmart, goodwill }

class OAuthLoginResult {
  final bool success;
  final String? userId;
  final String? uname;
  final String? accessToken;
  final String? errorMessage;

  const OAuthLoginResult({
    required this.success,
    this.userId,
    this.uname,
    this.accessToken,
    this.errorMessage,
  });
}

class OAuthLoginDialog extends StatefulWidget {
  final OAuthBroker broker;
  final String clientId;
  final String secretKey;
  final String? apiKey;   // required for GoodWill
  final String? ip;

  const OAuthLoginDialog({
    super.key,
    required this.broker,
    required this.clientId,
    required this.secretKey,
    this.apiKey,
    this.ip,
  });

  @override
  State<OAuthLoginDialog> createState() => _OAuthLoginDialogState();
}

class _OAuthLoginDialogState extends State<OAuthLoginDialog>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // UI phase: 'initial' → 'waitingCode' → 'done'
  String _phase = 'initial';
  String? _openedUrl;

  bool get _isProfitmart => widget.broker == OAuthBroker.profitmart;
  String get _brokerName => _isProfitmart ? 'Profitmart' : 'GoodWill';

  Color get _gradStart =>
      _isProfitmart ? const Color(0xFF7C3AED) : const Color(0xFF0F766E);
  Color get _gradEnd =>
      _isProfitmart ? const Color(0xFFA855F7) : const Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _openLoginPage(BuildContext context) {
    if (_isProfitmart) {
      context
          .read<BrokerOAuthBloc>()
          .add(ProfitmartOpenLoginUrl(clientId: widget.clientId));
    } else {
      context
          .read<BrokerOAuthBloc>()
          .add(GoodwillOpenLoginUrl(clientId: widget.clientId));
    }
  }

  void _submitCode(BuildContext context) {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    if (_isProfitmart) {
      context.read<BrokerOAuthBloc>().add(
        ProfitmartExchangeToken(
          userId: widget.clientId,
          code: code,
          secretKey: widget.secretKey,
          ip: widget.ip,
        ),
      );
    } else {
      context.read<BrokerOAuthBloc>().add(
        GoodwillExchangeToken(
          userId: widget.clientId,
          code: code,
          secretKey: widget.secretKey,
          apiKey: widget.apiKey ?? '',
          ip: widget.ip,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BrokerOAuthBloc(),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Dialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          child: BlocConsumer<BrokerOAuthBloc, BrokerOAuthState>(
            listener: (context, state) {
              if (state is ProfitmartLoginUrlOpened ||
                  state is GoodwillLoginUrlOpened) {
                final url = state is ProfitmartLoginUrlOpened
                    ? state.loginUrl
                    : (state as GoodwillLoginUrlOpened).loginUrl;
                setState(() {
                  _phase = 'waitingCode';
                  _openedUrl = url;
                });
              }

              if (state is ProfitmartTokenSuccess) {
                Navigator.of(context).pop(OAuthLoginResult(
                  success: true,
                  userId: state.userId,
                  uname: state.uname,
                  accessToken: state.accessToken,
                ));
              }
              if (state is GoodwillTokenSuccess) {
                Navigator.of(context).pop(OAuthLoginResult(
                  success: true,
                  userId: state.userId,
                  uname: state.uname,
                  accessToken: state.accessToken,
                ));
              }
              if (state is BrokerOAuthFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            builder: (context, state) {
              final isLoading = state is BrokerOAuthLoading;
              return Container(
                width: 480,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(context),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                        child: _phase == 'initial'
                            ? _buildInitialStep(context, isLoading)
                            : _buildCodeStep(context, isLoading),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_gradStart, _gradEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_open_outlined,
                size: 20, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_brokerName OAuth Login',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Secure 2-step broker authentication',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
              const Icon(Icons.close, size: 17, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1 UI: open login page ─────────────────────────────────────────────
  Widget _buildInitialStep(BuildContext context, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            border: Border.all(color: const Color(0xFFBAE6FD)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Click the button below to open the $_brokerName login page '
                      'in a new browser tab. After you log in, the broker will '
                      'redirect you back with an authorization code — paste it '
                      'in the next step.',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF0C4A6E)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Account info row
        _infoRow(Icons.person_outlined, 'Client ID', widget.clientId),
        const SizedBox(height: 8),
        _infoRow(Icons.business_outlined, 'Broker', _brokerName),
        const SizedBox(height: 28),
        // Step indicator
        _stepIndicator(currentStep: 1),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  foregroundColor: const Color(0xFF374151),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                isLoading ? null : () => _openLoginPage(context),
                icon: isLoading
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  isLoading ? 'Opening...' : 'Open $_brokerName Login',
                  style: const TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gradStart,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 2 UI: paste auth code ─────────────────────────────────────────────
  Widget _buildCodeStep(BuildContext context, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success banner: URL was opened
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            border: Border.all(color: const Color(0xFFA7F3D0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 16, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Login page opened in a new tab. Complete the login there, '
                      'then copy the authorization code from the redirect URL '
                      'and paste it below.',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF065F46)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Step indicator
        _stepIndicator(currentStep: 2),
        const SizedBox(height: 20),
        // Code input label
        Row(
          children: [
            const Text(
              'Authorization Code',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: const Text(
                'Required',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Paste the code from your browser\'s address bar after login',
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          autofocus: true,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
            fontFamily: 'monospace',
            letterSpacing: 0.5,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. abc123xyz...',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
              fontFamily: 'monospace',
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: Icon(Icons.vpn_key_outlined,
                  size: 18, color: Color(0xFF9CA3AF)),
            ),
            prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: IconButton(
              icon: const Icon(Icons.content_paste_rounded,
                  size: 16, color: Color(0xFF9CA3AF)),
              tooltip: 'Paste from clipboard',
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  _codeController.text = data!.text!.trim();
                }
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
              const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
              const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _gradStart, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Re-open link
        GestureDetector(
          onTap: () => _openLoginPage(context),
          child: Text(
            'Didn\'t get the code? Re-open login page →',
            style: TextStyle(
              fontSize: 11,
              color: _gradStart,
              decoration: TextDecoration.underline,
              decorationColor: _gradStart,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading
                    ? null
                    : () => setState(() {
                  _phase = 'initial';
                  _codeController.clear();
                }),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  foregroundColor: const Color(0xFF374151),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                isLoading ? null : () => _submitCode(context),
                icon: isLoading
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Icon(Icons.check_circle_outline, size: 16),
                label: Text(
                  isLoading ? 'Verifying...' : 'Confirm & Login',
                  style: const TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
              fontSize: 12, color: Color(0xFF6B7280)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _stepIndicator({required int currentStep}) {
    return Row(
      children: [
        _stepDot(1, currentStep >= 1, 'Open Login'),
        Expanded(
          child: Container(
            height: 1,
            color: currentStep >= 2
                ? const Color(0xFF059669)
                : const Color(0xFFE5E7EB),
          ),
        ),
        _stepDot(2, currentStep >= 2, 'Enter Code'),
      ],
    );
  }

  Widget _stepDot(int step, bool active, String label) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active ? _gradStart : const Color(0xFFE5E7EB),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: active
                ? const Color(0xFF374151)
                : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }
}