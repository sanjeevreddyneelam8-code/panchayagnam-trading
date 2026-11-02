import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../../bloc/broker_fetch_balance_bloc/fetch_account_balance_bloc.dart';
import '../../../bloc/dashboard_count_bloc/count_bloc.dart';
import '../../../bloc/dashboard_count_bloc/count_event.dart';
import '../../../bloc/dashboard_count_bloc/count_state.dart';
import '../../../bloc/fetch_user_demat_bloc/fetch_user_demat_bloc.dart';
import '../../../bloc/hot_stock_bloc/hot_stock_block.dart';
import '../../../bloc/hot_stock_bloc/hot_stock_event.dart';
import '../../../bloc/hot_stock_bloc/hot_stock_state.dart';
import '../../../bloc/individual_bloc/individual_execution_bloc.dart';
import '../../../constants/colors.dart';
import '../../../models/hot_stock_model.dart';
import '../../../models/ScripInfo.dart';
import 'dart:html' as html;
import '../../../reusable_widets/order_panel_widget.dart';
import '../../../reusable_widets/payment_gateway_dialog.dart';

enum UserRole { SUPER_ADMIN, ADMIN, USER }

extension UserRoleX on UserRole {
  static UserRole fromString(String? role) {
    switch (role?.toUpperCase()) {
      case 'SUPER_ADMIN':
        return UserRole.SUPER_ADMIN;
      case 'ADMIN':
        return UserRole.ADMIN;
      default:
        return UserRole.USER;
    }
  }
}

class DashboardTab extends StatefulWidget {
  final UserRole userRole;
  final int accId;
  final double availableMargin;
  final VoidCallback? onNavigateToBrokers;

  const DashboardTab({
    super.key,
    required this.userRole,
    this.accId = 0,
    this.availableMargin = 0.0,
    this.onNavigateToBrokers,
  });

