import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import '../../../bloc/approve_user_to_admin_bloc/approve_users_bloc.dart';
import 'dart:html' as html;

import '../../../constants/colors.dart';

int kSuperAdminId = 0;

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
class _T {
  static const Color purple     = Color(0xFF6D28D9);
  static const Color purpleSoft = Color(0xFFEDE9FE);
  static const Color bg         = Color(0xFFF3F4F8);
  static const Color border     = Color(0xFFE5E7EB);
  static const Color textDark   = Color(0xFF111827);
  static const Color textMid    = Color(0xFF374151);
  static const Color textGrey   = Color(0xFF6B7280);
  static const Color textLight  = Color(0xFF9CA3AF);
  static const Color green      = Color(0xFF059669);
  static const Color greenSoft  = Color(0xFFD1FAE5);
  static const Color greenDeep  = Color(0xFF065F46);
  static const Color amber      = Color(0xFFD97706);
  static const Color amberSoft  = Color(0xFFFEF3C7);
  static const Color red        = Color(0xFFDC2626);
  static const Color redSoft    = Color(0xFFFEE2E2);
}

// ─────────────────────────────────────────────────────────────────────────────
// Column flex weights — tuned for readability
// ─────────────────────────────────────────────────────────────────────────────
const int _fNo      = 2;
const int _fName    = 14;
const int _fPhone   = 11;
const int _fRole    = 7;
const int _fStatus  = 9;
const int _fClients = 8;
const int _fAmount  = 11;
const int _fDate    = 7;
const int _fTime    = 6;
const int _fReason  = 14;
const int _fActions = 7;

// ─────────────────────────────────────────────────────────────────────────────
// Root widget
// ─────────────────────────────────────────────────────────────────────────────
class ApproveUsersTab extends StatefulWidget {
  final String? activePage;
  const ApproveUsersTab(this.activePage, {super.key});

  @override
  State<ApproveUsersTab> createState() => _ApproveUsersTabState();
}

