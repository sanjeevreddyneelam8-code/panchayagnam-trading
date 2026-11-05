import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:html' as html;
import '../../../app_route/app_route.dart';
import '../../../app_route/user_session.dart';
import '../../../bloc/auth_bloc/auth_event.dart';
import '../../../bloc/auth_bloc/authbloc.dart';
import '../../../constants/colors.dart';
import '../../../service/copy_trading_engine.dart';
import '../../../reusable_widets/payment_gateway_dialog.dart';
import '../../../reusable_widets/signal_bridge_dialog.dart';
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
      // 1. Auto Trading (1st side heading)
      const _NavItem(
        icon: Icons.psychology_rounded,
        label: 'Auto Trading',
        type: _NavItemType.group,
        children: [
          _SubNavItem(icon: Icons.auto_awesome_rounded, label: 'Auto Strategies'),
          _SubNavItem(icon: Icons.history_toggle_off_rounded, label: 'Backtesting'),
          _SubNavItem(icon: Icons.shield_outlined, label: 'Paper Trading'),
          _SubNavItem(icon: Icons.psychology_alt_rounded, label: 'Strategy Builder'),
        ],
      ),

      // 2. Parent Children Trading (2nd side heading)
      const _NavItem(
        icon: Icons.content_copy_rounded,
        label: 'Parent Children Trading',
        type: _NavItemType.group,
        children: [
          _SubNavItem(icon: Icons.people_alt_rounded, label: 'Parent Children Trading'),
          _SubNavItem(icon: Icons.shopping_basket_rounded, label: 'Baskets'),
        ],
      ),

      // 3. Trading Workspace (3rd side heading)
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

      // 4. Option Chain (4th side heading)
      const _NavItem(
        icon: Icons.table_chart_rounded,
        label: 'Option Chain',
        type: _NavItemType.group,
        children: [
          _SubNavItem(icon: Icons.table_chart_rounded, label: 'Option Chain (F&O)'),
          _SubNavItem(icon: Icons.auto_graph_rounded, label: 'Multi-Strike OI & Greeks'),
        ],
      ),

      // 5. Tools and Accounts (5th side heading)
      _NavItem(
        icon: Icons.construction_rounded,
        label: 'Tools & Accounts',
        type: _NavItemType.group,
        children: [
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
      _currentSelection = const _NavSelection(4, 0);
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
      case 0: // 1. Auto Trading
        switch (subIdx) {
          case 0:
            return const AlgoStrategiesView();
          case 1:
            return const BacktestingView();
          case 2:
            return const PaperTradingView();
          case 3:
            return const OptionsChainView(initialTabIndex: 2); // Strategy Builder moved to Auto Trade
          default:
            return const AlgoStrategiesView();
        }

      case 1: // 2. Parent Children Trading
        switch (subIdx) {
          case 0:
            return GroupOrdersTab();
          case 1:
            return const BasketOrdersView();
          default:
            return GroupOrdersTab();
        }

      case 2: // 3. Trading Workspace
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

      case 3: // 4. Option Chain
        switch (subIdx) {
          case 0:
            return const OptionsChainView(initialTabIndex: 0);
          case 1:
            return const OptionsChainView(initialTabIndex: 1);
          default:
            return const OptionsChainView(initialTabIndex: 0);
        }

      case 4: // 5. Tools & Accounts
        switch (subIdx) {
          case 0:
            return const ChildAccountsTab();
          case 1:
            return const ReportsView();
          case 2:
            return const NotificationsView();
          case 3:
            return const SettingsView();
          case 4: // Group Admins (Super Admin only)
            return const GroupAdminsTab();
          case 5: // Admin Requests (Super Admin only)
            return ApproveUsersTab("admin");
          case 6: // Client Requests (Super Admin only)
            return ApproveUsersTab("client");
          default:
            return const ChildAccountsTab();
        }

      default:
        return const AlgoStrategiesView();
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
    return _buildAutoTraderTopBar();
  }

  Widget _buildAutoTraderTopBar() {
    final String userName = UserSession().fullName.isNotEmpty ? UserSession().fullName : 'Sanjeev@.123';
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF031416),
        border: Border(
          bottom: BorderSide(color: Color(0xFF063B32), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Brand Logo & ALGO PRO Badge (Navigation is consolidated in Left Sidebar only)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentSelection = const _NavSelection(0, 0);
                  _bodyKey = UniqueKey();
                });
              },
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.trending_up, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Panchayagnam',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF34D399).withOpacity(0.5)),
                    ),
                    child: const Text(
                      'ALGO PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right: Parent Children Trading Status, Help & Support, Theme Toggle & User Avatar
          Row(
            children: [
              AnimatedBuilder(
                animation: CopyTradingEngine(),
                builder: (context, _) {
                  final engine = CopyTradingEngine();
                  final isActive = engine.isCopyTradingActive;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _currentSelection = const _NavSelection(1, 0); // Jump to Parent Children Trading
                        _bodyKey = UniqueKey();
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF059669).withOpacity(0.18) : const Color(0xFF64748B).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? Icons.sync_alt_rounded : Icons.pause_circle_outline_rounded,
                            size: 14,
                            color: isActive ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isActive ? 'Parent Children Trading: ACTIVE (${engine.activeFollowersCount} Childs)' : 'Parent Children Trading: PAUSED',
                            style: TextStyle(
                              color: isActive ? const Color(0xFF6EE7B7) : const Color(0xFFCBD5E1),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(width: 10),

              // Help & Support Popup
              PopupMenuButton<String>(
                tooltip: 'Help & Knowledge Base',
                offset: const Offset(0, 44),
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                onSelected: (val) {
                  switch (val) {
                    case 'guide':
                      _showUserGuideDialog(context);
                      break;
                    case 'faq':
                      _showKnowledgeBaseDialog(context);
                      break;
                    case 'support':
                      _showSupportDialog(context);
                      break;
                    case 'terms':
                      _showTermsDialog(context);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'guide',
                    child: Row(
                      children: [
                        Icon(Icons.menu_book_outlined, size: 16, color: Color(0xFF94A3B8)),
                        SizedBox(width: 8),
                        Text('User Guide', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'faq',
                    child: Row(
                      children: [
                        Icon(Icons.help_center_outlined, size: 16, color: Color(0xFF94A3B8)),
                        SizedBox(width: 8),
                        Text('Knowledge Base', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'support',
                    child: Row(
                      children: [
                        Icon(Icons.headset_mic_outlined, size: 16, color: Color(0xFF34D399)),
                        SizedBox(width: 8),
                        Text('Live Support', style: TextStyle(color: Color(0xFF34D399), fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'terms',
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 16, color: Color(0xFF94A3B8)),
                        SizedBox(width: 8),
                        Text('Terms & Policy', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.help_outline_rounded, color: Color(0xFF94A3B8), size: 19),
                ),
              ),

              const SizedBox(width: 4),

              IconButton(
                icon: const Icon(Icons.light_mode_outlined, color: Color(0xFF94A3B8), size: 19),
                tooltip: 'Toggle Theme',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Panchayagnam Dark Theme is Active'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),

              const SizedBox(width: 8),

              PopupMenuButton<String>(
                tooltip: 'User Profile & Logout',
                offset: const Offset(0, 44),
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                onSelected: (val) {
                  if (val == 'logout') _handleLogout();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        const Text('8 Demats Connected · Pooled ₹80L', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 16, color: Color(0xFFF87171)),
                        SizedBox(width: 8),
                        Text('Sign Out', style: TextStyle(color: Color(0xFFF87171), fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF10B981),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF94A3B8), size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Interactive AutoTrader Dialogs ──────────────────────────────────────────

  void _showMyIpsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.language_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 10),
            Text('Dedicated Static IP Whitelist', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dedicated Gateway IP: 164.52.203.189', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text('Status: ACTIVE & WHITELISTED · Latency: 12 ms', style: TextStyle(color: Color(0xFF1E40AF), fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Connected Broker Mappings:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              const SizedBox(height: 8),
              _buildBrokerIpStatusRow('Angel One SmartAPI', 'Active & Bound', true),
              _buildBrokerIpStatusRow('Zerodha Kite Connect', 'Active & Bound', true),
              _buildBrokerIpStatusRow('DhanHQ Open API', 'Active & Bound', true),
              _buildBrokerIpStatusRow('Fyers API v3', 'Active & Bound', true),
              _buildBrokerIpStatusRow('Alice Blue ANT API', 'Active & Bound', true),
              _buildBrokerIpStatusRow('Upstox Pro API', 'Active & Bound', true),
              _buildBrokerIpStatusRow('Kotak Neo API', 'Active & Bound', true),
              _buildBrokerIpStatusRow('5Paisa Trade API', 'Active & Bound', true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildBrokerIpStatusRow(String name, String status, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          Row(
            children: [
              Icon(Icons.check_circle, size: 13, color: ok ? const Color(0xFF10B981) : Colors.grey),
              const SizedBox(width: 4),
              Text(status, style: TextStyle(fontSize: 11, color: ok ? const Color(0xFF047857) : Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  void _showClientLibrariesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.file_download_outlined, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 10),
            Text('AutoTrader Developer Hub & SDKs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Integrate Python scripts, TradingView alerts, or REST API hooks into your 8 Demats with sub-15ms replication.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('# Python SDK Installation', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace')),
                    SizedBox(height: 4),
                    Text('pip install autotrader-sdk', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text('from autotrader import AutoTrader\nclient = AutoTrader(token="py_live_9999999999")\n# Broadcast order across 8 Demats\nclient.place_group_order(symbol="NIFTY", qty=50)', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 11.5, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showActivityLogDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.show_chart_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 10),
            Text('Replication Latency & Activity Logs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActivityLogRow('18:44:02.102', 'Group Sync: 8 Accounts', '11 ms', 'SUCCESS'),
              _buildActivityLogRow('18:43:55.840', 'Dedicated IP Whitelist Ping', '9 ms', 'SUCCESS'),
              _buildActivityLogRow('18:42:19.420', 'NSE Scrip Token Fetch (NIFTY)', '14 ms', 'SUCCESS'),
              _buildActivityLogRow('18:40:11.205', 'Panchayagnam Engine Handshake', '12 ms', 'SUCCESS'),
              _buildActivityLogRow('18:38:00.000', 'Paper Execution Core Startup', '8 ms', 'SUCCESS'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildActivityLogRow(String time, String action, String latency, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace')),
          const SizedBox(width: 12),
          Expanded(child: Text(action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
            child: Text(latency, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
          ),
        ],
      ),
    );
  }

  void _showInstrumentsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('NSE / BSE Instrument Finder', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search scrip e.g. NIFTY, BANKNIFTY, RELIANCE...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              _buildInstrumentRow('NIFTY 24DEC 24000 CE', 'NSE_FO', 'Lot: 25 · Tick: 0.05'),
              _buildInstrumentRow('BANKNIFTY 24DEC 51800 PE', 'NSE_FO', 'Lot: 15 · Tick: 0.05'),
              _buildInstrumentRow('RELIANCE EQ', 'NSE_EQ', 'Lot: 1 · Freeze: 50000'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildInstrumentRow(String scrip, String seg, String info) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(scrip, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              Text(info, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
            child: Text(seg, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }

  void _showWhatsNewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.star, color: Color(0xFFEAB308), size: 22),
            SizedBox(width: 10),
            Text("What's New in AutoTrader Web & Panchayagnam", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Panchayagnam Mega Strategy Hub with 9 BUILD & 3 READY-MADE tools', style: TextStyle(fontSize: 13, height: 1.5)),
              Text('• AutoTrader Group Accounts Multiplier & Accounts Hierarchy', style: TextStyle(fontSize: 13, height: 1.5)),
              Text('• Split-screen Login with High-Performance Dark Slate Hero', style: TextStyle(fontSize: 13, height: 1.5)),
              Text('• Dedicated Static IP Whitelist gateway for 8 connected demats', style: TextStyle(fontSize: 13, height: 1.5)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got It')),
        ],
      ),
    );
  }

  void _showPrecautionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 10),
            Text('Regulatory & Trading Precautions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1. Paper Trading Mode is currently ACTIVE to protect your actual capital.', style: TextStyle(fontSize: 13, height: 1.4)),
              SizedBox(height: 8),
              Text('2. All simulated trades reflect live NSE/BSE tick feeds with realistic slippage.', style: TextStyle(fontSize: 13, height: 1.4)),
              SizedBox(height: 8),
              Text('3. Use the Master Kill Switch to halt all strategy executions in one click.', style: TextStyle(fontSize: 13, height: 1.4)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
        ],
      ),
    );
  }

  void _showUserGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 680,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Panchayagnam Pro & AutoTrader User Guide', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Step-by-step operational manual for algo execution and multi-account copy trading.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
              const SizedBox(height: 18),
              _buildGuideStep('1. Connect Demat Accounts', 'Navigate to Tools -> Trading Accounts. Enter API credentials for Dhan, Zerodha, Angel One, etc. All Demat sessions refresh automatically each morning.'),
              const SizedBox(height: 10),
              _buildGuideStep('2. Configure Copy Multipliers', 'Under Copy Trading -> Group Matrix, adjust individual child account multipliers (0.5x to 3.0x). Lot sizes snap automatically to valid NSE contract multiples.'),
              const SizedBox(height: 10),
              _buildGuideStep('3. TradingView & Chartink Webhook Bridge', 'Open Alert Auto -> Signal Bridge. Copy your dedicated webhook URL and Pine Script JSON template. Dispatches execute in sub-15ms parallel fan-out.'),
              const SizedBox(height: 10),
              _buildGuideStep('4. Safety & Auto-Kill Safeguards', 'Set your Daily Max Loss under Settings. If reached, the engine automatically squares off all positions and halts trading to protect capital.'),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  child: const Text('Understood', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideStep(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
          const SizedBox(height: 3),
          Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35)),
        ],
      ),
    );
  }

  void _showDemoVideosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 660,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFDC2626), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Video Tutorials & Architecture Walkthroughs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Interactive video training modules for multi-broker algorithmic execution.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
              const SizedBox(height: 18),
              _buildVideoCard('1. Master-Child Copy Trading Architecture', 'Sub-15ms parallel execution across 8 brokers with individual account multipliers.', '8:45 min', const Color(0xFF2563EB)),
              const SizedBox(height: 10),
              _buildVideoCard('2. Connecting TradingView Pine Script to Dedicated Gateway', 'How to generate webhook URLs, configure secret signatures, and test JSON alerts.', '6:20 min', const Color(0xFF059669)),
              const SizedBox(height: 10),
              _buildVideoCard('3. Option Chain Greeks & Multi-Leg Strategy Wizard', 'Deploying Iron Condors, Straddles, and Bear Put Spreads in a single click.', '11:15 min', const Color(0xFF7C3AED)),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(String title, String desc, String duration, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.play_arrow_rounded, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                const SizedBox(height: 3),
                Text(desc, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFCBD5E1))),
            child: Text(duration, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }

  void _showKnowledgeBaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 680,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.search_rounded, color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Knowledge Base & Technical FAQs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Answers to common queries regarding multi-broker latency and margin pooling.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
              const SizedBox(height: 18),
              _buildFaqItem('How does sub-20ms parallel execution work across 8 brokers?', 'Orders are dispatched concurrently using non-blocking asynchronous worker threads from our dedicated Equinix datacenter gateway (103.159.214.88) without sequential queuing delays.'),
              const SizedBox(height: 10),
              _buildFaqItem('What happens if one child account has insufficient margin?', 'Pre-trade margin checks evaluate funds before dispatch. If a specific follower has a deficit, only that order is rejected with an audible warning, while all other healthy Demats execute smoothly.'),
              const SizedBox(height: 10),
              _buildFaqItem('Are API secrets and Demat passwords stored securely?', 'All credentials are encrypted with bank-grade AES-256-GCM encryption. Session TOTP tokens are held strictly in volatile RAM and never logged in plain text.'),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(String q, String a) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Q: ', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2563EB), fontSize: 13)),
              Expanded(child: Text(q, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)))),
            ],
          ),
          const SizedBox(height: 4),
          Text(a, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35)),
        ],
      ),
    );
  }

  void _showSecurityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 660,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Security Architecture & SEBI Compliance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Military-grade encryption and institutional connection safeguards.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• AES-256-GCM At-Rest Encryption for all Broker Secrets & TOTP Seeds', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    SizedBox(height: 6),
                    Text('• Dedicated Static Whitelisted IP: 103.159.214.88 (Equinix Direct Leased Line)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    SizedBox(height: 6),
                    Text('• Strict Paper Trading Safety Sandbox Active (Prevents accidental live risk)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                    SizedBox(height: 6),
                    Text('• Pre-Trade Margin & Slippage Collar Checks on every single fan-out order', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  child: const Text('Understood', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 620,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Terms of Service & Algorithmic Disclosure', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              const Text(
                '1. Algorithmic and copy trading involves inherent market risk including potential execution slippage, latency fluctuations, and exchange rate-limiting.\n\n'
                '2. Panchayagnam operates as a multi-broker execution router. Users retain 100% legal custody of their respective Demat accounts.\n\n'
                '3. Paper trading simulation mode is provided for strategy verification with live tick feeds and zero financial capital liability.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.45),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  child: const Text('Acknowledge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 620,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Privacy Policy & Data Security', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              const Text(
                'Panchayagnam adheres strictly to SEBI data privacy regulations. Your broker credentials, API secrets, and trading order histories are encrypted and never disclosed, leased, or transmitted to unauthorized third parties.\n\n'
                'Session tokens are held in encrypted volatile memory and terminated upon logout or session expiry.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.45),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGeneralSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 680,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('General Trading & System Preferences', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Configure default order parameters, fast execution skips, and audio feedback.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Default Product Type: MIS (Intraday Auto Square-off)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('ACTIVE 🟢', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF059669))),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Default Order Type: MARKET (Sub-20ms Fast Fill)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('ACTIVE 🟢', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF059669))),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Skip Confirmation Modals: FAST EXECUTION MODE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('ENABLED 🟢', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF059669))),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Audio Chimes on Child Account Replication', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('ACTIVE 🟢', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF059669))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('General preferences saved successfully!'), backgroundColor: Color(0xFF059669), duration: Duration(seconds: 2)),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: const Text('Save Preferences', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSecuritySettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 700,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.lock_rounded, color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Security, 2FA & Dedicated IP Access', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Dedicated IP whitelist, MPIN authorization, and session token health.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Dedicated Gateway IP: 103.159.214.88', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('WHITELISTED 🟢', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF059669))),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Two-Factor Authentication (TOTP)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('ACTIVE 🟢', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF059669))),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Broker Token Auto-Refresh Daemon', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('ALL 8 DEMATS SYNCED 🟢', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF059669))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All remote child sessions verified and refreshed.')));
                    },
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: const Text('Refresh Tokens'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLookAndFeelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 660,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.wb_sunny_outlined, color: Color(0xFF7C3AED), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Look & Feel & High-Density UI Presets', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Customize trading table density, high-contrast themes, and chart engines.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Palette: Bloomberg Terminal Dark Slate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                    SizedBox(height: 6),
                    Text('Row Density: Compact (28px - AutoTrader Web High Density)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                    SizedBox(height: 6),
                    Text('Chart Engine: TradingView WebGL High-Performance Canvas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                    SizedBox(height: 6),
                    Text('Live M2M in Browser Tab: Enabled (+₹42,850.00)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF059669))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Look & Feel settings applied.')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  child: const Text('Apply Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSignalBridgeDialog(BuildContext context) {
    SignalBridgeDialog.show(context);
  }

  void _showSimulatorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 720,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.history_edu_rounded, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Strategy Simulator & Historic NSE Replay Engine', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Tick-by-tick simulation console for NIFTY & BANK NIFTY option strategies.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Simulation Date: 2024-10-31 (Weekly Expiry)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('HISTORIC DATA LOADED 🟢', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF059669))),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Simulated Strategy: Delta-Neutral Iron Condor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('Replay Speed: 10x Fast', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF2563EB))),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Simulated M2M Equity: +₹38,450.00 (+0.77%)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF059669))),
                        Text('Max Drawdown: -0.12%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Replay simulation running in background...')));
                    },
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: const Text('Run Step-by-Step'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Simulation completed! Net profit: +₹38,450.00'), backgroundColor: Color(0xFF059669)),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: const Text('Start Full Replay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMasterAccountsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 720,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Master Account & Copy Leadership Manager', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Designate which account acts as the primary master for group order fan-out.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBFDBFE))),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Master Leader: Dhan Pro Master (Client: 1100345678)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E3A8A))),
                          SizedBox(height: 2),
                          Text('Latency: 11ms • Pooled Followers: 7 Child Demats • Status: ACTIVE LEADER', style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                      child: const Text('ACTIVE LEADER 🟢', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('All manual orders placed in MarketWatch, Charts, Option Chain or incoming webhooks on this master replicate automatically across all 7 child accounts according to their individual multipliers.', style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4)),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOwnersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 720,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.people_alt_rounded, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Multi-Tenant Demat Account Owners', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Verified Demat account owners configured under this Panchayagnam tenant.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    _buildOwnerRow('Sanjeev Reddy', 'ABCDE****F', 'Super Admin', '4 Demats (Dhan, Angel, Zerodha, Motilal)', '₹55,00,000', true),
                    const Divider(height: 1),
                    _buildOwnerRow('Ramesh Kumar', 'FGHIJ****K', 'Investor Client', '2 Demats (Groww, Upstox)', '₹15,00,000', false),
                    const Divider(height: 1),
                    _buildOwnerRow('Vikram Patel', 'KLMNO****P', 'Investor Client', '1 Demat (AliceBlue)', '₹5,00,000', false),
                    const Divider(height: 1),
                    _buildOwnerRow('Priya Sharma', 'PQRST****U', 'Investor Client', '1 Demat (Fyers)', '₹5,00,000', false),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pooled Liquid Capital: ₹80,00,000 across 4 verified Demat owners.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerRow(String name, String pan, String role, String demats, String capital, bool isLead) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: isLead ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            child: Text(name[0], style: TextStyle(color: isLead ? Colors.white : const Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F172A))),
                Text('PAN: $pan • $role', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(demats, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
          ),
          Text(capital, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF059669))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
            child: const Text('KYC VERIFIED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF2563EB),
              child: Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
            ),
            SizedBox(width: 10),
            Text('AutoTrader Support Desk', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Need assistance with your broker API, IP whitelist, or copy trading setup? Our engineers are live online.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 18, color: Color(0xFF2563EB)),
                        SizedBox(width: 10),
                        Text('Phone: 9390076827', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.email_outlined, size: 18, color: Color(0xFF2563EB)),
                        SizedBox(width: 10),
                        Text('Email: support@panchayagnam.com', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Start Chat', style: TextStyle(color: Colors.white)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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
                  Text('Panchayagnam & AutoTrader Engine: 8 Demats Synchronized', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600)),
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
          Positioned(
            bottom: 24,
            right: 24,
            child: _AutoTraderSupportFloatingButton(
              onTap: () => _showSupportDialog(context),
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

          InkWell(
            onTap: () => PaymentGatewayDialog.show(
              context,
              initialPlan: 'Starter Plan (20 Demats)',
              initialAmount: 1999.0,
            ),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.35),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment, size: 12, color: Color(0xFF93C5FD)),
                  SizedBox(width: 4),
                  Text('Renew / Pay Online', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 9.5, fontWeight: FontWeight.bold)),
                ],
              ),
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
              child: Container(
                margin: const EdgeInsets.only(left: 10, right: 10, top: 4, bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E153D), // Distinct dark purple-charcoal inside card
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.14),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
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
                  ? const Color(0xFF6D28D9) // Rich luminous active purple
                  : _hovered
                  ? Colors.white.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: widget.isActive
                  ? Border.all(color: const Color(0xFFA78BFA).withOpacity(0.4), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isActive
                        ? const Color(0xFF34D399) // Glowing neon mint active strip
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 9),
                Icon(
                  widget.icon,
                  size: 14,
                  color: widget.isActive
                      ? const Color(0xFF34D399) // Neon mint active icon
                      : Colors.white.withOpacity(0.7),
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

// ─── AutoTrader Top Nav Helper Classes ────────────────────────────────────────

class _AutoTraderSupportFloatingButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AutoTraderSupportFloatingButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white,
                child: Icon(Icons.support_agent_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              SizedBox(width: 8),
              Text(
                'Support',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
