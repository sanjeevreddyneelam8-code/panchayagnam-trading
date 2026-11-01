import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:html' as html;
import '../../../app_route/app_route.dart';
import '../../../app_route/user_session.dart';
import '../../../bloc/auth_bloc/auth_event.dart';
import '../../../bloc/auth_bloc/authbloc.dart';
import '../../../constants/colors.dart';
import '../../../reusable_widets/subscription_plans_screen.dart';
import 'approve_user_tab.dart';
import 'child_accounts_tab.dart';
import 'dashboard_tab.dart';
import 'group_orders_tab.dart';
import 'groupadmin_tab.dart';
import 'individual_execution_screen.dart';
import 'market_watch_view.dart';
import 'charts_view.dart';
import 'algo_strategies_view.dart';
import 'backtesting_view.dart';
import 'options_chain_view.dart';
import 'basket_orders_view.dart';
import 'trading_workspace_views.dart';

const _kGradientTop = Color(0xFF7C3AED);
const _kGradientMid = Color(0xFF5B21B6);
const _kGradientBottom = Color(0xFF4C1D95);
const _kExpandedWidth = 220.0;
const _kCollapsedWidth = 80.0;
const _kAnimDuration = Duration(milliseconds: 280);
const _kAnimCurve = Curves.easeInOut;

enum _NavItemType { normal, group }

class _NavItem {
  final IconData icon;
  final String label;
  final _NavItemType type;
  final List<_SubNavItem> children;

  const _NavItem({
    required this.icon,
    required this.label,
    this.type = _NavItemType.normal,
    this.children = const [],
  });
}

class _SubNavItem {
  final IconData icon;
  final String label;
  const _SubNavItem({required this.icon, required this.label});
}

class _NavSelection {
  final int topIndex;
  final int? subIndex;
  const _NavSelection(this.topIndex, [this.subIndex]);

  @override
  bool operator ==(Object other) =>
      other is _NavSelection &&
      other.topIndex == topIndex &&
      other.subIndex == subIndex;

  @override
  int get hashCode => Object.hash(topIndex, subIndex);
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  _NavSelection _currentSelection = const _NavSelection(0, 0);
  bool _sidebarCollapsed = false;
  bool _roleLoaded = false;
  Key _bodyKey = UniqueKey(); // ← forces full remount on every nav tap

  @override
  void initState() {
    super.initState();
    _hydrateSession();
  }

  void _hydrateSession() {
    final session = UserSession();
    session.role = html.window.sessionStorage['user_role'] ?? '';
    session.fullName = html.window.sessionStorage['user_fullName'] ?? '';
    session.email = html.window.sessionStorage['user_email'] ?? '';
    session.phoneNumber = html.window.sessionStorage['user_phoneNumber'] ?? '';
    session.token = html.window.sessionStorage['auth_token'] ?? '';
    session.userId =
        int.tryParse(html.window.sessionStorage['user_id'] ?? '0') ?? 0;
    if (mounted) setState(() => _roleLoaded = true);
  }

  String get currentUserRole {
    final role = UserSession().role.isNotEmpty
        ? UserSession().role
        : (html.window.sessionStorage['user_role'] ?? '');
    return role.isNotEmpty ? role : 'USER';
  }