class _ApproveUsersTabState extends State<ApproveUsersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _assignId();
    _tabController = TabController(length: 3, vsync: this);
    context.read<ApproveUsersBloc>().add(
      FetchPendingRequests(widget.activePage == 'admin' ? 'ADMIN' : 'CLIENT'),
    );
  }

  void _assignId() {
    kSuperAdminId =
        int.tryParse(html.window.sessionStorage['user_id'] ?? '') ?? 0;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Reject dialog ────────────────────────────────────────────────────────
  void _showRejectDialog(Map<String, dynamic> request) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 360,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFFECACA), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _T.redSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.block_rounded,
                          size: 18, color: _T.red),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reject Request',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7F1D1D),
                            ),
                          ),
                          Text(
                            request['fullName'] ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: _T.red),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: _T.textLight),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reason for rejection',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _T.textMid,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctl,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 13, color: _T.textDark),
                      decoration: InputDecoration(
                        hintText: 'Enter reason for rejection...',
                        hintStyle: const TextStyle(
                            fontSize: 12, color: _T.textLight),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _T.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _T.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _T.red, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogBtn(
                            label: 'Cancel',
                            bg: const Color(0xFFF3F4F6),
                            textColor: _T.textGrey,
                            onTap: () => Navigator.pop(ctx),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DialogBtn(
                            label: 'Reject',
                            bg: _T.red,
                            textColor: Colors.white,
                            onTap: () {
                              if (ctl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                    Text('Please enter a rejection reason'),
                                    backgroundColor: _T.red,
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(ctx);
                              context.read<ApproveUsersBloc>().add(
                                ReviewRequest(
                                  superAdminId: kSuperAdminId,
                                  requestId: request['requestId'] as int,
                                  status: 'REJECTED',
                                  reason: ctl.text.trim(),
                                ),
                              );
                            },
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

  Map<String, dynamic> _extractLists(ApproveUsersState state) {
    if (state is ApproveUsersLoaded ||
        state is ApproveUsersReviewing ||
        state is ApproveUsersReviewSuccess) {
      final s = state as dynamic;
      return {
        'pending': s.pending as List<Map<String, dynamic>>,
        'approved': s.approved as List<Map<String, dynamic>>,
        'rejected': s.rejected as List<Map<String, dynamic>>,
        'totalCount': s.totalCount as int,
        'pendingCount': s.pendingCount as int,
        'approvedCount': s.approvedCount as int,
        'rejectedCount': s.rejectedCount as int,
      };
    } else if (state is ApproveUsersError) {
      return {
        'pending': state.pending,
        'approved': state.approved,
        'rejected': state.rejected,
        'totalCount': 0,
        'pendingCount': 0,
        'approvedCount': 0,
        'rejectedCount': 0,
      };
    }
    return {
      'pending': <Map<String, dynamic>>[],
      'approved': <Map<String, dynamic>>[],
      'rejected': <Map<String, dynamic>>[],
      'totalCount': 0, 'pendingCount': 0,
      'approvedCount': 0, 'rejectedCount': 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ApproveUsersBloc, ApproveUsersState>(
      listener: (context, state) {
        if (state is ApproveUsersReviewSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: state.message.contains('Approved')
                ? _T.green : _T.red,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ));
        } else if (state is ApproveUsersError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: _T.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      builder: (context, state) {
        final d = _extractLists(state);
        final pending  = d['pending']  as List<Map<String, dynamic>>;
        final approved = d['approved'] as List<Map<String, dynamic>>;
        final rejected = d['rejected'] as List<Map<String, dynamic>>;
        final total    = d['totalCount']    as int;
        final pCount   = d['pendingCount']  as int;
        final aCount   = d['approvedCount'] as int;
        final rCount   = d['rejectedCount'] as int;

        return Container(
          color: _T.bg,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ──────────────────────────────────────────────
              _TopBar(
                totalCount: total,
                pendingCount: pCount,
                activePage: widget.activePage,
              ),
              SizedBox(height: 20),

              if (state is ApproveUsersLoading)
                Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: _T.purple),
                  ),
                )
              else ...[
                // ── Stat row ─────────────────────────────────────────
                _StatRow(
                  total: total,
                  approved: aCount,
                  rejected: rCount,
                  pending: pCount,
                ),
                const SizedBox(height: 20),

                // ── Tab bar ──────────────────────────────────────────
                _TabBar(
                  controller: _tabController,
                  pendingCount: pCount,
                  approvedCount: aCount,
                  rejectedCount: rCount,
                ),
                const SizedBox(height: 16),

                // ── Tables ───────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _UsersTable(
                        users: pending,
                        listType: 'pending',
                        isLoading: state is ApproveUsersReviewing,
                        onApprove: (u) => context.read<ApproveUsersBloc>().add(
                          ReviewRequest(
                            superAdminId: kSuperAdminId,
                            requestId: u['requestId'] as int,
                            status: 'APPROVED',
                            reason: 'Approved by super admin',
                          ),
                        ),
                        onReject: _showRejectDialog,
                      ),
                      _UsersTable(
                          users: approved,
                          listType: 'approved',
                          isLoading: false),
                      _UsersTable(
                          users: rejected,
                          listType: 'rejected',
                          isLoading: false),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final int totalCount;
  final int pendingCount;
  final String? activePage;
  const _TopBar(
      {required this.totalCount,
        required this.pendingCount,
        required this.activePage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Approve Users',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _T.textDark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$totalCount request${totalCount == 1 ? '' : 's'} found',
              style: const TextStyle(fontSize: 13, color: _T.textGrey),
            ),
          ],
        ),
        const Spacer(),
        // Refresh button
        Tooltip(
          message: 'Refresh',
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.read<ApproveUsersBloc>().add(
              FetchPendingRequests(
                  activePage == 'admin' ? 'ADMIN' : 'CLIENT'),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _T.border),
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: _T.purple),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Pending pill
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _T.amberSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFCD34D)),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: _T.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '$pendingCount Pending',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat row
// ─────────────────────────────────────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  final int total, approved, rejected, pending;
  const _StatRow(
      {required this.total,
        required this.approved,
        required this.rejected,
        required this.pending});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          label: 'Total Requests',
          value: '$total',
          color: _T.purple,
          bg: _T.purpleSoft,
          icon: Icons.people_alt_rounded,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Pending Review',
          value: '$pending',
          color: _T.amber,
          bg: _T.amberSoft,
          icon: Icons.hourglass_top_rounded,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Approved',
          value: '$approved',
          color: _T.green,
          bg: _T.greenSoft,
          icon: Icons.verified_rounded,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Rejected',
          value: '$rejected',
          color: _T.red,
          bg: _T.redSoft,
          icon: Icons.cancel_rounded,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color, bg;
  final IconData icon;
  const _StatCard(
      {required this.label,
        required this.value,
        required this.color,
        required this.bg,
        required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _T.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _T.textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab bar
// ─────────────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final TabController controller;
  final int pendingCount, approvedCount, rejectedCount;
  const _TabBar(
      {required this.controller,
        required this.pendingCount,
        required this.approvedCount,
        required this.rejectedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
          ),
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: _T.purple.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: _T.textGrey,
        labelStyle:
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        tabs: [
          _Tab(label: 'Pending', count: pendingCount,
              dotColor: _T.amber),
          _Tab(label: 'Approved', count: approvedCount,
              dotColor: _T.green),
          _Tab(label: 'Rejected', count: rejectedCount,
              dotColor: _T.red),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int count;
  final Color dotColor;
  const _Tab(
      {required this.label, required this.count, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Users table
// ─────────────────────────────────────────────────────────────────────────────
class _UsersTable extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final String listType;
  final bool isLoading;
  final void Function(Map<String, dynamic>)? onApprove;
  final void Function(Map<String, dynamic>)? onReject;

  const _UsersTable({
    required this.users,
    required this.listType,
    required this.isLoading,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          _TableHeader(listType: listType),
          if (users.isEmpty)
            Expanded(
              child: Center(
                child: Lottie.asset(
                  'assets/animations/No Data.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (_, i) => _TableRow(
                  index: i + 1,
                  user: users[i],
                  listType: listType,
                  isLoading: isLoading,
                  isLast: i == users.length - 1,
                  isEven: i.isEven,
                  onApprove:
                  onApprove != null ? () => onApprove!(users[i]) : null,
                  onReject:
                  onReject != null ? () => onReject!(users[i]) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Table header
// ─────────────────────────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  final String listType;
  const _TableHeader({required this.listType});

  Widget _h(String text, {bool center = false}) => Text(
    text,
    textAlign: center ? TextAlign.center : TextAlign.left,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: 0.6,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isPending = listType == 'pending';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: _fNo, child: _h('#')),
          Expanded(flex: _fName, child: _h('USER')),
          Expanded(
              flex: _fPhone,
              child: _h(isPending ? 'PHONE' : 'REVIEWED BY')),
          Expanded(flex: _fRole, child: _h('ROLE')),
          Expanded(flex: _fStatus, child: _h('STATUS')),
          Expanded(flex: _fClients, child: _h('CLIENTS')),
          Expanded(flex: _fAmount, child: _h('AMOUNT')),
          Expanded(flex: _fDate, child: _h('DATE')),
          Expanded(flex: _fTime, child: _h('TIME')),
          Expanded(flex: _fReason, child: _h('REASON')),
          if (isPending)
            Expanded(flex: _fActions, child: _h('ACTIONS', center: true)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Table row
// ─────────────────────────────────────────────────────────────────────────────
class _TableRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> user;
  final String listType;
  final bool isLoading, isLast, isEven;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _TableRow({
    required this.index,
    required this.user,
    required this.listType,
    required this.isLoading,
    required this.isLast,
    required this.isEven,
    this.onApprove,
    this.onReject,
  });

  bool get _isPending => listType == 'pending';

  // ── Formatters ──────────────────────────────────────────────────────────────
  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        '', 'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec',
      ];
      return '${months[dt.month]} ${dt.day}, ${dt.year}';
    } catch (_) { return raw; }
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'PM' : 'AM';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour12:$m $period';
    } catch (_) { return '—'; }
  }

  /// Indian comma formatting: 4321.2 → ₹4,321.20
  String _formatAmount(dynamic raw) {
    if (raw == null) return '—';
    try {
      final double v =
      raw is num ? raw.toDouble() : double.parse(raw.toString());
      final parts = v.toStringAsFixed(2).split('.');
      final dec = parts[1];
      final intStr = parts[0];
      final buf = StringBuffer();
      for (int i = 0; i < intStr.length; i++) {
        if (i != 0) {
          final pos = intStr.length - i;
          if (pos == 3 || (pos > 3 && (pos - 3) % 2 == 0)) buf.write(',');
        }
        buf.write(intStr[i]);
      }
      return '₹$buf.$dec';
    } catch (_) { return '₹${raw}'; }
  }

  // ── Status helpers ──────────────────────────────────────────────────────────
  String get _statusLabel {
    switch ((user['status'] ?? '').toUpperCase()) {
      case 'APPROVED': return 'Approved';
      case 'REJECTED': return 'Rejected';
      default:         return 'Pending';
    }
  }

  Color get _statusColor {
    switch ((user['status'] ?? '').toUpperCase()) {
      case 'APPROVED': return _T.green;
      case 'REJECTED': return _T.red;
      default:         return _T.amber;
    }
  }

  Color get _statusBg {
    switch ((user['status'] ?? '').toUpperCase()) {
      case 'APPROVED': return _T.greenSoft;
      case 'REJECTED': return _T.redSoft;
      default:         return _T.amberSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name         = (user['fullName']      as String?) ?? '—';
    final phone        = (user['phoneNumber']   as String?) ?? '—';
    final email        = (user['email']         as String?) ?? '';
    final role         = (user['requestedRole'] as String?) ?? '—';
    final createdAt    = (user['createdAt']     as String?) ?? '';
    final reviewedBy   = (user['reviewedByName'] as String?) ?? '—';
    final reviewedAt   = (user['reviewedAt']    as String?) ?? '';

    // ── KEY FIX: noOfClients and amount ────────────────────────────────────
    final rawClients = user['noOfClients'];
    final rawAmount  = user['amount'];
    final clientsDisplay = rawClients != null ? rawClients.toString() : '—';
    final amountDisplay  = _formatAmount(rawAmount);
    // ─────────────────────────────────────────────────────────────────────────

    final ts           = _isPending ? createdAt : reviewedAt;
    final dateStr      = _formatDate(ts);
    final timeStr      = _formatTime(ts);
    final secondaryCol = _isPending ? phone : reviewedBy;

    final reason       = ((user['reason'] as String?)?.trim()) ?? '';

    // Row background — alternating subtle stripe
    final rowBg = isEven ? Colors.white : const Color(0xFFFAFAFC);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: rowBg,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── # ─────────────────────────────────────────────────
              Expanded(
                flex: _fNo,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _T.textGrey,
                    ),
                  ),
                ),
              ),

              // ── User ──────────────────────────────────────────────
              Expanded(
                flex: _fName,
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _T.purple,
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _T.textLight,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Phone / Reviewed By ───────────────────────────────
              Expanded(
                flex: _fPhone,
                child: Text(
                  secondaryCol,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _T.textMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // ── Role ──────────────────────────────────────────────
              Expanded(
                flex: _fRole,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _T.purpleSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      role,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _T.purple,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Status ────────────────────────────────────────────
              Expanded(
                flex: _fStatus,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Clients ───────────────────────────────────────────
              Expanded(
                flex: _fClients,
                child: rawClients == null
                    ? const Text('—',
                    style: TextStyle(color: _T.textLight, fontSize: 13))
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _T.purpleSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        size: 14,
                        color: _T.purple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      clientsDisplay,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _T.textDark,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Amount ────────────────────────────────────────────
              Expanded(
                flex: _fAmount,
                child: rawAmount == null
                    ? const Text('—',
                    style: TextStyle(color: _T.textLight, fontSize: 13))
                    : Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF6EE7B7), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.currency_rupee_rounded,
                          size: 12, color: _T.green),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          amountDisplay.replaceFirst('₹', ''),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _T.greenDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Date ──────────────────────────────────────────────
              Expanded(
                flex: _fDate,
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _T.textMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // ── Time ──────────────────────────────────────────────
              Expanded(
                flex: _fTime,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 12, color: _T.textLight),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _T.textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Reason ────────────────────────────────────────────
              Expanded(
                flex: _fReason,
                child: reason.isEmpty
                    ? const Text('—',
                    style:
                    TextStyle(color: _T.textLight, fontSize: 13))
                    : Tooltip(
                  message: reason,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _T.border),
                    ),
                    child: Text(
                      reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _T.textMid,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Actions ───────────────────────────────────────────
              if (_isPending)
                Expanded(
                  flex: _fActions,
                  child: isLoading
                      ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _T.purple,
                      ),
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionBtn(
                        icon: Icons.close_rounded,
                        color: _T.red,
                        bg: _T.redSoft,
                        tooltip: 'Reject',
                        onTap: onReject,
                      ),
                      const SizedBox(width: 1),
                      _ActionBtn(
                        icon: Icons.check_rounded,
                        color: _T.green,
                        bg: _T.greenSoft,
                        tooltip: 'Approve',
                        onTap: onApprove,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final String tooltip;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

class _DialogBtn extends StatelessWidget {
  final String label;
  final Color bg, textColor;
  final VoidCallback onTap;

  const _DialogBtn({
    required this.label,
    required this.bg,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}