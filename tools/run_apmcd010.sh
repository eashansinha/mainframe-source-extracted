#!/usr/bin/env bash
# run_apmcd010.sh - local emulation of APMC/jcl/APMCD010.jcl (files in -> files out)
#
#   STEP010 SORT     invoice feed on VENDOR-ID (13,8) / INV-NO (1,12)
#   STEP020 APMATCH1 three-way match + vouchering (DD names -> env vars)
#
# Usage: tools/run_apmcd010.sh [--in DIR] [--out DIR]
#   --in   directory holding APINVOIC.dat APPOLINE.dat APRCVLN.dat APVENDOR.dat SYSIN.txt
#          (default APMC/data/baseline/APMCD010/input)
#   --out  directory for APVOUCHR.dat APEXCEPT.dat APMCD010.rpt (default work/APMCD010)
#
# Exit code = job MAXCC: 0 clean, 4 exceptions, 8 empty feed / bad SYSIN, 16 abend.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IN="$ROOT/APMC/data/baseline/APMCD010/input"
OUT="$ROOT/work/APMCD010"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --in)  IN="$2"; shift ;;
        --out) OUT="$2"; shift ;;
        *) echo "run_apmcd010.sh: unknown argument $1" >&2; exit 12 ;;
    esac
    shift
done
BIN="$ROOT/bin/APMATCH1"
[[ -x "$BIN" ]] || { echo "run_apmcd010.sh: $BIN missing - run tools/build.sh" >&2; exit 12; }
rm -rf "$OUT"; mkdir -p "$OUT"

echo "==== APMCD010 STEP010  SORT APINVOIC (VENDOR-ID 13-20, INV-NO 1-12)"
LC_ALL=C sort -s -k1.13,1.20 -k1.1,1.12 "$IN/APINVOIC.dat" > "$OUT/APINVOIC.sorted.dat" || exit 16
echo "STEP010 RC=0 ($(wc -l < "$OUT/APINVOIC.sorted.dat") records)"

echo "==== APMCD010 STEP020  APMATCH1"
export COB_LS_FIXED=1
export DD_SYSIN="$IN/SYSIN.txt"
export DD_APINVOIC="$OUT/APINVOIC.sorted.dat"
export DD_APPOLINE="$IN/APPOLINE.dat"
export DD_APRCVLN="$IN/APRCVLN.dat"
export DD_APVENDOR="$IN/APVENDOR.dat"
export DD_APVOUCHR="$OUT/APVOUCHR.dat"
export DD_APEXCEPT="$OUT/APEXCEPT.dat"
export DD_APRPT="$OUT/APMCD010.rpt"
"$BIN"; RC=$?
echo "STEP020 RC=$RC"
rm -f "$OUT/APINVOIC.sorted.dat"
echo "APMCD010 JOB ENDED MAXCC=$RC"
exit $RC
