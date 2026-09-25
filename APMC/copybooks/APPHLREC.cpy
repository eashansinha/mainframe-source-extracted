      *================================================================*
      * APPHLREC  PAYMENT HOLD - VOUCHER NOT PAID, AP OPS REVIEW       *
      * DSN  AP.PROD.APPAYHLD.DAILY(+1)  RECFM=FB LRECL=80             *
      *================================================================*
       01  AP-PHL-REC.
           05  APH-VOUCHER-NO          PIC X(12).
           05  APH-INV-NO              PIC X(12).
           05  APH-VENDOR-ID           PIC X(08).
           05  APH-REASON-CD           PIC X(04).
           05  APH-REASON-TX           PIC X(30).
           05  APH-NET-AMT             PIC 9(09)V99.
           05  FILLER                  PIC X(03).
