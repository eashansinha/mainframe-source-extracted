# mainframe-source-extracted

Extract of mainframe source, organised by **application mnemonic**
(one top-level folder per application). This demo copy contains one application:

```
APMC/                 accounts payable
  cobol/              programs            APMATCH1.cbl
  copybooks/          record layouts      APINVREC APPOREC APRCVREC APVNDREC APVCHREC APEXCREC
  jcl/                jobs                APMCD010.jcl
  schedules/          scheduler extract   APMC-daily.txt (predecessors / successors)
  db2/                DDL for tables the application unloads from
  layouts/            DD -> copybook -> LRECL -> business key map
  data/baseline/      approved inputs + the legacy job's outputs, per job, checksummed
tools/                demo-only local emulation (GnuCOBOL), not part of a real extract
```

> Demo repository. Every job, vendor, invoice and amount is synthetic.

**This repository is read-only for migration work.** Migrated code goes to the
application's destination repository (`apmc-mod`), never here.

## APMCD010 in one picture

```
APINVOIC invoices ─┐
APPOLINE PO lines ─┤                           ┌─ APVOUCHR approved vouchers -> APMCD020 payment run
APRCVLN  receipts ─┼─ SORT ─ APMATCH1 ─────────┼─ APEXCEPT match exceptions -> AP clerk work queue
APVENDOR vendors  ─┘   (3-way match, terms)    └─ APRPT    control report   (+ return code 0/4/8/16)
```

## Reproducing the baseline locally

```bash
sudo apt-get install -y gnucobol       # GnuCOBOL stands in for Enterprise COBOL
tools/build.sh
tools/run_apmcd010.sh                  # -> work/APMCD010/, exit code 4 (exceptions written)
diff -r work/APMCD010 APMC/data/baseline/APMCD010/output   # identical (MAXCC file aside)
```

At Lowe's the baseline comes from a controlled mainframe run on masked data,
not from GnuCOBOL. `tools/gen_apmcd010_data.py` regenerates the synthetic inputs.
