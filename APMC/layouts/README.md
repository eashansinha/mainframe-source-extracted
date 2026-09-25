# APMC record layouts

Copybooks in `../copybooks/` are the authoritative layouts. Machine-readable
JSON layouts for parity comparison live with the migration target (`apmc-mod/parity/layouts/`),
derived from these copybooks.

| DD / dataset                 | Copybook | RECFM | LRECL | Business key            |
|------------------------------|----------|-------|-------|-------------------------|
| APINVOIC  invoice feed       | APINVREC | FB    | 100   | VENDOR-ID + INV-NO      |
| APPOLINE  open PO lines      | APPOREC  | FB    | 80    | PO-NO + PO-LINE         |
| APRCVLN   receipts           | APRCVREC | FB    | 60    | RCV-ID                  |
| APVENDOR  vendor master      | APVNDREC | FB    | 80    | VENDOR-ID               |
| APVOUCHR  approved vouchers  | APVCHREC | FB    | 120   | INV-NO + VENDOR-ID      |
| APEXCEPT  match exceptions   | APEXCREC | FB    | 80    | INV-NO + VENDOR-ID      |
| APRPT     control report     | -        | FBA   | 132   | -                       |

All numeric fields are unsigned zoned decimal with an implied decimal point (`V`).
The mainframe files are EBCDIC; the demo baselines are ASCII.
