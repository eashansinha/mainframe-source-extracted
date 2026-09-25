      *================================================================*
      * APVNDREC  VENDOR MASTER - VSAM KSDS UNLOAD                     *
      * DSN  AP.PROD.VENDMAST.UNLOAD     RECFM=FB LRECL=80             *
      * KSDS AP.PROD.VENDMAST (KEY 1,8) unloaded by IDCAMS REPRO.      *
      *================================================================*
       01  AP-VND-REC.
           05  APV-VENDOR-ID           PIC X(08).
           05  APV-VENDOR-NAME         PIC X(30).
           05  APV-STATUS              PIC X(01).
               88  APV-ACTIVE          VALUE 'A'.
               88  APV-INACTIVE        VALUE 'I'.
               88  APV-PAY-HOLD        VALUE 'H'.
           05  APV-PAY-METHOD          PIC X(03).
               88  APV-ACH             VALUE 'ACH'.
               88  APV-CHECK           VALUE 'CHK'.
           05  FILLER                  PIC X(38).