  List<_NavItem> get _navItems {
    final isSuperAdmin = currentUserRole == 'SUPER_ADMIN';

    return [
      const _NavItem(
        icon: Icons.trending_up_rounded,
        label: 'Trading Workspace',
        type: _NavItemType.group,
        children: [
          _SubNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
          _SubNavItem(icon: Icons.remove_red_eye_rounded, label: 'Market Watch'),
          _SubNavItem(icon: Icons.candlestick_chart_rounded, label: 'Charts'),
          _SubNavItem(icon: Icons.receipt_long_rounded, label: 'Orders'),
          _SubNavItem(icon: Icons.pie_chart_outline_rounded, label: 'Positions'),
          _SubNavItem(icon: Icons.account_balance_wallet_rounded, label: 'Holdings'),
        ],
      ),
      const _NavItem(
        icon: Icons.psychology_rounded,
        label: 'Algo Trading',
        type: _NavItemType.group,
        children: [
          _SubNavItem(icon: Icons.auto_awesome_rounded, label: 'Algo Strategies'),
          _SubNavItem(icon: Icons.history_toggle_off_rounded, label: 'Backtesting'),
          _SubNavItem(icon: Icons.shield_outlined, label: 'Paper Trading'),
        ],
      ),
      const _NavItem(
        icon: Icons.content_copy_rounded,
        label: 'Copy Trading',
        type: _NavItemType.group,
        children: [
          _SubNavItem(icon: Icons.people_alt_rounded, label: 'Copy Trading'),
          _SubNavItem(icon: Icons.shopping_basket_rounded, label: 'Baskets'),
        ],
      ),
      _NavItem(
        icon: Icons.construction_rounded,
        label: 'Tools & Accounts',
        type: _NavItemType.group,
        children: [
          const _SubNavItem(icon: Icons.table_chart_rounded, label: 'Options Chain'),
          const _SubNavItem(icon: Icons.link_rounded, label: 'Broker Accounts'),
          const _SubNavItem(icon: Icons.assessment_outlined, label: 'Reports'),
          const _SubNavItem(icon: Icons.notifications_none_rounded, label: 'Notifications'),
          const _SubNavItem(icon: Icons.settings_outlined, label: 'Settings'),
          if (isSuperAdmin) ...[
            const _SubNavItem(icon: Icons.manage_accounts_rounded, label: 'Group Admins'),
            const _SubNavItem(icon: Icons.admin_panel_settings_outlined, label: 'Admin Requests'),
            const _SubNavItem(icon: Icons.person_outline_rounded, label: 'Client Requests'),
          ],
        ],
      ),
    ];
  }

  void _navigateToBrokers() {
    setState(() {
      _currentSelection = const _NavSelection(3, 1);
      _bodyKey = UniqueKey();
    });
  }

  Widget _buildBody() {
    final String? roleStr = html.window.sessionStorage['user_role'];
    final UserRole role = switch (roleStr) {
      'SUPER_ADMIN' => UserRole.SUPER_ADMIN,
      'ADMIN' => UserRole.ADMIN,
      _ => UserRole.USER,
    };
    final int userId =
        int.tryParse(html.window.sessionStorage['user_id'] ?? '0') ?? 0;

    final topIdx = _currentSelection.topIndex;
    final subIdx = _currentSelection.subIndex ?? 0;

    switch (topIdx) {
      case 0: // Trading Workspace
        switch (subIdx) {
          case 0:
            return DashboardTab(userRole: role, onNavigateToBrokers: _navigateToBrokers);
          case 1:
            return const MarketWatchView();
          case 2:
            return const ChartsView();
          case 3:
            return const OrdersView();
          case 4:
            return const PositionsView();
          case 5:
            return const HoldingsView();
          default:
            return DashboardTab(userRole: role, onNavigateToBrokers: _navigateToBrokers);
        }

      case 1: // Algo Trading
        switch (subIdx) {
          case 0:
            return const AlgoStrategiesView();
          case 1:
            return const BacktestingView();
          case 2:
            return const PaperTradingView();
          default:
            return const AlgoStrategiesView();
        }

      case 2: // Copy Trading
        switch (subIdx) {
          case 0:
            return GroupOrdersTab();
          case 1:
            return const BasketOrdersView();
          default:
            return GroupOrdersTab();
        }

      case 3: // Tools & Accounts
        switch (subIdx) {
          case 0:
            return const OptionsChainView();
          case 1:
            return const ChildAccountsTab();
          case 2:
            return const ReportsView();
          case 3:
            return const NotificationsView();
          case 4:
            return const SettingsView();
          case 5: // Group Admins (Super Admin only)
            return const GroupAdminsTab();
          case 6: // Admin Requests (Super Admin only)
            return ApproveUsersTab("admin");
          case 7: // Client Requests (Super Admin only)
            return ApproveUsersTab("client");
          default:
            return const ChildAccountsTab();
        }

      default:
        return DashboardTab(userRole: role, onNavigateToBrokers: _navigateToBrokers);
    }
  }

  Future<void> _handleLogout() async {
    final router = GoRouter.of(context);
    final authBloc = context.read<AuthBloc>();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => const _LogoutConfirmDialog(),
    );

    if (confirmed != true) return;

