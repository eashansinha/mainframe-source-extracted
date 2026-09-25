      *================================================================*
      * APPOREC   PURCHASE ORDER LINE - OPEN PO UNLOAD                 *
      * DSN  AP.PROD.POLINE.UNLOAD       RECFM=FB LRECL=80             *
      * Unloaded nightly from DB2 table POPROD.PO_LINE (see db2/).     *
      *================================================================*
       01  AP-PO-REC.
           05  APP-PO-NO               PIC X(10).
           05  APP-PO-LINE             PIC 9(03).
           05  APP-VENDOR-ID           PIC X(08).
           05  APP-ITEM-NO             PIC X(10).
           05  APP-ORD-QTY             PIC 9(07).
           05  APP-UNIT-PRICE          PIC 9(07)V9(04).
           05  APP-STATUS              PIC X(01).
               88  APP-OPEN            VALUE 'O'.
               88  APP-CLOSED          VALUE 'C'.
               88  APP-HELD            VALUE 'H'.
           05  FILLER                  PIC X(30).
