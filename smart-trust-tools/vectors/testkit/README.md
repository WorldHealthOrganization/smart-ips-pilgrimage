# Test PKI (TEST ONLY)

Throw-away keys and self-signed DSCs for the library's own tests. They are on
no trust list and must never be used outside tests. [STT-ISS-003]

| File | Key | EKU |
|---|---|---|
| `es256-key.pem`, `es256-dsc.pem` | P-256 (ES256) | 1.3.6.1.4.1.1847.2021.1.2 (vaccinations) |
| `ps256-key.pem`, `ps256-dsc-test-eku.pem` | RSA 2048 (PS256) | 1.3.6.1.4.1.1847.2021.1.1 (test) |

Generated with `openssl` from `openssl.cnf`, valid ten years from 2026-10-20.
