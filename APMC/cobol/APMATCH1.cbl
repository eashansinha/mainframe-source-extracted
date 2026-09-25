       IDENTIFICATION DIVISION.
       PROGRAM-ID. APMATCH1.
       AUTHOR. AP-SYSTEMS.
      *================================================================*
      * APMATCH1 - ACCOUNTS PAYABLE THREE-WAY MATCH AND VOUCHERING     *
      *                                                                *
      * Run by job APMCD010 STEP020 (see ../jcl/APMCD010.jcl).         *
      *                                                                *
      * FILES IN                                                       *
      *   SYSIN     RUNDATE=YYYYMMDD                                   *
      *   APINVOIC  invoice feed, sorted VENDOR-ID/INV-NO  (APINVREC)  *
      *   APPOLINE  open PO lines                          (APPOREC)   *
      *   APRCVLN   receipts                               (APRCVREC)  *
      *   APVENDOR  vendor master KSDS unload              (APVNDREC)  *
      * FILES OUT                                                      *
      *   APVOUCHR  approved vouchers -> APMCD020 payment run          *
      *   APEXCEPT  match exceptions  -> AP clerk work queue           *
      *   APRPT     match control report (132)                         *
      *                                                                *
      * MATCH RULES - checked in this order, FIRST failure wins, one   *
      * exception record per rejected invoice:                         *
      *  E001 same VENDOR-ID + INV-NO as the previous feed record      *
      *       (adjacent duplicates only - feed is sorted)              *
      *  E002 vendor not on vendor master                              *
      *  E003 vendor status not 'A' (inactive or payment hold)         *
      *  E004 currency not USD                                         *
      *  E005 PO-NO + PO-LINE not on open PO file                      *
      *  E006 PO line belongs to a different vendor                    *
      *  E007 PO line status not 'O' (closed or held)                  *
      *  E008 terms code not in the terms table                        *
      *  E009 INV-AMT differs from INV-QTY x UNIT-PRICE (extension     *
      *       truncated to cents) by more than 0.01                    *
      *  E010 quantity already vouchered today + INV-QTY exceeds the   *
      *       quantity received on the PO line                         *
      *  E011 invoice UNIT-PRICE above PO UNIT-PRICE x 1.01 (price     *
      *       limit rounded to 4 decimals); lower prices are accepted  *
      *                                                                *
      * VOUCHER RULES                                                  *
      *  V1 VOUCHER-NO = 'V' + RUNDATE(YYMMDD) + 5-digit sequence,     *
      *     restarting at 00001 every run.                             *
      *  V2 GROSS = INV-AMT (pay what was invoiced, not the PO price). *
      *  V3 DUE-DATE = INV-DATE + net days of the terms code.          *
      *  V4 DISC-DATE = INV-DATE + discount days (zero when the terms  *
      *     carry no discount). The discount is taken only when        *
      *     DISC-DATE >= RUNDATE; DISC-AMT = GROSS x pct ROUNDED       *
      *     (half-up to the cent). NET = GROSS - DISC-AMT.             *
      *  V5 PAY-METHOD comes from the vendor master.                   *
      *  V6 Approved quantity is added to the PO line's vouchered      *
      *     quantity so later invoices on the same line see it (E010). *
      *                                                                *
      * RETURN CODES  0 clean   4 exceptions written                   *
      *               8 empty feed or bad control card   16 abend      *
      *                                                                *
      * CHANGE LOG                                                     *
      *  2006-03-13  AP-0118   initial (two-way match)                 *
      *  2008-11-02  AP-0540   receipts -> three-way match (E010)      *
      *  2011-06-20  AP-1302   1% price tolerance (E011)               *
      *  2014-09-08  AP-2261   early-pay discount terms table (V4)     *
      *  2017-01-30  AP-3047   vendor payment hold treated as E003     *
      *  2020-05-18  AP-4112   extension check E009 after EDI change   *
      *================================================================*
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SYSIN-FILE   ASSIGN TO SYSIN
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-SYSIN.
           SELECT INV-FILE     ASSIGN TO APINVOIC
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-INV.
           SELECT PO-FILE      ASSIGN TO APPOLINE
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-PO.
           SELECT RCV-FILE     ASSIGN TO APRCVLN
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-RCV.
           SELECT VND-FILE     ASSIGN TO APVENDOR
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-VND.
           SELECT VCH-FILE     ASSIGN TO APVOUCHR
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-VCH.
           SELECT EXC-FILE     ASSIGN TO APEXCEPT
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-EXC.
           SELECT REPORT-FILE  ASSIGN TO APRPT
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-RPT.

       DATA DIVISION.
       FILE SECTION.
       FD  SYSIN-FILE.
       01  SYSIN-REC                   PIC X(80).
       FD  INV-FILE.
           COPY APINVREC.
       FD  PO-FILE.
           COPY APPOREC.
       FD  RCV-FILE.
           COPY APRCVREC.
       FD  VND-FILE.
           COPY APVNDREC.
       FD  VCH-FILE.
           COPY APVCHREC.
       FD  EXC-FILE.
           COPY APEXCREC.
       FD  REPORT-FILE.
       01  REPORT-REC                  PIC X(132).

       WORKING-STORAGE SECTION.
       01  WS-FILE-STATUS.
           05  WS-FS-SYSIN             PIC X(02).
           05  WS-FS-INV               PIC X(02).
           05  WS-FS-PO                PIC X(02).
           05  WS-FS-RCV               PIC X(02).
           05  WS-FS-VND               PIC X(02).
           05  WS-FS-VCH               PIC X(02).
           05  WS-FS-EXC               PIC X(02).
           05  WS-FS-RPT               PIC X(02).

       01  WS-FLAGS.
           05  WS-INV-EOF              PIC X(01) VALUE 'N'.
               88  INV-EOF             VALUE 'Y'.
           05  WS-LOAD-EOF             PIC X(01) VALUE 'N'.
               88  LOAD-EOF            VALUE 'Y'.
           05  WS-INV-VALID            PIC X(01) VALUE 'Y'.
               88  INV-VALID           VALUE 'Y'.

       01  WS-CONTROL.
           05  WS-RUNDATE              PIC 9(08) VALUE ZERO.
           05  WS-RUNDATE-X REDEFINES WS-RUNDATE.
               10  WS-RUN-CC           PIC X(02).
               10  WS-RUN-YYMMDD       PIC X(06).
           05  WS-RETURN-CODE          PIC 9(02) VALUE ZERO.
           05  WS-PREV-KEY             PIC X(20) VALUE SPACES.
           05  WS-CURR-KEY             PIC X(20).

      *----------------------------------------------------------------*
      * Vendor master table (AP-0118: 500 max, overflow is an abend)   *
      *----------------------------------------------------------------*
       01  WS-VND-TABLE.
           05  WS-VND-COUNT            PIC 9(04) COMP VALUE ZERO.
           05  WS-VND-ENTRY OCCURS 500 TIMES INDEXED BY VND-IDX.
               10  WS-VND-ID           PIC X(08).
               10  WS-VND-STATUS       PIC X(01).
               10  WS-VND-PAY-METHOD   PIC X(03).

      *----------------------------------------------------------------*
      * Open PO line table with received / vouchered quantities        *
      *----------------------------------------------------------------*
       01  WS-PO-TABLE.
           05  WS-PO-COUNT             PIC 9(04) COMP VALUE ZERO.
           05  WS-PO-ENTRY OCCURS 2000 TIMES INDEXED BY PO-IDX.
               10  WS-PO-KEY.
                   15  WS-PO-NO        PIC X(10).
                   15  WS-PO-LINE      PIC 9(03).
               10  WS-PO-VENDOR        PIC X(08).
               10  WS-PO-STATUS        PIC X(01).
               10  WS-PO-PRICE         PIC 9(07)V9(04).
               10  WS-PO-RCV-QTY       PIC 9(09) COMP-3.
               10  WS-PO-VCH-QTY       PIC 9(09) COMP-3.
       01  WS-SEARCH-PO-KEY.
           05  WS-SK-PO-NO             PIC X(10).
           05  WS-SK-PO-LINE           PIC 9(03).

      *----------------------------------------------------------------*
      * Payment terms table (AP-2261)                                  *
      *   code, discount pct (9V9999), discount days, net days         *
      *----------------------------------------------------------------*
       01  WS-TERMS-VALUES.
           05  FILLER  PIC X(13) VALUE '2N10002001030'.
           05  FILLER  PIC X(13) VALUE '1N15001001545'.
           05  FILLER  PIC X(13) VALUE 'N30 000000030'.
           05  FILLER  PIC X(13) VALUE 'N45 000000045'.
           05  FILLER  PIC X(13) VALUE 'N60 000000060'.
       01  WS-TERMS-TABLE REDEFINES WS-TERMS-VALUES.
           05  WS-TRM-ENTRY OCCURS 5 TIMES INDEXED BY TRM-IDX.
               10  WS-TRM-CODE         PIC X(04).
               10  WS-TRM-PCT          PIC 9V9(04).
               10  WS-TRM-DISC-DAYS    PIC 9(02).
               10  WS-TRM-NET-DAYS     PIC 9(02).

       01  WS-WORK.
           05  WS-REASON-CD            PIC X(04).
           05  WS-REASON-TX            PIC X(30).
           05  WS-REASON-IDX           PIC 9(02).
           05  WS-EXTENSION            PIC 9(11)V99.
           05  WS-EXT-DIFF             PIC S9(11)V99.
           05  WS-PRICE-LIMIT          PIC 9(07)V9(04).
           05  WS-NEW-VCH-QTY          PIC 9(09).
           05  WS-DATE-INT             PIC 9(08).
           05  WS-DUE-DATE             PIC 9(08).
           05  WS-DISC-DATE            PIC 9(08).
           05  WS-DISC-AMT             PIC 9(07)V99.
           05  WS-VOUCHER-SEQ          PIC 9(05) VALUE ZERO.
           05  WS-CUR-PAY-METHOD       PIC X(03).

       01  WS-TOTALS.
           05  WS-TOT-READ             PIC 9(07) COMP-3 VALUE ZERO.
           05  WS-TOT-APPROVED         PIC 9(07) COMP-3 VALUE ZERO.
           05  WS-TOT-EXCEPTED         PIC 9(07) COMP-3 VALUE ZERO.
           05  WS-TOT-VENDORS          PIC 9(07) COMP-3 VALUE ZERO.
           05  WS-TOT-PO-LINES         PIC 9(07) COMP-3 VALUE ZERO.
           05  WS-TOT-RECEIPTS         PIC 9(07) COMP-3 VALUE ZERO.
           05  WS-TOT-RCV-NO-PO        PIC 9(07) COMP-3 VALUE ZERO.
           05  WS-TOT-DISC-TAKEN       PIC 9(07) COMP-3 VALUE ZERO.
           05  WS-TOT-INV-AMT          PIC 9(13)V99 COMP-3 VALUE ZERO.
           05  WS-TOT-GROSS            PIC 9(13)V99 COMP-3 VALUE ZERO.
           05  WS-TOT-DISC             PIC 9(13)V99 COMP-3 VALUE ZERO.
           05  WS-TOT-NET              PIC 9(13)V99 COMP-3 VALUE ZERO.
           05  WS-TOT-EXC-AMT          PIC 9(13)V99 COMP-3 VALUE ZERO.

      *  Approved totals by pay method: 1=ACH 2=CHK
       01  WS-METHOD-TOTALS.
           05  WS-MTH-ENTRY OCCURS 2 TIMES.
               10  WS-MTH-CODE         PIC X(03).
               10  WS-MTH-COUNT        PIC 9(07) COMP-3.
               10  WS-MTH-NET          PIC 9(13)V99 COMP-3.

      *  Exceptions by reason code: 1=E001 .. 11=E011
       01  WS-REASON-VALUES.
           05  FILLER PIC X(34) VALUE 'E001DUPLICATE INVOICE'.
           05  FILLER PIC X(34) VALUE 'E002VENDOR NOT ON FILE'.
           05  FILLER PIC X(34) VALUE 'E003VENDOR NOT ACTIVE'.
           05  FILLER PIC X(34) VALUE 'E004NON-USD CURRENCY'.
           05  FILLER PIC X(34) VALUE 'E005PO LINE NOT ON FILE'.
           05  FILLER PIC X(34) VALUE 'E006PO VENDOR MISMATCH'.
           05  FILLER PIC X(34) VALUE 'E007PO LINE CLOSED OR HELD'.
           05  FILLER PIC X(34) VALUE 'E008UNKNOWN PAYMENT TERMS'.
           05  FILLER PIC X(34) VALUE 'E009EXTENSION ERROR'.
           05  FILLER PIC X(34) VALUE 'E010QTY EXCEEDS RECEIVED'.
           05  FILLER PIC X(34) VALUE 'E011PRICE OVER TOLERANCE'.
       01  WS-REASON-TABLE REDEFINES WS-REASON-VALUES.
           05  WS-RSN-DEF OCCURS 11 TIMES.
               10  WS-RSN-DEF-CODE     PIC X(04).
               10  WS-RSN-DEF-TEXT     PIC X(30).
       01  WS-REASON-TOTALS.
           05  WS-RSN-ENTRY OCCURS 11 TIMES.
               10  WS-RSN-COUNT        PIC 9(07) COMP-3.
               10  WS-RSN-AMOUNT       PIC 9(13)V99 COMP-3.
       01  WS-RSN-SUB                  PIC 9(02).

      *----------------------------------------------------------------*
      * Report lines (132)                                             *
      *----------------------------------------------------------------*
       01  RL-HEADER-1.
           05  FILLER                  PIC X(10) VALUE 'APMATCH1'.
           05  FILLER                  PIC X(14) VALUE SPACES.
           05  FILLER                  PIC X(52) VALUE
               'AP THREE-WAY MATCH - VOUCHER CONTROL REPORT'.
           05  FILLER                  PIC X(20) VALUE SPACES.
           05  FILLER                  PIC X(09) VALUE 'RUN DATE '.
           05  RL-H1-YYYY              PIC X(04).
           05  FILLER                  PIC X(01) VALUE '-'.
           05  RL-H1-MM                PIC X(02).
           05  FILLER                  PIC X(01) VALUE '-'.
           05  RL-H1-DD                PIC X(02).
           05  FILLER                  PIC X(17) VALUE SPACES.

       01  RL-SECTION.
           05  RL-SEC-TITLE            PIC X(40).
           05  FILLER                  PIC X(92) VALUE SPACES.

       01  RL-TOTAL-COUNT.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  RL-TC-LABEL             PIC X(30).
           05  RL-TC-VALUE             PIC Z(7)9.
           05  FILLER                  PIC X(92) VALUE SPACES.

       01  RL-TOTAL-AMOUNT.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  RL-TA-LABEL             PIC X(30).
           05  RL-TA-VALUE             PIC Z(3),ZZZ,ZZZ,ZZZ,ZZ9.99.
           05  FILLER                  PIC X(78) VALUE SPACES.

       01  RL-METHOD-HDR.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  FILLER                  PIC X(12) VALUE 'PAY METHOD'.
           05  FILLER                  PIC X(10) VALUE '  VOUCHERS'.
           05  FILLER                  PIC X(22) VALUE
               '            NET AMOUNT'.
           05  FILLER                  PIC X(86) VALUE SPACES.

       01  RL-METHOD-LINE.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  RL-MTH-CODE             PIC X(12).
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  RL-MTH-COUNT            PIC Z(7)9.
           05  RL-MTH-NET              PIC Z(3),ZZZ,ZZZ,ZZZ,ZZ9.99.
           05  FILLER                  PIC X(86) VALUE SPACES.

       01  RL-REASON-HDR.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  FILLER                  PIC X(36) VALUE 'REASON'.
           05  FILLER                  PIC X(08) VALUE ' INVOICE'.
           05  FILLER                  PIC X(22) VALUE
               '        INVOICE AMOUNT'.
           05  FILLER                  PIC X(64) VALUE SPACES.

       01  RL-REASON-LINE.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  RL-RSN-CODE             PIC X(04).
           05  FILLER                  PIC X(01) VALUE SPACES.
           05  RL-RSN-TEXT             PIC X(31).
           05  RL-RSN-COUNT            PIC Z(7)9.
           05  RL-RSN-AMOUNT           PIC Z(3),ZZZ,ZZZ,ZZZ,ZZ9.99.
           05  FILLER                  PIC X(64) VALUE SPACES.

       01  RL-BLANK                    PIC X(132) VALUE SPACES.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-INVOICE
               UNTIL INV-EOF
           PERFORM 4000-WRITE-REPORT
           PERFORM 9000-TERMINATE
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.

      *================================================================*
       1000-INITIALIZE.
           PERFORM 1100-READ-CONTROL-CARDS
           PERFORM 1200-LOAD-VENDORS
           PERFORM 1300-LOAD-PO-LINES
           PERFORM 1400-APPLY-RECEIPTS
           PERFORM 1500-INIT-TOTALS
           OPEN INPUT INV-FILE
           IF WS-FS-INV NOT = '00'
               DISPLAY 'APMATCH1 OPEN APINVOIC FAILED FS=' WS-FS-INV
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           OPEN OUTPUT VCH-FILE EXC-FILE REPORT-FILE
           IF WS-FS-VCH NOT = '00' OR WS-FS-EXC NOT = '00'
              OR WS-FS-RPT NOT = '00'
               DISPLAY 'APMATCH1 OPEN OUTPUT FAILED FS='
                       WS-FS-VCH '/' WS-FS-EXC '/' WS-FS-RPT
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           PERFORM 2100-READ-INVOICE
           IF INV-EOF
               DISPLAY 'APMATCH1 EMPTY APINVOIC FEED - NOTHING MATCHED'
               MOVE 08 TO WS-RETURN-CODE
           END-IF.

       1100-READ-CONTROL-CARDS.
           OPEN INPUT SYSIN-FILE
           IF WS-FS-SYSIN NOT = '00'
               DISPLAY 'APMATCH1 OPEN SYSIN FAILED FS=' WS-FS-SYSIN
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           READ SYSIN-FILE
               AT END
                   DISPLAY 'APMATCH1 SYSIN EMPTY - RUNDATE REQUIRED'
                   MOVE 08 TO RETURN-CODE
                   STOP RUN
           END-READ
           IF SYSIN-REC(1:8) = 'RUNDATE='
              AND SYSIN-REC(9:8) IS NUMERIC
               MOVE SYSIN-REC(9:8) TO WS-RUNDATE
           ELSE
               DISPLAY 'APMATCH1 BAD CONTROL CARD: ' SYSIN-REC(1:40)
               MOVE 08 TO RETURN-CODE
               STOP RUN
           END-IF
           CLOSE SYSIN-FILE.

       1200-LOAD-VENDORS.
           OPEN INPUT VND-FILE
           IF WS-FS-VND NOT = '00'
               DISPLAY 'APMATCH1 OPEN APVENDOR FAILED FS=' WS-FS-VND
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           MOVE 'N' TO WS-LOAD-EOF
           PERFORM UNTIL LOAD-EOF
               READ VND-FILE
                   AT END SET LOAD-EOF TO TRUE
                   NOT AT END
                       ADD 1 TO WS-VND-COUNT
                       IF WS-VND-COUNT > 500
                           DISPLAY 'APMATCH1 VENDOR TABLE OVERFLOW'
                           MOVE 16 TO RETURN-CODE
                           STOP RUN
                       END-IF
                       MOVE APV-VENDOR-ID  TO WS-VND-ID (WS-VND-COUNT)
                       MOVE APV-STATUS     TO WS-VND-STATUS
                                              (WS-VND-COUNT)
                       MOVE APV-PAY-METHOD TO WS-VND-PAY-METHOD
                                              (WS-VND-COUNT)
               END-READ
           END-PERFORM
           MOVE WS-VND-COUNT TO WS-TOT-VENDORS
           CLOSE VND-FILE.

       1300-LOAD-PO-LINES.
           OPEN INPUT PO-FILE
           IF WS-FS-PO NOT = '00'
               DISPLAY 'APMATCH1 OPEN APPOLINE FAILED FS=' WS-FS-PO
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           MOVE 'N' TO WS-LOAD-EOF
           PERFORM UNTIL LOAD-EOF
               READ PO-FILE
                   AT END SET LOAD-EOF TO TRUE
                   NOT AT END
                       ADD 1 TO WS-PO-COUNT
                       IF WS-PO-COUNT > 2000
                           DISPLAY 'APMATCH1 PO TABLE OVERFLOW'
                           MOVE 16 TO RETURN-CODE
                           STOP RUN
                       END-IF
                       MOVE APP-PO-NO      TO WS-PO-NO (WS-PO-COUNT)
                       MOVE APP-PO-LINE    TO WS-PO-LINE (WS-PO-COUNT)
                       MOVE APP-VENDOR-ID  TO WS-PO-VENDOR
                                              (WS-PO-COUNT)
                       MOVE APP-STATUS     TO WS-PO-STATUS
                                              (WS-PO-COUNT)
                       MOVE APP-UNIT-PRICE TO WS-PO-PRICE (WS-PO-COUNT)
                       MOVE ZERO TO WS-PO-RCV-QTY (WS-PO-COUNT)
                                    WS-PO-VCH-QTY (WS-PO-COUNT)
               END-READ
           END-PERFORM
           MOVE WS-PO-COUNT TO WS-TOT-PO-LINES
           CLOSE PO-FILE.

      *    Receipts for a PO line that is not on the open PO file are
      *    counted on the report and otherwise ignored (AP-0540).
       1400-APPLY-RECEIPTS.
           OPEN INPUT RCV-FILE
           IF WS-FS-RCV NOT = '00'
               DISPLAY 'APMATCH1 OPEN APRCVLN FAILED FS=' WS-FS-RCV
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           MOVE 'N' TO WS-LOAD-EOF
           PERFORM UNTIL LOAD-EOF
               READ RCV-FILE
                   AT END SET LOAD-EOF TO TRUE
                   NOT AT END
                       ADD 1 TO WS-TOT-RECEIPTS
                       MOVE APR-PO-NO   TO WS-SK-PO-NO
                       MOVE APR-PO-LINE TO WS-SK-PO-LINE
                       SET PO-IDX TO 1
                       SEARCH WS-PO-ENTRY
                           AT END
                               ADD 1 TO WS-TOT-RCV-NO-PO
                           WHEN PO-IDX > WS-PO-COUNT
                               ADD 1 TO WS-TOT-RCV-NO-PO
                           WHEN WS-PO-KEY (PO-IDX) = WS-SEARCH-PO-KEY
                               ADD APR-RCV-QTY
                                 TO WS-PO-RCV-QTY (PO-IDX)
                       END-SEARCH
               END-READ
           END-PERFORM
           CLOSE RCV-FILE.

       1500-INIT-TOTALS.
           MOVE 'ACH' TO WS-MTH-CODE (1)
           MOVE 'CHK' TO WS-MTH-CODE (2)
           MOVE ZERO  TO WS-MTH-COUNT (1) WS-MTH-NET (1)
                         WS-MTH-COUNT (2) WS-MTH-NET (2)
           PERFORM VARYING WS-RSN-SUB FROM 1 BY 1 UNTIL WS-RSN-SUB > 11
               MOVE ZERO TO WS-RSN-COUNT (WS-RSN-SUB)
                            WS-RSN-AMOUNT (WS-RSN-SUB)
           END-PERFORM.

      *================================================================*
       2000-PROCESS-INVOICE.
           ADD 1 TO WS-TOT-READ
           ADD API-INV-AMT TO WS-TOT-INV-AMT
           PERFORM 2200-MATCH-INVOICE
           IF INV-VALID
               PERFORM 2300-WRITE-VOUCHER
           ELSE
               PERFORM 2400-WRITE-EXCEPTION
           END-IF
           MOVE WS-CURR-KEY TO WS-PREV-KEY
           PERFORM 2100-READ-INVOICE.

       2100-READ-INVOICE.
           READ INV-FILE
               AT END SET INV-EOF TO TRUE
           END-READ.

       2200-MATCH-INVOICE.
           MOVE 'Y' TO WS-INV-VALID
           MOVE API-VENDOR-ID TO WS-CURR-KEY(1:8)
           MOVE API-INV-NO    TO WS-CURR-KEY(9:12)
      *    E001 adjacent duplicate
           IF WS-CURR-KEY = WS-PREV-KEY
               MOVE 1 TO WS-REASON-IDX
               PERFORM 2900-FAIL
               EXIT PARAGRAPH
           END-IF
      *    E002 / E003 vendor
           SET VND-IDX TO 1
           SEARCH WS-VND-ENTRY
               AT END
                   MOVE 2 TO WS-REASON-IDX
               WHEN VND-IDX > WS-VND-COUNT
                   MOVE 2 TO WS-REASON-IDX
               WHEN WS-VND-ID (VND-IDX) = API-VENDOR-ID
                   IF WS-VND-STATUS (VND-IDX) NOT = 'A'
                       MOVE 3 TO WS-REASON-IDX
                   ELSE
                       MOVE ZERO TO WS-REASON-IDX
                       MOVE WS-VND-PAY-METHOD (VND-IDX)
                         TO WS-CUR-PAY-METHOD
                   END-IF
           END-SEARCH
           IF WS-REASON-IDX NOT = ZERO
               PERFORM 2900-FAIL
               EXIT PARAGRAPH
           END-IF
      *    E004 currency
           IF NOT API-USD
               MOVE 4 TO WS-REASON-IDX
               PERFORM 2900-FAIL
               EXIT PARAGRAPH
           END-IF
      *    E005 / E006 / E007 PO line
           MOVE API-PO-NO   TO WS-SK-PO-NO
           MOVE API-PO-LINE TO WS-SK-PO-LINE
           SET PO-IDX TO 1
           SEARCH WS-PO-ENTRY
               AT END
                   MOVE 5 TO WS-REASON-IDX
               WHEN PO-IDX > WS-PO-COUNT
                   MOVE 5 TO WS-REASON-IDX
               WHEN WS-PO-KEY (PO-IDX) = WS-SEARCH-PO-KEY
                   EVALUATE TRUE
                       WHEN WS-PO-VENDOR (PO-IDX) NOT = API-VENDOR-ID
                           MOVE 6 TO WS-REASON-IDX
                       WHEN WS-PO-STATUS (PO-IDX) NOT = 'O'
                           MOVE 7 TO WS-REASON-IDX
                       WHEN OTHER
                           MOVE ZERO TO WS-REASON-IDX
                   END-EVALUATE
           END-SEARCH
           IF WS-REASON-IDX NOT = ZERO
               PERFORM 2900-FAIL
               EXIT PARAGRAPH
           END-IF
      *    E008 terms
           SET TRM-IDX TO 1
           SEARCH WS-TRM-ENTRY
               AT END
                   MOVE 8 TO WS-REASON-IDX
                   PERFORM 2900-FAIL
                   EXIT PARAGRAPH
               WHEN WS-TRM-CODE (TRM-IDX) = API-TERMS-CD
                   CONTINUE
           END-SEARCH
      *    E009 extension (truncated, no ROUNDED - AP-4112)
           COMPUTE WS-EXTENSION = API-INV-QTY * API-UNIT-PRICE
           COMPUTE WS-EXT-DIFF = API-INV-AMT - WS-EXTENSION
           IF WS-EXT-DIFF > 0.01 OR WS-EXT-DIFF < -0.01
               MOVE 9 TO WS-REASON-IDX
               PERFORM 2900-FAIL
               EXIT PARAGRAPH
           END-IF
      *    E010 three-way quantity
           COMPUTE WS-NEW-VCH-QTY = WS-PO-VCH-QTY (PO-IDX)
                                  + API-INV-QTY
           IF WS-NEW-VCH-QTY > WS-PO-RCV-QTY (PO-IDX)
               MOVE 10 TO WS-REASON-IDX
               PERFORM 2900-FAIL
               EXIT PARAGRAPH
           END-IF
      *    E011 price tolerance +1%
           COMPUTE WS-PRICE-LIMIT ROUNDED = WS-PO-PRICE (PO-IDX) * 1.01
           IF API-UNIT-PRICE > WS-PRICE-LIMIT
               MOVE 11 TO WS-REASON-IDX
               PERFORM 2900-FAIL
               EXIT PARAGRAPH
           END-IF.

       2300-WRITE-VOUCHER.
           ADD 1 TO WS-VOUCHER-SEQ
           MOVE WS-NEW-VCH-QTY TO WS-PO-VCH-QTY (PO-IDX)
           MOVE SPACES TO AP-VCH-REC
           STRING 'V' WS-RUN-YYMMDD WS-VOUCHER-SEQ
               DELIMITED BY SIZE INTO APO-VOUCHER-NO
           MOVE API-INV-NO     TO APO-INV-NO
           MOVE API-VENDOR-ID  TO APO-VENDOR-ID
           MOVE API-PO-NO      TO APO-PO-NO
           MOVE API-PO-LINE    TO APO-PO-LINE
           MOVE API-INV-DATE   TO APO-INV-DATE
           MOVE API-TERMS-CD   TO APO-TERMS-CD
           MOVE WS-CUR-PAY-METHOD TO APO-PAY-METHOD
           COMPUTE WS-DATE-INT = FUNCTION INTEGER-OF-DATE(API-INV-DATE)
           COMPUTE WS-DUE-DATE = FUNCTION DATE-OF-INTEGER(
                   WS-DATE-INT + WS-TRM-NET-DAYS (TRM-IDX))
           MOVE WS-DUE-DATE TO APO-DUE-DATE
           MOVE ZERO TO WS-DISC-AMT WS-DISC-DATE
           IF WS-TRM-DISC-DAYS (TRM-IDX) > ZERO
               COMPUTE WS-DISC-DATE = FUNCTION DATE-OF-INTEGER(
                       WS-DATE-INT + WS-TRM-DISC-DAYS (TRM-IDX))
               IF WS-DISC-DATE NOT < WS-RUNDATE
                   COMPUTE WS-DISC-AMT ROUNDED =
                           API-INV-AMT * WS-TRM-PCT (TRM-IDX)
                   ADD 1 TO WS-TOT-DISC-TAKEN
               END-IF
           END-IF
           MOVE WS-DISC-DATE   TO APO-DISC-DATE
           MOVE API-INV-AMT    TO APO-GROSS-AMT
           MOVE WS-DISC-AMT    TO APO-DISC-AMT
           COMPUTE APO-NET-AMT = API-INV-AMT - WS-DISC-AMT
           WRITE AP-VCH-REC
           ADD 1 TO WS-TOT-APPROVED
           ADD APO-GROSS-AMT TO WS-TOT-GROSS
           ADD APO-DISC-AMT  TO WS-TOT-DISC
           ADD APO-NET-AMT   TO WS-TOT-NET
           IF APO-PAY-METHOD = 'ACH'
               ADD 1 TO WS-MTH-COUNT (1)
               ADD APO-NET-AMT TO WS-MTH-NET (1)
           ELSE
               ADD 1 TO WS-MTH-COUNT (2)
               ADD APO-NET-AMT TO WS-MTH-NET (2)
           END-IF.

       2400-WRITE-EXCEPTION.
           MOVE SPACES TO AP-EXC-REC
           MOVE API-INV-NO     TO APX-INV-NO
           MOVE API-VENDOR-ID  TO APX-VENDOR-ID
           MOVE API-PO-NO      TO APX-PO-NO
           MOVE API-PO-LINE    TO APX-PO-LINE
           MOVE WS-REASON-CD   TO APX-REASON-CD
           MOVE WS-REASON-TX   TO APX-REASON-TX
           MOVE API-INV-AMT    TO APX-INV-AMT
           WRITE AP-EXC-REC
           ADD 1 TO WS-TOT-EXCEPTED
           ADD API-INV-AMT TO WS-TOT-EXC-AMT
           ADD 1 TO WS-RSN-COUNT (WS-REASON-IDX)
           ADD API-INV-AMT TO WS-RSN-AMOUNT (WS-REASON-IDX)
           IF WS-RETURN-CODE < 4
               MOVE 4 TO WS-RETURN-CODE
           END-IF.

       2900-FAIL.
           MOVE 'N' TO WS-INV-VALID
           MOVE WS-RSN-DEF-CODE (WS-REASON-IDX) TO WS-REASON-CD
           MOVE WS-RSN-DEF-TEXT (WS-REASON-IDX) TO WS-REASON-TX.

      *================================================================*
       4000-WRITE-REPORT.
           MOVE WS-RUNDATE(1:4) TO RL-H1-YYYY
           MOVE WS-RUNDATE(5:2) TO RL-H1-MM
           MOVE WS-RUNDATE(7:2) TO RL-H1-DD
           WRITE REPORT-REC FROM RL-HEADER-1
           WRITE REPORT-REC FROM RL-BLANK

           MOVE 'REFERENCE DATA' TO RL-SEC-TITLE
           WRITE REPORT-REC FROM RL-SECTION
           MOVE 'VENDORS LOADED' TO RL-TC-LABEL
           MOVE WS-TOT-VENDORS TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'OPEN PO LINES LOADED' TO RL-TC-LABEL
           MOVE WS-TOT-PO-LINES TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'RECEIPTS READ' TO RL-TC-LABEL
           MOVE WS-TOT-RECEIPTS TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'RECEIPTS WITHOUT OPEN PO LINE' TO RL-TC-LABEL
           MOVE WS-TOT-RCV-NO-PO TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           WRITE REPORT-REC FROM RL-BLANK

           MOVE 'MATCH SUMMARY' TO RL-SEC-TITLE
           WRITE REPORT-REC FROM RL-SECTION
           MOVE 'INVOICES READ' TO RL-TC-LABEL
           MOVE WS-TOT-READ TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'INVOICES APPROVED' TO RL-TC-LABEL
           MOVE WS-TOT-APPROVED TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'INVOICES EXCEPTED' TO RL-TC-LABEL
           MOVE WS-TOT-EXCEPTED TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'DISCOUNTS TAKEN' TO RL-TC-LABEL
           MOVE WS-TOT-DISC-TAKEN TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'INVOICE AMOUNT READ' TO RL-TA-LABEL
           MOVE WS-TOT-INV-AMT TO RL-TA-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-AMOUNT
           MOVE 'GROSS APPROVED' TO RL-TA-LABEL
           MOVE WS-TOT-GROSS TO RL-TA-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-AMOUNT
           MOVE 'DISCOUNT TAKEN' TO RL-TA-LABEL
           MOVE WS-TOT-DISC TO RL-TA-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-AMOUNT
           MOVE 'NET APPROVED' TO RL-TA-LABEL
           MOVE WS-TOT-NET TO RL-TA-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-AMOUNT
           MOVE 'EXCEPTED AMOUNT' TO RL-TA-LABEL
           MOVE WS-TOT-EXC-AMT TO RL-TA-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-AMOUNT
           WRITE REPORT-REC FROM RL-BLANK

           MOVE 'APPROVED BY PAY METHOD' TO RL-SEC-TITLE
           WRITE REPORT-REC FROM RL-SECTION
           WRITE REPORT-REC FROM RL-METHOD-HDR
           PERFORM VARYING WS-RSN-SUB FROM 1 BY 1 UNTIL WS-RSN-SUB > 2
               MOVE WS-MTH-CODE (WS-RSN-SUB)  TO RL-MTH-CODE
               MOVE WS-MTH-COUNT (WS-RSN-SUB) TO RL-MTH-COUNT
               MOVE WS-MTH-NET (WS-RSN-SUB)   TO RL-MTH-NET
               WRITE REPORT-REC FROM RL-METHOD-LINE
           END-PERFORM
           WRITE REPORT-REC FROM RL-BLANK

           MOVE 'EXCEPTIONS BY REASON' TO RL-SEC-TITLE
           WRITE REPORT-REC FROM RL-SECTION
           WRITE REPORT-REC FROM RL-REASON-HDR
           PERFORM VARYING WS-RSN-SUB FROM 1 BY 1 UNTIL WS-RSN-SUB > 11
               IF WS-RSN-COUNT (WS-RSN-SUB) > ZERO
                   MOVE WS-RSN-DEF-CODE (WS-RSN-SUB) TO RL-RSN-CODE
                   MOVE WS-RSN-DEF-TEXT (WS-RSN-SUB) TO RL-RSN-TEXT
                   MOVE WS-RSN-COUNT (WS-RSN-SUB)    TO RL-RSN-COUNT
                   MOVE WS-RSN-AMOUNT (WS-RSN-SUB)   TO RL-RSN-AMOUNT
                   WRITE REPORT-REC FROM RL-REASON-LINE
               END-IF
           END-PERFORM
           WRITE REPORT-REC FROM RL-BLANK
           MOVE '*** END OF REPORT ***' TO RL-SEC-TITLE
           WRITE REPORT-REC FROM RL-SECTION.

       9000-TERMINATE.
           CLOSE INV-FILE VCH-FILE EXC-FILE REPORT-FILE
           DISPLAY 'APMATCH1 READ=' WS-TOT-READ
                   ' APPROVED=' WS-TOT-APPROVED
                   ' EXCEPTED=' WS-TOT-EXCEPTED
                   ' RC=' WS-RETURN-CODE.
