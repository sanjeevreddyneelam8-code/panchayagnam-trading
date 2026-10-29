package com.py.crypto;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * JPA Attribute Converter for transparent AES-256-GCM encryption and decryption.
 *
 * Design & Lifecycle:
 * - Implements Jakarta Persistence AttributeConverter<String, String>.
 * - Preserves the single public no-argument constructor required by the JPA specification.
 * - Uses Spring setter injection (@Autowired setCryptoService) to populate the static
 *   service reference across any converter instance instantiated by Hibernate or Spring.
 *
 * Safeguards:
 * - When writing to the database: Converts plaintext to "v1:Base64(...)" ciphertext.
 *   Throws IllegalStateException if CryptoService is not initialized (never silently writes unencrypted data).
 * - When reading from the database: Converts "v1:Base64(...)" ciphertext back to plaintext.
 *   Throws IllegalStateException if encrypted data ("v1:...") is encountered while CryptoService is uninitialized.
 *   Never silently returns raw ciphertext to callers.
 * - When reading legacy plaintext: Safely returns plaintext attribute when compatibility is active.
 */
@Converter
@Component
public class EncryptedStringConverter implements AttributeConverter<String, String> {

    private static final Logger log = LoggerFactory.getLogger(EncryptedStringConverter.class);

    private static CryptoService cryptoService;

    /**
     * Public no-argument constructor required by the JPA specification.
     */
    public EncryptedStringConverter() {
    }

    /**
     * Spring setter injection. Updates the shared static CryptoService reference.
     *
     * @param service the Spring-managed CryptoService bean
     */
    @Autowired
    public void setCryptoService(CryptoService service) {
        EncryptedStringConverter.cryptoService = service;
    }

    /**
     * Static setter strictly for unit testing environments where Spring context is not loaded.
     *
     * @param service test CryptoService fixture or null
     */
    public static void setStaticCryptoService(CryptoService service) {
        EncryptedStringConverter.cryptoService = service;
    }

    @Override
    public String convertToDatabaseColumn(String attribute) {
        if (attribute == null || attribute.isEmpty()) {
            return attribute;
        }

        if (cryptoService == null) {
            throw new IllegalStateException(
                    "[SECURITY] Cannot encrypt broker credential: EncryptedStringConverter is not initialized with CryptoService.");
        }

        return cryptoService.encrypt(attribute);
    }

    @Override
    public String convertToEntityAttribute(String dbData) {
        if (dbData == null || dbData.isEmpty()) {
            return dbData;
        }

        if (cryptoService == null) {
            if (dbData.startsWith(CryptoService.VERSION_PREFIX)) {
                throw new IllegalStateException(
                        "[SECURITY] Cannot decrypt broker credential: EncryptedStringConverter is not initialized with CryptoService. "
                                + "Encrypted ciphertext will not be returned to callers.");
            }
            log.warn("[SECURITY AUDIT] CryptoService is unavailable in EncryptedStringConverter; returning legacy unencrypted attribute.");
            return dbData;
        }

        return cryptoService.decrypt(dbData);
    }
}
