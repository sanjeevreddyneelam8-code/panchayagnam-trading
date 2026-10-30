import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/ScripInfo.dart';
import '../../service/individual_investment_service.dart';
import '../../ui_screens/web_screens/main_dashboard_screen/individual_execution_screen.dart';
import '../../use_causes/use_causes.dart';
import '../../repo/trading_repository_impl.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  EVENTS
// ══════════════════════════════════════════════════════════════════════════════

abstract class IndividualExecutionEvent extends Equatable {
  const IndividualExecutionEvent();
  @override
  List<Object?> get props => [];
}

class SearchScripRequested extends IndividualExecutionEvent {
  final String query;
  final String exchange;
  const SearchScripRequested({required this.query, this.exchange = 'NSE'});
  @override
  List<Object?> get props => [query, exchange];
}

class ScripSelected extends IndividualExecutionEvent {
  final ScripInfo scrip;
  const ScripSelected(this.scrip);
  @override
  List<Object?> get props => [scrip];
}

class LtpRequested extends IndividualExecutionEvent {
  final ScripInfo scrip;
  const LtpRequested(this.scrip);
  @override
  List<Object?> get props => [scrip];
}

class PlaceOrderRequested extends IndividualExecutionEvent {
  final int accId;
  final ScripInfo scrip;
  final int quantity;
  final String orderType;
  final double price;
  final String productType;
  final String variety;
  final String side;
  final BuildContext ctx;
  final String? idempotencyKey;

  const PlaceOrderRequested({
    required this.accId,
    required this.scrip,
    required this.quantity,
    required this.orderType,
    required this.price,
    required this.productType,
    required this.variety,
    required this.side,
    required this.ctx,
    this.idempotencyKey,
  });

  @override
  List<Object?> get props => [
    accId,
    scrip,
    quantity,
    orderType,
    price,
    productType,
    variety,
    side,
    idempotencyKey,
  ];
}

class OrderHistoryRequested extends IndividualExecutionEvent {
  final int accId;
  const OrderHistoryRequested(this.accId);
  @override
  List<Object?> get props => [accId];
}

class OrderStatusRequested extends IndividualExecutionEvent {
  final String uniqueOrderId;
  final int accId;
  const OrderStatusRequested({
    required this.uniqueOrderId,
    required this.accId,
  });
  @override
  List<Object?> get props => [uniqueOrderId, accId];
}

class CancelOrderRequested extends IndividualExecutionEvent {
  final int accId;
  final String orderId;
  final String variety;
  final BuildContext ctx;

  const CancelOrderRequested({
    required this.accId,
    required this.orderId,
    required this.variety,
    required this.ctx,
  });

  @override
  List<Object?> get props => [accId, orderId, variety];
}

class ModifyOrderRequested extends IndividualExecutionEvent {
  final int accId;
  final String orderId;
  final String variety;
  final String exchange;
  final String tradingSymbol;
  final String symbolToken;
  final String orderType;
  final String productType;
  final int quantity;
  final double price;
  final double triggerPrice;
  final String duration;
  final BuildContext ctx;

  const ModifyOrderRequested({
    required this.accId,
    required this.orderId,
    required this.variety,
    required this.exchange,
    required this.tradingSymbol,
    required this.symbolToken,
    required this.orderType,
    required this.productType,
    required this.quantity,
    required this.price,
    required this.triggerPrice,
    required this.duration,
    required this.ctx,
  });

  @override
  List<Object?> get props => [accId, orderId, variety, quantity, price];
}

// ══════════════════════════════════════════════════════════════════════════════
//  STATES
// ══════════════════════════════════════════════════════════════════════════════

abstract class IndividualExecutionState extends Equatable {
  const IndividualExecutionState();
  @override
  List<Object?> get props => [];
}

class IndividualExecutionInitial extends IndividualExecutionState {
  const IndividualExecutionInitial();
}

class ScripSearchLoading extends IndividualExecutionState {
  const ScripSearchLoading();
}

class ScripSearchSuccess extends IndividualExecutionState {
  final List<ScripInfo> results;
  const ScripSearchSuccess(this.results);
  @override
  List<Object?> get props => [results];
}

