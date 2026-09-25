       IDENTIFICATION DIVISION.
       PROGRAM-ID. APEXQUE1.
       AUTHOR. AP-SYSTEMS.
      *================================================================*
      * APEXQUE1 - AP MATCH EXCEPTION WORK QUEUE BUILD                 *
      *                                                                *
      * Run by job APMCD030 STEP010 (see ../jcl/APMCD030.jcl).         *
      * STEP020 then sorts the work items for the clerk screens.       *
      *                                                                *
      * FILES IN                                                       *
      *   SYSIN     RUNDATE=YYYYMMDD                                   *
      *   APEXCEPT  match exceptions from APMCD010         (APEXCREC)  *
      *   APVENDOR  vendor master KSDS unload              (APVNDREC)  *
      * FILES OUT                                                      *
      *   APWRKQU   work items, unsorted -> STEP020 SORT   (APWRKREC)  *
      *   APQRPT    work queue control report (132)                    *
      *                                                                *
      * ROUTING RULES - one work item per exception record:            *
      *  Q1 Queue from reason code:                                    *
      *       E001            -> DUPL  duplicate review                *
      *       E002 E003       -> VNDR  vendor maintenance              *
      *       E004 E008       -> APOP  AP operations                   *
      *       E005-E007 E009-E011 -> BUYR  buyer and receiving         *
      *     Any other code    -> APOP                                  *
      *  Q2 Base priority: E001 = 1, E002/E003 = 2, all others = 3.    *
      *     INV-AMT >= 1,000.00 raises priority one level (3->2,       *
      *     2->1). Priority 1 never changes.                           *
      *  Q3 SLA-DATE = RUNDATE + business days by priority             *
      *     (1 -> 1 day, 2 -> 3 days, 3 -> 5 days). Saturdays and      *
      *     Sundays are skipped; holidays are not (AP-3310).           *
      *  Q4 WORK-ID = 'W' + RUNDATE(YYMMDD) + 4-digit sequence in      *
      *     INPUT order. STEP020 re-sorts by queue, priority, amount   *
      *     descending, invoice, so WORK-IDs are not in file order.    *
      *  Q5 VENDOR-NAME from the vendor master; blank-padded          *
      *     '** NOT ON VENDOR MASTER **' when the vendor is missing.   *
      *                                                                *
      * RETURN CODES  0 clean   4 priority-1 items written             *
      *               8 bad control card   16 abend                    *
      *     An empty exception file is normal (RC 0, empty queue).     *
      *                                                                *
      * CHANGE LOG                                                     *
      *  2009-01-12  AP-0702   initial (single queue)                  *
      *  2013-05-06  AP-1877   queues by reason code (Q1)              *
      *  2016-10-17  AP-3310   business-day SLA dates (Q3)             *
      *  2018-03-26  AP-3902   $1,000 priority escalation (Q2)         *
      *================================================================*
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SYSIN-FILE   ASSIGN TO SYSIN
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-SYSIN.
           SELECT EXC-FILE     ASSIGN TO APEXCEPT
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-EXC.
           SELECT VND-FILE     ASSIGN TO APVENDOR
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-VND.
           SELECT WRK-FILE     ASSIGN TO APWRKQU
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-WRK.
           SELECT REPORT-FILE  ASSIGN TO APQRPT
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-FS-RPT.

       DATA DIVISION.
       FILE SECTION.
       FD  SYSIN-FILE.
       01  SYSIN-REC                   PIC X(80).
       FD  EXC-FILE.
           COPY APEXCREC.
       FD  VND-FILE.
           COPY APVNDREC.
       FD  WRK-FILE.
           COPY APWRKREC.
       FD  REPORT-FILE.
       01  REPORT-REC                  PIC X(132).

       WORKING-STORAGE SECTION.
       01  WS-FILE-STATUS.
           05  WS-FS-SYSIN             PIC X(02).
           05  WS-FS-EXC               PIC X(02).
           05  WS-FS-VND               PIC X(02).
           05  WS-FS-WRK               PIC X(02).
           05  WS-FS-RPT               PIC X(02).

       01  WS-FLAGS.
           05  WS-EXC-EOF              PIC X(01) VALUE 'N'.
               88  EXC-EOF             VALUE 'Y'.
           05  WS-LOAD-EOF             PIC X(01) VALUE 'N'.
               88  LOAD-EOF            VALUE 'Y'.

       01  WS-CONTROL.
           05  WS-RUNDATE              PIC 9(08) VALUE ZERO.
           05  WS-RUNDATE-X REDEFINES WS-RUNDATE.
               10  WS-RUN-CC           PIC X(02).
               10  WS-RUN-YYMMDD       PIC X(06).
           05  WS-RETURN-CODE          PIC 9(02) VALUE ZERO.
           05  WS-WORK-SEQ             PIC 9(04) VALUE ZERO.
           05  WS-PRIORITY             PIC 9(01).
           05  WS-SLA-DAYS             PIC 9(01).
           05  WS-DAYS-ADDED           PIC 9(01).
           05  WS-DATE-INT             PIC 9(08).
           05  WS-DOW                  PIC 9(01).
           05  WS-QUEUE                PIC X(04).

       01  WS-VENDOR-TABLE.
           05  WS-VND-COUNT            PIC 9(04) COMP VALUE ZERO.
           05  WS-VND-ENTRY OCCURS 500 TIMES
                             INDEXED BY WS-VND-IDX.
               10  WS-VND-ID           PIC X(08).
               10  WS-VND-NAME         PIC X(30).

       01  WS-QUEUE-VALUES.
           05  FILLER PIC X(26) VALUE 'APOPAP OPERATIONS'.
           05  FILLER PIC X(26) VALUE 'BUYRBUYER AND RECEIVING'.
           05  FILLER PIC X(26) VALUE 'DUPLDUPLICATE REVIEW'.
           05  FILLER PIC X(26) VALUE 'VNDRVENDOR MAINTENANCE'.
       01  WS-QUEUE-TABLE REDEFINES WS-QUEUE-VALUES.
           05  WS-QDEF OCCURS 4 TIMES.
               10  WS-QDEF-CODE        PIC X(04).
               10  WS-QDEF-TEXT        PIC X(22).
       01  WS-QUEUE-TOTALS.
           05  WS-QTOT OCCURS 4 TIMES.
               10  WS-Q-COUNT          PIC 9(07).
               10  WS-Q-AMOUNT         PIC 9(13)V99.
       01  WS-SUB                      PIC 9(02).

       01  WS-TOTALS.
           05  WS-TOT-VENDORS          PIC 9(07) VALUE ZERO.
           05  WS-TOT-READ             PIC 9(07) VALUE ZERO.
           05  WS-TOT-PRI OCCURS 3 TIMES
                                       PIC 9(07).
           05  WS-TOT-NO-VENDOR        PIC 9(07) VALUE ZERO.
           05  WS-TOT-ESCALATED        PIC 9(07) VALUE ZERO.
           05  WS-TOT-AMOUNT           PIC 9(13)V99 VALUE ZERO.

      *----------------------------------------------------------------*
      * Report lines (132)                                             *
      *----------------------------------------------------------------*
       01  RL-HEADER-1.
           05  FILLER                  PIC X(10) VALUE 'APEXQUE1'.
           05  FILLER                  PIC X(14) VALUE SPACES.
           05  FILLER                  PIC X(52) VALUE
               'AP MATCH EXCEPTIONS - WORK QUEUE CONTROL REPORT'.
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

       01  RL-QUEUE-HDR.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  FILLER                  PIC X(28) VALUE 'QUEUE'.
           05  FILLER                  PIC X(10) VALUE '     ITEMS'.
           05  FILLER                  PIC X(22) VALUE
               '        INVOICE AMOUNT'.
           05  FILLER                  PIC X(70) VALUE SPACES.

       01  RL-QUEUE-LINE.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  RL-Q-CODE               PIC X(04).
           05  FILLER                  PIC X(01) VALUE SPACES.
           05  RL-Q-TEXT               PIC X(23).
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  RL-Q-COUNT              PIC Z(7)9.
           05  RL-Q-AMOUNT             PIC Z(3),ZZZ,ZZZ,ZZZ,ZZ9.99.
           05  FILLER                  PIC X(70) VALUE SPACES.

       01  RL-BLANK                    PIC X(132) VALUE SPACES.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-EXCEPTION
               UNTIL EXC-EOF
           PERFORM 4000-WRITE-REPORT
           PERFORM 9000-TERMINATE
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.

      *================================================================*
       1000-INITIALIZE.
           PERFORM 1100-READ-CONTROL-CARD
           PERFORM 1200-LOAD-VENDORS
           PERFORM VARYING WS-SUB FROM 1 BY 1 UNTIL WS-SUB > 4
               MOVE ZERO TO WS-Q-COUNT (WS-SUB) WS-Q-AMOUNT (WS-SUB)
           END-PERFORM
           MOVE ZERO TO WS-TOT-PRI (1) WS-TOT-PRI (2) WS-TOT-PRI (3)
           OPEN INPUT EXC-FILE
           IF WS-FS-EXC NOT = '00'
               DISPLAY 'APEXQUE1 OPEN APEXCEPT FAILED FS=' WS-FS-EXC
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           OPEN OUTPUT WRK-FILE REPORT-FILE
           IF WS-FS-WRK NOT = '00' OR WS-FS-RPT NOT = '00'
               DISPLAY 'APEXQUE1 OPEN OUTPUT FAILED FS='
                       WS-FS-WRK '/' WS-FS-RPT
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           PERFORM 2100-READ-EXCEPTION.

       1100-READ-CONTROL-CARD.
           OPEN INPUT SYSIN-FILE
           IF WS-FS-SYSIN NOT = '00'
               DISPLAY 'APEXQUE1 OPEN SYSIN FAILED FS=' WS-FS-SYSIN
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
               DISPLAY 'APEXQUE1 BAD CONTROL CARD: ' SYSIN-REC(1:40)
               MOVE 08 TO RETURN-CODE
               STOP RUN
           END-IF
           CLOSE SYSIN-FILE.

       1200-LOAD-VENDORS.
           OPEN INPUT VND-FILE
           IF WS-FS-VND NOT = '00'
               DISPLAY 'APEXQUE1 OPEN APVENDOR FAILED FS=' WS-FS-VND
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
                           DISPLAY 'APEXQUE1 VENDOR TABLE OVERFLOW'
                           MOVE 16 TO RETURN-CODE
                           STOP RUN
                       END-IF
                       MOVE APV-VENDOR-ID
                         TO WS-VND-ID (WS-VND-COUNT)
                       MOVE APV-VENDOR-NAME
                         TO WS-VND-NAME (WS-VND-COUNT)
                       ADD 1 TO WS-TOT-VENDORS
               END-READ
           END-PERFORM
           CLOSE VND-FILE.

      *================================================================*
       2000-PROCESS-EXCEPTION.
           ADD 1 TO WS-WORK-SEQ
           MOVE SPACES TO AP-WRK-REC
           STRING 'W' WS-RUN-YYMMDD WS-WORK-SEQ
               DELIMITED BY SIZE INTO APW-WORK-ID
           PERFORM 2200-ROUTE
           PERFORM 2300-SLA-DATE
           PERFORM 2400-VENDOR-NAME
           MOVE WS-QUEUE        TO APW-QUEUE
           MOVE WS-PRIORITY     TO APW-PRIORITY
           MOVE APX-INV-NO      TO APW-INV-NO
           MOVE APX-VENDOR-ID   TO APW-VENDOR-ID
           MOVE APX-PO-NO       TO APW-PO-NO
           MOVE APX-PO-LINE     TO APW-PO-LINE
           MOVE APX-REASON-CD   TO APW-REASON-CD
           MOVE APX-INV-AMT     TO APW-INV-AMT
           WRITE AP-WRK-REC
           ADD 1 TO WS-TOT-PRI (WS-PRIORITY)
           ADD APX-INV-AMT TO WS-TOT-AMOUNT
           PERFORM VARYING WS-SUB FROM 1 BY 1 UNTIL WS-SUB > 4
               IF WS-QDEF-CODE (WS-SUB) = WS-QUEUE
                   ADD 1 TO WS-Q-COUNT (WS-SUB)
                   ADD APX-INV-AMT TO WS-Q-AMOUNT (WS-SUB)
               END-IF
           END-PERFORM
           IF WS-PRIORITY = 1 AND WS-RETURN-CODE < 4
               MOVE 4 TO WS-RETURN-CODE
           END-IF
           PERFORM 2100-READ-EXCEPTION.

       2100-READ-EXCEPTION.
           READ EXC-FILE
               AT END MOVE 'Y' TO WS-EXC-EOF
               NOT AT END ADD 1 TO WS-TOT-READ
           END-READ.

       2200-ROUTE.
           EVALUATE APX-REASON-CD
               WHEN 'E001'
                   MOVE 'DUPL' TO WS-QUEUE
                   MOVE 1 TO WS-PRIORITY
               WHEN 'E002' WHEN 'E003'
                   MOVE 'VNDR' TO WS-QUEUE
                   MOVE 2 TO WS-PRIORITY
               WHEN 'E004' WHEN 'E008'
                   MOVE 'APOP' TO WS-QUEUE
                   MOVE 3 TO WS-PRIORITY
               WHEN 'E005' WHEN 'E006' WHEN 'E007'
               WHEN 'E009' WHEN 'E010' WHEN 'E011'
                   MOVE 'BUYR' TO WS-QUEUE
                   MOVE 3 TO WS-PRIORITY
               WHEN OTHER
                   MOVE 'APOP' TO WS-QUEUE
                   MOVE 3 TO WS-PRIORITY
           END-EVALUATE
           IF APX-INV-AMT >= 1000.00 AND WS-PRIORITY > 1
               SUBTRACT 1 FROM WS-PRIORITY
               ADD 1 TO WS-TOT-ESCALATED
           END-IF.

       2300-SLA-DATE.
           EVALUATE WS-PRIORITY
               WHEN 1 MOVE 1 TO WS-SLA-DAYS
               WHEN 2 MOVE 3 TO WS-SLA-DAYS
               WHEN OTHER MOVE 5 TO WS-SLA-DAYS
           END-EVALUATE
           COMPUTE WS-DATE-INT = FUNCTION INTEGER-OF-DATE(WS-RUNDATE)
           MOVE ZERO TO WS-DAYS-ADDED
           PERFORM UNTIL WS-DAYS-ADDED = WS-SLA-DAYS
               ADD 1 TO WS-DATE-INT
      *        INTEGER-OF-DATE 1 = MON 1601-01-01; DOW 0=MON .. 6=SUN
               COMPUTE WS-DOW = FUNCTION MOD(WS-DATE-INT - 1, 7)
               IF WS-DOW < 5
                   ADD 1 TO WS-DAYS-ADDED
               END-IF
           END-PERFORM
           COMPUTE APW-SLA-DATE =
                   FUNCTION DATE-OF-INTEGER(WS-DATE-INT).

       2400-VENDOR-NAME.
           MOVE '** NOT ON VENDOR MASTER **' TO APW-VENDOR-NAME
           SET WS-VND-IDX TO 1
           SEARCH WS-VND-ENTRY
               AT END CONTINUE
               WHEN WS-VND-IDX > WS-VND-COUNT
                   CONTINUE
               WHEN WS-VND-ID (WS-VND-IDX) = APX-VENDOR-ID
                   MOVE WS-VND-NAME (WS-VND-IDX) TO APW-VENDOR-NAME
           END-SEARCH
           IF APW-VENDOR-NAME = '** NOT ON VENDOR MASTER **'
               ADD 1 TO WS-TOT-NO-VENDOR
           END-IF.

      *================================================================*
       4000-WRITE-REPORT.
           MOVE WS-RUNDATE(1:4) TO RL-H1-YYYY
           MOVE WS-RUNDATE(5:2) TO RL-H1-MM
           MOVE WS-RUNDATE(7:2) TO RL-H1-DD
           WRITE REPORT-REC FROM RL-HEADER-1
           WRITE REPORT-REC FROM RL-BLANK

           MOVE 'QUEUE SUMMARY' TO RL-SEC-TITLE
           WRITE REPORT-REC FROM RL-SECTION
           MOVE 'VENDORS LOADED' TO RL-TC-LABEL
           MOVE WS-TOT-VENDORS TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'EXCEPTIONS READ' TO RL-TC-LABEL
           MOVE WS-TOT-READ TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'PRIORITY 1 ITEMS' TO RL-TC-LABEL
           MOVE WS-TOT-PRI (1) TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'PRIORITY 2 ITEMS' TO RL-TC-LABEL
           MOVE WS-TOT-PRI (2) TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'PRIORITY 3 ITEMS' TO RL-TC-LABEL
           MOVE WS-TOT-PRI (3) TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'ESCALATED OVER 1,000.00' TO RL-TC-LABEL
           MOVE WS-TOT-ESCALATED TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'VENDOR NOT ON MASTER' TO RL-TC-LABEL
           MOVE WS-TOT-NO-VENDOR TO RL-TC-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-COUNT
           MOVE 'INVOICE AMOUNT QUEUED' TO RL-TA-LABEL
           MOVE WS-TOT-AMOUNT TO RL-TA-VALUE
           WRITE REPORT-REC FROM RL-TOTAL-AMOUNT
           WRITE REPORT-REC FROM RL-BLANK

           MOVE 'ITEMS BY QUEUE' TO RL-SEC-TITLE
           WRITE REPORT-REC FROM RL-SECTION
           WRITE REPORT-REC FROM RL-QUEUE-HDR
           PERFORM VARYING WS-SUB FROM 1 BY 1 UNTIL WS-SUB > 4
               MOVE WS-QDEF-CODE (WS-SUB) TO RL-Q-CODE
               MOVE WS-QDEF-TEXT (WS-SUB) TO RL-Q-TEXT
               MOVE WS-Q-COUNT (WS-SUB)   TO RL-Q-COUNT
               MOVE WS-Q-AMOUNT (WS-SUB)  TO RL-Q-AMOUNT
               WRITE REPORT-REC FROM RL-QUEUE-LINE
           END-PERFORM
           WRITE REPORT-REC FROM RL-BLANK
           MOVE '*** END OF REPORT ***' TO RL-SEC-TITLE
           WRITE REPORT-REC FROM RL-SECTION.

       9000-TERMINATE.
           CLOSE EXC-FILE WRK-FILE REPORT-FILE
           DISPLAY 'APEXQUE1 READ=' WS-TOT-READ
                   ' PRI1=' WS-TOT-PRI (1)
                   ' RC=' WS-RETURN-CODE.
