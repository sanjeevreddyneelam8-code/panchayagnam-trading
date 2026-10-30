package com.py.crypto;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Base64;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit test suite for CryptoService and EncryptedStringConverter (AES-256-GCM).
 *
 * Uses a synthetic 32-byte test key fixture strictly scoped to this test class.
 * Never uses or logs production secrets.
 */
public class CryptoServiceTest {

    // 32-byte synthetic test key encoded in Base64 (strictly for unit test assertions)
    private static final String SYNTHETIC_TEST_KEY_BASE64 = Base64.getEncoder().encodeToString(
            "01234567890123456789012345678901".getBytes());

    private CryptoService cryptoService;

    @BeforeEach
    public void setUp() {
        cryptoService = new CryptoService();
        cryptoService.setAllowLegacyPlaintext(true);
        cryptoService.initKey(SYNTHETIC_TEST_KEY_BASE64);
        EncryptedStringConverter.setStaticCryptoService(cryptoService);
    }

    // ── Test 1: Encryption with a valid key still works ──────────────────────────
    @Test
    public void testEncryptionWithValidKeyWorks() {
        String originalSecret = "mySecretMpin_12345";
        String encrypted = cryptoService.encrypt(originalSecret);

        assertNotNull(encrypted);
        assertTrue(encrypted.startsWith("v1:"), "Encrypted ciphertext must begin with 'v1:' version prefix");
        assertNotEquals(originalSecret, encrypted);

        String decrypted = cryptoService.decrypt(encrypted);
        assertEquals(originalSecret, decrypted, "Decrypted value must exactly match the original secret");
    }

    @Test
    public void testIvRandomness() {
        String secret = "identical_password_value";
        String encrypted1 = cryptoService.encrypt(secret);
        String encrypted2 = cryptoService.encrypt(secret);

        assertNotEquals(encrypted1, encrypted2, "Two encryptions of the same plaintext must produce different ciphertexts due to random IV");
        assertEquals(secret, cryptoService.decrypt(encrypted1));
        assertEquals(secret, cryptoService.decrypt(encrypted2));
    }

    @Test
    public void testTamperDetection() {
        String secret = "confidential_totp_seed";
        String encrypted = cryptoService.encrypt(secret);

        // Tamper with the ciphertext (flip a character in the Base64 payload, away from trailing padding)
        int tamperIdx = encrypted.indexOf(':') + 5;
        char originalChar = encrypted.charAt(tamperIdx);
        char tamperedChar = (originalChar == 'A') ? 'B' : 'A';
        String tamperedCiphertext = encrypted.substring(0, tamperIdx) + tamperedChar + encrypted.substring(tamperIdx + 1);

        assertThrows(RuntimeException.class, () -> cryptoService.decrypt(tamperedCiphertext),
                "Decryption must throw an exception when the GCM authentication tag fails due to tampering");
    }

    // ── Test 2: Encrypted data with an unavailable CryptoService fails safely ────
    @Test
    public void testEncryptedDataWithUnavailableCryptoServiceFailsSafely() {
        EncryptedStringConverter uninitializedConverter = new EncryptedStringConverter();
        EncryptedStringConverter.setStaticCryptoService(null);

        String ciphertext = "v1:MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDE=";

        // Reading encrypted ciphertext when CryptoService is unavailable must NEVER return ciphertext silently
        IllegalStateException readEx = assertThrows(IllegalStateException.class,
                () -> uninitializedConverter.convertToEntityAttribute(ciphertext),
                "Must throw IllegalStateException when attempting to decrypt with uninitialized CryptoService");
        assertTrue(readEx.getMessage().contains("Cannot decrypt"));

        // Writing when CryptoService is unavailable must NEVER write unencrypted data silently
        IllegalStateException writeEx = assertThrows(IllegalStateException.class,
                () -> uninitializedConverter.convertToDatabaseColumn("new_secret"),
                "Must throw IllegalStateException when attempting to encrypt with uninitialized CryptoService");
        assertTrue(writeEx.getMessage().contains("Cannot encrypt"));
    }

