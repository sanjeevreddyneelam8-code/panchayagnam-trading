import 'package:flutter/material.dart';
import '../service/theme_mode_service.dart';

/// ClientKnowledgeCenterDialog
/// Comprehensive, client-friendly interactive knowledge center & onboarding tour:
/// - "How Panchayagnam Works in 3 Steps" (Architecture & Workflow)
/// - Step-by-Step Broker Connection Guides for all 8 Demats (Angel One, Zerodha, Dhan, Fyers, Upstox, Kotak, Motilal, Alice Blue)
/// - Interactive Multi-Demat Lot Multiplier & Capital Calculator
/// - Capital Protection & Risk Rules (Daily Loss Kill-Switch, Trailing Stop-Loss, Whitelisted Static IP)
/// - Frequently Asked Questions (Security, Latency, API Independence)
class ClientKnowledgeCenterDialog extends StatefulWidget {
  final int initialTabIndex;
  final VoidCallback? onNavigateToBrokers;
  final VoidCallback? onNavigateToParentChild;
  final VoidCallback? onNavigateToAutoTrading;
  final VoidCallback? onNavigateToVirtualPractice;

  const ClientKnowledgeCenterDialog({
    super.key,
    this.initialTabIndex = 0,
    this.onNavigateToBrokers,
    this.onNavigateToParentChild,
    this.onNavigateToAutoTrading,
    this.onNavigateToVirtualPractice,
  });

  static void show(
    BuildContext context, {
    int initialTabIndex = 0,
    VoidCallback? onNavigateToBrokers,
    VoidCallback? onNavigateToParentChild,
    VoidCallback? onNavigateToAutoTrading,
    VoidCallback? onNavigateToVirtualPractice,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => ClientKnowledgeCenterDialog(
        initialTabIndex: initialTabIndex,
        onNavigateToBrokers: onNavigateToBrokers,
        onNavigateToParentChild: onNavigateToParentChild,
        onNavigateToAutoTrading: onNavigateToAutoTrading,
        onNavigateToVirtualPractice: onNavigateToVirtualPractice,
      ),
    );
  }

  @override
  State<ClientKnowledgeCenterDialog> createState() => _ClientKnowledgeCenterDialogState();
}

