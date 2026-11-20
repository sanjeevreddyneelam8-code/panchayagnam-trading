package com.py.common.config;

import com.py.common.enums.BrokerType;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.entity.PyBrokerSecret;
import com.py.demataccount.entity.PyBrokerToken;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.demataccount.repository.PyBrokerTokenRepository;
import com.py.entity.PyUser;
import com.py.ipconfig.entity.PyBrokerIpConfigEntity;
import com.py.ipconfig.repository.PyBrokerIpConfigRepository;
import com.py.repo.PyUserRepository;
import com.py.trading.entity.PaperAccountBalanceEntity;
import com.py.trading.repository.PaperAccountBalanceRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

/**
 * Initializes test data for isolated local development and demo testing when the 'h2' profile is active.
 * Safe: Runs strictly in-memory (never runs against or touches production data).
 */
@Component
@Profile({"h2", "local", "dev", "default"})
public class DevH2DataInitializer implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DevH2DataInitializer.class);

    @Autowired
    private PyUserRepository pyUserRepository;

    @Autowired
    private PyBrokerIpConfigRepository ipConfigRepository;

    @Autowired
    private PyBrokerAccountRepository brokerAccountRepository;

    @Autowired
    private PyBrokerTokenRepository brokerTokenRepository;

    @Autowired
    private PaperAccountBalanceRepository paperBalanceRepository;

    @Autowired
    private com.py.demataccount.repository.PyTradeGroupRepository tradeGroupRepository;

    @Autowired
    private com.py.demataccount.repository.PyTradeGroupMemberRepository tradeGroupMemberRepository;

    @Autowired
    private BCryptPasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {
        log.info("[H2-DEV] DevH2DataInitializer running: seeding local test data...");

        // 1. Seed registered IP for local broker microservice
        if (ipConfigRepository.findByIpAddress("127.0.0.1").isEmpty()) {
            PyBrokerIpConfigEntity ipEntity = new PyBrokerIpConfigEntity();
            ipEntity.setIpAddress("127.0.0.1");
            ipEntity.setPortNo(8082);
            ipConfigRepository.save(ipEntity);
            log.info("[H2-DEV] Seeded registered broker IP 127.0.0.1:8082 in py_broker_ip_config");
        }

        // 2. Seed default demo test user (Phone: 9999999999, MPIN: 1234)
        PyUser user = pyUserRepository.findByPhoneNumber("9999999999").orElseGet(() -> {
            PyUser newUser = new PyUser();
            newUser.setFullName("Demo Trader");
            newUser.setPhoneNumber("9999999999");
            newUser.setEmail("demo@panchayagnam.com");
            newUser.setMpin(passwordEncoder.encode("1234"));
            newUser.setRole(PyUser.Role.USER);
            newUser.setIsActive(true);
            newUser.setIsPhoneVerified(true);
            return pyUserRepository.save(newUser);
        });
        // Ensure MPIN is encoded for 1234
        user.setMpin(passwordEncoder.encode("1234"));
        pyUserRepository.save(user);
        log.info("[H2-DEV] Seeded demo user with ID: {}, phone: {}", user.getId(), user.getPhoneNumber());

        // Note: Real broker Demat accounts and follower groups are managed dynamically via the UI / CopyTradingEngine.
        // We do not seed mock broker accounts to ensure 100% authentic, user-connected accounts only.
    }

    private void seedBroker(
            PyUser user,
            String clientId,
            String userName,
            BrokerType brokerType,
            boolean isOwn,
            String apiKey,
            String apiSecret,
            String password,
            String totpSecret,
            String twoFa,
            String accessToken,
            String feedToken,
            String refreshToken) {

        PyBrokerAccountEntity account = brokerAccountRepository.findByClientId(clientId).orElseGet(() -> {
            PyBrokerAccountEntity acc = new PyBrokerAccountEntity();
            acc.setClientId(clientId);
            acc.setPyUser(user);
            return acc;
        });

        account.setUserName(userName);
        account.setBrokerType(brokerType);
        account.setActive(true);
        account.setIsOwn(isOwn);
        account.setBrokerRegisteredIp("127.0.0.1:8082");
        account.setLastLoginStatus("SUCCESS");
        account.setLastLoginError(null);
        account.setLastLoginAttempt(LocalDateTime.now().minusMinutes(5));

        // Secret
        PyBrokerSecret secret = account.getSecret();
        if (secret == null) {
            secret = new PyBrokerSecret();
            secret.setBrokerAccount(account);
            account.setSecret(secret);
        }
        secret.setApiKey(apiKey);
        secret.setApiSecret(apiSecret);
        secret.setPassword(password);
        secret.setTotpSecret(totpSecret);
        secret.setTwoFa(twoFa);
        secret.setIsActive(true);

        // Token
        PyBrokerToken token = account.getToken();
        if (token == null) {
            token = new PyBrokerToken();
            token.setBrokerAccount(account);
            account.setToken(token);
        }
        token.setAccessToken(accessToken != null ? accessToken : "PAPER-TOKEN-" + brokerType.name() + "-" + clientId);
        token.setFeedToken(feedToken);
        token.setRefreshToken(refreshToken);
        token.setTokenType("Bearer");
        token.setIsActive(true);
        token.setExpiresAt(LocalDateTime.now().plusYears(10));

        PyBrokerAccountEntity saved = brokerAccountRepository.save(account);

        // Seed virtual balance for paper trading if not already present
        if (paperBalanceRepository.findByPyUserIdAndDematAccountId(user.getId(), saved.getId()).isEmpty()) {
            PaperAccountBalanceEntity balance = new PaperAccountBalanceEntity();
            balance.setPyUserId(user.getId());
            balance.setDematAccountId(saved.getId());
            balance.setVirtualCashBalance(1000000.0);
            balance.setAllocatedMargin(0.0);
            balance.setRealizedPnl(0.0);
            balance.setUnrealizedPnl(0.0);
            balance.setCurrency("INR");
            paperBalanceRepository.save(balance);
        }
    }

    private void seedCopyTradingGroups(PyUser user) {
        java.util.List<PyBrokerAccountEntity> allAccounts = brokerAccountRepository.findByPyUserId(user.getId());
        if (allAccounts == null || allAccounts.isEmpty()) return;

        // Group 1: Master Multi-Broker Copy Pool (All 8 brokers)
        com.py.entity.PyTradeGroupEntity group1 = tradeGroupRepository.findByCreatedByAndIsActive(user, true)
                .stream()
                .filter(g -> "Master Multi-Broker Copy Pool".equals(g.getGroupName()))
                .findFirst()
                .orElseGet(() -> {
                    com.py.entity.PyTradeGroupEntity g = new com.py.entity.PyTradeGroupEntity();
                    g.setGroupName("Master Multi-Broker Copy Pool");
                    g.setDescription("Automated copy trading pool mirroring Master orders simultaneously across all 8 broker accounts (Dhan, Zerodha, Upstox, Angel One, Motilal, Profitmart, Goodwill, Groww).");
                    g.setCreatedBy(user);
                    g.setIsActive(true);
                    return tradeGroupRepository.save(g);
                });

        for (PyBrokerAccountEntity acc : allAccounts) {
            if (!tradeGroupMemberRepository.existsByTradeGroupAndBrokerAccount(group1, acc)) {
                com.py.entity.PyTradeGroupMemberEntity member = new com.py.entity.PyTradeGroupMemberEntity();
                member.setTradeGroup(group1);
                member.setBrokerAccount(acc);
                member.setIsLinked(true);
                tradeGroupMemberRepository.save(member);
            }
        }

        // Group 2: Options Alpha Copy Group (Top 4 brokers)
        com.py.entity.PyTradeGroupEntity group2 = tradeGroupRepository.findByCreatedByAndIsActive(user, true)
                .stream()
                .filter(g -> "Options Alpha Copy Trading Group".equals(g.getGroupName()))
                .findFirst()
                .orElseGet(() -> {
                    com.py.entity.PyTradeGroupEntity g = new com.py.entity.PyTradeGroupEntity();
                    g.setGroupName("Options Alpha Copy Trading Group");
                    g.setDescription("High-probability options copy group with 1:1 risk-parity lot allocation across primary brokers.");
                    g.setCreatedBy(user);
                    g.setIsActive(true);
                    return tradeGroupRepository.save(g);
                });

        for (PyBrokerAccountEntity acc : allAccounts) {
            if (acc.getBrokerType() == BrokerType.DHAN || acc.getBrokerType() == BrokerType.ZERODHA ||
                    acc.getBrokerType() == BrokerType.ANGELONE || acc.getBrokerType() == BrokerType.UPSTOX) {
                if (!tradeGroupMemberRepository.existsByTradeGroupAndBrokerAccount(group2, acc)) {
                    com.py.entity.PyTradeGroupMemberEntity member = new com.py.entity.PyTradeGroupMemberEntity();
                    member.setTradeGroup(group2);
                    member.setBrokerAccount(acc);
                    member.setIsLinked(true);
                    tradeGroupMemberRepository.save(member);
                }
            }
        }
        log.info("[H2-DEV] Seeded Copy Trading Groups with member broker accounts for user {}", user.getId());
    }
}
