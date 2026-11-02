import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/ip_based_bloc/ip_bloc.dart';
import 'ip_theme_colors.dart';

class IpHealthScreen extends StatefulWidget {
  const IpHealthScreen({super.key});

  @override
  State<IpHealthScreen> createState() => _IpHealthScreenState();
}

class _IpHealthScreenState extends State<IpHealthScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _selectedIps = [];
  bool _dropdownOpen = false;

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
    _pageFade =
        CurvedAnimation(parent: _pageController, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _pageController, curve: Curves.easeOutCubic));
    _pageController.forward();
    context.read<IpBloc>().add(FetchAllIpsEvent());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleIp(String ip) {
    setState(() {
      if (_selectedIps.contains(ip)) {
        _selectedIps.remove(ip);
      } else {
        _selectedIps.add(ip);
      }
    });
  }

  void _checkHealth() {
    if (_selectedIps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one IP'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    context.read<IpBloc>().add(CheckIpHealthEvent(List.from(_selectedIps)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IpBloc, IpState>(
      listener: (context, state) {
        if (state.healthError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.healthError!),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      builder: (context, state) {
        return FadeTransition(
          opacity: _pageFade,
          child: SlideTransition(
            position: _pageSlide,
            child: Scaffold(
              backgroundColor: AppTheme.background,
              body: RefreshIndicator(
                color: AppTheme.primary,
                backgroundColor: AppTheme.surface,
                onRefresh: () async {
                  context.read<IpBloc>().add(FetchAllIpsEvent());
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildDropdownSection(state),
                      const SizedBox(height: 16),
                      if (_selectedIps.isNotEmpty) _buildSelectedChips(),
                      if (_selectedIps.isNotEmpty) const SizedBox(height: 20),
                      _buildCheckButton(state),
                      const SizedBox(height: 24),
                      if (state.isCheckingHealth) _buildLoadingCard(),
                      if (state.healthResponse != null &&
                          !state.isCheckingHealth)
                        _buildHealthResults(state),
                    ],
                  ),
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
            color: AppTheme.successLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.health_and_safety_rounded,
            color: AppTheme.success,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IP Health Check',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Monitor server availability',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownSection(IpState state) {
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
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _dropdownOpen = !_dropdownOpen),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.dns_rounded,
                        color: AppTheme.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select IP Addresses',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: _selectedIps.isEmpty
                                ? AppTheme.textTertiary
                                : AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          child: Text(
                            _selectedIps.isEmpty
                                ? 'Tap to choose IPs'
                                : '${_selectedIps.length} IP${_selectedIps.length > 1 ? 's' : ''} selected',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.isFetchingAll)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary),
                    )
                  else
                    AnimatedRotation(
                      turns: _dropdownOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(Icons.expand_more_rounded,
                          color: AppTheme.textSecondary, size: 24),
                    ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _dropdownOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: AppTheme.divider),
                if (state.allIps.isEmpty && !state.isFetchingAll)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No IPs available. Pull to refresh.',
                      style: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 14),
                    ),
                  )
                else
                  Column(
                    children: [
                      _buildSelectAllRow(state),
                      const Divider(height: 1, color: AppTheme.divider),
                      ...state.allIps.map((ip) => _buildIpOption(ip)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllRow(IpState state) {
    final allSelected =
    state.allIps.every((ip) => _selectedIps.contains(ip));
    return InkWell(
      onTap: () {
        setState(() {
          if (allSelected) {
            _selectedIps.clear();
          } else {
            _selectedIps.clear();
            _selectedIps.addAll(state.allIps);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: allSelected ? AppTheme.primary : Colors.transparent,
                border: Border.all(
                  color: allSelected ? AppTheme.primary : AppTheme.divider,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: allSelected
                  ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),
            const Text(
              'Select All',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpOption(String ip) {
    final selected = _selectedIps.contains(ip);
    return InkWell(
      onTap: () => _toggleIp(ip),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.divider,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),
            Text(
              ip,
              style: TextStyle(
                color: selected
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
                fontSize: 15,
                fontFamily: 'SF Mono',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedChips() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _selectedIps.map((ip) {
          return Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTheme.primary.withOpacity(0.25), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ip,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontFamily: 'SF Mono',
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _toggleIp(ip),
                  child: const Icon(Icons.close_rounded,
                      color: AppTheme.primary, size: 14),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCheckButton(IpState state) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: (state.isCheckingHealth || _selectedIps.isEmpty)
            ? null
            : _checkHealth,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.success,
          disabledBackgroundColor: AppTheme.success.withOpacity(0.35),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: state.isCheckingHealth
              ? SizedBox(
            key: ValueKey('loading'),
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          )
              : Row(
            key: const ValueKey('label'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.wifi_tethering_rounded,
                  size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Check Health',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.primary),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Checking servers…',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pinging ${_selectedIps.length} IP${_selectedIps.length > 1 ? 's' : ''}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthResults(IpState state) {
    final results = state.healthResponse!.data;
    final upCount = results.where((r) => r.isUp).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: upCount == results.length
                ? AppTheme.successLight
                : AppTheme.warningLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (upCount == results.length
                  ? AppTheme.success
                  : AppTheme.warning)
                  .withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                upCount == results.length
                    ? Icons.check_circle_rounded
                    : Icons.warning_rounded,
                color: upCount == results.length
                    ? AppTheme.success
                    : AppTheme.warning,
                size: 24,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    upCount == results.length
                        ? 'All Servers Online'
                        : '$upCount of ${results.length} Servers Up',
                    style: TextStyle(
                      color: upCount == results.length
                          ? AppTheme.success
                          : AppTheme.warning,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${results.length - upCount} server${results.length - upCount != 1 ? 's' : ''} unreachable',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Health Results',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 14),
        ...results.asMap().entries.map((entry) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration:
            Duration(milliseconds: 300 + entry.key * 80),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            ),
            child: _buildHealthCard(entry.value),
          );
        }),
      ],
    );
  }

  Widget _buildHealthCard(result) {
    final isUp = result.isUp;
    final color = isUp ? AppTheme.success : AppTheme.error;
    final bgColor = isUp ? AppTheme.successLight : AppTheme.errorLight;
    final ts = result.timestamp.length > 19
        ? result.timestamp.substring(0, 19)
        : result.timestamp;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: color,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      result.status,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                ts.replaceAll('T', '  '),
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                  fontFamily: 'SF Mono',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.ip,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontFamily: 'SF Mono',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            result.message,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}