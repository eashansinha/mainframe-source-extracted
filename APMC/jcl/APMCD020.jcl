//APMCD020 JOB (FIN,AP),'AP PAYMENT RUN',CLASS=N,MSGCLASS=X,
//         MSGLEVEL=(1,1),NOTIFY=&SYSUID,REGION=0M
//*-------------------------------------------------------------------*
//* APMCD020 - ACCOUNTS PAYABLE PAYMENT SELECTION AND PAYMENT FILE     *
//*                                                                    *
//* SCHEDULE   : DAILY 03:00 (see ../schedules/APMC-daily.txt)         *
//* PREDECESSOR: APMCD010 (writes AP.PROD.APVOUCHR.DAILY)              *
//*              APMCV001 (vendor master unload)                       *
//* SUCCESSOR  : TRSD100 treasury ACH / check print reads APPAYMT      *
//*                                                                    *
//* STEP010 SORT     vouchers on VENDOR-ID (25,8) / VOUCHER-NO (1,12)  *
//* STEP020 APPAYSL1 select vouchers, write one payment per vendor     *
//*                                                                    *
//* FILES IN                                                           *
//*   AP.PROD.APVOUCHR.DAILY(0)   FB 120  approved vouchers   APVCHREC *
//*   AP.PROD.VENDMAST.UNLOAD     FB  80  vendor master       APVNDREC *
//* FILES OUT                                                          *
//*   AP.PROD.APPAYMT.DAILY(+1)   FB 100  payments            APPAYREC *
//*   AP.PROD.APPAYHLD.DAILY(+1)  FB  80  held vouchers       APPHLREC *
//*   AP.PROD.APPAYDEF.DAILY(+1)  FB 120  deferred vouchers   APVCHREC *
//*   APPAYRPT                    FBA132  payment control report       *
//*                                                                    *
//* RETURN CODES: 0 clean  4 vouchers held                             *
//*               8 empty voucher file or bad SYSIN  16 abend          *
//* RESTART     : from STEP010. Outputs are new GDG generations.       *
//*-------------------------------------------------------------------*
//         JCLLIB ORDER=(AP.PROD.PROCLIB)
//*
//STEP010  EXEC PGM=SORT
//SYSOUT   DD SYSOUT=*
//SORTIN   DD DSN=AP.PROD.APVOUCHR.DAILY(0),DISP=SHR
//SORTOUT  DD DSN=&&VCHSRT,DISP=(NEW,PASS),
//            UNIT=SYSDA,SPACE=(CYL,(5,5),RLSE),
//            DCB=(RECFM=FB,LRECL=120,BLKSIZE=27960)
//SYSIN    DD *
  SORT FIELDS=(25,8,CH,A,1,12,CH,A),EQUALS
/*
//*
//*  DD names match the SELECT ... ASSIGN clauses in APPAYSL1.cbl
//STEP020  EXEC PGM=APPAYSL1,COND=(4,LT,STEP010)
//STEPLIB  DD DSN=AP.PROD.LOADLIB,DISP=SHR
//SYSOUT   DD SYSOUT=*
//SYSUDUMP DD SYSOUT=D
//SYSIN    DD DSN=AP.PROD.PARMLIB(APMCD020),DISP=SHR
//APVOUCHR DD DSN=&&VCHSRT,DISP=(OLD,DELETE)
//APVENDOR DD DSN=AP.PROD.VENDMAST.UNLOAD,DISP=SHR
//APPAYMT  DD DSN=AP.PROD.APPAYMT.DAILY(+1),
//            DISP=(NEW,CATLG,DELETE),UNIT=SYSDA,
//            SPACE=(CYL,(2,1),RLSE),
//            DCB=(RECFM=FB,LRECL=100,BLKSIZE=27900)
//APPAYHLD DD DSN=AP.PROD.APPAYHLD.DAILY(+1),
//            DISP=(NEW,CATLG,DELETE),UNIT=SYSDA,
//            SPACE=(CYL,(1,1),RLSE),
//            DCB=(RECFM=FB,LRECL=80,BLKSIZE=27920)
//APPAYDEF DD DSN=AP.PROD.APPAYDEF.DAILY(+1),
//            DISP=(NEW,CATLG,DELETE),UNIT=SYSDA,
//            SPACE=(CYL,(5,5),RLSE),
//            DCB=(RECFM=FB,LRECL=120,BLKSIZE=27960)
//APPAYRPT DD SYSOUT=(R,,APRP),DCB=(RECFM=FBA,LRECL=132)
//
