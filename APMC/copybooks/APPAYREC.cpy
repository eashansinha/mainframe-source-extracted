      *================================================================*
      * APPAYREC  PAYMENT - ONE PER VENDOR, TO TREASURY RUN TRSD100    *
      * DSN  AP.PROD.APPAYMT.DAILY(+1)   RECFM=FB LRECL=100            *
      *================================================================*
       01  AP-PAY-REC.
           05  APP-PAY-NO              PIC X(11).
           05  APP-VENDOR-ID           PIC X(08).
           05  APP-VENDOR-NAME         PIC X(30).
           05  APP-PAY-METHOD          PIC X(03).
           05  APP-PAY-DATE            PIC 9(08).
           05  APP-VCH-COUNT           PIC 9(03).
           05  APP-GROSS-AMT           PIC 9(09)V99.
           05  APP-DISC-AMT            PIC 9(07)V99.
           05  APP-PAY-AMT             PIC 9(09)V99.
           05  FILLER                  PIC X(06).