class _ClientKnowledgeCenterDialogState extends State<ClientKnowledgeCenterDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State for Interactive Lot Multiplier Calculator (Tab 2)
  int _masterLots = 2; // e.g. 2 lots = 50 Qty for NIFTY
  final int _niftyLotSize = 25;

  // Selected Broker Guide (Tab 1)
  String _selectedBrokerGuide = 'ANGEL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeModeService.isDarkModeNotifier,
      builder: (context, isDark, _) {
        final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
        final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
        final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Dialog(
          backgroundColor: cardBg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderCol, width: 1.2),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960, maxHeight: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Bar
                _buildHeader(context, isDark, textMain, textSub, borderCol),

                // 2. Navigation Tabs
                Container(
                  color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: const Color(0xFF10B981),
                    unselectedLabelColor: textSub,
                    indicatorColor: const Color(0xFF10B981),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    tabs: const [
                      Tab(icon: Icon(Icons.rocket_launch_rounded, size: 16), text: '1. How It Works (Quick Start)'),
                      Tab(icon: Icon(Icons.cable_rounded, size: 16), text: '2. Connect Brokers Guide'),
                      Tab(icon: Icon(Icons.calculate_rounded, size: 16), text: '3. Multi-Demat Calculator'),
                      Tab(icon: Icon(Icons.shield_rounded, size: 16), text: '4. Capital Safety & Risk Rules'),
                      Tab(icon: Icon(Icons.help_outline_rounded, size: 16), text: '5. Client FAQs'),
                    ],
                  ),
                ),
                Divider(height: 1, color: borderCol),

                // 3. Tab Body
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 0: How Panchayagnam Works
                      _buildHowItWorksTab(isDark, cardBg, borderCol, textMain, textSub),

                      // Tab 1: Broker Connection Guides
                      _buildBrokerGuideTab(isDark, cardBg, borderCol, textMain, textSub),

                      // Tab 2: Interactive Lot Multiplier Calculator
                      _buildCalculatorTab(isDark, cardBg, borderCol, textMain, textSub),

                      // Tab 3: Capital Safety & Risk Management
                      _buildSafetyRulesTab(isDark, cardBg, borderCol, textMain, textSub),

                      // Tab 4: Frequently Asked Questions
                      _buildFaqTab(isDark, cardBg, borderCol, textMain, textSub),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header Bar ──
  Widget _buildHeader(BuildContext context, bool isDark, Color textMain, Color textSub, Color borderCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF1F5F9),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: borderCol)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Panchayagnam Client Knowledge Center',
                      style: TextStyle(color: textMain, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                      ),
                      child: const Text('SUB-15MS PARALLEL ENGINE', style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Everything you need to master 35+ Broker Copy Trading, MCX Commodities, Algos & Capital Safeguards',
                  style: TextStyle(color: textSub, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: textSub, size: 22),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close Guide',
          ),
        ],
      ),
    );
  }

  // ── Tab 0: How Panchayagnam Works (Visual 3-Step Guide) ──
  Widget _buildHowItWorksTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Welcome Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: Color(0xFF10B981), size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Panchayagnam — India\'s No. 1 Multi-Demat Algorithmic Trading Platform',
                      style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Instead of placing separate orders across dozens of individual broker apps, Panchayagnam connects your 35+ broker demats into one ultra-fast command center with automatic risk parity and sub-15ms execution.',
                      style: TextStyle(color: textSub, fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Step 1: Link Demats
        _buildStepItem(
          stepNumber: '1',
          title: 'Link Your Broker Demat Accounts (Supports 35+ Major Indian Brokers)',
          description:
              'Connect DhanHQ, Angel One, Zerodha Kite, Upstox, Groww, Fyers, Kotak Neo, Motilal Oswal, Alice Blue, ICICI Direct, HDFC Sky, Sharekhan, and 23+ more using official SEBI-compliant APIs & TOTP. Passwords stay encrypted.',
          icon: Icons.link_rounded,
          accentCol: const Color(0xFF38BDF8),
          actionLabel: 'Connect Broker Demats',
          onAction: () {
            Navigator.pop(context);
            if (widget.onNavigateToBrokers != null) widget.onNavigateToBrokers!();
          },
          isDark: isDark,
          cardBg: cardBg,
          borderCol: borderCol,
          textMain: textMain,
          textSub: textSub,
        ),
        const SizedBox(height: 14),

        // Step 2: Choose Mode
        _buildStepItem(
          stepNumber: '2',
          title: 'Select Your Trading Mode (Copy Trading, Algo Bots, Commodity, or SEBI Calls)',
          description:
              '• Parent-Child Copy Trading: Choose one Master Demat. Any trade placed on Master mirrors instantly to all connected Child brokers based on lot multipliers.\n• Auto Trading & Commodity: Deploy automated NIFTY/BankNifty bots or trade MCX/NSE Crude Oil, Gold, Silver & Natural Gas Futures/Options.\n• Trade Market: Access SEBI-verified setups with 1-click execution across all connected demats.',
          icon: Icons.alt_route_rounded,
          accentCol: const Color(0xFF10B981),
          actionLabel: 'Open Parent-Child Trading',
          onAction: () {
            Navigator.pop(context);
            if (widget.onNavigateToParentChild != null) widget.onNavigateToParentChild!();
          },
          isDark: isDark,
          cardBg: cardBg,
          borderCol: borderCol,
          textMain: textMain,
          textSub: textSub,
        ),
        const SizedBox(height: 14),

        // Step 3: Automated Fast Execution
        _buildStepItem(
          stepNumber: '3',
          title: 'High-Speed Concurrent Execution with Slippage & Risk Controls',
          description:
              'When a trade triggers, Panchayagnam dispatches orders across all connected demats concurrently using parallel non-blocking CompletableFuture threads in under 15ms. Dedicated whitelisted static IP routing prevents broker rate-limiting and exchange IP mismatch rejections.',
          icon: Icons.flash_on_rounded,
          accentCol: const Color(0xFFF59E0B),
          actionLabel: 'Try Virtual Paper Trading (₹10L)',
          onAction: () {
            Navigator.pop(context);
            if (widget.onNavigateToVirtualPractice != null) widget.onNavigateToVirtualPractice!();
          },
          isDark: isDark,
          cardBg: cardBg,
          borderCol: borderCol,
          textMain: textMain,
          textSub: textSub,
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color accentCol,
    required String actionLabel,
    required VoidCallback onAction,
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textMain,
    required Color textSub,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentCol.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: TextStyle(color: accentCol, fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(description, style: TextStyle(color: textSub, fontSize: 12, height: 1.4)),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: Icon(icon, size: 14, color: Colors.white),
                  label: Text(actionLabel, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentCol,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Broker Connection Guides ──
  Widget _buildBrokerGuideTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final Map<String, Map<String, dynamic>> brokerData = {
      'ANGEL': {
        'name': 'Angel One (SmartAPI)',
        'logo': 'ANGEL ONE',
        'authType': 'API Key + Client ID + PIN + TOTP',
        'steps': [
          '1. Log into your Angel One SmartAPI portal at smartapi.angelone.in',
          '2. Click on "Create an App", enter App Name (e.g. Panchayagnam) and set redirect URL.',
          '3. Copy your API Key and Secret Key.',
          '4. Open Authenticator App (Google Authenticator) to get your 6-digit TOTP.',
          '5. Enter your Client ID, MPIN, API Key, and TOTP in Panchayagnam Tools & Demats.',
        ],
        'note': 'Angel One allows completely free API access with 10 requests per second rate limit.',
      },
      'ZERODHA': {
        'name': 'Zerodha Kite Connect',
        'logo': 'ZERODHA KITE',
        'authType': 'API Key + API Secret + Request Token (OAuth)',
        'steps': [
          '1. Log into Kite Connect developer portal at developers.kite.trade',
          '2. Create a new Kite Connect app and enter your redirect URL.',
          '3. Copy the API Key and API Secret.',
          '4. In Panchayagnam, click "Connect Zerodha", log in with your Kite credentials, and authenticate TOTP.',
        ],
        'note': 'Zerodha requires daily morning token authentication at 8:45 AM before market opens.',
      },
      'DHAN': {
        'name': 'DhanHQ API',
        'logo': 'DHAN',
        'authType': 'Client ID + Access Token (Instant)',
        'steps': [
          '1. Log into Dhan Web (web.dhan.co) and go to Profile > DhanHQ Trading APIs.',
          '2. Click "Generate Access Token" (Valid for 30 days).',
          '3. Copy your 10-digit Client ID and the generated Access Token.',
          '4. Paste both into Panchayagnam Demat Accounts setup.',
        ],
        'note': 'Dhan provides instant 30-day tokens with zero daily re-authentication required!',
      },
      'FYERS': {
        'name': 'Fyers API v3',
        'logo': 'FYERS',
        'authType': 'App ID + Secret Key + TOTP',
        'steps': [
          '1. Go to myapi.fyers.in and create an app with redirect URL.',
          '2. Copy the App ID and Secret Key.',
          '3. Enter in Panchayagnam and complete the 2FA login verification.',
        ],
        'note': 'Fyers API v3 supports ultra-fast WebSocket data streaming at 10ms intervals.',
      },
      'UPSTOX': {
        'name': 'Upstox Pro API',
        'logo': 'UPSTOX',
        'authType': 'API Key + Secret + OAuth Token',
        'steps': [
          '1. Go to Upstox Developer console at service.upstox.com/developer/api-keys',
          '2. Create a new app and retrieve your API Key and Secret.',
          '3. Complete the interactive login on Panchayagnam to sync your portfolio.',
        ],
        'note': 'Upstox supports high-speed MTF (Margin Trading Facility) multiplier execution.',
      },
    };

    final selected = brokerData[_selectedBrokerGuide]!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Broker Selector Chips
        Wrap(
          spacing: 10,
          children: brokerData.keys.map((k) {
            final isSelected = _selectedBrokerGuide == k;
            return ChoiceChip(
              label: Text(brokerData[k]!['name'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : textMain)),
              selected: isSelected,
              selectedColor: const Color(0xFF10B981),
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              onSelected: (_) => setState(() => _selectedBrokerGuide = k),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Broker Guide Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(selected['name'] as String, style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(selected['authType'] as String, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Steps
              ...((selected['steps'] as List<String>).map((step) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(step, style: TextStyle(color: textMain, fontSize: 12.5, height: 1.4)),
                  ))),

              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(selected['note'] as String, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.onNavigateToBrokers != null) widget.onNavigateToBrokers!();
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.white),
                label: const Text('Connect Broker Account Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 2: Interactive Lot Multiplier Calculator ──
  Widget _buildCalculatorTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final masterQty = _masterLots * _niftyLotSize;

    final accounts = [
      {'name': 'Master Demat (Dhan Pro)', 'type': 'MASTER', 'mult': '1.0x (Base)', 'lots': _masterLots, 'qty': masterQty, 'cap': '₹25,00,000'},
      {'name': 'Child 1: Angel One', 'type': 'CHILD', 'mult': '2.0x Fixed', 'lots': _masterLots * 2, 'qty': masterQty * 2, 'cap': '₹50,00,000'},
      {'name': 'Child 2: Zerodha Kite', 'type': 'CHILD', 'mult': '1.5x Fixed', 'lots': (_masterLots * 1.5).round(), 'qty': (_masterLots * 1.5).round() * _niftyLotSize, 'cap': '₹35,00,000'},
      {'name': 'Child 3: Fyers Pro', 'type': 'CHILD', 'mult': '1.0x Mirror', 'lots': _masterLots, 'qty': masterQty, 'cap': '₹20,00,000'},
      {'name': 'Child 4: Upstox Pro', 'type': 'CHILD', 'mult': '2.0x Fixed', 'lots': _masterLots * 2, 'qty': masterQty * 2, 'cap': '₹40,00,000'},
      {'name': 'Child 5: Kotak Neo', 'type': 'CHILD', 'mult': '1.0x Mirror', 'lots': _masterLots, 'qty': masterQty, 'cap': '₹20,00,000'},
      {'name': 'Child 6: Motilal Oswal', 'type': 'CHILD', 'mult': '1.0x Mirror', 'lots': _masterLots, 'qty': masterQty, 'cap': '₹20,00,000'},
      {'name': 'Child 7: Alice Blue', 'type': 'CHILD', 'mult': '1.0x Mirror', 'lots': _masterLots, 'qty': masterQty, 'cap': '₹15,00,000'},
    ];

    final int totalPooledQty = accounts.map((a) => a['qty'] as int).reduce((a, b) => a + b);
    final int totalPooledLots = (totalPooledQty / _niftyLotSize).round();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Controls Row
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Adjust Master Demat Lots to Test Multiplier Math:', style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w900)),
                  Text('$_masterLots Lots ($masterQty Qty)', style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              Slider(
                value: _masterLots.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '$_masterLots Lots',
                activeColor: const Color(0xFF10B981),
                onChanged: (val) => setState(() => _masterLots = val.round()),
              ),
              Text(
                'Sample 8-account slice (scales to all 35+ connected brokers): When Master buys $_masterLots NIFTY lots, Panchayagnam mirrors $totalPooledLots lots ($totalPooledQty Qty) in parallel!',
                style: TextStyle(color: textSub, fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Accounts Table
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8)),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('DEMAT ACCOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('ROLE & MULTIPLIER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('LOTS EXECUTED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('TOTAL SHARES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
              Expanded(flex: 2, child: Text('ACCOUNT CAPITAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
            ],
          ),
        ),
        const SizedBox(height: 6),

        ...accounts.map((acc) {
          final isMaster = acc['type'] == 'MASTER';
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMaster ? const Color(0xFF10B981).withOpacity(0.08) : cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isMaster ? const Color(0xFF10B981).withOpacity(0.4) : borderCol),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Icon(isMaster ? Icons.star_rounded : Icons.account_balance_wallet_rounded, size: 15, color: isMaster ? const Color(0xFF10B981) : textSub),
                      const SizedBox(width: 6),
                      Text(acc['name'] as String, style: TextStyle(color: textMain, fontSize: 12.5, fontWeight: isMaster ? FontWeight.w900 : FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: Text(acc['mult'] as String, style: TextStyle(color: isMaster ? const Color(0xFF10B981) : textSub, fontSize: 11.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('${acc['lots']} Lots', style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('${acc['qty']} Qty', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w900))),
                Expanded(flex: 2, child: Text(acc['cap'] as String, textAlign: TextAlign.right, style: TextStyle(color: textSub, fontSize: 11.5))),
              ],
            ),
          );
        }),

        const SizedBox(height: 14),

        // Summary Total Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF047857)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL POOLED BATCH DISPATCH:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
              Text('$totalPooledLots Lots ($totalPooledQty Qty) in <15ms', style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 3: Capital Safety & Risk Rules ──
  Widget _buildSafetyRulesTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSafetyRuleCard(
          title: 'Daily MTM Loss Kill-Switch',
          desc:
              'Configure your maximum acceptable loss per day (e.g. ₹20,000). The moment cumulative unrealized losses across your connected demats hit this threshold, the system automatically squares off all active positions and halts trading for the session.',
          icon: Icons.cancel_presentation_rounded,
          accentCol: const Color(0xFFEF4444),
          badge: 'CAPITAL PRESERVATION',
          isDark: isDark,
          cardBg: cardBg,
          borderCol: borderCol,
          textMain: textMain,
          textSub: textSub,
        ),
        const SizedBox(height: 12),
        _buildSafetyRuleCard(
          title: 'Dedicated Whitelisted Static IP (13.235.14.89)',
          desc:
              'Indian exchanges (NSE, BSE & MCX) enforce strict security policies regarding IP changes during live trading. Panchayagnam routes all connected broker orders through your dedicated static IP gateway (13.235.14.89), preventing IP mismatch rejections.',
          icon: Icons.router_rounded,
          accentCol: const Color(0xFF38BDF8),
          badge: 'EXCHANGE COMPLIANCE',
          isDark: isDark,
          cardBg: cardBg,
          borderCol: borderCol,
          textMain: textMain,
          textSub: textSub,
        ),
        const SizedBox(height: 12),
        _buildSafetyRuleCard(
          title: 'Slippage Buffer & Limit Protection',
          desc:
              'Market orders during extreme volatility can incur costly slippage. Panchayagnam converts market orders to IOC (Immediate or Cancel) Limit orders pegged to the Best 5 Bid/Ask spread with a 0.25% buffer to guarantee execution without adverse fills.',
          icon: Icons.speed_rounded,
          accentCol: const Color(0xFFF59E0B),
          badge: 'SLIPPAGE CONTROL',
          isDark: isDark,
          cardBg: cardBg,
          borderCol: borderCol,
          textMain: textMain,
          textSub: textSub,
        ),
        const SizedBox(height: 12),
        _buildSafetyRuleCard(
          title: 'Automatic Isolated Broker Fail-Safe',
          desc:
              'If one broker’s server experiences downtime or API disconnection, Panchayagnam instantly isolates that demat without halting or delaying execution for all your remaining connected brokers, alerting you immediately.',
          icon: Icons.safety_check_rounded,
          accentCol: const Color(0xFF10B981),
          badge: 'HIGH AVAILABILITY',
          isDark: isDark,
          cardBg: cardBg,
          borderCol: borderCol,
          textMain: textMain,
          textSub: textSub,
        ),
      ],
    );
  }

  Widget _buildSafetyRuleCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color accentCol,
    required String badge,
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textMain,
    required Color textSub,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderCol)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accentCol.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: accentCol, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: TextStyle(color: textMain, fontSize: 14.5, fontWeight: FontWeight.w900)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: accentCol.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text(badge, style: TextStyle(color: accentCol, fontSize: 9.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(desc, style: TextStyle(color: textSub, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Client FAQs ──
  Widget _buildFaqTab(bool isDark, Color cardBg, Color borderCol, Color textMain, Color textSub) {
    final faqs = [
      {
        'q': 'Is my money or broker password safe with Panchayagnam?',
        'a':
            'Absolutely. Panchayagnam NEVER touches your funds. Your capital remains safely deposited inside your respective SEBI-registered broker accounts (Angel One, Zerodha, Dhan, etc.). We only send trade order instructions via official broker APIs with 256-bit SSL encryption. Broker tokens are stored strictly on your local secure browser session.',
      },
      {
        'q': 'Can I still trade manually on my Angel One or Zerodha mobile app?',
        'a':
            'Yes! You retain 100% manual control over your demat accounts. You can view, enter, modify, or exit trades from your broker’s official mobile app at any time without disrupting Panchayagnam.',
      },
      {
        'q': 'How does Panchayagnam achieve sub-15ms replication speed across 8 accounts?',
        'a':
            'Unlike traditional sequential copiers that send orders one after another (taking 2 to 5 seconds), Panchayagnam utilizes non-blocking parallel CompletableFuture threads. All 8 broker APIs receive order packets concurrently in under 15 milliseconds.',
      },
      {
        'q': 'Can I practice without risking real money first?',
        'a':
            'Yes! Panchayagnam provides a built-in ₹10,00,000 Virtual Practice Arena synced with real-time NSE tick prices. You can test your multi-demat setups, option strategies, and algorithmic bots completely risk-free before deploying live capital.',
      },
      {
        'q': 'What happens if my internet connection drops during an active trade?',
        'a':
            'Because orders execute directly via our secure cloud trading gateway, once an order or algo strategy is active, the exchange and broker servers manage your stop-loss and target triggers even if your local browser is closed or your device goes offline.',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: faqs.map((f) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderCol)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.help_outline_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f['q']!, style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(f['a']!, style: TextStyle(color: textSub, fontSize: 12, height: 1.4)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
