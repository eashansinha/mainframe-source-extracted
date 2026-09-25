      *================================================================*
      * APWRKREC  AP CLERK WORK ITEM - ONE PER MATCH EXCEPTION         *
      * DSN  AP.PROD.APWRKQ.DAILY(+1)    RECFM=FB LRECL=120            *
      *================================================================*
       01  AP-WRK-REC.
           05  APW-WORK-ID             PIC X(11).
           05  APW-QUEUE               PIC X(04).
           05  APW-PRIORITY            PIC 9(01).
           05  APW-SLA-DATE            PIC 9(08).
           05  APW-INV-NO              PIC X(12).
           05  APW-VENDOR-ID           PIC X(08).
           05  APW-VENDOR-NAME         PIC X(30).
           05  APW-PO-NO               PIC X(10).
           05  APW-PO-LINE             PIC 9(03).
           05  APW-REASON-CD           PIC X(04).
           05  APW-INV-AMT             PIC 9(09)V99.
           05  FILLER                  PIC X(18).
