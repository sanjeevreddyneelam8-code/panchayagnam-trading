import 'package:dartz/dartz.dart';

import '../models/ScripInfo.dart';
import '../repo/trading_repository.dart';
import '../service/individual_investment_service.dart';

class SearchScripUseCase {
  final TradingRepository _repo;
  const SearchScripUseCase(this._repo);

  Future<Either<TradingServiceException, List<ScripInfo>>> call(
      String query,
      String exchange,
      ) =>
      _repo.searchScrip(query, exchange);
}

class GetLtpUseCase {
  final TradingRepository _repo;
  const GetLtpUseCase(this._repo);

  Future<Either<TradingServiceException, LtpData>> call({
    required String exchange,
    required String tradingSymbol,
    required String symbolToken,
  }) =>
      _repo.getLtp(
        exchange: exchange,
        tradingSymbol: tradingSymbol,
        symbolToken: symbolToken,
      );
}

class PlaceOrderUseCase {
  final TradingRepository _repo;
  const PlaceOrderUseCase(this._repo);

  Future<Either<TradingServiceException, String>> call({
    required int accId,
    required String tradingSymbol,
    required String symbolToken,
    required String exchange,
    required int quantity,
    required String orderType,
    required double price,
    required String productType,
    required String variety,
    required String side,
    String? idempotencyKey,
  }) =>
      _repo.placeOrder(
        accId: accId,
        tradingSymbol: tradingSymbol,
        symbolToken: symbolToken,
        exchange: exchange,
        quantity: quantity,
        orderType: orderType,
        price: price,
        productType: productType,
        variety: variety,
        side: side,
        idempotencyKey: idempotencyKey,
      );
}

class GetOrderHistoryUseCase {
  final TradingRepository _repo;
  const GetOrderHistoryUseCase(this._repo);

  Future<Either<TradingServiceException, List<OrderHistoryItem>>> call(
      int accId,
      ) =>
      _repo.getOrderHistory(accId);
}

class GetOrderStatusUseCase {
  final TradingRepository _repo;
  const GetOrderStatusUseCase(this._repo);

  Future<Either<TradingServiceException, OrderDetail>> call({
    required String uniqueOrderId,
    required int accId,
  }) =>
      _repo.getOrderStatus(uniqueOrderId: uniqueOrderId, accId: accId);
}

class CancelOrderUseCase {
  final TradingRepository _repo;
  const CancelOrderUseCase(this._repo);

  Future<Either<TradingServiceException, String>> call({
    required int accId,
    required String orderId,
    required String variety,
  }) =>
      _repo.cancelOrder(
        accId: accId,
        orderId: orderId,
        variety: variety,
      );
}

class ModifyOrderUseCase {
  final TradingRepository _repo;
  const ModifyOrderUseCase(this._repo);

  Future<Either<TradingServiceException, String>> call({
    required int accId,
    required String orderId,
    required String variety,
    required String exchange,
    required String tradingSymbol,
    required String symbolToken,
    required String orderType,
    required String productType,
    required int quantity,
    required double price,
    required double triggerPrice,
    required String duration,
  }) =>
      _repo.modifyOrder(
        accId: accId,
        orderId: orderId,
        variety: variety,
        exchange: exchange,
        tradingSymbol: tradingSymbol,
        symbolToken: symbolToken,
        orderType: orderType,
        productType: productType,
        quantity: quantity,
        price: price,
        triggerPrice: triggerPrice,
        duration: duration,
      );
}

class ConvertPositionUseCase {
  final TradingRepository _repo;
  const ConvertPositionUseCase(this._repo);

  Future<Either<TradingServiceException, String>> call({
    required int accId,
    required String exchange,
    required String symbolToken,
    required String tradingSymbol,
    required String symbolName,
    required String oldProductType,
    required String newProductType,
    required String transactionType,
    required int quantity,
    required String buyQty,
    required String sellQty,
    required String buyAmount,
    required String sellAmount,
  }) =>
      _repo.convertPosition(
        accId: accId,
        exchange: exchange,
        symbolToken: symbolToken,
        tradingSymbol: tradingSymbol,
        symbolName: symbolName,
        oldProductType: oldProductType,
        newProductType: newProductType,
        transactionType: transactionType,
        quantity: quantity,
        buyQty: buyQty,
        sellQty: sellQty,
        buyAmount: buyAmount,
        sellAmount: sellAmount,
      );
}