class ScripSearchFailure extends IndividualExecutionState {
  final String message;
  const ScripSearchFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class LtpLoading extends IndividualExecutionState {
  final ScripInfo scrip;
  final int _ts;
  LtpLoading(this.scrip) : _ts = DateTime.now().microsecondsSinceEpoch;
  @override
  List<Object?> get props => [scrip, _ts];
}

class LtpSuccess extends IndividualExecutionState {
  final ScripInfo scrip;
  final LtpData ltpData;
  final int _ts;
  LtpSuccess({required this.scrip, required this.ltpData})
    : _ts = DateTime.now().microsecondsSinceEpoch;
  @override
  List<Object?> get props => [scrip, ltpData, _ts];
}

class LtpFailure extends IndividualExecutionState {
  final ScripInfo scrip;
  final String message;
  final int _ts;
  LtpFailure({required this.scrip, required this.message})
    : _ts = DateTime.now().microsecondsSinceEpoch;
  @override
  List<Object?> get props => [scrip, message, _ts];
}

class OrderPlacing extends IndividualExecutionState {
  final String side;
  const OrderPlacing(this.side);
  @override
  List<Object?> get props => [side];
}

class OrderPlaced extends IndividualExecutionState {
  final String result;
  const OrderPlaced(this.result);
  @override
  List<Object?> get props => [result];
}

class OrderPlacementFailure extends IndividualExecutionState {
  final String message;
  const OrderPlacementFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class OrderHistoryLoading extends IndividualExecutionState {
  const OrderHistoryLoading();
}

class OrderHistorySuccess extends IndividualExecutionState {
  final List<OrderHistoryItem> orders;
  const OrderHistorySuccess(this.orders);
  @override
  List<Object?> get props => [orders];
}

class OrderHistoryFailure extends IndividualExecutionState {
  final String message;
  const OrderHistoryFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class OrderStatusLoading extends IndividualExecutionState {
  const OrderStatusLoading();
}

class OrderStatusSuccess extends IndividualExecutionState {
  final OrderDetail detail;
  const OrderStatusSuccess(this.detail);
  @override
  List<Object?> get props => [detail];
}

class OrderStatusFailure extends IndividualExecutionState {
  final String message;
  const OrderStatusFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class CancelOrderLoading extends IndividualExecutionState {
  final String orderId;
  const CancelOrderLoading(this.orderId);
  @override
  List<Object?> get props => [orderId];
}

class CancelOrderSuccess extends IndividualExecutionState {
  final String message;
  final String orderId;
  const CancelOrderSuccess({required this.message, required this.orderId});
  @override
  List<Object?> get props => [message, orderId];
}

class CancelOrderFailure extends IndividualExecutionState {
  final String message;
  final String orderId;
  const CancelOrderFailure({required this.message, required this.orderId});
  @override
  List<Object?> get props => [message, orderId];
}

class ModifyOrderLoading extends IndividualExecutionState {
  final String orderId;
  const ModifyOrderLoading(this.orderId);
  @override
  List<Object?> get props => [orderId];
}

class ModifyOrderSuccess extends IndividualExecutionState {
  final String message;
  final String orderId;
  const ModifyOrderSuccess({required this.message, required this.orderId});
  @override
  List<Object?> get props => [message, orderId];
}

class ModifyOrderFailure extends IndividualExecutionState {
  final String message;
  final String orderId;
  const ModifyOrderFailure({required this.message, required this.orderId});
  @override
  List<Object?> get props => [message, orderId];
}

// ══════════════════════════════════════════════════════════════════════════════
//  BLOC
// ══════════════════════════════════════════════════════════════════════════════

class IndividualExecutionBloc
    extends Bloc<IndividualExecutionEvent, IndividualExecutionState> {
  final SearchScripUseCase _searchScrip;
  final GetLtpUseCase _getLtp;
  final PlaceOrderUseCase _placeOrder;
  final GetOrderHistoryUseCase _getOrderHistory;
  final GetOrderStatusUseCase _getOrderStatus;
  final CancelOrderUseCase _cancelOrder;
  final ModifyOrderUseCase _modifyOrder;
  final ConvertPositionUseCase _convertPosition;

  factory IndividualExecutionBloc.create() {
    final repo = TradingRepositoryImpl(TradingRemoteDataSourceImpl());
    return IndividualExecutionBloc(
      searchScrip: SearchScripUseCase(repo),
      getLtp: GetLtpUseCase(repo),
      placeOrder: PlaceOrderUseCase(repo),
      getOrderHistory: GetOrderHistoryUseCase(repo),
      getOrderStatus: GetOrderStatusUseCase(repo),
      cancelOrder: CancelOrderUseCase(repo),
      modifyOrder: ModifyOrderUseCase(repo),
      convertPosition: ConvertPositionUseCase(repo),
    );
  }

  IndividualExecutionBloc({
    required SearchScripUseCase searchScrip,
    required GetLtpUseCase getLtp,
    required PlaceOrderUseCase placeOrder,
    required GetOrderHistoryUseCase getOrderHistory,
    required GetOrderStatusUseCase getOrderStatus,
    required CancelOrderUseCase cancelOrder,
    required ModifyOrderUseCase modifyOrder,
    required ConvertPositionUseCase convertPosition,
  }) : _searchScrip = searchScrip,
       _getLtp = getLtp,
       _placeOrder = placeOrder,
       _getOrderHistory = getOrderHistory,
       _getOrderStatus = getOrderStatus,
       _cancelOrder = cancelOrder,
       _modifyOrder = modifyOrder,
       _convertPosition = convertPosition,
       super(const IndividualExecutionInitial()) {
    on<SearchScripRequested>(_onSearchScrip);
    on<ScripSelected>(_onScripSelected);
    on<LtpRequested>(_onLtpRequested);
    on<PlaceOrderRequested>(_onPlaceOrder);
    on<OrderHistoryRequested>(_onOrderHistory);
    on<OrderStatusRequested>(_onOrderStatus);
    on<CancelOrderRequested>(_onCancelOrder);
    on<ModifyOrderRequested>(_onModifyOrder);
    on<ConvertPositionRequested>(_onConvertPosition);
  }

  Future<void> _onSearchScrip(
    SearchScripRequested event,
    Emitter<IndividualExecutionState> emit,
  ) async {
    emit(const ScripSearchLoading());
    final result = await _searchScrip(event.query, event.exchange);
    result.fold(
      (f) => emit(ScripSearchFailure(f.message)),
      (s) => emit(ScripSearchSuccess(s)),
    );
  }

  Future<void> _onScripSelected(
    ScripSelected event,
    Emitter<IndividualExecutionState> emit,
  ) async {
    emit(LtpLoading(event.scrip));
    final result = await _getLtp(
      exchange: event.scrip.exchange,
      tradingSymbol: event.scrip.tradingSymbol,
      symbolToken: event.scrip.symbolToken,
    );
    result.fold(
      (f) => emit(LtpFailure(scrip: event.scrip, message: f.message)),
      (d) => emit(LtpSuccess(scrip: event.scrip, ltpData: d)),
    );
  }

  Future<void> _onLtpRequested(
    LtpRequested event,
    Emitter<IndividualExecutionState> emit,
  ) async {
    emit(LtpLoading(event.scrip));
    final result = await _getLtp(
      exchange: event.scrip.exchange,
      tradingSymbol: event.scrip.tradingSymbol,
      symbolToken: event.scrip.symbolToken,
    );
    result.fold(
      (f) => emit(LtpFailure(scrip: event.scrip, message: f.message)),
      (d) => emit(LtpSuccess(scrip: event.scrip, ltpData: d)),
    );
  }

  Future<void> _onPlaceOrder(
    PlaceOrderRequested event,
    Emitter<IndividualExecutionState> emit,
  ) async {
    emit(OrderPlacing(event.side));
    final safeSymbol = event.scrip.tradingSymbol.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final keyToUse = (event.idempotencyKey != null && event.idempotencyKey!.isNotEmpty)
        ? event.idempotencyKey!
        : 'UI-${DateTime.now().millisecondsSinceEpoch}-$safeSymbol-${event.quantity}';

    final result = await _placeOrder(
      accId: event.accId,
      tradingSymbol: event.scrip.tradingSymbol,
      symbolToken: event.scrip.symbolToken,
      exchange: event.scrip.exchange,
      quantity: event.quantity,
      orderType: event.orderType,
      price: event.price,
      productType: event.productType,
      variety: event.variety,
      side: event.side,
      idempotencyKey: keyToUse,
    );
    result.fold(
      (f) {
        emit(OrderPlacementFailure(f.message));
        _showSnack(event.ctx, 'Order failed: ${f.message}', isError: true);
      },
      (r) {
        emit(OrderPlaced(r));
        _showSnack(event.ctx, 'Order placed successfully ✓', isError: false);
      },
    );
  }

  Future<void> _onOrderHistory(
    OrderHistoryRequested event,
    Emitter<IndividualExecutionState> emit,
  ) async {
    emit(const OrderHistoryLoading());
    final result = await _getOrderHistory(event.accId);
    result.fold(
      (f) => emit(OrderHistoryFailure(f.message)),
      (o) => emit(OrderHistorySuccess(o)),
    );
  }

  Future<void> _onOrderStatus(
    OrderStatusRequested event,
    Emitter<IndividualExecutionState> emit,
  ) async {
    emit(const OrderStatusLoading());
    final result = await _getOrderStatus(
      uniqueOrderId: event.uniqueOrderId,
      accId: event.accId,
    );
    result.fold(
      (f) => emit(OrderStatusFailure(f.message)),
      (d) => emit(OrderStatusSuccess(d)),
    );
  }

  Future<void> _onCancelOrder(
    CancelOrderRequested event,
    Emitter<IndividualExecutionState> emit,
  ) async {
    emit(CancelOrderLoading(event.orderId));
    final result = await _cancelOrder(
      accId: event.accId,
      orderId: event.orderId,
      variety: event.variety,
    );
    result.fold(
      (f) {
        emit(CancelOrderFailure(message: f.message, orderId: event.orderId));
        _showSnack(event.ctx, 'Cancel failed: ${f.message}', isError: true);
      },
      (r) {
        emit(CancelOrderSuccess(message: r, orderId: event.orderId));
        _showSnack(event.ctx, 'Order cancelled successfully', isError: false);
      },
    );
  }

  Future<void> _onModifyOrder(
    ModifyOrderRequested event,
    Emitter<IndividualExecutionState> emit,
  ) async {
    emit(ModifyOrderLoading(event.orderId));
    final result = await _modifyOrder(
      accId: event.accId,
      orderId: event.orderId,
      variety: event.variety,
      exchange: event.exchange,
      tradingSymbol: event.tradingSymbol,
      symbolToken: event.symbolToken,
      orderType: event.orderType,
      productType: event.productType,
      quantity: event.quantity,
      price: event.price,
      triggerPrice: event.triggerPrice,
      duration: event.duration,
    );
    result.fold(
      (f) {
        emit(ModifyOrderFailure(message: f.message, orderId: event.orderId));
        _showSnack(event.ctx, 'Modify failed: ${f.message}', isError: true);
      },
      (r) {
        emit(ModifyOrderSuccess(message: r, orderId: event.orderId));
        _showSnack(event.ctx, 'Order modified successfully ✓', isError: false);
      },
    );
  }

  Future<void> _onConvertPosition(
    ConvertPositionRequested event,
    Emitter<IndividualExecutionState> emit,
  ) async {
    final p = event.position;
    final token = p.token;
    final qty = event.quantity;
    final isLong = p.netQty >= 0;

    emit(ConvertPositionLoading(token));

    final result = await _convertPosition(
      accId: event.accId,
      exchange: p.exchange,
      symbolToken: p.token,
      tradingSymbol: p.tradingSymbol,
      symbolName: p.tradingSymbol, // API needs this; use tradingSymbol
      oldProductType: p.productType,
      newProductType: event.newProductType,
      transactionType: isLong ? 'BUY' : 'SELL',
      quantity: qty,
      buyQty: isLong ? '$qty' : '0',
      sellQty: isLong ? '0' : '$qty',
      buyAmount: isLong ? (p.avgPrice * qty).toStringAsFixed(2) : '0',
      sellAmount: isLong ? '0' : (p.avgPrice * qty).toStringAsFixed(2),
    );

    result.fold(
      (f) {
        emit(ConvertPositionFailure(message: f.message, token: token));
        _showSnack(event.ctx, 'Convert failed: ${f.message}', isError: true);
      },
      (r) {
        emit(ConvertPositionSuccess(message: r, token: token));
        _showSnack(
          event.ctx,
          'Position converted successfully ✓',
          isError: false,
        );
      },
    );
  }
}

void _showSnack(BuildContext ctx, String msg, {required bool isError}) {
  if (!ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: isError
          ? const Color(0xFFDC2626)
          : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ),
  );
}

class ConvertPositionRequested extends IndividualExecutionEvent {
  final int accId;
  final WsPosition position;
  final String newProductType;
  final int quantity; // ← NEW: user-selected qty
  final BuildContext ctx;

  const ConvertPositionRequested({
    required this.accId,
    required this.position,
    required this.newProductType,
    required this.quantity,
    required this.ctx,
  });

  @override
  List<Object?> get props => [accId, position.token, newProductType, quantity];
}

// ── NEW STATES ─────────────────────────────────────────────────────────────
class ConvertPositionLoading extends IndividualExecutionState {
  final String token;
  const ConvertPositionLoading(this.token);
  @override
  List<Object?> get props => [token];
}

class ConvertPositionSuccess extends IndividualExecutionState {
  final String message;
  final String token;
  const ConvertPositionSuccess({required this.message, required this.token});
  @override
  List<Object?> get props => [message, token];
}

class ConvertPositionFailure extends IndividualExecutionState {
  final String message;
  final String token;
  const ConvertPositionFailure({required this.message, required this.token});
  @override
  List<Object?> get props => [message, token];
}
