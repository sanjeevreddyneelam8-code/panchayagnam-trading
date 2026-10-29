package com.py.crypto;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Authenticated AES-256-GCM encryption service for broker credentials and tokens.
 *
 * Format: "v1:" + Base64(12-byte IV + Ciphertext + 16-byte GCM Authentication Tag)
 *
 * Safeguards:
 * - Unique 12-byte random IV per encryption operation via SecureRandom.
 * - 128-bit GCM authentication tag guarantees tamper detection.
 * - Dual-read legacy fallback prevents crashing on unmigrated database rows when allowLegacyPlaintext is true.
 * - Startup validation verifies key length (32 bytes / 256 bits) when configured.
 */
@Service
public class CryptoService {

    private static final Logger log = LoggerFactory.getLogger(CryptoService.class);

    public static final String VERSION_PREFIX = "v1:";
    private static final String ALGORITHM = "AES/GCM/NoPadding";
    private static final int GCM_TAG_LENGTH_BITS = 128;
    private static final int IV_LENGTH_BYTES = 12;
    private static final int KEY_LENGTH_BYTES = 32; // 256 bits

    private final SecureRandom secureRandom = new SecureRandom();
    private final AtomicBoolean keyMissingWarningLogged = new AtomicBoolean(false);

    @Value("${app.crypto.broker-encryption-key:}")
    private String encryptionKeyBase64;

    @Value("${app.crypto.allow-legacy-plaintext:true}")
    private boolean allowLegacyPlaintext;

    private SecretKey secretKey;

    @PostConstruct
    public void init() {
        if (encryptionKeyBase64 != null && !encryptionKeyBase64.trim().isEmpty()) {
            initKey(encryptionKeyBase64.trim());
            log.info("[SECURITY] CryptoService initialized with authenticated AES-256-GCM encryption.");
        } else {
            if (allowLegacyPlaintext) {
                log.warn("[SECURITY AUDIT] BROKER_ENCRYPTION_KEY is unset. Legacy plaintext compatibility mode is active. "
                        + "New writes will not be encrypted until BROKER_ENCRYPTION_KEY is configured.");
            } else {
                throw new IllegalStateException("[SECURITY] BROKER_ENCRYPTION_KEY must be configured when strict mode is active "
                        + "(app.crypto.allow-legacy-plaintext=false). Application startup halted.");
            }
        }
    }

    /**
     * Initializes the secret key from a Base64-encoded 256-bit key string.
     */
    public synchronized void initKey(String keyBase64) {
        byte[] keyBytes;
        try {
            keyBytes = Base64.getDecoder().decode(keyBase64);
        } catch (IllegalArgumentException e) {
            throw new IllegalStateException("[SECURITY] BROKER_ENCRYPTION_KEY is not a valid Base64 string.", e);
        }

        if (keyBytes.length != KEY_LENGTH_BYTES) {
            throw new IllegalStateException(String.format(
                    "[SECURITY] BROKER_ENCRYPTION_KEY must be exactly %d bytes (256 bits), found %d bytes.",
                    KEY_LENGTH_BYTES, keyBytes.length));
        }

        this.secretKey = new SecretKeySpec(keyBytes, "AES");
    }

