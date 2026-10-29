package com.py.crypto;

import com.py.common.enums.BrokerType;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.entity.PyBrokerSecret;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.demataccount.repository.PyBrokerSecretRepository;
import com.py.entity.PyUser;
import com.py.repo.PyUserRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Base64;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration test suite verifying transparent AES-256-GCM encryption of broker secrets
 * against a real in-memory H2 relational database.
 *
 * Tests:
 * 1. Database ciphertext verification via direct JDBC query (bypassing JPA converter).
 * 2. Transparent decryption on JPA repository reads.
 * 3. Strict mode rejection of plaintext writes when key is missing and compatibility is disabled.
 * 4. Persistence across persistence-context clear (simulating fresh entity retrieval).
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("h2")
@Import({CryptoService.class, EncryptedStringConverter.class})
@EntityScan(basePackages = {"com.py.demataccount.entity", "com.py.entity"})
@EnableJpaRepositories(basePackages = {"com.py.demataccount.repository", "com.py.repo"})
@TestPropertySource(properties = {
        "app.crypto.broker-encryption-key=MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDE=",
        "app.crypto.allow-legacy-plaintext=true"
})
public class PyBrokerSecretEncryptionIntegrationTest {

    private static final String SYNTHETIC_TEST_KEY_BASE64 = "MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDE=";

    @Autowired
    private PyUserRepository userRepository;

    @Autowired
    private PyBrokerAccountRepository accountRepository;

    @Autowired
    private PyBrokerSecretRepository secretRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private EntityManager entityManager;

    @Autowired
    private CryptoService cryptoService;

    @Test
    @Transactional
    @DisplayName("Verify raw database columns hold 'v1:' ciphertext and JPA transparently decrypts")
    void testRawDatabaseCiphertextAndJpaDecryption() {
        // ── 1. Create and persist parent User and BrokerAccount entities ───────
        PyUser user = new PyUser();
        user.setFullName("Integration Test User");
        user.setEmail("integration.test@panchayagnam.com");
        user.setPhoneNumber("9999988888");
        user.setMpin("$2a$10$dummyBcryptHashForTestPurposesOnly");
        user.setIsPhoneVerified(true);
        user.setRole(PyUser.Role.USER);
        user.setIsActive(true);
        user = userRepository.saveAndFlush(user);

        PyBrokerAccountEntity account = new PyBrokerAccountEntity();
        account.setClientId("TEST_INTEG_001");
        account.setUserName("Test Broker Account");
        account.setBrokerType(BrokerType.ANGELONE);
        account.setActive(true);
        account.setCreatedAt(LocalDateTime.now());
        account.setPyUser(user);
        account = accountRepository.saveAndFlush(account);

        // ── 2. Create and persist PyBrokerSecret with known plaintexts ─────────
        String plainApiKey = "synthetic_api_key_ABC123";
        String plainApiSecret = "synthetic_api_secret_XYZ789";
        String plainPassword = "synthetic_mpin_9911";
        String plainTotp = "JBSWY3DPEHPK3PXP";
        String plainTwoFa = "1992-05-15";
        String plainMobile = "9999988888";

        PyBrokerSecret secret = new PyBrokerSecret();
        secret.setBrokerAccount(account);
        secret.setApiKey(plainApiKey);
        secret.setApiSecret(plainApiSecret);
        secret.setPassword(plainPassword);
        secret.setTotpSecret(plainTotp);
        secret.setTwoFa(plainTwoFa);
        secret.setMobileNo(plainMobile);
        secret.setVenderInfo("TEST_VENDOR");
        secret.setAppId("TEST_APP_ID");
        secret.setIsActive(true);

        PyBrokerSecret savedSecret = secretRepository.saveAndFlush(secret);
        Long secretId = savedSecret.getId();
        assertNotNull(secretId, "Saved secret entity must have a generated ID");

        // ── 3. Raw JDBC Query: verify database columns hold 'v1:' ciphertext ───
        Map<String, Object> rawRow = jdbcTemplate.queryForMap(
                "SELECT api_key, api_secret, password, totp_secret, DOB, Mobile, app_id, vender_info "
                        + "FROM py_broker_secret_table WHERE id = ?", secretId);

        String rawDbApiKey = (String) rawRow.get("api_key");
        String rawDbApiSecret = (String) rawRow.get("api_secret");
        String rawDbPassword = (String) rawRow.get("password");
        String rawDbTotp = (String) rawRow.get("totp_secret");
        String rawDbTwoFa = (String) rawRow.get("DOB");
        String rawDbMobile = (String) rawRow.get("Mobile");
        String rawDbAppId = (String) rawRow.get("app_id");
        String rawDbVendorInfo = (String) rawRow.get("vender_info");

        // Assert all 6 sensitive fields are encrypted with "v1:" prefix
        assertTrue(rawDbApiKey.startsWith("v1:"), "Raw api_key column must start with 'v1:'");
        assertTrue(rawDbApiSecret.startsWith("v1:"), "Raw api_secret column must start with 'v1:'");
        assertTrue(rawDbPassword.startsWith("v1:"), "Raw password column must start with 'v1:'");
        assertTrue(rawDbTotp.startsWith("v1:"), "Raw totp_secret column must start with 'v1:'");
        assertTrue(rawDbTwoFa.startsWith("v1:"), "Raw DOB column must start with 'v1:'");
        assertTrue(rawDbMobile.startsWith("v1:"), "Raw Mobile column must start with 'v1:'");

        // Assert raw database columns do NOT contain any plaintext values
        assertNotEquals(plainApiKey, rawDbApiKey);
        assertNotEquals(plainApiSecret, rawDbApiSecret);
        assertNotEquals(plainPassword, rawDbPassword);
        assertNotEquals(plainTotp, rawDbTotp);
        assertFalse(rawDbApiKey.contains(plainApiKey));
        assertFalse(rawDbPassword.contains(plainPassword));

        // Assert non-sensitive fields remain unencrypted plaintext
        assertEquals("TEST_APP_ID", rawDbAppId, "Non-sensitive app_id must remain unencrypted");
        assertEquals("TEST_VENDOR", rawDbVendorInfo, "Non-sensitive vender_info must remain unencrypted");

        // ── 4. Clear Hibernate persistence context (simulating fresh load) ─────
        entityManager.clear();

        // ── 5. JPA Read: verify transparent decryption returns original values ─
        PyBrokerSecret retrieved = secretRepository.findById(secretId).orElseThrow(
                () -> new AssertionError("Secret entity must be found by ID: " + secretId));

        assertEquals(plainApiKey, retrieved.getApiKey(), "JPA read must transparently decrypt api_key");
        assertEquals(plainApiSecret, retrieved.getApiSecret(), "JPA read must transparently decrypt api_secret");
        assertEquals(plainPassword, retrieved.getPassword(), "JPA read must transparently decrypt password");
        assertEquals(plainTotp, retrieved.getTotpSecret(), "JPA read must transparently decrypt totp_secret");
        assertEquals(plainTwoFa, retrieved.getTwoFa(), "JPA read must transparently decrypt DOB / twoFa");
        assertEquals(plainMobile, retrieved.getMobileNo(), "JPA read must transparently decrypt Mobile");
    }

