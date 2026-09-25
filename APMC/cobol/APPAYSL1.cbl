       IDENTIFICATION DIVISION.
       PROGRAM-ID. APPAYSL1.
       AUTHOR. AP-SYSTEMS.
      *================================================================*
      * APPAYSL1 - AP PAYMENT SELECTION AND PAYMENT FILE BUILD         *
      *                                                                *
      * Run by job APMCD020 STEP020 (see ../jcl/APMCD020.jcl).         *
      *                                                                *
      * FILES IN                                                       *
      *   SYSIN     RUNDATE=YYYYMMDD  then  PAYDATE=YYYYMMDD           *
      *   APVOUCHR  approved vouchers from APMCD010, sorted            *
      *             VENDOR-ID/VOUCHER-NO                   (APVCHREC)  *
      *   APVENDOR  vendor master KSDS unload              (APVNDREC)  *
      * FILES OUT                                                      *
      *   APPAYMT   payments, one per vendor -> TRSD100    (APPAYREC)  *
      *   APPAYHLD  vouchers held from payment             (APPHLREC)  *
      *   APPAYDEF  vouchers not yet due, carried forward  (APVCHREC)  *
      *   APPAYRPT  payment control report (132)                       *
      *                                                                *
      * SELECTION RULES - applied to every voucher, in this order:     *
      *  S1 Vendor re-read from the vendor master at payment time:     *
      *     not on file -> hold H01, status 'H' -> hold H02,           *
      *     status 'I' -> hold H03. Held vouchers are not paid.        *
      *  S2 A discount is still available when DISC-AMT > 0 and        *
      *     DISC-DATE >= PAYDATE (the settlement date, not RUNDATE).   *
      *  S3 Voucher is paid today when a discount is available, or     *
      *     DUE-DATE <= PAYDATE + 21 calendar days (AP-5120 window).   *
      *     Otherwise it is deferred to APPAYDEF unchanged.            *
      *  S4 Amount paid = NET-AMT when the discount is available,      *
      *     otherwise GROSS-AMT (discount lost, reported).             *
      *  S5 Pay method comes from the vendor master, not the voucher.  *
      *     Vouchers whose method changed are counted in the report.   *
      *                                                                *
      * PAYMENT RULES                                                  *
      *  P1 One payment per vendor (control break on VENDOR-ID),       *
      *     written only when at least one voucher was paid.           *
      *  P2 PAY-NO = 'P' + RUNDATE(YYMMDD) + 4-digit sequence,         *
      *     restarting at 0001 every run.                              *
      *  P3 PAY-DATE = PAYDATE. GROSS = sum of GROSS-AMT paid,         *
      *     DISC = sum of discounts taken, PAY-AMT = GROSS - DISC.     *
      *                                                                *
      * RETURN CODES  0 clean   4 vouchers held                        *
      *               8 empty voucher file or bad control card         *
      *              16 abend                                          *
      *                                                                *
      * CHANGE LOG                                                     *
      *  2006-04-03  AP-0121   initial (checks only)                   *
      *  2012-02-14  AP-1540   ACH payments, method from vendor master *
      *  2014-09-08  AP-2262   settlement date for discount (S2)       *
      *  2019-07-22  AP-5120   21-day pay window replaces pay-all      *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SYSIN-FILE   ASSIGN TO SYSIN
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-SYSIN.
           SELECT VCH-FILE     ASSIGN TO APVOUCHR
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-VCH.
           SELECT VND-FILE     ASSIGN TO APVENDOR
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-VND.
           SELECT PAY-FILE     ASSIGN TO APPAYMT
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-PAY.
           SELECT HLD-FILE     ASSIGN TO APPAYHLD
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-HLD.
           SELECT DEF-FILE     ASSIGN TO APPAYDEF
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-DEF.
           SELECT REPORT-FILE  ASSIGN TO APPAYRPT
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-RPT.

       DATA DIVISION.
       FILE SECTION.
       FD  SYSIN-FILE.
       01  SYSIN-REC                   PIC X(80).
       FD  VCH-FILE.
           COPY APVCHREC.
       FD  VND-FILE.
           COPY APVNDREC.
       FD  PAY-FILE.
           COPY APPAYREC.
       FD  HLD-FILE.
           COPY APPHLREC.
       FD  DEF-FILE.
       01  DEF-REC                     PIC X(120).
       FD  REPORT-FILE.
       01  REPORT-REC                  PIC X(132).

       WORKING-STORAGE SECTION.
       01  WS-FILE-STATUS.
           05  WS-FS-SYSIN             PIC X(02).
           05  WS-FS-VCH               PIC X(02).
           05  WS-FS-VND               PIC X(02).
           05  WS-FS-PAY               PIC X(02).
           05  WS-FS-HLD               PIC X(02).
           05  WS-FS-DEF               PIC X(02).
           05  WS-FS-RPT               PIC X(02).

       01  WS-FLAGS.
           05  WS-VCH-EOF              PIC X(01) VALUE 'N'.
               88  VCH-EOF             VALUE 'Y'.
           05  WS-LOAD-EOF             PIC X(01) VALUE 'N'.
               88  LOAD-EOF            VALUE 'Y'.
           05  WS-VND-FOUND            PIC X(01).
               88  VND-FOUND           VALUE 'Y'.
           05  WS-DISC-AVAIL           PIC X(01).
               88  DISC-AVAIL          VALUE 'Y'.

       01  WS-CONTROL.
           05  WS-RUNDATE              PIC 9(08) VALUE ZERO.
           05  WS-RUNDATE-X REDEFINES WS-RUNDATE.
               10  WS-RUN-CC           PIC X(02).
               10  WS-RUN-YYMMDD       PIC X(06).
           05  WS-PAYDATE              PIC 9(08) VALUE ZERO.
           05  WS-WINDOW-END           PIC 9(08) VALUE ZERO.
           05  WS-PAY-WINDOW-DAYS      PIC 9(03) VALUE 21.
           05  WS-RETURN-CODE          PIC 9(02) VALUE ZERO.
           05  WS-CURR-VENDOR          PIC X(08) VALUE SPACES.
           05  WS-PAY-SEQ              PIC 9(04) VALUE ZERO.

       01  WS-VENDOR-TABLE.
           05  WS-VND-COUNT            PIC 9(04) COMP VALUE ZERO.
           05  WS-VND-ENTRY OCCURS 500 TIMES
                             INDEXED BY WS-VND-IDX.
               10  WS-VND-ID           PIC X(08).
               10  WS-VND-NAME         PIC X(30).
               10  WS-VND-STATUS       PIC X(01).
               10  WS-VND-METHOD       PIC X(03).

       01  WS-VENDOR-ACCUM.
           05  WS-VA-NAME              PIC X(30).
           05  WS-VA-METHOD            PIC X(03).
           05  WS-VA-COUNT             PIC 9(03).
           05  WS-VA-GROSS             PIC 9(09)V99.
           05  WS-VA-DISC              PIC 9(07)V99.

       01  WS-TOTALS.
           05  WS-TOT-VENDORS          PIC 9(07) VALUE ZERO.
           05  WS-TOT-READ             PIC 9(07) VALUE ZERO.
           05  WS-TOT-PAID             PIC 9(07) VALUE ZERO.
           05  WS-TOT-DEFERRED         PIC 9(07) VALUE ZERO.
           05  WS-TOT-HELD             PIC 9(07) VALUE ZERO.
           05  WS-TOT-DISC-TAKEN       PIC 9(07) VALUE ZERO.
           05  WS-TOT-DISC-LOST        PIC 9(07) VALUE ZERO.
           05  WS-TOT-MTH-CHANGED      PIC 9(07) VALUE ZERO.
           05  WS-TOT-PAYMENTS         PIC 9(07) VALUE ZERO.
           05  WS-AMT-GROSS            PIC 9(13)V99 VALUE ZERO.
           05  WS-AMT-DISC             PIC 9(13)V99 VALUE ZERO.
           05  WS-AMT-DISC-LOST        PIC 9(13)V99 VALUE ZERO.
           05  WS-AMT-PAID             PIC 9(13)V99 VALUE ZERO.
           05  WS-AMT-DEFERRED         PIC 9(13)V99 VALUE ZERO.
           05  WS-AMT-HELD             PIC 9(13)V99 VALUE ZERO.

       01  WS-METHOD-TOTALS.
           05  WS-MTH-ENTRY OCCURS 2 TIMES.
               10  WS-MTH-CODE         PIC X(03).
               10  WS-MTH-PAYMENTS     PIC 9(07).
               10  WS-MTH-VOUCHERS     PIC 9(07).
               10  WS-MTH-AMOUNT       PIC 9(13)V99.
       01  WS-SUB                      PIC 9(02).

      *----------------------------------------------------------------*
      * Report lines (132)                                             *
      *----------------------------------------------------------------*
       01  RL-HEADER-1.
           05  FILLER                  PIC X(10) VALUE 'APPAYSL1'.
           05  FILLER                  PIC X(14) VALUE SPACES.
           05  FILLER                  PIC X(52) VALUE
               'AP PAYMENT SELECTION - PAYMENT CONTROL REPORT'.
           05  FILLER                  PIC X(20) VALUE SPACES.
           05  FILLER                  PIC X(09) VALUE 'RUN DATE '.
           05  RL-H1-YYYY              PIC X(04).
           05  FILLER                  PIC X(01) VALUE '-'.
           05  RL-H1-MM                PIC X(02).
           05  FILLER                  PIC X(01) VALUE '-'.
           05  RL-H1-DD                PIC X(02).
           05  FILLER                  PIC X(17) VALUE SPACES.

       01  RL-HEADER-2.
           05  FILLER                  PIC X(96) VALUE SPACES.
           05  FILLER                  PIC X(09) VALUE 'PAY DATE '.
           05  RL-H2-YYYY              PIC X(04).
           05  FILLER                  PIC X(01) VALUE '-'.
           05  RL-H2-MM                PIC X(02).
           05  FILLER                  PIC X(01) VALUE '-'.
           05  RL-H2-DD                PIC X(02).
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
           05  FILLER                  PIC X(10) VALUE '  PAYMENTS'.
           05  FILLER                  PIC X(10) VALUE '  VOUCHERS'.
           05  FILLER                  PIC X(22) VALUE
               '           AMOUNT PAID'.
           05  FILLER                  PIC X(76) VALUE SPACES.

       01  RL-METHOD-LINE.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  RL-MTH-CODE             PIC X(12).
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  RL-MTH-PAYMENTS         PIC Z(7)9.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  RL-MTH-VOUCHERS         PIC Z(7)9.
           05  RL-MTH-AMOUNT           PIC Z(3),ZZZ,ZZZ,ZZZ,ZZ9.99.
           05  FILLER                  PIC X(76) VALUE SPACES.

       01  RL-BLANK                    PIC X(132) VALUE SPACES.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-VOUCHER
               UNTIL VCH-EOF
           PERFORM 3000-WRITE-PAYMENT
           PERFORM 4000-WRITE-REPORT
           PERFORM 9000-TERMINATE
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.

      *================================================================*
       1000-INITIALIZE.
           PERFORM 1100-READ-CONTROL-CARDS
           PERFORM 1200-LOAD-VENDORS
           MOVE 'ACH' TO WS-MTH-CODE (1)
           MOVE 'CHK' TO WS-MTH-CODE (2)
           PERFORM VARYING WS-SUB FROM 1 BY 1 UNTIL WS-SUB > 2
               MOVE ZERO TO WS-MTH-PAYMENTS (WS-SUB)
                            WS-MTH-VOUCHERS (WS-SUB)
                            WS-MTH-AMOUNT (WS-SUB)
           END-PERFORM
           COMPUTE WS-WINDOW-END = FUNCTION DATE-OF-INTEGER(
                   FUNCTION INTEGER-OF-DATE(WS-PAYDATE)
                   + WS-PAY-WINDOW-DAYS)
           OPEN INPUT VCH-FILE
           IF WS-FS-VCH NOT = '00'
               DISPLAY 'APPAYSL1 OPEN APVOUCHR FAILED FS=' WS-FS-VCH
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           OPEN OUTPUT PAY-FILE HLD-FILE DEF-FILE REPORT-FILE
           IF WS-FS-PAY NOT = '00' OR WS-FS-HLD NOT = '00'
              OR WS-FS-DEF NOT = '00' OR WS-FS-RPT NOT = '00'
               DISPLAY 'APPAYSL1 OPEN OUTPUT FAILED'
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           PERFORM 2100-READ-VOUCHER
           IF VCH-EOF
               DISPLAY 'APPAYSL1 APVOUCHR EMPTY - NOTHING TO PAY'
               MOVE 08 TO WS-RETURN-CODE
           END-IF.

       1100-READ-CONTROL-CARDS.
           OPEN INPUT SYSIN-FILE
           IF WS-FS-SYSIN NOT = '00'
               DISPLAY 'APPAYSL1 OPEN SYSIN FAILED FS=' WS-FS-SYSIN
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           READ SYSIN-FILE
               AT END MOVE SPACES TO SYSIN-REC
           END-READ
           IF SYSIN-REC(1:8) = 'RUNDATE='
              AND SYSIN-REC(9:8) IS NUMERIC
               MOVE SYSIN-REC(9:8) TO WS-RUNDATE
           ELSE
               DISPLAY 'APPAYSL1 BAD CONTROL CARD: ' SYSIN-REC(1:40)
               MOVE 08 TO RETURN-CODE
               STOP RUN
           END-IF
           READ SYSIN-FILE
               AT END MOVE SPACES TO SYSIN-REC
           END-READ
           IF SYSIN-REC(1:8) = 'PAYDATE='
              AND SYSIN-REC(9:8) IS NUMERIC
               MOVE SYSIN-REC(9:8) TO WS-PAYDATE
           ELSE
               DISPLAY 'APPAYSL1 BAD CONTROL CARD: ' SYSIN-REC(1:40)
               MOVE 08 TO RETURN-CODE
               STOP RUN
           END-IF
           CLOSE SYSIN-FILE.

       1200-LOAD-VENDORS.
           OPEN INPUT VND-FILE
           IF WS-FS-VND NOT = '00'
               DISPLAY 'APPAYSL1 OPEN APVENDOR FAILED FS=' WS-FS-VND
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           MOVE 'N' TO WS-LOAD-EOF
           PERFORM UNTIL LOAD-EOF
               READ VND-FILE
                   AT END
                       MOVE 'Y' TO WS-LOAD-EOF
                   NOT AT END
                       ADD 1 TO WS-VND-COUNT
                       IF WS-VND-COUNT > 500
                           DISPLAY 'APPAYSL1 VENDOR TABLE OVERFLOW'
                           MOVE 16 TO RETURN-CODE
                           STOP RUN
                       END-IF
                       MOVE APV-VENDOR-ID
                         TO WS-VND-ID (WS-VND-COUNT)
                       MOVE APV-VENDOR-NAME
                         TO WS-VND-NAME (WS-VND-COUNT)
                       MOVE APV-STATUS
                         TO WS-VND-STATUS (WS-VND-COUNT)
                       MOVE APV-PAY-METHOD
                         TO WS-VND-METHOD (WS-VND-COUNT)
                       ADD 1 TO WS-TOT-VENDORS
               END-READ
           END-PERFORM
           CLOSE VND-FILE.

      *================================================================*
       2000-PROCESS-VOUCHER.
           IF APO-VENDOR-ID NOT = WS-CURR-VENDOR
               PERFORM 3000-WRITE-PAYMENT
               PERFORM 2200-START-VENDOR
           END-IF
           EVALUATE TRUE
               WHEN NOT VND-FOUND
                   MOVE 'H01' TO APH-REASON-CD
                   MOVE 'VENDOR NOT ON FILE' TO APH-REASON-TX
                   PERFORM 2500-HOLD-VOUCHER
               WHEN WS-VND-STATUS (WS-VND-IDX) = 'H'
                   MOVE 'H02' TO APH-REASON-CD
                   MOVE 'VENDOR PAYMENT HOLD' TO APH-REASON-TX
                   PERFORM 2500-HOLD-VOUCHER
               WHEN WS-VND-STATUS (WS-VND-IDX) = 'I'
                   MOVE 'H03' TO APH-REASON-CD
                   MOVE 'VENDOR INACTIVE' TO APH-REASON-TX
                   PERFORM 2500-HOLD-VOUCHER
               WHEN OTHER
                   PERFORM 2300-SELECT-VOUCHER
           END-EVALUATE
           PERFORM 2100-READ-VOUCHER.

       2100-READ-VOUCHER.
           READ VCH-FILE
               AT END MOVE 'Y' TO WS-VCH-EOF
               NOT AT END ADD 1 TO WS-TOT-READ
           END-READ.

       2200-START-VENDOR.
           MOVE APO-VENDOR-ID TO WS-CURR-VENDOR
           MOVE ZERO TO WS-VA-COUNT WS-VA-GROSS WS-VA-DISC
           MOVE 'N' TO WS-VND-FOUND
           SET WS-VND-IDX TO 1
           SEARCH WS-VND-ENTRY
               AT END MOVE 'N' TO WS-VND-FOUND
               WHEN WS-VND-IDX > WS-VND-COUNT
                   MOVE 'N' TO WS-VND-FOUND
               WHEN WS-VND-ID (WS-VND-IDX) = APO-VENDOR-ID
                   MOVE 'Y' TO WS-VND-FOUND
           END-SEARCH
           IF VND-FOUND
               MOVE WS-VND-NAME (WS-VND-IDX)   TO WS-VA-NAME
               MOVE WS-VND-METHOD (WS-VND-IDX) TO WS-VA-METHOD
           END-IF.

       2300-SELECT-VOUCHER.
           MOVE 'N' TO WS-DISC-AVAIL
           IF APO-DISC-AMT > ZERO AND APO-DISC-DATE >= WS-PAYDATE
               MOVE 'Y' TO WS-DISC-AVAIL
           END-IF
           IF NOT DISC-AVAIL AND APO-DUE-DATE > WS-WINDOW-END
               WRITE DEF-REC FROM AP-VCH-REC
               ADD 1 TO WS-TOT-DEFERRED
               ADD APO-NET-AMT TO WS-AMT-DEFERRED
           ELSE
               ADD 1 TO WS-VA-COUNT WS-TOT-PAID
               ADD APO-GROSS-AMT TO WS-VA-GROSS WS-AMT-GROSS
               IF DISC-AVAIL
                   ADD APO-DISC-AMT TO WS-VA-DISC WS-AMT-DISC
                   ADD 1 TO WS-TOT-DISC-TAKEN
               ELSE
                   IF APO-DISC-AMT > ZERO
                       ADD 1 TO WS-TOT-DISC-LOST
                       ADD APO-DISC-AMT TO WS-AMT-DISC-LOST
                   END-IF
               END-IF
               IF APO-PAY-METHOD NOT = WS-VA-METHOD
                   ADD 1 TO WS-TOT-MTH-CHANGED
               END-IF
           END-IF.

       2500-HOLD-VOUCHER.
           MOVE APO-VOUCHER-NO TO APH-VOUCHER-NO
           MOVE APO-INV-NO     TO APH-INV-NO
           MOVE APO-VENDOR-ID  TO APH-VENDOR-ID
           MOVE APO-NET-AMT    TO APH-NET-AMT
           MOVE SPACES TO AP-PHL-REC(78:3)
           WRITE AP-PHL-REC
           ADD 1 TO WS-TOT-HELD
           ADD APO-NET-AMT TO WS-AMT-HELD
           IF WS-RETURN-CODE < 4
               MOVE 4 TO WS-RETURN-CODE
           END-IF.

      *================================================================*
       3000-WRITE-PAYMENT.
           IF WS-CURR-VENDOR NOT = SPACES AND WS-VA-COUNT > ZERO
               ADD 1 TO WS-PAY-SEQ WS-TOT-PAYMENTS
               MOVE SPACES TO AP-PAY-REC
               STRING 'P' WS-RUN-YYMMDD WS-PAY-SEQ
                   DELIMITED BY SIZE INTO APP-PAY-NO
               MOVE WS-CURR-VENDOR TO APP-VENDOR-ID
               MOVE WS-VA-NAME     TO APP-VENDOR-NAME
               MOVE WS-VA-METHOD   TO APP-PAY-METHOD
               MOVE WS-PAYDATE     TO APP-PAY-DATE
               MOVE WS-VA-COUNT    TO APP-VCH-COUNT
               MOVE WS-VA-GROSS    TO APP-GROSS-AMT
               MOVE WS-VA-DISC     TO APP-DISC-AMT
               COMPUTE APP-PAY-AMT = WS-VA-GROSS - WS-VA-DISC
               WRITE AP-PAY-REC
               ADD APP-PAY-AMT TO WS-AMT-PAID
               IF WS-VA-METHOD = 'ACH'
                   MOVE 1 TO WS-SUB
               ELSE
                   MOVE 2 TO WS-SUB
               END-IF
               ADD 1 TO WS-MTH-PAYMENTS (WS-SUB)
               ADD WS-VA-COUNT TO WS-MTH-VOUCHERS (WS-SUB)
               ADD APP-PAY-AMT TO WS-MTH-AMOUNT (WS-SUB)
               MOVE ZERO TO WS-VA-COUNT
           END-IF.

      *================================================================*
       4000-WRITE-REPORT.
           MOVE WS-RUNDATE(1:4) TO RL-H1-YYYY
           MOVE WS-RUNDATE(5:2) TO RL-H1-MM
           MOVE WS-RUNDATE(7:2) TO RL-H1-DD
           MOVE WS-PAYDATE(1:4) TO RL-H2-YYYY
           MOVE WS-PAYDATE(5:2) TO RL-H2-MM
           MOVE WS-PAYDATE(7:2) TO RL-H2-DD
           WRITE REPORT-REC FROM RL-HEADER-1
           WRITE REPORT-REC FROM RL-HEADER-2
           WRITE REPORT-REC FROM RL-BLANK

           MOVE 'SELECTION SUMMARY' TO RL-SEC-TITLE
           WRITE REPORT-REC FROM RL-SECTION
           MOVE 'VENDORS LOADED' TO RL-TC-LABEL
           MOVE WS-TOT-VENDORS TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'VOUCHERS READ' TO RL-TC-LABEL
           MOVE WS-TOT-READ TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'VOUCHERS PAID' TO RL-TC-LABEL
           MOVE WS-TOT-PAID TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'VOUCHERS DEFERRED' TO RL-TC-LABEL
           MOVE WS-TOT-DEFERRED TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'VOUCHERS HELD' TO RL-TC-LABEL
           MOVE WS-TOT-HELD TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'DISCOUNTS TAKEN' TO RL-TC-LABEL
           MOVE WS-TOT-DISC-TAKEN TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'DISCOUNTS LOST' TO RL-TC-LABEL
           MOVE WS-TOT-DISC-LOST TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'PAY METHOD CHANGED' TO RL-TC-LABEL
           MOVE WS-TOT-MTH-CHANGED TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'GROSS PAID' TO RL-TA-LABEL
           MOVE WS-AMT-GROSS TO RL-TA-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-AMOUNT
           MOVE 'DISCOUNT TAKEN' TO RL-TA-LABEL
           MOVE WS-AMT-DISC TO RL-TA-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-AMOUNT
           MOVE 'DISCOUNT LOST' TO RL-TA-LABEL
           MOVE WS-AMT-DISC-LOST TO RL-TA-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-AMOUNT
           MOVE 'AMOUNT PAID' TO RL-TA-LABEL
           MOVE WS-AMT-PAID TO RL-TA-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-AMOUNT
           MOVE 'NET DEFERRED' TO RL-TA-LABEL
           MOVE WS-AMT-DEFERRED TO RL-TA-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-AMOUNT
           MOVE 'NET HELD' TO RL-TA-LABEL
           MOVE WS-AMT-HELD TO RL-TA-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-AMOUNT
           WRITE REPORT-REC FROM RL-BLANK

           MOVE 'PAYMENTS BY METHOD' TO RL-SEC-TITLE
           WRITE REPORT-REC FROM RL-SECTION
           WRITE REPORT-REC FROM RL-METHOD-HDR
           PERFORM VARYING WS-SUB FROM 1 BY 1 UNTIL WS-SUB > 2
               MOVE WS-MTH-CODE (WS-SUB)     TO RL-MTH-CODE
               MOVE WS-MTH-PAYMENTS (WS-SUB) TO RL-MTH-PAYMENTS
               MOVE WS-MTH-VOUCHERS (WS-SUB) TO RL-MTH-VOUCHERS
               MOVE WS-MTH-AMOUNT (WS-SUB)   TO RL-MTH-AMOUNT
               WRITE REPORT-REC FROM RL-METHOD-LINE
           END-PERFORM
           WRITE REPORT-REC FROM RL-BLANK
           MOVE '*** END OF REPORT ***' TO RL-SEC-TITLE
           WRITE REPORT-REC FROM RL-SECTION.

       9000-TERMINATE.
           CLOSE VCH-FILE PAY-FILE HLD-FILE DEF-FILE REPORT-FILE
           DISPLAY 'APPAYSL1 READ=' WS-TOT-READ
                   ' PAID=' WS-TOT-PAID
                   ' DEFERRED=' WS-TOT-DEFERRED
                   ' HELD=' WS-TOT-HELD
                   ' PAYMENTS=' WS-TOT-PAYMENTS
                   ' RC=' WS-RETURN-CODE.