    html.window.sessionStorage.remove('auth_token');
    html.window.sessionStorage.remove('user_role');
    html.window.sessionStorage.remove('user_fullName');
    html.window.sessionStorage.remove('user_email');
    html.window.sessionStorage.remove('user_phoneNumber');
    html.window.sessionStorage.remove('user_id');
    html.window.sessionStorage.remove('expiresInDays');
    html.window.sessionStorage.remove('expiredFlag');

    UserSession().clear();

    authBloc.add(LogoutRequested());

    router.go(AppRoutes.login);
  }

  String get _initials {
    final name = html.window.sessionStorage['user_fullName'] ?? '';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty)
      return parts[0][0].toUpperCase();
    return 'U';
  }

  Widget _buildTopHeader() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFB45309)),
                    const SizedBox(width: 6),
                    const Text(
                      'PAPER TRADING ACTIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Simulated execution · Live broker orders disabled',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  currentUserRole,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6D28D9),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                UserSession().fullName.isNotEmpty ? UserSession().fullName : 'User',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketTickerStrip() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x3310B981),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.fiber_manual_record, color: Color(0xFF34D399), size: 8),
                  SizedBox(width: 4),
                  Text('MARKET: OPEN (PAPER ENGINE)', style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            _buildTickerItem('NIFTY 50', '24,150.50', '+0.45%', true),
            _buildTickerDivider(),
            _buildTickerItem('BANK NIFTY', '51,820.00', '+0.62%', true),
            _buildTickerDivider(),
            _buildTickerItem('RELIANCE', '2,940.50', '+0.85%', true),
            _buildTickerDivider(),
            _buildTickerItem('HCLTECH', '1,428.10', '0.00%', null),
            _buildTickerDivider(),
            _buildTickerItem('HINDUNILVR', '1,864.60', '+0.30%', true),
            _buildTickerDivider(),
            _buildTickerItem('HDFCBANK', '1,650.00', '-0.20%', false),
            _buildTickerDivider(),
            _buildTickerItem('INFY', '1,785.40', '+1.10%', true),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFFBBF24)),
                  SizedBox(width: 4),
                  Text('Tradetron & AutoTrader Engine: 8 Demats Synchronized', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTickerItem(String symbol, String price, String change, bool? isPositive) {
    final color = isPositive == true
        ? const Color(0xFF34D399)
        : isPositive == false
            ? const Color(0xFFF87171)
            : const Color(0xFF94A3B8);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(symbol, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 10.5, fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Text('₹$price', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Text(change, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildTickerDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Text('|', style: TextStyle(color: Color(0xFF334155), fontSize: 11)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: _kGradientTop)),
      );
    }

    final token = html.window.sessionStorage['auth_token'] ?? '';
    if (token.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.go(AppRoutes.login),
      );
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: _kGradientTop)),
      );
    }

    final double sidebarWidth = _sidebarCollapsed
        ? _kCollapsedWidth
        : _kExpandedWidth;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: Stack(
        children: [
          Row(
            children: [
              _AnimatedSidebar(
                collapsed: _sidebarCollapsed,
                navItems: _navItems,
                currentSelection: _currentSelection,
                initials: _initials,
                userRole: currentUserRole,
                onItemTap: (sel) => setState(() {
                  _currentSelection = sel;
                  _bodyKey =
                      UniqueKey(); // ← new key on every tap → full remount
                }),
                onLogout: _handleLogout,
              ),
              Expanded(
                child: Column(
                  children: [
                    _buildTopHeader(),
                    _buildMarketTickerStrip(),
                    Expanded(
                      child: KeyedSubtree(
                        key: _bodyKey, // ← applied here
                        child: _buildBody(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AnimatedPositioned(
            duration: _kAnimDuration,
            curve: _kAnimCurve,
            left: sidebarWidth - 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ToggleButton(
                collapsed: _sidebarCollapsed,
                onTap: () =>
                    setState(() => _sidebarCollapsed = !_sidebarCollapsed),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Subscription Expiry Card ─────────────────────────────────────────────────

class _SubscriptionExpiryCard extends StatelessWidget {
  final bool collapsed;
  const _SubscriptionExpiryCard({required this.collapsed});

  int get _expiresInDays {
    final raw = html.window.sessionStorage['expiresInDays'] ?? '';
    return int.tryParse(raw) ?? 0;
  }

  Color get _statusColor {
    final days = _expiresInDays;
    if (days <= 5) return const Color(0xFFEF4444);
    if (days <= 15) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String get _statusLabel {
    final days = _expiresInDays;
    if (days <= 0) return 'Expired';
    if (days <= 5) return 'Critical';
    if (days <= 15) return 'Expiring Soon';
    return 'Active';
  }

  IconData get _statusIcon {
    final days = _expiresInDays;
    if (days <= 0) return Icons.cancel_rounded;
    if (days <= 5) return Icons.warning_amber_rounded;
    if (days <= 15) return Icons.hourglass_bottom_rounded;
    return Icons.verified_rounded;
  }

  double get _progress {
    final days = _expiresInDays.clamp(0, 30);
    return days / 30;
  }

  @override
  Widget build(BuildContext context) {
    final days = _expiresInDays;
    final color = _statusColor;

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Tooltip(
          message: days <= 0
              ? 'Subscription Expired'
              : 'Expires in $days day${days == 1 ? '' : 's'}',
          preferBelow: false,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B4B),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: _kGradientTop.withOpacity(0.4)),
          ),
          textStyle: const TextStyle(
            color: Color(0xFFE0E7FF),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Center(child: Icon(_statusIcon, color: color, size: 17)),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: _kAnimDuration,
      curve: _kAnimCurve,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.28), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: color.withOpacity(0.35)),
                ),
                child: Icon(_statusIcon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subscription',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                days <= 0 ? '0' : '$days',
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  days == 1 ? 'day left' : 'days left',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  width: double.infinity,
                  color: Colors.white.withOpacity(0.08),
                ),
                FractionallySizedBox(
                  widthFactor: _progress,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.7), color],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          Text(
            days <= 0
                ? 'Please renew to restore access.'
                : days <= 5
                ? 'Renew soon to avoid disruption.'
                : days <= 15
                ? 'Consider renewing your plan.'
                : 'Your plan is in good standing.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.38),
              fontSize: 9,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Logout Confirmation Dialog ───────────────────────────────────────────────

class _LogoutConfirmDialog extends StatefulWidget {
  const _LogoutConfirmDialog();

  @override
  State<_LogoutConfirmDialog> createState() => _LogoutConfirmDialogState();
}

class _LogoutConfirmDialogState extends State<_LogoutConfirmDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss(bool result) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 380,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.35),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFA78BFA).withOpacity(0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Log Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Are you sure you want to log out of your account?\nYou will need to log in again to access the dashboard.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 13,
                          height: 1.55,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.08),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _DialogButton(
                              label: 'Cancel',
                              isDestructive: false,
                              onTap: () => _dismiss(false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DialogButton(
                              label: 'Log Out',
                              isDestructive: true,
                              onTap: () => _dismiss(true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dialog Button ────────────────────────────────────────────────────────────

class _DialogButton extends StatefulWidget {
  final String label;
  final bool isDestructive;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.isDestructive,
    required this.onTap,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgBase = widget.isDestructive
        ? const Color(0xFF7C3AED)
        : Colors.white.withOpacity(0.07);
    final bgHover = widget.isDestructive
        ? const Color(0xFF6D28D9)
        : Colors.white.withOpacity(0.13);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 44,
          decoration: BoxDecoration(
            color: _hovered ? bgHover : bgBase,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: widget.isDestructive
                  ? const Color(0xFFA78BFA).withOpacity(_hovered ? 0.6 : 0.35)
                  : Colors.white.withOpacity(_hovered ? 0.2 : 0.1),
              width: 1.2,
            ),
            boxShadow: widget.isDestructive && _hovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.isDestructive
                    ? Colors.white
                    : Colors.white.withOpacity(0.75),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Animated Sidebar ─────────────────────────────────────────────────────────

class _AnimatedSidebar extends StatelessWidget {
  final bool collapsed;
  final List<_NavItem> navItems;
  final _NavSelection currentSelection;
  final String initials;
  final String userRole;
  final ValueChanged<_NavSelection> onItemTap;
  final VoidCallback onLogout;

  const _AnimatedSidebar({
    required this.collapsed,
    required this.navItems,
    required this.currentSelection,
    required this.initials,
    required this.userRole,
    required this.onItemTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _kAnimDuration,
      curve: _kAnimCurve,
      width: collapsed ? _kCollapsedWidth : _kExpandedWidth,
      height: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGradientTop, _kGradientMid, _kGradientBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserCard(collapsed: collapsed, initials: initials),
          _SidebarDivider(),
          _SectionLabel(collapsed: collapsed),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: navItems.length,
              itemBuilder: (_, i) {
                final item = navItems[i];

                if (item.type == _NavItemType.group) {
                  return _ExpandableNavItem(
                    icon: item.icon,
                    label: item.label,
                    children: item.children,
                    isGroupActive: currentSelection.topIndex == i,
                    activeSubIndex: currentSelection.topIndex == i
                        ? currentSelection.subIndex
                        : null,
                    collapsed: collapsed,
                    onSubTap: (subIdx) => onItemTap(_NavSelection(i, subIdx)),
                  );
                }

                return _SidebarNavItem(
                  icon: item.icon,
                  label: item.label,
                  isActive:
                      currentSelection.topIndex == i &&
                      currentSelection.subIndex == null,
                  collapsed: collapsed,
                  onTap: () => onItemTap(_NavSelection(i)),
                );
              },
            ),
          ),

          if (userRole != 'SUPER_ADMIN') ...[
            _SidebarDivider(bottom: 4),
            _SubscriptionExpiryCard(collapsed: collapsed),
          ],

          _SidebarDivider(bottom: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
            child: _SidebarNavItem(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              isActive: false,
              isLogout: true,
              collapsed: collapsed,
              onTap: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Expandable Nav Item ──────────────────────────────────────────────────────

class _ExpandableNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<_SubNavItem> children;
  final bool isGroupActive;
  final int? activeSubIndex;
  final bool collapsed;
  final ValueChanged<int> onSubTap;

  const _ExpandableNavItem({
    required this.icon,
    required this.label,
    required this.children,
    required this.isGroupActive,
    required this.activeSubIndex,
    required this.collapsed,
    required this.onSubTap,
  });

  @override
  State<_ExpandableNavItem> createState() => _ExpandableNavItemState();
}

class _ExpandableNavItemState extends State<_ExpandableNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;
  bool _isExpanded = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isGroupActive;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: _isExpanded ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(_ExpandableNavItem old) {
    super.didUpdateWidget(old);
    if (widget.collapsed && _isExpanded) {
      _isExpanded = false;
      _ctrl.reverse();
    } else if (!old.isGroupActive && widget.isGroupActive && !widget.collapsed && !_isExpanded) {
      _isExpanded = true;
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.collapsed) {
      widget.onSubTap(0);
      return;
    }
    setState(() => _isExpanded = !_isExpanded);
    _isExpanded ? _ctrl.forward() : _ctrl.reverse();
  }

  Color get _iconColor {
    if (widget.isGroupActive || _hovered) return Colors.white;
    return const Color(0xFFDDD6FE);
  }

  Color get _bgColor {
    if (widget.isGroupActive) return Colors.white.withOpacity(0.15);
    if (_hovered) return Colors.white.withOpacity(0.09);
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          Tooltip(
            message: widget.collapsed ? widget.label : '',
            preferBelow: false,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _kGradientTop.withOpacity(0.4)),
            ),
            textStyle: const TextStyle(
              color: Color(0xFFE0E7FF),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: InkWell(
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 40,
                  decoration: BoxDecoration(
                    color: _bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 3,
                        margin: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: (widget.isGroupActive && !widget.collapsed)
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      AnimatedContainer(
                        duration: _kAnimDuration,
                        curve: _kAnimCurve,
                        width: widget.collapsed ? 51 : 36,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: widget.isGroupActive
                                  ? Colors.white.withOpacity(0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.icon,
                              color: _iconColor,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          opacity: widget.collapsed ? 0 : 1,
                          child: Text(
                            widget.label,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: _iconColor,
                              fontSize: 12,
                              fontWeight: widget.isGroupActive
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: widget.collapsed ? 0 : 1,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AnimatedRotation(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeInOut,
                            turns: _isExpanded ? 0.25 : 0.0,
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: _iconColor.withOpacity(0.7),
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.collapsed ? 0 : 1,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
                child: Column(
                  children: widget.children.asMap().entries.map((e) {
                    final idx = e.key;
                    final sub = e.value;
                    final isActive = widget.activeSubIndex == idx;
                    return _SubNavItemWidget(
                      icon: sub.icon,
                      label: sub.label,
                      isActive: isActive,
                      onTap: () => widget.onSubTap(idx),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubNavItemWidget extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SubNavItemWidget({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SubNavItemWidget> createState() => _SubNavItemWidgetState();
}

class _SubNavItemWidgetState extends State<_SubNavItemWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 34,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? Colors.white.withOpacity(0.13)
                  : _hovered
                  ? Colors.white.withOpacity(0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: widget.isActive
                  ? Border.all(color: Colors.white.withOpacity(0.18))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.isActive
                        ? const Color(0xFFA78BFA)
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  widget.icon,
                  size: 14,
                  color: widget.isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.55),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: widget.isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.6),
                      fontSize: 11.5,
                      fontWeight: widget.isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sidebar helpers ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final bool collapsed;
  const _SectionLabel({required this.collapsed});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _kAnimDuration,
      curve: _kAnimCurve,
      height: collapsed ? 0 : 20,
      child: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Text(
          'NAVIGATION',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  final double bottom;
  const _SidebarDivider({this.bottom = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: EdgeInsets.fromLTRB(10, 12, 10, bottom > 0 ? bottom : 12),
      color: Colors.white.withOpacity(0.12),
    );
  }
}

class _UserCard extends StatelessWidget {
  final bool collapsed;
  final String initials;
  const _UserCard({required this.collapsed, required this.initials});

  @override
  Widget build(BuildContext context) {
    final name = html.window.sessionStorage['user_fullName'] ?? '';
    final role = html.window.sessionStorage['user_role'] ?? '';

    return AnimatedContainer(
      duration: _kAnimDuration,
      curve: _kAnimCurve,
      margin: const EdgeInsets.fromLTRB(8, 14, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(collapsed ? 0 : 0.1),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: Colors.white.withOpacity(collapsed ? 0 : 0.15),
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: _kAnimDuration,
            curve: _kAnimCurve,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(collapsed ? 17 : 8),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: collapsed ? 0 : 1,
              child: Padding(
                padding: const EdgeInsets.only(left: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.pink.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.pink.withOpacity(0.4)),
                      ),
                      child: Text(
                        role.toUpperCase() == 'SUPER_ADMIN'
                            ? 'Super Admin'
                            : role.toUpperCase() == 'ADMIN'
                            ? 'Admin'
                            : 'User',
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isLogout;
  final bool collapsed;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.collapsed,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  Color get _iconColor {
    if (widget.isLogout) return const Color(0xFFFCA5A5);
    if (widget.isActive || _hovered) return Colors.white;
    return const Color(0xFFDDD6FE);
  }

  Color get _bgColor {
    if (widget.isLogout && _hovered) return Colors.red.withOpacity(0.12);
    if (widget.isActive) return Colors.white.withOpacity(0.15);
    if (_hovered) return Colors.white.withOpacity(0.09);
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: widget.collapsed ? widget.label : '',
        preferBelow: false,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B4B),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _kGradientTop.withOpacity(0.4)),
        ),
        textStyle: const TextStyle(
          color: Color(0xFFE0E7FF),
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: InkWell(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 40,
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: (widget.isActive && !widget.collapsed)
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: _kAnimDuration,
                    curve: _kAnimCurve,
                    width: widget.collapsed ? 51 : 36,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: widget.isActive
                              ? Colors.white.withOpacity(0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(widget.icon, color: _iconColor, size: 17),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: widget.collapsed ? 0 : 1,
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: _iconColor,
                          fontSize: 12,
                          fontWeight: widget.isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Toggle Button ────────────────────────────────────────────────────────────

class _ToggleButton extends StatefulWidget {
  final bool collapsed;
  final VoidCallback onTap;
  const _ToggleButton({required this.collapsed, required this.onTap});

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF6D28D9) : _kGradientTop,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _kGradientMid.withOpacity(_hovered ? 0.65 : 0.4),
                blurRadius: _hovered ? 10 : 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: AnimatedRotation(
              duration: _kAnimDuration,
              curve: _kAnimCurve,
              turns: widget.collapsed ? 0.5 : 0,
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