    /**
     * Encrypts plaintext using AES-256-GCM.
     * Returns "v1:" + Base64(IV + Ciphertext + Tag).
     *
     * @param plaintext raw sensitive credential
     * @return versioned ciphertext, or original input if null/empty or if key is unconfigured during transition
     */
    public String encrypt(String plaintext) {
        if (plaintext == null || plaintext.isEmpty()) {
            return plaintext;
        }

        // Avoid double-encryption
        if (plaintext.startsWith(VERSION_PREFIX)) {
            return plaintext;
        }

        // Failsafe: if key is unset during transition window and legacy plaintext is allowed
        if (secretKey == null) {
            if (allowLegacyPlaintext) {
                if (keyMissingWarningLogged.compareAndSet(false, true)) {
                    log.warn("[SECURITY WARNING] Writing unencrypted broker credential to database because BROKER_ENCRYPTION_KEY is unset! "
                            + "Plaintext fallback is active for compatibility, but unencrypted storage is INSECURE. "
                            + "Configure BROKER_ENCRYPTION_KEY immediately to enable AES-256-GCM encryption.");
                }
                return plaintext;
            } else {
                throw new IllegalStateException("[SECURITY] Cannot encrypt: BROKER_ENCRYPTION_KEY is not configured.");
            }
        }

        try {
            byte[] iv = new byte[IV_LENGTH_BYTES];
            secureRandom.nextBytes(iv);

            Cipher cipher = Cipher.getInstance(ALGORITHM);
            GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv);
            cipher.init(Cipher.ENCRYPT_MODE, secretKey, parameterSpec);

            byte[] cipherTextWithTag = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));

            byte[] combined = new byte[iv.length + cipherTextWithTag.length];
            System.arraycopy(iv, 0, combined, 0, iv.length);
            System.arraycopy(cipherTextWithTag, 0, combined, iv.length, cipherTextWithTag.length);

            return VERSION_PREFIX + Base64.getEncoder().encodeToString(combined);
        } catch (Exception e) {
            log.error("[SECURITY] Encryption failed: {}", e.getMessage());
            throw new RuntimeException("Encryption operation failed", e);
        }
    }

    /**
     * Decrypts ciphertext if prefixed with "v1:".
     * If unencrypted, handles according to allowLegacyPlaintext flag.
     *
     * @param storedValue value read from database
     * @return decrypted plaintext string
     */
    public String decrypt(String storedValue) {
        if (storedValue == null || storedValue.isEmpty()) {
            return storedValue;
        }

        if (storedValue.startsWith(VERSION_PREFIX)) {
            if (secretKey == null) {
                throw new IllegalStateException("[SECURITY] Cannot decrypt 'v1:' ciphertext: BROKER_ENCRYPTION_KEY is not configured.");
            }

            try {
                String base64Payload = storedValue.substring(VERSION_PREFIX.length());
                byte[] combined = Base64.getDecoder().decode(base64Payload);

                if (combined.length < IV_LENGTH_BYTES + (GCM_TAG_LENGTH_BITS / 8)) {
                    throw new IllegalArgumentException("[SECURITY] Ciphertext payload is too short to contain valid IV and GCM tag.");
                }

                byte[] iv = new byte[IV_LENGTH_BYTES];
                System.arraycopy(combined, 0, iv, 0, IV_LENGTH_BYTES);

                int cipherTextLength = combined.length - IV_LENGTH_BYTES;
                byte[] cipherTextWithTag = new byte[cipherTextLength];
                System.arraycopy(combined, IV_LENGTH_BYTES, cipherTextWithTag, 0, cipherTextLength);

                Cipher cipher = Cipher.getInstance(ALGORITHM);
                GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv);
                cipher.init(Cipher.DECRYPT_MODE, secretKey, parameterSpec);

                byte[] plainBytes = cipher.doFinal(cipherTextWithTag);
                return new String(plainBytes, StandardCharsets.UTF_8);
            } catch (Exception e) {
                log.error("[SECURITY] Decryption failed or ciphertext was tampered with: {}", e.getMessage());
                throw new RuntimeException("Decryption operation failed — invalid key or tampered ciphertext", e);
            }
        }

        // Legacy plaintext record (does NOT start with v1:)
        if (allowLegacyPlaintext) {
            return storedValue;
        } else {
            throw new SecurityException("[SECURITY] Legacy unencrypted credential rejected in strict security mode. "
                    + "Please execute credential migration.");
        }
    }

    public boolean isConfigured() {
        return secretKey != null;
    }

    public boolean isAllowLegacyPlaintext() {
        return allowLegacyPlaintext;
    }

    public boolean isKeyMissingWarningLogged() {
        return keyMissingWarningLogged.get();
    }

    public void setAllowLegacyPlaintext(boolean allowLegacyPlaintext) {
        this.allowLegacyPlaintext = allowLegacyPlaintext;
    }
}
