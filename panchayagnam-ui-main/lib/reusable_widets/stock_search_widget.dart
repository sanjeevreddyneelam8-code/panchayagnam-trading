import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/individual_bloc/individual_execution_bloc.dart';
import '../models/ScripInfo.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────
const _kAccent     = Color(0xFF6366F1);
const _kAccentSoft = Color(0xFFEEEDFF);
const _kBorder     = Color(0xFFE4E7EF);
const _kBgInput    = Colors.white;
const _kTextMain   = Color(0xFF1A1D27);
const _kTextSub    = Color(0xFF94A3B8);
const _kSurface    = Color(0xFFF8F9FB);

// ── Instrument type badge colours ──────────────────────────────────────────
const _kEqFg    = Color(0xFF166534);
const _kEqBg    = Color(0xFFDCFCE7);
const _kEqBd    = Color(0xFFBBF7D0);
const _kFutFg   = Color(0xFF1E40AF);
const _kFutBg   = Color(0xFFDBEAFE);
const _kFutBd   = Color(0xFFBFDBFE);
const _kOptFg   = Color(0xFF92400E);
const _kOptBg   = Color(0xFFFEF3C7);
const _kOptBd   = Color(0xFFFDE68A);
const _kOtherFg = Color(0xFF4B5563);
const _kOtherBg = Color(0xFFF3F4F6);
const _kOtherBd = Color(0xFFE5E7EB);

// ── Exchange brand colours ─────────────────────────────────────────────────
const _kNseFg  = Color(0xFF6366F1);
const _kNseBg  = Color(0xFFEEEDFF);
const _kBseFg  = Color(0xFF1D4ED8);
const _kBseBg  = Color(0xFFDBEAFE);
const _kNfoFg  = Color(0xFFC2410C);
const _kNfoBg  = Color(0xFFFFF7ED);
const _kNfoBd  = Color(0xFFFED7AA);

/// Which instrument-type filter is active in the dropdown header.
/// `null` means "All" (no filter).
enum _InstrFilter { all, eq, fut, opt }

class StockSearchWidget extends StatefulWidget {
  final ValueChanged<ScripInfo> onScripSelected;
  const StockSearchWidget({Key? key, required this.onScripSelected})
      : super(key: key);

  @override
  State<StockSearchWidget> createState() => _StockSearchWidgetState();
}