    // ── Test 3: Legacy plaintext remains readable when compatibility is enabled ──
    @Test
    public void testLegacyPlaintextReadableWhenCompatibilityEnabled() {
        cryptoService.setAllowLegacyPlaintext(true);
        String legacyPlaintext = "raw_legacy_unencrypted_secret";

        // Direct service read
        String serviceResult = cryptoService.decrypt(legacyPlaintext);
        assertEquals(legacyPlaintext, serviceResult, "Legacy plaintext must be returned as-is when allowLegacyPlaintext is true");

        // Converter read with CryptoService available
        EncryptedStringConverter converter = new EncryptedStringConverter();
        converter.setCryptoService(cryptoService);
        String converterResult = converter.convertToEntityAttribute(legacyPlaintext);
        assertEquals(legacyPlaintext, converterResult, "Converter must return legacy plaintext when compatibility is active");

        // Converter read even if CryptoService is uninitialized
        EncryptedStringConverter.setStaticCryptoService(null);
        String fallbackResult = converter.convertToEntityAttribute(legacyPlaintext);
        assertEquals(legacyPlaintext, fallbackResult, "Converter must return legacy plaintext even if CryptoService is uninitialized");
    }

    // ── Test 4: Missing encryption key follows configured compatibility policy ──
    @Test
    public void testMissingEncryptionKeyFollowsCompatibilityPolicy() {
        // Policy A: When allowLegacyPlaintext is true (Transition Window)
        CryptoService transitionService = new CryptoService();
        transitionService.setAllowLegacyPlaintext(true);
        assertFalse(transitionService.isKeyMissingWarningLogged(), "Warning should not be logged before any write");
        // encrypt falls back to plaintext with security warning
        assertEquals("secret_password", transitionService.encrypt("secret_password"));
        assertTrue(transitionService.isKeyMissingWarningLogged(), "Warning should be logged on first unencrypted write");
        // subsequent write should still return plaintext and warning logged state remains true
        assertEquals("second_password", transitionService.encrypt("second_password"));
        assertTrue(transitionService.isKeyMissingWarningLogged(), "Warning state remains true without re-logging");
        // legacy plaintext remains readable
        assertEquals("legacy_password", transitionService.decrypt("legacy_password"));
        // but encrypted ciphertext cannot be decrypted without key
        assertThrows(IllegalStateException.class,
                () -> transitionService.decrypt("v1:MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDE="),
                "Decrypting 'v1:' ciphertext without key must throw IllegalStateException");

        // Policy B: When allowLegacyPlaintext is false (Strict Mode)
        CryptoService strictService = new CryptoService();
        strictService.setAllowLegacyPlaintext(false);
        // encrypt throws IllegalStateException
        assertThrows(IllegalStateException.class,
                () -> strictService.encrypt("secret_password"),
                "Encrypting without key in strict mode must throw IllegalStateException");
        // legacy plaintext is rejected with SecurityException
        assertThrows(SecurityException.class,
                () -> strictService.decrypt("legacy_password"),
                "Decrypting plaintext in strict mode must throw SecurityException");
    }

    @Test
    public void testInvalidKeyLengthRejection() {
        CryptoService invalidService = new CryptoService();
        // 16-byte key (AES-128) should be rejected because AES-256 (32 bytes) is required
        String shortKey = Base64.getEncoder().encodeToString("1234567890123456".getBytes());
        assertThrows(IllegalStateException.class, () -> invalidService.initKey(shortKey),
                "Key initialization must throw IllegalStateException if the key is not exactly 32 bytes");
    }

    @Test
    public void testNullAndEmptyHandling() {
        assertNull(cryptoService.encrypt(null));
        assertEquals("", cryptoService.encrypt(""));
        assertNull(cryptoService.decrypt(null));
        assertEquals("", cryptoService.decrypt(""));
    }

    @Test
    public void testEncryptedStringConverterDelegation() {
        EncryptedStringConverter converter = new EncryptedStringConverter();
        converter.setCryptoService(cryptoService);

        String original = "converter_test_secret";
        String dbColumn = converter.convertToDatabaseColumn(original);

        assertTrue(dbColumn.startsWith("v1:"));
        String entityAttr = converter.convertToEntityAttribute(dbColumn);
        assertEquals(original, entityAttr);
    }
}