  bool get isSuperAdmin => userRole == UserRole.SUPER_ADMIN;
  bool get isAdmin => userRole == UserRole.ADMIN;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  int? pyId = int.tryParse(html.window.sessionStorage['user_id'] ?? '');
  int _carouselIndex = 0;
  late PageController _pageController;
  Timer? _carouselTimer;
  bool _isToday(String dateStr) {
    try {
      final parsed = DateFormat('yyyy-MM-dd').parse(dateStr);
      final now = DateTime.now();
      return parsed.year == now.year &&
          parsed.month == now.month &&
          parsed.day == now.day;
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> _activeAccounts = [];
  String _selectedPortfolioTab = 'Summary';
  String _selectedAccount = 'ALL';
  bool _isGridLayout = false;

  // ─── Demo Trading Engine State ─────────────────────────────────────────────
  double _pooledMargin = 8000000.0;
  double _usedMargin = 14050.0;
  double _realizedPnl = 0.0;
  Timer? _marketPriceTickerTimer;

  // Live Open Positions
  final List<Map<String, dynamic>> _livePositions = [
    {
      'id': 'POS-1',
      'symbol': 'NIFTY 24DEC 24000 CE',
      'product': 'MIS / INTRADAY',
      'qty': 50,
      'avgPrice': 152.00,
      'ltp': 168.20,
      'pnl': 810.00,
      'broker': 'Angel One (ANGEL-28941)',
    },
    {
      'id': 'POS-2',
      'symbol': 'BANKNIFTY 24DEC 51800 PE',
      'product': 'MIS / INTRADAY',
      'qty': 30,
      'avgPrice': 215.00,
      'ltp': 238.50,
      'pnl': 705.00,
      'broker': 'Zerodha Kite (ZERODHA-88219)',
    },
  ];

  // Live Orders Execution History
  final List<Map<String, dynamic>> _liveOrders = [
    {
      'time': '18:42:10',
      'id': '#ORD-984210',
      'scrip': 'NIFTY 24000 CE',
      'side': 'BUY',
      'qty': 50,
      'price': 152.00,
      'status': 'COMPLETE',
      'broker': 'Angel One (ANGEL-28941)',
    },
    {
      'time': '18:42:10',
      'id': '#ORD-984209',
      'scrip': 'BANKNIFTY 51800 PE',
      'side': 'BUY',
      'qty': 30,
      'price': 215.00,
      'status': 'COMPLETE',
      'broker': 'Zerodha Kite (ZERODHA-88219)',
    },
  ];

  // Trade Ticket Form Controllers
  String _tradeSymbol = 'NIFTY 24DEC 24000 CE';
  double _tradeLtp = 168.20;
  String _tradeOrderType = 'MARKET';
  String _tradeProductType = 'MIS';
  int _tradeQty = 50;
  String _tradeBroker = 'All Accounts (8 Demats - Group 1x)';

  // ── Balance fetch tracking ────────────────────────────────────────────────
  final Map<int, _PendingTrade> _pendingTrades = {};
  final Set<int> _loadingBalanceIds = {};
  final Map<int, double> _fetchedBalances = {};

  static const _slides = [
    _Slide(
      gradient: [Color(0xFF7C3AED), Color(0xFF9333EA)],
      title: 'Smart Signals. Better Trades.',
      subtitle: 'Real-time buy/sell alerts across NSE & BSE.',
      tag: 'NEW',
      icon: Icons.auto_awesome_rounded,
    ),
    _Slide(
      gradient: [Color(0xFF1D4ED8), Color(0xFF7C3AED)],
      title: 'Multi-Broker Execution in One Click',
      subtitle: 'Place orders across Angel One, Motilal & more instantly.',
      tag: 'PRO',
      icon: Icons.flash_on_rounded,
    ),
    _Slide(
      gradient: [Color(0xFF0F766E), Color(0xFF1D4ED8)],
      title: 'Group Orders Now 3× Faster',
      subtitle: '500+ orders per second with zero slippage.',
      tag: 'UPDATE',
      icon: Icons.speed_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    if (pyId != null) {
      context.read<DashboardStatsBloc>().add(FetchDashboardStatsEvent(pyId!));
      context.read<FetchUserDematBloc>().add(LoadUserDematAccounts(pyId!));
    }

    // Refresh hot stocks on dashboard entry
    context.read<HotStockBloc>().add(
      FetchHotStocksEvent(
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        category: HotStockCategory.INTRADAY,
      ),
    );

    // Start live market simulated tick updates every 2 seconds
    _marketPriceTickerTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        for (var pos in _livePositions) {
          final double ltp = pos['ltp'] as double;
          // Micro-fluctuation +/- 0.35%
          final delta = ((DateTime.now().millisecond % 10) - 4.5) * 0.12;
          final newLtp = (ltp + delta).clamp(1.0, 99999.0);
          pos['ltp'] = double.parse(newLtp.toStringAsFixed(2));
          final avg = pos['avgPrice'] as double;
          final qty = pos['qty'] as int;
          pos['pnl'] = double.parse(((newLtp - avg) * qty).toStringAsFixed(2));
        }
      });
    });

    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_carouselIndex + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _marketPriceTickerTimer?.cancel();
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context, String currentDate) async {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    DateTime initial;
    try {
      initial = DateFormat('yyyy-MM-dd').parse(currentDate);
    } catch (_) {
      initial = now;
    }
    if (initial.isAfter(todayEnd)) {
      initial = now;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023),
      lastDate: todayEnd,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF7C3AED),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && context.mounted) {
      context.read<HotStockBloc>().add(
        ChangeDateEvent(DateFormat('yyyy-MM-dd').format(picked)),
      );
    }
  }

  void _requestBalanceThenOpenPanel({
    required HotStockModel stock,
    required String side,
    required Map<String, dynamic> account,
    LtpData? ltpData,
  }) {
    final int accountId = account['id'] as int? ?? 0;

    if (_loadingBalanceIds.contains(accountId)) return;

    setState(() {
      _loadingBalanceIds.add(accountId);
      _pendingTrades[accountId] = _PendingTrade(
        stock: stock,
        side: side,
        account: account,
        ltpData: ltpData,
      );
    });

    context.read<FetchAccountBalanceBloc>().add(LoadAccountBalance(accountId));
  }

  void _openOrderPanelWithBalance({
    required HotStockModel stock,
    required String side,
    required Map<String, dynamic> account,
    required double availableMargin,
    LtpData? ltpData,
  }) {
    if (!mounted) return;

    final scrip = ScripInfo(
      tradingSymbol: stock.companyName,
      exchange: 'NSE',
      symbolToken: stock.symbolToken ?? '',
    );

    final int selectedAccId = account['id'] as int? ?? 0;

    final ltpDataResolved =
        ltpData ??
        LtpData(
          ltp: stock.price,
          open: stock.price,
          high: stock.price,
          low: stock.price,
          close: stock.price,
          change: stock.changePercent ?? 0.0,
          percentChange: stock.changePercent ?? 0.0,
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<IndividualExecutionBloc>()),
        ],
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: OrderPanelWidget(
            scrip: scrip,
            ltpData: ltpDataResolved,
            side: side,
            accId: selectedAccId,
            availableMargin: availableMargin,
          ),
        ),
      ),
    );
  }

  double _parseMargin(String raw) {
    final cleaned = raw.replaceAll('₹', '').replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // ── FetchUserDemat ─────────────────────────────────────────────────
        BlocListener<FetchUserDematBloc, FetchUserDematState>(
          listener: (context, state) {
            if (state is FetchUserDematLoaded) {
              final accounts = state.accounts
                  .map((item) {
                    return <String, dynamic>{
                      'id': item.id,
                      'name': item.userName,
                      'clientCode': item.clientId,
                      'broker': item.brokerType,
                      'portfolioValue':
                          '₹ ${item.availableCash.toStringAsFixed(2)}',
                      'status': item.active ? 'ACTIVE' : 'INACTIVE',
                      'isOwn': item.isOwnAccount ?? false,
                    };
                  })
                  .where((a) => a['status'] == 'ACTIVE')
                  .toList();

              accounts.sort((a, b) {
                final aOwn = a['isOwn'] == true ? 0 : 1;
                final bOwn = b['isOwn'] == true ? 0 : 1;
                return aOwn.compareTo(bOwn);
              });

              setState(() => _activeAccounts = accounts);
            }
          },
        ),

        // ── FetchAccountBalance ────────────────────────────────────────────
        BlocListener<FetchAccountBalanceBloc, FetchAccountBalanceState>(
          listener: (context, state) {
            if (state is FetchAccountBalanceLoaded) {
              final int accountId = state.pyBrokerId;
              final double balance = state.availableCash;

              setState(() {
                _loadingBalanceIds.remove(accountId);
                _fetchedBalances[accountId] = balance;
              });

              final pending = _pendingTrades.remove(accountId);
              if (pending != null) {
                _openOrderPanelWithBalance(
                  stock: pending.stock,
                  side: pending.side,
                  account: pending.account,
                  availableMargin: balance,
                  ltpData: pending.ltpData,
                );
              }
            } else if (state is FetchAccountBalanceError) {
              final int accountId = state.pyBrokerId;

              setState(() => _loadingBalanceIds.remove(accountId));

              final pending = _pendingTrades.remove(accountId);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Could not fetch balance: ${state.message}. Opening panel with ₹0.',
                  ),
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );

              if (pending != null) {
                _openOrderPanelWithBalance(
                  stock: pending.stock,
                  side: pending.side,
                  account: pending.account,
                  availableMargin: 0.0,
                  ltpData: pending.ltpData,
                );
              }
            }
          },
        ),

        // ── HotStockBloc operation feedback ───────────────────────────────
        BlocListener<HotStockBloc, HotStockState>(
          listenWhen: (prev, curr) =>
              curr.operationStatus != prev.operationStatus &&
              curr.operationStatus != OperationStatus.idle &&
              curr.operationStatus != OperationStatus.loading,
          listener: (context, state) {
            final isSuccess = state.operationStatus == OperationStatus.success;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationMessage ?? ''),
                backgroundColor: isSuccess
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
            context.read<HotStockBloc>().add(const ClearOperationResultEvent());
          },
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. AutoTrader Connect Broker Hero Card (Image 2)
            _buildAutoTraderConnectHeroCard(),
            const SizedBox(height: 16),

            // 2. AutoTrader Multi-Account Toolbar (Image 2)
            _buildAutoTraderMultiAccountToolbar(),
            const SizedBox(height: 14),

            // 3. AutoTrader 9-Tab Portfolio Navigation Bar (Image 2)
            _buildAutoTraderPortfolioTabs(),
            const SizedBox(height: 16),

            // 4. View corresponding to Selected Portfolio Tab
            _buildSelectedPortfolioTabContent(),
          ],
        ),
      ),
    );
  }

  // ── Right panel ────────────────────────────────────────────────────────────


  // ─── AutoTrader Web Portfolio Command Center Components (Image 2) ──────────

  Widget _buildAutoTraderConnectHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connect a broker to see your portfolio here',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'There is nothing to show yet, because no broker account is linked to your AutoTrader account. Once one is linked, your positions, orders and holdings appear on this screen and update live.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                _buildSetupStep('1. Add your broker account, using the API details your broker gives you.'),
                const SizedBox(height: 8),
                _buildSetupStep(
                  '2. Take a dedicated IP address.',
                  subtext:
                      'Brokers only accept API orders from one fixed address, so this is needed before any order can be placed. You can buy one from us or bring your own. Either way it costs money and is separate from your free trial. You see every option and its price before you choose.',
                ),
                const SizedBox(height: 8),
                _buildSetupStep('3. Mark the account Live. Your portfolio fills in.'),
                const SizedBox(height: 14),
                // Status badge indicating 8 connected accounts
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                      SizedBox(width: 6),
                      Text(
                        '8 Demats Synced (Angel One, Zerodha, Dhan, Fyers, AliceBlue, Upstox, Kotak, 5Paisa) · Pooled Margin: ₹80,00,000',
                        style: TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 30),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      PaymentGatewayDialog.show(
                        context,
                        initialPlan: 'Dedicated Static IP',
                        initialAmount: 1500.0,
                        onPaymentSuccess: (amount, plan, txn) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Dedicated IP Activated! Ref: $txn'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                        },
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.language_rounded, size: 16),
                    label: const Text('Buy Dedicated IP (₹1,500)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (widget.onNavigateToBrokers != null) {
                        widget.onNavigateToBrokers!();
                      } else {
                        _showConnectBrokerDialog(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Add your broker account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'It takes a few minutes, and we walk\nyou through it broker by broker.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetupStep(String title, {String? subtext}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtext != null) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              subtext,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAutoTraderMultiAccountToolbar() {
    return Row(
      children: [
        // Dropdown: [ All Accounts (8 Demats) ⌄ ]
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF2563EB), width: 1.2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedAccount,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB), size: 20),
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Accounts (8 Demats - Pooled ₹80L)')),
                DropdownMenuItem(value: 'ANGEL', child: Text('Angel One (ANGEL-28941)')),
                DropdownMenuItem(value: 'ZERODHA', child: Text('Zerodha Kite (ZERODHA-88219)')),
                DropdownMenuItem(value: 'DHAN', child: Text('DhanHQ (DHAN-44912)')),
                DropdownMenuItem(value: 'FYERS', child: Text('Fyers (FYERS-77312)')),
                DropdownMenuItem(value: 'ALICE', child: Text('Alice Blue (ALICE-10293)')),
                DropdownMenuItem(value: 'UPSTOX', child: Text('Upstox Pro (UPSTOX-55109)')),
                DropdownMenuItem(value: 'KOTAK', child: Text('Kotak Neo (KOTAK-99214)')),
                DropdownMenuItem(value: '5PAISA', child: Text('5Paisa (PAISA-66321)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedAccount = val);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),

        // [ ⟳ ] Refresh button
        _buildToolbarIconButton(
          icon: Icons.refresh_rounded,
          isPrimary: true,
          tooltip: 'Refresh Portfolio & Balances',
          onTap: () {
            if (pyId != null) {
              context.read<DashboardStatsBloc>().add(FetchDashboardStatsEvent(pyId!));
              context.read<FetchUserDematBloc>().add(LoadUserDematAccounts(pyId!));
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Portfolio refreshed · All 8 Demats synchronized'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        const SizedBox(width: 6),

        // [ ⌘ ] Hotkeys button
        _buildToolbarIconButton(
          icon: Icons.keyboard_command_key_rounded,
          tooltip: 'AutoTrader Hotkeys',
          onTap: () => _showHotkeysModal(context),
        ),
        const SizedBox(width: 6),

        // [ ⊞ ] Grid layout button
        _buildToolbarIconButton(
          icon: Icons.grid_view_rounded,
          tooltip: 'Toggle Multi-Account Grid',
          onTap: () {
            setState(() => _isGridLayout = !_isGridLayout);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isGridLayout ? 'Grid Layout: Enabled' : 'Compact Layout: Enabled'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
        const SizedBox(width: 6),

        // [ ⚙ ] Configure button
        _buildToolbarIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Configure Portfolio View',
          onTap: () => _showConfigureModal(context),
        ),

        const Spacer(),

        // [ 💳 Payment Gateway / Add Funds ]
        ElevatedButton.icon(
          onPressed: () {
            PaymentGatewayDialog.show(
              context,
              initialPlan: 'Add Trading Margin (₹50,000)',
              initialAmount: 50000.0,
              onPaymentSuccess: (amt, plan, txn) {
                setState(() {
                  _pooledMargin += amt;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Funds Added: ₹${amt.toInt()} to Pooled Margin!'),
                    backgroundColor: const Color(0xFF059669),
                  ),
                );
              },
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: const Icon(Icons.account_balance_wallet_rounded, size: 15, color: Colors.white),
          label: const Text('Add Funds (Gateway)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),

        const SizedBox(width: 8),

        // [ ⛶ ] Fullscreen toggle
        _buildToolbarIconButton(
          icon: Icons.fullscreen_rounded,
          tooltip: 'Toggle Fullscreen',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Fullscreen Mode toggled'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAutoTraderPortfolioTabs() {
    final tabs = [
      ('Summary', Icons.dashboard_outlined),
      ('Positions', Icons.pie_chart_outline_rounded),
      ('Orders', Icons.shopping_bag_outlined),
      ('GTT', Icons.access_time_rounded),
      ('Margins', Icons.account_balance_wallet_outlined),
      ('Holdings', Icons.inventory_2_outlined),
      ('MarketWatch', Icons.show_chart_rounded),
      ('Trade', Icons.flash_on_rounded),
      ('Notifications', Icons.notifications_none_rounded),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((t) {
            final isSelected = _selectedPortfolioTab == t.$1;
            return InkWell(
              onTap: () => setState(() => _selectedPortfolioTab = t.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      t.$2,
                      size: 15,
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      t.$1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAutoTraderLiveSummaryKPIBanner() {
    double totalUnrealizedPnl = 0.0;
    for (var pos in _livePositions) {
      totalUnrealizedPnl += (pos['pnl'] as num).toDouble();
    }
    final double netTotalPnl = _realizedPnl + totalUnrealizedPnl;
    final isNetPositive = netTotalPnl >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 28),
          _buildKPIMetric(
            "TODAY'S TRADES · AT P&L",
            '${_liveOrders.length} Fills',
            'today\'s fills only · live',
          ),
          const SizedBox(width: 32),
          _buildKPIMetric(
            'NET · AT P&L',
            (isNetPositive ? '+₹ ' : '-₹ ') + netTotalPnl.abs().toStringAsFixed(2),
            'auto-trade · live',
            valueColor: isNetPositive ? const Color(0xFF047857) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 32),
          _buildKPIMetric(
            'NET · M2M / PNL',
            (totalUnrealizedPnl >= 0 ? '+₹ ' : '-₹ ') + totalUnrealizedPnl.abs().toStringAsFixed(2),
            'PnL · live open positions',
            valueColor: totalUnrealizedPnl >= 0 ? const Color(0xFF047857) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 32),
          _buildKPIMetric(
            'MARGIN',
            '₹ ${_formatINRDouble(_pooledMargin - _usedMargin)}',
            'free of ${_formatINRDouble(_pooledMargin)} pooled',
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                'UPDATED Live',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
            ],
          ),
        ],
      ),
    );
  }

  String _formatINRDouble(double val) {
    final s = val.toInt().toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i != 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    return '$buf,$last3';
  }

  Widget _buildKPIMetric(String title, String value, String subtitle, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: valueColor ?? const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPortfolioTabContent() {
    switch (_selectedPortfolioTab) {
      case 'Positions':
        return _buildPositionsTableView();
      case 'Orders':
        return _buildOrdersTableView();
      case 'GTT':
        return _buildGTTTableView();
      case 'Margins':
        return _buildMarginsTableView();
      case 'Holdings':
        return _buildHoldingsTableView();
      case 'MarketWatch':
        return _buildMarketWatchTableView();
      case 'Trade':
        return _buildTradeTicketView();
      case 'Notifications':
        return _buildNotificationsStreamView();
      case 'Summary':
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAutoTraderLiveSummaryKPIBanner(),
            const SizedBox(height: 18),
            _buildCarousel(),
            const SizedBox(height: 16),
            SizedBox(
              height: 350,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFEDE9FE),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: buildHotStocksSection(context),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: _buildRightStatGrid()),
                ],
              ),
            ),
          ],
        );
    }
  }

  // ─── Demo Trading Actions ──────────────────────────────────────────────────

  void _executeDemoTrade({
    required String symbol,
    required String side,
    required int qty,
    required double price,
    String product = 'MIS / INTRADAY',
    String? broker,
  }) {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final orderId = "#ORD-${now.millisecondsSinceEpoch.toString().substring(now.millisecondsSinceEpoch.toString().length - 6)}";
    final chosenBroker = broker ?? _tradeBroker;

    setState(() {
      // 1. Add to orders log
      _liveOrders.insert(0, {
        'time': timeStr,
        'id': orderId,
        'scrip': symbol,
        'side': side,
        'qty': qty,
        'price': price,
        'status': 'COMPLETE',
        'broker': chosenBroker,
      });

      // 2. Update positions
      final existingIndex = _livePositions.indexWhere((p) => p['symbol'] == symbol);
      if (existingIndex >= 0) {
        if (side == 'BUY') {
          final oldQty = _livePositions[existingIndex]['qty'] as int;
          final oldAvg = _livePositions[existingIndex]['avgPrice'] as double;
          final newQty = oldQty + qty;
          final newAvg = ((oldAvg * oldQty) + (price * qty)) / newQty;
          _livePositions[existingIndex]['qty'] = newQty;
          _livePositions[existingIndex]['avgPrice'] = double.parse(newAvg.toStringAsFixed(2));
          _livePositions[existingIndex]['ltp'] = price;
          _livePositions[existingIndex]['pnl'] = double.parse(((price - newAvg) * newQty).toStringAsFixed(2));
        } else {
          // Sell reduces or closes
          final oldQty = _livePositions[existingIndex]['qty'] as int;
          final oldAvg = _livePositions[existingIndex]['avgPrice'] as double;
          if (qty >= oldQty) {
            _realizedPnl += (price - oldAvg) * oldQty;
            _livePositions.removeAt(existingIndex);
          } else {
            _realizedPnl += (price - oldAvg) * qty;
            final newQty = oldQty - qty;
            _livePositions[existingIndex]['qty'] = newQty;
            _livePositions[existingIndex]['pnl'] = double.parse(((price - oldAvg) * newQty).toStringAsFixed(2));
          }
        }
      } else {
        if (side == 'BUY') {
          _livePositions.insert(0, {
            'id': 'POS-${now.millisecondsSinceEpoch}',
            'symbol': symbol,
            'product': product,
            'qty': qty,
            'avgPrice': price,
            'ltp': price,
            'pnl': 0.0,
            'broker': chosenBroker,
          });
        }
      }

      // 3. Update margin reservation
      _usedMargin += (price * qty * 0.20); // 20% margin
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Trade Executed: $side $qty $symbol @ ₹$price ($chosenBroker)'),
        backgroundColor: side == 'BUY' ? const Color(0xFF059669) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _squareOffPosition(Map<String, dynamic> pos) {
    final symbol = pos['symbol'] as String;
    final qty = pos['qty'] as int;
    final avgPrice = pos['avgPrice'] as double;
    final ltp = pos['ltp'] as double;
    final broker = pos['broker'] as String;
    final realized = (ltp - avgPrice) * qty;

    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final orderId = "#ORD-${now.millisecondsSinceEpoch.toString().substring(now.millisecondsSinceEpoch.toString().length - 6)}";

    setState(() {
      _livePositions.remove(pos);
      _realizedPnl += realized;
      _usedMargin = (_usedMargin - (avgPrice * qty * 0.20)).clamp(0.0, double.infinity);

      _liveOrders.insert(0, {
        'time': timeStr,
        'id': orderId,
        'scrip': symbol,
        'side': 'SELL (SQ OFF)',
        'qty': qty,
        'price': ltp,
        'status': 'COMPLETE',
        'broker': broker,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Position Closed: $symbol · Realized P&L: ₹${realized.toStringAsFixed(2)}'),
        backgroundColor: realized >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
      ),
    );
  }

  void _squareOffAllPositions() {
    if (_livePositions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No open positions to square off.')),
      );
      return;
    }

    final toRemove = List<Map<String, dynamic>>.from(_livePositions);
    for (var pos in toRemove) {
      _squareOffPosition(pos);
    }
  }

  // ─── 1. Positions View ─────────────────────────────────────────────────────

  Widget _buildPositionsTableView() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Open Positions (Simulated AutoTrader Engine)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${_livePositions.length} Active', style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _selectedPortfolioTab = 'Trade'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text('Place New Trade', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _squareOffAllPositions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                    label: const Text('Square Off All', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_livePositions.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline, size: 40, color: Color(0xFF10B981)),
                  const SizedBox(height: 10),
                  const Text('No Open Positions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Go to the Trade tab or MarketWatch to execute demo orders across your 8 Demats.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => setState(() => _selectedPortfolioTab = 'Trade'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                    child: const Text('Open Trade Terminal', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ] else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('SYMBOL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('PRODUCT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('NET QTY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('AVG PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('LTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('P&L', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('BROKER DEMAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
                rows: _livePositions.map((pos) {
                  final pnl = (pos['pnl'] as num).toDouble();
                  final isProfit = pnl >= 0;
                  return DataRow(cells: [
                    DataCell(Text(pos['symbol'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                    DataCell(Text(pos['product'], style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)))),
                    DataCell(Text('+${pos['qty']}', style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 12.5))),
                    DataCell(Text('₹ ${(pos['avgPrice'] as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₹ ${(pos['ltp'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        const SizedBox(width: 4),
                        Icon(isProfit ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: isProfit ? const Color(0xFF047857) : const Color(0xFFDC2626), size: 18),
                      ],
                    )),
                    DataCell(Text(
                      (isProfit ? '+₹ ' : '-₹ ') + pnl.abs().toStringAsFixed(2),
                      style: TextStyle(
                        color: isProfit ? const Color(0xFF047857) : const Color(0xFFDC2626),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    )),
                    DataCell(Text(pos['broker'], style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)))),
                    DataCell(OutlinedButton(
                      onPressed: () => _squareOffPosition(pos),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      child: const Text('Exit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 2. Orders View ────────────────────────────────────────────────────────

  Widget _buildOrdersTableView() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Execution Logs · 8 Connected Broker Demats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${_liveOrders.length} Total Orders Executed', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('TIME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('ORDER ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('SCRIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('SIDE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('BROKER DEMAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: _liveOrders.map((ord) {
                final isBuy = ord['side'].toString().contains('BUY');
                return DataRow(cells: [
                  DataCell(Text(ord['time'], style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'))),
                  DataCell(Text(ord['id'], style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
                  DataCell(Text(ord['scrip'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isBuy ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(ord['side'], style: TextStyle(color: isBuy ? const Color(0xFF047857) : const Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 11)),
                  )),
                  DataCell(Text('${ord['qty']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataCell(Text('₹ ${(ord['price'] as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                    child: Text(ord['status'], style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 10.5)),
                  )),
                  DataCell(Text(ord['broker'], style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. Trade View (Rapid Order Placement Ticket) ───────────────────────────

  Widget _buildTradeTicketView() {
    final quickScrips = [
      ('NIFTY 24DEC 24000 CE', 168.20, 'OPT'),
      ('NIFTY 24DEC 24000 PE', 112.50, 'OPT'),
      ('BANKNIFTY 24DEC 51800 CE', 310.00, 'OPT'),
      ('BANKNIFTY 24DEC 51800 PE', 238.50, 'OPT'),
      ('RELIANCE EQ', 2940.50, 'EQ'),
      ('HDFCBANK EQ', 1650.00, 'EQ'),
      ('INFY EQ', 1785.40, 'EQ'),
      ('TCS EQ', 4120.00, 'EQ'),
    ];

    final double estMargin = _tradeLtp * _tradeQty * 0.20;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Rapid Trade Execution Terminal (Demo & Live)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.speed, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text('Sub-15ms Replication · Pooled Margin: ₹ ${_formatINRDouble(_pooledMargin)}', style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 1. Select Scrip / Instrument
          const Text('1. SELECT INSTRUMENT / CONTRACT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickScrips.map((item) {
              final isSelected = _tradeSymbol == item.$1;
              return InkWell(
                onTap: () => setState(() {
                  _tradeSymbol = item.$1;
                  _tradeLtp = item.$2;
                }),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.$1, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text('₹ ${item.$2}', style: TextStyle(color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 11.5)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // 2. Broker Demat & Quantity
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('2. EXECUTION DEMAT ACCOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _tradeBroker,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'All Accounts (8 Demats - Group 1x)', child: Text('All Accounts (8 Demats - Broadcast Multiplier 1x)')),
                            DropdownMenuItem(value: 'Angel One (ANGEL-28941)', child: Text('Angel One (ANGEL-28941)')),
                            DropdownMenuItem(value: 'Zerodha Kite (ZERODHA-88219)', child: Text('Zerodha Kite (ZERODHA-88219)')),
                            DropdownMenuItem(value: 'DhanHQ (DHAN-44912)', child: Text('DhanHQ (DHAN-44912)')),
                            DropdownMenuItem(value: 'Fyers (FYERS-77312)', child: Text('Fyers (FYERS-77312)')),
                            DropdownMenuItem(value: 'Alice Blue (ALICE-10293)', child: Text('Alice Blue (ALICE-10293)')),
                            DropdownMenuItem(value: 'Upstox Pro (UPSTOX-55109)', child: Text('Upstox Pro (UPSTOX-55109)')),
                            DropdownMenuItem(value: 'Kotak Neo (KOTAK-99214)', child: Text('Kotak Neo (KOTAK-99214)')),
                            DropdownMenuItem(value: '5Paisa (PAISA-66321)', child: Text('5Paisa (PAISA-66321)')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _tradeBroker = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('3. QUANTITY / LOTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_tradeQty > 25) setState(() => _tradeQty -= 25);
                          },
                          icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF64748B)),
                        ),
                        Expanded(
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text('$_tradeQty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _tradeQty += 25),
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('4. PRODUCT & ORDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      alignment: Alignment.centerLeft,
                      child: const Text('MIS · MARKET ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Margin Required Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text('Approx. Margin Required: ₹ ${_formatINRDouble(estMargin)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const SizedBox(width: 14),
                    Text('Available Pooled Margin: ₹ ${_formatINRDouble(_pooledMargin - _usedMargin)}', style: const TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('LTP: ₹ $_tradeLtp', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Buy & Sell Big Action Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _executeDemoTrade(
                        symbol: _tradeSymbol,
                        side: 'BUY',
                        qty: _tradeQty,
                        price: _tradeLtp,
                        product: 'MIS / INTRADAY',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    label: Text(
                      'BUY $_tradeSymbol @ ₹ $_tradeLtp',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _executeDemoTrade(
                        symbol: _tradeSymbol,
                        side: 'SELL',
                        qty: _tradeQty,
                        price: _tradeLtp,
                        product: 'MIS / INTRADAY',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 20),
                    label: Text(
                      'SELL $_tradeSymbol @ ₹ $_tradeLtp',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 4. MarketWatch View ───────────────────────────────────────────────────

  Widget _buildMarketWatchTableView() {
    final watchScrips = [
      ('NIFTY 50', 'NSE_INDEX', 24150.50, '+0.45%', true),
      ('BANK NIFTY', 'NSE_INDEX', 51820.00, '+0.62%', true),
      ('FINNIFTY', 'NSE_INDEX', 23410.00, '+0.38%', true),
      ('RELIANCE', 'NSE_EQ', 2940.50, '+0.85%', true),
      ('HDFCBANK', 'NSE_EQ', 1650.00, '-0.20%', false),
      ('INFY', 'NSE_EQ', 1785.40, '+1.10%', true),
      ('TCS', 'NSE_EQ', 4120.00, '+0.15%', true),
      ('HCLTECH', 'NSE_EQ', 1428.10, '0.00%', null),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('AutoTrader Live MarketWatch (1-Click Trading Enabled)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Text('Click B or S to execute instantaneous group orders', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('SCRIP / SYMBOL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('SEGMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('LTP (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('CHANGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('QUICK BUY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('QUICK SELL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: watchScrips.map((item) {
                final isPositive = item.$5 == true;
                return DataRow(cells: [
                  DataCell(Text(item.$1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  DataCell(Text(item.$2, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                  DataCell(Text('₹ ${item.$3}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  DataCell(Text(
                    item.$4,
                    style: TextStyle(
                      color: item.$5 == true ? const Color(0xFF047857) : item.$5 == false ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  )),
                  DataCell(ElevatedButton(
                    onPressed: () => _executeDemoTrade(symbol: item.$1, side: 'BUY', qty: 25, price: item.$3),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
                    child: const Text('B (Buy)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  )),
                  DataCell(ElevatedButton(
                    onPressed: () => _executeDemoTrade(symbol: item.$1, side: 'SELL', qty: 25, price: item.$3),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
                    child: const Text('S (Sell)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  )),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 5. Margins View (With Payment Gateway Integration) ─────────────────────

  Widget _buildMarginsTableView() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pooled Margin Breakdown across 8 Demats (Total: ₹ ${_formatINRDouble(_pooledMargin)})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('Available: ₹ ${_formatINRDouble(_pooledMargin - _usedMargin)} · Utilized: ₹ ${_formatINRDouble(_usedMargin)}', style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  PaymentGatewayDialog.show(
                    context,
                    initialPlan: 'Add Trading Margin (₹50,000)',
                    initialAmount: 50000.0,
                    onPaymentSuccess: (amt, plan, txn) {
                      setState(() {
                        _pooledMargin += amt;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Deposit Confirmed! ₹${amt.toInt()} added to Pooled Margin. Ref: $txn'),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.add_card_rounded, size: 16, color: Colors.white),
                label: const Text('＋ Add Funds / Deposit Margin', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('BROKER DEMAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('ALLOCATED MARGIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('USED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('AVAILABLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: [
                DataRow(cells: [const DataCell(Text('Angel One (ANGEL-28941)')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('₹ 0.00')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('ACTIVE', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)))]),
                DataRow(cells: [const DataCell(Text('Zerodha Kite (ZERODHA-88219)')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('₹ 0.00')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('ACTIVE', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)))]),
                DataRow(cells: [const DataCell(Text('DhanHQ (DHAN-44912)')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('₹ 0.00')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('ACTIVE', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)))]),
                DataRow(cells: [const DataCell(Text('Fyers (FYERS-77312)')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('₹ 0.00')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('ACTIVE', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)))]),
                DataRow(cells: [const DataCell(Text('Alice Blue (ALICE-10293)')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('₹ 0.00')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('ACTIVE', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)))]),
                DataRow(cells: [const DataCell(Text('Upstox Pro (UPSTOX-55109)')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('₹ 0.00')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('ACTIVE', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)))]),
                DataRow(cells: [const DataCell(Text('Kotak Neo (KOTAK-99214)')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('₹ 0.00')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('ACTIVE', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)))]),
                DataRow(cells: [const DataCell(Text('5Paisa (PAISA-66321)')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('₹ 0.00')), DataCell(Text('₹ ${_formatINRDouble(_pooledMargin / 8)}')), const DataCell(Text('ACTIVE', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)))]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGTTTableView() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good-Till-Triggered (GTT) Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          SizedBox(height: 12),
          Text('No active GTT orders. Orders placed via GTT monitor price ticks 24/7 and execute without manual intervention.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildHoldingsTableView() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Equity & Demat Holdings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          SizedBox(height: 12),
          Text('Long term delivery portfolios across all connected Demat accounts are pooled and monitored here.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNotificationsStreamView() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Real-time Order & Risk Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          SizedBox(height: 12),
          Text('All API responses, execution fills, and risk parameter checks stream here in real time.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        ],
      ),
    );
  }
  void _showHotkeysModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('AutoTrader Keyboard Hotkeys', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('Buy Order Ticket'), trailing: Chip(label: Text('B'))),
            ListTile(title: Text('Sell Order Ticket'), trailing: Chip(label: Text('S'))),
            ListTile(title: Text('Square Off All Positions'), trailing: Chip(label: Text('Shift + Q'))),
            ListTile(title: Text('Cancel All Open Orders'), trailing: Chip(label: Text('Shift + X'))),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showConfigureModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Configure Portfolio Columns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Customize which Demats, margins, and Greeks are visible in the portfolio view.', style: TextStyle(fontSize: 13)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
      ),
    );
  }

  void _showConnectBrokerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Add Broker Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('All 8 broker accounts are currently connected and operational in Paper Mode.', style: TextStyle(fontSize: 13)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Widget _buildRightStatGrid() {
    return BlocBuilder<DashboardStatsBloc, DashboardCountState>(
      builder: (context, state) {
        final cards = _getStatCards(state);

        if (state.isLoading) return _buildShimmerGrid(cards.length.clamp(1, 6));
        if (state.isFailure && state.stats == null) {
          return _buildStatsError(context, state.errorMessage);
        }

        return _StatCardGrid(cards: cards);
      },
    );
  }

  Widget _buildShimmerGrid(int count) {
    return _StatCardGrid(
      cards: List.generate(count, (_) => null),
      isShimmer: true,
    );
  }

  (String, String, bool) _getMarketStatus() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)); // IST
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return ('Closed', 'Weekend · Normal hours closed', false);
    }
    final minutes = now.hour * 60 + now.minute;
    if (minutes >= 9 * 60 && minutes < 9 * 60 + 15) {
      return ('Pre-Open', '09:00 - 09:15 IST (excl. holidays)', true);
    }
    if (minutes >= 9 * 60 + 15 && minutes < 15 * 60 + 30) {
      return ('Open (Hours)', 'Normal hours · Excl. holidays', true);
    }
    return ('Closed', 'Outside normal hours · Excl. holidays', false);
  }

  List<_StatCardConfig> _getStatCards(DashboardCountState state) {
    final s = state.stats;
    final (marketLabel, marketDetail, marketOpen) = _getMarketStatus();

    final marketCard = _StatCardConfig(
      icon: Icons.schedule_rounded,
      iconColor: marketOpen ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
      iconBg: marketOpen ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
      accentColor: marketOpen ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
      title: 'Market Hours (IST)',
      value: marketLabel,
      trend: marketDetail,
      trendUp: marketOpen,
      showTrendBadge: true,
    );

    final paperTradingCard = _StatCardConfig(
      icon: Icons.shield_outlined,
      iconColor: const Color(0xFF7C3AED),
      iconBg: const Color(0xFFEDE9FE),
      accentColor: const Color(0xFF7C3AED),
      title: 'Paper Trading',
      value: 'Simulation Mode',
      trend: 'Zero Real Funds at Risk',
      trendUp: true,
    );

    final algoCard = _StatCardConfig(
      icon: Icons.psychology_rounded,
      iconColor: const Color(0xFF3B82F6),
      iconBg: const Color(0xFFDBEAFE),
      accentColor: const Color(0xFF3B82F6),
      title: 'Algo Strategies',
      value: '0 active',
      trend: 'Setup in Algo Strategies',
      trendUp: false,
    );

    switch (widget.userRole) {
      case UserRole.SUPER_ADMIN:
        return [
          marketCard,
          _StatCardConfig(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF0F766E),
            iconBg: const Color(0xFFCCFBF1),
            accentColor: const Color(0xFF0F766E),
            title: 'Broker Accounts',
            value: s != null
                ? (s.totalBrokerAccounts == 0 ? '0 connected' : _fmt(s.totalBrokerAccounts))
                : '—',
            trend: s != null && s.totalBrokerAccounts == 0
                ? 'No broker connected'
                : 'Linked brokers',
            trendUp: s != null && s.totalBrokerAccounts > 0,
            subPills: s != null && s.totalBrokerAccounts > 0
                ? [
                    '${s.angelOneAccounts} Angel',
                    '${s.motilalAccounts} Motilal',
                    '${s.profitMartAccounts} ProfitMart',
                    if (s.dhanAccounts > 0) '${s.dhanAccounts} Dhan',
                    '${s.goodWillAccounts} GoodWill',
                  ]
                : [],
            actionLabel: s != null && s.totalBrokerAccounts == 0 ? 'Connect Broker' : null,
            onAction: widget.onNavigateToBrokers,
          ),
          paperTradingCard,
          algoCard,
          _StatCardConfig(
            icon: Icons.workspaces_rounded,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFD1FAE5),
            accentColor: const Color(0xFF10B981),
            title: 'Copy Groups',
            value: s != null ? _fmt(s.groupCount) : '—',
            trend: 'Active order groups',
            trendUp: true,
          ),
          _StatCardConfig(
            icon: Icons.people_alt_rounded,
            iconColor: const Color(0xFF7C3AED),
            iconBg: const Color(0xFFEDE9FE),
            accentColor: const Color(0xFF7C3AED),
            title: 'Total Users',
            value: s != null ? _fmt(s.totalUsers) : '—',
            trend: 'Registered traders',
            trendUp: true,
          ),
        ];
      case UserRole.ADMIN:
        return [
          marketCard,
          _StatCardConfig(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF0F766E),
            iconBg: const Color(0xFFCCFBF1),
            accentColor: const Color(0xFF0F766E),
            title: 'Broker Accounts',
            value: s != null
                ? (s.totalBrokerAccounts == 0 ? '0 connected' : _fmt(s.totalBrokerAccounts))
                : '—',
            trend: s != null && s.totalBrokerAccounts == 0
                ? 'No broker connected'
                : 'Linked brokers',
            trendUp: s != null && s.totalBrokerAccounts > 0,
            subPills: s != null && s.totalBrokerAccounts > 0
                ? [
                    '${s.angelOneAccounts} Angel',
                    '${s.motilalAccounts} Motilal',
                    '${s.profitMartAccounts} ProfitMart',
                    if (s.dhanAccounts > 0) '${s.dhanAccounts} Dhan',
                    '${s.goodWillAccounts} GoodWill',
                  ]
                : [],
            actionLabel: s != null && s.totalBrokerAccounts == 0 ? 'Connect Broker' : null,
            onAction: widget.onNavigateToBrokers,
          ),
          paperTradingCard,
          algoCard,
          _StatCardConfig(
            icon: Icons.workspaces_rounded,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFD1FAE5),
            accentColor: const Color(0xFF10B981),
            title: 'Copy Groups',
            value: s != null ? _fmt(s.groupCount) : '—',
            trend: 'Active order groups',
            trendUp: true,
          ),
        ];
      case UserRole.USER:
        return [
          marketCard,
          _StatCardConfig(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF7C3AED),
            iconBg: const Color(0xFFEDE9FE),
            accentColor: const Color(0xFF7C3AED),
            title: 'Broker Accounts',
            value: s != null
                ? (s.totalBrokerAccounts == 0 ? '0 connected' : _fmt(s.totalBrokerAccounts))
                : '—',
            trend: s != null && s.totalBrokerAccounts == 0
                ? 'No broker connected'
                : 'Your linked brokers',
            trendUp: s != null && s.totalBrokerAccounts > 0,
            subPills: s != null && s.totalBrokerAccounts > 0
                ? [
                    '${s.angelOneAccounts} Angel',
                    '${s.motilalAccounts} Motilal',
                    '${s.profitMartAccounts} ProfitMart',
                    if (s.dhanAccounts > 0) '${s.dhanAccounts} Dhan',
                    '${s.goodWillAccounts} GoodWill',
                  ]
                : [],
            actionLabel: s != null && s.totalBrokerAccounts == 0 ? 'Connect Broker' : null,
            onAction: widget.onNavigateToBrokers,
          ),
          paperTradingCard,
          algoCard,
        ];
    }
  }

  String _fmt(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  Widget _buildStatsError(BuildContext context, String? message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFEF4444),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message ?? 'Failed to load stats',
              style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
            ),
          ),
          InkWell(
            onTap: () {
              if (pyId != null) {
                context.read<DashboardStatsBloc>().add(
                  FetchDashboardStatsEvent(pyId!),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Carousel ───────────────────────────────────────────────────────────────

  Widget _buildCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _carouselIndex = i),
            itemBuilder: (_, i) => _CarouselSlide(slide: _slides[i]),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            final active = i == _carouselIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : const Color(0xFFDDD6FE),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Hot Stocks Section ─────────────────────────────────────────────────────

  Widget buildHotStocksSection(BuildContext context) {
    return BlocBuilder<HotStockBloc, HotStockState>(
      builder: (context, state) {
        return SizedBox(
          height: MediaQuery.of(context).size.height / 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFEF4444),
                    size: 30,
                  ),
                  const Text(
                    'Model Portfolio',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _CategoryChips(
                    selected: state.selectedCategory,
                    onSelect: (cat) => context.read<HotStockBloc>().add(
                      ChangeCategoryEvent(cat),
                    ),
                  ),
                  const Spacer(),
                  _DatePill(
                    date: state.selectedDate,
                    onTap: () => _pickDate(context, state.selectedDate),
                  ),
                  if (widget.isSuperAdmin && _isToday(state.selectedDate)) ...[
                    const SizedBox(width: 8),
                    _AddButton(onTap: () => _openAddDialog(context, state)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: state.isLoadingStocks
                    ? _buildLoadingSkeleton()
                    : state.loadError != null
                    ? _buildErrorWithEmpty(context, state)
                    : state.stocks.where((s) => s.isActive).isEmpty
                    ? _buildEmpty(context, state)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.isFallback && state.fallbackDate != null)
                            _buildFallbackBanner(state.fallbackDate!),
                          Expanded(
                            child: _buildStockTable(context, state),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEDE9FE), width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: 4,
          separatorBuilder: (_, __) =>
              Container(height: 1, color: const Color(0xFFF0EEFF)),
          itemBuilder: (_, i) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            color: i.isOdd ? const Color(0xFFFAF9FF) : Colors.white,
            child: Row(
              children: [
                _Shimmer(width: 32, height: 32, radius: 8),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Shimmer(width: 70, height: 10, radius: 4),
                      const SizedBox(height: 5),
                      _Shimmer(width: 100, height: 8, radius: 4),
                    ],
                  ),
                ),
                _Shimmer(width: 50, height: 10, radius: 4),
                const SizedBox(width: 12),
                _Shimmer(width: 40, height: 10, radius: 4),
                const SizedBox(width: 12),
                _Shimmer(width: 52, height: 22, radius: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWithEmpty(BuildContext context, HotStockState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFCDD2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.loadError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
              InkWell(
                onTap: () => context.read<HotStockBloc>().add(
                  ChangeDateEvent(state.selectedDate),
                ),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildEmptyWithAction(context, state),
      ],
    );
  }

  Widget _buildFallbackBanner(String fallbackDate) {
    String formattedDate = fallbackDate;
    try {
      final parsed = DateTime.parse(fallbackDate);
      formattedDate = DateFormat('dd MMM yyyy').format(parsed);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history_rounded,
            color: Color(0xFFD97706),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF92400E),
                ),
                children: [
                  const TextSpan(
                    text: 'Recent recommendations — dated ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: formattedDate,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(
                    text: ' (No recommendations published for selected date)',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, HotStockState state) {
    final category = state.selectedCategory;
    final isToday = _isToday(state.selectedDate);

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFF9FAFB),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.trending_up_rounded,
                color: Color(0xFF9CA3AF),
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No stock recommendations for ${category.label}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'There are no active stock recommendations published for this date or category.\nTry selecting another category or date.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            if (widget.isSuperAdmin && isToday) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _openAddDialog(context, state),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Add Recommendation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWithAction(BuildContext context, HotStockState state) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Icon(
              Icons.inbox_outlined,
              color: Color(0xFFD1D5DB),
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              'No ${state.selectedCategory.label} stocks for this date',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            if (widget.isSuperAdmin && _isToday(state.selectedDate)) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _openAddDialog(context, state),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Add Stock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStockTable(BuildContext context, HotStockState state) {
    final activeStocks = state.stocks.where((s) => s.isActive).toList();
    final hasAdmin = widget.isSuperAdmin;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0D9FF), width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            // ── Header row ───────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF3EEFF), Color(0xFFEEE8FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 28,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: _ColLabel('SYMBOL'),
                      ),
                    ),
                    const _TableVLine(headerLine: true),
                    Expanded(
                      flex: 18,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: _ColLabel('PRICE', right: true),
                      ),
                    ),
                    const _TableVLine(headerLine: true),
                    Expanded(
                      flex: 16,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: _ColLabel('CHG%', right: true),
                      ),
                    ),
                    const _TableVLine(headerLine: true),
                    Expanded(
                      flex: 18,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: _ColLabel('TARGET', right: true),
                      ),
                    ),
                    const _TableVLine(headerLine: true),
                    Expanded(
                      flex: 16,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: _ColLabel('SIGNAL', right: true),
                      ),
                    ),
                    const _TableVLine(headerLine: true),
                    Expanded(
                      flex: 22,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: _ColLabel('TRADE', right: true),
                      ),
                    ),
                    if (hasAdmin) ...[
                      const _TableVLine(headerLine: true),
                      Expanded(
                        flex: 12,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: _ColLabel('ACTION', right: true),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(height: 1.5, color: const Color(0xFFCCC5F5)),
            // ── Data rows ────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: activeStocks.length,
                separatorBuilder: (_, __) =>
                    Container(height: 1, color: const Color(0xFFEDE9FE)),
                itemBuilder: (_, i) => _StockRow(
                  stock: activeStocks[i],
                  isLast: i == activeStocks.length - 1,
                  shade: i.isOdd,
                  isSuperAdmin: hasAdmin,
                  activeAccounts: _activeAccounts,
                  loadingBalanceIds: _loadingBalanceIds,
                  onEdit: () =>
                      _openEditDialog(context, state, activeStocks[i]),
                  onDelete: () => _confirmDelete(context, activeStocks[i]),
                  onAccountSelected: (account, side) =>
                      _requestBalanceThenOpenPanel(
                        stock: activeStocks[i],
                        side: side,
                        account: account,
                        ltpData: LtpData(
                          ltp: activeStocks[i].price,
                          open: activeStocks[i].price,
                          high: activeStocks[i].price,
                          low: activeStocks[i].price,
                          close: activeStocks[i].price,
                          change: activeStocks[i].changePercent ?? 0.0,
                          percentChange: activeStocks[i].changePercent ?? 0.0,
                        ),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddDialog(BuildContext context, HotStockState state) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<HotStockBloc>()),
          BlocProvider.value(value: context.read<IndividualExecutionBloc>()),
        ],
        child: _HotStockFormDialog(
          title: 'Add Hot Stock',
          pyId: pyId ?? 0,
          defaultCategory: state.selectedCategory,
          onSubmit: (req) =>
              context.read<HotStockBloc>().add(AddHotStockEvent(req)),
        ),
      ),
    );
  }

  void _openEditDialog(
    BuildContext context,
    HotStockState state,
    HotStockModel stock,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<HotStockBloc>()),
          BlocProvider.value(value: context.read<IndividualExecutionBloc>()),
        ],
        child: _HotStockFormDialog(
          title: 'Edit Stock',
          pyId: pyId ?? 0,
          defaultCategory: stock.category,
          existingStock: stock,
          onSubmit: (req) =>
              context.read<HotStockBloc>().add(UpdateHotStockEvent(req)),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, HotStockModel stock) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Remove Stock',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove ${stock.symbol} from hot stocks? This is a soft delete — it will still appear in date history.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<HotStockBloc>().add(
                DeleteHotStockEvent(stock.stockId),
              );
            },
            child: const Text(
              'Remove',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending trade helper model
// ─────────────────────────────────────────────────────────────────────────────

class _PendingTrade {
  final HotStockModel stock;
  final String side;
  final Map<String, dynamic> account;
  final LtpData? ltpData;

  const _PendingTrade({
    required this.stock,
    required this.side,
    required this.account,
    this.ltpData,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatCardGrid
// ─────────────────────────────────────────────────────────────────────────────

class _StatCardGrid extends StatelessWidget {
  final List<_StatCardConfig?> cards;
  final bool isShimmer;

  const _StatCardGrid({required this.cards, this.isShimmer = false});

  @override
  Widget build(BuildContext context) {
    final count = cards.length;

    if (count == 0) return const SizedBox.shrink();

    if (count == 1) {
      return _buildCard(cards[0], horizontal: true);
    }

    if (count == 2) {
      return Column(
        children: [
          Expanded(child: _buildCard(cards[0], horizontal: true)),
          const SizedBox(height: 10),
          Expanded(child: _buildCard(cards[1], horizontal: true)),
        ],
      );
    }

    if (count == 3) {
      return Row(
        children: [
          Expanded(child: _buildCard(cards[0])),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildCard(cards[1])),
                const SizedBox(height: 10),
                Expanded(child: _buildCard(cards[2])),
              ],
            ),
          ),
        ],
      );
    }

    if (count == 4) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildCard(cards[0])),
                const SizedBox(width: 10),
                Expanded(child: _buildCard(cards[1])),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildCard(cards[2])),
                const SizedBox(width: 10),
                Expanded(child: _buildCard(cards[3])),
              ],
            ),
          ),
        ],
      );
    }

    if (count == 5) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildCard(cards[0])),
                const SizedBox(width: 10),
                Expanded(child: _buildCard(cards[1])),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildCard(cards[2])),
                const SizedBox(width: 10),
                Expanded(child: _buildCard(cards[3])),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildCard(cards[4], horizontal: true)),
        ],
      );
    }

    return Column(
      children: [
        for (int row = 0; row < 3; row++) ...[
          if (row > 0) const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildCard(cards[row * 2])),
                const SizedBox(width: 10),
                Expanded(child: _buildCard(cards[row * 2 + 1])),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCard(_StatCardConfig? config, {bool horizontal = false}) {
    if (isShimmer || config == null) {
      return _ShimmerCard(horizontal: horizontal);
    }
    return _StatCard(config: config, horizontal: horizontal);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatCardConfig
// ─────────────────────────────────────────────────────────────────────────────

class _StatCardConfig {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color accentColor;
  final String title;
  final String value;
  final String trend;
  final bool trendUp;
  final bool showTrendBadge;
  final List<String> subPills;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatCardConfig({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.accentColor,
    required this.title,
    required this.value,
    required this.trend,
    this.trendUp = true,
    this.showTrendBadge = false,
    this.subPills = const [],
    this.actionLabel,
    this.onAction,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatCard
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final _StatCardConfig config;
  final bool horizontal;

  const _StatCard({required this.config, this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0EEFF), width: 1),
        boxShadow: [
          BoxShadow(
            color: config.accentColor.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: horizontal ? _buildHorizontal() : _buildVertical(),
    );
  }

  Widget _buildHorizontal() {
    return Row(
      children: [
        Container(width: 4, color: config.accentColor),
        Container(
          width: 72,
          color: config.iconBg.withOpacity(0.35),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: config.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(config.icon, color: config.iconColor, size: 20),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  config.title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  config.value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: config.accentColor,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(height: 0.5, color: const Color(0xFFEEEEEE)),
                const SizedBox(height: 6),
                if (config.actionLabel != null && config.onAction != null)
                  InkWell(
                    onTap: config.onAction,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: config.accentColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: config.accentColor.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_link_rounded, size: 13, color: config.accentColor),
                          const SizedBox(width: 4),
                          Text(
                            config.actionLabel!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: config.accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (config.subPills.isNotEmpty)
                  _SubPillRow(pills: config.subPills)
                else
                  _TrendRow(
                    label: config.trend,
                    up: config.trendUp,
                    showBadge: config.showTrendBadge,
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Icon(
            config.icon,
            size: 48,
            color: config.accentColor.withOpacity(0.07),
          ),
        ),
      ],
    );
  }

  Widget _buildVertical() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 3, color: config.accentColor),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: config.iconBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          config.icon,
                          color: config.iconColor,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          config.title,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    config.value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: config.accentColor,
                      height: 1.0,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(height: 0.5, color: const Color(0xFFEEEEEE)),
                      const SizedBox(height: 5),
                      if (config.actionLabel != null && config.onAction != null)
                        InkWell(
                          onTap: config.onAction,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: config.accentColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: config.accentColor.withOpacity(0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_link_rounded, size: 12, color: config.accentColor),
                                const SizedBox(width: 4),
                                Text(
                                  config.actionLabel!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: config.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (config.subPills.isNotEmpty)
                        _SubPillRow(pills: config.subPills)
                      else
                        _TrendRow(
                          label: config.trend,
                          up: config.trendUp,
                          showBadge: config.showTrendBadge,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShimmerCard
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerCard extends StatelessWidget {
  final bool horizontal;
  const _ShimmerCard({this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      clipBehavior: Clip.antiAlias,
      child: horizontal ? _buildHorizontal() : _buildVertical(),
    );
  }

  Widget _buildHorizontal() {
    return Row(
      children: [
        Container(width: 4, color: const Color(0xFFEDE9FE)),
        Container(
          width: 72,
          color: const Color(0xFFF5F3FF),
          child: Center(child: _Shimmer(width: 40, height: 40, radius: 10)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Shimmer(width: 80, height: 10, radius: 4),
                const SizedBox(height: 8),
                _Shimmer(width: 60, height: 26, radius: 6),
                const SizedBox(height: 10),
                _Shimmer(width: 120, height: 8, radius: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVertical() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _Shimmer(width: 28, height: 28, radius: 8),
              const SizedBox(width: 8),
              _Shimmer(width: 70, height: 9, radius: 4),
            ],
          ),
          _Shimmer(width: 50, height: 22, radius: 6),
          _Shimmer(width: 110, height: 8, radius: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AccountPickerDialog
// ─────────────────────────────────────────────────────────────────────────────

class _AccountPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  final String side;
  final String stockSymbol;
  final Set<int> loadingBalanceIds;
  final void Function(Map<String, dynamic> account) onSelect;

  const _AccountPickerDialog({
    required this.accounts,
    required this.side,
    required this.stockSymbol,
    required this.loadingBalanceIds,
    required this.onSelect,
  });

  @override
  State<_AccountPickerDialog> createState() => _AccountPickerDialogState();
}

class _AccountPickerDialogState extends State<_AccountPickerDialog> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.accounts);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = widget.accounts.where((a) {
        return a['name'].toString().toLowerCase().contains(q) ||
            a['clientCode'].toString().toLowerCase().contains(q) ||
            a['broker'].toString().toLowerCase().contains(q);
      }).toList();
    });
  }

  Color get _sideColor =>
      widget.side == 'BUY' ? const Color(0xFF059669) : const Color(0xFFDC2626);

  Color get _sideBg =>
      widget.side == 'BUY' ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);

  Color get _sideLightBg =>
      widget.side == 'BUY' ? const Color(0xFFF0FDF4) : const Color(0xFFFFF5F5);

  // ── Updated broker color mapping (removed Upstox, added ProfitMart & GoodWill) ──
  Color _brokerColor(String broker) {
    final b = broker.toUpperCase();
    if (b.contains('ANGEL')) return const Color(0xFF7C3AED);
    if (b.contains('MOTILAL')) return const Color(0xFF1D4ED8);
    if (b.contains('PROFITMART') ||
        b.contains('PROFIT_MART') ||
        b.contains('PROFIT MART')) {
      return const Color(0xFF0891B2);
    }
    if (b.contains('GOODWILL') ||
        b.contains('GOOD_WILL') ||
        b.contains('GOOD WILL')) {
      return const Color(0xFF059669);
    }
    if (b.contains('ZERODHA')) return const Color(0xFF16A34A);
    return const Color(0xFF6B7280);
  }

  // ── Updated short broker name mapping ──
  String _shortBroker(String broker) {
    final b = broker.toUpperCase();
    if (b.contains('ANGEL')) return 'Angel';
    if (b.contains('MOTILAL')) return 'Motilal';
    if (b.contains('PROFITMART') ||
        b.contains('PROFIT_MART') ||
        b.contains('PROFIT MART')) {
      return 'ProfitMart';
    }
    if (b.contains('GOODWILL') ||
        b.contains('GOOD_WILL') ||
        b.contains('GOOD WILL')) {
      return 'GoodWill';
    }
    if (b.contains('ZERODHA')) return 'Zerodha';
    return broker.length > 9 ? broker.substring(0, 9) : broker;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Container(
        width: 360,
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _sideColor.withOpacity(0.18),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: _sideBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(color: _sideColor.withOpacity(0.20)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _sideColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      widget.side == 'BUY'
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.side} ${widget.stockSymbol}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _sideColor,
                          ),
                        ),
                        Text(
                          'Select a broker account to place order',
                          style: TextStyle(
                            fontSize: 11,
                            color: _sideColor.withOpacity(0.70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _sideColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: _sideColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search bar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _filter,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1F2937),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search by name, code, broker…',
                    hintStyle: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 9),
                    isDense: true,
                  ),
                ),
              ),
            ),

            // ── Account count badge ────────────────────────────────────
            if (_filtered.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _sideColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${_filtered.length} active account${_filtered.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _sideColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Account list ───────────────────────────────────────────
            if (_filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 36,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No active accounts found',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                  shrinkWrap: true,
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final acc = _filtered[i];
                    final isOwn = acc['isOwn'] == true;
                    final broker = acc['broker'].toString();
                    final brokerColor = _brokerColor(broker);
                    final accountId = acc['id'] as int? ?? 0;
                    final isLoading = widget.loadingBalanceIds.contains(
                      accountId,
                    );

                    return InkWell(
                      onTap: isLoading
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.onSelect(acc);
                            },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isOwn ? const Color(0xFFFFFBEB) : _sideLightBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isOwn
                                ? const Color(0xFFFCD34D).withOpacity(0.6)
                                : _sideColor.withOpacity(0.12),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _sideColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  acc['name'].toString().isNotEmpty
                                      ? acc['name'].toString()[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _sideColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Name + code
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isOwn) ...[
                                        const Icon(
                                          Icons.star_rounded,
                                          size: 12,
                                          color: Color(0xFFD97706),
                                        ),
                                        const SizedBox(width: 3),
                                      ],
                                      Expanded(
                                        child: Text(
                                          acc['name'].toString(),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1F2937),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    acc['clientCode'].toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Broker tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: brokerColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: brokerColor.withOpacity(0.30),
                                ),
                              ),
                              child: Text(
                                _shortBroker(broker),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: brokerColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Loading spinner OR arrow
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _sideColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: isLoading
                                  ? Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _sideColor,
                                      ),
                                    )
                                  : Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 12,
                                      color: _sideColor,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SubPillRow
// ─────────────────────────────────────────────────────────────────────────────

class _SubPillRow extends StatelessWidget {
  final List<String> pills;
  const _SubPillRow({required this.pills});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: pills.map((label) {
        Color pillBg, pillFg, pillBorder;
        if (label.contains('approved')) {
          pillBg = const Color(0xFFD1FAE5);
          pillFg = const Color(0xFF059669);
          pillBorder = const Color(0xFF6EE7B7);
        } else if (label.contains('rejected')) {
          pillBg = const Color(0xFFFEE2E2);
          pillFg = const Color(0xFFDC2626);
          pillBorder = const Color(0xFFFCA5A5);
        } else if (label.contains('ProfitMart')) {
          pillBg = const Color(0xFFE0F2FE);
          pillFg = const Color(0xFF0891B2);
          pillBorder = const Color(0xFFBAE6FD);
        } else if (label.contains('GoodWill')) {
          pillBg = const Color(0xFFD1FAE5);
          pillFg = const Color(0xFF059669);
          pillBorder = const Color(0xFF6EE7B7);
        } else {
          pillBg = const Color(0xFFF5F3FF);
          pillFg = const Color(0xFF7C3AED);
          pillBorder = const Color(0xFFDDD6FE);
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: pillBorder, width: 0.7),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: pillFg,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TrendRow
// ─────────────────────────────────────────────────────────────────────────────

class _TrendRow extends StatelessWidget {
  final String label;
  final bool up;
  final bool showBadge;
  const _TrendRow({
    required this.label,
    required this.up,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = up ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final parts = label.split(' ');

    if (showBadge && parts.isNotEmpty) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  up
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 9,
                  color: color,
                ),
                const SizedBox(width: 2),
                Text(
                  parts.first,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              parts.skip(1).join(' '),
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 11,
          color: color,
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TableVLine
// ─────────────────────────────────────────────────────────────────────────────

class _TableVLine extends StatelessWidget {
  final bool headerLine;
  const _TableVLine({this.headerLine = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      color: headerLine ? const Color(0xFFD4C9FF) : const Color(0xFFEDE9FE),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DatePill
// ─────────────────────────────────────────────────────────────────────────────

class _DatePill extends StatelessWidget {
  final String date;
  final VoidCallback onTap;
  const _DatePill({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String display = date;
    try {
      final parsed = DateFormat('yyyy-MM-dd').parse(date);
      final today = DateTime.now();
      if (parsed.year == today.year &&
          parsed.month == today.month &&
          parsed.day == today.day) {
        display = 'Today';
      } else {
        display = DateFormat('d MMM').format(parsed);
      }
    } catch (_) {}

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 11,
              color: Color(0xFF7C3AED),
            ),
            const SizedBox(width: 5),
            Text(
              display,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AddButton
// ─────────────────────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.30),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add_rounded, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              'Add Stock',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CategoryChips
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final HotStockCategory selected;
  final void Function(HotStockCategory) onSelect;
  const _CategoryChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: HotStockCategory.values.map((cat) {
          final isSelected = cat == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onSelect(cat),
              borderRadius: BorderRadius.circular(5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFFDDD6FE),
                  ),
                ),
                child: Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF7C3AED),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StockRow
// ─────────────────────────────────────────────────────────────────────────────

class _StockRow extends StatelessWidget {
  final HotStockModel stock;
  final bool isLast;
  final bool shade;
  final bool isSuperAdmin;
  final List<Map<String, dynamic>> activeAccounts;
  final Set<int> loadingBalanceIds;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(Map<String, dynamic> account, String side)
  onAccountSelected;

  const _StockRow({
    required this.stock,
    required this.isLast,
    required this.shade,
    required this.isSuperAdmin,
    required this.activeAccounts,
    required this.loadingBalanceIds,
    required this.onEdit,
    required this.onDelete,
    required this.onAccountSelected,
  });

  void _showAccountPicker(BuildContext context, String side) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => _AccountPickerDialog(
        accounts: activeAccounts,
        side: side,
        stockSymbol: stock.symbol,
        loadingBalanceIds: loadingBalanceIds,
        onSelect: (account) => onAccountSelected(account, side),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: shade ? const Color(0xFFFAF9FF) : Colors.white,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SYMBOL
            Expanded(
              flex: 28,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      stock.symbol,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      stock.companyName,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9CA3AF),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const _TableVLine(),
            // PRICE
            Expanded(
              flex: 18,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '₹${stock.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ),
            ),
            const _TableVLine(),
            // CHG%
            Expanded(
              flex: 16,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      stock.direction == HotStockDirection.UP
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      color: stock.direction == HotStockDirection.UP
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      size: 16,
                    ),
                    Text(
                      stock.changePercent != null
                          ? '${stock.changePercent!.toStringAsFixed(1)}%'
                          : '-',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: stock.direction == HotStockDirection.UP
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const _TableVLine(),
            // TARGET
            Expanded(
              flex: 18,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '₹${stock.target.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
            const _TableVLine(),
            // SIGNAL
            Expanded(
              flex: 16,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _signalColor(stock.signal).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      stock.signal.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _signalColor(stock.signal),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const _TableVLine(),
            // TRADE buttons
            Expanded(
              flex: 22,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _TradeBtn(
                      label: 'B',
                      color: const Color(0xFF059669),
                      bg: const Color(0xFFD1FAE5),
                      labelColor: const Color(0xFF059669),
                      tooltip: 'Buy ${stock.symbol}',
                      onTap: () => _showAccountPicker(context, 'BUY'),
                    ),
                    const SizedBox(width: 5),
                    _TradeBtn(
                      label: 'S',
                      color: const Color(0xFFDC2626),
                      bg: const Color(0xFFFEE2E2),
                      labelColor: const Color(0xFFDC2626),
                      tooltip: 'Sell ${stock.symbol}',
                      onTap: () => _showAccountPicker(context, 'SELL'),
                    ),
                  ],
                ),
              ),
            ),
            if (isSuperAdmin) ...[
              const _TableVLine(),
              Expanded(
                flex: 12,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(5),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(5),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 14,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _signalColor(HotStockSignal signal) {
    switch (signal) {
      case HotStockSignal.BUY:
        return const Color(0xFF10B981);
      case HotStockSignal.STRONG_BUY:
        return const Color(0xFF7C3AED);
      case HotStockSignal.HOLD:
        return const Color(0xFFF59E0B);
      case HotStockSignal.SELL:
        return const Color(0xFFEF4444);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TradeBtn
// ─────────────────────────────────────────────────────────────────────────────

class _TradeBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final Color labelColor;
  final String tooltip;
  final VoidCallback onTap;

  const _TradeBtn({
    required this.label,
    required this.color,
    required this.bg,
    required this.labelColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: labelColor,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HotStockFormDialog
// ─────────────────────────────────────────────────────────────────────────────

class _HotStockFormDialog extends StatefulWidget {
  final String title;
  final int pyId;
  final HotStockCategory defaultCategory;
  final HotStockModel? existingStock;
  final void Function(HotStockOperationRequest) onSubmit;

  const _HotStockFormDialog({
    required this.title,
    required this.pyId,
    required this.defaultCategory,
    required this.onSubmit,
    this.existingStock,
  });

  @override
  State<_HotStockFormDialog> createState() => _HotStockFormDialogState();
}

class _HotStockFormDialogState extends State<_HotStockFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _symbolCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _changeCtrl;
  late final TextEditingController _targetCtrl;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  List<ScripInfo> _searchResults = [];
  bool _searchLoading = false;
  bool _showDropdown = false;
  String _exchange = 'NSE';
  bool _ltpLoading = false;
  ScripInfo? _selectedScrip;

  String? _symbolToken;

  late HotStockSignal _signal;
  late HotStockDirection _direction;
  late HotStockCategory _category;

  bool get _isEdit => widget.existingStock != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existingStock;
    _symbolCtrl = TextEditingController(text: s?.symbol ?? '');
    _nameCtrl = TextEditingController(text: s?.companyName ?? '');
    _priceCtrl = TextEditingController(
      text: s != null ? s.price.toStringAsFixed(0) : '',
    );
    _changeCtrl = TextEditingController(
      text: s?.changePercent != null
          ? s!.changePercent!.toStringAsFixed(1)
          : '',
    );
    _targetCtrl = TextEditingController(
      text: s != null ? s.target.toStringAsFixed(0) : '',
    );
    _signal = s?.signal ?? HotStockSignal.BUY;
    _direction = s?.direction ?? HotStockDirection.UP;
    _category = s?.category ?? widget.defaultCategory;
    _symbolToken = s?.symbolToken;
  }

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _changeCtrl.dispose();
    _targetCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    if (val.length < 2) {
      setState(() {
        _searchResults = [];
        _showDropdown = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _searchLoading = true);
      context.read<IndividualExecutionBloc>().add(
        SearchScripRequested(query: val, exchange: _exchange),
      );
    });
  }

  void _selectScrip(ScripInfo s) {
    final cleanSymbol = s.tradingSymbol.replaceAll('-EQ', '').trim();
    final companyName = s.tradingSymbol.trim();

    setState(() {
      _selectedScrip = s;
      _symbolCtrl.text = cleanSymbol.toUpperCase();
      _nameCtrl.text = companyName;
      _symbolToken = s.symbolToken;
      _searchCtrl.clear();
      _searchResults = [];
      _showDropdown = false;
      _ltpLoading = true;
    });
    _searchFocus.unfocus();
    context.read<IndividualExecutionBloc>().add(LtpRequested(s));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_isEdit) {
      widget.onSubmit(
        HotStockOperationRequest(
          actionType: HotStockActionType.UPDATE,
          stockId: widget.existingStock!.stockId,
          symbol: _symbolCtrl.text.trim().toUpperCase(),
          companyName: _nameCtrl.text.trim(),
          price: double.tryParse(_priceCtrl.text.trim()),
          target: double.tryParse(_targetCtrl.text.trim()),
          changePercent: double.tryParse(_changeCtrl.text.trim()),
          direction: _direction,
          signal: _signal,
          category: _category,
          symbolToken: _symbolToken,
        ),
      );
    } else {
      widget.onSubmit(
        HotStockOperationRequest(
          actionType: HotStockActionType.ADD,
          pyId: widget.pyId,
          symbol: _symbolCtrl.text.trim().toUpperCase(),
          companyName: _nameCtrl.text.trim(),
          price: double.tryParse(_priceCtrl.text.trim()),
          target: double.tryParse(_targetCtrl.text.trim()),
          changePercent: double.tryParse(_changeCtrl.text.trim()),
          direction: _direction,
          signal: _signal,
          category: _category,
          symbolToken: _symbolToken,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<IndividualExecutionBloc, IndividualExecutionState>(
      listener: (context, state) {
        if (state is ScripSearchSuccess) {
          setState(() {
            _searchResults = state.results;
            _searchLoading = false;
            _showDropdown = true;
          });
        } else if (state is ScripSearchLoading) {
          setState(() => _searchLoading = true);
        } else if (state is ScripSearchFailure) {
          setState(() {
            _searchResults = [];
            _searchLoading = false;
            _showDropdown = false;
          });
        } else if (state is LtpSuccess &&
            _selectedScrip != null &&
            state.scrip.symbolToken == _selectedScrip!.symbolToken) {
          setState(() {
            _ltpLoading = false;
            _priceCtrl.text = state.ltpData.ltp.toStringAsFixed(2);
            _changeCtrl.text = state.ltpData.change.toStringAsFixed(2);
            _direction = state.ltpData.change >= 0
                ? HotStockDirection.UP
                : HotStockDirection.DOWN;
          });
        } else if (state is LtpFailure) {
          setState(() => _ltpLoading = false);
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: 480,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _labelText('SEARCH STOCK'),
                        const SizedBox(height: 6),
                        _buildScripSearch(),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                label: 'SYMBOL',
                                hint: 'e.g. RELIANCE',
                                ctrl: _symbolCtrl,
                                formatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9&]'),
                                  ),
                                  LengthLimitingTextInputFormatter(20),
                                ],
                                required: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                label: 'COMPANY NAME',
                                hint: 'e.g. Reliance Ind.',
                                ctrl: _nameCtrl,
                                required: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                label: 'PRICE (₹)',
                                hint: 'e.g. 2847',
                                ctrl: _priceCtrl,
                                keyboard: TextInputType.number,
                                formatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                required: true,
                                suffix: _ltpLoading
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Color(0xFF7C3AED),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                label: 'TARGET (₹)',
                                hint: 'e.g. 3200',
                                ctrl: _targetCtrl,
                                keyboard: TextInputType.number,
                                formatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                required: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                label: 'CHANGE %',
                                hint: 'e.g. 2.4',
                                ctrl: _changeCtrl,
                                keyboard: TextInputType.number,
                                formatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _directionToggle()),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _labelText('CATEGORY'),
                        const SizedBox(height: 6),
                        _categorySelector(),
                        const SizedBox(height: 14),
                        _labelText('SIGNAL'),
                        const SizedBox(height: 6),
                        _signalSelector(),
                        if (_isEdit) ...[
                          const SizedBox(height: 14),
                          _buildTokenStatusChip(),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isEdit
                                          ? Icons.save_rounded
                                          : Icons.add_rounded,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isEdit ? 'Save Changes' : 'Add Stock',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenStatusChip() {
    final hasToken = _symbolToken != null && _symbolToken!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: hasToken ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasToken ? const Color(0xFF6EE7B7) : const Color(0xFFFBBF24),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasToken
                ? Icons.check_circle_outline_rounded
                : Icons.warning_amber_rounded,
            size: 14,
            color: hasToken ? const Color(0xFF059669) : const Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasToken
                  ? 'Symbol token: $_symbolToken  (auto-filled)'
                  : 'No symbol token — search & select a stock above to update it',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: hasToken
                    ? const Color(0xFF059669)
                    : const Color(0xFFD97706),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isEdit ? Icons.edit_rounded : Icons.add_chart_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScripSearch() {
    return Column(
      children: [
        Row(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _exchange = _exchange == 'NSE' ? 'BSE' : 'NSE';
                  if (_searchCtrl.text.length >= 2) {
                    _onSearchChanged(_searchCtrl.text);
                  }
                });
              },
              child: Container(
                height: 44,
                width: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _exchange,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const Icon(
                      Icons.unfold_more_rounded,
                      size: 11,
                      color: Color(0xFF6366F1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search symbol (e.g. INFY, SBIN...)',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                    prefixIcon: _searchLoading
                        ? Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Color(0xFF6B7280),
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _searchResults = [];
                                _showDropdown = false;
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_showDropdown && _searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                itemBuilder: (_, i) {
                  final s = _searchResults[i];
                  final displaySymbol = s.tradingSymbol
                      .replaceAll('-EQ', '')
                      .trim();
                  return InkWell(
                    onTap: () => _selectScrip(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                displaySymbol.isNotEmpty
                                    ? displaySymbol[0]
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displaySymbol,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                Text(
                                  s.tradingSymbol,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.exchange,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 15,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        if (_selectedScrip != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_selectedScrip!.tradingSymbol} · ${_selectedScrip!.exchange}  —  price auto-filled from LTP',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_ltpLoading)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _labelText(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: Color(0xFF6B7280),
    ),
  );

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController ctrl,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? formatters,
    bool required = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelText(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          inputFormatters: formatters,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)),
            suffixIcon: suffix != null
                ? Padding(padding: const EdgeInsets.all(12), child: suffix)
                : null,
            filled: true,
            fillColor: const Color(0xFFFAF9FF),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
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
              borderSide: const BorderSide(
                color: Color(0xFF7C3AED),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1.5,
              ),
            ),
            errorStyle: const TextStyle(fontSize: 10),
          ),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
        ),
      ],
    );
  }

  Widget _directionToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelText('DIRECTION'),
        const SizedBox(height: 6),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () =>
                      setState(() => _direction = HotStockDirection.UP),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: _direction == HotStockDirection.UP
                          ? const Color(0xFF10B981)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: 13,
                          color: _direction == HotStockDirection.UP
                              ? Colors.white
                              : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'UP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _direction == HotStockDirection.UP
                                ? Colors.white
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () =>
                      setState(() => _direction = HotStockDirection.DOWN),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: _direction == HotStockDirection.DOWN
                          ? const Color(0xFFEF4444)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 13,
                          color: _direction == HotStockDirection.DOWN
                              ? Colors.white
                              : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'DOWN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _direction == HotStockDirection.DOWN
                                ? Colors.white
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categorySelector() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: HotStockCategory.values.map((cat) {
        final sel = cat == _category;
        return InkWell(
          onTap: () => setState(() => _category = cat),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: sel
                  ? const Color(0xFF7C3AED).withOpacity(0.10)
                  : const Color(0xFFF9F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sel ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB),
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Text(
              cat.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: sel ? const Color(0xFF7C3AED) : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _signalSelector() {
    const options = [
      (HotStockSignal.BUY, Color(0xFF10B981)),
      (HotStockSignal.STRONG_BUY, Color(0xFF7C3AED)),
      (HotStockSignal.HOLD, Color(0xFFF59E0B)),
      (HotStockSignal.SELL, Color(0xFFEF4444)),
    ];
    return Row(
      children: options.map((opt) {
        final (sig, color) = opt;
        final sel = _signal == sig;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: sig == HotStockSignal.SELL ? 0 : 6),
            child: InkWell(
              onTap: () => setState(() => _signal = sig),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? color.withOpacity(0.12)
                      : const Color(0xFFF9F9FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel ? color : const Color(0xFFE5E7EB),
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  sig.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: sel ? color : const Color(0xFF9CA3AF),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Shimmer
// ─────────────────────────────────────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const _Shimmer({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ColLabel extends StatelessWidget {
  final String text;
  final bool right;
  const _ColLabel(this.text, {this.right = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9B87E8),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _Slide {
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  const _Slide({
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
  });
}

class _CarouselSlide extends StatelessWidget {
  final _Slide slide;
  const _CarouselSlide({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: slide.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    slide.tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  slide.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  slide.subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(slide.icon, color: Colors.white.withOpacity(0.18), size: 58),
        ],
      ),
    );
  }
}