class _StockSearchWidgetState extends State<StockSearchWidget>
    with TickerProviderStateMixin {

  final TextEditingController _ctrl      = TextEditingController();
  final FocusNode             _focus     = FocusNode();
  final LayerLink             _layerLink = LayerLink();

  Timer?          _debounce;
  List<ScripInfo> _results      = [];
  bool            _loading      = false;
  bool            _isFocused    = false;
  _InstrFilter    _activeFilter = _InstrFilter.all;

  /// True while the pointer is inside the overlay dropdown.
  /// Used to suppress the focus-lost close when a filter chip is tapped.
  bool _pointerInsideOverlay = false;

  OverlayEntry? _overlayEntry;

  late AnimationController _focusCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _borderAnim;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();

    _focusCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _borderAnim =
        CurvedAnimation(parent: _focusCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _focus.addListener(_onFocusChanged);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _removeOverlay();
    _focus.removeListener(_onFocusChanged);
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    _focusCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _isFocused = _focus.hasFocus);
    if (_focus.hasFocus) {
      _focusCtrl.forward();
    } else {
      // If the pointer is still inside the overlay (e.g. tapping a filter chip),
      // re-request focus instead of closing so the overlay stays visible.
      if (_pointerInsideOverlay) {
        Future.microtask(() {
          if (mounted) _focus.requestFocus();
        });
        return;
      }
      _focusCtrl.reverse();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_pointerInsideOverlay) _removeOverlay();
      });
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────
  void _onChanged(String val) {
    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() {
        _results = [];
        _loading = false;
      });
      _removeOverlay();
      return;
    }
    _debounce = Timer(
        const Duration(milliseconds: 350), () => _doSearch(val.trim()));
  }

  void _doSearch(String query) {
    if (!mounted) return;
    setState(() => _loading = true);
    context.read<IndividualExecutionBloc>().add(
      SearchScripRequested(query: query.toUpperCase(), exchange: ''),
    );
  }

  void _onResultsReceived(List<ScripInfo> results) {
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
    results.isNotEmpty ? _refreshOverlay() : _removeOverlay();
  }

  void _select(ScripInfo s) {
    final display = (s.name.isNotEmpty ? s.name : s.tradingSymbol)
        .replaceAll('-EQ', '');
    _ctrl.text = '$display  ·  ${s.exchange}';
    setState(() {
      _results = [];
      _loading = false;
    });
    _removeOverlay();
    _focus.unfocus();
    widget.onScripSelected(s);
  }

  void _clear() {
    _ctrl.clear();
    setState(() {
      _results = [];
      _loading = false;
      _activeFilter = _InstrFilter.all;
    });
    _removeOverlay();
  }

  void _setFilter(_InstrFilter f) {
    setState(() => _activeFilter = f);
    _refreshOverlay();
    // Re-focus the text field so keyboard stays up and focus isn't lost
    _focus.requestFocus();
  }

  // ── Overlay ───────────────────────────────────────────────────────────────
  void _refreshOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) => _DropdownOverlay(
        layerLink:    _layerLink,
        results:      _results,
        activeFilter: _activeFilter,
        onSelect:     _select,
        onFilterChanged: (f) {
          _activeFilter = f;
          _overlayEntry?.markNeedsBuild();
          // Re-focus after filter tap so text field regains focus
          _focus.requestFocus();
        },
        onPointerEnter: () => _pointerInsideOverlay = true,
        onPointerExit:  () => _pointerInsideOverlay = false,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return BlocListener<IndividualExecutionBloc, IndividualExecutionState>(
      listener: (ctx, state) {
        if (state is ScripSearchSuccess) {
          _onResultsReceived(state.results);
        } else if (state is ScripSearchLoading) {
          if (mounted) setState(() => _loading = true);
        } else if (state is ScripSearchFailure) {
          if (mounted) setState(() {
            _results = [];
            _loading = false;
          });
          _removeOverlay();
        }
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: AnimatedBuilder(
          animation: _borderAnim,
          builder: (_, __) {
            final t = _borderAnim.value;
            return Container(
              height: 48,
              decoration: BoxDecoration(
                color: _kBgInput,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color.lerp(_kBorder, _kAccent, t)!,
                  width: 1.0 + (t * 0.8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.055),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  if (t > 0)
                    BoxShadow(
                      color: _kAccent.withOpacity(0.14 * t),
                      blurRadius: 16 * t,
                      spreadRadius: t * 1,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Search icon / loader ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(left: 14, right: 8),
                      child: _loading
                          ? Center(child: _PulsingLoader(pulse: _pulse))
                          : Center(
                        child: AnimatedBuilder(
                          animation: _borderAnim,
                          builder: (_, __) => Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: Color.lerp(
                                const Color(0xFFCBD5E1),
                                _kAccent,
                                _borderAnim.value),
                          ),
                        ),
                      ),
                    ),

                    // ── Text field ───────────────────────────────────
                    Expanded(
                      child: Center(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          onChanged: _onChanged,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: _kTextMain,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.15,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search  e.g. INFY, SBIN, NIFTY…',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFBCC8D8),
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),

                    // ── Clear button ─────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: _ctrl.text.isNotEmpty
                          ? InkWell(
                        key: const ValueKey('clear'),
                        onTap: _clear,
                        child: Padding(
                          padding:
                          const EdgeInsets.only(right: 12),
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEDF0F5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.close_rounded,
                                  size: 12,
                                  color: Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      )
                          : const SizedBox(
                          key: ValueKey('empty'), width: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Pulsing loader ────────────────────────────────────────────────────────────
class _PulsingLoader extends StatelessWidget {
  final Animation<double> pulse;
  const _PulsingLoader({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Opacity(
        opacity: pulse.value,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: _kAccent,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Overlay dropdown — filter chips + EQ / FUT / OPT section headers
// ─────────────────────────────────────────────────────────────────────────────
class _DropdownOverlay extends StatefulWidget {
  final LayerLink                     layerLink;
  final List<ScripInfo>               results;
  final _InstrFilter                  activeFilter;
  final ValueChanged<ScripInfo>       onSelect;
  final ValueChanged<_InstrFilter>    onFilterChanged;
  final VoidCallback                  onPointerEnter;
  final VoidCallback                  onPointerExit;

  const _DropdownOverlay({
    required this.layerLink,
    required this.results,
    required this.activeFilter,
    required this.onSelect,
    required this.onFilterChanged,
    required this.onPointerEnter,
    required this.onPointerExit,
  });

  @override
  State<_DropdownOverlay> createState() => _DropdownOverlayState();
}

class _DropdownOverlayState extends State<_DropdownOverlay>
    with SingleTickerProviderStateMixin {

  late AnimationController _enterCtrl;
  late Animation<double>   _slideAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _slideAnim = Tween<double>(begin: -8, end: 0).animate(
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _fadeAnim =
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── Filter the full results list ─────────────────────────────────────────
  List<ScripInfo> get _filtered {
    if (widget.activeFilter == _InstrFilter.all) return widget.results;
    return widget.results.where((s) {
      final t = s.instrumentType.toUpperCase();
      switch (widget.activeFilter) {
        case _InstrFilter.eq:
          return t == 'EQ' || t.isEmpty;
        case _InstrFilter.fut:
          return t.contains('FUT');
        case _InstrFilter.opt:
          return t.contains('OPT') || t == 'CE' || t == 'PE';
        default:
          return true;
      }
    }).toList();
  }

  // ── Group results: EQ → FUT → OPT → OTHER ────────────────────────────────
  List<Map<String, dynamic>> _buildSections(List<ScripInfo> items) {
    final eq    = <ScripInfo>[];
    final fut   = <ScripInfo>[];
    final opt   = <ScripInfo>[];
    final other = <ScripInfo>[];

    for (final s in items) {
      final t = s.instrumentType.toUpperCase();
      if (t.contains('FUT')) {
        fut.add(s);
      } else if (t.contains('OPT') || t == 'CE' || t == 'PE') {
        opt.add(s);
      } else if (t == 'EQ' || t.isEmpty) {
        eq.add(s);
      } else {
        other.add(s);
      }
    }

    return [
      if (eq.isNotEmpty)    {'label': 'EQUITY',  'items': eq},
      if (fut.isNotEmpty)   {'label': 'FUTURES', 'items': fut},
      if (opt.isNotEmpty)   {'label': 'OPTIONS', 'items': opt},
      if (other.isNotEmpty) {'label': 'OTHER',   'items': other},
    ];
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF6366F1), Color(0xFF0EA5E9), Color(0xFF10B981),
      Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6),
      Color(0xFF06B6D4), Color(0xFFEC4899),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  // ── How many results exist per type (for chip counts) ────────────────────
  int _countFor(_InstrFilter f) {
    if (f == _InstrFilter.all) return widget.results.length;
    return widget.results.where((s) {
      final t = s.instrumentType.toUpperCase();
      switch (f) {
        case _InstrFilter.eq:  return t == 'EQ' || t.isEmpty;
        case _InstrFilter.fut: return t.contains('FUT');
        case _InstrFilter.opt: return t.contains('OPT') || t == 'CE' || t == 'PE';
        default: return true;
      }
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) return const SizedBox.shrink();

    final filtered = _filtered;
    final sections = _buildSections(filtered);

    // Flat widget list
    final List<Widget> rows = [];
    for (final section in sections) {
      final label = section['label'] as String;
      final items = section['items'] as List<ScripInfo>;

      rows.add(_SectionHeader(label: label, count: items.length));
      for (int i = 0; i < items.length; i++) {
        final s    = items[i];
        final name = (s.name.isNotEmpty ? s.name : s.tradingSymbol)
            .replaceAll('-EQ', '');
        rows.add(_ResultTile(
          s: s,
          name: name,
          col: _avatarColor(name),
          onSelect: widget.onSelect,
        ));
        if (i < items.length - 1) {
          rows.add(const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 1, color: Color(0xFFF3F4F8)),
          ));
        }
      }
    }

    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: widget.layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 54),
        child: AnimatedBuilder(
          animation: _enterCtrl,
          builder: (_, child) => FadeTransition(
            opacity: _fadeAnim,
            child: Transform.translate(
              offset: Offset(0, _slideAnim.value),
              child: child,
            ),
          ),
          // MouseRegion wraps the entire dropdown so we know when the pointer
          // is inside — this prevents closing when tapping filter chips.
          child: MouseRegion(
            onEnter: (_) => widget.onPointerEnter(),
            onExit:  (_) => widget.onPointerExit(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 480,
                constraints: const BoxConstraints(maxHeight: 480),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFEBEDF3), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 32,
                      spreadRadius: -2,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: _kAccent.withOpacity(0.07),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ── Header bar: result count + filter chips ──────
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFBFBFD),
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFEEF0F5)),
                          ),
                        ),
                        child: Row(
                          children: [
                            // ● result count
                            Container(
                              width: 7, height: 7,
                              decoration: const BoxDecoration(
                                color: _kAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kTextSub,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // ── Filter chips ─────────────────────────
                            _FilterChip(
                              label: 'All',
                              count: _countFor(_InstrFilter.all),
                              active: widget.activeFilter == _InstrFilter.all,
                              activeFg: Colors.white,
                              activeBg: _kAccent,
                              inactiveFg: _kTextSub,
                              inactiveBg: const Color(0xFFF1F3F8),
                              onTap: () => widget.onFilterChanged(_InstrFilter.all),
                            ),
                            const SizedBox(width: 6),
                            _FilterChip(
                              label: 'EQ',
                              count: _countFor(_InstrFilter.eq),
                              active: widget.activeFilter == _InstrFilter.eq,
                              activeFg: Colors.white,
                              activeBg: _kEqFg,
                              inactiveFg: _kEqFg,
                              inactiveBg: _kEqBg,
                              borderColor: _kEqBd,
                              onTap: () => widget.onFilterChanged(_InstrFilter.eq),
                            ),
                            const SizedBox(width: 6),
                            _FilterChip(
                              label: 'FUT',
                              count: _countFor(_InstrFilter.fut),
                              active: widget.activeFilter == _InstrFilter.fut,
                              activeFg: Colors.white,
                              activeBg: _kFutFg,
                              inactiveFg: _kFutFg,
                              inactiveBg: _kFutBg,
                              borderColor: _kFutBd,
                              onTap: () => widget.onFilterChanged(_InstrFilter.fut),
                            ),
                            const SizedBox(width: 6),
                            _FilterChip(
                              label: 'OPT',
                              count: _countFor(_InstrFilter.opt),
                              active: widget.activeFilter == _InstrFilter.opt,
                              activeFg: Colors.white,
                              activeBg: _kOptFg,
                              inactiveFg: _kOptFg,
                              inactiveBg: _kOptBg,
                              borderColor: _kOptBd,
                              onTap: () => widget.onFilterChanged(_InstrFilter.opt),
                            ),

                            const Spacer(),
                            const Text(
                              'tap to select',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFCBD5E1)),
                            ),
                          ],
                        ),
                      ),

                      // ── Sectioned results ───────────────────────────
                      if (rows.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No results for this filter',
                              style: TextStyle(
                                fontSize: 13,
                                color: _kTextSub,
                              ),
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView(
                            padding:
                            const EdgeInsets.symmetric(vertical: 4),
                            shrinkWrap: true,
                            children: rows,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Clickable filter chip ─────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String  label;
  final int     count;
  final bool    active;
  final Color   activeFg, activeBg;
  final Color   inactiveFg, inactiveBg;
  final Color?  borderColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.activeFg,
    required this.activeBg,
    required this.inactiveFg,
    required this.inactiveBg,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? activeFg : inactiveFg;
    final bg = active ? activeBg : inactiveBg;
    final bd = active
        ? activeBg
        : (borderColor ?? inactiveBg);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: bd, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: fg,
                letterSpacing: 0.4,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? activeFg.withOpacity(0.20)
                      : fg.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Section header row ────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final int    count;
  const _SectionHeader({required this.label, required this.count});

  Color get _fg {
    switch (label) {
      case 'FUTURES': return _kFutFg;
      case 'OPTIONS': return _kOptFg;
      case 'EQUITY':  return _kEqFg;
      default:        return _kOtherFg;
    }
  }

  Color get _bg {
    switch (label) {
      case 'FUTURES': return _kFutBg;
      case 'OPTIONS': return _kOptBg;
      case 'EQUITY':  return _kEqBg;
      default:        return _kOtherBg;
    }
  }

  Color get _bd {
    switch (label) {
      case 'FUTURES': return _kFutBd;
      case 'OPTIONS': return _kOptBd;
      case 'EQUITY':  return _kEqBd;
      default:        return _kOtherBd;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 6),
      color: const Color(0xFFFAFAFC),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bd),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _fg,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count item${count == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 11,
              color: _kTextSub,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              height: 1,
              color: const Color(0xFFEEF0F5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual animated result tile ──────────────────────────────────────────
class _ResultTile extends StatefulWidget {
  final ScripInfo               s;
  final String                  name;
  final Color                   col;
  final ValueChanged<ScripInfo> onSelect;

  const _ResultTile({
    required this.s,
    required this.name,
    required this.col,
    required this.onSelect,
  });

  @override
  State<_ResultTile> createState() => _ResultTileState();
}

class _ResultTileState extends State<_ResultTile>
    with SingleTickerProviderStateMixin {

  late AnimationController _hoverCtrl;
  late Animation<double>   _hoverAnim;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 140));
    _hoverAnim =
        CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  _BadgeStyle get _instrumentBadge {
    switch (widget.s.typeLabel) {
      case 'FUT': return const _BadgeStyle(_kFutFg, _kFutBg, _kFutBd);
      case 'OPT': return const _BadgeStyle(_kOptFg, _kOptBg, _kOptBd);
      case 'EQ':  return const _BadgeStyle(_kEqFg,  _kEqBg,  _kEqBd);
      default:    return const _BadgeStyle(_kOtherFg, _kOtherBg, _kOtherBd);
    }
  }

  _BadgeStyle get _exchangeBadge {
    switch (widget.s.exchange.toUpperCase()) {
      case 'NFO': return const _BadgeStyle(_kNfoFg, _kNfoBg, _kNfoBd);
      case 'BSE': return const _BadgeStyle(_kBseFg, _kBseBg, _kBseBg);
      default:    return const _BadgeStyle(_kNseFg, _kAccentSoft, _kAccentSoft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ib = _instrumentBadge;
    final eb = _exchangeBadge;

    return MouseRegion(
      onEnter: (_) => _hoverCtrl.forward(),
      onExit:  (_) => _hoverCtrl.reverse(),
      child: InkWell(
        onTap: () => widget.onSelect(widget.s),
        child: AnimatedBuilder(
          animation: _hoverAnim,
          builder: (_, __) => Container(
            color: Color.lerp(
                Colors.transparent, _kAccentSoft, _hoverAnim.value),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(
              children: [

                // ── Avatar ────────────────────────────────────────
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: widget.col.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: widget.col.withOpacity(0.20), width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.name.isNotEmpty ? widget.name[0] : '?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: widget.col,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // ── Name + symbol + lot size ───────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _kTextMain,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.s.tradingSymbol,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _kTextSub,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.s.isDerivative &&
                              widget.s.lotSize > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: _kOptBg,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: _kOptBd),
                              ),
                              child: Text(
                                'Lot ${widget.s.lotSize}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _kOptFg,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Instrument type badge ──────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ib.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ib.bd),
                  ),
                  child: Text(
                    widget.s.typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ib.fg,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 5),

                // ── Exchange badge (NSE / BSE / NFO) ──────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: eb.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: eb.bd),
                  ),
                  child: Text(
                    widget.s.exchange,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: eb.fg,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // ── Arrow nudges on hover ──────────────────────────
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _hoverAnim,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(_hoverAnim.value * 3, 0),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: Color.lerp(
                          const Color(0xFFDDE1EA),
                          _kAccent,
                          _hoverAnim.value),
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

// ── Badge style helper ────────────────────────────────────────────────────────
class _BadgeStyle {
  final Color fg, bg, bd;
  const _BadgeStyle(this.fg, this.bg, this.bd);
}