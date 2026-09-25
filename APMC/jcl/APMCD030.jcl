//APMCD030 JOB (FIN,AP),'AP EXCEPTION QUEUE',CLASS=N,MSGCLASS=X,
//         MSGLEVEL=(1,1),NOTIFY=&SYSUID,REGION=0M
//*-------------------------------------------------------------------*
//* APMCD030 - AP MATCH EXCEPTION WORK QUEUE FOR AP CLERKS             *
//*                                                                    *
//* SCHEDULE   : DAILY 05:00 (see ../schedules/APMC-daily.txt)         *
//* PREDECESSOR: APMCD010 (writes AP.PROD.APEXCEPT.DAILY)              *
//*              APMCV001 (vendor master unload)                       *
//* SUCCESSOR  : AP clerk work queue screens (online) read APWRKQ      *
//*                                                                    *
//* STEP010 APEXQUE1 route, prioritise and date each exception         *
//* STEP020 SORT     work items on QUEUE (12,4) / PRIORITY (16,1) /    *
//*                  INV-AMT (92,11) descending / INV-NO (25,12)       *
//*                                                                    *
//* FILES IN                                                           *
//*   AP.PROD.APEXCEPT.DAILY(0)   FB  80  match exceptions    APEXCREC *
//*   AP.PROD.VENDMAST.UNLOAD     FB  80  vendor master       APVNDREC *
//* FILES OUT                                                          *
//*   AP.PROD.APWRKQ.DAILY(+1)    FB 120  clerk work items    APWRKREC *
//*   APQRPT                      FBA132  work queue control report    *
//*                                                                    *
//* RETURN CODES: 0 clean  4 priority-1 items written                  *
//*               8 bad SYSIN  16 abend                                *
//* RESTART     : from STEP010.                                        *
//*-------------------------------------------------------------------*
//         JCLLIB ORDER=(AP.PROD.PROCLIB)
//*
//*  DD names match the SELECT ... ASSIGN clauses in APEXQUE1.cbl
//STEP010  EXEC PGM=APEXQUE1
//STEPLIB  DD DSN=AP.PROD.LOADLIB,DISP=SHR
//SYSOUT   DD SYSOUT=*
//SYSUDUMP DD SYSOUT=D
//SYSIN    DD DSN=AP.PROD.PARMLIB(APMCD030),DISP=SHR
//APEXCEPT DD DSN=AP.PROD.APEXCEPT.DAILY(0),DISP=SHR
//APVENDOR DD DSN=AP.PROD.VENDMAST.UNLOAD,DISP=SHR
//APWRKQU  DD DSN=&&WRKQU,DISP=(NEW,PASS),
//            UNIT=SYSDA,SPACE=(CYL,(2,1),RLSE),
//            DCB=(RECFM=FB,LRECL=120,BLKSIZE=27960)
//APQRPT   DD SYSOUT=(R,,APRP),DCB=(RECFM=FBA,LRECL=132)
//*
//STEP020  EXEC PGM=SORT,COND=(4,LT,STEP010)
//SYSOUT   DD SYSOUT=*
//SORTIN   DD DSN=&&WRKQU,DISP=(OLD,DELETE)
//SORTOUT  DD DSN=AP.PROD.APWRKQ.DAILY(+1),
//            DISP=(NEW,CATLG,DELETE),UNIT=SYSDA,
//            SPACE=(CYL,(2,1),RLSE),
//            DCB=(RECFM=FB,LRECL=120,BLKSIZE=27960)
//SYSIN    DD *
  SORT FIELDS=(12,4,CH,A,16,1,CH,A,92,11,CH,D,25,12,CH,A),EQUALS
/*
//
