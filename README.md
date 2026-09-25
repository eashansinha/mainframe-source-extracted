# mainframe-source-extracted

Extract of mainframe source, organised by **application mnemonic**
(one top-level folder per application). This demo copy contains one application:

```
APMC/                 accounts payable
  cobol/              programs            APMATCH1 APPAYSL1 APEXQUE1
  copybooks/          record layouts      APINVREC APPOREC APRCVREC APVNDREC APVCHREC APEXCREC
                                          APPAYREC APPHLREC APWRKREC
  jcl/                jobs                APMCD010 APMCD020 APMCD030
  schedules/          scheduler extract   APMC-daily.txt (predecessors / successors)
  db2/                DDL for tables the application unloads from
  layouts/            DD -> copybook -> LRECL -> business key map
  data/baseline/      approved inputs + the legacy job's outputs, per job, checksummed
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

## APMCD020 and APMCD030

| Job      | Program  | Reads                                 | Writes                                   |
|----------|----------|---------------------------------------|------------------------------------------|
| APMCD020 | APPAYSL1 | APVOUCHR (from APMCD010), APVENDOR    | APPAYMT payments, APPAYHLD held, APPAYDEF deferred, report |
| APMCD030 | APEXQUE1 | APEXCEPT (from APMCD010), APVENDOR    | APWRKQ clerk work items, report          |

## Where the baseline comes from

`APMC/data/baseline/<JOB>/` holds, per job:

- `input/`  - the approved (masked) input files and the SYSIN control card
- `output/` - the files the **legacy job produced** from those inputs on the
  mainframe, plus `MAXCC` (its return code)
- `SHA256SUMS` - checksums; any migration must verify these before comparing

The baseline is produced by a controlled mainframe run owned by the application
team. Migration sessions never run the COBOL: they read it, and they compare the
new job's output against these files.
