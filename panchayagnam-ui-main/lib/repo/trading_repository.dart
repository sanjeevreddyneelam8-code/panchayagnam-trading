import 'package:dartz/dartz.dart';

import '../../models/add_demat_account_request.dart';
import '../../models/add_demat_account_response.dart';
import '../models/ScripInfo.dart';
import '../service/individual_investment_service.dart';

abstract class TradingRepository {
  Future<Either<TradingServiceException, AddDematAccountResponse>>
  addDematAccount(AddDematAccountRequest request, String actionType);

  Future<Either<TradingServiceException, List<ScripInfo>>> searchScrip(
    String query,
    String exchange,
  );

  Future<Either<TradingServiceException, LtpData>> getLtp({
    required String exchange,
    required String tradingSymbol,
    required String symbolToken,
  });

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
  });

  Future<Either<TradingServiceException, List<OrderHistoryItem>>>
  getOrderHistory(int accId);

  Future<Either<TradingServiceException, OrderDetail>> getOrderStatus({
    required String uniqueOrderId,
    required int accId,
  });

  Future<Either<TradingServiceException, String>> cancelOrder({
    required int accId,
    required String orderId,
    required String variety,
  });

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
  });
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
  });
}
