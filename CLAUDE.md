# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ACSM Input Plugin for Calibre — converts ACSM files (Adobe Content Server Message) into EPUB/PDF without Adobe Digital Editions. A full Python reimplementation of the C++ libgourou library. Supports Python 2.7 through 3.14 for compatibility with older Calibre versions.

## Build Commands

```bash
# Download vendored dependencies (asn1crypto, oscrypto fork)
./package_modules.sh

# Build the main plugin ZIP (calibre-plugin.zip)
# Requires MinGW cross-compiler for Windows key extraction binaries
./bundle_calibre_plugin.sh

# Build the migration plugin ZIP (calibre-migration-plugin.zip)
./bundle_migration_plugin.sh
```

The build script (`bundle_calibre_plugin.sh`) does several transformations: compiles C key-extraction binaries via MinGW, base64-encodes them into `keyextractDecryptor.py`, injects Python 2 compatibility code from `__calibre_compat_code.py` into all `.py` files, and packages everything into a ZIP.

## Running Tests

```bash
cd tests && python main.py
```

Tests use `unittest` with `freezegun` for time mocking. Test dependencies are listed in `.github/workflows/ci_test_requirements.txt`:
- freezegun, lxml, pycryptodome, rsa, oscrypto, cryptography>=3.1

CI tests across Python 2.7–3.14 on Linux, Windows, and macOS (ARM + Intel).

## Architecture

### Plugin Entry Point
`calibre-plugin/__init__.py` — implements Calibre's `FileTypePlugin` interface. Handles ACSM file import, triggers fulfillment, downloads the ebook, and optionally invokes DeDRM.

### Adobe Protocol Layer (core logic)
- **`libadobe.py`** — Protocol primitives: device key encryption/decryption (AES), serial/fingerprint generation, nonce calculation, XML node hashing, RSA signing, HTTP requests with ADE version emulation (supports 6 ADE versions).
- **`libadobeAccount.py`** — Account creation, user activation, authentication method discovery, login credential encryption.
- **`libadobeFulfill.py`** — ACSM fulfillment: builds fulfillment requests, parses license tokens/metadata, handles loan returns.
- **`libadobeImportAccount.py`** — Imports existing ADE accounts from Windows/macOS/Linux installations.

### Supporting Modules
- **`customRSA.py`** — Custom PKCS#1 RSA signing (Adobe-specific, avoids external RSA library dependency).
- **`libpdf.py`** — PDF encryption metadata parsing and rights.xml handling.
- **`config.py`** — PyQt5 GUI (1500 lines): account authorization, loaned books management, import/export.
- **`prefs.py`** — Persistent settings storage via Calibre's JSONConfig.
- **`keyextract/`** — C programs compiled with MinGW for Windows DPAPI key extraction.
- **`getEncryptionKeyLinux.py`**, **`getEncryptionKeyWindows.py`** — Platform-specific key extraction.

### Data Flow
ACSM file → `__init__.py` (plugin entry) → device/account check (`libadobe.py`) → build fulfillment request (`libadobeFulfill.py`) → Adobe server → parse response → download EPUB/PDF → optional DeDRM → output file.

### Migration Plugin
`migration_plugin/` — one-time migration from the old "DeACSM" plugin name to "ACSM Input". Downloads the new plugin and uninstalls itself.

## Key Design Considerations

- **Python 2/3 dual support**: All code must work on both. Use try/except for import differences (e.g., `Crypto` vs `Cryptodome`, `urllib` variants). The build injects compatibility shims from `__calibre_compat_code.py`.
- **Vendored dependencies**: `oscrypto` is a custom fork for OpenSSL 3 compatibility; `asn1crypto` is also bundled. Both are downloaded by `package_modules.sh` and shipped in the plugin ZIP.
- **ADE version emulation**: The plugin can emulate 6 different ADE versions (1.7.2 through 4.5.11) to avoid server-side blocking. Version-specific headers and behaviors are in `libadobe.py`.
- **Cross-platform key extraction**: Different strategies per OS — Windows uses compiled DPAPI binaries, Linux uses AES decryption, macOS uses native paths.
