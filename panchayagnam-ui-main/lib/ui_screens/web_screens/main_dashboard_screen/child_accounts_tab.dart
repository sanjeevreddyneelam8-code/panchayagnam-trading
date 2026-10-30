import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'dart:html' as html;
import 'dart:convert';
import '../../../bloc/add_demat_account/add_demat_bloc.dart';
import '../../../bloc/broker_fetch_balance_bloc/fetch_account_balance_bloc.dart';
import '../../../bloc/broker_o_auth_dilogue_bloc/broker_o_auth_bloc.dart';
import '../../../bloc/broker_o_auth_dilogue_bloc/broker_o_auth_event.dart';
import '../../../bloc/broker_o_auth_dilogue_bloc/broker_o_auth_state.dart';
import '../../../bloc/fetch_user_demat_bloc/fetch_user_demat_bloc.dart';
import '../../../constants/colors.dart';
import '../../../reusable_widets/add_child_account_dialog.dart';
import '../../../reusable_widets/filter_sort_dialog.dart';
import '../../../service/service_class.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BROKER FILTER CHIPS
// ─────────────────────────────────────────────────────────────────────────────

/// Brokers that support OAuth connect flow
const Set<String> _oauthBrokers = {
  'PROFITMART',
  'GOODWILL',
  'ZERODHA',
  'UPSTOX',
  'ANGELONE',
  'MOTILAL',
  'DHAN',
  'GROWW',
};

/// Returns true if this broker needs the Connect button
bool _supportsOAuth(String broker) =>
    _oauthBrokers.contains(broker.toUpperCase());

// ─────────────────────────────────────────────────────────────────────────────
// MAIN TAB
// ─────────────────────────────────────────────────────────────────────────────

class ChildAccountsTab extends StatefulWidget {
  const ChildAccountsTab({super.key});

  @override
  State<ChildAccountsTab> createState() => _ChildAccountsTabState();
}

class _ChildAccountsTabState extends State<ChildAccountsTab> {
  String _statusFilter = 'ALL';
  String _sortBy = 'Name (A-Z)';

  /// broker type filter — 'ALL' | 'PROFITMART' | 'GOODWILL' | 'ANGELONE' | 'MOTILAL'
  String _brokerFilter = 'ALL';

  final Set<String> _pendingStatusUpdate = {};
  final Map<int, double> _refreshedBalances = {};
  final Set<int> _loadingBalanceIds = {};

  bool get _isExpired =>
      (html.window.sessionStorage['expiredFlag'] ?? '') == 'true';

