import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/ip_based_bloc/ip_bloc.dart';
import 'ip_theme_colors.dart';

class SaveIpScreen extends StatefulWidget {
  const SaveIpScreen({super.key});

  @override
  State<SaveIpScreen> createState() => _SaveIpScreenState();
}

class _SaveIpScreenState extends State<SaveIpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = [];
  final List<GlobalKey<FormFieldState>> _fieldKeys = [];
  final _formKey = GlobalKey<FormState>();

  late final AnimationController _pageController;
  late final Animation<double> _pageFade;
  late final Animation<Offset> _pageSlide;

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pageFade = CurvedAnimation(
        parent: _pageController, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _pageController, curve: Curves.easeOutCubic));
    _pageController.forward();
    _addField();
  }

  void _addField() {
    setState(() {
      _controllers.add(TextEditingController());
      _fieldKeys.add(GlobalKey<FormFieldState>());
    });
  }

  void _removeField(int index) {
    if (_controllers.length == 1) return;
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
      _fieldKeys.removeAt(index);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final ips = _controllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (ips.isEmpty) return;
    context.read<IpBloc>().add(SaveIpsEvent(ips));
  }

  String? _validateIp(String? value) {
    if (value == null || value.trim().isEmpty) return 'IP address is required';
    final pattern = RegExp(r'^\d{1,3}(\.\d{1,3}){3}(:\d+)?$');
    if (!pattern.hasMatch(value.trim())) {
      return 'Enter valid format: 0.0.0.0 or 0.0.0.0:port';
    }
    return null;
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IpBloc, IpState>(
      listener: (context, state) {
        if (state.saveResponse != null) {
          _showResultSheet(context, state);
        }
        if (state.saveError != null) {
          _showErrorSnackbar(context, state.saveError!);
        }
      },
      builder: (context, state) {
        return FadeTransition(
          opacity: _pageFade,
          child: SlideTransition(
            position: _pageSlide,
            child: Scaffold(
              backgroundColor: AppTheme.background,
              body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),
                    _buildIpFieldsCard(state),
                    const SizedBox(height: 20),
                    _buildSaveButton(state),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.save_rounded,
            color: AppTheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Save IP Addresses',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Add one or multiple IP addresses',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIpFieldsCard(IpState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'IP Addresses ',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: '(${_controllers.length})',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _addField,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.2),
                            width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              color: AppTheme.primary, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Add IP',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: _controllers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _buildIpField(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpField(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 50,
            alignment: Alignment.center,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              key: _fieldKeys[index],
              controller: _controllers[index],
              validator: _validateIp,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontFamily: 'SF Mono',
                letterSpacing: 0.3,
              ),
              decoration: InputDecoration(
                hintText: '0.0.0.0:8082',
                prefixIcon: const Icon(
                  Icons.dns_rounded,
                  color: AppTheme.textTertiary,
                  size: 18,
                ),
                suffixIcon: _controllers[index].text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  color: AppTheme.textTertiary,
                  onPressed: () {
                    setState(() => _controllers[index].clear());
                  },
                )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
            ),
          ),
          if (_controllers.length > 1) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _removeField(index),
              child: Container(
                width: 42,
                height: 50,
                alignment: Alignment.center,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.remove_rounded,
                    color: AppTheme.error,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton(IpState state) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: state.isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          disabledBackgroundColor: AppTheme.primary.withOpacity(0.4),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: state.isSaving
              ? SizedBox(
            key: ValueKey('loading'),
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Row(
            key: const ValueKey('label'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_upload_rounded,
                  size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Save ${_controllers.length} IP${_controllers.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResultSheet(BuildContext context, IpState state) {
    final r = state.saveResponse!;
    final hasNew = r.data.isNotEmpty;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppTheme.success,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              r.message,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasNew) ...[
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Newly saved IPs:',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
              ...r.data.map((ip) => _ipChip(ip)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<IpBloc>().add(ClearSaveStateEvent());
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ipChip(String ip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            ip,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontFamily: 'SF Mono',
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(error,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}