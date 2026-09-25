      *================================================================*
      * APRCVREC  RECEIVING LINE - DC / STORE RECEIPTS                 *
      * DSN  AP.PROD.RECEIPTS.DAILY(0)   RECFM=FB LRECL=60             *
      * Zero or more receipts per PO line; quantities accumulate.      *
      *================================================================*
       01  AP-RCV-REC.
           05  APR-PO-NO               PIC X(10).
           05  APR-PO-LINE             PIC 9(03).
           05  APR-RCV-ID              PIC X(10).
           05  APR-RCV-DATE            PIC 9(08).
           05  APR-RCV-QTY             PIC 9(07).
           05  FILLER                  PIC X(22).
