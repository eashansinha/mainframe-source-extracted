#!/usr/bin/env bash
# build.sh - compile the legacy load modules with GnuCOBOL for local emulation.
#
# Mainframe equivalent: IGYWCL compile/link into AP.PROD.LOADLIB(APMATCH1).
# GnuCOBOL output is a stand-in for the Enterprise COBOL build; baselines for a
# real job come from a controlled mainframe run, not from this script.
#
# Usage: tools/build.sh            -> bin/APMATCH1
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v cobc >/dev/null || { echo "build.sh: cobc not found (sudo apt-get install -y gnucobol)" >&2; exit 1; }
mkdir -p "$ROOT/bin"
echo "build.sh: $(cobc --version | head -1)"
cobc -x -I "$ROOT/APMC/copybooks" -o "$ROOT/bin/APMATCH1" "$ROOT/APMC/cobol/APMATCH1.cbl"
echo "build.sh: OK -> bin/APMATCH1"
