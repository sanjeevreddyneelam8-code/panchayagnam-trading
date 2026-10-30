import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/add_demat_account/add_demat_bloc.dart';
import '../constants/colors.dart';
import '../service/service_class.dart';

enum AccountDialogAction { add, update }

// ── IP Validation State ────────────────────────────────────────────────────────
enum IpValidationStatus {
  idle,
  loading,
  valid,
  invalid,
  notFound,
  alreadyAssigned,
}

class AddChildAccountDialog extends StatefulWidget {
  Function callBack;
  final List<dynamic> nonAdminAccounts;
  final AccountDialogAction actionType;
  final Map<String, dynamic>? existingAccount;

  AddChildAccountDialog({
    super.key,
    required this.nonAdminAccounts,
    required this.callBack,
    this.actionType = AccountDialogAction.add,
    this.existingAccount,
  });

  @override
  State<AddChildAccountDialog> createState() => _AddChildAccountDialogState();
}

class _AddChildAccountDialogState extends State<AddChildAccountDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ── Common controllers ─────────────────────────────────────────────────────
  final _pseudoNameController = TextEditingController();
  final _loginIdController = TextEditingController();
  final _mpinController = TextEditingController();
  final _apiKeyController = TextEditingController();

  // ── Phone Number ───────────────────────────────────────────────────────────
  final _phoneNumberController = TextEditingController();

  // ── AngelOne-specific ──────────────────────────────────────────────────────
  final _totpKeyAngelController = TextEditingController();

  // ── Motilal-specific ───────────────────────────────────────────────────────
  final _totpKeyMotilalController = TextEditingController();
  final _apiSecretKeyController = TextEditingController();

  // ── Dhan-specific ─────────────────────────────────────────────────────────
  final _totpKeyDhanController = TextEditingController();

  // ── Profit Mart-specific ───────────────────────────────────────────────────
  final _totpKeyProfitMartController = TextEditingController();

  // ── Good Well-specific ────────────────────────────────────────────────────
  final _totpKeyGoodWellController = TextEditingController();

  // ── IP Address ─────────────────────────────────────────────────────────────
  final _ipController = TextEditingController();
  IpValidationStatus _ipStatus = IpValidationStatus.idle;
  String _ipStatusMessage = '';
  int? _validatedPort;

  // ── DOB — manual text input + picker ──────────────────────────────────────
  final _dobTextController = TextEditingController();
  DateTime? _selectedDob;
  bool _dobError = false;
  String _dobErrMsg = 'Please enter or select Date of Birth';

  // ── Visibility toggles ─────────────────────────────────────────────────────
  bool _showMpin = false;
  bool _showTotpAngel = false;
  bool _showApiKey = false;
  bool _showTotpMotilal = false;
  bool _showApiSecretKey = false;
  bool _showTotpDhan = false;
  bool _showTotpProfitMart = false;
  bool _showApiKeyProfitMart = false;
  bool _showTotpGoodWell = false;
  bool _showApiKeyGoodWell = false;

  bool _useLoginAsNickname = false;
  String? _selectedBroker;

  // ── Own Account ────────────────────────────────────────────────────────────
  bool? _ownAccount;
  bool _ownAccountError = false;

  int? _recordId;
  bool _showReviewScreen = false;

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool get _isUpdate => widget.actionType == AccountDialogAction.update;
  bool get _isMotilal => _selectedBroker == 'Motilal Oswal';
  bool get _isDhan => _selectedBroker == 'Dhan';
  bool get _isProfitMart => _selectedBroker == 'Profit Mart';
  bool get _isGoodWell => _selectedBroker == 'Good Well';
  bool get _isUpstox => _selectedBroker == 'Upstox';
  bool get _isGroww => _selectedBroker == 'Groww';
  bool get _isZerodha => _selectedBroker == 'Zerodha';
  bool get _isUnsupportedBroker => _isGroww;

  // ── IP validation ──────────────────────────────────────────────────────────
  String _brokerApiKey(String? broker) {
    if (broker == 'Angel One') return 'ANGELONE';
    if (broker == 'Motilal Oswal') return 'MOTILAL';
    if (broker == 'Dhan') return 'DHAN';
    if (broker == 'Profit Mart') return 'PROFITMART';
    if (broker == 'Upstox') return 'UPSTOX';
    if (broker == 'Good Well' || broker == 'Goodwill') return 'GOODWILL';
    if (broker == 'Zerodha') return 'ZERODHA';
    if (broker == 'Groww') return 'GROWW';
    return '';
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
    if (_selectedBroker == null) {
      setState(() {
        _ipStatus = IpValidationStatus.invalid;
        _ipStatusMessage = 'Please select a broker first';
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
        brokerType: _brokerApiKey(_selectedBroker),
      );

      if (result['status'] == "SUCCESS") {
        // Parse the nested data string
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

        // Try to parse inner JSON message for ALREADY_ASSIGNED case
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
    } catch (e) {
      setState(() {
        _ipStatus = IpValidationStatus.invalid;
        _ipStatusMessage = 'Validation failed. Please try again.';
        _validatedPort = null;
      });
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    if (_isUpdate && widget.existingAccount != null) {
      _prefillFromExisting(widget.existingAccount!);
    }
  }

  void _prefillFromExisting(Map<String, dynamic> data) {
    _recordId = data['id'];

    final brokerRaw = (data['broker'] ?? '').toString().toUpperCase();
    if (brokerRaw == 'ANGELONE') {
      _selectedBroker = 'Angel One';
    } else if (brokerRaw == 'MOTILAL') {
      _selectedBroker = 'Motilal Oswal';
    } else if (brokerRaw == 'DHAN') {
      _selectedBroker = 'Dhan';
    } else if (brokerRaw == 'PROFITMART') {
      _selectedBroker = 'Profit Mart';
    } else if (brokerRaw == 'GOODWILL' || brokerRaw == 'GOODWELL' || brokerRaw == 'GOOD WELL') {
      _selectedBroker = 'Good Well';
    } else if (brokerRaw == 'ZERODHA') {
      _selectedBroker = 'Zerodha';
    } else if (brokerRaw == 'UPSTOX') {
      _selectedBroker = 'Upstox';
    } else if (brokerRaw == 'GROWW') {
      _selectedBroker = 'Groww';
    }

    _loginIdController.text = data['clientId'] ?? '';
    _pseudoNameController.text = data['nickName'] ?? '';
    _mpinController.text = data['mpin'] ?? '';
    _apiKeyController.text = data['apiKey'] ?? '';
    _dobTextController.text = data['dob'] ?? '';

    // Pre-fill phone number
    _phoneNumberController.text = data['mobileNumber'] ?? '';
    print("test ${_phoneNumberController.text}");

    _totpKeyAngelController.text =
        data['totpKey'] ?? data['totpReferenceKey'] ?? '';
    _totpKeyMotilalController.text =
        data['totpKey'] ?? data['totpReferenceKey'] ?? '';
    _totpKeyDhanController.text =
        data['totpKey'] ?? data['totpReferenceKey'] ?? '';
    _totpKeyProfitMartController.text =
        data['totpKey'] ?? data['totpReferenceKey'] ?? '';
    _totpKeyGoodWellController.text =
        data['totpKey'] ?? data['totpReferenceKey'] ?? '';
    _apiSecretKeyController.text = data['apiSecretKey'] ?? '';

    // Pre-fill IP if present
    _ipController.text = data['ip'] ?? '';
    if (_ipController.text.isNotEmpty) {
      _ipStatus = IpValidationStatus.valid;
      _ipStatusMessage = 'Previously validated IP address';
      _validatedPort = data['portNo'] as int?;
    }

    if (data['ownAccount'] != null) {
      _ownAccount = data['ownAccount'] as bool;
    }

    final dobStr = data['dob'] as String?;
    if (dobStr != null && dobStr.isNotEmpty) {
      final parts = dobStr.split('-');
      if (parts.length == 3) {
        _selectedDob = DateTime(
          int.tryParse(parts[0]) ?? 1990,
          int.tryParse(parts[1]) ?? 1,
          int.tryParse(parts[2]) ?? 1,
        );
        _dobTextController.text = _formatDob(_selectedDob!);
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _pseudoNameController.dispose();
    _loginIdController.dispose();
    _mpinController.dispose();
    _apiKeyController.dispose();
    _totpKeyAngelController.dispose();
    _totpKeyMotilalController.dispose();
    _apiSecretKeyController.dispose();
    _totpKeyDhanController.dispose();
    _totpKeyProfitMartController.dispose();
    _totpKeyGoodWellController.dispose();
    _dobTextController.dispose();
    _ipController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _onBrokerChanged(String? value) {
    setState(() {
      _selectedBroker = value;
      _loginIdController.clear();
      _phoneNumberController.clear();
      _mpinController.clear();
      _apiKeyController.clear();
      _totpKeyAngelController.clear();
      _totpKeyMotilalController.clear();
      _totpKeyDhanController.clear();
      _totpKeyProfitMartController.clear();
      _totpKeyGoodWellController.clear();
      _apiSecretKeyController.clear();
      _dobTextController.clear();
      _ipController.clear();
      _selectedDob = null;
      _dobError = false;
      _dobErrMsg = 'Please enter or select Date of Birth';
      _pseudoNameController.clear();
      _useLoginAsNickname = false;
      _ownAccount = null;
      _ownAccountError = false;
      _ipStatus = IpValidationStatus.idle;
      _ipStatusMessage = '';
      _validatedPort = null;
      _showMpin = _showTotpAngel = _showApiKey = false;
      _showTotpMotilal = _showApiSecretKey = _showTotpDhan = false;
      _showTotpProfitMart = _showApiKeyProfitMart = false;
      _showTotpGoodWell = _showApiKeyGoodWell = false;
    });
  }

  String _formatDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _dobForApi(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  DateTime? _parseDobText(String text) {
    final trimmed = text.trim();
    if (trimmed.length != 10) return null;
    final parts = trimmed.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (year < 1900 || year > DateTime.now().year - 18) return null;
    try {
      final dt = DateTime(year, month, day);
      if (dt.day != day || dt.month != month) return null;
      return dt;
    } catch (_) {
      return null;
    }
  }

  void _onDobTextChanged(String value) {
    final parsed = _parseDobText(value);
    setState(() {
      _selectedDob = parsed;
      if (parsed != null) _dobError = false;
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Select Date of Birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primaryBlue,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: const Color(0xFF111827),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobTextController.text = _formatDob(picked);
        _dobError = false;
      });
    }
  }

  bool _validateDob() {
    if (!_isMotilal) return true;
    final text = _dobTextController.text.trim();
    if (text.isEmpty) {
      _dobError = true;
      _dobErrMsg = 'Please enter or select Date of Birth';
      return false;
    }
    final parsed = _parseDobText(text);
    if (parsed == null) {
      _dobError = true;
      _dobErrMsg = 'Invalid date. Use dd/MM/yyyy (must be 18+ years ago)';
      return false;
    }
    _selectedDob = parsed;
    _dobError = false;
    return true;
  }

  bool _validateIpField() {
    if (_ipController.text.trim().isEmpty) {
      setState(() {
        _ipStatus = IpValidationStatus.invalid;
        _ipStatusMessage = 'Please enter an IP address and validate';
      });
      return false;
    }
    if (_ipStatus != IpValidationStatus.valid) {
      setState(() {
        if (_ipStatus == IpValidationStatus.idle) {
          _ipStatusMessage = 'Please click Validate to check the IP address';
          _ipStatus = IpValidationStatus.invalid;
        }
      });
      return false;
    }
    return true;
  }

  void _showReviewDetails() {
    final dobOk = _validateDob();
    final ipOk = _validateIpField();

    if (!dobOk || !ipOk) {
      setState(() {});
      _formKey.currentState?.validate();
      return;
    }
    if (_ownAccount == null) {
      setState(() => _ownAccountError = true);
      _formKey.currentState?.validate();
      return;
    }
    if (_formKey.currentState!.validate()) {
      setState(() {
        _showReviewScreen = true;
        _dobError = false;
        _ownAccountError = false;
      });
    }
  }

  // ── Submit methods ─────────────────────────────────────────────────────────
  void _submitAngelOne(BuildContext context) {
    context.read<AddDematBloc>().add(
      AddDematAccountEvent(
        id: _isUpdate ? _recordId : null,
        clientId: _loginIdController.text.trim(),
        broker: 'ANGELONE',
        mobileNumber: _phoneNumberController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        mpin: _mpinController.text.trim(),
        password: '',
        totpReferenceKey: _totpKeyAngelController.text.trim(),
        dob: null,
        isAdmin: false,
        childIds: [],
        nickName: _pseudoNameController.text.trim(),
        actionType: _isUpdate ? 'UPDATE' : 'ADD',
        isOwn: _ownAccount == true,
        apiSecretKey: null,
        vendorInfo: null,
        ip: _ipController.text.trim(),
      ),
    );
  }

  void _submitMotilal(BuildContext context) {
    final clientId = _loginIdController.text.trim();
    context.read<AddDematBloc>().add(
      AddDematAccountEvent(
        id: _isUpdate ? _recordId : null,
        clientId: clientId,
        broker: 'MOTILAL',
        mobileNumber: _phoneNumberController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        mpin: _mpinController.text.trim(),
        password: '',
        totpReferenceKey: _totpKeyMotilalController.text.trim(),
        dob: _selectedDob != null ? _dobForApi(_selectedDob!) : null,
        isAdmin: false,
        childIds: [],
        nickName: _pseudoNameController.text.trim(),
        actionType: _isUpdate ? 'UPDATE' : 'ADD',
        isOwn: _ownAccount == true,
        apiSecretKey: _apiSecretKeyController.text.trim(),
        vendorInfo: clientId,
        ip: _ipController.text.trim(),
      ),
    );
  }

  void _submitDhan(BuildContext context) {
    context.read<AddDematBloc>().add(
      AddDematAccountEvent(
        id: _isUpdate ? _recordId : null,
        clientId: _loginIdController.text.trim(),
        broker: 'DHAN',
        mobileNumber: _phoneNumberController.text.trim(),
        apiKey: '',
        mpin: _mpinController.text.trim(),
        password: '',
        totpReferenceKey: _totpKeyDhanController.text.trim(),
        dob: null,
        isAdmin: false,
        childIds: [],
        nickName: _pseudoNameController.text.trim(),
        actionType: _isUpdate ? 'UPDATE' : 'ADD',
        isOwn: _ownAccount == true,
        apiSecretKey: null,
        vendorInfo: null,
        ip: _ipController.text.trim(),
      ),
    );
  }

  void _submitProfitMart(BuildContext context) {
    context.read<AddDematBloc>().add(
      AddDematAccountEvent(
        id: _isUpdate ? _recordId : null,
        clientId: _loginIdController.text.trim(),
        broker: 'PROFITMART',
        mobileNumber: _phoneNumberController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        mpin: '',
        password: '',
        totpReferenceKey: _totpKeyProfitMartController.text.trim(),
        dob: null,
        isAdmin: false,
        childIds: [],
        nickName: _pseudoNameController.text.trim(),
        actionType: _isUpdate ? 'UPDATE' : 'ADD',
        isOwn: _ownAccount == true,
        apiSecretKey: null,
        vendorInfo: null,
        ip: _ipController.text.trim(),
      ),
    );
  }

  void _submitGoodWell(BuildContext context) {
    context.read<AddDematBloc>().add(
      AddDematAccountEvent(
        id: _isUpdate ? _recordId : null,
        clientId: _loginIdController.text.trim(),
        broker: 'GOODWILL',
        mobileNumber: _phoneNumberController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        mpin: _mpinController.text.trim(),
        password: _mpinController.text.trim(),
        totpReferenceKey: _totpKeyGoodWellController.text.trim(),
        dob: null,
        isAdmin: false,
        childIds: [],
        nickName: _pseudoNameController.text.trim(),
        actionType: _isUpdate ? 'UPDATE' : 'ADD',
        isOwn: _ownAccount == true,
        apiSecretKey: _apiSecretKeyController.text.trim(),
        vendorInfo: null,
        ip: _ipController.text.trim(),
      ),
    );
  }

  void _submitZerodha(BuildContext context) {
    context.read<AddDematBloc>().add(
      AddDematAccountEvent(
        id: _isUpdate ? _recordId : null,
        clientId: _loginIdController.text.trim(),
        broker: 'ZERODHA',
        mobileNumber: _phoneNumberController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        mpin: '',
        password: '',
        totpReferenceKey: '',
        dob: null,
        isAdmin: false,
        childIds: [],
        nickName: _pseudoNameController.text.trim(),
        actionType: _isUpdate ? 'UPDATE' : 'ADD',
        isOwn: _ownAccount == true,
        apiSecretKey: _apiSecretKeyController.text.trim(),
        vendorInfo: null,
        ip: _ipController.text.trim(),
      ),
    );
  }

  void _submitUpstox(BuildContext context) {
    context.read<AddDematBloc>().add(
      AddDematAccountEvent(
        id: _isUpdate ? _recordId : null,
        clientId: _loginIdController.text.trim(),
        broker: 'UPSTOX',
        mobileNumber: _phoneNumberController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        mpin: '',
        password: '',
        totpReferenceKey: '',
        dob: null,
        isAdmin: false,
        childIds: [],
        nickName: _pseudoNameController.text.trim(),
        actionType: _isUpdate ? 'UPDATE' : 'ADD',
        isOwn: _ownAccount == true,
        apiSecretKey: _apiSecretKeyController.text.trim(),
        vendorInfo: null,
        ip: _ipController.text.trim(),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddDematBloc(),
      child: BlocListener<AddDematBloc, AddDematAccountState>(
        listener: (context, state) {
          if (state is AddDematAccountSuccess) {
            Navigator.pop(context);
            widget.callBack();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isUpdate
                      ? 'Account Updated Successfully'
                      : 'Client Added Successfully',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is AddDematAccountFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            child: Container(
              width: 700,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.92,
              ),
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
                    // ── Coloured top bar ──────────────────────────────────
                    _buildDialogHeader(),
                    // ── Scrollable body ───────────────────────────────────
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                        child: Form(
                          key: _formKey,
                          child: _showReviewScreen
                              ? _buildReviewScreen(context)
                              : _buildFormScreen(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Coloured header banner ─────────────────────────────────────────────────
  Widget _buildDialogHeader() {
    final isReview = _showReviewScreen;
    final Color gradStart = _isUpdate
        ? const Color(0xFF1D4ED8)
        : const Color(0xFF0F766E);
    final Color gradEnd = _isUpdate
        ? const Color(0xFF3B82F6)
        : const Color(0xFF14B8A6);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isReview
              ? [const Color(0xFF1E293B), const Color(0xFF334155)]
              : [gradStart, gradEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isReview
                  ? Icons.fact_check_outlined
                  : _isUpdate
                  ? Icons.edit_outlined
                  : Icons.person_add_outlined,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReview
                      ? (_isUpdate
                      ? 'Review Changes'
                      : 'Review Account Details')
                      : (_isUpdate ? 'Edit Account' : 'Add New Account'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  isReview
                      ? 'Please verify the details before confirming'
                      : _isUpdate
                      ? 'Update the details below'
                      : 'Link a new trading account to your profile',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.75),
                  ),
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
              child: const Icon(Icons.close, size: 17, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormScreen(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Stock Broker'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedBroker,
          validator: (v) => v == null ? 'Please select a broker' : null,
          decoration: _inputDecoration('Select Stock Broker'),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(8),
          onChanged: _isUpdate ? null : _onBrokerChanged,
          items: const [
            DropdownMenuItem(value: 'Angel One', child: Text('Angel One')),
            DropdownMenuItem(
              value: 'Motilal Oswal',
              child: Text('Motilal Oswal'),
            ),
            DropdownMenuItem(value: 'Dhan', child: Text('Dhan')),
            DropdownMenuItem(value: 'Profit Mart', child: Text('Profit Mart')),
            DropdownMenuItem(value: 'Good Well', child: Text('Goodwill')),
            DropdownMenuItem(value: 'Zerodha', child: Text('Zerodha')),
            DropdownMenuItem(value: 'Upstox', child: Text('Upstox')),
            DropdownMenuItem(value: 'Groww', child: Text('Groww (No Trading API)')),
          ],
        ),

        if (_selectedBroker != null && !_isUnsupportedBroker) ...[
          const SizedBox(height: 16),
          _sectionLabel('Trading Platform'),
          const SizedBox(height: 8),
          _readOnlyField(
            _selectedBroker == 'Angel One'
                ? 'SMART_API'
                : _selectedBroker == 'Motilal Oswal'
                ? 'MOTILAL_API'
                : _selectedBroker == 'Dhan'
                ? 'DHAN_API'
                : _selectedBroker == 'Profit Mart'
                ? 'PROFITMART_API'
                : _selectedBroker == 'Good Well'
                ? 'GOODWILL_API'
                : _selectedBroker == 'Zerodha'
                ? 'KITE_CONNECT_API'
                : _selectedBroker == 'Upstox'
                ? 'UPSTOX_V2_API'
                : 'GROWW_PLATFORM',
          ),
          const SizedBox(height: 16),
        ],

        if (_isUnsupportedBroker) ..._buildUnsupportedBrokerBanner(),

        if (_selectedBroker == 'Angel One') ..._buildAngelOneFields(),
        if (_selectedBroker == 'Motilal Oswal') ..._buildMotilalFields(),
        if (_selectedBroker == 'Dhan') ..._buildDhanFields(),
        if (_selectedBroker == 'Profit Mart') ..._buildProfitMartFields(),
        if (_selectedBroker == 'Good Well') ..._buildGoodWellFields(),
        if (_selectedBroker == 'Zerodha') ..._buildZerodhaFields(),
        if (_selectedBroker == 'Upstox') ..._buildUpstoxFields(),

        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  foregroundColor: const Color(0xFF374151),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUnsupportedBroker ? null : _showReviewDetails,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(
                  _isUpdate ? 'Review Changes' : 'Review Details',
                  style: const TextStyle(fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isUnsupportedBroker ? const Color(0xFF9CA3AF) : AppColors.primaryBlue,
                  disabledBackgroundColor: const Color(0xFF9CA3AF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Unsupported / Coming Soon Broker Banner ───────────────────────────────
  List<Widget> _buildUnsupportedBrokerBanner() {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 8, bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 22),
                SizedBox(width: 8),
                Text(
                  'Groww — No Official Trading API',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF92400E)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Groww does not provide a public trading API for retail algorithmic trading. Web scraping or unofficial login attempts violate SEBI regulations and broker terms of service.',
              style: TextStyle(fontSize: 13, color: Color(0xFF78350F)),
            ),
            const SizedBox(height: 8),
            const Text(
              'To connect an account and place trades, please select one of the 7 supported brokers: Angel One, Motilal Oswal, Dhan, Profit Mart, Goodwill, Zerodha, or Upstox.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
            ),
          ],
        ),
      ),
    ];
  }

  // ── Phone Number Field ─────────────────────────────────────────────────────
  List<Widget> _buildPhoneNumberField() {
    return [
      _sectionLabel('Phone Number'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _phoneNumberController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        validator: (v) {
          if (v == null || v.trim().isEmpty) {
            return 'Please enter a phone number';
          }
          if (v.trim().length != 10) {
            return 'Phone number must be 10 digits';
          }
          return null;
        },
        decoration: _inputDecorationWithSuffix(
          'Enter 10-digit mobile number',
          const Icon(Icons.phone_outlined, color: Color(0xFF9CA3AF), size: 18),
        ),
      ),
    ];
  }

  // ── IP Address Field ───────────────────────────────────────────────────────
  List<Widget> _buildIpAddressField() {
    final bool isValid = _ipStatus == IpValidationStatus.valid;
    final bool isLoading = _ipStatus == IpValidationStatus.loading;
    final bool isError =
        _ipStatus == IpValidationStatus.invalid ||
            _ipStatus == IpValidationStatus.notFound ||
            _ipStatus == IpValidationStatus.alreadyAssigned;

    Color borderColor = const Color(0xFFD1D5DB);
    if (isValid) borderColor = const Color(0xFF059669);
    if (isError) borderColor = const Color(0xFFDC2626);

    return [
      Row(
        children: [
          _sectionLabel('IP Address'),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      ),
      const SizedBox(height: 4),
      const Text(
        'Enter the server IP address associated with this account',
        style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IP input
          Expanded(
            child: TextFormField(
              controller: _ipController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
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
                  horizontal: 14,
                  vertical: 14,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
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
                  minWidth: 0,
                  minHeight: 0,
                ),
                suffixIcon: isValid
                    ? const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Color(0xFF059669),
                  ),
                )
                    : isError
                    ? const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: Color(0xFFDC2626),
                  ),
                )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
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
          // ── Validate button ───────────────────────────────────────────
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: (isLoading || isValid) ? null : _validateIp,
              style: ElevatedButton.styleFrom(
                backgroundColor: isValid
                    ? const Color(0xFF059669)
                    : AppColors.primaryBlue,
                disabledBackgroundColor: isValid
                    ? const Color(0xFF059669).withOpacity(0.7)
                    : AppColors.primaryBlue.withOpacity(0.5),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      // Status banner
      _buildIpStatusBanner(),
    ];
  }

  Widget _buildIpStatusBanner() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (isValid && _validatedPort != null) ...[const SizedBox(height: 6)],
        ],
      ),
    );
  }

  // ── AngelOne fields ────────────────────────────────────────────────────────
  List<Widget> _buildAngelOneFields() {
    return [
      _sectionLabel('Trading Platform Login ID'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _loginIdController,
        readOnly: _isUpdate,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter Login ID' : null,
        decoration: _inputDecorationWithSuffix(
          'Trading Platform Login ID',
          const Icon(Icons.badge_outlined, color: Color(0xFF9CA3AF), size: 18),
        ),
        onChanged: (v) {
          if (_useLoginAsNickname) {
            setState(() => _pseudoNameController.text = v);
          }
        },
      ),
      const SizedBox(height: 16),
      ..._buildPhoneNumberField(),
      const SizedBox(height: 16),
      _sectionLabel('Enter your MPIN'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _mpinController,
        obscureText: !_showMpin,
        keyboardType: TextInputType.number,
        validator: (v) => v == null || v.isEmpty ? 'Please enter MPIN' : null,
        decoration: _inputDecorationWithSuffix(
          'MPIN',
          _eyeToggle(_showMpin, () => setState(() => _showMpin = !_showMpin)),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('TOTP Key'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _totpKeyAngelController,
        obscureText: !_showTotpAngel,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter TOTP Key' : null,
        decoration: _inputDecorationWithSuffix(
          'TOTP Key',
          _eyeToggle(
            _showTotpAngel,
                () => setState(() => _showTotpAngel = !_showTotpAngel),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('API Key'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _apiKeyController,
        obscureText: !_showApiKey,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter API Key' : null,
        decoration: _inputDecorationWithSuffix(
          'Trading Platform API Key',
          _eyeToggle(
            _showApiKey,
                () => setState(() => _showApiKey = !_showApiKey),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (!_isUpdate) ..._buildIpAddressField(),
      if (!_isUpdate) const SizedBox(height: 16),
      ..._buildOwnAccountField(),
      const SizedBox(height: 16),
      ..._buildPseudoNameFields(),
    ];
  }

  // ── Motilal fields ─────────────────────────────────────────────────────────
  List<Widget> _buildMotilalFields() {
    return [
      _sectionLabel('Trading Platform Login ID'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _loginIdController,
        readOnly: _isUpdate,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter Login ID' : null,
        decoration: _inputDecorationWithSuffix(
          'Trading Platform Login ID',
          const Icon(Icons.badge_outlined, color: Color(0xFF9CA3AF), size: 18),
        ),
        onChanged: (v) {
          if (_useLoginAsNickname) {
            setState(() => _pseudoNameController.text = v);
          }
        },
      ),
      const SizedBox(height: 16),
      ..._buildPhoneNumberField(),
      const SizedBox(height: 16),
      _sectionLabel('Password'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _mpinController,
        obscureText: !_showMpin,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter Password' : null,
        decoration: _inputDecorationWithSuffix(
          'Trading Platform Password',
          _eyeToggle(_showMpin, () => setState(() => _showMpin = !_showMpin)),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('TOTP Key'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _totpKeyMotilalController,
        obscureText: !_showTotpMotilal,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter TOTP Key' : null,
        decoration: _inputDecorationWithSuffix(
          'TOTP Key',
          _eyeToggle(
            _showTotpMotilal,
                () => setState(() => _showTotpMotilal = !_showTotpMotilal),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('API Key'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _apiKeyController,
        obscureText: !_showApiKey,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter API Key' : null,
        decoration: _inputDecorationWithSuffix(
          'API Key',
          _eyeToggle(
            _showApiKey,
                () => setState(() => _showApiKey = !_showApiKey),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('API Secret Key'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _apiSecretKeyController,
        obscureText: !_showApiSecretKey,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter API Secret Key' : null,
        decoration: _inputDecorationWithSuffix(
          'e.g. d7c64c9e-cef3-4eae-a382-82d9fa64efc0',
          _eyeToggle(
            _showApiSecretKey,
                () => setState(() => _showApiSecretKey = !_showApiSecretKey),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('Date of Birth (2FA)'),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _dobTextController,
              keyboardType: TextInputType.number,
              inputFormatters: [_DobInputFormatter()],
              onChanged: _onDobTextChanged,
              validator: (_) {
                if (!_dobError) return null;
                return _dobErrMsg;
              },
              style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
              decoration: InputDecoration(
                hintText: 'dd/MM/yyyy',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _dobError
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFD1D5DB),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _dobError
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFD1D5DB),
                    width: _dobError ? 1.5 : 1,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFDC2626),
                    width: 1.5,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFDC2626),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _pickDob,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: _dobError
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFD1D5DB),
                  width: _dobError ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                size: 20,
                color: _dobError
                    ? const Color(0xFFDC2626)
                    : AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ),
      if (_dobError) ...[
        const SizedBox(height: 6),
        Text(
          _dobErrMsg,
          style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
        ),
      ] else ...[
        const SizedBox(height: 4),
        const Text(
          'Type manually or tap 📅 to pick from calendar',
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      ],
      const SizedBox(height: 16),
      if (!_isUpdate) ..._buildIpAddressField(),
      if (!_isUpdate) const SizedBox(height: 16),
      ..._buildOwnAccountField(),
      const SizedBox(height: 16),
      ..._buildPseudoNameFields(),
    ];
  }

  // ── Dhan fields ────────────────────────────────────────────────────────────
  List<Widget> _buildDhanFields() {
    return [
      _sectionLabel('Client ID'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _loginIdController,
        readOnly: _isUpdate,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter Client ID' : null,
        decoration: _inputDecorationWithSuffix(
          'Dhan Client ID',
          const Icon(Icons.badge_outlined, color: Color(0xFF9CA3AF), size: 18),
        ),
        onChanged: (v) {
          if (_useLoginAsNickname) {
            setState(() => _pseudoNameController.text = v);
          }
        },
      ),
      const SizedBox(height: 16),
      ..._buildPhoneNumberField(),
      const SizedBox(height: 16),
      _sectionLabel('MPIN'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _mpinController,
        obscureText: !_showMpin,
        keyboardType: TextInputType.number,
        validator: (v) => v == null || v.isEmpty ? 'Please enter MPIN' : null,
        decoration: _inputDecorationWithSuffix(
          'MPIN',
          _eyeToggle(_showMpin, () => setState(() => _showMpin = !_showMpin)),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('TOTP Key'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _totpKeyDhanController,
        obscureText: !_showTotpDhan,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter TOTP Key' : null,
        decoration: _inputDecorationWithSuffix(
          'TOTP Key',
          _eyeToggle(
            _showTotpDhan,
                () => setState(() => _showTotpDhan = !_showTotpDhan),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (!_isUpdate) ..._buildIpAddressField(),
      if (!_isUpdate) const SizedBox(height: 16),
      ..._buildOwnAccountField(),
      const SizedBox(height: 16),
      ..._buildPseudoNameFields(),
    ];
  }

  // ── Profit Mart fields ─────────────────────────────────────────────────────
  // Same as Angel One but WITHOUT MPIN field
  List<Widget> _buildProfitMartFields() {
    return [
      _sectionLabel('Trading Platform Login ID'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _loginIdController,
        readOnly: _isUpdate,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter Login ID' : null,
        decoration: _inputDecorationWithSuffix(
          'Trading Platform Login ID',
          const Icon(Icons.badge_outlined, color: Color(0xFF9CA3AF), size: 18),
        ),
        onChanged: (v) {
          if (_useLoginAsNickname) {
            setState(() => _pseudoNameController.text = v);
          }
        },
      ),
      const SizedBox(height: 16),
      ..._buildPhoneNumberField(),
      const SizedBox(height: 16),
      _sectionLabel('TOTP Key'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _totpKeyProfitMartController,
        obscureText: !_showTotpProfitMart,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter TOTP Key' : null,
        decoration: _inputDecorationWithSuffix(
          'TOTP Key',
          _eyeToggle(
            _showTotpProfitMart,
                () => setState(
                    () => _showTotpProfitMart = !_showTotpProfitMart),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('API Key'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _apiKeyController,
        obscureText: !_showApiKeyProfitMart,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter API Key' : null,
        decoration: _inputDecorationWithSuffix(
          'Trading Platform API Key',
          _eyeToggle(
            _showApiKeyProfitMart,
                () => setState(
                    () => _showApiKeyProfitMart = !_showApiKeyProfitMart),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (!_isUpdate) ..._buildIpAddressField(),
      if (!_isUpdate) const SizedBox(height: 16),
      ..._buildOwnAccountField(),
      const SizedBox(height: 16),
      ..._buildPseudoNameFields(),
    ];
  }

  // ── Goodwill fields ────────────────────────────────────────────────────────
  List<Widget> _buildGoodWellFields() {
    return [
      _sectionLabel('Trading Platform Login ID (Client Code)'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _loginIdController,
        readOnly: _isUpdate,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter Login ID' : null,
        decoration: _inputDecorationWithSuffix(
          'Goodwill Client Code',
          const Icon(Icons.badge_outlined, color: Color(0xFF9CA3AF), size: 18),
        ),
        onChanged: (v) {
          if (_useLoginAsNickname) {
            setState(() => _pseudoNameController.text = v);
          }
        },
      ),
      const SizedBox(height: 16),
      ..._buildPhoneNumberField(),
      const SizedBox(height: 16),
      _sectionLabel('Password / MPIN'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _mpinController,
        obscureText: !_showMpin,
        validator: (v) => v == null || v.isEmpty ? 'Please enter Password / MPIN' : null,
        decoration: _inputDecorationWithSuffix(
          'Password / MPIN',
          _eyeToggle(_showMpin, () => setState(() => _showMpin = !_showMpin)),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('API Key (App Key)'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _apiKeyController,
        obscureText: !_showApiKeyGoodWell,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter API Key' : null,
        decoration: _inputDecorationWithSuffix(
          'Goodwill App Key',
          _eyeToggle(
            _showApiKeyGoodWell,
                () => setState(() => _showApiKeyGoodWell = !_showApiKeyGoodWell),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('API Secret Key'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _apiSecretKeyController,
        obscureText: !_showApiSecretKey,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter API Secret Key' : null,
        decoration: _inputDecorationWithSuffix(
          'Goodwill Secret Key',
          _eyeToggle(
            _showApiSecretKey,
                () => setState(() => _showApiSecretKey = !_showApiSecretKey),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('TOTP Key'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _totpKeyGoodWellController,
        obscureText: !_showTotpGoodWell,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter TOTP Key' : null,
        decoration: _inputDecorationWithSuffix(
          'TOTP Key',
          _eyeToggle(
            _showTotpGoodWell,
                () => setState(() => _showTotpGoodWell = !_showTotpGoodWell),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (!_isUpdate) ..._buildIpAddressField(),
      if (!_isUpdate) const SizedBox(height: 16),
      ..._buildOwnAccountField(),
      const SizedBox(height: 16),
      ..._buildPseudoNameFields(),
    ];
  }

  // ── Zerodha fields ─────────────────────────────────────────────────────────
  List<Widget> _buildZerodhaFields() {
    return [
      _sectionLabel('Kite User ID (Client ID)'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _loginIdController,
        readOnly: _isUpdate,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter Kite User ID' : null,
        decoration: _inputDecorationWithSuffix(
          'e.g. AB1234',
          const Icon(Icons.badge_outlined, color: Color(0xFF9CA3AF), size: 18),
        ),
        onChanged: (v) {
          if (_useLoginAsNickname) {
            setState(() => _pseudoNameController.text = v);
          }
        },
      ),
      const SizedBox(height: 16),
      ..._buildPhoneNumberField(),
      const SizedBox(height: 16),
      _sectionLabel('Kite API Key'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _apiKeyController,
        obscureText: !_showApiKey,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter Kite API Key' : null,
        decoration: _inputDecorationWithSuffix(
          'API Key from Kite Developer console',
          _eyeToggle(_showApiKey, () => setState(() => _showApiKey = !_showApiKey)),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('Kite API Secret'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _apiSecretKeyController,
        obscureText: !_showApiSecretKey,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter Kite API Secret' : null,
        decoration: _inputDecorationWithSuffix(
          'API Secret from Kite Developer console',
          _eyeToggle(_showApiSecretKey, () => setState(() => _showApiSecretKey = !_showApiSecretKey)),
        ),
      ),
      const SizedBox(height: 16),
      if (!_isUpdate) ..._buildIpAddressField(),
      if (!_isUpdate) const SizedBox(height: 16),
      ..._buildOwnAccountField(),
      const SizedBox(height: 16),
      ..._buildPseudoNameFields(),
    ];
  }

  // ── Upstox fields ──────────────────────────────────────────────────────────
  List<Widget> _buildUpstoxFields() {
    return [
      _sectionLabel('Upstox UCC / Client ID'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _loginIdController,
        readOnly: _isUpdate,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter Client ID / UCC' : null,
        decoration: _inputDecorationWithSuffix(
          'e.g. 6WAABC',
          const Icon(Icons.badge_outlined, color: Color(0xFF9CA3AF), size: 18),
        ),
        onChanged: (v) {
          if (_useLoginAsNickname) {
            setState(() => _pseudoNameController.text = v);
          }
        },
      ),
      const SizedBox(height: 16),
      ..._buildPhoneNumberField(),
      const SizedBox(height: 16),
      _sectionLabel('Upstox API Key'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _apiKeyController,
        obscureText: !_showApiKey,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter Upstox API Key' : null,
        decoration: _inputDecorationWithSuffix(
          'API Key from Upstox Developer portal',
          _eyeToggle(_showApiKey, () => setState(() => _showApiKey = !_showApiKey)),
        ),
      ),
      const SizedBox(height: 16),
      _sectionLabel('Upstox API Secret Key'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _apiSecretKeyController,
        obscureText: !_showApiSecretKey,
        validator: (v) =>
        v == null || v.isEmpty ? 'Please enter Upstox API Secret' : null,
        decoration: _inputDecorationWithSuffix(
          'API Secret from Upstox Developer portal',
          _eyeToggle(_showApiSecretKey, () => setState(() => _showApiSecretKey = !_showApiSecretKey)),
        ),
      ),
      const SizedBox(height: 16),
      if (!_isUpdate) ..._buildIpAddressField(),
      if (!_isUpdate) const SizedBox(height: 16),
      ..._buildOwnAccountField(),
      const SizedBox(height: 16),
      ..._buildPseudoNameFields(),
    ];
  }

  List<Widget> _buildPseudoNameFields() {
    return [
      _sectionLabel('Pseudo Name (Nickname)'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _pseudoNameController,
        enabled: !_useLoginAsNickname,
        validator: (v) {
          if (_useLoginAsNickname) return null;
          if (v == null || v.trim().isEmpty) return 'Please enter a Pseudo Name';
          return null;
        },
        decoration: _inputDecorationWithSuffix(
          'Easy to remember nickname',
          const Icon(Icons.tag_outlined, color: Color(0xFF9CA3AF), size: 18),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: _useLoginAsNickname,
              activeColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
              onChanged: (v) {
                setState(() {
                  _useLoginAsNickname = v ?? false;
                  if (_useLoginAsNickname) _pseudoNameController.text = '';
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Use trading account login id as nickname',
            style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    ];
  }

  // ── Own Account ────────────────────────────────────────────────────────────
  List<Widget> _buildOwnAccountField() {
    return [
      _sectionLabel('Own Account'),
      const SizedBox(height: 4),
      const Text(
        'Is this your own trading account?',
        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _ownAccountOption(
              true,
              'Yes',
              Icons.person_rounded,
              const Color(0xFF1D4ED8),
              const Color(0xFFEFF6FF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ownAccountOption(
              false,
              'No',
              Icons.people_alt_outlined,
              const Color(0xFFF97316),
              const Color(0xFFFFF7ED),
            ),
          ),
        ],
      ),
      if (_ownAccountError) ...[
        const SizedBox(height: 6),
        const Text(
          'Please select whether this is your own account',
          style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
        ),
      ],
    ];
  }

  Widget _ownAccountOption(
      bool value,
      String label,
      IconData icon,
      Color activeColor,
      Color activeBg,
      ) {
    final selected = _ownAccount == value;
    return InkWell(
      onTap: () => setState(() {
        _ownAccount = value;
        _ownAccountError = false;
      }),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? activeBg : Colors.white,
          border: Border.all(
            color: selected
                ? activeColor
                : _ownAccountError
                ? const Color(0xFFDC2626)
                : const Color(0xFFD1D5DB),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: selected ? activeColor : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 6),
            Icon(
              icon,
              size: 15,
              color: selected ? activeColor : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? activeColor : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Review screen ──────────────────────────────────────────────────────────
  Widget _buildReviewScreen(BuildContext context) {
    return BlocBuilder<AddDematBloc, AddDematAccountState>(
      builder: (context, state) {
        final isLoading = state is AddDematAccountLoading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReviewCard(
              title: 'Account Info',
              icon: Icons.account_circle_outlined,
              rows: [
                _reviewRow('Account Type', 'Individual Client'),
                _reviewRow('Own Account', _ownAccount == true ? 'Yes' : 'No'),
              ],
            ),
            const SizedBox(height: 14),
            _buildReviewCard(
              title: 'Broker Details',
              icon: Icons.business_center_outlined,
              rows: [
                _reviewRow('Stock Broker', _selectedBroker ?? ''),
                _reviewRow(
                  'Trading Platform',
                  _selectedBroker == 'Angel One'
                      ? 'SMART_API'
                      : _selectedBroker == 'Motilal Oswal'
                      ? 'MOTILAL_API'
                      : _selectedBroker == 'Dhan'
                      ? 'DHAN_API'
                      : _selectedBroker == 'Profit Mart'
                      ? 'PROFITMART_API'
                      : _selectedBroker == 'Good Well'
                      ? 'GOODWILL_API'
                      : _selectedBroker == 'Zerodha'
                      ? 'KITE_CONNECT_API'
                      : _selectedBroker == 'Upstox'
                      ? 'UPSTOX_V2_API'
                      : 'GROWW_PLATFORM',
                ),
                _reviewRow('Login ID', _loginIdController.text),
                _reviewRow('Phone Number', _phoneNumberController.text.trim()),
                if (_selectedBroker == 'Angel One') ...[
                  _reviewRow('MPIN', '•' * _mpinController.text.length),
                  _reviewRow(
                    'TOTP Key',
                    '•' * _totpKeyAngelController.text.length,
                  ),
                  _reviewRow('API Key', '•' * _apiKeyController.text.length),
                ],
                if (_selectedBroker == 'Motilal Oswal') ...[
                  _reviewRow('Password', '•' * _mpinController.text.length),
                  _reviewRow(
                    'TOTP Key',
                    '•' * _totpKeyMotilalController.text.length,
                  ),
                  _reviewRow('API Key', '•' * _apiKeyController.text.length),
                  _reviewRow(
                    'API Secret Key',
                    '•' * _apiSecretKeyController.text.length,
                  ),
                  _reviewRow(
                    'Date of Birth (2FA)',
                    _selectedDob != null ? _formatDob(_selectedDob!) : '',
                  ),
                ],
                if (_selectedBroker == 'Dhan') ...[
                  _reviewRow('MPIN', '•' * _mpinController.text.length),
                  _reviewRow(
                    'TOTP Key',
                    '•' * _totpKeyDhanController.text.length,
                  ),
                ],
                if (_selectedBroker == 'Profit Mart') ...[
                  _reviewRow(
                    'TOTP Key',
                    '•' * _totpKeyProfitMartController.text.length,
                  ),
                  _reviewRow('API Key', '•' * _apiKeyController.text.length),
                ],
                if (_selectedBroker == 'Good Well') ...[
                  _reviewRow('Password / MPIN', '•' * _mpinController.text.length),
                  _reviewRow('API Key (App Key)', '•' * _apiKeyController.text.length),
                  _reviewRow('API Secret Key', '•' * _apiSecretKeyController.text.length),
                  _reviewRow('TOTP Key', '•' * _totpKeyGoodWellController.text.length),
                ],
                if (_selectedBroker == 'Zerodha') ...[
                  _reviewRow('Kite API Key', '•' * _apiKeyController.text.length),
                  _reviewRow('Kite API Secret', '•' * _apiSecretKeyController.text.length),
                ],
                if (_selectedBroker == 'Upstox') ...[
                  _reviewRow('Upstox API Key', '•' * _apiKeyController.text.length),
                  _reviewRow('Upstox API Secret', '•' * _apiSecretKeyController.text.length),
                ],
                _reviewRow('Pseudo Name', _pseudoNameController.text),
              ],
            ),
            const SizedBox(height: 14),
            if (!_isUpdate)
              _buildReviewCard(
                title: 'Server Configuration',
                icon: Icons.dns_outlined,
                rows: [
                  _reviewRow('IP Address', _ipController.text.trim()),
                  _reviewRowWithBadge(
                    'IP Status',
                    'Verified',
                    const Color(0xFF059669),
                    const Color(0xFFD1FAE5),
                  ),
                ],
              ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => setState(() => _showReviewScreen = false),
                    icon: const Icon(Icons.arrow_back, size: 15),
                    label: const Text('Back & Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      foregroundColor: const Color(0xFF374151),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () {
                      if (_isUpdate && _recordId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Unable to update: account ID is missing',
                            ),
                            backgroundColor: Color(0xFFDC2626),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      if (_selectedBroker == 'Angel One') {
                        _submitAngelOne(context);
                      } else if (_selectedBroker == 'Motilal Oswal') {
                        _submitMotilal(context);
                      } else if (_selectedBroker == 'Dhan') {
                        _submitDhan(context);
                      } else if (_selectedBroker == 'Profit Mart') {
                        _submitProfitMart(context);
                      } else if (_selectedBroker == 'Good Well') {
                        _submitGoodWell(context);
                      } else if (_selectedBroker == 'Zerodha') {
                        _submitZerodha(context);
                      } else if (_selectedBroker == 'Upstox') {
                        _submitUpstox(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isUpdate
                          ? AppColors.primaryBlue
                          : const Color(0xFF059669),
                      disabledBackgroundColor:
                      (_isUpdate
                          ? AppColors.primaryBlue
                          : const Color(0xFF059669))
                          .withOpacity(0.55),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isUpdate
                              ? Icons.save_outlined
                              : Icons.check_circle_outline,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isUpdate ? 'Save Changes' : 'Confirm & Add',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────
  Widget _eyeToggle(bool visible, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Icon(
      visible ? Icons.visibility : Icons.visibility_off,
      color: const Color(0xFF9CA3AF),
      size: 18,
    ),
  );

  Widget _readOnlyField(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      border: Border.all(color: const Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF374151),
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _buildReviewCard({
    required String title,
    required IconData icon,
    required List<Widget> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 14, color: const Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
          ...rows.map(
                (row) => Column(
              children: [
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: row,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
      ),
    ],
  );

  Widget _reviewRowWithBadge(
      String label,
      String badgeText,
      Color textColor,
      Color bgColor,
      ) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              badgeText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Color(0xFF374151),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
    ),
  );

  InputDecoration _inputDecorationWithSuffix(String hint, Widget suffix) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: suffix,
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
      );
}

// ── DOB auto-formatter ─────────────────────────────────────────────────────────
class _DobInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}