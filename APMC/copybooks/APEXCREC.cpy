      *================================================================*
      * APEXCREC  MATCH EXCEPTION - AP CLERK WORK QUEUE                *
      * DSN  AP.PROD.APEXCEPT.DAILY(+1)  RECFM=FB LRECL=80             *
      *================================================================*
       01  AP-EXC-REC.
           05  APX-INV-NO              PIC X(12).
           05  APX-VENDOR-ID           PIC X(08).
           05  APX-PO-NO               PIC X(10).
           05  APX-PO-LINE             PIC 9(03).
           05  APX-REASON-CD           PIC X(04).
           05  APX-REASON-TX           PIC X(30).
           05  APX-INV-AMT             PIC 9(09)V99.
           05  FILLER                  PIC X(02).
