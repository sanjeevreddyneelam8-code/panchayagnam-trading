package com.py.demataccount.service;

import com.py.brokers.angel.dto.Order;
import com.py.brokers.angel.exception.DeActivatedAccountException;
import com.py.brokers.angel.exception.SmartAPIException;
import com.py.brokers.angel.dto.CancelOrderRequest;
import com.py.brokers.angel.dto.ModifyOrderRequest;
import com.py.common.dto.ApiResponse;
import com.py.common.enums.AccountActionType;
import com.py.common.enums.BrokerType;
import com.py.demataccount.dto.DematAccountAddRequest;
import com.py.demataccount.dto.DematAccountFetchResponse;
import com.py.dto.ConvertPositionRequest;
import com.py.dto.PyBrokerAccountSummaryDto;
import com.py.easytrade.dto.IndividualOrderRequest;

import java.util.List;
import java.util.Map;
import org.json.JSONObject;

public interface PyBrokerAccountService {

    ApiResponse<?> dematAccountOperations(
            DematAccountAddRequest request,
            AccountActionType actionType) throws Exception, SmartAPIException;

    ApiResponse<List<DematAccountFetchResponse>> fetchAllBrokerAccounts(boolean amountReq);

    ApiResponse<List<DematAccountFetchResponse>> fetchAccountsByPyId(Long pyId, boolean amtReq);

    ApiResponse<List<DematAccountFetchResponse>> fetchAccountsByPyBrokerId(Long pyId, boolean amtReq);

    Map<String, String> getLatestAccessToken(long pyUserId);

    String getApiKey();

    Order placeIndividualOrder(IndividualOrderRequest request, String transactionType);

    Map<String, List<Map<String, Object>>> getBrokerAccountsGroupedByType(Long pyId);

    JSONObject getOrderHistory(Long accId) throws DeActivatedAccountException;

    ApiResponse<Map<String, List<PyBrokerAccountSummaryDto>>> getBrokerAccountsGrouped(Long pyId);

    // PyBrokerAccountService.java
    JSONObject getPositions(Long accId);

    JSONObject getHoldings(Long accId);

    Order modifyIndividualOrder(ModifyOrderRequest request);

    Order cancelIndividualOrder(CancelOrderRequest request);

    ApiResponse<?> validateIpConfig(String ipAddress, BrokerType brokerType);

    JSONObject getLTP(Long brokerId, String exchange, String tradingSymbol, String symbolToken);

    JSONObject convertPosition(Long accId, ConvertPositionRequest request);

}
