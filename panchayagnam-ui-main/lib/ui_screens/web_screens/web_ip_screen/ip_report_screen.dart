import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/ip_based_bloc/ip_bloc.dart';
import '../../../models/ip_model.dart';
import 'ip_theme_colors.dart';

class IpReportScreen extends StatefulWidget {
  const IpReportScreen({super.key});

  @override
  State<IpReportScreen> createState() => _IpReportScreenState();
}

class _IpReportScreenState extends State<IpReportScreen>
    with SingleTickerProviderStateMixin {
  String _filterType = 'All';

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
    context.read<IpBloc>().add(FetchIpReportEvent());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IpBloc, IpState>(
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
                  context.read<IpBloc>().add(FetchIpReportEvent());
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 24),
                            if (state.isFetchingReport) _buildSkeletonLoader(),
                            if (state.reportError != null &&
                                !state.isFetchingReport)
                              _buildError(context, state.reportError!),
                            if (state.reportResponse != null &&
                                !state.isFetchingReport) ...[
                              _buildSummaryCards(state.reportResponse!.data),
                              const SizedBox(height: 24),
                              _buildFilterBar(),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (state.reportResponse != null && !state.isFetchingReport)
                      _buildDetailsList(state.reportResponse!.data),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
            color: AppTheme.warningLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.assessment_rounded,
            color: AppTheme.warning,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IP Report',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Consolidated IP address report',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(IpReportData data) {
    return Column(
      children: [
        // Gradient total card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A6EFF), Color(0xFF0050CC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total IPs',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.totalIpCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                children: [
                  _miniStat(
                    label: 'Used',
                    value: data.usedIpCount,
                    color: Colors.white,
                    icon: Icons.check_circle_rounded,
                  ),
                  const SizedBox(height: 12),
                  _miniStat(
                    label: 'Unused',
                    value: data.unusedIpCount,
                    color: Colors.white60,
                    icon: Icons.radio_button_unchecked_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Utilization card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Utilization',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  Text(
                    data.totalIpCount > 0
                        ? '${((data.usedIpCount / data.totalIpCount) * 100).toStringAsFixed(0)}%'
                        : '0%',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween(
                    begin: 0,
                    end: data.totalIpCount > 0
                        ? data.usedIpCount / data.totalIpCount
                        : 0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: AppTheme.surfaceElevated,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.success),
                    minHeight: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStat({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(
          '$value $label',
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: ['All', 'Used', 'Unused'].map((type) {
        final active = _filterType == type;
        return GestureDetector(
          onTap: () => setState(() => _filterType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: 8),
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppTheme.primary : AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? AppTheme.primary : AppTheme.divider,
                width: 1,
              ),
              boxShadow: active
                  ? [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
                  : null,
            ),
            child: Text(
              type,
              style: TextStyle(
                color: active ? Colors.white : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight:
                active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  SliverList _buildDetailsList(IpReportData data) {
    final filtered = data.details.where((d) {
      if (_filterType == 'Used') return d.isUsed;
      if (_filterType == 'Unused') return !d.isUsed;
      return true;
    }).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Row(
                children: [
                  Text(
                    'Details',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${filtered.length}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          final detail = filtered[index - 1];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 200 + (index - 1) * 60),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child:
              Transform.translate(offset: Offset(0, 16 * (1 - value)), child: child),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: _buildDetailCard(detail),
            ),
          );
        },
        childCount: filtered.length + 1,
      ),
    );
  }

  Widget _buildDetailCard(IpDetail detail) {
    final isUsed = detail.isUsed;
    final statusColor = isUsed ? AppTheme.success : AppTheme.textTertiary;
    final statusBg = isUsed ? AppTheme.successLight : AppTheme.surfaceCard;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUsed
              ? AppTheme.success.withOpacity(0.2)
              : AppTheme.divider,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isUsed
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    color: statusColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.ipAddress,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'SF Mono',
                        ),
                      ),
                      Text(
                        detail.portNo != null
                            ? 'Port: ${detail.portNo}'
                            : 'Port: —',
                        style: const TextStyle(
                            color: AppTheme.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isUsed ? 'IN USE' : 'UNUSED',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (detail.brokerTypes.isNotEmpty) ...[
            const Divider(height: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BROKER TYPES',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: detail.brokerTypes
                        .map((b) => _brokerChip(b))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],

          if (detail.accounts.isNotEmpty) ...[
            const Divider(height: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'ACCOUNTS',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${detail.accounts.length}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...detail.accounts
                      .map((a) => _buildAccountRow(a)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _brokerChip(String broker) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: AppTheme.primary.withOpacity(0.2), width: 1),
      ),
      child: Text(
        broker,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAccountRow(IpAccount account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded,
                color: AppTheme.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.clientId ?? 'Unknown',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF Mono',
                  ),
                ),
                if (account.brokerType != null)
                  Text(
                    account.brokerType!,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              if (account.isOwn) _badge('Own', AppTheme.primary),
              const SizedBox(width: 4),
              _badge(
                account.active ? 'Active' : 'Inactive',
                account.active ? AppTheme.success : AppTheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      children: List.generate(
        3,
            (i) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1.0),
          duration: Duration(milliseconds: 800 + i * 100),
          curve: Curves.easeInOut,
          builder: (context, value, _) => Opacity(
            opacity: value,
            child: Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider, width: 1),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.errorLight,
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: AppTheme.error.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_rounded, color: AppTheme.error, size: 32),
          const SizedBox(height: 12),
          Text(
            error,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () =>
                context.read<IpBloc>().add(FetchIpReportEvent()),
            child: const Text(
              'Retry',
              style: TextStyle(color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}