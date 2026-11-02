import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'dart:html' as html;
import '../../../bloc/admin_accounts_bloc/delete_admin_account_bloc/demote_admin_bloc.dart';
import '../../../bloc/admin_accounts_bloc/fetch_py_users_bloc.dart';
import '../../../bloc/broker_fetch_balance_bloc/fetch_account_balance_bloc.dart';
import '../../../bloc/fetch_user_demat_bloc/fetch_user_demat_bloc.dart';
import '../../../constants/colors.dart';
import '../../../models/demat_account.dart';
import '../../../models/py_user.dart';

class GroupAdminsTab extends StatefulWidget {
  const GroupAdminsTab({super.key});

  @override
  State<GroupAdminsTab> createState() => _GroupAdminsTabState();
}

class _GroupAdminsTabState extends State<GroupAdminsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  int? _expandedPyId;
  final Map<int, List<DematAccount>> _dematCache = {};
  final Map<int, bool> _dematLoading = {};
  final Map<int, String?> _dematError = {};

  // ── Balance refresh state (mirrors ChildAccountsTab) ───────────────────────
  /// Stores refreshed balances keyed by account 'id' (int).
  final Map<int, double> _refreshedBalances = {};

  /// Tracks which account ids are currently loading their balance.
  final Set<int> _loadingBalanceIds = {};

  // ── For smooth animated removal ────────────────────────────────────────────
  int? _removingPyId;

  @override
  void initState() {
    super.initState();
    context.read<FetchPyUsersBloc>().add(LoadAdminUsers());
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PyUser> _filtered(List<PyUser> users) {
    if (_searchQuery.isEmpty) return users;
    return users.where((u) {
      return u.fullName.toLowerCase().contains(_searchQuery) ||
          u.email.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadDematForUser(int pyUserId) async {
    if (_dematCache.containsKey(pyUserId)) return;
    setState(() => _dematLoading[pyUserId] = true);
    try {
      context.read<FetchUserDematBloc>().add(LoadUserDematAccounts(pyUserId));
    } catch (_) {
      setState(() {
        _dematLoading[pyUserId] = false;
        _dematError[pyUserId] = 'Failed to load accounts';
      });
    }
  }

  void _toggleRow(int pyUserId) {
    setState(() {
      if (_expandedPyId == pyUserId) {
        _expandedPyId = null;
      } else {
        _expandedPyId = pyUserId;
        _loadDematForUser(pyUserId);
      }
    });
  }

  // ── Eye button: trigger balance refresh for one demat account ──────────────
  void _onRefreshBalance(int accountId) {
    if (_loadingBalanceIds.contains(accountId)) return;
    setState(() => _loadingBalanceIds.add(accountId));
    context.read<FetchAccountBalanceBloc>().add(LoadAccountBalance(accountId));
  }

  // ─── Demote Confirmation Dialog ───────────────────────────────────────────

  Future<void> _confirmDemote(BuildContext context, PyUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: Color(0xFFDC2626),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Remove Admin Access',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'You are about to demote '),
                  TextSpan(
                    text: user.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const TextSpan(text: ' from Admin to User.'),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 13)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Remove Access',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<DemoteAdminBloc>().add(
        DemoteAdminUser(
          superAdminPyId:
              int.tryParse(html.window.sessionStorage['user_id'] ?? '') ?? 0,
          targetPyId: user.pyId,
        ),
      );
    }
  }

  // ─── Snackbars ────────────────────────────────────────────────────────────

  void _showSuccessSnackbar(DemoteAdminSuccess state) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF166534),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF16A34A), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16A34A).withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${state.fullName} demoted successfully',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Role changed to ${state.newRole} · ${state.groupsAffected} group(s) deactivated',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF86EFAC),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () =>
                    ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFF86EFAC),
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<FetchUserDematBloc, FetchUserDematState>(
          listener: (context, state) {
            if (state is FetchUserDematLoaded) {
              setState(() {
                _dematCache[state.pyUserId] = state.accounts;
                _dematLoading[state.pyUserId] = false;
                _dematError.remove(state.pyUserId);
              });
            } else if (state is FetchUserDematError) {
              setState(() {
                _dematLoading[state.pyUserId] = false;
                _dematError[state.pyUserId] = state.message;
              });
            }
          },
        ),
        // ── Balance refresh listener (mirrors ChildAccountsTab) ───────────────
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
        BlocListener<DemoteAdminBloc, DemoteAdminState>(
          listener: (context, state) {
            if (state is DemoteAdminSuccess) {
              setState(() {
                _removingPyId = state.targetPyId;
                if (_expandedPyId == state.targetPyId) {
                  _expandedPyId = null;
                }
              });

              _showSuccessSnackbar(state);
            } else if (state is DemoteAdminError) {}
            context.read<FetchPyUsersBloc>().add(LoadAdminUsers());
          },
        ),
      ],
      child: BlocBuilder<FetchPyUsersBloc, FetchPyUsersState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildCard(state)],
            ),
          );
        },
      ),
    );
  }

  // ─── Main Card ────────────────────────────────────────────────────────────

  Widget _buildCard(FetchPyUsersState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardToolbar(state),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildBody(state),
        ],
      ),
    );
  }

  Widget _buildCardToolbar(FetchPyUsersState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin Accounts',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                state is FetchPyUsersLoaded
                    ? '${_filtered(state.users).length} of ${state.users.length} shown'
                    : 'Loading...',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search name or email…',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF6366F1),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Body States ──────────────────────────────────────────────────────────

  Widget _buildBody(FetchPyUsersState state) {
    if (state is FetchPyUsersLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              color: Color(0xFF6366F1),
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }
    if (state is FetchPyUsersError) return _buildError(state.message);
    if (state is FetchPyUsersLoaded) {
      final users = _filtered(state.users);
      if (users.isEmpty) return _buildEmpty();
      return _buildTable(users);
    }
    return const SizedBox();
  }

  Widget _buildError(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              msg,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  context.read<FetchPyUsersBloc>().add(LoadAdminUsers()),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Container(
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
      ),
    );
  }

  // ─── Table ────────────────────────────────────────────────────────────────

  Widget _buildTable(List<PyUser> users) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, width: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              // Table header
              Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                  color: AppColors.primary,
                ),
                height: 45,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 36),
                    Expanded(flex: 3, child: _TH('Admin Name')),
                    Expanded(flex: 3, child: _TH('Email')),
                    Expanded(flex: 2, child: _TH('Phone')),
                    Expanded(flex: 1, child: _TH('Accounts')),
                    Expanded(flex: 1, child: _TH('Status')),
                    Expanded(flex: 1, child: _TH('Joined')),
                    Expanded(flex: 1, child: _TH('Action')),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              BlocBuilder<DemoteAdminBloc, DemoteAdminState>(
                builder: (context, demoteState) {
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: users.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (_, i) {
                      final user = users[i];
                      final isDemoting =
                          demoteState is DemoteAdminLoading &&
                          demoteState.targetPyId == user.pyId;
                      final isRemoving = _removingPyId == user.pyId;

                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 350),
                        opacity: isRemoving ? 0.0 : 1.0,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 350),
                          offset: isRemoving
                              ? const Offset(0.08, 0)
                              : Offset.zero,
                          curve: Curves.easeInOut,
                          child: _AdminRow(
                            user: user,
                            isExpanded: _expandedPyId == user.pyId,
                            isLoading: _dematLoading[user.pyId] == true,
                            dematAccounts: _dematCache[user.pyId],
                            dematError: _dematError[user.pyId],
                            isDemoting: isDemoting,
                            refreshedBalances: _refreshedBalances,
                            loadingBalanceIds: _loadingBalanceIds,
                            onRefreshBalance: _onRefreshBalance,
                            onTap: () => _toggleRow(user.pyId),
                            onDemote: () => _confirmDemote(context, user),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Admin Row ────────────────────────────────────────────────────────────────

class _AdminRow extends StatelessWidget {
  final PyUser user;
  final bool isExpanded;
  final bool isLoading;
  final bool isDemoting;
  final List<DematAccount>? dematAccounts;
  final String? dematError;
  final Map<int, double> refreshedBalances;
  final Set<int> loadingBalanceIds;
  final void Function(int accountId) onRefreshBalance;
  final VoidCallback onTap;
  final VoidCallback onDemote;

  const _AdminRow({
    required this.user,
    required this.isExpanded,
    required this.isLoading,
    required this.dematAccounts,
    required this.dematError,
    required this.isDemoting,
    required this.refreshedBalances,
    required this.loadingBalanceIds,
    required this.onRefreshBalance,
    required this.onTap,
    required this.onDemote,
  });

  @override
  Widget build(BuildContext context) {
    final initials = user.fullName.isNotEmpty
        ? user.fullName
              .trim()
              .split(' ')
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join()
        : '?';

    final joined = _formatDate(user.createdAt);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: isExpanded ? const Color(0xFFF5F3FF) : Colors.white,
      child: Column(
        children: [
          InkWell(
            onTap: isDemoting ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              child: Row(
                children: [
                  // Chevron
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isExpanded
                          ? const Color(0xFF6366F1)
                          : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Name + avatar
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: isExpanded
                              ? const Color(0xFF6366F1)
                              : const Color(0xFFEEF2FF),
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isExpanded
                                  ? Colors.white
                                  : const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            user.fullName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Email
                  Expanded(
                    flex: 3,
                    child: Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Phone
                  Expanded(
                    flex: 2,
                    child: Text(
                      user.phoneNumber,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  // Accounts count badge
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: 36,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${user.accountsCount}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ),
                  // Status
                  Expanded(flex: 1, child: _StatusBadge(active: user.isActive)),
                  // Joined
                  Expanded(
                    flex: 1,
                    child: Text(
                      joined,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  // ── Demote Action ─────────────────────────────────────────
                  Expanded(
                    flex: 1,
                    child: isDemoting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFDC2626),
                            ),
                          )
                        : Tooltip(
                            message: 'Remove admin access',
                            child: InkWell(
                              onTap: onDemote,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.remove_moderator_outlined,
                                      size: 13,
                                      color: Color(0xFFDC2626),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Remove',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) _buildDematSection(),
        ],
      ),
    );
  }

  Widget _buildDematSection() {
    if (isLoading) {
      return Container(
        color: const Color(0xFFFAF9FF),
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF6366F1),
            ),
          ),
        ),
      );
    }

    if (dematError != null) {
      return Container(
        color: const Color(0xFFFAF9FF),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            dematError!,
            style: const TextStyle(fontSize: 12, color: Colors.red),
          ),
        ),
      );
    }

    final accounts = dematAccounts ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF9FF),
        border: Border(
          top: BorderSide(color: Color(0xFFE0E7FF), width: 1),
          bottom: BorderSide(color: Color(0xFFE0E7FF), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 14, 20, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_rounded,
                  size: 14,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 6),
                Text(
                  'Demat Accounts (${accounts.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4F46E5),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          if (accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 4, 20, 20),
              child: Text(
                'No demat accounts linked to this admin.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 20, 16),
              child: Column(
                children: [
                  // ── Sub-table header (added Cash Balance column header) ───
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: _SubTH('Account Name')),
                        Expanded(flex: 2, child: _SubTH('Client ID')),
                        Expanded(flex: 2, child: _SubTH('Broker')),
                        Expanded(flex: 3, child: _SubTH('Cash Balance')),
                        Expanded(flex: 1, child: _SubTH('Type')),
                        Expanded(flex: 1, child: _SubTH('Status')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...accounts.asMap().entries.map((e) {
                    final acc = e.value;
                    final isEven = e.key.isEven;
                    final accountId = acc.id;
                    final isInactive = !acc.active;
                    final isBalanceLoading = loadingBalanceIds.contains(
                      accountId,
                    );
                    final hasRefreshedBalance = refreshedBalances.containsKey(
                      accountId,
                    );

                    // Use refreshed balance if available, else fall back
                    final double displayCash = hasRefreshedBalance
                        ? refreshedBalances[accountId]!
                        : acc.availableCash;
                    final String balanceDisplay =
                        '₹ ${displayCash.toStringAsFixed(2)}';

                    return Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isEven
                            ? Colors.white
                            : const Color(0xFFF5F3FF).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          // Account Name
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    acc.userName.isNotEmpty
                                        ? acc.userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    acc.userName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Client ID
                          Expanded(
                            flex: 2,
                            child: Text(
                              acc.clientId,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          // Broker
                          Expanded(
                            flex: 2,
                            child: _BrokerChip(broker: acc.brokerType),
                          ),
                          // ── Cash Balance + eye icon ────────────────────────
                          //
                          // Same logic as ChildAccountsTab:
                          //   • Loading       → spinner
                          //   • INACTIVE + not yet fetched
                          //                   → closed-eye icon only
                          //   • All others    → amount + open/filled eye icon
                          //
                          Expanded(
                            flex: 3,
                            child: isBalanceLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: Text("Loading..."),
                                  )
                                // ── Inactive & not yet fetched ──────────────────
                                // Show only a closed-eye icon; no amount text.
                                : (isInactive && !hasRefreshedBalance)
                                ? Container()
                                // ── Amount + eye icon (active or refreshed) ─────
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        balanceDisplay,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: hasRefreshedBalance
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF059669),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(width: 6),
                                      Tooltip(
                                        message: 'Refresh balance',
                                        child: InkWell(
                                          onTap: () =>
                                              onRefreshBalance(accountId),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(2),
                                            child: Icon(
                                              hasRefreshedBalance
                                                  ? Icons.visibility_rounded
                                                  : Icons.visibility_outlined,
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
                          // Type
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: acc.isAdmin
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                acc.isAdmin ? 'Admin' : 'User',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: acc.isAdmin
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF6B7280),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // Status
                          Expanded(
                            flex: 1,
                            child: _StatusBadge(
                              active: acc.active,
                              small: true,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _TH extends StatelessWidget {
  final String label;
  const _TH(this.label);
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: 0.4,
    ),
  );
}

class _SubTH extends StatelessWidget {
  final String label;
  const _SubTH(this.label);
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: Color(0xFF6366F1),
      letterSpacing: 0.3,
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  final bool small;
  const _StatusBadge({required this.active, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: small ? 5 : 6,
            height: small ? 5 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? const Color(0xFF059669) : const Color(0xFFDC2626),
            ),
          ),
          SizedBox(width: small ? 4 : 5),
          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: small ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF059669) : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrokerChip extends StatelessWidget {
  final String broker;
  const _BrokerChip({required this.broker});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (broker.toUpperCase()) {
      case 'ANGELONE':
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFEA580C);
        break;
      case 'MOTILAL':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        break;
      case 'DHAN':
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF16A34A);
        break;
      case 'ZERODHA':
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF16A34A);
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        broker,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}