  int get _noOfClients =>
      int.tryParse(html.window.sessionStorage['noOfClients'] ?? '') ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final int pyUserId =
        int.tryParse(html.window.sessionStorage['user_id'] ?? '') ?? 0;
    context.read<FetchUserDematBloc>().add(LoadUserDematAccounts(pyUserId));
  }

  String _resolveBrokerApi(String brokerDisplay) {
    final upper = brokerDisplay.toUpperCase();
    if (upper.contains('ANGEL')) return 'ANGELONE';
    if (upper.contains('MOTILAL')) return 'MOTILAL';
    if (upper.contains('DHAN')) return 'DHAN';
    if (upper.contains('PROFITMART') || upper.contains('PROFIT MART')) return 'PROFITMART';
    if (upper.contains('GOODWILL') || upper.contains('GOOD WELL')) return 'GOODWILL';
    if (upper.contains('ZERODHA')) return 'ZERODHA';
    if (upper.contains('UPSTOX')) return 'UPSTOX';
    if (upper.contains('GROWW')) return 'GROWW';
    return upper;
  }

  bool _isMotilal(String broker) => broker.toUpperCase().contains('MOTILAL');

  List<Map<String, dynamic>> _activeAccounts(
      List<Map<String, dynamic>> accounts,
      ) =>
      accounts.where((a) => a['status'] == 'ACTIVE').toList();

  List<Map<String, dynamic>> _applyFilterAndSort(
      List<Map<String, dynamic>> accounts,
      ) {
    List<Map<String, dynamic>> filtered = List.from(accounts);

    if (_statusFilter != 'ALL') {
      filtered = filtered
          .where(
            (a) => a['status'].toUpperCase() == _statusFilter.toUpperCase(),
      )
          .toList();
    }

    if (_brokerFilter != 'ALL') {
      filtered = filtered.where((a) {
        final broker = (a['broker'] as String).toUpperCase();
        switch (_brokerFilter) {
          case 'PROFITMART':
            return broker.contains('PROFITMART') || broker.contains('PROFIT MART');
          case 'GOODWILL':
            return broker.contains('GOODWILL') || broker.contains('GOOD WELL');
          case 'ANGELONE':
            return broker.contains('ANGEL');
          case 'MOTILAL':
            return broker.contains('MOTILAL');
          case 'DHAN':
            return broker.contains('DHAN');
          case 'ZERODHA':
            return broker.contains('ZERODHA');
          case 'UPSTOX':
            return broker.contains('UPSTOX');
          case 'GROWW':
            return broker.contains('GROWW');
          default:
            return true;
        }
      }).toList();
    }

    switch (_sortBy) {
      case 'Name (A-Z)':
        filtered.sort((a, b) => a['name'].compareTo(b['name']));
        break;
      case 'Name (Z-A)':
        filtered.sort((a, b) => b['name'].compareTo(a['name']));
        break;
    }

    filtered.sort((a, b) {
      final aOwn = a['isOwn'] == true ? 0 : 1;
      final bOwn = b['isOwn'] == true ? 0 : 1;
      return aOwn.compareTo(bOwn);
    });

    return filtered;
  }

  AddDematAccountEvent _buildEvent({
    required Map<String, dynamic> account,
    required String actionType,
    bool? active,
    String? ip,
  }) {
    final broker = _resolveBrokerApi(account['broker'] as String);
    final motilal = _isMotilal(broker);

    return AddDematAccountEvent(
      id: account['id'],
      clientId: account['clientCode'] ?? '',
      broker: broker,
      apiKey: account['apiKey'] ?? '',
      mpin: account['mpin'] ?? '',
      password: account['password'] ?? '',
      totpReferenceKey: account['totpKey'] ?? '',
      dob: (account['dob']?.toString().isNotEmpty == true)
          ? account['dob'].toString()
          : null,
      isAdmin: (account['accountType'] ?? '') == 'Admin',
      childIds: List<String>.from(account['childIds'] ?? []),
      nickName: account['name'] ?? '',
      actionType: actionType,
      active: active,
      apiSecretKey: motilal ? (account['apiSecretKey'] ?? '') : null,
      vendorInfo: motilal
          ? ((account['vendorInfo']?.toString().isNotEmpty == true)
          ? account['vendorInfo'].toString()
          : account['clientCode'] ?? '')
          : null,
      isOwn: account['isOwn'] ?? false,
      mobileNumber: account['mobileNumber'] ?? '',
      ip: ip ??
          (account['ip']?.toString().isNotEmpty == true
              ? account['ip'].toString()
              : null),
    );
  }

  // ── Add account dialog ──────────────────────────────────────────────────────
  void _showAddAccountDialog(List<Map<String, dynamic>> allAccounts) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AddChildAccountDialog(
        nonAdminAccounts: _activeAccounts(allAccounts),
        actionType: AccountDialogAction.add,
        callBack: () {
          _load();
        },
      ),
    );
  }

  // ── Edit account dialog ─────────────────────────────────────────────────────
  void _showEditAccountDialog(
      Map<String, dynamic> account,
      List<Map<String, dynamic>> allAccounts,
      ) {
    final broker = _resolveBrokerApi(account['broker'] as String);
    final motilal = _isMotilal(broker);

    final existingData = <String, dynamic>{
      'id': account['id'],
      'clientId': account['clientCode'],
      'broker': broker,
      'nickName': account['name'],
      'accountType': account['accountType'] ?? 'Non-Admin',
      'mpin': account['mpin'] ?? '',
      'apiKey': account['apiKey'] ?? '',
      'mobileNumber': account['mobileNumber'] ?? '',
      'totpKey': account['totpKey'] ?? '',
      'password': account['password'] ?? '',
      'totpReferenceKey': account['totpKey'] ?? '',
      'dob': account['dob'] ?? '',
      'childIds': account['childIds'] ?? <String>[],
      'ownAccount': account['isOwn'] ?? false,
      'ip': account['ip'] ?? '',
      'portNo': account['portNo'],
      if (motilal) 'apiSecretKey': account['apiSecretKey'] ?? '',
      if (motilal)
        'vendorInfo': (account['vendorInfo']?.toString().isNotEmpty == true)
            ? account['vendorInfo'].toString()
            : account['clientCode'] ?? '',
    };

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AddChildAccountDialog(
        nonAdminAccounts: _activeAccounts(allAccounts),
        actionType: AccountDialogAction.update,
        existingAccount: existingData,
        callBack: () {
          _load();
        },
      ),
    );
  }

  // ── Delete / Remove account dialog ─────────────────────────
  void _showDeleteAccountDialog(Map<String, dynamic> account) {
    final clientCode = account['clientCode']?.toString() ?? '';
    final name = account['name']?.toString() ?? 'Account';
    final broker = account['broker']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text(
              'Remove Broker Account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove account "$name" ($clientCode - $broker)?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Text(
                'This will permanently disconnect and remove this broker account from the system.',
                style: TextStyle(color: Color(0xFF991B1B), fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete'),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _deleteAccount(account);
            },
          ),
        ],
      ),
    );
  }

  void _deleteAccount(Map<String, dynamic> account) {
    final clientCode = account['clientCode']?.toString() ?? '';
    setState(() => _pendingStatusUpdate.add(clientCode));

    context.read<AddDematBloc>().add(
      AddDematAccountEvent(
        id: account['id'] as int?,
        clientId: clientCode,
        broker: _resolveBrokerApi(account['broker'] as String? ?? ''),
        mobileNumber: account['mobileNumber'] as String? ?? '',
        apiKey: account['apiKey'] as String? ?? '',
        mpin: '',
        password: '',
        totpReferenceKey: '',
        dob: null,
        isAdmin: false,
        childIds: [],
        nickName: account['name'] as String? ?? '',
        actionType: 'DELETE',
        isOwn: account['isOwn'] == true,
        apiSecretKey: null,
        vendorInfo: null,
        ip: account['ip'] as String? ?? '',
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => FilterSortDialog(
        currentStatus: _statusFilter,
        currentSortBy: _sortBy,
        onApply: (status, sortBy) {
          setState(() {
            _statusFilter = status;
            _sortBy = sortBy;
          });
        },
      ),
    );
  }

  void _showAccountDetails(Map<String, dynamic> account) {
    showDialog(
      context: context,
      builder: (context) => _AccountDetailsDialog(account: account),
    );
  }

  // ── Connect / OAuth popup ───────────────────────────────────────────────────
  void _showConnectDialog(Map<String, dynamic> account) {
    final broker = _resolveBrokerApi(account['broker'] as String);
    final clientCode = account['clientCode'] as String? ?? '';
    final brokerUpper = broker.toUpperCase();

    _openOAuthPopup(brokerUpper, clientCode);
  }

  void _openOAuthPopup(String broker, String clientId) {
    const backendUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8081');
    final connectUrl = '$backendUrl/api/v1/oauth/connect/$broker?clientId=${Uri.encodeComponent(clientId)}';

    // Open popup window
    html.window.open(connectUrl, 'BrokerAuth_$clientId', 'width=650,height=750,menubar=no,toolbar=no,location=no');

    // Subscribe to postMessage callback from popup
    StreamSubscription? sub;
    sub = html.window.onMessage.listen((event) {
      try {
        if (event.data is Map) {
          final data = event.data as Map;
          final type = data['type']?.toString();
          final targetClient = data['clientId']?.toString();

          if (type == 'BROKER_CONNECTED' && (targetClient == clientId || targetClient == null)) {
            sub?.cancel();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$broker account ($clientId) connected successfully!'),
                backgroundColor: const Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
            // Refresh account list automatically!
            _load();
          } else if (type == 'BROKER_AUTH_FAILED' && (targetClient == clientId || targetClient == null)) {
            sub?.cancel();
            final errMsg = data['error']?.toString() ?? 'Authentication rejected';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to connect $broker: $errMsg'),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
              ),
            );
            _load();
          }
        }
      } catch (e) {
        // ignore
      }
    });
  }

  void _showDirectReconnectDialog(Map<String, dynamic> account, String broker) {
    final clientCode = account['clientCode'] as String? ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sync_lock_rounded, color: Color(0xFF0284C7)),
            const SizedBox(width: 8),
            Text('Reconnect $broker', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client ID: $clientCode', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            const Text(
              'To reconnect this account with the official broker API, click below to verify or update your trading credentials.',
              style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showEditAccountDialog(account, []);
            },
            child: const Text('Update & Authenticate'),
          ),
        ],
      ),
    );
  }

  // ── Eye button: trigger balance refresh ─────────────────────────────────────
  void _onRefreshBalance(int accountId) {
    if (_loadingBalanceIds.contains(accountId)) return;
    setState(() => _loadingBalanceIds.add(accountId));
    context.read<FetchAccountBalanceBloc>().add(LoadAccountBalance(accountId));
  }

  // ── Status toggle ───────────────────────────────────────────────────────────
  void _showEditStatusMenu(
      BuildContext context,
      Map<String, dynamic> account,
      Offset offset,
      ) async {
    final currentStatus = (account['status'] as String).toUpperCase();
    final clientCode = account['clientCode'] as String;

    if (_pendingStatusUpdate.contains(clientCode)) return;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        offset.dx + 1,
        offset.dy + 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: [
        PopupMenuItem(
          value: 'ACTIVE',
          child: _statusMenuItem('Set Active', const Color(0xFF059669)),
        ),
        PopupMenuItem(
          value: 'INACTIVE',
          child: _statusMenuItem('Set Inactive', const Color(0xFFDC2626)),
        ),
      ],
    );

    if (result == null || result.toUpperCase() == currentStatus) return;

    final isActive = result.toUpperCase() == 'ACTIVE';

    if (isActive) {
      final broker = _resolveBrokerApi(account['broker'] as String);
      final ipResult = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _IpInputDialog(brokerApiKey: broker),
      );

      if (ipResult == null) return;

      setState(() => _pendingStatusUpdate.add(clientCode));
      if (mounted) {
        context.read<AddDematBloc>().add(
          _buildEvent(
            account: account,
            actionType: 'UPDATE',
            active: true,
            ip: ipResult,
          ),
        );
      }
      return;
    }

    setState(() => _pendingStatusUpdate.add(clientCode));
    context.read<AddDematBloc>().add(
      _buildEvent(account: account, actionType: 'UPDATE', active: false),
    );
  }

  Widget _statusMenuItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AddDematBloc, AddDematAccountState>(
          listener: (context, state) {
            if (state is AddDematAccountSuccess) {
              setState(() => _pendingStatusUpdate.clear());
              _load();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Operation completed successfully'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else if (state is AddDematAccountFailure) {
              setState(() => _pendingStatusUpdate.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: const Color(0xFFDC2626),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
        BlocListener<FetchAccountBalanceBloc, FetchAccountBalanceState>(
          listener: (context, state) {
            if (state is FetchAccountBalanceLoaded) {
              setState(() {
                _loadingBalanceIds.remove(state.pyBrokerId);
                _refreshedBalances[state.pyBrokerId] = state.availableCash;
              });
            } else if (state is FetchAccountBalanceError) {
              setState(() => _loadingBalanceIds.remove(state.pyBrokerId));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Balance refresh failed: ${state.message}'),
                  backgroundColor: const Color(0xFFDC2626),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<FetchUserDematBloc, FetchUserDematState>(
        builder: (context, state) {
          if (state is FetchUserDematLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            );
          }

          if (state is FetchUserDematError) {
            return _buildErrorState(state.message, []);
          }

          if (state is FetchUserDematLoaded) {
            final allAccounts = state.accounts.map((item) {
              final clientCode = item.clientId;
              final rawStatus = item.active ? 'ACTIVE' : 'INACTIVE';
              final vendorInfo = (item.vendorInfo?.isNotEmpty == true)
                  ? item.vendorInfo!
                  : clientCode;

              return <String, dynamic>{
                'id': item.id,
                'name': item.userName,
                'clientCode': clientCode,
                'broker': item.brokerType,
                'assignedTo': item.assignedTo,
                'availableCash': item.availableCash,
                'portfolioValue': '₹ ${item.availableCash.toStringAsFixed(2)}',
                'created': item.createdDate,
                'status': rawStatus,
                'accountType': item.isAdmin ? 'Admin' : 'Non-Admin',
                'mpin': item.mpin ?? '',
                'apiKey': item.apiKey ?? '',
                'totpKey': item.totpKey ?? '',
                'password': item.password ?? '',
                'dob': item.dob ?? '',
                'childIds': item.childIds ?? <String>[],
                'isOwn': item.isOwnAccount ?? false,
                'apiSecretKey': item.apiSecretKey ?? '',
                'vendorInfo': vendorInfo,
                'ip': item.ip ?? '',
                'mobileNumber': item.mobileNumber ?? '',
                'tokenUpdated': item.tokenUpdated ?? false,
                'lastLoginStatus': item.lastLoginStatus ?? '',
                'lastLoginError': item.lastLoginError ?? '',
                'lastLoginAttempt': item.lastLoginAttempt ?? '',
              };
            }).toList();

            final displayed = _applyFilterAndSort(allAccounts);
            return _buildMainUI(displayed, allAccounts);
          }

          return _buildErrorState(
            'Something went wrong. Please try again.',
            [],
          );
        },
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  Widget _buildErrorState(
      String message,
      List<Map<String, dynamic>> allAccounts,
      ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 30, right: 30, bottom: 30, top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accounts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage linked trading accounts',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildToolbar('Unable to load accounts', allAccounts),
                const SizedBox(height: 20),
                _buildApiErrorBody(message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiErrorBody(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFF9FAFB),
      ),
      child: Center(
        child: Lottie.asset(
          'assets/animations/No Data.json',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildMainUI(
      List<Map<String, dynamic>> displayed,
      List<Map<String, dynamic>> allAccounts,
      ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 30, right: 30, bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildLegend(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildToolbar(
                  '${displayed.length} account${displayed.length == 1 ? '' : 's'} found',
                  allAccounts,
                ),
                const SizedBox(height: 14),
                _buildBrokerFilterChips(),
                const SizedBox(height: 16),
                displayed.isEmpty
                    ? _buildEmptyState()
                    : _buildDataTable(displayed, allAccounts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Broker filter chips ─────────────────────────────────────────────────────
  Widget _buildBrokerFilterChips() {
    final brokers = [
      ('ALL', 'All Brokers', null),
      ('ANGELONE', 'Angel One', const Color(0xFFB45309)),
      ('MOTILAL', 'Motilal Oswal', const Color(0xFF065F46)),
      ('DHAN', 'Dhan', const Color(0xFFD97706)),
      ('PROFITMART', 'Profit Mart', const Color(0xFF7C3AED)),
      ('GOODWILL', 'Goodwill', const Color(0xFF0369A1)),
      ('ZERODHA', 'Zerodha', const Color(0xFFEA580C)),
      ('UPSTOX', 'Upstox', const Color(0xFF4F46E5)),
      ('GROWW', 'Groww (No API)', const Color(0xFF6B7280)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: brokers.map((entry) {
          final (value, label, color) = entry;
          final isSelected = _brokerFilter == value;
          final chipColor = color ?? AppColors.primaryBlue;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _brokerFilter = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? chipColor.withOpacity(0.12)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? chipColor : const Color(0xFFE5E7EB),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: chipColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                        color:
                        isSelected ? chipColor : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        _legendItem(Colors.white, const Color(0xFFE5E7EB), 'Regular account'),
        _legendItem(
          const Color(0xFFFFFBEB),
          const Color(0xFFFCD34D),
          'Own account',
          icon: Icons.star_rounded,
          iconColor: const Color(0xFFD97706),
        ),
        _legendItem(
          const Color(0xFFFFF0F0),
          const Color(0xFFFFCDD2),
          'Inactive account',
        ),
        // ── NEW: legend entry for token expired ────────────────────────────
        _legendItem(
          const Color(0xFFFFF5F5),
          const Color(0xFFFCA5A5),
          'Token expired — reconnect required',
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFDC2626),
        ),
      ],
    );
  }

  Widget _legendItem(
      Color bg,
      Color border,
      String label, {
        IconData? icon,
        Color? iconColor,
      }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: icon != null ? Icon(icon, size: 12, color: iconColor) : null,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildToolbar(
      String subtitle,
      List<Map<String, dynamic>> allAccounts,
      ) {
    final bool isLimitReached =
        _noOfClients > 0 && allAccounts.length >= _noOfClients;

    String? disabledReason;
    if (_isExpired) {
      disabledReason =
      'Your session has expired. Please renew to add accounts.';
    } else if (isLimitReached) {
      disabledReason =
      'Maximum $_noOfClients account${_noOfClients == 1 ? '' : 's'} allowed for your plan.';
    }
    final String role = html.window.sessionStorage['user_role'] ?? '';

    final bool addButtonDisabled =
    role == 'SUPER_ADMIN' ? false : _isExpired || isLimitReached;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Linked Accounts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _showFilterDialog,
              icon: const Icon(Icons.filter_list, size: 16),
              label: Text(
                _statusFilter != 'ALL' ? 'Filter: $_statusFilter' : 'Filter',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                side: const BorderSide(color: AppColors.primaryBlue),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: disabledReason ?? '',
              triggerMode: addButtonDisabled
                  ? TooltipTriggerMode.tap
                  : TooltipTriggerMode.manual,
              child: ElevatedButton.icon(
                onPressed: addButtonDisabled
                    ? null
                    : () => _showAddAccountDialog(allAccounts),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add Account',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
                  disabledForegroundColor: const Color(0xFF9CA3AF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFF9FAFB),
      ),
      child: Center(
        child: Lottie.asset(
          'assets/animations/No Data.json',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildDataTable(
      List<Map<String, dynamic>> accounts,
      List<Map<String, dynamic>> allAccounts,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showAssigned = constraints.maxWidth > 700;
        final showPortfolio = constraints.maxWidth > 520;
        final showPhone = constraints.maxWidth > 860;

        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: double.infinity,
            child: DataTable(
              columnSpacing: 8,
              horizontalMargin: 12,
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 52,
              dividerThickness: 1,
              border: TableBorder(
                horizontalInside: const BorderSide(
                  color: Color(0xFFE5E7EB),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              headingRowColor: WidgetStateProperty.all(AppColors.primary),
              columns: [
                const DataColumn(label: _HeaderLabel('Name')),
                const DataColumn(label: _HeaderLabel('Client Code')),
                const DataColumn(label: _HeaderLabel('Broker')),
                if (showPhone) const DataColumn(label: _HeaderLabel('Phone')),
                const DataColumn(
                    label: _HeaderLabel('Created Date & Time')),
                if (showAssigned)
                  const DataColumn(label: _HeaderLabel('Assigned To')),
                if (showPortfolio)
                  const DataColumn(
                    label: _HeaderLabel('Trade Balance'),
                    numeric: true,
                  ),
                const DataColumn(label: _HeaderLabel('Status')),
                const DataColumn(label: _HeaderLabel('Actions')),
              ],
              rows: List.generate(accounts.length, (index) {
                final account = accounts[index];
                final isInactive =
                    account['status'].toString().toUpperCase() == 'INACTIVE';
                final isOwnAccount = account['isOwn'] == true;
                final clientCode = account['clientCode'] as String;
                final isPending = _pendingStatusUpdate.contains(clientCode);
                final accountId = account['id'] as int;
                final isBalanceLoading =
                _loadingBalanceIds.contains(accountId);
                final bool hasRefreshedBalance =
                _refreshedBalances.containsKey(accountId);

                // ── Token-expired flag (Profitmart only) ──────────────────
                final broker = _resolveBrokerApi(account['broker'] as String);
                final bool isProfitmart =
                broker.toUpperCase().contains('PROFITMART');
                final bool tokenUpdated = account['tokenUpdated'] == true;
                // needsReconnect is true only for Profitmart when token is stale
                final bool needsReconnect = isProfitmart && !tokenUpdated;

                final double displayCash = hasRefreshedBalance
                    ? _refreshedBalances[accountId]!
                    : (account['availableCash'] as double? ?? 0.0);
                final String portfolioDisplay =
                    '₹ ${displayCash.toStringAsFixed(2)}';

                // ── Row color: token-expired overrides other states ────────
                final Color rowColor;
                if (needsReconnect) {
                  // Soft red tint so the row stands out as needing attention
                  rowColor = const Color(0xFFFFF5F5);
                } else if (isInactive) {
                  rowColor = const Color(0xFFFFF0F0);
                } else if (isOwnAccount) {
                  rowColor = const Color(0xFFFFFBEB);
                } else {
                  rowColor =
                  index.isEven ? Colors.white : const Color(0xFFF9FAFB);
                }

                final phone =
                (account['mobileNumber'] as String?)?.isNotEmpty == true
                    ? account['mobileNumber'] as String
                    : '—';

                final bool actionsDisabled = _isExpired;
                final bool isConnected = account['lastLoginStatus']?.toString().toUpperCase() == 'SUCCESS';
                final bool showConnect = !isConnected;

                return DataRow(
                  color: WidgetStateProperty.all(rowColor),
                  cells: [
                    // ── Name ─────────────────────────────────────────────────
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOwnAccount) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                          ],
                          // ── Warning icon when Profitmart token is stale ──
                          if (needsReconnect) ...[
                            Tooltip(
                              message:
                              'Token expired — please reconnect this Profitmart account',
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: InkWell(
                              onTap: () => _showAccountDetails(account),
                              child: Text(
                                account['name'],
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryBlue,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primaryBlue,
                                ),
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Client Code ───────────────────────────────────────────
                    DataCell(
                      Text(
                        account['clientCode'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF374151),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // ── Broker ────────────────────────────────────────────────
                    DataCell(
                      Text(
                        account['broker'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF374151),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // ── Phone ─────────────────────────────────────────────────
                    if (showPhone)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (phone != '—') ...[
                              const Icon(
                                Icons.phone_outlined,
                                size: 13,
                                color: Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                phone,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: phone == '—'
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF374151),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // ── Created Date ──────────────────────────────────────────
                    DataCell(
                      Text(
                        account['created'] != null
                            ? DateFormat('dd MMM yyyy, hh:mm a').format(
                          DateTime.parse(account['created']).toLocal(),
                        )
                            : '-',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // ── Assigned To ───────────────────────────────────────────
                    if (showAssigned)
                      DataCell(
                        Text(
                          account['assignedTo'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    // ── Trading Balance ───────────────────────────────────────
                    if (showPortfolio)
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: isBalanceLoading
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryBlue,
                            ),
                          )
                              : (isInactive && !hasRefreshedBalance)
                              ? Tooltip(
                            message: 'Click to view balance',
                            child: InkWell(
                              onTap: () =>
                                  _onRefreshBalance(accountId),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Container(),
                              ),
                            ),
                          )
                              : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                !hasRefreshedBalance
                                    ? ''
                                    : portfolioDisplay,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: hasRefreshedBalance
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF111827),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Refresh balance',
                                child: InkWell(
                                  onTap: () =>
                                      _onRefreshBalance(accountId),
                                  borderRadius:
                                  BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      hasRefreshedBalance
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off,
                                      size: 15,
                                      color: hasRefreshedBalance
                                          ? const Color(0xFF059669)
                                          : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // ── Status ────────────────────────────────────────────────
                    DataCell(
                      isPending
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryBlue,
                        ),
                      )
                          : _buildStatusBadge(account['status'], account),
                    ),
                    // ── Actions ───────────────────────────────────────────────
                    DataCell(
                      actionsDisabled
                          ? Tooltip(
                        message:
                        'Actions disabled: your session has expired.',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionButton(
                              icon: Icons.edit_outlined,
                              color: const Color(0xFFD1D5DB),
                              tooltip: 'Session expired',
                              disabled: true,
                              onTap: (_) {},
                            ),
                            const SizedBox(width: 8),
                            _ActionButton(
                              icon: Icons.swap_vert_outlined,
                              color: const Color(0xFFD1D5DB),
                              tooltip: 'Session expired',
                              disabled: true,
                              onTap: (_) {},
                            ),
                            if (showConnect) ...[
                              const SizedBox(width: 8),
                              _ActionButton(
                                icon: Icons.link_outlined,
                                color: const Color(0xFFD1D5DB),
                                tooltip: 'Session expired',
                                disabled: true,
                                onTap: (_) {},
                              ),
                            ],
                            const SizedBox(width: 8),
                            _ActionButton(
                              icon: Icons.delete_outline_rounded,
                              color: const Color(0xFFD1D5DB),
                              tooltip: 'Session expired',
                              disabled: true,
                              onTap: (_) {},
                            ),
                          ],
                        ),
                      )
                          : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ActionButton(
                            icon: Icons.edit_outlined,
                            color: const Color(0xFF6366F1),
                            tooltip: 'Edit Account',
                            onTap: (_) => _showEditAccountDialog(
                              account,
                              allAccounts,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.swap_vert_outlined,
                            color: isPending
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFF0EA5E9),
                            tooltip: isPending
                                ? 'Updating...'
                                : 'Change Status',
                            onTap: isPending
                                ? (_) {}
                                : (offset) => _showEditStatusMenu(
                              context,
                              account,
                              offset,
                            ),
                          ),
                          // ── Connect button — red when token is stale ──────
                          if (showConnect) ...[
                            const SizedBox(width: 8),
                            needsReconnect
                                ? _ConnectWarningButton(
                              onTap: (_) =>
                                  _showConnectDialog(account),
                            )
                                : _ActionButton(
                              icon: Icons.link_rounded,
                              color: const Color(0xFF0284C7),
                              tooltip: 'Connect $broker Account',
                              onTap: (_) =>
                                  _showConnectDialog(account),
                            ),
                          ],
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.delete_outline_rounded,
                            color: isPending
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFFEF4444),
                            tooltip: isPending ? 'Processing...' : 'Delete Account',
                            onTap: isPending
                                ? (_) {}
                                : (_) => _showDeleteAccountDialog(account),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, [Map<String, dynamic>? account]) {
    final lastStatus = account?['lastLoginStatus']?.toString().toUpperCase() ?? '';
    final lastError = account?['lastLoginError']?.toString() ?? '';
    final isInactive = status.toUpperCase() == 'INACTIVE';

    if (isInactive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF9CA3AF), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            const Text(
              'Disconnected',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (lastStatus == 'FAILED') {
      return Tooltip(
        message: lastError.isNotEmpty ? 'Auth error: $lastError' : 'Broker authentication failed',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF87171)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.error_outline, size: 12, color: Color(0xFFDC2626)),
              SizedBox(width: 4),
              Text(
                'Auth Failed',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (lastStatus == 'SUCCESS') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF34D399)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF059669)),
            SizedBox(width: 4),
            Text(
              'Connected',
              style: TextStyle(
                color: Color(0xFF059669),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle)),
          const SizedBox(width: 5),
          const Text(
            'Active',
            style: TextStyle(
              color: Color(0xFF059669),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONNECT WARNING BUTTON  (red pulsing button shown when tokenUpdated=false)
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectWarningButton extends StatefulWidget {
  final void Function(Offset) onTap;
  const _ConnectWarningButton({required this.onTap});

  @override
  State<_ConnectWarningButton> createState() => _ConnectWarningButtonState();
}

class _ConnectWarningButtonState extends State<_ConnectWarningButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Token expired — tap to reconnect Profitmart',
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => InkWell(
          onTapDown: (d) => widget.onTap(d.globalPosition),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              // Pulsing red background
              color: Color.lerp(
                const Color(0xFFFFE4E4),
                const Color(0xFFFFCDD2),
                _pulse.value,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Color.lerp(
                  const Color(0xFFFCA5A5),
                  const Color(0xFFDC2626),
                  _pulse.value,
                )!,
                width: 1.2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: Color.lerp(
                    const Color(0xFFEF4444),
                    const Color(0xFFDC2626),
                    _pulse.value,
                  ),
                ),
                // Small warning badge at top-right corner
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.priority_high_rounded,
                      size: 6,
                      color: Colors.white,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// BROKER CONNECT DIALOG
// ─────────────────────────────────────────────────────────────────────────────

enum _ConnectStep { totpAndClientId, exchangeToken }

class _BrokerConnectDialog extends StatefulWidget {
  final Map<String, dynamic> account;
  final String broker;

  const _BrokerConnectDialog({
    required this.account,
    required this.broker,
  });

  @override
  State<_BrokerConnectDialog> createState() => _BrokerConnectDialogState();
}

class _BrokerConnectDialogState extends State<_BrokerConnectDialog> {
  _ConnectStep _step = _ConnectStep.totpAndClientId;

  final _codeCtrl = TextEditingController();

  String _currentTotp = '';
  int _totpCountdown = 30;
  Timer? _countdownTimer;
  bool _totpLoading = false;

  String _loginUrl = '';
  bool _loginPageOpened = false;

  String get _totpKey => widget.account['totpKey'] as String? ?? '';
  String get _secretKey => widget.account['apiKey'] as String? ?? '';
  String get _apiKey => widget.account['apiKey'] as String? ?? '';
  String get _clientId => widget.account['clientCode'] as String? ?? '';

  bool get _isProfitmart =>
      widget.broker.toUpperCase().contains('PROFITMART');

  Color get _accentColor =>
      _isProfitmart ? const Color(0xFF7C3AED) : const Color(0xFF0369A1);

  List<Color> get _gradientColors => _isProfitmart
      ? [const Color(0xFF5B21B6), const Color(0xFF7C3AED)]
      : [const Color(0xFF075985), const Color(0xFF0369A1)];

  String get _brokerLabel => _isProfitmart ? 'Profitmart' : 'Goodwill';

  // Whether this dialog was opened because of a token-expired warning
  bool get _isReconnect => widget.account['tokenUpdated'] == false;

  @override
  void initState() {
    super.initState();
    if (_totpKey.isNotEmpty) {
      _fetchTotp();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _fetchTotp() {
    if (!mounted) return;
    setState(() => _totpLoading = true);

    final bloc = context.read<BrokerOAuthBloc>();
    if (_isProfitmart) {
      bloc.add(GenerateProfitmartTotp(totpKey: _totpKey));
    } else {
      bloc.add(GenerateGoodwillTotp(totpKey: _totpKey));
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _totpCountdown = 30);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _totpCountdown--;
        if (_totpCountdown <= 0) {
          t.cancel();
          _fetchTotp();
        }
      });
    });
  }

  void _copyTotp() {
    if (_currentTotp.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _currentTotp));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('TOTP copied to clipboard'),
        backgroundColor: Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openLoginPage(BuildContext ctx) {
    if (_clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client ID not found. Please check your account.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final bloc = ctx.read<BrokerOAuthBloc>();
    if (_isProfitmart) {
      bloc.add(ProfitmartOpenLoginUrl(clientId: _clientId));
    } else {
      bloc.add(GoodwillOpenLoginUrl(clientId: _clientId));
    }
  }

  void _exchangeToken(BuildContext ctx) {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    final bloc = ctx.read<BrokerOAuthBloc>();
    if (_isProfitmart) {
      bloc.add(ProfitmartExchangeToken(
        userId: _clientId,
        code: code,
        secretKey: _secretKey,
      ));
    } else {
      bloc.add(GoodwillExchangeToken(
        userId: _clientId,
        code: code,
        secretKey: _secretKey,
        apiKey: _apiKey,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BrokerOAuthBloc, BrokerOAuthState>(
      listener: (ctx, state) {
        if (state is ProfitmartTotpGenerated && _isProfitmart) {
          setState(() {
            _currentTotp = state.totp;
            _totpLoading = false;
          });
          _startCountdown();
        }
        if (state is GoodwillTotpGenerated && !_isProfitmart) {
          setState(() {
            _currentTotp = state.totp;
            _totpLoading = false;
          });
          _startCountdown();
        }

        if (state is ProfitmartLoginUrlOpened) {
          html.window.open(state.loginUrl, '_blank');
          setState(() {
            _loginUrl = state.loginUrl;
            _loginPageOpened = true;
            _step = _ConnectStep.exchangeToken;
          });
        }
        if (state is GoodwillLoginUrlOpened) {
          html.window.open(state.loginUrl, '_blank');
          setState(() {
            _loginUrl = state.loginUrl;
            _loginPageOpened = true;
            _step = _ConnectStep.exchangeToken;
          });
        }

        if (state is ProfitmartTokenSuccess || state is GoodwillTokenSuccess) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_brokerLabel connected successfully!'),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
            ),
          );
          ctx.read<BrokerOAuthBloc>().add(BrokerOAuthReset());
        }

        if (state is BrokerOAuthFailure) {
          setState(() => _totpLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (ctx, state) {
        final isLoading = state is BrokerOAuthLoading;

        return Dialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          child: Container(
            width: 500,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(ctx),
                  // ── Token-expired warning banner inside dialog ──────────
                  if (_isReconnect)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      color: const Color(0xFFFFF5F5),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF991B1B)),
                                children: [
                                  TextSpan(
                                    text: 'Token expired. ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(
                                    text:
                                    'Your Profitmart session has expired. '
                                        'Please complete the OAuth flow below to reconnect.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _step == _ConnectStep.totpAndClientId
                              ? _buildStep1(ctx, isLoading)
                              : _buildStep2(ctx, isLoading),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext ctx) {
    final stepNum = _step == _ConnectStep.totpAndClientId ? 1 : 2;

    // If reconnect, use a red-tinted gradient to reinforce urgency
    final gradientColors = _isReconnect
        ? [const Color(0xFF991B1B), const Color(0xFFDC2626)]
        : _gradientColors;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isReconnect
                  ? Icons.warning_amber_rounded
                  : Icons.link_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isReconnect
                      ? 'Reconnect $_brokerLabel'
                      : 'Connect $_brokerLabel',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isReconnect
                      ? 'Token expired — re-authenticate to restore access'
                      : 'OAuth 2.0 authentication',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          _StepIndicator(
              current: stepNum, total: 2, accentColor: Colors.white),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              ctx.read<BrokerOAuthBloc>().add(BrokerOAuthReset());
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, size: 17, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(BuildContext ctx, bool isLoading) {
    final double progress = _totpCountdown / 30.0;
    final Color timerColor = _totpCountdown > 10
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);

    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _InfoBanner(
          icon: Icons.info_outline_rounded,
          message:
          'A time-based OTP (TOTP) has been generated for your account. '
              'Copy it, then click "Open Login Page" to authenticate with '
              '$_brokerLabel in a new tab.',
          bgColor: const Color(0xFFF0F9FF),
          borderColor: const Color(0xFFBAE6FD),
          iconColor: const Color(0xFF0284C7),
          textColor: const Color(0xFF0C4A6E),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Client ID',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _clientId.isNotEmpty ? _clientId : '—',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Text(
                  'From account',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your TOTP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          backgroundColor: const Color(0xFFE5E7EB),
                          valueColor:
                          AlwaysStoppedAnimation<Color>(timerColor),
                        ),
                        Text(
                          '$_totpCountdown',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: timerColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _totpLoading
                  ? const SizedBox(
                height: 52,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ..._currentTotp.split('').asMap().entries.map((e) {
                    if (e.key == 3) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 10),
                          _totpDigitBox(e.value),
                        ],
                      );
                    }
                    return _totpDigitBox(e.value);
                  }),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _currentTotp.isEmpty ? null : _copyTotp,
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy TOTP',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accentColor,
                      side: BorderSide(color: _accentColor),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _totpLoading ? null : _fetchTotp,
                    icon: _totpLoading
                        ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accentColor,
                      ),
                    )
                        : const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Refresh',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ctx.read<BrokerOAuthBloc>().add(BrokerOAuthReset());
                  Navigator.pop(context);
                },
                style: _cancelStyle(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : () => _openLoginPage(ctx),
                icon: isLoading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(isLoading ? 'Opening...' : 'Open Login Page'),
                style: _primaryStyle(_accentColor),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _totpDigitBox(String digit) {
    return Container(
      width: 42,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _accentColor.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _accentColor,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildStep2(BuildContext ctx, bool isLoading) {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _InfoBanner(
          icon: Icons.open_in_new_rounded,
          message:
          'The $_brokerLabel login page has been opened in a new tab. '
              'Complete the login there, then copy the authorization code '
              'and paste it below.',
          bgColor: const Color(0xFFECFDF5),
          borderColor: const Color(0xFFA7F3D0),
          iconColor: const Color(0xFF059669),
          textColor: const Color(0xFF065F46),
        ),
        const SizedBox(height: 16),

        if (_loginUrl.isNotEmpty) ...[
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 13, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _loginUrl,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => html.window.open(_loginUrl, '_blank'),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.open_in_new_rounded,
                        size: 13, color: _accentColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        _FieldLabel('Authorization Code', required: true),
        const SizedBox(height: 8),
        TextField(
          controller: _codeCtrl,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          decoration: _inputDecoration(
            hint: 'Paste authorization code here',
            prefixIcon: Icons.key_rounded,
          ),
        ),

        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            border: Border.all(color: const Color(0xFFA7F3D0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded,
                  size: 15, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Secret key on file: ${_maskKey(_secretKey)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF065F46),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),

        if (!_isProfitmart) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              border: Border.all(color: const Color(0xFFBAE6FD)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.api_rounded,
                    size: 15, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'API key on file: ${_maskKey(_apiKey)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0C4A6E),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading
                    ? null
                    : () =>
                    setState(() => _step = _ConnectStep.totpAndClientId),
                style: _cancelStyle(),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : () => _exchangeToken(ctx),
                icon: isLoading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.check_circle_outline_rounded,
                    size: 16),
                label:
                Text(isLoading ? 'Connecting...' : 'Connect Account'),
                style: _primaryStyle(_accentColor),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _maskKey(String key) {
    if (key.isEmpty) return '—';
    if (key.length <= 4) return '••••';
    return '${key.substring(0, 4)}${'•' * (key.length - 4)}';
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(prefixIcon, size: 18, color: const Color(0xFF9CA3AF)),
      ),
      prefixIconConstraints:
      const BoxConstraints(minWidth: 0, minHeight: 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _accentColor, width: 1.5),
      ),
    );
  }

  ButtonStyle _cancelStyle() => OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 14),
    side: const BorderSide(color: Color(0xFFD1D5DB)),
    foregroundColor: const Color(0xFF374151),
    shape:
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  ButtonStyle _primaryStyle(Color color) => ElevatedButton.styleFrom(
    backgroundColor: color,
    disabledBackgroundColor: color.withOpacity(0.5),
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape:
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP INDICATOR
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  final Color accentColor;

  const _StepIndicator({
    required this.current,
    required this.total,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i + 1 <= current;
        return Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isActive
                    ? accentColor.withOpacity(0.9)
                    : accentColor.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? Colors.white
                        : accentColor.withOpacity(0.7),
                  ),
                ),
              ),
            ),
            if (i < total - 1) ...[
              Container(
                width: 20,
                height: 2,
                color: isActive
                    ? accentColor.withOpacity(0.6)
                    : accentColor.withOpacity(0.2),
              ),
            ],
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color bgColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;

  const _InfoBanner({
    required this.icon,
    required this.message,
    required this.bgColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD LABEL
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        if (required) ...[
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
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IP INPUT DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _IpInputDialog extends StatefulWidget {
  final String brokerApiKey;
  const _IpInputDialog({required this.brokerApiKey});

  @override
  State<_IpInputDialog> createState() => _IpInputDialogState();
}

class _IpInputDialogState extends State<_IpInputDialog> {
  final _ipController = TextEditingController();
  IpValidationStatus _ipStatus = IpValidationStatus.idle;
  String _ipStatusMessage = '';
  int? _validatedPort;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _validateIp() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      setState(() {
        _ipStatus = IpValidationStatus.invalid;
        _ipStatusMessage = 'Please enter an IP address';
      });
      return;
    }

    setState(() {
      _ipStatus = IpValidationStatus.loading;
      _ipStatusMessage = '';
    });

    try {
      final service = ServiceClass();
      final result = await service.validateIpAddress(
        ipAddress: ip,
        brokerType: widget.brokerApiKey,
      );

      if (result['status'] == 'SUCCESS') {
        final dataRaw = result['data'];
        Map<String, dynamic>? dataMap;
        if (dataRaw is String) {
          try {
            dataMap = jsonDecode(dataRaw) as Map<String, dynamic>;
          } catch (_) {}
        } else if (dataRaw is Map) {
          dataMap = Map<String, dynamic>.from(dataRaw);
        }
        setState(() {
          _ipStatus = IpValidationStatus.valid;
          _validatedPort = dataMap?['portNo'] as int?;
          _ipStatusMessage =
              dataMap?['message'] as String? ?? 'IP is valid and available';
        });
      } else {
        final status = result['status'] as int? ?? 0;
        final msgRaw = result['message'] as String? ?? '';
        String displayMsg = msgRaw;
        try {
          final inner = jsonDecode(msgRaw) as Map<String, dynamic>;
          displayMsg = inner['message'] as String? ?? msgRaw;
        } catch (_) {}

        setState(() {
          _validatedPort = null;
          if (status == 404) {
            _ipStatus = IpValidationStatus.notFound;
            _ipStatusMessage = msgRaw;
          } else if (status == 409) {
            _ipStatus = IpValidationStatus.alreadyAssigned;
            _ipStatusMessage = displayMsg;
          } else {
            _ipStatus = IpValidationStatus.invalid;
            _ipStatusMessage = displayMsg;
          }
        });
      }
    } catch (_) {
      setState(() {
        _ipStatus = IpValidationStatus.invalid;
        _ipStatusMessage = 'Validation failed. Please try again.';
        _validatedPort = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isValid = _ipStatus == IpValidationStatus.valid;
    final bool isLoading = _ipStatus == IpValidationStatus.loading;
    final bool isError = _ipStatus == IpValidationStatus.invalid ||
        _ipStatus == IpValidationStatus.notFound ||
        _ipStatus == IpValidationStatus.alreadyAssigned;

    Color borderColor = const Color(0xFFD1D5DB);
    if (isValid) borderColor = const Color(0xFF059669);
    if (isError) borderColor = const Color(0xFFDC2626);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Container(
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
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 18),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.dns_outlined,
                          size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign Server IP',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Enter & validate the IP before activating',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xCCFFFFFF)),
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
                        child: const Icon(Icons.close,
                            size: 17, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        border:
                        Border.all(color: const Color(0xFFBAE6FD)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16, color: Color(0xFF0284C7)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'An IP address must be assigned and validated before this account can be set to Active.',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF0C4A6E)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text(
                          'IP Address',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: const Color(0xFFFCD34D)),
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
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ipController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                            onChanged: (_) {
                              if (_ipStatus != IpValidationStatus.idle) {
                                setState(() {
                                  _ipStatus = IpValidationStatus.idle;
                                  _ipStatusMessage = '';
                                  _validatedPort = null;
                                });
                              }
                            },
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF111827),
                              fontFamily: 'monospace',
                              letterSpacing: 0.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. 192.168.1.100',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9CA3AF),
                                fontFamily: 'monospace',
                              ),
                              filled: true,
                              fillColor: isValid
                                  ? const Color(0xFFF0FDF4)
                                  : isError
                                  ? const Color(0xFFFFF5F5)
                                  : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(
                                    left: 12, right: 8),
                                child: Icon(
                                  Icons.dns_outlined,
                                  size: 18,
                                  color: isValid
                                      ? const Color(0xFF059669)
                                      : isError
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                  minWidth: 0, minHeight: 0),
                              suffixIcon: isValid
                                  ? const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: Color(0xFF059669)),
                              )
                                  : isError
                                  ? const Padding(
                                padding:
                                EdgeInsets.only(right: 12),
                                child: Icon(
                                    Icons.error_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFDC2626)),
                              )
                                  : null,
                              suffixIconConstraints: const BoxConstraints(
                                  minWidth: 0, minHeight: 0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: borderColor,
                                  width: (isValid || isError) ? 1.5 : 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: isValid
                                      ? const Color(0xFF059669)
                                      : isError
                                      ? const Color(0xFFDC2626)
                                      : AppColors.primaryBlue,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (isLoading || isValid)
                                ? null
                                : _validateIp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isValid
                                  ? const Color(0xFF059669)
                                  : AppColors.primaryBlue,
                              disabledBackgroundColor: isValid
                                  ? const Color(0xFF059669).withOpacity(0.7)
                                  : AppColors.primaryBlue.withOpacity(0.5),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: isLoading
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2),
                            )
                                : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isValid
                                      ? Icons.verified_rounded
                                      : Icons.wifi_tethering_rounded,
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isValid ? 'Verified' : 'Validate',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildStatusBanner(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              side: const BorderSide(
                                  color: Color(0xFFD1D5DB)),
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
                            onPressed: isValid
                                ? () => Navigator.pop(
                                context, _ipController.text.trim())
                                : null,
                            icon: const Icon(Icons.check_circle_outline,
                                size: 16),
                            label: const Text('Confirm & Activate',
                                style: TextStyle(fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              disabledBackgroundColor:
                              const Color(0xFF059669).withOpacity(0.4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
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
    );
  }

  Widget _buildStatusBanner() {
    if (_ipStatus == IpValidationStatus.idle ||
        _ipStatus == IpValidationStatus.loading) {
      return const SizedBox.shrink();
    }

    final bool isValid = _ipStatus == IpValidationStatus.valid;
    final bool isAlreadyAssigned =
        _ipStatus == IpValidationStatus.alreadyAssigned;
    final bool isNotFound = _ipStatus == IpValidationStatus.notFound;

    Color bgColor, borderColor, iconColor, textColor;
    IconData icon;

    if (isValid) {
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFFA7F3D0);
      iconColor = const Color(0xFF059669);
      textColor = const Color(0xFF065F46);
      icon = Icons.check_circle_outline_rounded;
    } else if (isAlreadyAssigned) {
      bgColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFFED7AA);
      iconColor = const Color(0xFFD97706);
      textColor = const Color(0xFF92400E);
      icon = Icons.warning_amber_rounded;
    } else if (isNotFound) {
      bgColor = const Color(0xFFF0F9FF);
      borderColor = const Color(0xFFBAE6FD);
      iconColor = const Color(0xFF0284C7);
      textColor = const Color(0xFF0C4A6E);
      icon = Icons.info_outline_rounded;
    } else {
      bgColor = const Color(0xFFFFF5F5);
      borderColor = const Color(0xFFFECACA);
      iconColor = const Color(0xFFDC2626);
      textColor = const Color(0xFF991B1B);
      icon = Icons.error_outline_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _ipStatusMessage,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED ENUMS & SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

enum IpValidationStatus {
  idle,
  loading,
  valid,
  invalid,
  notFound,
  alreadyAssigned,
}

class _HeaderLabel extends StatelessWidget {
  final String label;
  const _HeaderLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      letterSpacing: 0.4,
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final void Function(Offset) onTap;
  final bool disabled;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTapDown: disabled ? null : (d) => onTap(d.globalPosition),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(disabled ? 0.05 : 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: disabled ? const Color(0xFFD1D5DB) : color,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT DETAILS DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _AccountDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> account;
  const _AccountDetailsDialog({required this.account});

  @override
  Widget build(BuildContext context) {
    final status = account['status'] as String;
    final isActive = status.toUpperCase() == 'ACTIVE';
    final isMotilal =
    account['broker'].toString().toUpperCase().contains('MOTILAL');
    final isOwnAccount = account['isOwn'] == true;
    final mobileNumber =
    (account['mobileNumber'] as String?)?.isNotEmpty == true
        ? account['mobileNumber'] as String
        : '-';

    // Token status for Profitmart
    final bool isProfitmart =
    account['broker'].toString().toUpperCase().contains('PROFITMART');
    final bool tokenUpdated = account['tokenUpdated'] == true;
    final bool needsReconnect = isProfitmart && !tokenUpdated;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF334155)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      child: Text(
                        (account['name'] as String).isNotEmpty
                            ? (account['name'] as String)[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  account['name'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (isOwnAccount) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706)
                                        .withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFCD34D)
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded,
                                          size: 11,
                                          color: Color(0xFFFCD34D)),
                                      SizedBox(width: 3),
                                      Text(
                                        'Own',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFFCD34D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              // ── Token-expired badge in details header ──
                              if (needsReconnect) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFCA5A5)
                                          .withOpacity(0.7),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          size: 11,
                                          color: Color(0xFFFCA5A5)),
                                      SizedBox(width: 3),
                                      Text(
                                        'Token Expired',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFFCA5A5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone_outlined,
                                  size: 12,
                                  color: Colors.white.withOpacity(0.6)),
                              const SizedBox(width: 4),
                              Text(
                                mobileNumber,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            account['clientCode'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF059669).withOpacity(0.2)
                            : const Color(0xFFDC2626).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF059669).withOpacity(0.5)
                              : const Color(0xFFDC2626).withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFF87171),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFF87171),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Token-expired inline warning inside details body ──────────
              if (needsReconnect)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  color: const Color(0xFFFFF5F5),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 15, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This Profitmart account\'s token has expired. '
                              'Use the Connect button on the accounts table to re-authenticate.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _DetailSection(
                      title: 'Account Information',
                      icon: Icons.account_circle_outlined,
                      fields: [
                        _DetailField('Broker', account['broker']),
                        _DetailField('Client Code', account['clientCode']),
                        _DetailField('Phone Number', mobileNumber),
                        _DetailField('Assigned To', account['assignedTo']),
                        _DetailField('Created Date', account['created']),
                        _DetailField(
                            'Own Account', isOwnAccount ? 'Yes' : 'No'),
                        _DetailField(
                          'Connection Status',
                          account['lastLoginStatus'] == 'SUCCESS'
                              ? 'Connected'
                              : (account['lastLoginStatus'] == 'FAILED'
                                  ? 'Auth Failed'
                                  : (isActive ? 'Active' : 'Disconnected')),
                          bold: true,
                        ),
                        if (account['lastLoginError']?.toString().isNotEmpty == true)
                          _DetailField(
                            'Auth Error',
                            account['lastLoginError'].toString(),
                          ),
                        if (account['ip']?.toString().isNotEmpty == true)
                          _DetailField('Registered IP', account['ip'].toString()),
                        if (isProfitmart)
                          _DetailField(
                            'Token Status',
                            tokenUpdated ? 'Active' : 'Expired',
                            bold: true,
                          ),
                        if (account['dob']?.toString().isNotEmpty == true)
                          _DetailField(
                            isMotilal
                                ? 'Date of Birth (2FA)'
                                : 'Date of Birth',
                            account['dob'],
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailSection(
                      title: 'Financial Details',
                      icon: Icons.account_balance_outlined,
                      fields: [
                        _DetailField(
                            'Portfolio Value', account['portfolioValue'],
                            bold: true),
                      ],
                    ),
                    if (isMotilal) ...[
                      const SizedBox(height: 16),
                      _DetailSection(
                        title: 'Motilal Oswal Details',
                        icon: Icons.business_center_outlined,
                        fields: [
                          _DetailField(
                            'Vendor Info',
                            account['vendorInfo']?.toString().isNotEmpty ==
                                true
                                ? account['vendorInfo'].toString()
                                : account['clientCode'],
                          ),
                          if (account['apiSecretKey']
                              ?.toString()
                              .isNotEmpty ==
                              true)
                            const _DetailField(
                                'API Secret Key', '••••••••'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border:
                  Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL SECTION & FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_DetailField> fields;
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(icon, size: 15, color: const Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(spacing: 24, runSpacing: 12, children: fields),
          ),
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _DetailField(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.isNotEmpty ? value : '-',
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}