    @Test
    @DisplayName("Verify strict mode rejects unencrypted writes when key is missing")
    void testStrictModeRejectionWhenKeyMissing() {
        CryptoService strictService = new CryptoService();
        strictService.setAllowLegacyPlaintext(false);
        // Do not call initKey() — simulate missing BROKER_ENCRYPTION_KEY in strict mode

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> strictService.encrypt("confidential_credential_value"),
                "Strict mode must throw IllegalStateException if BROKER_ENCRYPTION_KEY is unset");

        assertTrue(ex.getMessage().contains("BROKER_ENCRYPTION_KEY is not configured"),
                "Exception message must specify that key is not configured");
    }

    @Test
    @DisplayName("Verify persisted ciphertext can be decrypted after restart simulation")
    void testDecryptionAcrossPersistenceContextRestart() {
        // Step A: Encrypt with initial service instance
        String originalToken = "sample_jwt_access_token_header.payload.signature_xyz";
        String ciphertext = cryptoService.encrypt(originalToken);
        assertTrue(ciphertext.startsWith("v1:"));

        // Step B: Simulate application restart by creating a completely fresh CryptoService
        // instance initialized with the exact same master key
        CryptoService restartedService = new CryptoService();
        restartedService.setAllowLegacyPlaintext(true);
        restartedService.initKey(SYNTHETIC_TEST_KEY_BASE64);

        // Step C: Decrypt with the restarted service instance
        String decryptedAfterRestart = restartedService.decrypt(ciphertext);
        assertEquals(originalToken, decryptedAfterRestart,
                "Restarted CryptoService must cleanly decrypt ciphertext produced by previous instance");
    }
}
