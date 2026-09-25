      *================================================================*
      * APINVREC  AP INVOICE LINE - DAILY INVOICE INTAKE FEED          *
      * DSN  AP.PROD.APINVOIC.DAILY(0)   RECFM=FB LRECL=100            *
      * One record per invoice (single PO line per invoice).           *
      * Written by APMCD005 (EDI 810 + scanned-invoice intake).        *
      *================================================================*
       01  AP-INV-REC.
           05  API-INV-NO              PIC X(12).
           05  API-VENDOR-ID           PIC X(08).
           05  API-PO-NO               PIC X(10).
           05  API-PO-LINE             PIC 9(03).
           05  API-INV-DATE            PIC 9(08).
           05  API-TERMS-CD            PIC X(04).
           05  API-INV-QTY             PIC 9(07).
           05  API-UNIT-PRICE          PIC 9(07)V9(04).
           05  API-INV-AMT             PIC 9(09)V99.
           05  API-CURRENCY            PIC X(03).
               88  API-USD             VALUE 'USD'.
           05  API-REMIT-SITE          PIC X(03).
           05  FILLER                  PIC X(20).
