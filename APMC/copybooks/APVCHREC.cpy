      *================================================================*
      * APVCHREC  APPROVED VOUCHER - INPUT TO PAYMENT RUN APMCD020     *
      * DSN  AP.PROD.APVOUCHR.DAILY(+1)  RECFM=FB LRECL=120            *
      *================================================================*
       01  AP-VCH-REC.
           05  APO-VOUCHER-NO          PIC X(12).
           05  APO-INV-NO              PIC X(12).
           05  APO-VENDOR-ID           PIC X(08).
           05  APO-PO-NO               PIC X(10).
           05  APO-PO-LINE             PIC 9(03).
           05  APO-INV-DATE            PIC 9(08).
           05  APO-DUE-DATE            PIC 9(08).
           05  APO-DISC-DATE           PIC 9(08).
           05  APO-GROSS-AMT           PIC 9(09)V99.
           05  APO-DISC-AMT            PIC 9(07)V99.
           05  APO-NET-AMT             PIC 9(09)V99.
           05  APO-PAY-METHOD          PIC X(03).
           05  APO-TERMS-CD            PIC X(04).
           05  FILLER                  PIC X(13).
