//APMCD010 JOB (FIN,AP),'AP 3-WAY MATCH',CLASS=N,MSGCLASS=X,
//         MSGLEVEL=(1,1),NOTIFY=&SYSUID,REGION=0M
//*-------------------------------------------------------------------*
//* APMCD010 - ACCOUNTS PAYABLE THREE-WAY MATCH AND VOUCHERING         *
//*                                                                    *
//* SCHEDULE   : DAILY 01:30 (see ../schedules/APMC-daily.txt)         *
//* PREDECESSOR: APMCD005 (invoice intake) POXTR010 (PO unload)        *
//*              RCVXT010 (receipts extract) APMCV001 (vendor unload)  *
//* SUCCESSOR  : APMCD020 payment run reads AP.PROD.APVOUCHR.DAILY(0)  *
//*              APMCD030 clerk work queue reads APEXCEPT.DAILY(0)     *
//*                                                                    *
//* STEP010 SORT     invoice feed on VENDOR-ID (13,8) / INV-NO (1,12)  *
//* STEP020 APMATCH1 three-way match, write vouchers and exceptions    *
//*                                                                    *
//* FILES IN                                                           *
//*   AP.PROD.APINVOIC.DAILY(0)   FB 100  invoice feed        APINVREC *
//*   AP.PROD.POLINE.UNLOAD       FB  80  open PO lines       APPOREC  *
//*   AP.PROD.RECEIPTS.DAILY(0)   FB  60  receipts            APRCVREC *
//*   AP.PROD.VENDMAST.UNLOAD     FB  80  vendor master       APVNDREC *
//* FILES OUT                                                          *
//*   AP.PROD.APVOUCHR.DAILY(+1)  FB 120  approved vouchers   APVCHREC *
//*   AP.PROD.APEXCEPT.DAILY(+1)  FB  80  match exceptions    APEXCREC *
//*   APRPT                       FBA132  match control report         *
//*                                                                    *
//* RETURN CODES: 0 clean  4 exceptions written                        *
//*               8 empty feed or bad SYSIN  16 abend                  *
//* RESTART     : from STEP010. Outputs are new GDG generations, so a  *
//*               rerun never pays an invoice twice.                   *
//*-------------------------------------------------------------------*
//         JCLLIB ORDER=(AP.PROD.PROCLIB)
//*
//STEP010  EXEC PGM=SORT
//SYSOUT   DD SYSOUT=*
//SORTIN   DD DSN=AP.PROD.APINVOIC.DAILY(0),DISP=SHR
//SORTOUT  DD DSN=&&INVSRT,DISP=(NEW,PASS),
//            UNIT=SYSDA,SPACE=(CYL,(5,5),RLSE),
//            DCB=(RECFM=FB,LRECL=100,BLKSIZE=27900)
//SYSIN    DD *
  SORT FIELDS=(13,8,CH,A,1,12,CH,A),EQUALS
/*
//*
//*  DD names match the SELECT ... ASSIGN clauses in APMATCH1.cbl
//STEP020  EXEC PGM=APMATCH1,COND=(4,LT,STEP010)
//STEPLIB  DD DSN=AP.PROD.LOADLIB,DISP=SHR
//SYSOUT   DD SYSOUT=*
//SYSUDUMP DD SYSOUT=D
//SYSIN    DD DSN=AP.PROD.PARMLIB(APMCD010),DISP=SHR
//APINVOIC DD DSN=&&INVSRT,DISP=(OLD,DELETE)
//APPOLINE DD DSN=AP.PROD.POLINE.UNLOAD,DISP=SHR
//APRCVLN  DD DSN=AP.PROD.RECEIPTS.DAILY(0),DISP=SHR
//APVENDOR DD DSN=AP.PROD.VENDMAST.UNLOAD,DISP=SHR
//APVOUCHR DD DSN=AP.PROD.APVOUCHR.DAILY(+1),
//            DISP=(NEW,CATLG,DELETE),UNIT=SYSDA,
//            SPACE=(CYL,(10,5),RLSE),
//            DCB=(RECFM=FB,LRECL=120,BLKSIZE=27960)
//APEXCEPT DD DSN=AP.PROD.APEXCEPT.DAILY(+1),
//            DISP=(NEW,CATLG,DELETE),UNIT=SYSDA,
//            SPACE=(CYL,(2,1),RLSE),
//            DCB=(RECFM=FB,LRECL=80,BLKSIZE=27920)
//APRPT    DD SYSOUT=(R,,APRP),DCB=(RECFM=FBA,LRECL=132)
//
