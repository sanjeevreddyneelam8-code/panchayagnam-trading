package com.py.controller;

import com.py.brokers.angel.dto.CancelOrderRequest;
import com.py.brokers.angel.dto.ModifyOrderRequest;
import com.py.brokers.angel.dto.Order;
import com.py.common.dto.ApiResponse;
import com.py.common.enums.AccountActionType;
import com.py.controller.utils.ControllerResponseBuilder;
import com.py.demataccount.dto.DematAccountAddRequest;
import com.py.demataccount.dto.DematAccountFetchResponse;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.demataccount.service.LiveHoldingsWebSocketManager;
import com.py.demataccount.service.PyBrokerAccountService;
import com.py.dto.ConvertPositionRequest;
import com.py.dto.PyBrokerAccountSummaryDto;
import com.py.easytrade.dto.IndividualOrderRequest;
import com.py.entity.PyUser;
import com.py.repo.PyUserRepository;
import com.py.tokenrefresh.repository.TokenRefreshAuditRepository;
import com.py.brokers.motilal.repository.MotilalTokenRefreshAuditRepository;
import com.py.trading.service.OrderIdempotencyService;
import com.py.trading.service.PaperTradingEngine;
import org.json.JSONObject;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.Collections;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class PyBrokerControllerOwnershipTest {

    @Mock
    private PyBrokerAccountService pyBrokerAccountService;

    @Mock
    private TokenRefreshAuditRepository tokenRefreshAuditRepository;

    @Mock
    private MotilalTokenRefreshAuditRepository motilalTokenRefreshAuditRepository;

    @Mock
    private LiveHoldingsWebSocketManager liveHoldingsWebSocketManager;

    @Spy
    private ControllerResponseBuilder responseBuilder = new ControllerResponseBuilder();

    @Mock
    private OrderIdempotencyService orderIdempotencyService;

    @Mock
    private PaperTradingEngine paperTradingEngine;

    @Mock
    private PyUserRepository pyUserRepository;

    @Mock
    private PyBrokerAccountRepository pyBrokerAccountRepository;

    @InjectMocks
    private PyBrokerController pyBrokerController;

    private PyUser userA;
    private PyUser userB;
    private PyUser superAdmin;
    private PyBrokerAccountEntity accountA;

    @BeforeEach
    void setUp() {
        SecurityContextHolder.clearContext();

        userA = new PyUser();
        userA.setId(101L);
        userA.setPhoneNumber("9000000001");
        userA.setRole(PyUser.Role.USER);

        userB = new PyUser();
        userB.setId(102L);
        userB.setPhoneNumber("9000000002");
        userB.setRole(PyUser.Role.USER);

        superAdmin = new PyUser();
        superAdmin.setId(999L);
        superAdmin.setPhoneNumber("9999999999");
        superAdmin.setRole(PyUser.Role.SUPER_ADMIN);

        accountA = new PyBrokerAccountEntity();
        accountA.setId(201L);
        accountA.setPyUser(userA);
        accountA.setClientId("ANGEL_201");
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    private void authenticateAs(PyUser user) {
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                user.getPhoneNumber(), null, Collections.emptyList());
        SecurityContextHolder.getContext().setAuthentication(auth);
        lenient().when(pyUserRepository.findByPhoneNumber(user.getPhoneNumber())).thenReturn(Optional.of(user));
        lenient().when(pyUserRepository.findById(user.getId())).thenReturn(Optional.of(user));
    }

    @Test
    @DisplayName("Paper Balance Ownership: User B accessing User A account returns 403 Forbidden")
    void testPaperBalanceCrossUserForbidden() {
        authenticateAs(userB);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        ResponseEntity<?> response = pyBrokerController.getPaperBalance(201L);

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(paperTradingEngine, never()).getOrCreateBalance(anyLong(), anyLong());
    }

    @Test
    @DisplayName("Paper Balance Ownership: Account Owner (User A) successfully accesses paper balance")
    void testPaperBalanceOwnerAllowed() {
        authenticateAs(userA);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        ResponseEntity<?> response = pyBrokerController.getPaperBalance(201L);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(paperTradingEngine).getOrCreateBalance(101L, 201L);
    }

    @Test
    @DisplayName("Paper Balance Ownership: SUPER_ADMIN successfully accesses any user account")
    void testPaperBalanceSuperAdminAllowed() {
        authenticateAs(superAdmin);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        ResponseEntity<?> response = pyBrokerController.getPaperBalance(201L);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(paperTradingEngine).getOrCreateBalance(999L, 201L);
    }

    @Test
    @DisplayName("Paper Positions Ownership: User B accessing User A positions returns 403 Forbidden")
    void testPaperPositionsCrossUserForbidden() {
        authenticateAs(userB);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        ResponseEntity<?> response = pyBrokerController.getPaperPositions(201L);

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(paperTradingEngine, never()).getPositions(anyLong());
    }

    @Test
    @DisplayName("Order History Ownership: User B accessing User A order history returns 403 Forbidden")
    void testOrderHistoryCrossUserForbidden() throws Exception {
        authenticateAs(userB);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        ResponseEntity<?> response = pyBrokerController.getOrderHistory(201L);

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(pyBrokerAccountService, never()).getOrderHistory(anyLong());
    }

    @Test
    @DisplayName("Modify Order Ownership: User B modifying User A order returns 403 Forbidden")
    void testModifyOrderCrossUserForbidden() {
        authenticateAs(userB);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        ModifyOrderRequest request = new ModifyOrderRequest();
        request.setAccId(201L);
        request.setOrderId("PAPER-SIM-12345");
        request.setPrice(150.0);
        request.setQuantity(10);

        ResponseEntity<ApiResponse<Order>> response = pyBrokerController.modifyOrder(request);

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(pyBrokerAccountService, never()).modifyIndividualOrder(any());
    }

    @Test
    @DisplayName("Modify Order: Owner modifies order successfully")
    void testModifyOrderOwnerAllowed() {
        authenticateAs(userA);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        ModifyOrderRequest request = new ModifyOrderRequest();
        request.setAccId(201L);
        request.setOrderId("ORDER-001");
        request.setPrice(155.0);
        request.setQuantity(20);

        Order expectedOrder = new Order();
        expectedOrder.orderId = "ORDER-001";
        when(pyBrokerAccountService.modifyIndividualOrder(request)).thenReturn(expectedOrder);

        ResponseEntity<ApiResponse<Order>> response = pyBrokerController.modifyOrder(request);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals("ORDER-001", response.getBody().getData().orderId);
    }

    @Test
    @DisplayName("Modify Order: IllegalStateException (filled simulated order) returns 400 Bad Request")
    void testModifyOrderValidationErrorReturns400() {
        authenticateAs(userA);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        ModifyOrderRequest request = new ModifyOrderRequest();
        request.setAccId(201L);
        request.setOrderId("PAPER-SIM-FILLED");

        when(pyBrokerAccountService.modifyIndividualOrder(request))
                .thenThrow(new IllegalStateException("Cannot modify order: simulated order is already executed / filled"));

        ResponseEntity<ApiResponse<Order>> response = pyBrokerController.modifyOrder(request);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertTrue(response.getBody().getMessage().contains("already executed / filled"));
    }

    @Test
    @DisplayName("Cancel Order Ownership: User B cancelling User A order returns 403 Forbidden")
    void testCancelOrderCrossUserForbidden() {
        authenticateAs(userB);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        CancelOrderRequest request = new CancelOrderRequest();
        request.setAccId(201L);
        request.setOrderId("PAPER-SIM-12345");

        ResponseEntity<ApiResponse<Order>> response = pyBrokerController.cancelOrder(request);

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(pyBrokerAccountService, never()).cancelIndividualOrder(any());
    }

    @Test
    @DisplayName("Cancel Order: Owner cancels order successfully")
    void testCancelOrderOwnerAllowed() {
        authenticateAs(userA);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        CancelOrderRequest request = new CancelOrderRequest();
        request.setAccId(201L);
        request.setOrderId("ORDER-002");

        Order expectedOrder = new Order();
        expectedOrder.orderId = "ORDER-002";
        when(pyBrokerAccountService.cancelIndividualOrder(request)).thenReturn(expectedOrder);

        ResponseEntity<ApiResponse<Order>> response = pyBrokerController.cancelOrder(request);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals("ORDER-002", response.getBody().getData().orderId);
    }

    @Test
    @DisplayName("Cancel Order: IllegalStateException returns 400 Bad Request")
    void testCancelOrderValidationErrorReturns400() {
        authenticateAs(userA);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        CancelOrderRequest request = new CancelOrderRequest();
        request.setAccId(201L);
        request.setOrderId("PAPER-SIM-FILLED");

        when(pyBrokerAccountService.cancelIndividualOrder(request))
                .thenThrow(new IllegalStateException("Cannot cancel order: simulated order is already executed / filled"));

        ResponseEntity<ApiResponse<Order>> response = pyBrokerController.cancelOrder(request);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertTrue(response.getBody().getMessage().contains("already executed / filled"));
    }

    @Test
    @DisplayName("Positions Ownership: User B fetching User A positions returns 403 Forbidden")
    void testGetPositionsCrossUserForbidden() {
        authenticateAs(userB);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        ResponseEntity<?> response = pyBrokerController.getPositions(201L);

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(pyBrokerAccountService, never()).getPositions(anyLong());
    }

    @Test
    @DisplayName("Convert Position Ownership: User B converting positions on User A account returns 403 Forbidden")
    void testConvertPositionCrossUserForbidden() {
        authenticateAs(userB);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        ConvertPositionRequest request = new ConvertPositionRequest();
        request.setAccId(201L);
        request.setTradingsymbol("SBIN-EQ");

        ResponseEntity<?> response = pyBrokerController.convertPosition(request);

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(pyBrokerAccountService, never()).convertPosition(anyLong(), any());
    }

    @Test
    @DisplayName("Buy Order Ownership: User B placing buy order on User A account returns 403 Forbidden")
    void testBuyOrderCrossUserForbidden() {
        authenticateAs(userB);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        IndividualOrderRequest request = new IndividualOrderRequest();
        request.setAccId(201L);
        request.setTradingSymbol("TCS-EQ");
        request.setQuantity(10);
        request.setPrice(3500.0);

        ResponseEntity<?> response = pyBrokerController.placeIndividualBuy(request, "TEST-IDEMP-KEY-1");

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verifyNoInteractions(orderIdempotencyService);
        verify(pyBrokerAccountService, never()).placeIndividualOrder(any(), any());
    }

    @Test
    @DisplayName("Sell Order Ownership: User B placing sell order on User A account returns 403 Forbidden")
    void testSellOrderCrossUserForbidden() {
        authenticateAs(userB);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        IndividualOrderRequest request = new IndividualOrderRequest();
        request.setAccId(201L);
        request.setTradingSymbol("TCS-EQ");
        request.setQuantity(10);
        request.setPrice(3500.0);

        ResponseEntity<?> response = pyBrokerController.placeIndividualSell(request, "TEST-IDEMP-KEY-2");

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verifyNoInteractions(orderIdempotencyService);
        verify(pyBrokerAccountService, never()).placeIndividualOrder(any(), any());
    }

    @Test
    @DisplayName("Account Operations Ownership: User B managing account for User A returns 403 Forbidden")
    void testDematAccountOperationsCrossUserForbidden() throws Throwable {
        authenticateAs(userB);

        DematAccountAddRequest request = new DematAccountAddRequest();
        request.setPyUserId(userA.getId()); // User A's ID
        request.setClientId("A12345");

        ResponseEntity<?> response = pyBrokerController.dematAccountOperations(request, AccountActionType.ADD);

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(pyBrokerAccountService, never()).dematAccountOperations(any(), any());
    }

    @Test
    @DisplayName("Fetch Accounts Ownership: User B fetching accounts for User A returns 403 Forbidden")
    void testFetchAccountsByPyIdCrossUserForbidden() {
        authenticateAs(userB);

        ResponseEntity<ApiResponse<java.util.List<DematAccountFetchResponse>>> response =
                pyBrokerController.fetchAccountsByPyId(userA.getId());

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(pyBrokerAccountService, never()).fetchAccountsByPyId(anyLong(), anyBoolean());
    }

    @Test
    @DisplayName("Fetch Account Details Ownership: User B fetching User A account with balance returns 403 Forbidden")
    void testFetchAccountByPyBrokerIdCrossUserForbidden() {
        authenticateAs(userB);
        when(pyBrokerAccountRepository.findById(201L)).thenReturn(Optional.of(accountA));

        ResponseEntity<ApiResponse<java.util.List<DematAccountFetchResponse>>> response =
                pyBrokerController.fetchAccountByPyBrokerId(201L);

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(pyBrokerAccountService, never()).fetchAccountsByPyBrokerId(anyLong(), anyBoolean());
    }

    @Test
    @DisplayName("Grouped Accounts Ownership: User B fetching grouped accounts for User A returns 403 Forbidden")
    void testGetBrokerAccountsGroupedCrossUserForbidden() {
        authenticateAs(userB);

        ResponseEntity<ApiResponse<java.util.Map<String, java.util.List<PyBrokerAccountSummaryDto>>>> response =
                pyBrokerController.getBrokerAccountsGrouped(userA.getId());

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(pyBrokerAccountService, never()).getBrokerAccountsGrouped(anyLong());
    }

    @Test
    @DisplayName("Delete Account Ownership: Owner can successfully delete their own broker account")
    void testDematAccountOperationsDeleteAllowedForOwner() throws Throwable {
        authenticateAs(userA);

        DematAccountAddRequest request = new DematAccountAddRequest();
        request.setPyUserId(userA.getId());
        request.setClientId(accountA.getClientId());

        when(pyBrokerAccountRepository.findByClientId(accountA.getClientId())).thenReturn(Optional.of(accountA));
        when(pyBrokerAccountService.dematAccountOperations(request, AccountActionType.DELETE))
                .thenReturn(ApiResponse.success("Broker account deleted successfully", null));

        ResponseEntity<?> response = pyBrokerController.dematAccountOperations(request, AccountActionType.DELETE);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(pyBrokerAccountService, times(1)).dematAccountOperations(request, AccountActionType.DELETE);
    }

    @Test
    @DisplayName("Delete Account Ownership: User B attempting to delete User A's account via pyUserId mismatch returns 403 Forbidden")
    void testDematAccountOperationsDeleteCrossUserForbidden() throws Throwable {
        authenticateAs(userB);

        DematAccountAddRequest request = new DematAccountAddRequest();
        request.setPyUserId(userA.getId());
        request.setClientId("A12345");

        ResponseEntity<?> response = pyBrokerController.dematAccountOperations(request, AccountActionType.DELETE);

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(pyBrokerAccountService, never()).dematAccountOperations(any(), any());
    }

    @Test
    @DisplayName("Delete Account Ownership: User B targeting User A's clientId returns 403 Forbidden")
    void testDematAccountOperationsDeleteTargetAccountBelongsToOtherUserForbidden() throws Throwable {
        authenticateAs(userB);

        DematAccountAddRequest request = new DematAccountAddRequest();
        request.setPyUserId(userB.getId());
        request.setClientId(accountA.getClientId());

        when(pyBrokerAccountRepository.findByClientId(accountA.getClientId())).thenReturn(Optional.of(accountA));

        ResponseEntity<?> response = pyBrokerController.dematAccountOperations(request, AccountActionType.DELETE);

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(pyBrokerAccountService, never()).dematAccountOperations(any(), any());
    }
}
