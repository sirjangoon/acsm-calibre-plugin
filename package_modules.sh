#!/usr/bin/env bash

# Copyright (c) 2021-2023 Leseratte10
# This file is part of the ACSM Input Plugin by Leseratte10
# ACSM Input Plugin for Calibre / acsm-calibre-plugin
#
# For more information, see: 
# https://github.com/Leseratte10/acsm-calibre-plugin

pushd calibre-plugin

# As the latest oscrypto release (1.3.0) does not yet support OpenSSL3, we'll have to download a forked version ...
# See https://github.com/wbond/oscrypto/pull/61 for more information.

wget https://github.com/Leseratte10/acsm-calibre-plugin/releases/download/config/asn1crypto_1.5.1.zip -O asn1crypto.zip
wget https://github.com/Leseratte10/acsm-calibre-plugin/releases/download/config/oscrypto_1.3.0_fork_2023-12-19.zip -O oscrypto.zip

# Patch oscrypto to handle unsigned libcrypto on macOS (code signing requirement).
# The CDLL() call raises OSError when the library is unsigned, but only
# LibraryNotFoundError is caught, preventing the pure-Python fallback from working.
tmpdir=$(mktemp -d)
unzip -o oscrypto.zip -d "$tmpdir" > /dev/null
python3 -c "
import os, sys
p = os.path.join(sys.argv[1], 'oscrypto', 'oscrypto', '_openssl', '_libcrypto_ctypes.py')
t = open(p).read()
old = 'libcrypto = CDLL(libcrypto_path, use_errno=True)'
new = '''try:
    libcrypto = CDLL(libcrypto_path, use_errno=True)
except OSError as e:
    raise LibraryNotFoundError('The library libcrypto could not be loaded: %s' % str(e))'''
if old not in t:
    print('WARNING: oscrypto patch target not found, skipping', file=sys.stderr)
else:
    open(p, 'w').write(t.replace(old, new, 1))
" "$tmpdir"
(cd "$tmpdir" && zip -r - oscrypto) > oscrypto.zip
rm -rf "$tmpdir"

popd

