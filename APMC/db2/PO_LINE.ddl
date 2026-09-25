-- POPROD.PO_LINE - source of AP.PROD.POLINE.UNLOAD (job POXTR010, DSNTIAUL)
-- APMCD010 never touches DB2 directly; it reads the nightly unload file.
CREATE TABLE POPROD.PO_LINE
  ( PO_NO          CHAR(10)       NOT NULL
  , PO_LINE        SMALLINT       NOT NULL
  , VENDOR_ID      CHAR(8)        NOT NULL
  , ITEM_NO        CHAR(10)       NOT NULL
  , ORD_QTY        INTEGER        NOT NULL
  , UNIT_PRICE     DECIMAL(11,4)  NOT NULL
  , LINE_STATUS    CHAR(1)        NOT NULL  -- O open, C closed, H held
  , LAST_UPD_TS    TIMESTAMP      NOT NULL WITH DEFAULT
  , PRIMARY KEY (PO_NO, PO_LINE)
  ) IN APDB01.POLINETS;
