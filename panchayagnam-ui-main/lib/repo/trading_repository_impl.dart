import 'package:dartz/dartz.dart';
import '../repo/trading_repository.dart';
import '../../models/add_demat_account_request.dart';
import '../../models/add_demat_account_response.dart';
import '../models/ScripInfo.dart';
import '../service/individual_investment_service.dart';

class TradingRepositoryImpl implements TradingRepository {
  final TradingRemoteDataSource _remote;

  const TradingRepositoryImpl(this._remote);

  @override
  Future<Either<TradingServiceException, AddDematAccountResponse>>
  addDematAccount(AddDematAccountRequest request, String actionType) async {
    try {
      final result = await _remote.addDematAccount(request, actionType);
      return Right(result);
    } on TradingServiceException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(TradingServiceException(e.toString()));
    }
  }

  @override
  Future<Either<TradingServiceException, List<ScripInfo>>> searchScrip(
    String query,
    String exchange,
  ) async {
    try {
      final result = await _remote.searchScrip(query, exchange);
      return Right(result);
    } on TradingServiceException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(TradingServiceException(e.toString()));
    }
  }

  @override
  Future<Either<TradingServiceException, LtpData>> getLtp({
    required String exchange,
    required String tradingSymbol,
    required String symbolToken,
  }) async {
    try {
      final result = await _remote.getLtp(
        exchange: exchange,
        tradingSymbol: tradingSymbol,
        symbolToken: symbolToken,
      );
      return Right(result);
    } on TradingServiceException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(TradingServiceException(e.toString()));
    }
  }

  @override
  Future<Either<TradingServiceException, String>> placeOrder({
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
  }) async {
    try {
      final result = await _remote.placeOrder(
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
      return Right(result);
    } on TradingServiceException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(TradingServiceException(e.toString()));
    }
  }

  @override
  Future<Either<TradingServiceException, List<OrderHistoryItem>>>
  getOrderHistory(int accId) async {
    try {
      final result = await _remote.getOrderHistory(accId);
      return Right(result);
    } on TradingServiceException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(TradingServiceException(e.toString()));
    }
  }

  @override
  Future<Either<TradingServiceException, OrderDetail>> getOrderStatus({
    required String uniqueOrderId,
    required int accId,
  }) async {
    try {
      final result = await _remote.getOrderStatus(
        uniqueOrderId: uniqueOrderId,
        accId: accId,
      );
      return Right(result);
    } on TradingServiceException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(TradingServiceException(e.toString()));
    }
  }

  @override
  Future<Either<TradingServiceException, String>> cancelOrder({
    required int accId,
    required String orderId,
    required String variety,
  }) async {
    try {
      final result = await _remote.cancelOrder(
        accId: accId,
        orderId: orderId,
        variety: variety,
      );
      return Right(result);
    } on TradingServiceException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(TradingServiceException(e.toString()));
    }
  }

  @override
  Future<Either<TradingServiceException, String>> modifyOrder({
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
  }) async {
    try {
      final result = await _remote.modifyOrder(
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
      return Right(result);
    } on TradingServiceException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(TradingServiceException(e.toString()));
    }
  }

  @override
  Future<Either<TradingServiceException, String>> convertPosition({
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
  }) async {
    try {
      final result = await _remote.convertPosition(
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
      return Right(result);
    } on TradingServiceException catch (e) {
      return Left(e);
    } catch (e) {
      return Left(TradingServiceException(e.toString()));
    }
  }
}
