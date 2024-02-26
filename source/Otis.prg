/*
 * Build with MINIGUI HMG Extended - Harbour Win32
 *
 * OTIS.PRG - Open table inspector dbf browser tool.
 *
 * Copyright 2020-2021 Hans Marc (Belgium).
 *
 * This code was written while the world was fighting against the 'Corona virus'
 * and i had some time available. (mars 2020 - ... 2021)
 *
*/

// Includes
#include "minigui.ch"
#include "i_hmgcompat.ch"
#include "HBGTINFO.CH"
#include "tsbrowse.ch"
#include "dbinfo.ch"
#include "dbstruct.ch"
#include "error.ch"
#include "ord.ch"
#include "directry.ch"
// include all harbour code pages
#include "hbextcdp.ch"

// Includes for LETODBF
#include "RDDLETO.ch"
#include "LETO_STD.ch"

// Include only if necessary
// All harbour file function are xtranslated by there corresponding leto function.
//#include "LETOFILE.ch"


//****************************************************************************************************************
// Defines, they are not placed in a separated include folder and file to make it easier to
//          integrate this file in your own project.
//          With this method only this prg file needs to be included into your own project.
//****************************************************************************************************************

// Version info
#define  Version        "V1.50"
#define  Versiondate    "26/02/2024"
#define  Versionbuild   "B01"

// aOtables array offsets   (array used in tbrowse in main form)
#define  ATI_ALIAS      1
#define  ATI_AREA       2
#define  ATI_RDD        3
#define  ATI_ISSELECTED 4
#define  ATI_ISLOCKED   5
#define  ATI_RECNO      6
#define  ATI_RECCNT     7
#define  ATI_CURIND     8
#define  ATI_INDCNT     9
#define  ATI_FN         10

// invalid filename name chars
#define def_invfnchars      "-#%&{}\<>*?/*!"+"'"+'"'+":@"

// Definitions for nMode var in Struct_editor()
#define  se_append       1
#define  se_insert       2
#define  se_modify       3

// definitions for CARGO property of form dv_viewer array
#define  dvc_alias       1
#define  dvc_recno       2
#define  dvc_indfocus    3
#define  dvc_filter      4
#define  dvc_ScopeTop    5
#define  dvc_ScopeBottom 6

// definitions OrderInfo_xxx for aIndexInfo array
#define OI_BAGNAME       1
#define OI_TAG           2
#define OI_KEY           3
#define OI_FOR           4
#define OI_UNIQUE        5          // unique
#define OI_ASCDESC       6          // ascending, descending

// default settings
// Some tables areas are reserved
#define def_Otisdb_area_nr          "65534"    // ATTENTION : 2^16 = 65535,0xFFFF is not accepted by Harbour as area nr
#define def_ini_lockscheme          "4"
#define def_area_min_scan           "1"
#define def_area_max_scan           "1000"
#define def_area_pi_reopen_start    "10000"
#define def_area_reopen             .T.
// Leto default
#define def_ini_leto_ipserver       'localhost'
#define def_ini_leto_portserver     "2812"
// command line mode defaults
#define def_ini_cl_autopen          .T.
#define def_ini_cl_excl             .F.

//****************************************************************************************************************

// some translations
#define  crlf     hb_eol()

//******************************************************************************


// Statics for Dbfviewer
// ** TODO, not used for the moment. **
Static nOpenindexfiles,;         // number of opened index files
       nTempindexcnt := 0,;      // number of new created temporary index files.
       fOpenedMan := .F.         // used to detect if we opened files manually because there were no open files
                                 // in the current running program and we have to close them when this window is released.

// static array used by freadini() and fwriteini()
STATIC ar_ini := {}

// Statics for search / replace functions  (from DbfView of Grigory Filatov)
Static aSearch := {}, aReplace := {}, ;
       nSearch := 1, nReplace := 1, nColumns := 1, ;
       lMatchCase := .F., lMatchWhole := .F., nDirect := 3

Static lOldDel, ;                // used to save current SET_DELETE status
       nOldSel                   // idem current area nr


// Statics for structure editor
//
//                    Full descript       ID  LEN (if 00 len is variable)
Static aTypes := { { "Character",         "C", 00 }, ;
                   { "Numeric",           "N", 00 }, ;
                   { "Date",              "D", 08 }, ;
                   { "Logical",           "L", 01 }, ;
                   { "Memo",              "M", 10 }, ;
                   { "Date     3 (ext.)", "D", 03 }, ;
                   { "Date     4 (ext.)", "D", 04 }, ;
                   { "Memo     4 (ext.)", "M", 04 }, ;
                   { "AutoInc  4 (ext.)", "+", 04 }, ;
                   { "ModTime  8 (ext.)", "=", 08 }, ;
                   { "RowVers  8 (ext.)", "^", 08 }, ;
                   { "Time     4 (ext.)", "T", 04 }, ;
                   { "DayTime  8 (ext.)", "@", 08 }, ;
                   { "Integer  1 (ext.)", "I", 01 }, ;
                   { "Integer  2 (ext.)", "I", 02 }, ;
                   { "Integer  3 (ext.)", "I", 03 }, ;
                   { "Integer  4 (ext.)", "I", 04 }, ;
                   { "Integer  8 (ext.)", "I", 08 }, ;
                   { "Variant  3 (ext.)", "V", 03 }, ;
                   { "Variant  4 (ext.)", "V", 04 }, ;
                   { "Variant  6 (ext.)", "V", 06 }, ;
                   { "Variant  x (ext.)", "V", 00 }, ;
                   { "Currency 8 (ext.)", "Y", 08 }, ;
                   { "Double   8 (ext.)", "B", 08 } ;
                 }


//******************************************************************************

// Externals that could possibly be used in expressions like in a index KEY, FOR, ...
REQUEST ABS, ALLTRIM, AT, CHR, CTOD, CDOW, CMONTH, DATE, DAY, DELETED, DESCEND, DTOC, ;
        DTOS, DOW, EMPTY, I2BIN, L2BIN, LEFT, LEN, LOWER, LTRIM, MAX, MIN, MONTH, OS, ;
        PAD, PADC, PADL, PADR, RAT, RECNO, RIGHT, ROUND, RTRIM, SPACE, STOD, STR, ;
        STRZERO, SUBSTR, REPLICATE, TIME, TRANSFORM, TRIM, UPPER, VAL, VALTYPE, YEAR, ;
        SOUNDEX

//******************************************************************************

// memvar declarations (mostly public vars)
MEMVAR th_w_width
MEMVAR th_w_height
MEMVAR th_w_ctrlgap
MEMVAR th_bt_width
MEMVAR th_bt_height

MEMVAR th_w_fontcolor
MEMVAR th_w_bgcolor

MEMVAR th_bt_fontcol
MEMVAR th_bt_bgcol
MEMVAR th_bt_ohfontcol
MEMVAR th_bt_ohbgcol

MEMVAR th_fctb_leven
MEMVAR th_bgtb_leven
MEMVAR th_fctb_lodd
MEMVAR th_bgtb_lodd

MEMVAR ini_lOpen_Exclusive, ;          // default is open files in shared mode.
       ini_default_rdd, ;
       ini_default_mem, ;
       ini_dbf_codepage

// set version vars, set by freadini but init with #defines (see above) after it.
MEMVAR ini_version, ;
       ini_versiondate, ;
       ini_versionbuild

// 5 Most recent Datasets
MEMVAR ini_mr_ds1, ;
       ini_mr_ds2, ;
       ini_mr_ds3, ;
       ini_mr_ds4, ;
       ini_mr_ds5

// Last used folder to open files
MEMVAR ini_lu_folder

// locking scheme
MEMVAR ini_lockscheme

// color theme number
MEMVAR ini_theme

// cmdline options
MEMVAR ini_cl_autopen
MEMVAR ini_cl_excl

// AutoOpen orderbags flag,  ATTENTION only for CDX or NSX files
MEMVAR ini_ordbag_autoopen

// Some area settings
// area nr to open OTIS_DS.DBF  (can be changed in ini file if there is a conflict)
MEMVAR ini_Otisdb_area_nr
// area nr scanned when used in plugin mode
MEMVAR ini_area_min_scan
MEMVAR ini_area_max_scan
MEMVAR ini_area_pi_reopen_start
// flag NOT USED for the moment
MEMVAR ini_area_reopen

// LetoDbf server settings
MEMVAR ini_leto_ipserver
MEMVAR ini_leto_portserver

MEMVAR aOtables
MEMVAR lDsChanged

MEMVAR cMacro, cMacro1  // used everywhere for &macro substitution
MEMVAR aDefaultRdd      // array filled with rdd drivers
MEMVAR aDefaultMem      // array filled with rdd memo file drivers

MEMVAR fn_ini
MEMVAR fn_ds_table

MEMVAR pu_fontname, pu_fontsize

MEMVAR aCopyPaste

MEMVAR cCmdLine

MEMVAR pi_area_cnt

MEMVAR cWhoSetFocustoMain

MEMVAR lStandAlone

MEMVAR lSimul_PlugIn_mode

MEMVAR oError

MEMVAR tb_Otis, tb_delindex, tb_Dv_Browse, tb_Dv_Vis

MEMVAR aDatasets
MEMVAR o_Dsmng_browse

MEMVAR HMG_ModalDialogReturn

MEMVAR cInfo
MEMVAR BRW_2, aStruct

//******************************************************************************

//
// Main form OTIS : Open Table InSpector
//
Function OTIS()

   // Locals
   LOCAL temp, i, x, ;                          // some common vars used everywhere
         cAlias, ;                              // alias name of area
         aButtons := {}, ;                      // left menubar array
         ;//nCurrec, nCurind, cCurflt, ;           // environment vars, record, index, filter
         lFlgopen,;                             // used for first rappid check if tables are opened when Otis is called.
         aTokens

   LOCAL cFontname, nFontsize
   LOCAL lReOpenOk, cUseName, nOrdernr, nRecno, cFilter
   LOCAL nOrdercnt

   MEMVAR aCodepage
   Private aCodepage

//******************************************************************************
// Define Theme variables
//******************************************************************************

   // metrics
   Public th_w_width                            // OTIS main window width
   Public th_w_height                           // OTIS main window height
   Public th_w_ctrlgap                          // OTIS main window border and control gap
   Public th_bt_width                           // menu button width
   Public th_bt_height                          // menu button height

   // window colors
   Public th_w_fontcolor                        // window font color
   Public th_w_bgcolor                          // window bg color

   // colors settings for menu buttons and some controls
   Public th_bt_fontcol                         // font color
   Public th_bt_bgcol                           // font bg color
   Public th_bt_ohfontcol                       // on hover font color
   Public th_bt_ohbgcol                         // on hover bg color

   // color settings for tbrowse() line colors
   public th_fctb_leven, th_bgtb_leven, th_bgtb_lodd,  th_fctb_lodd

   //******************************************************************************
   // otis.ini file vars
   //******************************************************************************

   // Init program wide publics
   // These vars are saved or restored in or from a ini file.
   // If the ini file does not exist it will be created automaticely by FREADINI()

   // rdd settings
   PUBLIC ini_lOpen_Exclusive := .F.,;          // default is open files in shared mode.
          ini_default_rdd   := "DBFCDX"         // default dbf rdd driver
          ini_default_mem   := "DBFFPT"         // default memofield driver (dbt or fpt)
          ini_dbf_codepage  := 'FRWIN'          // default dbf code page

   // set version vars, set by freadline but init with #defines (see above) after it.
   Public ini_version      := "",;
          ini_versiondate  := "",;
          ini_versionbuild := ""

   // 5 Most recent Datasets
   PUBLIC ini_mr_ds1 := "",;
          ini_mr_ds2 := "",;
          ini_mr_ds3 := "",;
          ini_mr_ds4 := "",;
          ini_mr_ds5 := ""

   // Last used folder to open files
   Public ini_lu_folder := hb_dirbase()         // default program exe folder

   // locking scheme
   Public ini_lockscheme := hb_ntos(DB_DBFLOCK_HB32)

   // color theme number
   Public ini_theme := "1"                      // default color theme

   // cmdline options
   Public ini_cl_autopen := def_ini_cl_autopen  // cmdline orderbag autopen mode
   Public ini_cl_excl    := def_ini_cl_excl     // cmdline open exclusive mode

   // AutoOpen orderbags flag,  ATTENTION only for CDX or NSX files
   Public ini_ordbag_autoopen := .F.

   // Some area settings
   //   area nr to open OTIS_DS.DBF  (can be changed in ini file if there is a conflict)
   Public ini_Otisdb_area_nr       := def_Otisdb_area_nr
   //   area nr scanned when used in plugin mode
   Public ini_area_min_scan        := def_area_min_scan
   Public ini_area_max_scan        := def_area_max_scan
   Public ini_area_pi_reopen_start := def_area_pi_reopen_start
   //   flag NOT USED for the moment
   Public ini_area_reopen          := def_area_reopen

   // LetoDbf server settings
   Public ini_leto_ipserver        := "   .   .   .   "
   Public ini_leto_portserver      := "2812"

   //*** some other Privates & publics ********************************************

   PRIVATE aOtables := {}                       // Dataset array with open files info displayed in the main browse.
   PRIVATE lDsChanged := .F.                    // flag to indicate if a dataset has been modified after loading one
                                                // or when creating a new dataset from empty.

   //
   Public cMacro, cMacro1                       // used everywhere for &macro substitution
   Public aDefaultRdd                           // array filled with rdd drivers
   Public aDefaultMem                           // array filled with rdd memo file drivers

   // ini and dataset table path
   // use hb_dirbase and not getcurrentfolder() to localize the .ini file.
   Public fn_ini      := hb_dirbase() + "\Otis.ini"     // ini filename
   Public fn_ds_table := hb_dirbase() + "\Otis_ds.dbf"  // Otis dataset table name.

   // fontname and size
   public pu_fontname, pu_fontsize
   pu_fontname := {'Segoe','Calibri','Arial','Courier'}[1]
   pu_fontsize := 10

   // record copy / paste buffer array (details see dv_cp_rec() )
   public aCopyPaste := {}  // multi dim, { { fieldname, data } }

   // cmdline var filled with command line arguments
   public cCmdLine := hb_CmdLine()
   //msgstop(cCmdline)

   // area counter used in STANDALONE mode if no area number is found in otis_ds.dbf
   // area counter used in PLUGIN mode to add files manually to the
   // already opened files by the running program
   public pi_area_cnt := 1

   // Id of form that set the focus back to the Main Otis window
   // used as trigger to exit Dataset manager immediatelly in command line mode.
   // see ON GOTFOCUS in form_otis.
   public cWhoSetFocustoMain := ""

   //******************************************************************************

   //
   // Set lStandAlone flag.
   //
   //   This flag is .T. if otis is launched as a executable thus StandAlone.
   //   As explained you can include Otis.prg in your own code/program or use otis.lib.
   //   We need this flag to init all settings 'SET()' if it is launched as a exe
   //   or inherite the settings from your program
   //   and to open the main form as MAIN or STANDARD.
   //   We do this by checking if the 'Application.ExeName' contains the keyword 'OTIS'.
   //
   Public lStandAlone
   lStandAlone := if( 'OTIS' $ hb_FNameNameExt(UPPER(Application.ExeName)), .T., .F. )
   *msgstop(hb_FNameNameExt(UPPER(Application.ExeName)))
   *msgstop(lStandAlone)

   // For testing, set to .T. if you want to emulate plugin mode when in standalone exe
   Public lSimul_PlugIn_mode := .F.

   // TEST :
   // to simulate 'plugin mode' when in exe mode set flag to .F. and
   //  open some files
   /*
   ANNOUNCE RDDSYS
   REQUEST  DBFCDX
   REQUEST  DBFFPT
   REQUEST  DBFDBT
   RDDSETDEFAULT("DBFCDX")
   Set( _SET_EXCLUSIVE, .F.)
   * override mode
   lStandalone := .F.
   lSimul_PlugIn_mode := .T.
   *
   select 1
   use data\client alias client
   set index to data\iclieref.cdx, data\iclienom.cdx
   set filter to left(refer,1)=='T'
   set order to 2
   goto top
   *
   select 2
   use data\produit alias produit
   set index to data\iprodnum.cdx, data\iprodnom.cdx
   set order to 1
   goto 150
   */

   //******************************************************************************

   //
   // STANDALONE mode
   //   Set all default settings
   //
   IF lStandAlone

      // Load RDD drivers
      ANNOUNCE RDDSYS
      REQUEST  DBFCDX
      REQUEST  DBFNTX
      REQUEST  LETO
      REQUEST  SIXCDX
      REQUEST  DBFNSX
      *
      REQUEST  DBFFPT
      REQUEST  DBFDBT

      // fill combobox rdd array with previous requested rdds
      aDefaultRdd := { "DBFCDX", "DBFNTX", "LETO", "DBFNSX", "SIXCDX" }
      // idem memo rdd drivers
      aDefaultMem := { "DBFFPT", "DBFDBT" }

      // set default rdd driver
      RDDSETDEFAULT("DBFCDX")

      // Set locking scheme so dbf filesize can be maximum 4GB,
      // we have clients with files bigger than 1.5GB  and if this value is not set
      // random dbfcdx/1010 dos error 33 will occur in a multi-user network environment
      // because file locking size is limited to 1GB.
      // Default 0.
      //
      /* Other locking schemes from dbinfo.ch
      // LOCK SCHEMES: RDDI_LOCKSCHEME, DBI_LOCKSCHEME
      #define DB_DBFLOCK_DEFAULT      0
      #define DB_DBFLOCK_CLIPPER      1   // default Cl*pper locking scheme
      #define DB_DBFLOCK_COMIX        2   // COMIX and CL53 DBFCDX hyper locking scheme
      #define DB_DBFLOCK_VFP          3   // [V]FP, CL52 DBFCDX, SIx3 SIXCDX, CDXLOCK.OBJ
      #define DB_DBFLOCK_HB32         4   // Harbour hyper locking scheme for 32-bit file API, table size max 4GB
      #define DB_DBFLOCK_HB64         5   // Harbour hyper locking scheme for 64-bit file API, table size no limit
      #define DB_DBFLOCK_CLIPPER2     6   // extended Cl*pper locking scheme NTXLOCK2.OBJ
      */
      SET(_SET_DBFLOCKSCHEME, DB_DBFLOCK_HB32 )       // 4 = max 4GB

      // default open files in shared mode, overwritten by read ini file below
      ini_lOpen_Exclusive := .F.
      Set( _SET_EXCLUSIVE, ini_lOpen_Exclusive )

      // DO or DO NOT auto open orderbags files with the same name as the table.
      Set( _SET_AUTOPEN, ini_ordbag_autoopen)

      // RDD CODEPAGE settings
      // Database Codepage requests
      // no longe necessary to load individually see below.
      /*
      REQUEST HB_CODEPAGE_ES850C
      REQUEST HB_CODEPAGE_FR850
      REQUEST HB_CODEPAGE_FRWIN
      REQUEST HB_CODEPAGE_PT850
      REQUEST HB_CODEPAGE_RU1251
      REQUEST HB_CODEPAGE_RU866
      REQUEST HB_CODEPAGE_RUKOI8
      *
      aCodepage := { "ES850C",;
                     "FR850" ,;
                     "FRWIN" ,;
                     "PT850" ,;
                     "RU1251",;
                     "RU866" ,;
                     "RUKOI8" }
      */
      // ******
      //   OR
      // ******
      // fill combobox array with previous requested cp
      // all codepage are loaded by the #include "hbextcdp.ch"
      aCodepage := hb_cdpList()

      // set default codepage
      hb_cdpSelect('FRWIN' )

      // debug
      //msgstop(hb_cdpSelect())

      // Program Language setting EN
      REQUEST HB_LANG_EN
      HB_LANGSELECT('EN')
      //REQUEST HB_LANG_FR
      //HB_LANGSELECT('FR')

      // date
      SET CENTURY ON
      SET EPOCH TO 1950
      SET DATE BRITISH

      // error reporting
      SET SHOWREDALERT OFF
      SET ShowDetailError ON

      // tooltip style
      SET TOOLTIP ON
      SET TOOLTIPBALLOON ON
      //SET TOOLTIPBACKCOLOR { 255 , 255 , 255 }
      //SET TOOLTIPFORECOLOR { 0 , 0 , 0 }

      // center message box in parent
      SET CENTERWINDOW RELATIVE PARENT

      // numeric
      SET FIXED ON
      SET DECIMALS TO 2

      // TODO : right select multiple files in explorer and right click 'OPEN'
      //        open only one otis.exe with all files explorer_selected in a dataset
      //
      //SET MULTIPLE OFF WARNING

      // divers
      SET CONFIRM ON
      SET BELL ON

      // set navigation extended mode, Enter key behaves like Tab key
      SET NAVIGATION EXTENDED
      SET BROWSESYNC ON

      // default icon
      SET DEFAULT ICON TO "MAINICON"

      // set
      SET WINDOW MODAL PARENT HANDLE ON

   //
   // PLUGIN mode, otis.prg or otis.lib intergrated in your prg
   //    settings for OTIS are inherited from your program code.
   ELSE

      // fill combobox with settings from running program.
      aDefaultRdd     := RDDLIST()               // ex. { "DBFCDX", "DBFNTX", "DBFNSX", }
      ini_default_rdd := RDDSETDEFAULT()

      // idem memo type file
      aDefaultMem := { "DBFFPT", "DBFDBT" }

      // init orderbags autopen flag
      ini_ordbag_autoopen := Sx_AutoOpen()

      // fill combobox array with all codepages in running program
      aCodepage := hb_cdpList()

      // and set current table codepage
      //ini_dbf_codepage := hb_cdpSelect()

   ENDIF

   // save _SET_DELETE status
   lOldDel := SET(_SET_DELETED)

   // save the current area nr
   nOldSel := SELECT()

   //******************************************************************************

   // Create a empty dataset table file if this table is not found in the Otis.exe program folder
   // Each folder can and will have its own OTIS_DS.DBF dataset table if you copie OTIS.EXE
   // in a folder or when you include otis.prg in your project / program.
   if !file(fn_ds_table)
      ds_create_ds_table()
   endif

   //******************************************************************************
   //
   // load ini file, it overwrites public vars declared above.
   //
   FREADINI( fn_ini )

   // set rdddefault with setting from ini file
   RDDSETDEFAULT( ini_default_rdd )

   // AutoOpen flag is forced to false if ini setting for rdd
   //   is DBFNTX because it does not support AutoOpen.
   if ini_default_rdd=="DBFNTX"
      ini_ordbag_autoopen := .F.
   endif

   // set orderbags AutoOpen with setting from ini file
   Set( _SET_AUTOPEN, ini_ordbag_autoopen)

   // reinit ini_version vars they are overwritten by freadini()
   // and could contain old values. Fwriteini() will update ini file at exit.
   ini_version      := Version
   ini_versiondate  := Versiondate
   ini_versionbuild := Versionbuild

   // Standalone mode
   if lStandalone

      // set open exclusive mode with setting in ini file
      Set( _SET_EXCLUSIVE, ini_lOpen_Exclusive )

      // restore locking scheme
      // but check first for invalid values restored from ini file
      ini_lockscheme := val(ini_lockscheme)
      if ini_lockscheme < 0 .or. ini_lockscheme > 6
         msgstop("A invalid filelocking scheme is defined in the ini file." + crlf + ;
                 "Otis will use by default scheme 4, (DB_DBFLOCK_HB32).")
         ini_lockscheme := DB_DBFLOCK_HB32
      endif
      SET(_SET_DBFLOCKSCHEME, ini_lockscheme )

   // Plugin mode
   // it inherits from the running program independend of the ini file
   else
      ini_lOpen_Exclusive := Set( _SET_EXCLUSIVE )
   endif

   // set all area values with setting in ini file
   //  convert them all from C to N
   ini_Otisdb_area_nr       := val(ini_Otisdb_area_nr)
   ini_area_min_scan        := val(ini_area_min_scan)
   ini_area_max_scan        := val(ini_area_max_scan)
   ini_area_pi_reopen_start := val(ini_area_pi_reopen_start)

   // set add area counter to ghost area counter
   // if in PLUGIN mode
   // or
   // in command line mode
   if !lStandalone .or. !empty(cCmdline)
      pi_area_cnt := ini_area_pi_reopen_start + ini_area_max_scan
   endif

   // set theme vars
   set_theme(ini_theme)

   //******************************************************************************

   // Create header font for Tbrowse controls
   IF ! _IsControlDefined("FontBold","Main")
      cFontname := _HMG_DefaultFontName     // current font name
      nFontsize := _HMG_DefaultFontSize     // current font size
      DEFINE FONT FontBold FONTNAME cFontname SIZE nFontsize BOLD // ITALIC
   endif


   // If in PLUGIN mode
   //       ******
   //   Scan if there are araes open.
   //   The Otis browse table will automaticaly be filled with
   //   all dbf opened by the running program.
   //   Remember that it is necessary, in this case,
   //   that otis.prg or otis.lib is included in your own program and that Otis is
   //   called by a hotkey or a Control Action event.
   IF !lStandalone

      // init flag, files where opened by the running program
      lFlgopen := .F.

      // Set autoOpen to .F. temporary, gives a better control below
      Sx_AutoOpen(.F.)

      // scan
      FOR i := ini_area_min_scan TO ini_area_max_scan

         // if this area is in use and area nr < reopen start area nr
         //
         IF !EMPTY( ALIAS(i) ) .and. i < ini_area_pi_reopen_start

            // flag table is opened
            lReOpenOk := .T.

            // get info from the file that was openend by a running program
            cAlias   := Alias(i)
            cUseName := (cAlias)->( Sx_Tablename() )            // full file/path name
            nRecno   := (cAlias)->(recno())
            cFilter  := (cAlias)->(DBINFO(DBI_DBFILTER))
            nOrdernr := (cAlias)->(INDEXORD())

            // reopen it again in a new area = is current area + offset
            select (i + ini_area_pi_reopen_start)
            //msgstop(cUseName + crlf + cAlias+'_'+hb_ntos(i + ini_area_pi_reopen_start))

            // open table in a new area with
            // alias name the current alias + suffix area nr.
            Try
               USE (cUseName) ALIAS ( cAlias+'_'+hb_ntos(i + ini_area_pi_reopen_start)) CODEPAGE ini_dbf_codepage

               // set filter if a filter was set in the original alias
               if !empty(cFilter)
                  DbSetFilter( &("{||" + cFilter + "}" ), cFilter )
               endif

            // table could not be opened
            Catch oError
               lReOpenOk := .F.
               MsgStop("Otis can not open a GHOST AREA of table : " + crlf +;
                       "   " + cUseName +  crlf + crlf + ;
                       "You are probably running in Exclusive mode." + crlf + crlf + ;
                        ErrorMessage(oError) )
            End

            // if a table was reopened succesfully
            if lReOpenOk

               // Open also the same orderbag files for the reopened table
               if ( nOrderCnt := (cAlias)->(DBORDERINFO(DBOI_ORDERCOUNT)) ) <> 0

                  try
                     temp := ""
                     for x := 1 to nOrderCnt
                        if temp <> (cAlias)->( ORDBAGNAME(x) )
                           temp := (cAlias)->( ORDBAGNAME(x) )
                           ORDLISTADD( (cAlias)->( Sx_IndexName(x) ) )
                        endif
                     next x

                  catch oError
                     MsgStop("Otis can not open a orderbag for table : " + crlf + crlf + ;
                              "  " + cUseName +  crlf + crlf + ;
                              ErrorMessage(oError) )
                  end

               endif

               // set the same order nbr
               ORDSETFOCUS(nOrdernr)

               // and go to the same recno as the original
               goto nRecno

               // set flag, are opened by the running program
               lFlgopen := .T.

               //EXIT

            endif

         ENDIF

      NEXT i

      // Restore AutoOpen mode
      Set( _SET_AUTOPEN, ini_ordbag_autoopen)


   // if in STANDALONE mode, open tables specified on the command line.
   //       **********
   //
   //  The command line contains also the name of a table if you double click on it in Explorer.
   //  Otis launches immediately the 'Inspector'
   //  See 'ON INIT' codeblock of main window if in standalone mode.
   //
   else

      // if there is anything specified on the command line.
      if !empty(cCmdline)

         // filenames are "," or ";" delimited
         // transform , to ";" before tokenizing
         cCmdline := strtran(cCmdline, ",", ";")
         // debug
         //msgstop("Command line : <" + cCmdline + ">")

         // Tokenize cmdline to array
         aTokens := hb_atokens( cCmdline, ";")

         // force default rdd driver DBFCDX in command line mode
         RDDSETDEFAULT("DBFCDX")

         // set command line EXCLUSIVE mode
         Set( _SET_EXCLUSIVE, ini_cl_excl )

         // set command line AUTOPEN mode
         Set( _SET_AUTOPEN, ini_cl_autopen)

         // open tables ALLWAYS IN SHARED MODE
         for i := 1 to len(aTokens)

            // open table in a new area with the dbf name as alias
            Try
               // select area
               select (pi_area_cnt)

               // open table
               // We use the table name as alias but first remove unallowed chars. in a alias name.
               USE (aTokens[i]) alias (charrem( "-#%&{}<>*?/*!@"+"'"+'"', hb_FNameName(aTokens[i]))) CODEPAGE ini_dbf_codepage

               // next area
               pi_area_cnt++

               // clear flag 'Dataset has changed' to prevent asking to save settings on exit.
               // Details, see function otis_release()
               lDsChanged := .F.

            Catch oError
               temp := "Otis can not open file : "+ aTokens[i] + crlf + crlf + ErrorMessage(oError)
               if at("DOS Error 32", temp) <> 0
                  temp += crlf + crlf + 'File is probably already opened or in readonly mode.'
               endif
               MsgStop(temp)
            End

         next i

      endif

   endif

   // debug
   //msgstop(SET(_SET_DBFLOCKSCHEME))
   //msgstop(ini_lOpen_Exclusive)

   // fill tbrowse dataset array with info of all open dbf/index files.
   aOtables := otis_get_area_info()

   //
   // Construct the main window "OTIS"
   //*********************************

   // Define main window to show the Dataset manager with open files or to open files.
   IF .T. //LEN(aOtables) <> 0

      // build titel main window
      temp := 'OTIS - DataSet Manager          Freeware - ' + Version + ' ' + Versionbuild + ' - ' + Versiondate

      // define as MAIN window in STANDALONE mode
      IF lStandalone .or. lSimul_PlugIn_mode

         // show main window
         if empty(cCmdline)
            DEFINE WINDOW form_otis ;
               at 0,0 ;
               clientarea th_w_width, th_w_height ;
               TITLE temp ;
               WINDOWTYPE MAIN ;
               NOMAXIMIZE ;
               NOSIZE ;
               ON INTERACTIVECLOSE otis_release() ;
               ;//ON GOTFOCUS {|| if( !empty(cCmdline) .and. !lDsChanged .and. cWhoSetFocustoMain =="DV", otis_release(), nil) }  ;
               BACKCOLOR th_w_bgcolor ;
               ;// Open Inspector IMMEDIATELY if there is any table has been opened at startup of Otis
               ;//   usefull when double clicking on a dbf file
               ;//   or when the command line option is used.
               ON INIT { || if( !empty(aOtables[ 1, ATI_ALIAS ]), otis_dv(), nil ) }

         // Hide main window on double click
         else
            DEFINE WINDOW form_otis ;
               at 0,0 ;
               clientarea th_w_width, th_w_height ;
               TITLE temp ;
               WINDOWTYPE MAIN NOSHOW ;
               NOMAXIMIZE ;
               NOSIZE ;
               ON INTERACTIVECLOSE otis_release() ;
               ON GOTFOCUS {|| if( !empty(cCmdline) .and. !lDsChanged .and. cWhoSetFocustoMain =="DV", otis_release(), nil) }  ;
               BACKCOLOR th_w_bgcolor ;
               ;// Open Inspector IMMEDIATELY if there is any table has been opened at startup of Otis
               ;//   usefull when double clicking on a dbf file
               ;//   or when the command line option is used.
               ON INIT { || if( !empty(aOtables[ 1, ATI_ALIAS ]), otis_dv(), nil ) }
         endif

      // define as STANDARD window if otis.prg is INCLUDED in your program.
      ELSE
         DEFINE WINDOW form_otis ;
            at 0,0 ;
            clientarea th_w_width, th_w_height ;
            TITLE temp ;
            WINDOWTYPE STANDARD ;
            NOMAXIMIZE ;
            NOSIZE ;
            ON INTERACTIVECLOSE otis_release() ;
            BACKCOLOR th_w_bgcolor
      ENDIF

         // Dataset name label and combobox
         DEFINE LABEL lb_dataset
            ROW th_w_ctrlgap * 2
            COL th_bt_width + th_w_ctrlgap * 2
            WIDTH 50
            HEIGHT 24
            FONTSIZE 10
            FONTCOLOR th_bt_ohfontcol
            BACKCOLOR th_bt_ohbgcol
            Value " Recent"
            VCENTERALIGN .T.
         END label
         *
         define COMBOBOX cb_dataset
            row th_w_ctrlgap * 2
            col getproperty(ThisWindow.name, "lb_dataset","col") + getproperty(ThisWindow.name, "lb_dataset","width") + th_w_ctrlgap
            height 140
            width 350
            FONTSIZE 10
            DISPLAYEDIT .F.
            ONCHANGE otis_cbds_change()
            ONINIT  setproperty( "form_otis", "cb_dataset", "Cargo", .T.)
            Items { '', ini_mr_ds1, ini_mr_ds2, ini_mr_ds3, ini_mr_ds4, ini_mr_ds5 }
            VALUE 1
         end COMBOBOX

         // "DS Changed Status" checkbox
         DEFINE Checkbox cb_ds_changed
            ROW th_w_ctrlgap * 2
            COL getproperty(ThisWindow.name, "cb_dataset","col") + getproperty(ThisWindow.name, "cb_dataset","width") + th_w_ctrlgap
            WIDTH 75
            HEIGHT 24
            //FONTBOLD .T.
            FONTCOLOR th_bt_ohfontcol
            BACKCOLOR th_bt_ohbgcol
            Caption ' Changed'
            TOOLTIP "Flag to show if a dataset has been changed since it has been loaded or created."
            LEFTJUSTIFY .T.
            VALUE lDsChanged
            // can not be changed by the user, it reflects always the var lDsChanged
            ON CHANGE setproperty(ThisWindow.name, "cb_ds_changed", "Value", lDsChanged )
         END Checkbox
         * small empty label right of checkbox to obtain a visual centered checkbox
         Define label lb_dum_sc
            ROW th_w_ctrlgap * 2
            col getproperty(ThisWindow.name, "cb_ds_changed","col") + getproperty(ThisWindow.name, "cb_ds_changed","width")
            height 24
            width 4
            BACKCOLOR th_bt_ohbgcol
         end label

         // Open Exclusive on/off
         DEFINE Checkbox cb_ds_openExcl
            ROW th_w_ctrlgap * 2
            COL getproperty(ThisWindow.name, "lb_dum_sc","col") + getproperty(ThisWindow.name, "lb_dum_sc","width") + th_w_ctrlgap
            WIDTH 75
            HEIGHT 24
            //FONTBOLD .T.
            FONTCOLOR th_bt_ohfontcol
            BACKCOLOR th_bt_ohbgcol
            Caption ' Exclusive'
            TOOLTIP "Open tables 'Exclusive', needed for operations like Zap, Pack, Insert record, ...etc."
            LEFTJUSTIFY .T.
            Value ini_lOpen_Exclusive
            ON CHANGE { || ini_lOpen_Exclusive := getproperty(ThisWindow.name, "cb_ds_openExcl", "Value"), ;
                           Set( _SET_EXCLUSIVE, ini_lOpen_Exclusive ), tb_Otis:SetFocus() }
         END Checkbox
         * small empty label right of checkbox to obtain a visual centered checkbox
         Define label lb_dum_oexcl
            ROW th_w_ctrlgap * 2
            col getproperty(ThisWindow.name, "cb_ds_openExcl","col") + getproperty(ThisWindow.name, "cb_ds_openExcl","width")
            height 24
            width 4
            BACKCOLOR th_bt_ohbgcol
         end label

         // AutoOpen orderbag order files
         DEFINE Checkbox cb_AutoOpen
            ROW th_w_ctrlgap * 2
            COL getproperty(ThisWindow.name, "lb_dum_oexcl","col") + getproperty(ThisWindow.name, "lb_dum_oexcl","width") + th_w_ctrlgap
            WIDTH 75
            HEIGHT 24
            //FONTBOLD .T.
            FONTCOLOR th_bt_ohfontcol
            BACKCOLOR th_bt_ohbgcol
            Caption ' AutoOpen'
            TOOLTIP "AutoOpen orderbag files (only for cdx or nsx)."
            LEFTJUSTIFY .T.
            Value ini_ordbag_autoopen
            ON CHANGE { || otis_cbao_change(), tb_Otis:SetFocus() }

         END Checkbox
         * small empty label right of checkbox to obtain a visual centered checkbox
         Define label lb_dum_ao
            ROW th_w_ctrlgap * 2
            col getproperty(ThisWindow.name, "cb_AutoOpen","col") + getproperty(ThisWindow.name, "cb_AutoOpen","width")
            height 24
            width 4
            BACKCOLOR th_bt_ohbgcol
         end label

         // Codepage combobox
         define COMBOBOX cb_codepage
            row th_w_ctrlgap * 2
            col getproperty(ThisWindow.name, "lb_dum_ao","col") + getproperty(ThisWindow.name, "lb_dum_ao","width") + th_w_ctrlgap
            height 140
            width 85
            FONTSIZE 10
            DISPLAYEDIT .T.
            ONCHANGE { || ini_dbf_codepage := aCodepage[ getproperty(ThisWindow.name,"cb_codepage","Value") ],;
                        SET( _SET_DBCODEPAGE, ini_dbf_codepage ),;
                        tb_Otis:SetFocus();
                     }
            //ONINIT This.Value :=
            Items aCodepage
            VALUE ascan(aCodepage, ini_dbf_codepage)
         end COMBOBOX

         // RDDxxx combobox
         define COMBOBOX cb_defrdd
            row th_w_ctrlgap * 2
            col getproperty(ThisWindow.name, "cb_codepage","col") + getproperty(ThisWindow.name, "cb_codepage","width") + th_w_ctrlgap
            height 140
            width 85
            FONTSIZE 10
            DISPLAYEDIT .T.
            // reflect status to var and if DBFNTX is choosen reset AutoOpen checkbox
            ONCHANGE { || otis_rdd_change(), tb_Otis:SetFocus() }
            Items aDefaultRdd
            VALUE ascan(aDefaultRdd, ini_default_rdd)
         end COMBOBOX

         //"? About" button
         DEFINE LABEL bt_About
            ROW th_w_ctrlgap / 1.5
            COL getproperty(ThisWindow.name,"ClientWidth") - th_w_ctrlgap / 1.5 - 17
            WIDTH 18
            HEIGHT 18
            FONTBOLD .T.
            Value " ? "
            TOOLTIP 'About Otis'
            VCENTERALIGN .T.
            CENTERALIGN .T.
            ACTION otis_about()
            FONTCOLOR th_bt_ohfontcol
            BACKCOLOR th_bt_ohbgcol
         END label

         // define Tbrowse with the currently open table/index files,
         //   they are in the dataset array aOtables.
         DEFINE TBROWSE tb_Otis ;
            AT getproperty(ThisWindow.name, "lb_dataset","row") + getproperty(ThisWindow.name, "lb_dataset","Height") + th_w_ctrlgap, th_bt_width + th_w_ctrlgap * 2;
            WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width -  th_w_ctrlgap * 3 ;
            HEIGHT getproperty(ThisWindow.name,"ClientHeight") - getproperty(ThisWindow.name, "lb_dataset","Height") - th_w_ctrlgap * 4 ;
            COLORS {CLR_BLACK, CLR_WHITE} ;
            SELECTOR .T.

            // set array
            :SetArray( aOtables )

            // set colors
            :SetColor( { 1, 2, 4, 5, 6 }, { ;
                    CLR_BLACK, ;
                    CLR_WHITE, ;
                    { CLR_WHITE, RGB(210, 210, 220) }, ;
                      CLR_WHITE, RGB(21, 113, 173) }, )

            // add all columns
            ADD COLUMN TO TBROWSE tb_Otis ;
               DATA ARRAY ELEMENT ATI_ALIAS ;
               TITLE "Alias" SIZE 125 ;
               ALIGN DT_LEFT, DT_LEFT, DT_LEFT

            ADD COLUMN TO TBROWSE tb_Otis ;
               DATA ARRAY ELEMENT ATI_AREA ;
               TITLE "Area" SIZE 40 ;
               ALIGN DT_RIGHT, DT_RIGHT, DT_RIGHT

            ADD COLUMN TO TBROWSE tb_Otis ;
               DATA ARRAY ELEMENT ATI_ISSELECTED ;
               TITLE "S" SIZE 20 ;
               ALIGN DT_CENTER

            ADD COLUMN TO TBROWSE tb_Otis ;
               DATA ARRAY ELEMENT ATI_ISLOCKED ;
               TITLE "L" SIZE 25 ;
               ALIGN DT_CENTER

            ADD COLUMN TO TBROWSE tb_Otis ;
               DATA ARRAY ELEMENT ATI_RECNO ;
               TITLE "Recno" SIZE 70 ;
               ALIGN DT_RIGHT

            ADD COLUMN TO TBROWSE tb_Otis ;
               DATA ARRAY ELEMENT ATI_RECCNT ;
               TITLE "Reccount" SIZE 70 ;
               ALIGN DT_RIGHT

            ADD COLUMN TO TBROWSE tb_Otis ;
               DATA ARRAY ELEMENT ATI_CURIND ;
               TITLE "Act.Ind." SIZE 55 ;
               ALIGN DT_CENTER, DT_RIGHT, DT_RIGHT

            ADD COLUMN TO TBROWSE tb_Otis ;
               DATA ARRAY ELEMENT ATI_INDCNT ;
               TITLE "Nbr.Ind." SIZE 55 ;
               ALIGN DT_CENTER, DT_RIGHT, DT_RIGHT

            ADD COLUMN TO TBROWSE tb_Otis ;
               DATA ARRAY ELEMENT ATI_RDD ;
               TITLE "Rdd" SIZE 60 ;
               ALIGN DT_LEFT,DT_LEFT,DT_LEFT

            ADD COLUMN TO TBROWSE tb_Otis ;
               DATA ARRAY ELEMENT ATI_FN ;
               TITLE "Table name" SIZE 545 ;
               ALIGN DT_LEFT, DT_LEFT, DT_LEFT

            // mouse wheel skip, 1 line
            :nWheelLines := 1

            // header is a little bit heigher than the data rows
            :nHeightHead += 6
            :nHeightCell += 3
            // Header font in BOLD
            MODIFY TBROWSE tb_Otis HEADER FONT TO FontBold

            // cell margins, add one space left and right
            :nCellMarginLR := 1

            // Row Colors, fontcolor en/disabled, bg odd or even
            :SetColor( { 1, 2 }, { th_fctb_leven, {|nRow, nCol, oBrw| iif( nRow%2==0, th_bgtb_leven, th_bgtb_lodd )}} )

            // open dbfviewer on double click
            :bLDblClick := { || otis_dv() }

         END TBROWSE

         // Define left menu buttons
         //               Label               ID used by mn_dispatch()
         aButtons := { ;
                       { "Table Inspector"  , "ot_br"  },;
                       { "Table Properties" , "ot_pr"  },;
                       { "Struct. Editor"   , "ot_se"  },;
                       { "-"                , ""       },;
                       { "Load DataSet"     , "ot_lds" },;
                       { "Save DataSet"     , "ot_sds" },;
                       { "Close Dataset"    , "ot_cds" },;
                       { "-"                , ""       },;
                       { "Add Table(s)"     , "ot_at"  },;
                       { "Add Index(es)"    , "ot_ai"  },;
                       { "Remove Table"     , "ot_dt"  },;
                       { "Remove Index"     , "ot_di"  },;
                       { "-"                , ""       },;
                       { "Settings"         , "ot_set" };
                     }

         // draw menu buttons (row, col, array, winname)
         draw_menu( th_w_ctrlgap * 2, th_w_ctrlgap, aButtons, "form_otis" )

         // Quit button (allways on the bottom )
         DEFINE LABEL bt_Quit
            ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
            COL th_w_ctrlgap
            WIDTH th_bt_width
            HEIGHT th_bt_height
            FONTBOLD .T.
            Value "Quit"
            VCENTERALIGN .T.
            CENTERALIGN .T.
            ACTION otis_release()
            FONTCOLOR th_bt_ohfontcol
            BACKCOLOR th_bt_ohbgcol
         END label

      END WINDOW

      // en/dis-able some menus in function of contents of dataset array aOtables
      otis_endi_menus(.F.)

      // center
      // CENTER WINDOW form_otis   // for one reason or another it does not always center
      //   workaround
      setproperty("form_otis","Row", GetDesktopHeight()/2 - th_w_height/2 )
      setproperty("form_otis","Col", GetDesktopWidth()/2  - th_w_width/2 )

      // activate window
      ACTIVATE WINDOW form_otis

   endif

Return nil


// enable / disable menus
static function otis_endi_menus(lState)

   // -w2
   lState := lState

   /* NOT USED, I DON'T LIKE IT
   setproperty( "form_otis", "bt_ot_br" , "Enabled", lState)
   setproperty( "form_otis", "bt_ot_sds", "Enabled", lState)
   setproperty( "form_otis", "bt_ot_ai",  "Enabled", lState)
   setproperty( "form_otis", "bt_ot_dt",  "Enabled", lState)
   setproperty( "form_otis", "bt_ot_di",  "Enabled", lState)
   setproperty( "form_otis", "bt_ot_pr",  "Enabled", lState)
   */
return nil

// Exit Otis
static function otis_release()

   //msgstop("release Otis")

   // Save Dataset and Settings only if files added or deleted from the dataset.
   //  Rem : this flag is set to .F. if in command line mode
   //        it permits us to open and close a table without other mouse clicks.
   //        When you are in command line mode and add a file in the dataset manager
   //        than this flag will be set with result that on exit Otis asks to
   //        save the dataset on exit.
   if lDsChanged

      // First save current dataset if changed
      ds_save_if_changed()

   endif

   // Copy combobox with 5 most recent datasets to ini file vars
   ini_mr_ds1 := getproperty("form_otis", "cb_dataset", "Item", 2)
   ini_mr_ds2 := getproperty("form_otis", "cb_dataset", "Item", 3)
   ini_mr_ds3 := getproperty("form_otis", "cb_dataset", "Item", 4)
   ini_mr_ds4 := getproperty("form_otis", "cb_dataset", "Item", 5)
   ini_mr_ds5 := getproperty("form_otis", "cb_dataset", "Item", 6)

   // get some ini settings from controls
   ini_lOpen_Exclusive := getproperty("form_otis", "cb_ds_openExcl", "Value")

   // save current settings
   FWRITEINI(fn_ini)

   // restore
   SET(_SET_DELETED, lOldDel)
   SELECT (nOldSel)

   // Close areas
   //  Standalone mode : all
   //  or
   //  Plugin mode : only ghost areas or added tables, running program areas stay open.
   ds_close_areas()

   // release main window
   domethod( "form_otis","release")

return nil


// OTIS call to browse table with dbfviewer
static function otis_dv()

   // get area number form selected row in DS tbrowse
   Local nSelect := val(tb_Otis:aArray[tb_Otis:nAt, ATI_AREA ])

   local lOk := .T.
   Local cMsg := "WARNING : " + crlf + ;
                 crlf + ;
                 "Otis is running in 'Plugin mode'." + crlf + ;
                 + crlf + ;
                 "You want to open a table in area ("+hb_ntos(nSelect)+") that is opened" + crlf + ;
                 "and used by the running program." + crlf + ;
                 crlf + ;
                 "We advise you to open the 'GHOST AREA' because" + crlf + ;
                 "data integrity can NOT be assured if you change by" + crlf + ;
                 "ex. the record position, filter, scope, order, ...etc." + crlf + ;
                 "in the original area used by the running program." + crlf + crlf

   // browse area
   if nSelect <> 0

      // if Plugin mode advise to open the ghost area
      //   only if this area exists
      //   The 'ghost' areas are not saved in a dataset when you run in plugin mode
      //   This test is necessary because if you close all files in the running program and load
      //   a previous dataset Otis thinks that the 'ghost' area are also opened and that is
      //   not the case because you loaded a dataset.
      //   Ghost area are only created when there are tables open at the moment that you open Otis.
      if ! lStandalone .and. nSelect < ini_area_pi_reopen_start

         // You selected a table opened by the running program
         // if the Ghost table is still open  (it could be possible that you closed them)
         if !empty( alias(nSelect+ini_area_pi_reopen_start) )

            // display a warning message and propose to open the ghost table
            if nSelect < ini_area_pi_reopen_start
               PlayExclamation()
               if msgYesNo( cMsg + ;
                           "Do you want to open the ghost area : "+ hb_ntos(nSelect+ini_area_pi_reopen_start) + " ?" ;
                          )

                  // new select to open is the ghost table
                  nSelect := nSelect+ini_area_pi_reopen_start

               endif
            endif

         // Ghost tables is closed
         // display a warning
         else
            PlayExclamation()
            lOk := msgYesNo(cMsg + ;
                            "Do you want to continue ? " ;
                           )
         endif

      endif

      // open area
      if lOk
         dv_viewer(nSelect)
      endif

   // Dataset is empty
   else
      // msg
      //MsgInfo("There are no tables open for the moment.")

      // Act as click on button 'add table(s)'.
      otis_add_table(tb_Otis)

   endif

return nil


// add one or more dbf tables to the browse array of the main otis form.
static function otis_add_table(oBrowse)

   local lOk := .T., i
   local aSelected := {}, cAlias

   // get rdd to use
   local cRdd := getproperty("form_otis", "cb_defrdd","Item", getproperty( "form_otis", "cb_defrdd", "Value") )

   // if RDD to use is LETODBF
   //msgstop(cTablename + " : " + cRdd)
   if upper(cRdd) == "LETO"
      // if server is NOT connected
      if leto_Connect() < 0
         // connect server
         lOk := otis_leto_connect()
      endif
   endif

   //
   if lOk
      // set always the choosen rdd
      RDDSETDEFAULT(cRdd)

      // open a file,
      // you can select more files at once by using the usual shift and control keys.
      //
      // if RDDxxx
      if cRdd <> 'LETO'
         //                        acFilter ,                                    cTitle,            cDefaultPath , lMultiSelect , lNoChangeDir , nIndex
         aSelected := Getfile( { {'Dbf Files','*.DBF'}, {'All Files','*.*'} } , 'Open DBF file(s)' , ini_lu_folder, .t. ,         .t. )

      // if RDD LetoDbf
      else
        aSelected := leto_Getfile({ {'Dbf Files','*.DBF'}, {'All Files','*.*'} }, "Open LetoDbf table", , .T.)
        //msgstop(len(aSelected))
      endif

      // open all selected tables
      if len(aSelected) <> 0

         // set ini var lastusedfolder
         ini_lu_folder := hb_FNameDir( aSelected[1] )
         // remove last "\"
         ini_lu_folder := remright( ini_lu_folder, '\')
         // if this folder is a subfolder of the current folder
         // delete it from the filename.
         // Why ? if we save a dataset i prefer to not have the current folder name included
         //       because with this method a data folder can be moved to another drive and
         //       file pathnames are still valid as long as it stays a subfolder.
         //
         ini_lu_folder := strtran(ini_lu_folder, GetCurrentFolder()+"\", '')

         // open each dbf in a new area
         for i := 1 to len(aSelected)

            // debug
            //msgstop(aSelected[i])

            // Construct alias name, remove invalid chars in filename used it as alias name
            cAlias := charrem( def_invfnchars, hb_FNameName(aSelected[i]) )
            *msgstop(cAlias)

            // v1.21 06/05/2021
            // Add the area counter if necessary to the alias name to asure a unique alias name.
            // It is possible that you open 2 files with the same name thus the same alias
            // but in different folders to compare by example
            // or
            // open the same file 2 times to inspect different records at the same time.
            if select(cAlias) <> 0
               cAlias += '_' + hb_ntos(pi_area_cnt)
            endif

            // open table in a new area with the dbf name as alias
            Try
               // select area
               select (pi_area_cnt)
               //msgstop(pi_area_cnt)

               // open table
               USE (aSelected[i]) alias (cAlias) CODEPAGE ini_dbf_codepage

               // next area
               pi_area_cnt++

               // set flag Dataset has changed
               Otis_Ds_changed(.T.)

            Catch oError
               MsgStop("Otis can not open table :" + crlf + crlf + ;
                        aSelected[i] + crlf + crlf + ;
                        "It is possible, if Autopen is enabled, that" + crlf + ;
                        "the index expression could not be resolved" + crlf + ;
                        "because of a unknown variable or function." + crlf + crlf + ;
                        ErrorMessage(oError) + crlf  ;
                      )
            End

         next i

         // reconstruct the tbrowse array
         aOtables := otis_get_area_info()

         // refresh tbrowse array
         tb_Otis:SetArray( aOtables )
         oBrowse:Refresh()

         // enable some menus
         otis_endi_menus(.T.)

      endif

   endif

   // return number of opened files.
return len(aSelected)


// Delete a dbf in the dataset table
static function otis_rem_table(oBrowse)

   local nSelect

   // Exit if no tables opened at all
   if len(aOtables) == 0 .or. empty(aOtables[ 1, ATI_ALIAS ])

      Msginfo("There are no open tables in the dataset.")

   // delete a table
   else

      // get area nr of selected dbf in dataset table
      nSelect := val(tb_Otis:aArray[tb_Otis:nAt, ATI_AREA ])

      // ask 'DELETE' confirmation
      PlayExclamation()
      if MsgOkCancel("Remove table <" + alltrim(tb_Otis:aArray[tb_Otis:nAt, ATI_FN ]) + "> from the current dataset.")

         // close table and index files
         select (nSelect)
         use

         // set flag Dataset has changed
         Otis_Ds_changed(.T.)

         // reconstruct the tbrowse array
         aOtables := otis_get_area_info()

         // refresh tbrowse array
         tb_Otis:SetArray( aOtables )
         oBrowse:refresh()

         // Reset area counter if no more tables in dataset
         if len(aOtables) == 0 .or. empty(aOtables[ 1, ATI_ALIAS ])
            pi_area_cnt := 1
         endif

      endif

   endif

return nil


// Add one or more index files to one of the tables
static function otis_add_index(oBrowse)

   local i, cOrdBagext, nOldsel, aSelected := {}, cTablename

   // get rdd to use
   local cRdd := getproperty("form_otis", "cb_defrdd","Item", getproperty( "form_otis", "cb_defrdd", "Value") )

   // if any table opened to attach a index file
   if len(aOtables) == 0 .or. empty(aOtables[ 1, ATI_ALIAS ])

      Msginfo("There are no tables open and it is thus" + crlf + ;
              "impossible to attach a index file to a table.")
      return nil

   endif

   // orderbag extension in function of rdd driver
   cOrdBagExt := ORDBAGEXT()

   // if RDDxxx
   if cRdd <> 'LETO'

      // open a index file on disk,
      // you can select more files at once by using the usual shift and control keys.
      aSelected := Getfile( { {cOrdBagExt + ' files','*'+cOrdBagExt}, {'All Files','*.*'} } , 'Open index file(s)' , ini_lu_folder, .t. , .t. )

   // if RDD LetoDbf index file
   else
     aSelected := leto_Getfile({ {'Cdx Files','*.CDX'}, {'All Files','*.*'} }, "Open LetoDbf index file" , , .T.)
   endif

   // open all selected tables
   if len(aSelected) <> 0

      // set ini var lastusedfolder
      ini_lu_folder := hb_FNameDir( aSelected[1] )
      // remove last "\"
      ini_lu_folder := remright( ini_lu_folder, '\')
      // if this folder is a subfolder of the current folder
      // delete it from the filename.
      // Why ? if we save a dataset i prefer to NOT have the current folder name included
      //       because with this method a data folder can be moved to another drive and
      //       file pathnames are still valid as long as it stays a subfolder of Otis.
      //
      ini_lu_folder := strtran(ini_lu_folder, GetCurrentFolder()+"\", '')

      // open index files
      for i := 1 to len(aSelected)

         // save current area
         nOldsel := select()

         // get table name
         cTablename := tb_Otis:aArray[tb_Otis:nAt, ATI_FN ]

         // activate select table in browse array
         select ( tb_Otis:aArray[tb_Otis:nAt, ATI_AREA ] )

         // attach index to table (with error trapping)
         Try
            SET INDEX TO (aSelected[i]) ADDITIVE

            // set flag Dataset has changed
            Otis_Ds_changed(.T.)

         Catch oError
            MsgStop("OTIS can not open index :"+ crlf + ;
                    "  " + alltrim(aSelected[i]) + crlf + ;
                    "for table : " + crlf + ;
                    "  " + alltrim(cTablename)+ crlf + crlf +;
                    "This index does not belong to this table," + crlf + ;
                    "the index is corrupted," + crlf + ;
                    "the wrong rdd driver is used" + crlf + ;
                    "or" + crlf + ;
                    "a unknown function/fieldname/variable is used in the KEY or FOR expression."+crlf+crlf+;
                    ErrorMessage(oError) )
         End

         // restore old select
         select (nOldsel)

      next i

      // reconstruct the tbrowse array
      aOtables := otis_get_area_info()

      // refresh tbrowse array
      tb_Otis:SetArray( aOtables )
      oBrowse:refresh()

   endif

   // return number of opened files.
return len(aSelected)


// Close a index file attached to a dbf
// and remove it from the dataset array
//static function otis_rem_index(oBrowse)
static function otis_rem_index()

   local temp, i, aIndexInfo, nIndexOrd

   // save current area nr
   local nOldsel := select()

   // get area nr of selected dbf in dataset table
   local nSelect := val(tb_Otis:aArray[tb_Otis:nAt, ATI_AREA ])

   // select table
   select (nSelect)

   // if there is a table open
   if !empty(alias())

      // if a index attached
      if DBORDERINFO(DBOI_BAGCOUNT) <> 0

         // get current active order
         nIndexOrd := IndexOrd()

         // get the name of all orderbag files
         aIndexInfo := {}
         temp := ""
         for i := 1 to DBORDERINFO(DBOI_BAGCOUNT)
            if temp <> ORDBAGNAME(i)
               temp := ORDBAGNAME(i)
               aadd( aIndexInfo, { ORDBAGNAME(i), Sx_IndexName(i) } )
            endif
         next i

         // show all index files and select one to delete from the dataset
         define window form_del_index ;
            row getproperty("form_otis","row") + 200 ;
            col getproperty("form_otis","col") + 200 ;
            clientarea 860 + th_w_ctrlgap * 2, 310 + th_bt_height + th_w_ctrlgap * 3 ;
            TITLE "OTIS - Remove orderbag from dataset for Alias <" + alltrim(tb_Otis:aArray[tb_Otis:nAt, ATI_ALIAS ]) + '>' ;
            backcolor th_w_bgcolor ;
            WINDOWTYPE MODAL ;
            ON SIZE otis_rem_index_resize()

            // set min, max width
            ThisWindow.MinWidth := th_w_ctrlgap * 3 + th_bt_width * 2 + GetBorderWidth() * 2
            ThisWindow.MaxWidth := getproperty(ThisWindow.name, "WIDTH")

             // tsbrowse
            define TBROWSE tb_delindex ;
               at th_w_ctrlgap, th_w_ctrlgap ;
               width  860 ;
               height 310 ;
               COLORS {CLR_BLACK, CLR_WHITE} ;
               size 10 ;
               grid ;
               SELECTOR .T.

               // set array
               tb_delindex:SetArray( aIndexInfo )

               // set colors
               tb_Otis:SetColor( { 1, 2, 4, 5, 6 }, { ;
                       CLR_BLACK, ;
                       CLR_WHITE, ;
                       { CLR_WHITE, RGB(210, 210, 220) }, ;
                         CLR_WHITE, RGB(21, 113, 173) }, )

               // add column with index nr and "*" if the row is the active index
               ADD COLUMN TO tb_delindex  ;
                  HEADER "#" ;
                  DATA hb_ntos(tb_delindex:nLogicPos) + if( nIndexOrd == tb_delindex:nLogicPos, " *", "") ;
                  SIZE 30 PIXELS ;
                  3DLOOK TRUE,TRUE,FALSE ;                  // cell, header, footer
                  ALIGN DT_CENTER,DT_CENTER,DT_CENTER ;     // cell, header, footer
                  COLORS CLR_BLACK, CLR_HGRAY

               ADD COLUMN TO TBROWSE tb_delindex ;
                  DATA ARRAY ELEMENT 1 ;
                  TITLE "Index filename" SIZE 130 ;
                  ALIGN DT_LEFT, DT_LEFT, DT_LEFT

               ADD COLUMN TO TBROWSE tb_delindex ;
                  DATA ARRAY ELEMENT 2 ;
                  TITLE "Full name" SIZE 660 ;
                  ALIGN DT_LEFT, DT_LEFT, DT_LEFT
               /* only needed if KEY and FOR are not in he same cell
               ADD COLUMN TO TBROWSE tb_delindex ;
                  DATA ARRAY ELEMENT 3 ;
                  TITLE "For" SIZE 375 ;
                  ALIGN DT_LEFT
               */

               // header is a little bit heigher than the data rows
               :nHeightHead += 6
               :nHeightCell += 3
               // Header in BOLD
               MODIFY TBROWSE tb_delindex HEADER FONT TO FontBold

               // Row Colors, fontcolor en/disabled, bg odd or even
               :SetColor( { 1, 2 }, { th_fctb_leven, {|nRow, nCol, oBrw| iif( nRow%2==0, th_bgtb_leven, th_bgtb_lodd )}} )

               // cell margins, add one space left and right
               :nCellMarginLR := 1

               // mouse wheel skip, 1 line
               :nWheelLines := 1

            end tbrowse

            // *****
            // Next code is needed to show a vertial scroll bar with double line cells
            // and correct mousewheel refresh of last line in browse.
            // Advised by Grigory Filatov, see forum :
            //      https://groups.google.com/forum/#!topic/minigui-forum/Nn-y7Pe2QXE
            //
            tb_delindex:SetNoHoles()
            tb_delindex:SetFocus()
            tb_delindex:ResetVScroll( .T. )
            // *****

            // "Quit" button
            DEFINE LABEL bt_Quit
               ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
               COL getproperty(ThisWindow.name,"ClientWidth") - ( th_bt_width + th_w_ctrlgap ) * 1
               WIDTH th_bt_width
               HEIGHT th_bt_height
               FONTBOLD .T.
               FONTCOLOR th_bt_ohfontcol
               BACKCOLOR th_bt_ohbgcol
               Value "Quit"
               VCENTERALIGN .T.
               CENTERALIGN .T.
               ACTION form_del_index.release
            END label

            // "Delete" button
            DEFINE LABEL bt_Delete
               ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
               COL getproperty(ThisWindow.name,"ClientWidth") - ( th_bt_width + th_w_ctrlgap ) * 2
               WIDTH th_bt_width
               HEIGHT th_bt_height
               FONTBOLD .T.
               FONTCOLOR th_bt_fontcol
               BACKCOLOR th_bt_bgcol
               Value "Delete"
               VCENTERALIGN .T.
               CENTERALIGN .T.
               ACTION { || otis_rem_index2(), form_del_index.Release }
               // font and background color when onhover / onleave
               ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                                 setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
               ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                                 setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
            END label

            // escape key action
            ON KEY ESCAPE ACTION This.bt_Quit.OnClick

         end window

         // activate window
         domethod( "form_del_index", "ACTIVATE")

      // message there are no index files open for this table
      else
         MsgInfo("There are no orderbag files open for the selected table.")

      endif

   // message there are no index files open for this table
   else
      Msginfo("There are no tables open in the dataset.")

   endif

   // restore selected area
   select (nOldsel)

return nil


// delete index from dataset table
//toremove static function otis_rem_index2( aIndexInfo )
static function otis_rem_index2()

   local temp, i, fn_index, cAlias

   // ask Delete confirmation
   PlayExclamation()
   if MsgOkCancel("Remove orderbag <" + alltrim( tb_delindex:aArray[tb_delindex:nAt, 1 ] ) + "> from the current dataset.")

      // get index file name
      fn_index := alltrim( tb_delindex:aArray[tb_delindex:nAt, 1 ] )

      // get alias name
      cAlias := alltrim(tb_Otis:aArray[tb_Otis:nAt, ATI_ALIAS ])

      // get selected index orderbag to close
      i := tb_delindex:nAt

      // set flag close index allowed or not
      temp := .T.

      // If the controlling index == the one that you want to close
      //  and if it is not the last one
      if (cAlias)->(IndexOrd()) == i .and. i > 1

         // ask confirmation
         PlayExclamation()
         temp := MsgOkCancel("WARNING"+crlf+crlf + ;
                               "You have chosen to close the active index." + crlf + ;
                               "Focus will be set to the first order." + crlf + crlf + ;
                               "Please confirm.")
      endif

      // if close allowed
      if temp

         // close index file
         (cAlias)->(ORDCLOSE(i))

         // set flag Dataset has changed
         Otis_Ds_changed(.T.)

         // reconstruct the tbrowse array
         aOtables := otis_get_area_info()

         // refresh tbrowse array
         tb_Otis:SetArray( aOtables )
         tb_Otis:refresh()

      endif

   endif

return nil


// Change some control rows,cols on resize of form 'delete index'
static function otis_rem_index_resize()

   // height and width browse table
   setproperty(ThisWindow.name, "tb_delindex", "Width", getproperty(ThisWindow.name,"ClientWidth") - th_w_ctrlgap * 2 )
   setproperty(ThisWindow.name, "tb_delindex", "Height", getproperty(ThisWindow.name,"ClientHeight") - th_bt_height * 1 - th_w_ctrlgap * 3 )

   // repos buttons
   setproperty(ThisWindow.name, "bt_Quit","Row", getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap )
   setproperty(ThisWindow.name, "bt_Quit","Col", getproperty(ThisWindow.name,"ClientWidth") - ( th_bt_width + th_w_ctrlgap ) * 1 )
   setproperty(ThisWindow.name, "bt_Delete","Row", getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap )
   setproperty(ThisWindow.name, "bt_Delete","Col", getproperty(ThisWindow.name,"ClientWidth") - ( th_bt_width + th_w_ctrlgap ) * 2 )

   // refresh
   tb_delindex:refresh()

return nil


// Get dbf/index info and return a array with :
//           alias, number of area, index, indexcount, .....
//
static function otis_get_area_info()

   local i, x, cAlias, aTblInfo, temp

   // init array to empty and index pointer
   aTblInfo := {}
   x := 0

   // scan areas for open tables
   FOR i := 1 TO 65534        // dont use 65535 and 65536 result in errors

      // only area nr between min and max or between reopen and reopen +
      *IF ( i >= ini_area_min_scan .and. i <= ini_area_max_scan ) ;
      *   .or. ;
      *   ( i >= ini_area_pi_reopen_start .and. i <= ini_area_pi_reopen_start + ini_area_max_scan - ini_area_min_scan ) ;

         // if the alias name is not empty the area is in use.
         IF !EMPTY( cAlias:=ALIAS(i) )

            // exclude always OTIS_DS.DBF
            if upper(cAlias) <> "DS_TABLE"

               // cAlias contains the alias name.
               //msgstop(cAlias + ' : ' + hb_ntos(i))

               // add a empty array element : Alias, Area_nr, Selected, Locked, recno, reccount, act.index, nbr ind, rdd, table filename
               //                               1        2        3       4        5       6          7        8       9   10
               aadd(aTblInfo, {" "," "," "," "," "," "," "," "," "," "," "} )
               // increment array index pointer
               x++

               // alias name
               aTblInfo[x, ATI_ALIAS] := cAlias

               // area nr
               aTblInfo[x, ATI_AREA] := STR( i, 5) + ' '

               // selected "*" if this table is the current selected area
               if i == nOldsel
                  aTblInfo[x, ATI_ISSELECTED] := "*"
               endif

               // Lock status :
               // 'F' if the file is locked or not shared (= exclusive)
               IF (cAlias)->(Sx_IsFlocked() .or. !Sx_IsShared() )
                  aTblInfo[x, ATI_ISLOCKED] := "F"
               // or
               // if record locked display a 'R'
               // if there are more records locked display 'R+'
               ELSE
                  if ( temp := LEN((cAlias)->(DBRLOCKLIST())) ) > 0
                     aTblInfo[x, ATI_ISLOCKED] := if( temp == 1, "R", "R+")
                  endif
               ENDIF

               // recno
               aTblInfo[x, ATI_RECNO] := STR( (cAlias)->(RECNO()), 10) + ' '
               // reccount
               aTblInfo[x, ATI_RECCNT] := STR( (cAlias)->(RECCOUNT()), 10) + ' '
               // active index nr
               aTblInfo[x, ATI_CURIND] := STR( (cAlias)->(INDEXORD()), 3) + ' '
               // number of index files
               aTblInfo[x, ATI_INDCNT] := STR( (cAlias)->(DBORDERINFO(DBOI_ORDERCOUNT)), 3) + ' '    // total of all orderbag files
               // rdd used
               aTblInfo[x, ATI_RDD] := (cAlias)->(RDDNAME())
               // table filename
               //aTblInfo[x,8] := (cAlias)->(Sx_Tablename())
               aTblInfo[x, ATI_FN] := STRTRAN((cAlias)->(Sx_Tablename()), GetCurrentFolder()+"\", '')

            ENDIF

         ENDIF

      *ENDIF

   NEXT i

   // if no entries return always a empty element for tbrowse.
   if len(aTblInfo) == 0
      aTblInfo := { {" "," "," "," "," "," "," "," "," "," "," "} }
   endif

   // return info array
return aTblInfo


// Refresh checkbox 'Dataset' has been changed
static function otis_Ds_changed(lStatus, lClearCmdLine)

   // defaults
   default lClearCmdLine := .T.

   lDsChanged := lStatus
   setproperty("form_otis", "cb_ds_changed", "Value", lDsChanged )

   // It is possible that Otis was opened by a double click in a file in Explorer.
   // Thus the cCmdline contains the table name.
   // We must reset cCmdline because a table or a dataset is loaded or added and
   // we don't want to AUTO CLOSE in that case the 'DS manager'
   // when closing the 'Inspector'.
   //
   if  lClearCmdLine
      cCmdline := ""
   endif

return nil


// load dataset on change of combobox with 5 most recent used datasets
static function otis_cbds_change()

   local ds_name

   // if cargo of dataset combobox is .T.
   //   The Cargo property is used to allow update only if the combobox is clicked and changed.
   //   Other parts of the program also change the "value" and triggers thus a ONCHANGE event.
   //   We set Cargo to .F. to prevent that this function is executed when it is not needed.
   //
   if getproperty("form_otis", "cb_dataset", "Cargo")

      // open dataset table
      //   EXCLUSIVE
      if Open_dstable()

         // get dataset name from MRU combobox
         ds_name := getproperty("form_otis", "cb_dataset","Item", getproperty( "form_otis", "cb_dataset", "Value") )

         // and load it if not empty
         if !empty(ds_name)
            ds_manager_load(ds_name)
         endif

         // set focus to browse
         domethod("form_otis", "tb_Otis", "SETFOCUS")

         // close
         select ds_table
         use

      endif

   endif

return nil


// Otis, event on change checkbox AutoOpen
static function otis_cbao_change()

   // can not be set if active rdd is DBFNTX
   if getproperty("form_otis", "cb_defrdd","Item", getproperty( "form_otis", "cb_defrdd", "Value") )=="DBFNTX" .and. getproperty("form_otis", "cb_AutoOpen", "Value")

      // reset to false
      setproperty( "form_otis", "cb_AutoOpen", "Value", .F.)

      // warning message
      msgstop("DBFNTX does not support AutoOpen of orderbag files.")

   endif

   // save new value in ini var.
   ini_ordbag_autoopen := getproperty(ThisWindow.name, "cb_AutoOpen", "Value")

   // and set/reset AutoOpen modus
   Set( _SET_AUTOPEN, ini_ordbag_autoopen)

return nil


// change rdd to use
static function otis_rdd_change()

   // get driver name
   local cRdd := getproperty("form_otis", "cb_defrdd","Item", getproperty( "form_otis", "cb_defrdd", "Value") )
   local lAutoOpen := .T.

   // get driver name
   ini_default_rdd := aDefaultRdd[ getproperty(ThisWindow.name,"cb_defrdd","Value") ]

   // set it as default driver
   RDDSETDEFAULT(ini_default_rdd)

   // activate AUTOOPEN for all drivers except NTX
   if cRdd == "DBFNTX"
      lAutoOpen := .F.
   endif
   setproperty(ThisWindow.name, "cb_AutoOpen", "Value", lAutoOpen)

   // and set/reset AutoOpen modus
   Set( _SET_AUTOPEN, ini_ordbag_autoopen)

   // if LETODBF
   if cRdd == "LETO"
      otis_leto_connect()
   endif

return nil


// Program Settings
static function Otis_settings()

   local r, c, c1, w

   // settings can only be changed if no tables open in the dataset
   if val(tb_Otis:aArray[tb_Otis:nAt, ATI_AREA ]) <> 0
      msgstop("Settings can only be changed if"+crlf + ;
              "there is no dataset loaded.")
      return nil
   endif

   // draw form
   DEFINE WINDOW f_settings ;
      row getproperty("form_otis", "row") + 125 ;
      col getproperty("form_otis", "col") + 250 ;
      clientarea 455, 455 ;
      TITLE 'Otis - Settings' ;
      WINDOWTYPE MODAL ;
      NOSIZE ;
      BACKCOLOR th_w_bgcolor

      // background controls
      DEFINE LABEL bg_sere
         ROW    th_w_ctrlgap
         COL    th_bt_width + th_w_ctrlgap * 2
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 3
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2
         VISIBLE .T.
      END LABEL
      // frame around, looks nicer
      define FRAME fr_seek
         ROW    th_w_ctrlgap
         COL    th_bt_width + th_w_ctrlgap * 2 + 1
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 3 - 1
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2
      end frame

      // row, col start position for controls
      w  := 50
      r  := th_w_ctrlgap * 2
      c  := th_w_ctrlgap * 3 + th_bt_width
      c1 := getproperty(ThisWindow.name,"ClientWidth") - th_w_ctrlgap * 3 - w

      // global program settings
      // ***********************
      define FRAME fr_ps
         ROW r
         COL c
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 5
         HEIGHT 92
         CAPTION "Program settings"
         FONTBOLD .T.
      end frame

      // Area nr Otis_ds.DBF
      r += 29
      DEFINE LABEL lb_AreaDS
          ROW       r+2
          COL       c
          VALUE     "   Area reserved for OTIS_DS.DBF"
          AUTOSIZE .T.
      END LABEL
      *
      define TEXTBOX tb_AreaDS
         row r
         col c1
         height 20
         width w
         ONCHANGE { || if(This.Value > 65534, msgstop("Maximum area number is 65534."), nil) }
         NUMERIC .T.
         VALUE ini_Otisdb_area_nr
         MAXLENGTH 5
      end textbox

      // Locking scheme
      r += 29
      DEFINE LABEL lb_Lockscheme
          ROW       r+2
          COL       c
          VALUE     "   Locking scheme 0...6   (Standalone only)"
          AUTOSIZE .T.
      END LABEL
      *
      define TEXTBOX tb_lockscheme
         row r
         col c1
         height 20
         width w
         ONCHANGE { || if(This.Value < 0 .or. This.Value > 6, msgstop("Locking scheme values 0...6"), nil) }
         NUMERIC .T.
         VALUE ini_lockscheme
         MAXLENGTH 5
      end textbox

      // PLUGIN mode settings
      // ********************
      r += 42
      define FRAME fr_frame
         ROW r
         COL c
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 5
         HEIGHT 120
         CAPTION "Plugin mode (.lib) area settings"
         FONTBOLD .T.
      end frame

      // Plugin scan from
      r += 29
      DEFINE LABEL lb_AreaFrom
          ROW       r+2
          COL       c
          VALUE     "   Scan start"
          AUTOSIZE .T.
      END LABEL
      *
      define TEXTBOX tb_AreaFrom
         row r
         col c1
         height 20
         width w
         NUMERIC .T.
         VALUE ini_area_min_scan
         MAXLENGTH 5
      end textbox

      // Plugin scan To
      r += 29
      DEFINE LABEL lb_AreaTo
          ROW       r+2
          COL       c
          VALUE     "   Scan end"
          AUTOSIZE .T.
      END LABEL
      *
      define TEXTBOX tb_AreaTo
         row r
         col c1
         height 20
         width w
         NUMERIC .T.
         VALUE ini_area_max_scan
         MAXLENGTH 5
      end textbox

      // Plugin reopen start
      r += 29
      DEFINE LABEL lb_AreaRO
          ROW       r+2
          COL       c
          VALUE     "   Ghost area offset"
          AUTOSIZE .T.
      END LABEL
      *
      define TEXTBOX tb_AreaRO
         row r
         col c1
         height 20
         width w
         NUMERIC .T.
         VALUE ini_area_pi_reopen_start
         MAXLENGTH 5
      end textbox

      // CMDLINE settings
      // ****************
      r += 42
      define FRAME fr_cl
         ROW r
         COL c
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 5
         HEIGHT 92
         CAPTION "Command line settings"
         FONTBOLD .T.
      end frame

      // cmdline Autopen mode label
      r += 29
      DEFINE LABEL lb_cl_autopen
          ROW       r+2
          COL       c
          VALUE     "   AutoOpen"
          AUTOSIZE .T.
      END LABEL
      // cmdline Autopen mode checkbox
      DEFINE Checkbox cb_cl_autopen
         ROW r+2
         COL c1
         WIDTH 24
         HEIGHT 24
         Caption ''
         TOOLTIP "Command line AutoOpen orderbag mode (only for cdx or nsx)."
         LEFTJUSTIFY .F.
         Value ini_cl_autopen
         //ON CHANGE { || ini_cl_autopen :=  }
      END Checkbox

      // cmdline Exclusive mode label
      r += 29
      DEFINE LABEL lb_cl_excl
          ROW       r+2
          COL       c
          VALUE     "   Open in Exclusive mode"
          AUTOSIZE .T.
      END LABEL
      // cmdline Exclusive mode checkbox
      DEFINE Checkbox cb_cl_excl
         ROW r+2
         COL c1
         WIDTH 24
         HEIGHT 24
         Caption ''
         TOOLTIP "Command line open Exclusive mode."
         LEFTJUSTIFY .F.
         Value ini_cl_excl
         //ON CHANGE { || ini_cl_excl :=  }
      END Checkbox

      // LETODBF settings
      // ****************
      r += 42
      define FRAME fr_letodbf
         ROW r
         COL c
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 5
         HEIGHT 91
         CAPTION "LetoDbf server settings"
         FONTBOLD .T.
      end frame

      // LetoDbf ip server
      r += 29
      DEFINE LABEL lb_LetoIp
          ROW       r+2
          COL       c
          VALUE     "   Ip / hostname"
          AUTOSIZE .T.
      END LABEL
      *
      define TEXTBOX tb_LetoIp
         row r
         col c1 - 125
         height 20
         width 175
         VALUE ini_leto_ipserver
         TOOLTIP "Ex. 192.168.1.240, hostname, otis.ddns.net, localhost, ..."
         //MAXLENGTH 5
      end textbox

      // LetoDbf port server
      r += 29
      DEFINE LABEL lb_LetoPort
          ROW       r+2
          COL       c
          VALUE     "   Port"
          AUTOSIZE .T.
      END LABEL
      *
      define TEXTBOX tb_LetoPort
         row r
         col c1
         height 20
         width w
         INPUTMASK '9999'
         VALUE ini_leto_portserver
         TOOLTIP "Default 2812. Don't forget LetDbf use 2 ports, this one and the next one."
         MAXLENGTH 4
      end textbox

      // init row, col position for other buttons
      r := th_w_ctrlgap
      c := th_w_ctrlgap

      // Button : Save
      DEFINE LABEL bt_Save
         ROW  r
         COL  c
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         Value " Save"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION { || otis_settings_save(), ThisWindow.release }
         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
      END label

      // Button : Defaults
      r := r + ( th_bt_height + th_w_ctrlgap ) * 1
      DEFINE LABEL bt_Defaults
         ROW  r
         COL  c
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         Value " Set Defaults"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION { || SetProperty( ThisWindow.NAME, "tb_AreaDS",     "Value", Val( def_Otisdb_area_nr ) ), ;
                     SetProperty( ThisWindow.NAME, "tb_AreaFrom",   "Value", Val( def_area_min_scan ) ), ;
                     SetProperty( ThisWindow.NAME, "tb_AreaTo",     "Value", Val( def_area_max_scan ) ), ;
                     SetProperty( ThisWindow.NAME, "tb_AreaRO",     "Value", Val( def_area_pi_reopen_start ) ), ;
                     SetProperty( ThisWindow.NAME, "tb_LetoIp",     "Value", def_ini_leto_ipserver ), ;
                     SetProperty( ThisWindow.NAME, "tb_LetoPort",   "Value", def_ini_leto_portserver ), ;
                     SetProperty( ThisWindow.NAME, "cb_cl_autopen", "Value", def_ini_cl_autopen ), ;
                     SetProperty( ThisWindow.NAME, "cb_cl_excl",    "Value", def_ini_cl_excl ), ;
                     SetProperty( ThisWindow.NAME, "tb_lockscheme", "Value", Val( def_ini_lockscheme ) ) ;
                }

         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
      END label

      // Button : help locking schemes
      r := r + ( th_bt_height + th_w_ctrlgap ) * 1
      DEFINE LABEL bt_helpls
         ROW  r
         COL  c
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         Value " ? Lock schemes"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION otset_helpls()

         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
      END label

      // Button : Test connexion LetoDbf
      DEFINE LABEL bt_connleto
         ROW  getproperty(ThisWindow.name,"ClientHeight") - ( th_bt_height + th_w_ctrlgap) * 3
         COL  c
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         Value " Test conn. Leto"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION otis_leto_connect(This.tb_LetoIp.Value)
         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
      END label

      // button : Cancel
      DEFINE Label bt_Cancel
         ROW  getproperty(ThisWindow.name,"ClientHeight") - ( th_bt_height + th_w_ctrlgap) * 1
         COL  th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Cancel"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         ACTION ThisWindow.release
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      END label

      // Escape Key
      ON KEY ESCAPE ACTION This.bt_Cancel.OnClick

   end window

   // activate window
   ACTIVATE WINDOW f_settings

return nil


// save settings
static function otis_settings_save()

   // get all values and copy them to there corresponding ini_ var
   ini_Otisdb_area_nr       := getproperty("f_settings","tb_AreaDS","Value")
   ini_lockscheme           := getproperty("f_settings","tb_lockscheme","Value")
   *
   ini_area_min_scan        := getproperty("f_settings","tb_AreaFrom","Value")
   ini_area_max_scan        := getproperty("f_settings","tb_AreaTo","Value")
   ini_area_pi_reopen_start := getproperty("f_settings","tb_AreaRO","Value")
   *
   ini_leto_ipserver        := getproperty("f_settings","tb_LetoIp","Value")
   ini_leto_portserver      := getproperty("f_settings","tb_LetoPort","Value")
   *
   ini_cl_autopen           := getproperty("f_settings","cb_cl_autopen","Value")
   ini_cl_excl              := getproperty("f_settings","cb_cl_excl","Value")

   // save new settings on disk
   FWRITEINI(fn_ini)

return nil


// connect to a LetoDbf server
static function otis_leto_connect(cHost)

   //
   local lConnected := .F.

   // leto port number, default is 2812 if empty
   local cPort := if( empty(ini_leto_portserver),  "2812", ini_leto_portserver )
   local cFull_Ip, temp

   // default is ini setting if not passed.
   //  settings menu can call this function to test a connexion
   //  on a specific ip but the ip is still in the textbox and not yet
   //  copy into the ini var.
   default cHost := ini_leto_ipserver

   // Standalone mode, connect to a server
   if lStandalone

      // message if no IP adresse is defined
      if empty(ini_leto_ipserver)
         msgstop("WARNING" + crlf + crlf + ;
                 "Connection to LetoDbf server is impossible." + crlf + ;
                 "There is no server Ip adresse or Port defined." + crlf + ;
                 "See 'Settings' menu." ;
                )

      // connect to LetoDbf server.
      else

         // create full ip "//xxx.xxx.xxx.xxx:portnr/"
         cFull_Ip :=  "//" + alltrim(cHost) + ":" + alltrim(ini_leto_portserver) + "/"

         // wait box "trying to connect"
         WAIT WINDOW ("Trying to connect to LetDbf server on ip " + cFull_ip ) NOWAIT
         CursorWait()
         do events

         // make connection
         temp := leto_Connect( cFull_Ip)

         // clear wait message
         CursorArrow()
         WAIT CLEAR
         do events

         // failed
         IF temp < 0
            msgstop( "Failed to connect to LetoDbf server on ip :" + crlf + crlf + ;
                     cFull_Ip + crlf + crlf + ;
                     "Error : " + hb_ntos(temp) ;
                   )

         // display connexion info
         else
            otis_info_letdbf()

            // refresh EXCLUSIVE and AUTOPEN for update of LetDbf server
            Set( _SET_EXCLUSIVE, ini_lOpen_Exclusive )
            Set( _SET_AUTOPEN, ini_ordbag_autoopen)

            lConnected := .T.

         ENDIF

      endif


   // plugin mode, display connection info established by the running program.
   else
      // Warning message, no server is connected
      if leto_Connect() < 0
         msgstop("WARNING" + crlf + crlf + ;
                 "You are in PLUGIN mode and your program" + crlf + ;
                 "is NOT connected to a LetoDbf server.";
                )

      // display connection info
      else
         otis_info_letdbf()
         lConnected := .T.
      endif
   endif

return lConnected


// collect and display info of current LetoDbf connexion
static function otis_info_letdbf()

   msginfo("You are connected to server LetoDbf : "  + crlf + crlf + ;
           "   Id"      + repl(chr(9),2) + ": " + hb_ntos(LETO_CONNECT()) + crlf + ;
           "   Version" + repl(chr(9),2) + ": " + LETO_GETSERVERVERSION() + crlf + ;
           "   Mode"    + repl(chr(9),2) + ": " + hb_ntos(LETO_GETSERVERMODE()) + crlf + ;
           "   Ip/Hostname"  + repl(chr(9),1) + ": " + LETO_SETCURRENTCONNECTION() )

return nil


// About OTIS info form
static function otis_about()

   MsgInfo("OTIS - Open Table InSpector (c)" + crlf + ;
             crlf + ;
             "Version "  + Version + ' ' + Versionbuild + ' - ' + Versiondate + crlf + ;
             crlf + ;
             "Author : Hans Marc (Belgium)" + crlf + ;
             "This program is written with Harbour MiniGui"+ crlf + "and is FreeWare." + crlf + crlf + ;
             "Mode" + repl(chr(9),2) + ": " + if(lStandAlone, "Standalone executable", "Plugin") + crlf + ;
             "Exe path" + repl(chr(9),2) + ": " + hb_dirbase() + crlf + ;
             "Os Codepage" + chr(9) + ": " + hb_cdpOS() ;
            , "About OTIS")

return nil


// show lockingscheme info
static function otset_helpls()

   local cInfo := "  Locking schemes %T1 Val. %T1 Description |"   + ;
                  "  ------------------- %T1 ---- %T1 ------------------------------------------------------------------------ |" + ;
                  " |" + ;
                  "  DEFAULT   %T1 0 |" + ;
                  "  CLIPPER   %T1 1  %T1 default Clipper locking scheme |" + ;
                  "  COMIX     %T1 2  %T1 COMIX and CL53 DBFCDX hyper locking scheme |" + ;
                  "  VFP       %T2 3  %T1 [V]FP, CL52 DBFCDX, SIx3 SIXCDX, CDXLOCK.OBJ |" + ;
                  "  HB32      %T2 4  %T1 Harbour hyper locking scheme for 32-bit file API, table size max 4GB |" + ;
                  "  HB64      %T2 5  %T1 Harbour hyper locking scheme for 64-bit file API, table size no limit |" + ;
                  "  CLIPPER2  %T1 6  %T1 extended Clipper locking scheme NTXLOCK2.OBJ |" + ;
                  "  |" + ;
                  "  Function  SET(_SET_DBFLOCKSCHEME, 0...6 )|" + ;
                  "  |" + ;
                  "  |"

   // show it
   show_help(cInfo, 580, 275)

return nil

//***********************************************************************************************************************************
   * Procedure ------------------------


// Table / index properties
//
//       Export structure to a *.csv file
//       Export structure to a *.prg file
//       Show table / index info
//
static function table_prop(cWinname)

   local i, r, c, nOldsel, nNewsel, cAlias, aColVis, cTablename
   local aGrsize := {}

   // construct at each entry a unique form id name so that multiple forms can be opened.
   local f_tabprop := 'f_tabprop_' + cWinname

   MEMVAR nGrsize
   Private nGrsize := 0

   // if any table opened to attach a index file
   if len(aOtables) == 0 .or. empty(aOtables[ 1, ATI_ALIAS ])
      Msginfo("There are no tables open in the dataset.")
      return nil
   endif

   // Set focus back to this form if it is already open
   if ISWINDOWDEFINED("'"+f_tabprop+"'")
      domethod( f_tabprop, "SETFOCUS")
      return nil
   endif

   // save current area
   nOldsel := select()

   // get area number from selected row in tbrowse
   nNewsel := tb_Otis:aArray[tb_Otis:nAt, ATI_AREA ]

   // select area
   select (nNewsel)
   cAlias := alias()

   // fill array with structure of selected table
   aColVis := dbStruct()
   // add col with field nr
   for i := 1 to len(aColVis)
      aColVis[i] := { strzero(i,3), aColVis[i,1], aColVis[i,2], aColVis[i,3], aColVis[i,4]  }
   next i

   // get tablename
   cTablename := Sx_Tablename()

   // restore old select
   select (nOldsel)

   // define grid col size
   aGrsize := { 30, 120, 40, 80, 80 }
   aeval( aGrsize, { |val| nGrsize += val } )
   nGrsize += 27                                // grid borders

   // show structure in a grid
   define window &f_tabprop ;
      AT 100, 100 ;
      Clientarea th_bt_width + nGrsize + th_w_ctrlgap * 3, th_w_height ;
      TITLE cTablename ;
      BACKCOLOR th_w_bgcolor ;
      WINDOWTYPE STANDARD ;
      ON SIZE     table_prop_resize() ;
      ON MAXIMIZE table_prop_resize() ;
      ON MINIMIZE table_prop_resize() ;
      ON RELEASE  table_prop_release()                 // set focus back to OTIS main screen
      ;//NOSIZE

      // set min,max width
      ThisWindow.MaxWidth := getproperty(ThisWindow.name, "Width")
      ThisWindow.MinWidth := ThisWindow.MaxWidth

      // define grid with open tables info
      @ th_w_ctrlgap, th_w_ctrlgap + th_bt_width + th_w_ctrlgap GRID gr_struct ;
         ;//WIDTH th_w_width / 2 - th_w_ctrlgap * 2 ;
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 3 ;
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2 ;
         HEADERS {'Nr', 'Fieldname','Type','Len','Dec'} ;
         WIDTHS  aGrsize ;
         JUSTIFY {GRID_JTFY_LEFT, GRID_JTFY_LEFT, GRID_JTFY_CENTER, GRID_JTFY_RIGHT, GRID_JTFY_RIGHT } ;
         ITEMS aColVis ;
         VALUE 1

      // init row, col position for other buttons
      r := th_w_ctrlgap
      c := th_w_ctrlgap

      // Button : Export structure as PRG
      DEFINE LABEL bt_exp_prg
         ROW r
         COL c
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         Value " Struct. -> prg"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION table_export(cTablename, cAlias, aColVis, "prg")
         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
      END label

      // Button : Export structure as CSV
      r := r + th_bt_height + th_w_ctrlgap
      DEFINE LABEL bt_exp_csv
         ROW r
         COL c
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         Value " Struct. -> csv"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION table_export(cTablename, cAlias, aColVis, "csv")
         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
      END label

      // Button : Struct to clipboard
      r := r + th_bt_height + th_w_ctrlgap
      DEFINE LABEL bt_struct_to_cb
         ROW r
         COL c
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         Value " Struct. -> clipb."
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION table_export(cTablename, cAlias, aColVis, "clipboard")
         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
      END label

      // Button : Table info
      r := r + (th_bt_height + th_w_ctrlgap) * 2
      DEFINE LABEL bt_table_info
         ROW r
         COL c
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         Value " Table info"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION show_table_info(cTablename, cAlias)
         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
      END label

      // Button : Index info
      r := r + th_bt_height + th_w_ctrlgap
      DEFINE LABEL bt_index_info
         ROW r
         COL c
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         Value " Index info"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION show_index_info(cAlias)
         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
      END label

      // Quit button
      DEFINE LABEL bt_Quit
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap * 1
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Quit"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         ACTION { || ThisWindow.Release, domethod(cWinname, "SETFOCUS") }
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         /*
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
         */
      END label

      // Escape key Quits
      ON KEY ESCAPE OF &(f_tabprop) ACTION {|| domethod(ThisWindow.name, "RELEASE"), domethod(cWinname, "SETFOCUS")}

   END WINDOW

   // activate
   //CENTER WINDOW w_struct
   Activate WINDOW &f_tabprop

return nil


// table_prop release
static function table_prop_release()

   /*
   // set focus back to OTIS main screen after closing this form.
   if ISWINDOWDEFINED("form_otis")
      domethod( "form_otis", "SETFOCUS")
      return nil
   endif
   */

return nil


// Show structure browse windows RESIZE, resize and reposition controls in this window.
static function table_prop_resize()

   // update height "structure" grid table
   setproperty(ThisWindow.name, "gr_struct","Height", getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2)

   // repos Quit button
   setproperty(ThisWindow.name, "bt_Quit","row", getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap * 1 )

return nil


// Export structure to a *.prg file, a *.csv file or copy structure to the clipboard
static function table_export( cTablename, cAlias, aColVis, cType )

   local i, temp, fqfn_fdest, filenamename, ;
         body         := "", ;
         header       := "", ;
         cClipboard   := "", ;
         prg_index_code

   // if or csv
   if cType $ 'csv,prg'

      // get file name without path or extension
      filenamename := upper( hb_FNameName(cTablename) )

      // get only filename and add '.csv'
      fqfn_fdest := 'Table_' + fileNameName + '.' + cType

      // Ask for destination folder and filename
      fqfn_fdest := Putfile( { { cType+' files','*.'+cType} } , 'Export as '+ cType +' file', GetCurrentFolder(), nil, fqfn_fdest )

      // if a destination  folder and name selected
      if !empty(fqfn_fdest)

         // common header text for csv and prg file
         header := "// " + crlf + ;
                   "// Otis stands for 'Open Table InSpector'." + crlf + ;
                   "// " + crlf + ;
                   "// Table   ; " + cTablename + crlf + ;
                   "// Date    ; " + dtoc(date()) + crlf + ;
                   "// Time    ; " + time() + crlf + ;
                   "// " + crlf

         // get index info, text and prg code
         temp := collect_index_info(cAlias)        // return array, details see function
         // add index info to header
         header += temp[1]
         // init footer for prg type with 'ON INDEX ....' code.
         prg_index_code := temp[2] + crlf + 'Return nil' + crlf

         // if type CSV
         if cType == 'csv'

            // init header with delimiters so that the csv file can be opened with Excel
            header := ";;;" + header + crlf
            // add to header some info
            header := ";;;" + crlf + ;
                      "// " + crlf + ;
                      "// This document is generated by OTIS()" + crlf + ;
                      + header

            // add fields headers
            body := "Fieldname;Type;Len;Dec" + body + crlf

            // fill the body with the structure
            for i := 1 to len(aColVis)
               body += aColVis[i,2] + ";" + aColVis[i,3] + ";" + hb_ntos(aColVis[i,4]) + ";" + hb_ntos(aColVis[i,5]) + crlf
            next i

            // delete // in header
            header := strtran(header, '//', "" )

         endif

         // if type prg
         if cType == 'prg'

            // add to header some info
            header := "// " + crlf + ;
                      "// This code is generated by OTIS()" + crlf + ;
                      + header

            // function name
            body := 'Function Dbf_Create_' + filenamename + '()' + crlf + crlf
            // create structure
            body += "  DBCREATE( '"+ filenamename +  "', {;" + crlf

            // fill array with the structure :
            //                    { array name         fieldname                           type                      len                                     dec
            for i := 1 to len(aColVis)
               body += "          { " + padr("'" + aColVis[i,2] + "'", 12 ) + ", '" + aColVis[i,3] + "', " + padl(hb_ntos(aColVis[i,4]), 3) + ", " + padl(hb_ntos(aColVis[i,5]), 3) + " } ,;"+ crlf
            next i
            // replace chars ,;crlf with ;crlf
            body := substr( body, 1, len(body) - 4 ) + ";" + crlf
            body += '          }, ' + "'"+RDDSETDEFAULT()+"' )" + crlf
            //body += crlf + 'Return nil' + crlf

         endif

         // if file to save
         if cType <> 'clipboard'

            // default write file is allowed = .T.
            temp := .T.

            // check if file exist already
            if file(fqfn_fdest)

               // ask overwrite confirmation if this is the case
               if msgyesno("This file exists already."+ crlf + crlf + "Do you want to overwrite it ?" )

                  // delete it first to see if it not open in your editor
                  if FErase(fqfn_fdest) < 0
                     // message : file delete error
                     Msgstop("File   " + fqfn_fdest + "   could not be overwritten." + crlf + crlf + ;
                               "It is probably still open in your editor."+crlf + "Close it and try again." )
                     temp := .F.
                  endif

               // overwritten not allowed
               else
                  temp := .F.
               endif

            endif

            // write file if allowed
            if temp
               hb_MemoWrit(fqfn_fdest, header + body + prg_index_code)
            endif

         endif

         // eventually ask to open csv with excel or prg with your editor
         // todo

      endif


   // if type clipboard
   elseif cType == 'clipboard'

      // add to header some info
      cClipboard := "// " + crlf + ;
                    "// Generated by OTIS()" + crlf + ;
                    "// " + crlf + ;
                    "// Table    : " + cTablename + crlf + ;
                    "// Date     : " + dtoc(date()) + crlf + ;
                    "// Time     : " + time() + crlf + ;
                    "// " + crlf + ;
                    "// " + "Nr" + repl(chr(9),3) + ;
                            "Fieldname" + repl(chr(9),3) + ;
                            "Type" + chr(9) + ;
                            "Len" + chr(9) + ;
                            "Dec" + crlf + ;
                    "// " + crlf

      // fill string with the structure :
      //                  nr  fieldname  type  len  dec
      for i := 1 to len(aColVis)
         cClipboard += "// " + ;
                       strzero(i,3) + chr(9) + chr(9) +;
                       padr(aColVis[i,2],15) + chr(9) + ;
                       aColVis[i,3] + chr(9) + chr(9) + ;
                       strzero(aColVis[i,4], 3) + chr(9) + ;
                       strzero(aColVis[i,5], 3) + ;
                       + crlf
      next i

      // copy to clipboard
      CopyToClipboard(cClipboard)
      msginfo("Done")

   endif

return nil

// Collect Table info
static function show_table_info(cTablename, cAlias)

   local i, temp, cInfo := ""

   // Get all kind of info
   //   see dbinfo.ch for all defined vars.
   Local aInfo := { ;
                    {   0, "" },;
                    { DBI_FULLPATH,       "Full name & path"+repl(chr(9),4) },;
                    { DBI_ALIAS,          "Alias for this workarea"+repl(chr(9),3) },;
                    {  -1,                "Area select number"+repl(chr(9),3), "SELECT()"},;
                    {   0, "" },;
                    {  -1,                "Dbf driver used"+repl(chr(9),4), "RDDNAME()" },;
                    { DBI_LOCKSCHEME,     "Locking scheme used by RDD"+repl(chr(9),2) },;
                    { DBI_CODEPAGE,       "Codepage used"+repl(chr(9),4) },;
                    { DBI_ISENCRYPTED,    "Is encrypted"+repl(chr(9),4) },;
                    {   0, "" },;
                    { DBI_LASTUPDATE,     "Last modification date"+repl(chr(9),3) },;
                    {   0, "" },;
                    { DBI_SHARED,         "Was the file opened shared?"+repl(chr(9),2) },;
                    { DBI_ISREADONLY,     "Was the file opened readonly?"+repl(chr(9),2) },;
                    {   0, "" },;
                    { DBI_GETHEADERSIZE,  "Data file's header size"+repl(chr(9),3) },;
                    { DBI_GETRECSIZE,     "The size of 1 record in the file"+repl(chr(9),2) },;
                    { DBI_FCOUNT,         "Number of fields in a record"+repl(chr(9),2) },;
                    {  -1,                "Number of records"+repl(chr(9),3), "RECCOUNT()"},;
                    {   0, "" },;
                    { DBI_DBFILTER,       "Current Filter setting"+repl(chr(9),3) },;
                    {   0, "" },;
                    { DBI_ISFLOCK,        "Is there a file lock active?"+repl(chr(9),3) },;
                    { DBI_LOCKCOUNT,      "Number of record locks"+repl(chr(9),3) },;
                    { DBI_GETLOCKARRAY,   "An array of locked records numbers"+repl(chr(9),2) },;
                    {   0, "" },;
                    { DBI_CHILDCOUNT,     "Number of child relations set"+repl(chr(9),2) },;
                    {   0, "" },;
                    { DBI_FOUND,          "Same as Found()"+repl(chr(9),4) },;
                    { DBI_BOF,            "Same as Bof()"+repl(chr(9),4) },;
                    { DBI_EOF,            "Same as Eof()"+repl(chr(9),4) },;
                    {   0, "" },;
                    { DBI_MEMOTYPE,       "Type of MEMO file: DBT, SMT, FPT"+repl(chr(9),2) },;
                    { DBI_MEMOEXT,        "The memo file's file extension"+repl(chr(9),2) },;
                    { DBI_MEMOBLOCKSIZE,  "Memo File's block size"+repl(chr(9),3) };
                  }

   // put info in a string
   for i := 1 to len(aInfo)

      // add own specific data (-1)
      temp := ""
      if aInfo[i,1] < 0
         temp := hb_ntos( &("('"+cAlias+"')->("+aInfo[i,3]+")") )

      // or add dbinfo() data (>0)
      elseif aInfo[i,1] > 0
         temp := alltrim( CStr( (cAlias)->(DBINFO(aInfo[i,1]))) )
      endif

      cInfo := cInfo + if( aInfo[i,1] <> 0, aInfo[i,2] + ": " + temp, "")  + crlf

   next i

   // show it
   show_info(cTablename, cInfo)

return nil


// display selected dbf index files information
static function show_index_info(cAlias)

   local cinfo
   local cTablename := (cAlias)->(Sx_Tablename())

   // collect info
   cInfo := collect_index_info(cAlias)[1]

   // delete // chars
   cInfo := strtran(cInfo, "//","")

   // add some header info
   cInfo := "Table : " + cTablename + crlf + crlf + cInfo

   // show it
   show_info(cTablename, cInfo)

return nil


// display selected dbf current active index info
static function show_Active_index_info(cAlias, nCurrentIndexNbr)

   local aIndexInfo
   local cTablename := alltrim((cAlias)->(Sx_Tablename()))

   // -1 from combobox value
   nCurrentIndexNbr--

   // show all index if no tag selected
   if nCurrentIndexNbr == 0
      show_index_info(cAlias)

   // else only the one that is active
   else

      // collect info
      aIndexInfo := collect_index_info(cAlias)[3]

      // build info to show
      cInfo := ""
      cInfo += "//  OrderBag name : " + Sx_IndexName(nCurrentIndexNbr) + crlf                                           // path and filename
      cInfo += "//" + crlf
      cInfo += "//          Order nbr" + chr(9) + ": " + hb_ntos(nCurrentIndexNbr) + crlf
      cInfo += "//          Tag "   + chr(9) + ": " + aIndexInfo[nCurrentIndexNbr, OI_TAG] + crlf
      cInfo += "//          Key "   + chr(9) + ": " + aIndexInfo[nCurrentIndexNbr, OI_KEY] + crlf
      cInfo += "//          For "   + chr(9) + ": " + aIndexInfo[nCurrentIndexNbr, OI_FOR] + crlf
      cInfo += "//          Unique" + chr(9) + ": " + if(aIndexInfo[nCurrentIndexNbr, OI_UNIQUE],".T.",".F.") + crlf
      cInfo += "//          Descending" + chr(9) + ": " + if(aIndexInfo[nCurrentIndexNbr, OI_ASCDESC],".T.",".F.") + crlf
      cInfo += "//" + crlf
      cInfo := strtran(cInfo, "//","")

      // add some header info
      cInfo := "Table : " + cTablename + crlf + crlf + cInfo
      // delete // chars
      cInfo := strtran(cInfo, "//","")

      // show it
      show_info(cTablename, cInfo, .T.)

   ENDIF

return nil


// Collect info for all index files open in the passed area.
//
// Return array with 3 elements :
//    1. text with collected info of all index files
//    2. text with prg code for creating all index files "index on ...."
//    3. array with { index filename, tag, key, for, unique, descend }
//
static function collect_index_info(cAlias)

   local i, x, nOldsel, nOldorder
   local cInfo := "", prg_code := "", aIndexInfo := {}
   local nOrdercnt, cBagName

   // save area
   nOldsel   := select()
   nOldorder := IndexOrd()

   // select the one from who to collect index info
   Select(cAlias)

   // get order count
   nOrdercnt := DBORDERINFO(DBOI_ORDERCOUNT)        // returns total of all orders even if multiple files

   // if there are index files, add index file info, filename, key, for, ....
   if nOrdercnt <> 0

      // add header index section
      cInfo += "// Index info : " + crlf
      cInfo += "//       Orderbags" + chr(9) + ": "+ hb_ntos(DBORDERINFO(DBOI_BAGCOUNT)) + crlf        // returns number of opened index files
      cInfo += "//       Orders"    + chr(9) + ": "+ hb_ntos(nOrdercnt) + crlf
      cInfo += "//" + crlf

      // init order bag name
      cBagName := ""

      // init orderbag physical file counter
      i := 0

      // for each order
      for x := 1 to nOrdercnt

         // get order bag name
         if cBagName <> ORDBAGNAME(x)

            // set new bag name
            cBagName := ORDBAGNAME(x)
            // next physical index file
            i++
            // add header info, index order number, index filename, KEY and FOR clause
            //cInfo += "// "+ str( i, 3) + "  OrderBag name : " + ORDBAGNAME(i) + crlf           // only filename
            cInfo += "// "+ str( i, 3) + "  OrderBag name : " + Sx_IndexName(i) + crlf       // path and filename

         endif

         // add to array
         aadd(aIndexInfo, { cBagName, ;                              // "OI_BAGNAME"
                            ORDNAME( x, cBagName),;                  // "OI_TAG"
                            ORDKEY( x, cBagName), ;                  // "OI_KEY"
                            ORDFOR( x, cBagName), ;                  // "OI_FOR"
                            ORDISUNIQUE( x, cBagName), ;             // "OI_UNIQUE"
                            ORDDESCEND(x, cBagName) ;                // "OI_ASCDESC"
                          };
             )

         // info
         cInfo += "//          Order nbr" + chr(9) + ": " + hb_ntos(x) + crlf
         cInfo += "//          Tag "   + chr(9) + ": " + aIndexInfo[x, OI_TAG] + crlf
         cInfo += "//          Key "   + chr(9) + ": " + aIndexInfo[x, OI_KEY] + crlf
         cInfo += "//          For "   + chr(9) + ": " + aIndexInfo[x, OI_FOR] + crlf
         cInfo += "//          Unique" + chr(9) + ": " + if(aIndexInfo[x, OI_UNIQUE],".T.",".F.") + crlf
         cInfo += "//          Descending" + chr(9) + ": " + if(aIndexInfo[x, OI_ASCDESC],".T.",".F.") + crlf
         cInfo += "//" + crlf

         // prg code
         prg_code += "  INDEX ON  " + aIndexInfo[x, OI_KEY] + " ;" + crlf + ;
                     "        TAG " + aIndexInfo[x, OI_TAG] + " ;" + crlf + ;
                     "        TO  " + aIndexInfo[x, OI_BAGNAME] + ;
                               if( !empty(aIndexInfo[x, OI_FOR]),  " ;" + crlf + "        FOR " + aIndexInfo[x,4], "" ) + ;
                               if( aIndexInfo[x, OI_UNIQUE], " ;" + crlf +          "        UNIQUE","" ) + ;
                               if( aIndexInfo[x, OI_ASCDESC],  " ;" + crlf +          "        DESCENDING","" ) + ;
                               crlf + crlf
      next x

   endif

   // finish prg code, Header, USE table, CODE, USE
   if !empty(prg_code)
      prg_code := crlf + "  // Create index files" + crlf + ;
                  "  USE " + alltrim( hb_FNameNameExt(Sx_Tablename())) + " NEW" + crlf + crlf + ;
                  prg_code + ;
                  "  USE " +  crlf
   // no index files
   else
      prg_code := crlf + "  // No index files." + crlf
   endif

   // restore area if any was open
   select (nOldsel)
   *
   if !empty(Alias())
      ORDSETFOCUS(nOldOrder)
   endif

return { cInfo, prg_code, aIndexInfo }


//***********************************************************************************************************************************
   * Procedure ------------------------


// Manage index files, create, delete, ...
static function index_mng(cWinname)

   local temp, i, aIndexInfo, nIndexOrd, aButtons

   // if called from otis main
   // get area nr of selected dbf in the dataset table
   //local nSelect := val(tb_Otis:aArray[tb_Otis:nAt, ATI_AREA ])

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // construct at each entry a unique form id name so that multiple forms can be opened.
   LOCAL f_indmng := 'f_indmng_' + cWinname       // cWinname is already a unique form ID

   // Set focus back to this form if it is already open
   if ISWINDOWDEFINED("'"+f_indmng+"'")
      domethod( f_indmng, "SETFOCUS")
      return nil
   endif

   // if there are index files opened
   //if (cAlias)->(Sx_IndexCount()) <> 0
   if .T.

      // get current active order
      nIndexOrd := (cAlias)->(IndexOrd())

      // fill temp array with all orderindex info
      temp := collect_index_info(cAlias)[3]
      // fill array for tbrowse below
      //  place KEY and FOR on 2 diff. lines in the same cell.
      aIndexInfo := {}
      //
      if len(temp) <> 0
         for i := 1 to len(temp)
            aadd(aIndexInfo, { temp[i, OI_BAGNAME], ;
                               'Tag   : ' + temp[i, OI_TAG] + space(10) + if(temp[i, OI_UNIQUE],"Unique","") + space(10)+ if(temp[i, OI_ASCDESC],"Descending","Ascending") + crlf + ;
                               'Key   : ' + temp[i, OI_KEY] + crlf + ;
                               'For    : ' + temp[i, OI_FOR] ;
                             } )
         next i

      // create a empty entry if no index files open for the moment
      else
         aIndexInfo := { {"", ""} }
      endif


      // show all index files and select one to delete from the dataset
      define window &f_indmng ;
         row getproperty(cWinname,"row") + 200 ;
         col getproperty(cWinname,"col") + 200 ;
         clientarea 860 + th_w_ctrlgap * 2, 310 + th_bt_height + th_w_ctrlgap * 3 ;
         TITLE "OTIS - Index manager for alias : " + cAlias ;
         backcolor th_w_bgcolor ;
         WINDOWTYPE STANDARD ;
         ON RELEASE o_Browse:SetFocus() ;
         ON SIZE index_mng_resize(ThisWindow.name) ;
         ON MAXIMIZE index_mng_resize(ThisWindow.name)

         // set min, max
         //ThisWindow.MaxWidth := getproperty(ThisWindow.name, "WIDTH")
         ThisWindow.MinWidth := ThisWindow.MaxWidth / 2
         ThisWindow.MinHeight := getproperty(ThisWindow.name, "Height")

          // tsbrowse
         define TBROWSE tb_delindex ;
            AT th_w_ctrlgap * 1, th_bt_width * 1 + th_w_ctrlgap * 2 ;
            WIDTH getproperty(ThisWindow.name,"ClientWidth") - th_bt_width * 1 -  th_w_ctrlgap * 3 ;
            HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2 ;
            COLORS {CLR_BLACK, CLR_WHITE} ;
            SELECTOR .T.

            // set array
            tb_delindex:SetArray( aIndexInfo )

            // set colors
            tb_delindex:SetColor( { 1, 2, 4, 5, 6 }, { ;
                        CLR_BLACK, ;
                        CLR_WHITE, ;
                        { CLR_WHITE, RGB(210, 210, 220) }, ;
                          CLR_WHITE, RGB(21, 113, 173) }, )

            // add column with index nr and "*" if the row is the active index
            ADD COLUMN TO tb_delindex  ;
               HEADER '('+hb_ntos(len(aIndexInfo))+')' ;
               DATA hb_ntos(tb_delindex:nLogicPos) + if( nIndexOrd == tb_delindex:nLogicPos, " *", "") ;
               SIZE 30 PIXELS ;
               3DLOOK TRUE,TRUE,FALSE ;                  // cels, header, footer
               ALIGN DT_CENTER,DT_CENTER,DT_CENTER ;     // cells, header, footer
               COLORS CLR_BLACK, CLR_HGRAY

            ADD COLUMN TO TBROWSE tb_delindex ;
               DATA ARRAY ELEMENT 1 ;
               TITLE "Order filename" SIZE 130 ;
               ALIGN DT_LEFT, DT_LEFT, DT_LEFT

            ADD COLUMN TO TBROWSE tb_delindex ;
               DATA ARRAY ELEMENT 2 ;
               TITLE "Tag / Key / For" SIZE 1250 ;
               ALIGN DT_LEFT, DT_LEFT, DT_LEFT
            /* only needed if KEY and FOR are not in he same cell
            ADD COLUMN TO TBROWSE tb_delindex ;
               DATA ARRAY ELEMENT 3 ;
               TITLE "For" SIZE 375 ;
               ALIGN DT_LEFT
            */

            // Row Colors, fontcolor en/disabled, bg odd or even
            :SetColor( { 1, 2 }, { th_fctb_leven, {|nRow, nCol, oBrw| iif( nRow%2==0, th_bgtb_leven, th_bgtb_lodd )}} )

            // header is a little bit heigher than the data rows
            :nHeightHead += 6
            :nHeightCell += 3
            // Header in BOLD
            MODIFY TBROWSE tb_delindex HEADER FONT TO FontBold

            // Row Colors, fontcolor en/disabled, bg odd or even
            :SetColor( { 1, 2 }, { th_fctb_leven, {|nRow, nCol, oBrw| iif( nRow%2==0, th_bgtb_leven, th_bgtb_lodd )}} )

            // cell margins, add one space left and right
            :nCellMarginLR := 1

            // mouse wheel skip, 1 line
            :nWheelLines := 1

         end tbrowse

         // *****
         // Next code is needed to show a vertial scroll bar with double/triple line cells
         // and correct mousewheel refresh of last line in browse.
         // Advised by Grigory Filatov, see forum :
         //      https://groups.google.com/forum/#!topic/minigui-forum/Nn-y7Pe2QXE
         //
         tb_delindex:SetNoHoles()
         tb_delindex:SetFocus()
         tb_delindex:ResetVScroll( .T. )
         // *****

         // Define left menu buttons
         //              "Value Label"      "menu_keyword" (used by dispatcher)
         aButtons := {}
         aadd( aButtons, { "New"          , "im_new"   } )
         aadd( aButtons, { "Modify"       , "im_mod"   } )
         aadd( aButtons, { "Delete"       , "im_del"   } )
         aadd( aButtons, { "-"            , ""   } )
         aadd( aButtons, { "Reindex"      , "im_reind" } )
         aadd( aButtons, { "-"            , ""         } )
         aadd( aButtons, { "Index info"   , "im_info"  } )

         // draw menu buttons
         draw_menu( th_w_ctrlgap, th_w_ctrlgap, aButtons, cWinname )

         // Quit button (allways on the bottom )
         DEFINE LABEL bt_Quit
            ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
            COL th_w_ctrlgap
            WIDTH th_bt_width
            HEIGHT th_bt_height
            FONTBOLD .T.
            Value "Quit"
            VCENTERALIGN .T.
            CENTERALIGN .T.
            VISIBLE .T.
            ACTION ThisWindow.Release
            FONTCOLOR th_bt_ohfontcol
            BACKCOLOR th_bt_ohbgcol
         END label

         // Escape Key
         ON KEY ESCAPE ACTION This.bt_Quit.OnClick

      end window

      // activate window
      ACTIVATE WINDOW &f_indmng

   // message there are no index files open for this table
   else
      MsgInfo("There are no index files open for the selected table.")

   endif

return nil


// Change some control rows,cols on resize of form.
static function index_mng_resize(cWinname)

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_delindex", cWinname )

   // height and width browse table
   setproperty(ThisWindow.name, "tb_delindex", "Width", getproperty(ThisWindow.name,"ClientWidth") - th_bt_width * 1 - th_w_ctrlgap * 3 )
   setproperty(ThisWindow.name, "tb_delindex", "Height", getproperty(ThisWindow.name,"ClientHeight") -  th_w_ctrlgap * 2 )

   // repos menu button
   setproperty(ThisWindow.name, "bt_Quit","Row", getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap * 1 )

   // refresh tbrowse is necessary, if not refreshed display of cols could be disturbed.
   o_Browse:refresh()

return nil


// delete index from table and dataset table
static function index_mng_del( cWinname, cWinnamecaller )

   local temp, i, fn_index
   Local cOrderbagname, cOrderTag

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias
   // get from index manager tbrowse table object
   local o_browse_indexlist := GetBrowseObj( "tb_delindex", cWinnamecaller )

   // debug
   //msgstop('Entry index DELETE : ' + cWinname)
   //msgstop('Entry index DELETE caller : ' + cWinnamecaller)

   // get orderbagname and tag name
   temp := o_browse_indexlist:nAt
   cOrderbagname := o_browse_indexlist:aArray[temp, 1]
   cOrderTag     := o_browse_indexlist:aArray[temp, 2]
   cOrdertag := alltrim(memoline(cOrderTag, 240, 1))
   cOrdertag := alltrim(substr(cOrderTag, at(":", cOrderTag)+1))

   // if ordername not empty
   if !empty(cOrderbagname)

      // ask Delete confirmation
      PlayExclamation()
      if MsgOkCancel("Delete order ?" + crlf + crlf + ;
                     "  Tag          " + chr(9) + ': ' + cOrdertag + crlf + ;
                     "  From orderbag" + chr(9) + ': ' + cOrderbagname )

         // get index file name
         fn_index := alltrim( tb_delindex:aArray[tb_delindex:nAt, 1 ] )

         // get selected index order number to close
         i := o_browse_indexlist:nAt

         // set flag close index allowed
         temp := .T.

         // If the actif index == the one that you want to delete
         //  and if it is not the last one
         if (cAlias)->(IndexOrd()) == i .and. i > 1

            // ask confirmation
            PlayExclamation()
            temp := MsgOkCancel("WARNING"+crlf+crlf + ;
                                "You have chosen to DELETE the active order TAG." + crlf + ;
                                "If you confirm the order focus will be set to the first order." + crlf + crlf +;
                                "The file will be deleted from disk if this is the last order left." + crlf + crlf + ;
                                "Please confirm.")
         endif

         // if close allowed
         if temp

            // delete order from a multi order bag
            //  if it is the last order than the file is deleted from disk
            (cAlias)->( ORDDESTROY( cOrdertag , Sx_IndexName(i) ) )

            // update index combobox in DV and dataset array
            index_ds_update(cWinname, cAlias, -1 )

         endif

      endif

   // no orders to delete
   else
      MsgInfo("There are no orderbag files open for this table.")

   endif

return nil


// index manager : new / modif index
static function index_mng_newmod(cWinname, cMode, cWinnamecaller)

   local r, c, c1, aIndexInfo, nSelected_IndexNbr := 0

   // index vars
   local cTag      := ""
   local cKey      := ""
   local cFor      := ""
   local lUnique   := .F.
   local nAscDesc  := 1
   local cFilename := sx_indexname( tb_delindex:nAt )

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias
   // get from index manager tbrowse table object
   local o_browse_indexlist := GetBrowseObj( "tb_delindex", cWinnamecaller )

   // construct at each entry a unique form id name so that multiple forms can be opened.
   LOCAL f_indnew := 'f_indnew_' + cWinname       // cWinname is already a unique form ID

   // prefill if modif of a existing index
   if cMode == "mod"
      // fill temp array with all orderindex info
      aIndexInfo := collect_index_info(cAlias)[3]
      nSelected_IndexNbr := o_browse_indexlist:nAt
      //msgdebug(i)
      // and fill
      cTag      := aIndexInfo[nSelected_IndexNbr, OI_TAG]
      cKey      := aIndexInfo[nSelected_IndexNbr, OI_KEY]
      cFor      := aIndexInfo[nSelected_IndexNbr, OI_FOR]
      lUnique   := aIndexInfo[nSelected_IndexNbr, OI_UNIQUE]
      nAscDesc  := if( !aIndexInfo[nSelected_IndexNbr, OI_ASCDESC], 1, 2 )
      cFilename := aIndexInfo[nSelected_IndexNbr, OI_BAGNAME]
                  *sx_indexname( tb_delindex:nAt )

   // Propose the same order filename as the table
   //   if cFIlename is still empty because there are no order defined at all.
   //   It will be opened automatically later on with the AutoOpen feature.
   else
      if empty(cFilename)
         cFilename := hb_FNameExtSet(DBINFO(DBI_FULLPATH), ORDBAGEXT() )
      endif
   endif

   // Set focus back to this form if it is already open
   if ISWINDOWDEFINED("'"+f_indnew+"'")
      domethod( f_indnew, "SETFOCUS")
      return nil
   endif

   // define form
   DEFINE WINDOW &f_indnew ;
      row getproperty(cWinname,"Row")+150 ;
      col getproperty(cWinname,"Col")+300 ;
      clientarea 750, 280 ;
      TITLE 'OTIS - '+ if(cMode=="new",'Create new','Modify') + ' index for alias : ' + cAlias ;
      BACKCOLOR th_w_bgcolor ;
      WINDOWTYPE MODAL ;
      NOSIZE
      ;//NOMAXIMIZE ;
      ;//NOMINIMIZE


      // background controls
      DEFINE LABEL bg_sere
         ROW    th_w_ctrlgap
         COL    th_bt_width + th_w_ctrlgap * 2
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 3
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2
         VISIBLE .T.
      END LABEL
      // frame around, looks nicer
      define FRAME fr_seek
         ROW    th_w_ctrlgap
         COL    th_bt_width + th_w_ctrlgap * 2 + 1
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 3 - 1
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2
      end frame

      // row, col start position for controls
      r := th_w_ctrlgap * 2
      c := th_w_ctrlgap * 3 + th_bt_width
      c1 := c + 75

      // Table
      DEFINE LABEL Label_1
         ROW    r
         COL    c
         WIDTH  60
         HEIGHT 21
         VALUE "Table (alias)"
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL
      // Alias
      DEFINE LABEL Label_11
         ROW    r
         COL    c1
         WIDTH  240
         HEIGHT 21
         VALUE cAlias
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL

      // filename
      r += 32
      DEFINE LABEL lblfilenm
          ROW       r
          COL       c
          VALUE     "Filename"
          AUTOSIZE .T.
      END LABEL
      *
      define TEXTBOX tb_filename
         row r
         col c1
         height 23
         //width 250
         width getproperty(ThisWindow.name,"ClientWidth") - c1 - th_w_ctrlgap * 2
         VALUE cFilename
         READONLY if(cMode == "new", .F., .T.)     // readonly if modify
      end textbox

      // Tag ordername
      r += 32
      DEFINE LABEL lbltag
          ROW       r
          COL       c
          VALUE     "Tag"
          AUTOSIZE .T.
      END LABEL
      *
      define TEXTBOX tb_tag
         row r
         col c1
         height 23
         width 100
         VALUE cTag
         MAXLENGTH 10
         READONLY if(cMode == "new", .F., .T.)     // readonly if modify
      end textbox

      // check box UNIQUE
      DEFINE Checkbox cb_unique
         ROW r
         COL c1 + getproperty(ThisWindow.name,"tb_tag","Width") + th_w_ctrlgap * 2
         WIDTH 70
         HEIGHT 24
         //FONTBOLD .T.
         //FONTCOLOR th_bt_ohfontcol
         //BACKCOLOR th_bt_ohbgcol
         Caption ' Unique'
         LEFTJUSTIFY .T.
         VALUE lUnique
      END Checkbox

      // radio button Ascending / Descending
      DEFINE RADIOGROUP Rd_AscDes
         ROW   r - 2
         COL   getproperty(ThisWindow.name,"cb_unique","Col" ) + getproperty(ThisWindow.name,"cb_unique","Width" ) + th_w_ctrlgap * 6
         WIDTH th_bt_width // 100
         HORIZONTAL .T.
         OPTIONS { "Ascending", "Descending" }
         VALUE nAscDesc
         TABSTOP .T.
      END RADIOGROUP

      // Key
      r += 32
      DEFINE LABEL lblKey
          ROW       r
          COL       c
          VALUE     "Key"
          AUTOSIZE .T.
      END LABEL
      *
      DEFINE EDITBOX edtKey
          ROW       r
          COL       c1
          WIDTH     getproperty(ThisWindow.name,"ClientWidth") - c1 - th_w_ctrlgap * 2
          HEIGHT    65
          VALUE     cKey
          NOHSCROLLBAR .T.
      END EDITBOX

      // For
      r += 32 + 47
      DEFINE LABEL lblFor
          ROW       r
          COL       c
          VALUE     "For"
          AUTOSIZE .T.
      END LABEL
      *
      DEFINE EDITBOX edtFor
          ROW       r
          COL       c1
          WIDTH     getproperty(ThisWindow.name,"ClientWidth") - c1 - th_w_ctrlgap * 2
          HEIGHT    65
          VALUE     cFor
          NOHSCROLLBAR .T.
      END EDITBOX

      // button : Create new / Apply modif
      DEFINE label lb_create
         ROW th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value if(cMode == "new", " Create", " Apply")
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || cFilename := AllTrim( getproperty(ThisWindow.name,"tb_filename","Value")),;
                     cTag      := AllTrim( getproperty(ThisWindow.name,"tb_tag","Value") ), ;
                     lUnique   := getproperty(ThisWindow.name,"cb_unique","Value"), ;
                     nAscDesc  := getproperty(ThisWindow.name,"Rd_AscDes","Value"), ;
                     cKey      := AllTrim( getproperty(ThisWindow.name,"edtKey","Value" ) ),;
                     cFor      := AllTrim( getproperty(ThisWindow.name,"edtFor","Value" ) ),;
                     ;
                     index_mng_newmod2( cWinname, cMode, aIndexInfo, nSelected_IndexNbr, cFilename, cTag, cKey, cFor, lUnique, nAscDesc) ;
                }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
      END label

      // Quit button (allways on the bottom )
      DEFINE LABEL bt_Quit
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Quit"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || ThisWindow.Release, domethod(cWinnamecaller, "setfocus") }
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      END label

      // escape key action
      ON KEY ESCAPE ACTION { || ThisWindow.Release, domethod(cWinnamecaller, "setfocus") }

   end window

   ACTIVATE WINDOW &f_indnew

return nil


// create / add a new order
static function index_mng_newmod2( cWinname, cMode, aIndexInfo, nSelected_IndexNbr, cFilename, cTag, cKey, cFor, lUnique, nAscDesc )

   local i, lOk := .T., nSeconds := seconds()

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   local cAlias   := o_browse:cAlias

   // save current area
   Local nOldsel := select()
   Local nOldOrdNbr

   // Asc/Desc
   local lAscDes := if( nAscDesc == 1, .F., .T. )

   // ADDITIVE
   local lAdditive := .T.

   // select area used in dv
   select(cAlias)
   // and current active order
   nOldOrdNbr := INDEXORD()

   // debug
   //msgstop(cFilename + crlf + cTag + crlf + cKey +crlf + cFor )
   //msgdebug(collect_index_info(cAlias)[3])

   // Filename
   if empty(cFilename)
      msgstop("No filename is specified.")
      lOk := .F.
   endif

   // TAG label, verify for invalid chars.
   if !empty(cTag) .and. lOK
      if len(charonly("_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", upper(cTag))) <> len(upper(cTag))
         MsgStop( "Only the following characters, 0..9_A..Z, are allowed in the TAG name.")
         lOk := .F.
      endif
   endif

   // KEY expression cleanup, it could be that the user the 'enter' key after entering the KEY expr.
   //  delete crlf pairs and white space
   cKey := alltrim(strtran(cKey, crlf, ""))
   // KEY expression can not be empty
   if empty(cKey) .and. lOK
      msgstop("No KEY expression specified.")
      lOk := .F.
   endif
   // verify KEY expression by evaluation
   if !empty(cKey) .and. lOK
      Try
         lOk := ( ValType( &cKey ) $"CDNL" )       // result must be char, date, number or logical
      catch oError
         lOk := .F.
         MsgStop("KEY expression error :" + crlf + crlf + ;
                  ErrorMessage(oError) )
      END
   endif

   // FOR expression cleanup, it could be that the user used 'enter' after entering the FOR expr.
   //  delete crlf pairs and white space
   cFor := alltrim(strtran(cFor, crlf, ""))
   // verify FOR expression by evaluation
   if !empty(cFor) .and. lOK
      Try
         lOk := ( ValType( &cFor ) == "L" )
      catch oError
         lOk := .F.
         MsgStop("FOR expression error :" + crlf + crlf + ;
                  ErrorMessage(oError) )
      END
   endif

   // ok, green light
   if lOk

      // no tag message
      if empty(cTag)
         PlayExclamation()
         lOk := msgokCancel("WARNING"+crlf+crlf +;
                            "No TAG name is specified. A 'single order' bag"+crlf + ;
                            "will be created and all other TAGS contained in"+crlf+ ;
                            "this orderbag file will be LOST."+crlf+crlf + ;
                            "Please confirm to continue.", "Otis - Create a new order")
      endif

      //
      if lOk

         // debug
         //msgstop(Alias())
         //msgdebug("before create / modif index")

         // create index
         try
            // wait message
            WAIT WINDOW ("Update orders is in progress for alias : " + cAlias) NOWAIT
            CursorWait()
            do events

            /* Some Info
            // analysis create order command syntax to ppo
            //
            #command INDEX ON <key> [TAG <(tag)>] TO <(bag)> ;
               [FOR <for>] [WHILE <while>] [NEXT <next>] ;
               [RECORD <rec>] [<rest:REST>] [<all:ALL>] ;
               [EVAL <eval>] [EVERY <every>] [<unique: UNIQUE>] ;
               [<ascend: ASCENDING>] [<descend: DESCENDING>] ;
               [<add: ADDITIVE>] [<cur: USECURRENT>] [<cust: CUSTOM>] ;
               [<noopt: NOOPTIMIZE>] [<mem: MEMORY, TEMPORARY>] ;
               [<filter: USEFILTER>] [<ex: EXCLUSIVE>] => ;
               ordCondSet( <"for">, <{for}>, [<.all.>], <{while}>, ;
                     <{eval}>, <every>, RecNo(), <next>, <rec>, ;
                     [<.rest.>], [<.descend.>],, ;
                     [<.add.>], [<.cur.>], [<.cust.>], [<.noopt.>], ;
                     <"while">, [<.mem.>], [<.filter.>], [<.ex.>] ) ;;
               ordCreate( <(bag)>, <(tag)>, <"key">, <{key}>, [<.unique.>] )

               // some examples of ppo code ordcondset() and ordcreate()
               //
               INDEX ON REFER TO (cfilename) ASCENDING ADDITIVE
                  ordCondSet(,,,,,, RecNo(),,,,,, .T.,,,,,,, )
                  ordCreate( (cfilename),, "REFER", {|| REFER}, )

               INDEX ON REFER TO (cfilename) ASCENDING FOR REFER == "A" ADDITIVE
                  ordCondSet( 'REFER == "A"', {|| REFER == "A"},,,,, RecNo(),,,,,, .T.,,,,,,, )
                  ordCreate( (cfilename),, "REFER", {|| REFER}, )

               INDEX ON REFER TAG TEST1 TO (cfilename) ASCENDING UNIQUE FOR REFER == "A" ADDITIVE
                  ordCondSet( 'REFER == "A"', {|| REFER == "A"},,,,, RecNo(),,,,,, .T.,,,,,,, )
                  ordCreate( (cfilename), "TEST1", "REFER", {|| REFER}, .T. )

               INDEX ON REFER TO (cfilename) DESCENDING FOR REFER == "A" ADDITIVE
                  ordCondSet( 'REFER == "A"', {|| REFER == "A"},,,,, RecNo(),,,, .T.,, .T.,,,,,,, )
                  ordCreate( (cfilename),, "REFER", {|| REFER}, )

               INDEX ON REFER TAG TEST1 TO (cfilename) DESCENDING UNIQUE FOR REFER == "A" ADDITIVE
                  ordCondSet( 'REFER == "A"', {|| REFER == "A"},,,,, RecNo(),,,, .T.,, .T.,,,,,,, )
                  ordCreate( (cfilename), "TEST1", "REFER", {|| REFER}, .T. )

            */

            // create a new index
            if cMode == "new"

               // Thus .....
               ordCondSet( cFor, "{||"+cFor+"}",,,,, RecNo(),,,, lAscDes,, lAdditive,,,,,,, )
               ordCreate( (cFilename), ctag, ckey, "{||"+ cKey+"}", lUnique)


            // If a order is modified .....
            //   You can not simply recreate a modified tag as we did for a new tag
            //   In Harbour using ordcreate() will destroy the existing TAG and append
            //   the modified order as a new last order tag. It should not.
            //
            //   If someone use order numbers and not tag names it can create HUGE PROBLEMS
            //   because order tag names and order numbers are out of synch.
            //   So we have to rebuild all tags with result that previous tags and corresponding
            //   order number are respected.
            else
               //msgdebug(nSelected_IndexNbr)
               //cWinname, cMode, aIndexInfo, nSelected_IndexNbr, cFilename, cTag, cKey, cFor, lUnique, nAscDesc

               // store first new info of the modified entry in the array
               aIndexInfo[nSelected_IndexNbr, OI_TAG]     := cTag
               aIndexInfo[nSelected_IndexNbr, OI_KEY]     := cKey
               aIndexInfo[nSelected_IndexNbr, OI_FOR]     := cFor
               aIndexInfo[nSelected_IndexNbr, OI_UNIQUE]  := lUnique
               aIndexInfo[nSelected_IndexNbr, OI_ASCDESC] := if( nAscDesc == 1, .F., .T.)
               aIndexInfo[nSelected_IndexNbr, OI_BAGNAME] := cFilename
               //msgdebug(aIndexInfo)

               // and rebuild all index 'one after the other' to keep the tag name and order number synchronised as before.
               for i := 1 to len(aIndexInfo)
                  ordCondSet( aIndexInfo[i, OI_FOR], "{||"+aIndexInfo[i, OI_FOR]+"}",,,,, RecNo(),,,, aIndexInfo[i, OI_ASCDESC],, lAdditive,,,,,,, )
                  ordCreate( (aIndexInfo[i, OI_BAGNAME]), aIndexInfo[i, OI_TAG], aIndexInfo[i, OI_KEY], "{||"+ aIndexInfo[i, OI_KEY]+"}", aIndexInfo[i, OI_UNIQUE])
               next i

            endif

            // flush to disk
            COMMIT

            // clear wait message
            CursorArrow()
            WAIT CLEAR
            do events

            // message finished
            msginfo("Index update has finished in " + hb_ntos(seconds() - nSeconds), 'Otis')

            // restore order if "modify"
            if cMode == "mod"
               ORDSETFOCUS(nOldOrdNbr)
            endif

            // rebuild index info table and combobox in Dataset viewer and dataset array
            // and set order to the last created order
            index_ds_update(cWinname, cAlias, 1 )

            // reset flag Dataset has changed if in cmdline mode
            // so that the hidden main window is closed also.
            if !empty(cCmdline)
               Otis_Ds_changed(.F., .F.)
            endif

         catch oError
            MsgStop( "Order create failed probably caused by" + crlf + ;
                     "using a invalid KEY or FOR expression." + crlf + crlf + ;
                     ErrorMessage(oError) ;
                   )
            lOk := .F.
         end

      endif

   endif

   // restore prev area
   select (nOldsel)

return nil


// index manager, reindex all files
static function index_mng_reind(cWinname)

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   local cAlias   := o_browse:cAlias

   db_reindexall(cWinname, cAlias, .T.)

return nil


// update DV index combobox and Otis dataset array
static function index_ds_update(cWinname, cAlias, nValue )

   local i

   // del all entries in index combobox in DV
   domethod(cWinname, "cb_sel_index", "DELETEALLITEMS")

   // refill this array
   domethod(cWinname, "cb_sel_index", "ADDITEM", '0 - No order')
   for i := 1 to (cAlias)->(DBORDERINFO(DBOI_ORDERCOUNT))
      domethod(cWinname, "cb_sel_index", "ADDITEM", strzero(i,2) + ' - ' + ORDNAME( i, ORDBAGNAME(i)) + repl(chr(9),2) + " - " + Indexkey(i) + ' for ' + ORDFOR(ORDNAME(i)))
   next i
   // display selected index in combobox in DV
   setproperty(cWinname, "cb_sel_index", "VALUE", (cAlias)->(INDEXORD()) + 1 )

   // update Dataset
   // set flag Dataset has changed
   Otis_Ds_changed(.T.)
   //   add / substract 1 to index count
   tb_Otis:aArray[tb_Otis:nAt, ATI_INDCNT ] := str( val(tb_Otis:aArray[tb_Otis:nAt, ATI_INDCNT ]) + nValue, 3)
   //   set new order focus if changed
   tb_Otis:aArray[tb_Otis:nAt, ATI_CURIND ] := str( (cAlias)->(IndexOrd()), 3)
   //   refresh display
   tb_Otis:refresh()

   // update dv label ORDER (xx)
   setproperty(cWinname, "lb_sel_index", "value", ' Orders   (' + hb_ntos(DBORDERINFO(DBOI_ORDERCOUNT)) + ')' )

   // release "new index" form
   ThisWindow.release

   // release index del form
   domethod( 'f_indmng_' + cWinname, "release")
   // and reopen it so that it is refreshed with current new index info
   domethod( cWinname, "SETFOCUS")              // display again the DV screen
   do events                                    // is necessary
   domethod( cWinname, "bt_dv_im", "ONCLICK")   // and simulate button press to reopen the index manager
   do events

return nil


// reindex all orders
static function db_reindexall(cWinname, cAlias, lWarningnoindex)

   local lOk := .T.

   // get current focused window
   local cHasFocus :=  FocusedWindow.Name
   local nSecStart

   // default no warning if there are no index files open
   Default lWarningnoindex := .F.

   // only if there index files opened
   if  (cAlias)->(DBORDERINFO(DBOI_BAGCOUNT)) <> 0

      // only if file is opened in exclusive mode
      if (cAlias)->(DBINFO(DBI_SHARED))
         // error message
         msginfo("Reindex is impossible."+crlf+;
                 "The table is not opened in EXCLUSIVE mode.")
         // try to reopen exclusive
         lOk := dv_reopen_excl(cWinname)
      endif

      // reindex if ok
      if lOk

         TRY
            WAIT WINDOW ("Reindex in progress for alias : " + cAlias) NOWAIT
            CursorWait()
            do events

            nSecStart := seconds()

            (cAlias)->(DBREINDEX())
            commit                                  // commit is necessary
                                                    // i have seen that sometimes the 'files size' in win explorer stays 0 until exit of OTIS

            // clear wait window
            CursorArrow()
            WAIT CLEAR
            do events

            // message finished
            msginfo("Re-Index has finished in  ("+ hb_ntos(seconds()-nSecStart) + " sec.)" )

            // refresh and set focus
            domethod(cWinname, "setfocus")
            domethod(cHasFocus, "setfocus")

         // reindex error message
         Catch oError
            MsgStop("Reindex error :" + crlf + crlf + ;
                     ErrorMessage(oError) )

         end

      endif

   // message no index files opened
   else
      if lWarningnoindex
         MsgInfo("There are no orderbag files open for this table.")
      endif
   endif

return nil


// insert n records in a database, use new low level DBINSERT()
//   Att. : DBINSERT() does not update index files.
static function db_insert(cWinname, cAlias, nIns_records)

   local cHasFocus :=  FocusedWindow.Name

   default nIns_records := 1

   try

      // wait message
      WAIT WINDOW ("Insert record(s) in progress for alias : " + cAlias) NOWAIT
      CursorWait()
      do events

      // insert record(s)
      (cAlias)->(dbInsert( ,nIns_records))
      commit

      // clear wait message
      CursorArrow()
      WAIT CLEAR
      do events

      // refresh and set focus
      domethod(cWinname, "setfocus")
      domethod(cHasFocus, "setfocus")

   // insert error message
   Catch oError
      MsgStop("Insert record(s) error :" + crlf + crlf + ;
               ErrorMessage(oError) )

   end

return nil


//***********************************************************************************************************************************
  * Procedure ------------------------


// Left Menu button dispatcher
function mn_dispatch( cButton_id, cWinname )

   // dispatch
   switch cButton_id

      // dispatch menu for main otis()
      //------------------------------
      case 'ot_br'
         otis_dv()
         exit

      case 'ot_pr'
         table_prop("form_otis")
         exit

      case 'ot_at'
         otis_add_table(tb_Otis)
         exit

      case 'ot_ai'
         otis_add_index(tb_Otis)
         exit

      case 'ot_dt'
         otis_rem_table(tb_Otis)
         exit

      case 'ot_di'
         //otis_rem_index("tb_Otis")
         otis_rem_index()
         exit

      case 'ot_sds'
         ds_manager("Save")
         exit

      case 'ot_lds'
         ds_manager("Load")
         exit

      case 'ot_cds'
         ds_manager_clear()
         exit

      case 'ot_se'
         Struct_editor()
         exit

      case 'ot_set'
         Otis_Settings()
         exit

      // dispatch menu for dv_viewer()
      //------------------------------
      case "dv_sk"
         dv_seek(cWinname)
         exit

      case "dv_sr"
         dv_Search_Replace(.F., cWinname)
         exit

      case "dv_srext"
         dv_repl_ext(cWinname)
         exit

      case "dv_go"
         dv_goto(cWinname)
         exit

      case "dv_st"
         table_prop(cWinname)
         exit

      case "dv_ai"
         dv_ai_rec(cWinname)
         exit

      case "dv_cp"
         dv_cp_rec(cWinname, "C")
         exit

      case "dv_pa"
         dv_cp_rec(cWinname, "P")
         exit

      case "dv_cl"
         dv_clrec(cWinname)
         exit

      case "dv_du"
         dv_du_rec(cWinname)
         exit

      case "dv_dr"
         dv_dr_rec(cWinname)
         exit

      case "dv_pack"
         dv_pack_zap(cWinname, "PACK")
         exit

      case "dv_zap"
         dv_pack_zap(cWinname, "ZAP")
         exit

      case "dv_af"
         dv_append_file(cWinname)
         exit

      case "dv_im"
         index_mng(cWinname)
         exit

      case 'ot_dvse'
         Struct_editor(cWinname, "DV")
         exit

      case "dv_up"
         dv_pupd_rec(cWinname, 'U')
         exit

      case "dv_down"
         dv_pupd_rec(cWinname, 'D')
         exit

      case "dv_save"
         dv_save(cWinname)
         exit

      case "dv_export"
         dv_export(cWinname)
         exit

      // dispatch menu for index_mng()
      //------------------------------
      case "im_del"
         index_mng_del(cWinname, ThisWindow.name)
         exit

      case "im_new"
         index_mng_newmod(cWinname, "new", ThisWindow.name)
         exit

      case "im_mod"
         index_mng_newmod(cWinname, "mod", ThisWindow.name)
         exit

      case "im_reind"
         index_mng_reind(cWinname)
         exit
      case "im_info"
         show_index_info(GetBrowseObj( "tb_Dv_Browse", cWinname ):cAlias)
         exit


      // dispatch menu for Struct_editor()
      //------------------------------
      case "se_af"
         se_aim_field( se_append, ThisWindow.Name )
         exit

      case "se_if"
         se_aim_field( se_insert, ThisWindow.Name )
         exit

      case "se_mf"
         se_aim_field( se_modify, ThisWindow.Name )
         exit

      case "se_df"
         se_del_field(ThisWindow.Name)
         exit

      case "se_up"
         se_field_ud("U")
         exit

      case "se_dn"
         se_field_ud("D")
         exit

      case "se_is"
         se_load_struct(ThisWindow.Name)
         exit

      case "se_cl"
         se_clear_struct()
         exit

      case "se_fthelp"
         se_helpfldtype()
         exit

      case "se_tblhelp"
         se_helptbl()
         exit

      // unknown keyword or not yet implemented.
      //----------------------------------------
      otherwise
         msgstop("Menu : " + cButton_id + " is not yet implemented.")

   end

return nil


//***********************************************************************************************************************************
   * Procedure ------------------------

//
// Dataset manager : save (as), load, delete, ...
//
// Args  : keyword   "Save"
//                   "Load"
//
static function ds_manager(keyword)

   LOCAL i, nOldsel

   Private aDatasets := {}             // array with all datasets found in the dataset table
   Private o_Dsmng_browse

   // if anything to save
   if keyword == "Save" .and. ( len(aOtables) == 0 .or. empty(aOtables[ 1, ATI_ALIAS ]) )

      Msginfo("There is nothing to save, there are no open tables.")
      return nil

   endif

   // save current area
   nOldsel := select()

   // open dataset table
   //   EXCLUSIVE (pack is used below)
   if Open_dstable()

      // open a form with browse to display all existing datasets already saved

      // get all datasets in dataset table
      *select ds_table
      *goto top
      do while !eof()
         i := ascan( aDatasets, ds_table->DATASET )
         if i == 0
            aadd( aDatasets, ds_table->DATASET )
         endif
         skip 1
      enddo

      // assure min len array aDatasets for tbrowse
      if len(aDatasets) == 0
         aadd(aDatasets, " ")
      endif

      // form
      define window form_dsmng ;
         row getproperty("form_otis","row") + 200 ;
         col getproperty("form_otis","col") + 200 ;
         clientarea 460 + th_w_ctrlgap * 2, 300 + th_bt_height + th_w_ctrlgap * 4 + 22 ;
         TITLE "OTIS - " + keyword + " Dataset" ;
         backcolor th_w_bgcolor ;
         WINDOWTYPE MODAL ;
         ON RELEASE ds_manager_release(nOldsel) ;
         NOSIZE
         /*
         NOMINIMIZE ;
         NOMAXIMIZE ;
         NOSIZE
         */

         // tsbrowse
         define TBROWSE o_Dsmng_browse ;
            at th_w_ctrlgap, th_w_ctrlgap ;
            width  460 ;
            height 300 ;
            COLORS {CLR_BLACK, CLR_WHITE} ;
            size 10 ;
            grid ;
            SELECTOR .T.

            // set array
            o_Dsmng_browse:SetArray( aDatasets )

            ADD COLUMN TO TBROWSE o_Dsmng_browse ;
               DATA ARRAY ELEMENT 1 ;
               TITLE "Dataset name" SIZE 434 ;
               ALIGN DT_LEFT

            // mouse wheel skip, 1 line
            o_Dsmng_browse:nWheelLines := 1

            // header is a little bit heigher than the data rows
            o_Dsmng_browse:nHeightHead += 6
            o_Dsmng_browse:nHeightCell += 3
            // Header in BOLD
            MODIFY TBROWSE o_Dsmng_browse HEADER FONT TO FontBold

            // left mouse single click, copy ds name to getbox
            o_Dsmng_browse:bLClicked := { || setproperty("form_dsmng", "gb_ds_name", "Value", o_Dsmng_browse:aArray[o_Dsmng_browse:nAt, 1 ] ) }

            // left mouse double click, copy ds name to getbox, save and release this form
            // TODO

            // codeblock row delete, settings : allow delete, no confirm by tbrowse it self
            //o_Dsmng_browse:SetDeleteMode( .T., .F., { || ds_manager_del( getproperty(ThisWindow.name, "gb_ds_name","value") ) } )

            // cell margins, add one space left and right
            :nCellMarginLR := 1

            // Row Colors, fontcolor en/disabled, bg odd or even
            :SetColor( { 1, 2 }, { th_fctb_leven, {|nRow, nCol, oBrw| iif( nRow%2==0, th_bgtb_leven, th_bgtb_lodd )}} )

         end tbrowse

         // Dataset name label and getbox
         DEFINE LABEL lb_dataset
            ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap * 2 - 22
            COL th_w_ctrlgap
            WIDTH th_bt_width
            HEIGHT 22
            FONTBOLD .T.
            FONTCOLOR th_bt_ohfontcol
            BACKCOLOR th_bt_ohbgcol
            Value " Dataset name"
            VCENTERALIGN .T.
         END label
         *
         define GETBOX gb_ds_name
            ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap * 2 - 22
            col th_bt_width + th_w_ctrlgap * 2
            height 23
            width 353
            FONTSIZE 10
            VALUE space(50)
            ONCHANGE { || setproperty(ThisWindow.name, "gb_ds_name","value", padr( alltrim( getproperty(ThisWindow.name, "gb_ds_name","value") ), 50) ) }
         end getbox

         // "Cancel" button
         DEFINE LABEL bt_Cancel
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL getproperty(ThisWindow.name,"ClientWidth") - ( th_bt_width + th_w_ctrlgap ) * 1
            WIDTH th_bt_width
            HEIGHT th_bt_height
            FONTBOLD .T.
            FONTCOLOR th_bt_fontcol
            BACKCOLOR th_bt_bgcol
            Value "Cancel"
            VCENTERALIGN .T.
            CENTERALIGN .T.
            ACTION form_dsmng.release
            // font and background color when onhover / onleave
            ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
            ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
         END label

         // "Save / Load" button
         DEFINE LABEL bt_Save_Load
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL getproperty(ThisWindow.name,"ClientWidth") - ( th_bt_width + th_w_ctrlgap ) * 2
            WIDTH th_bt_width
            HEIGHT th_bt_height
            FONTBOLD .T.
            FONTCOLOR th_bt_fontcol
            BACKCOLOR th_bt_bgcol
            Value keyword
            VCENTERALIGN .T.
            CENTERALIGN .T.
            if keyword == "Save"
               // save
               ACTION ds_manager_save( getproperty(ThisWindow.name, "gb_ds_name","value") )
            else
               // load
               ACTION { || ds_manager_load( getproperty(ThisWindow.name, "gb_ds_name","value") ), form_dsmng.Release }
            endif
            // font and background color when onhover / onleave
            ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
            ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
         END label

         // "Delete" button
         DEFINE LABEL bt_Delete
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL th_w_ctrlgap
            WIDTH th_bt_width
            HEIGHT th_bt_height
            FONTBOLD .T.
            FONTCOLOR th_bt_fontcol
            BACKCOLOR th_bt_bgcol
            Value "Delete"
            VCENTERALIGN .T.
            CENTERALIGN .T.
            ACTION ds_manager_del( getproperty(ThisWindow.name, "gb_ds_name","value") )
            // font and background color when onhover / onleave
            ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
            ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
         END label

         // Escape Key
         ON KEY ESCAPE ACTION ThisWindow.Release

      end window

      // init getbox for dsname with passed dataset name
      setproperty( "form_dsmng", "gb_ds_name", "Value", getproperty("form_otis", "cb_dataset", "Item", getproperty("form_otis", "cb_dataset", "Value" )))

      // activate window
      domethod( "form_dsmng", "ACTIVATE")

   ENDIF

return nil


// release dataset manager form
static function ds_manager_release(nOldsel)

   // close dataset table
   select ds_table
   use

   // select prev. area
   select (nOldsel)

return nil


// Dataset : Save
static function ds_manager_save( ds_name )

   local temp, i, y, cIndexfn

   // loop
   do while .T.

      // if a name is set
      if !empty( ds_name )

         // verify if dataset with the same name exists already
         // and if this is the case ask to overwrite
         temp := .T.
         if ascan( aDatasets, ds_name ) <> 0

            // get user input
            PlayExclamation()
            temp := MsgYesNo( "Dataset <" + alltrim(ds_name) + "> exists already." + crlf + crlf + ;
                              "Do you want to overwrite ?" )

            // if overwrite confirmed, erase old entries in dbf
            if temp
               ds_manager_del2( ds_name )
            endif

         endif

         // write ok
         if temp

            // save dataset
            for i := 1 to len(aOtables)

               // Save only if area nr < ini_area_pi_reopen_start
               //  thus we don't save, when in PLUGIN mode, the reopened areas.
               if val(aOtables[ i, ATI_AREA ]) < ini_area_pi_reopen_start

                  // append dbf info
                  ds_table->(DBAPPEND())
                  replace ds_table->DATASET   with ds_name,;
                          ds_table->FILENAME  with aOtables[ i, ATI_FN ], ;
                          ds_table->TYPE      with 'DBF', ;
                          ds_table->ALIAS     with aOtables[ i, ATI_ALIAS ], ;
                          ds_table->AREA      with alltrim(aOtables[ i, ATI_AREA ]), ;
                          ds_table->INDEXORD  with str(IndexOrd()), ;
                          ds_table->RDD       with aOtables[ i, ATI_RDD ], ;
                          ds_table->SELECTED  with aOtables[ i, ATI_ISSELECTED ], ;
                          ds_table->RECNO     with aOtables[ i, ATI_RECNO ]

                  // Append index info
                  //   save also the dbf alias name to know later
                  //   on to what dbf it should be attached.
                  select ( val(aOtables[ i, ATI_AREA ]) )
                  for y := 1 to Sx_indexcount()
                     // append record
                     ds_table->(DBAPPEND())
                     // format index filename
                     cIndexFn := Sx_IndexName(y)
                     if aOtables[ i, ATI_RDD ] <> 'LETO'
                        cIndexFn := STRTRAN( Sx_IndexName(y), GetCurrentFolder()+"\", "")
                     else
                        cIndexFn := '\' + Sx_IndexName(y)
                     endif
                     *
                     replace ds_table->DATASET   with ds_name,;
                             ds_table->FILENAME  with cIndexFn, ;
                             ds_table->TYPE      with right(ORDBAGEXT(),3) ,;
                             ds_table->RDD       with aOtables[ i, ATI_RDD ], ;
                             ds_table->ALIAS     with aOtables[ i, ATI_ALIAS ], ;
                             ds_table->AREA      with alltrim(str(y, 3))
                  next y

               endif

            next i

            // reset flag Dataset has changed
            Otis_Ds_changed(.F.)

            // prevent a ONCHANGE event when we change the dataset combobox
            setproperty( "form_otis", "cb_dataset", "Cargo", .F.)

            // update combobox control with ds name
            setproperty( "form_otis", "cb_dataset", "Item", 2, ds_name)
            setproperty( "form_otis", "cb_dataset", "Value", 2)

            // reactivate ONCHANGE event when we click it
            setproperty( "form_otis", "cb_dataset", "Cargo", .T.)

            // release form 'save / load'
            domethod( "form_dsmng", "release")
            exit

         // no overwrite or canceled
         else
            exit

         endif

      // message, no name is entered
      else
         Msgstop("Please select or enter a new 'Dataset name'.")
         exit
      endif

   enddo

return nil


// load a dataset
static function ds_manager_load( ds_name )

   local lOk := .T.
   local temp, i, nArea, cAlias, cTablename, nOrderfocus, nRecno, cRdd

   // if a dataset name is passed.
   if !empty(ds_name)

      // locate ds_name in dataset table
      locate for alltrim(ds_table->DATASET) == alltrim(ds_name)

      // if dataset name found
      if found()

         // open dbf and index files
         do while alltrim(ds_table->DATASET) == alltrim(ds_name)

            // open DBF
            if ds_table->TYPE == "DBF"

               // get alias name
               cAlias := alltrim(ds_table->ALIAS)

               // If in plugin mode add ghost alias suffix.
               if !lStandAlone
                  cAlias := cAlias + "_" + alltrim(ds_table->AREA)
               endif

               // if the ALIAS is not already opened
               if select(cAlias) == 0

                  // get RDD driver name to use
                  cRdd := alltrim(ds_table->RDD)
                  // if it is empty use the current setting from the combobox.
                  //   (can be empty because it was not used in previous versions of Otis)
                  if empty(cRdd)
                     cRdd := getproperty("form_otis", "cb_defrdd","Item", getproperty( "form_otis", "cb_defrdd", "Value") )
                  endif

                  // if RDD to use is LETODBF
                  //msgstop(cTablename + " : " + cRdd)
                  if upper(cRdd) == "LETO"
                     // if server is NOT connected
                     if leto_Connect() < 0
                        // connect server
                        lOk := otis_leto_connect()

                        // if not connected exit and don't open tables
                        if !lOk
                           exit
                        endif
                     endif
                  endif

                  // check if table is still there
                  if hb_vfExists(ds_table->FILENAME) ;            // for local or mapped drives
                     .or. ;
                     Leto_File(ds_table->FILENAME)                // if letodbf server

                     // save last opened table name for index open error reporting
                     cTablename := alltrim(ds_table->FILENAME)

                     // get selected order number when the dataset was saved
                     nOrderfocus := if( VAL(ds_table->INDEXORD) <> 0, VAL(ds_table->INDEXORD), 1)
                     // default recno to go to
                     nRecno := 1

                     // open table (with error trapping)
                     TRY
                        // use area nr is stored in otis_ds.dbf
                        // if there is no saved area nbr see 'else'
                        if ( nArea := val(ds_table->AREA) ) <> 0

                           // if in plugin mode all areas in a DS are opened as a ghost area
                           //   this to prevent conflicts if Otis is already open and
                           //   the running program opens tables after it.
                           if !lStandAlone
                              nArea := nArea + ini_area_pi_reopen_start
                           endif

                           // open table
                           select (nArea)
                           use (ds_table->FILENAME) ALIAS (cAlias) VIA (cRdd) CODEPAGE ini_dbf_codepage

                           // save the highest area number because we can add other tables
                           //   to a already loaded dataset and the added must have a unique area nbr.
                           //msgstop(hb_ntos(nArea) + crlf+ hb_ntos(pi_area_cnt))
                           pi_area_cnt := if( nArea >= pi_area_cnt, nArea + 1, pi_area_cnt )

                        // Open always in a new area if
                        // no area nr was stored in the DS (because of a error or a user manipulation)
                        else
                           use (ds_table->FILENAME) ALIAS (cAlias) NEW VIA (cRdd) CODEPAGE ini_dbf_codepage
                        endif

                        // get record number that was stored in the dataset table
                        // and position table on it
                        nRecno := val(ds_table->RECNO)
                        DBGOTO(nRecno)

                     CATCH oError
                        MsgStop("OTIS can not open table :"+ crlf + crlf + ;
                                 alltrim(ds_table->FILENAME) + crlf + crlf + ;
                                "It is probably still open in another program" + crlf + ;
                                "or" + crlf + ;
                                "the wrong Rdd driver is used.")

                        // skip to the next dbf record,
                        // index files can not be opened if there is no table opened
                        ds_manager_skipindex(ds_table->ALIAS)

                     END

                  // table not found
                  else
                     // error message, file can not be opened, it does not exist
                     Uto_file(ds_table->FILENAME)
                     // skip to the next dbf record
                     ds_manager_skipindex(ds_table->ALIAS)
                  endif

               // alias is already in use
               else
                  MsgInfo("Alias : <" + alltrim(cAlias) + "> is already in use." + crlf + crlf + ;
                          "Table <"+alltrim(ds_table->FILENAME)+"> can not be opened again.")

                  // skip to the last index record,
                  //   they can not be opened because the alias is already in use
                  //   and all attached index files are thus already open.
                  ds_manager_skipindex(ds_table->ALIAS)

               endif

            // Open index
            else

               // select area
               select (cAlias)

               // open only if AutoOpen flag is false or if current rdd is DBFNTX
               //    if no auto open
               //    if rdd == DBFNTX, this type does not support AutoOpen
               //    if index filename <> database name (without .ext )
               if !ini_ordbag_autoopen ;
                  .or. ;
                  RDDSETDEFAULT() == "DBFNTX" ;
                  .or. ;
                  hb_FNameName(ds_table->FILENAME) <> hb_FNameName(DBINFO(DBI_FULLPATH))

                  // if the orderbag file still exists
                  if hb_vfExists(ds_table->FILENAME) ;            // for local or mapped drives
                     .or. ;
                     Leto_File(ds_table->FILENAME)                // if letodbf server

                      // add index (with error trapping)
                     Try
                        // add index
                        ORDLISTADD(ds_table->FILENAME)
                        // restore the default order after each add index
                        ORDSETFOCUS(nOrderfocus)
                        // restore also the record position
                        DBGOTO(nRecno)

                     Catch oError
                        MsgStop("OTIS can not open index :"+ crlf + ;
                                "  " +  alltrim(ds_table->FILENAME) + crlf + ;
                                "for table : " + crlf + ;
                                "  " + alltrim(cTablename)+ crlf + crlf +;
                                "This index does not belong to this table," + crlf + ;
                                "the index is corrupted," + crlf + ;
                                "the wrong rdd driver is used" + crlf + ;
                                "or" + crlf + ;
                                "a unknown function/fieldname/variable is used in the KEY or FOR expression."+crlf+crlf+;
                                ErrorMessage(oError) )
                     end

                  // message, orderbag does not exist anymore
                  else
                     MsgInfo("The following orderbag file does not exist anymore :"+crlf+crlf+;
                             "  " + alltrim(ds_table->FILENAME)  + crlf + crlf +;
                             "Rebuild it or remove it from the dataset.")
                  endif

               endif

            endif

            // next record (table or index)
            select ds_table
            skip 1

         enddo

         // init getbox for dsname with loaded dataset name
         //setproperty( "form_otis", "cb_dataset", "Item", 2, ds_name )

         // prevent a ONCHANGE event when we change the dataset combobox
         setproperty( "form_otis", "cb_dataset", "Cargo", .F.)

         // update combobox "most recent used datasets".
         for i := 2 to 6
            if alltrim(ds_name) == alltrim( getproperty("form_otis", "cb_dataset", "Item", i) )
               exit
            endif
         next i
         * not found
         if i == 7
            * push all down
            for i := 6 to 3 step -1
               setproperty( "form_otis", "cb_dataset", "Item", i, getproperty("form_otis", "cb_dataset", "Item", i-1) )
            next i
            * and set the last loaded in the first entry
            setproperty( "form_otis", "cb_dataset", "Item", 2, ds_name )
            setproperty( "form_otis", "cb_dataset", "Value", 2)

         * already on the first place but we need to refresh the combobox item
         elseif i == 2
            setproperty( "form_otis", "cb_dataset", "Value", 2 )

         * already in list but not on the first place
         elseif i >= 3 .and. i <= 6

            * swap entries
            temp := getproperty("form_otis", "cb_dataset", "Item", 2)
            setproperty( "form_otis", "cb_dataset", "Item", i, temp )
            setproperty( "form_otis", "cb_dataset", "Item", 2, ds_name )
            setproperty( "form_otis", "cb_dataset", "Value", 2 )

         endif

         // Reset flag Dataset has changed NOT changed
         // only if there were no tables opened before.
         // BUT it must be set to changed if
         //   the first DS load is OK but if you add tables manually
         //   or add a second dataset because current (the first DS loaded) has changed.
         Otis_Ds_changed(.F.)

         // reactivate ONCHANGE event when we click it
         setproperty( "form_otis", "cb_dataset", "Cargo", .T.)

         // refill OTIS main tbrowse array with info for all open dbf/index files (details see function)
         aOtables := otis_get_area_info()

         // refresh table
         tb_Otis:SetArray( aOtables )

         // enable some menus
         otis_endi_menus(.T.)

      // message, dataset name not found
      else
         //
         MsgInfo("The selected dataset does not exist anymore."+crlf+;
                 "It will be removed from the 'most recent used' list.")

         // prevent a ONCHANGE event when we change the dataset combobox
         setproperty( "form_otis", "cb_dataset", "Cargo", .F.)

         // find entry and delete it from the 'most recent used" combobox.
         for i := 2 to 6
            if alltrim(ds_name) == alltrim( getproperty("form_otis", "cb_dataset", "Item", i) )
               exit
            endif
         next i
         // if found
         if i < 7
            // pull all other entries up
            for i := i to 5
               setproperty( "form_otis", "cb_dataset", "Item", i, getproperty("form_otis", "cb_dataset", "Item", i+1) )
            next i
            // and empty the last one
            setproperty( "form_otis", "cb_dataset", "Item", 6, "" )
            setproperty( "form_otis", "cb_dataset", "Value", 1 )
         endif

         // reactivate ONCHANGE event when we click it
         setproperty( "form_otis", "cb_dataset", "Cargo", .T.)

      endif

   endif

return nil


// skip to the last INDEX record
//   necessary because there is a skip after this function
static function ds_manager_skipindex(cAlias)

   select ds_table
   *
   do while ds_table->ALIAS == cAlias
      skip 1
      if ds_table->ALIAS <> cAlias .or. eof()
         skip -1
         exit
      endif
   enddo

return nil


// Dataset : delete
static function ds_manager_del( ds_name )

   local lDelete := .T.

   // if a dataset name is entered
   if !empty(ds_name)

      // ask user confirmation if ness.
      PlayExclamation()
      lDelete := MsgOkCancel( "Confirm delete of dataset <" + alltrim(ds_name) + ">." )

      // delete a dataset
      if lDelete

         // delete records in dataset database
         ds_manager_del2( ds_name )

         // delete entry in browse table
         //  temp disable "keyboard del key" function in browse table
         o_Dsmng_browse:SetDeleteMode( .T., .F.)
         //  delete row
         o_Dsmng_browse:DeleteRow()
         o_Dsmng_browse:refresh()
         //  enable "keyboard del key" function in browse table
         //o_Dsmng_browse:SetDeleteMode( .T., .F., { || ds_manager_del( getproperty(ThisWindow.name, "gb_ds_name","value") ) } )
         o_Dsmng_browse:SetDeleteMode( .F., .F.)

         // clear contents of getbox
         setproperty( "form_dsmng", "gb_ds_name", "Value", space(50) )

      endif

   endif

return nil


// Delete all records in dataset table with the passed dsname
static function ds_manager_del2( ds_name )

   // delete records
   select ds_table
   goto top
   delete rest FOR alltrim(ds_table->DATASET) == alltrim(ds_name)

   // and remove them physically
   pack

return nil


// Clear / close current dataset
static function ds_manager_clear()

   local cMsg := ""

   // if any table opened to attach a index file
   if !empty(aOtables[ 1, ATI_ALIAS ])

      // ask confirmation to wipe current opened tables
      if lStandalone
         cMsg := "ATTENTION : " + crlf + crlf + ;
                 "All tables will be CLOSED." + crlf + crlf + ;
                 "Close the current dataset ?"
      else
         cMsg := "ATTENTION : " + crlf + crlf + ;
                 "All GHOST areas and ADDED tables will be CLOSED." + crlf + ;
                 "Tables opened by the running program stay open." + crlf + crlf + ;
                 "Close the current dataset ?"
      endif
      *
      PlayExclamation()
      if MsgYesNo(cMsg)

         // save current dataset before if changed
         ds_save_if_changed()

         // Close all or only reopened in function of run mode
         ds_close_areas()

         // reset area counter in function of program mode
         pi_area_cnt := if( lStandalone, 1, ini_area_pi_reopen_start + ini_area_max_scan )

         // reset flag Dataset has changed
         Otis_Ds_changed(.F.)

         // fill tbrowse array with a empty entry because there is no dbf open
         aOtables := otis_get_area_info()

         // refresh table
         tb_Otis:SetArray( aOtables )

         // clear contents of getbox
         setproperty("form_otis", "cb_dataset", "Item", 1, "")
         setproperty("form_otis", "cb_dataset", "Value", 1)

         // disable some menus
         otis_endi_menus(.F.)

      endif

   endif

return nil


// Ask to save dataset if changed before close, load of another dataset
// or quit the program.
static function ds_save_if_changed()

   // verify if current dataset has been changed
   if lDsChanged

      // ask confirmation to save first all changements.
      PlayExclamation()
      if MsgYesNo("Warning" + crlf + crlf + ;
                  "The current dataset has been modified." + crlf + ;
                  "Do you want to save it.";
                 )

      // save current dataset
      ds_manager("Save")

      //ds_manager_save( getproperty("form_otis", "cb_dataset","Item", getproperty( "form_otis", "cb_dataset", "Value") ) )

      endif

   endif

return nil


// close all tables or only the reopend ones
static function ds_close_areas()

   local i

   // Standalone : close all
   if lStandAlone
      close all

   // plugin mode : close only the reopened ones
   else
      // close area between reopenstart and reopenstart + maxscan * 2
      //    maxscan * 2 because if we add tables manually the area nbr starts at reopenstart+maxscan
      //    and these added tables have to be closed also.
      for i := ini_area_pi_reopen_start to ini_area_pi_reopen_start + ( ini_area_max_scan * 2 )
         if !empty( alias(i) )
            //msgstop("close area : " + hb_ntos(i))
            select (i)
            use
         endif
      next i
   endif

   // reset area counter in function of run mode
   pi_area_cnt := if( lStandalone, 1, ini_area_pi_reopen_start + ini_area_max_scan )

return nil

// create a new empty dataset table
static function ds_create_ds_table()

   local lOk := .T.

   try

      DBCREATE( fn_ds_table, {;
              { 'DATASET     ', 'C',  50,   0 } ,;
              { 'FILENAME    ', 'C', 250,   0 } ,;
              { 'TYPE        ', 'C',   3,   0 } ,;
              { 'ALIAS       ', 'C',  20,   0 } ,;
              { 'AREA        ', 'C',   5,   0 } ,;
              { 'INDEXORD    ', 'C',   3,   0 } ,;
              { 'RDD         ', 'C',   7,   0 } ,;
              { 'SELECTED    ', 'C',   1,   0 } ,;
              { 'RECNO       ', 'C',  10,   0 } ;
              }, 'DBFCDX' )

   catch oError
      lOk := .F.
      MsgStop("Otis could not create a new dataset table : " + crlf +;
              "   " + fn_ds_table +  crlf + crlf + ;
               ErrorMessage(oError) )
   end

return lOk

//***********************************************************************************************************************************
   * Function ------------------------

//
// dbfviewer
//
static function dv_viewer(nSelect)

   Local i, temp, r, c
   local gap := 28
   Local cFontname, nFontsize
   Local cAlias
   Local aIndexinfo, aButtons
   Local cDvWinname, cFilter
   Local aColVis

   // some settings
   SET BROWSESYNC ON

   // tbrowse header font
   IF ! _IsControlDefined ("FontBold","Main")
      cFontname := _HMG_DefaultFontName     // current font name
      nFontsize := _HMG_DefaultFontSize     // current font size
      DEFINE FONT FontBold FONTNAME cFontname SIZE nFontsize BOLD // ITALIC
   endif

   // if no area number passed get the current active area
   if nSelect == nil
      nSelect := select()
   endif

   // select area to browse
   select (nSelect)

   // get alias name
   cAlias := Alias()

   // get current filter
   cFilter := DBINFO(DBI_DBFILTER)
   //cFilter := "LEFT(REFER,1)=='T'"         // for test

   // get number of orders
   nOpenindexfiles := DBORDERINFO(DBOI_BAGCOUNT)

   // fill a array with available index info
   aIndexinfo := {}
   AADD(aIndexinfo, '00 - No order')
   // multi TAG orderbag files
   for i := 1 to DBORDERINFO(DBOI_ORDERCOUNT)
        AADD(aIndexinfo, strzero(i,2) + ' - ' + ORDNAME( i, ORDBAGNAME(i)) + repl(chr(9),2) + " - " + Indexkey(i) + ' for ' + ORDFOR(ORDNAME(i)))
   next i

   // Fill array "column visibility" with structure of the table
   aColVis := (cAlias )->(dbStruct())
   // add logical element displayed as a checkbox
   AEval( aColVis, { |a| AAdd( a, .T. ) } )

   // Construct at each entry a unique window id name so that multiple windows can be opened.
   // This name is also used as suffix to create subwindows form names like search/replace, seek, ....
   cDvWinname := 'f_dv_' + hb_ntos(int(seconds()*100))

   // define window
   define window &cDvWinname ;
      AT GetDesktopHeight()/2 - int(GetDesktopHeight() * 0.85)/2, GetDesktopWidth()/2 - int(GetDesktopWidth() * 0.70)/2 ;
      clientarea int(GetDesktopWidth() * 0.80), int(GetDesktopHeight() * 0.80) ;
      TITLE 'OTIS - Open Table InSpector         File : ' + alltrim(Sx_Tablename()) + "         Alias : "+ Alias() + "         Area : "+hb_ntos(select()) + "         Cp : "+ (cAlias)->(DBINFO(147)) ;
      BACKCOLOR th_w_bgcolor ;
      WINDOWTYPE STANDARD ;
      ON SIZE     dv_mw_resize( cDvWinname ) ;
      ON MAXIMIZE dv_mw_resize( cDvWinname ) ;
      ON MINIMIZE dv_mw_resize( cDvWinname ) ;
      ON RELEASE  dv_mw_release( cDvWinname )

      // save current area properties in the window CARGO property
      //  they are used to restore area properties when releasing this window.
      temp := { cAlias, ;
                RECNO(), ;
                INDEXORD(), ;
                DBFILTER(), ;
                DBORDERINFO(DBOI_SCOPETOP),;
                DBORDERINFO(DBOI_SCOPEBOTTOM) ;
              }
      setproperty(cDvWinname, "CARGO", temp)

      // Init row pos and gap
      // For all controls defined below
      r   := th_w_ctrlgap * 2

      // Index button (label) and index select combobox
      DEFINE LABEL lb_sel_index
         ROW r
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT 23
         FONTBOLD .T.
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         Value ' Order info  (' + hb_ntos(DBORDERINFO(DBOI_ORDERCOUNT)) + ')'
         VCENTERALIGN .T.
         Action show_Active_index_info(cAlias, getproperty(ThisWindow.name, "cb_sel_index","VALUE"))
      END label

      // Select index combobox
      Define COMBOBOX cb_sel_index
         row r
         COL col_right_off( ThisWindow.name, "lb_sel_index" ) + th_w_ctrlgap
         width  600
         height 250
         ITEMS aIndexinfo
         VALUE (cAlias)->(INDEXORD()) + 1             // +1 because the first entry is '0 - no order'
         ONCHANGE dv_change_order( cDvWinname )
      end combobox

      // Order Scope, checkbox and label
      * small empty label left of checkbox to obtain a visual centered checkbox
      Define label lb_cv_dumos
         row r
         col col_right_off( ThisWindow.name, "cb_sel_index" )  + th_w_ctrlgap
         height 23
         width 4
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      end label
      // checkbox Order Scope
      DEFINE Checkbox cb_ordscope_yn
         ROW r
         COL col_right_off( ThisWindow.name, "lb_cv_dumos" )
         WIDTH th_bt_width - 4
         HEIGHT 23
         //FONTBOLD .T.
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         Caption " Order Scope"
         LEFTJUSTIFY .F.
         ON CHANGE dv_scope(cDvWinname, "ONOFF" )
         ON INIT This.Enabled := if( getproperty(ThisWindow.name, "cb_sel_index", "Value") - 1 == 0, .F., .T. )
      END Checkbox


      // checkbox "EDIT on/off"
      DEFINE Checkbox cb_edit_yn
         ROW r
         COL col_right_off( ThisWindow.name, "cb_ordscope_yn" ) + th_w_ctrlgap
         WIDTH th_bt_width - 4
         HEIGHT 23
         //FONTBOLD .T.
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         Caption ' F2 Allow Edit'
         ToolTip "Allow edit of a field with 'Enter' or a 'Double click'."
         LEFTJUSTIFY .T.
         ON CHANGE dv_cb_edit_yn(cDvWinname)
      END Checkbox
      * small empty label right of checkbox to obtain a visual centered checkbox
      Define label lb_dummy3
         row r
         col col_right_off( ThisWindow.name, "cb_edit_yn" )
         height 23
         width 4
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      end label


      // Checkbox "Hide deleted : on/off"
      DEFINE Checkbox cb_deleted_yn
         ROW r
         COL col_right_off( ThisWindow.name, "lb_dummy3" ) + th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT 23
         //FONTBOLD .T.
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         Caption ' Hide Deleted'
         ToolTip "Show / Hide deleted() records."
         LEFTJUSTIFY .T.
         ONINIT {|| setproperty(ThisWindow.name, "cb_deleted_yn", "Cargo", .T.), ;    // enable on change function,
                                                                                 ;    // argo is used to prevent recursif onchange calls
                    setproperty(ThisWindow.name, "cb_deleted_yn", "Value", Set( _SET_DELETED) ) ;
                }
         ON CHANGE dv_cb_hide_deleted_yn(cDvWinname)
      END Checkbox
      * small empty label right of checkbox to obtain a visual centered checkbox
      Define label lb_dummy1
         row r
         COL col_right_off( ThisWindow.name, "cb_deleted_yn" )
         height 23
         width 4
         BACKCOLOR th_bt_ohbgcol
      end label


      // checkbox "lock columns"
      * checkbox
      DEFINE Checkbox cb_lockcols_yn
         ROW r
         col col_right_off( ThisWindow.name, "lb_dummy1" ) + th_w_ctrlgap
         WIDTH th_bt_width - 5
         HEIGHT 23
         //FONTBOLD .T.
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         Caption ' Lock columns'
         LEFTJUSTIFY .T.
         ON CHANGE dv_change_lockcols( cDvWinname, "CB")
      END Checkbox
      * small empty label right of checkbox to obtain a visual centered checkbox
      Define label lb_dummy5
         row r
         col col_right_off( ThisWindow.name, "cb_lockcols_yn" )
         height 23
         width 4
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      end label
      * spinner
      DEFINE SPINNER sp_lockcols
         ROW r
         col col_right_off( ThisWindow.name, "lb_dummy5" ) + 3
         WIDTH 40
         HEIGHT 23
         RANGEMIN 0
         RANGEMAX 20
         HORIZONTAL .F.
         //FONTBOLD .T.
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         VALUE 0
         ON CHANGE dv_change_lockcols( cDvWinname, "SP")
      END SPINNER


      // Filter button (label), checkbox, editbox
      r := row_below_off(ThisWindow.name, "lb_sel_index") + th_w_ctrlgap
      DEFINE LABEL lb_filter
         ROW r
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT 23
         FONTBOLD .T.
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         Value " Filter    -->"
         VCENTERALIGN .T.
         ACTION { || if( empty( getproperty(ThisWindow.name,"tb_filter","Value")), ;
                         dv_setfilter(ThisWindow.name), ;
                         setproperty(ThisWindow.name,"tb_filter","Value", "") ;
                       ), ;
                     dv_setfilter(cDvWinname, .T.) ;
                }
         // font and background color when onhover / onleave
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
      END label

      // Filter Textbox
      define TEXTBOX tb_filter
         row r
         col col_right_off( ThisWindow.name, "lb_filter" ) + th_w_ctrlgap
         height 23
         width 600
         ONINIT This.Value := cFilter
         ONCHANGE { || setproperty(ThisWindow.name,"lb_filter","Value", if( empty( getproperty(ThisWindow.name,"tb_filter","Value")), " Filter    -->", " Filter clear")) }
         VALUE nil
      end textbox
      // checkbox Filter small empty label right of checkbox to obtain a visual centered checkbox
      Define label lb_dummy
         row r
         col col_right_off( ThisWindow.name, "tb_filter" ) + th_w_ctrlgap
         height 23
         width 4
         BACKCOLOR th_bt_ohbgcol
         ON INIT This.tb_filter.Onchange
      end label
      // checkbox filter On/Off
      Define Checkbox cb_filter
         row r
         col col_right_off( ThisWindow.name, "lb_dummy" )
         height 23
         width th_bt_width - 4
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         caption "On/Off"
         LEFTJUSTIFY .F.
         ON INIT This.Value := if( !empty( getproperty(ThisWindow.name, "tb_filter","Value")  ), .T., .F. )
         ON CHANGE dv_setfilter(cDvWinname, .T.)
         value .F.
      end checkbox


      // tbrowse refresh button (same as F5)
      DEFINE LABEL lb_refresh
         ROW r
         col col_right_off( ThisWindow.name, "cb_filter" ) + th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT 23
         FONTBOLD .F.
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         Value ' F5 Refresh'
         TOOLTIP "Refresh browse"
         VCENTERALIGN .T.
         CENTERALIGN .F.
         Action dv_F5Refresh(cDvWinname)
      END label


      // Checkbox "File lock : on/off"
      //    can be set only if exclusive mode is off
      //    this permits to temporary lockout modifications in other instances or parts in the program when in Otis plugin-mode.
      DEFINE Checkbox cb_filelock_yn
         ROW r
         col col_right_off( ThisWindow.name, "lb_refresh" ) + th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT 23
         //FONTBOLD .T.
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         Caption ' Filelock'
         ToolTip "Place a temporary filelock when you want to lockout others instances to modify this table at the same time."
         LEFTJUSTIFY .T.
         ONINIT setproperty(ThisWindow.name, "cb_filelock_yn", "Value", !(cAlias)->(DBINFO(DBI_SHARED)) )
         ON CHANGE dv_change_filelock(cDvWinname)
      END Checkbox
      * small empty label right of checkbox to obtain a visual centered checkbox
      Define label lb_dummyfl
         row r
         col col_right_off( ThisWindow.name, "cb_filelock_yn" )
         height 23
         width 4
         BACKCOLOR th_bt_ohbgcol
      end label


      // Button : Hide columns
      DEFINE LABEL lb_colvis
         ROW r
         col col_right_off( ThisWindow.name, "lb_dummyfl" ) + th_w_ctrlgap
         WIDTH th_bt_width - 21
         HEIGHT 23
         //FONTBOLD .T.
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         //Value " Column Visib."
         Value " Hide Columns"
         VCENTERALIGN .T.
         ACTION { || dv_ColumnVis(cDvWinname, aColVis) }
         /*
         // font and background color when onhover / onleave
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
         */
      END label
      // checkbox col vis
      DEFINE Checkbox cb_colvis_yn
         ROW r
         col col_right_off( ThisWindow.name, "lb_colvis" )
         WIDTH 16
         HEIGHT 23
         //FONTBOLD .T.
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         Caption ' '
         LEFTJUSTIFY .T.
         ON CHANGE { || if( This.Value, dv_Apply_ColVis( cDvWinname, aColVis ), dv_Apply_AllVis( cDvWinname, aColVis ) ) }
      END Checkbox
      * small empty label right of checkbox to obtain a visual centered checkbox
      Define label lb_cv_dummy
         row r
         col getproperty(ThisWindow.name, "cb_colvis_yn","col") + getproperty(ThisWindow.name, "cb_colvis_yn","width")
         height 23
         width 4
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      end label


*********************************************

      // Tbrowse
      DEFINE TBROWSE tb_Dv_Browse  ;
         AT getproperty(ThisWindow.name, "lb_filter","row")+getproperty(ThisWindow.name, "lb_filter","height")+th_w_ctrlgap, th_bt_width * 1 + th_w_ctrlgap * 2 ;
         WIDTH getproperty(ThisWindow.name,"ClientWidth") - th_bt_width * 1 -  th_w_ctrlgap * 3 ;
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - ( getproperty(ThisWindow.name, "lb_filter","row")+getproperty(ThisWindow.name, "lb_filter","height")) - th_w_ctrlgap*2  + 2 ;
         COLORS {CLR_BLACK, CLR_WHITE} ;
         SIZE 10 ;
         ALIAS cAlias ;
         MESSAGE " Browse DataBase ";
         EDITABLE ;
         APPEND ;
         SELECTOR .T.

         // add column with recno
         ADD COLUMN TO tb_Dv_Browse  ;
            ;//HEADER "Log.Pos." ;
            ;//DATA   (cAlias)->(Sx_KeyNo()) ;           // &(tb_Dv_Browse):nLogicPos ;
            HEADER "Record" ;
            DATA   (cAlias)->(recno()) ;              // &(tb_Dv_Browse):nLogicPos ;
            SIZE 60 PIXELS ;
            3DLOOK TRUE,TRUE,FALSE ;                  // cels, header, footer
            ALIGN DT_CENTER,DT_CENTER,DT_CENTER ;     // cells, header, footer
            COLORS CLR_BLACK, CLR_HGRAY

         // add column with deleted() status
         ADD COLUMN TO tb_Dv_Browse ;
            HEADER "Del" ;
            DATA   {|| if((cAlias)->(deleted()),"x"," ") };
            SIZE 30 PIXELS ;
            3DLOOK TRUE,TRUE,FALSE ;                  // cels, header, footer
            ALIGN DT_CENTER,DT_CENTER,DT_CENTER ;     // cells, header, footer
            COLORS CLR_BLACK, CLR_HGRAY

         // building columns for every field making not editable (.T.)
         :LoadFields(.F.)

         // set celled navigation
         :lCellBrw := .T.

         // avoids changing active order by double clicking on headers
         :lNoChangeOrd := .T.

         // <Enter> key processing
         :nFireKey     := VK_F10         // default Edit key

         // mouse wheel skip, 3 line
         :nWheelLines := 3

         // header is a little bit heigher than the data rows
         tb_Dv_Browse:nHeightHead += 6
         // HEADER IN BOLD
         MODIFY TBROWSE tb_Dv_Browse HEADER FONT TO FontBold

         // cell margins, add one space left and right
         :nCellMarginLR := 1

         // TODO
         // Correct cell height to a fixed size because height will be auto adapted by tbrowse if there is a Memo field.
         //tb_Dv_Browse:nHeightCell += 2
         //tb_Dv_Browse:nHeightCell := 18

         // draw footer
         :lDrawFooters := .T.
         :lFooting     := .T.
         :nHeightFoot  := tb_Dv_Browse:nHeightHead

         // Footer settings
         //    index key count
         //to remove :aColumns[1]:cFooting := { |nc| hb_ntos((cAlias)->(Sx_KeyCount())) }
         :aColumns[1]:cFooting := { || hb_ntos((cAlias)->(Sx_KeyCount())) }
         //    footer :  reccount()
         //to remove :aColumns[3]:cFooting := { |nc| hb_ntos((cAlias)->(reccount())) }
         :aColumns[3]:cFooting := { || hb_ntos((cAlias)->(reccount())) }

         //tb_Dv_Browse:bChange := { |oBr| oBr:DrawFooters() }

         // freeze the 2 first columns
         :nFreeze := 2

         // Row Colors, fontcolor en/disabled, bg odd or even
         :SetColor( { 1, 2 }, { th_fctb_leven, {|nRow, nCol, oBrw| iif( nRow%2==0, th_bgtb_leven, th_bgtb_lodd )}} )

         // enable freeze
         :lLockFreeze := .T.
         :SetNoHoles()

         :ResetVScroll(.T.)

         // <DELETE> key processing, disable here but enable by EDIT CHECKBOX
         :SetDeleteMode( .F., .F. )
         :bPostDel := {|o| o:Refresh( .F. ) }

      end TBROWSE

      // restore table index order
      // it is set to 1 when defining the tbrowse object,
      // WHY, i don't know ....
      (cAlias)->( ORDSETFOCUS(getproperty(cDvWinname,"CARGO")[dvc_indfocus]) )

      // goto recno stored in the Cargo
      (cAlias)->( DBGOTO(getproperty(cDvWinname,"CARGO")[dvc_recno]) )
      tb_Dv_Browse:GoToRec( (cAlias)->( RecNo() ) )
      tb_Dv_Browse:refresh()

      //msgstop((cAlias)->(indexord()))

      // Define left menu buttons
      //              "Value Label"                  "menu_keyword" (used by dispatcher)
      aButtons := { ;
                     { "-"                             , ""      } , ;
                     { "Seek wizard"                   , "dv_sk" } , ;
                     { "Search|Repl."                  , "dv_sr", "dv_srext" } , ;
                     { "Goto record"                   , "dv_go" } , ;
                     { "-"                             , ""      } , ;
                     { "Copy|Paste"                    , "dv_cp", "dv_pa" } , ;
                     { "Clear|Dupl."                   , "dv_cl", "dv_du" } , ;
                     { "Add|Insert"                    , "dv_ai", "dv_ai" } , ;
                     { "Up|Down"                       , "dv_up", "dv_down" } , ;
                     { "Delete|Recall"                 , "dv_dr", "dv_dr" } , ;
                     { "-"                             , ""      } , ;
                     { "Pack|Zap"                      , "dv_pack", "dv_zap" } , ;
                     { "Append file"                   , "dv_af" } , ;
                     { "-"                             , ""      } , ;
                     { "Index manager"                 , "dv_im" } , ;
                     { "-"                             , ""      } , ;
                     { "Prop. / Struct."               , "dv_st" } , ;
                     { "Struct. Editor"                , "ot_dvse" } , ;
                     { "-"                             , ""      } , ;
                     { "Export -> csv"                 , "dv_export" } , ;
                     { "Save (as)"                     , "dv_save" } , ;
                     { "-"                             , ""      } ;
                   }

      // define start row, col position
      r := getproperty(ThisWindow.name,"tb_Dv_Browse","row")
      c := th_w_ctrlgap
      // draw menu buttons
      draw_menu( r, c, aButtons, cDvWinname )

      // Button : Set focus to the Dataset Manager WITHOUT closing this 'Inspector'
      // Only if main windows is not hidden.
      if getproperty("form_otis", "VISIBLE")
         DEFINE Label mb_backtods
            ROW  getproperty(ThisWindow.name,"ClientHeight") - 2 * th_bt_height - th_w_ctrlgap * 2
            COL  th_w_ctrlgap
            WIDTH th_bt_width
            HEIGHT th_bt_height
            FONTBOLD .T.
            FONTCOLOR th_bt_fontcol
            BACKCOLOR th_bt_bgcol
            Value " Dataset mng"
            VCENTERALIGN .T.
            CENTERALIGN .T.
            ACTION { || domethod("form_otis", "SETFOCUS"), domethod("form_otis", "tb_Otis", "SETFOCUS")}
            ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
            ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
         END label
      endif

      // Quit button, always on the bottom
      DEFINE Label mb_Quit
         ROW  getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap * 1
         COL  th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Quit"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         ACTION ThisWindow.Release
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      END label

   END WINDOW

   // F2 toggle Edit checkbox
   ON KEY F2 OF &cDvWinname ACTION { || setproperty(cDvWinname, "cb_edit_yn", "value", !getproperty(cDvWinname, "cb_edit_yn", "value")), ;
                                        dv_cb_edit_yn(cDvWinname) }

   // Key "F5" set to refresh tbrowse
   ON KEY F5 OF &cDvWinname ACTION dv_F5Refresh(cDvWinname)

   domethod(cDvWinname, "tb_Dv_Browse", "setfocus")
   //domethod( cDvWinname, "CENTER")     // does not work and i don't know why ???
   domethod( cDvWinname, "ACTIVATE")

return nil


// F5 Refresh browse
// Needed if a external process outside of Otis change table size
// Without it display of new records is incorrect
// because tbrowse is not aware of those new records and still draws records in function of old reccount
function dv_F5Refresh(cWinname)

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )

   o_browse:refresh()

return nil


// main dbfviewer window RELEASE
static function dv_mw_release( cWinname )

   local i

   // get table alias from the the passed form name cargo.
   local cAlias := getproperty(cWinname,"CARGO")[dvc_alias]

   // close all possible sub windows, like the seek, search/replace forms and others
   //   all "DV_" subwindows start with the string in the array + the DV 'cWinname'.
   Local aForms := { "f_seek_"      ,;
                     "f_sr_"        ,;
                     "f_scope_"     ,;
                     "f_sre_"       ,;
                     "f_goto_"      ,;
                     "f_ai_"        ,;
                     "f_dre_"       ,;
                     "f_tabprop_"   ,;
                     "f_indmng_"    ,;
                     "f_indnew_"    ,;
                     "f_vi_"  }
   for i := 1 to len(aForms)
      if ISWINDOWDEFINED("'"+ aForms[i] + cWinname +"'")
         domethod( aForms[i] + cWinname, "RELEASE")
      endif
   next i

   // if the area is still in use, restore area properties.
   //   don't forget it could be closed by the running application if otis is included in your program.
   if SELECT(cAlias) <> 0

      // debug
      /*
      msgstop( getproperty(cWinname,"CARGO")[dvc_alias] )
      msgstop( getproperty(cWinname,"CARGO")[dvc_indfocus] )
      msgstop( "<"+getproperty(cWinname,"CARGO")[dvc_filter] + ">")
      msgstop( getproperty(cWinname,"CARGO")[dvc_recno] )
      */

      // restore index
      (cAlias)->( ORDSETFOCUS(getproperty(cWinname,"CARGO")[dvc_indfocus]) )
      // set filter as it was before
      cMacro := getproperty(cWinname,"CARGO")[dvc_filter]
      if !empty(cMacro)
         (cAlias)->( DbSetFilter( &("{||" + cMacro + "}" ), cMacro ) )
      else
         (cAlias)->(DBCLEARFILTER())
      endif
      // go back to recno
      (cAlias)->( DbGoto(getproperty(cWinname,"CARGO")[dvc_recno]) )

      // TODO, not sure
      // release allways all locks
      (cAlias)->(dbunlock())

   endif

   // set focus back to OTIS main screen after closing a dbfviewer window
   if ISWINDOWDEFINED("form_otis")
      cWhoSetFocustoMain := "DV"
      domethod( "form_otis", "SETFOCUS")
   endif

return nil


// main dbfviewer browse window RESIZE :
//    resize and reposition controls in this window.
static function dv_mw_resize( cWinname )

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )

   // height and width browse table
   setproperty(ThisWindow.name, "tb_Dv_Browse", "Width", getproperty(ThisWindow.name,"ClientWidth") - th_bt_width * 1 - th_w_ctrlgap * 3 )
   setproperty(ThisWindow.name, "tb_Dv_Browse", "Height", getproperty(ThisWindow.name,"ClientHeight") - th_bt_height * 2 - th_w_ctrlgap * 4 )

   // repos menu & Ds mng button
   setproperty(ThisWindow.name, "mb_Quit","Row", getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap * 1 )

   // if _IsControlDefined("mb_backtods", "form_otis")
   // Can't get working previous line with _IsControlDefined() so i test it with next line.
   if getproperty("form_otis", "VISIBLE")
      setproperty(ThisWindow.name, "mb_backtods","Row", getproperty(ThisWindow.name,"ClientHeight") - th_bt_height * 2 - th_w_ctrlgap * 2 )
   endif

   // refresh tbrowse is necessary, if not used display of cols could be disturbed.
   o_Browse:refresh()

return nil


// Change order
static function dv_change_order( cWinname )

   LOCAL temp, cTopExpr, cBottomExpr

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_browse:cAlias

   // change order in function of selected item in the combobox
   //   -1 because entry 1 is 'No order'
   temp := getproperty(cWinname, "cb_sel_index", "Value") - 1
   (cAlias)->(ORDSETFOCUS(temp))

   // If no order disable scope checkbox
   setproperty(cWinname,"cb_ordscope_yn","Enabled", if(temp == 0, .F., .T.) )
   //setproperty(cWinname,"lb_ordscope","Enabled", if(temp == 0, .F., .T.) )

   // get orderscope if any
   //   it could be set when you selected this order before and defined a scope for it.
   //   so when you reselect this order the scope must be reinitialized.
   cTopExpr    := DBORDERINFO(DBOI_SCOPETOP)
   cBottomExpr := DBORDERINFO(DBOI_SCOPEBOTTOM)
   // save it in the tbrowse 'cargo'
   temp := getproperty(cWinname,"CARGO")
   temp[dvc_ScopeTop]    := cTopExpr
   temp[dvc_ScopeBottom] := cBottomExpr
   setproperty(cWinname, "CARGO", temp)
   // and enabled it
   // set  top / bottom scope
   (cAlias)->(ordscope(TOPSCOPE, cTopExpr))
   (cAlias)->(ordscope(BOTTOMSCOPE, cBottomExpr ))
   // set / reset checkbox
   temp := if( empty(cTopExpr) .and. empty(cBottomExpr), .F., .T.)
   Setproperty(cWinname, "cb_ordscope_yn","Value", temp)

   // message, a scope is active and not all records are displayed
   if temp
      msginfo("Warning" + crlf + crlf +;
              "A scope is defined for this order thus" + crlf + ;
              "not all records will be displayed.")
   endif

   // go always to the top
   // o_Browse:GoTop() does not work if ordnumber is set to 0
   //   workaround
   o_Browse:GoPos( (cAlias)->(DBGOTOP()) )

   // refresh browse and setfocus
   o_Browse:refresh()
   o_Browse:setfocus()
   o_Browse:ResetVScroll( .T. )
   // and set min max range
   o_Browse:oVScroll:SetRange( 1, ordKeyCount())

return nil


// "Lock columns" spinner change
static function dv_change_lockcols(cWinname, cType)

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )

   // always set checkbox if Spinner change
   if cType == "SP"
      setproperty(ThisWindow.name,"cb_lockcols_yn","Value", .T.)
   endif

   // ON
   if getproperty(ThisWindow.name,"cb_lockcols_yn","Value")

      // set frozen columns, don't forget to include the 3 first ones
      o_Browse:nFreeze := getproperty(ThisWindow.name, "sp_lockcols","value") + 3

   // off, always freeze first 3 cols
   else
      o_Browse:nFreeze := 3
   endif

   // refresh browse
   o_Browse:refresh()
   o_Browse:setfocus()

return nil


// change set deleted status to show or hide deleted() records.
static function dv_cb_hide_deleted_yn(cWinname)

   // get previous status of checkbox before clicking on it
   local lNewstat := getproperty(cWinname,"cb_deleted_yn","Value")
   local lOldstat := !lNewstat

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // if on change function enabled by cargo value
   if getproperty(cWinname,"cb_deleted_yn","Cargo")

      // Off to ON
      if lNewstat
         // if deleted() is used in the index FOR expression then
         // display a warning.
         if "DELETED()" $ upper( (cAlias)->(ORDFOR( (cAlias)->(ORDNAME()) )) )
            MsgInfo("WARNING"+crlf+crlf + ;
                    "Deleted records are not displayed because the FOR clause"+crlf + ;
                    "contains the DELETED() function in the selected index.")
            // reset checkbox
            //lNewstat := .F.
         endif
      endif

      // Warning this a global setting
      //  ask confirmation to change status
      if lNewstat <> lOldstat

         // ask for confirmation only in plugin mode
         if !lStandalone

            PlayExclamation()
            IF !msgYesNo("WARNING :" + crlf + crlf + ;
                            "SET DELETED ON/OFF is A GLOBAL PROGRAM SETTING." + crlf + crlf + ;
                            "It changes the record visibility of all opened" + crlf + ;
                            "tables and also the tables opened by your program" + crlf + ;
                            "if you are in plugin mode."+ crlf + ;
                            "Be carefull." + crlf + crlf + ;
                            "Do you want to change this setting ?" ;
                            )
               // Answer was NO thus reset flag to the previous state
               lNewstat := !lNewstat
            endif

         endif

         // set deleted() on/off
         Set( _SET_DELETED, lNewstat )

         // set new status
         setproperty( cWinname, "cb_deleted_yn", "Cargo", .F.)       // prevent recursif call
         setproperty( cWinname, "cb_deleted_yn", "Value", lNewstat )
         setproperty( cWinname, "cb_deleted_yn", "Cargo", .T.)

         // refresh tbrowse and setfocus to it
         //o_Browse:gotop()
         o_Browse:refresh()
         o_Browse:setfocus()

      endif

   endif

return nil


// change checkbox : file lock
static function dv_change_filelock(cWinname)

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // if SET place a file lock
   if getproperty(ThisWindow.name, "cb_filelock_yn","Value")

      // if not already in EXCLUSIVE mode, place a file lock
      if (cAlias)->(DBINFO(DBI_SHARED))
         if !(cAlias)->(Flock())
            setproperty(cWinname, "cb_filelock_yn","Value", .F.)
            msgstop("A filelock could not be placed on alias : " + cAlias + ".")
         endif
      endif

   // If reset
   // checkbox can be set to false only if the file was not opened in SHARED mode
   else
      if (cAlias)->(DBINFO(DBI_SHARED))
         (cAlias)->(DBUNLOCK())
      else
         setproperty(cWinname, "cb_filelock_yn","Value", .T.)
         msgstop("The filelock can not be released for alias : " + cAlias + "." + crlf + crlf + ;
                 "The table is opened in EXCLUSIVE mode.")
      endif
   endif

   // set focus back to 'tbrowse'
   o_Browse:SetFocus()

return nil


// Enable / Disable EDIT browse
static function dv_cb_edit_yn(cWinname)

   // get checkbox status
   local lTemp := getproperty(cWinname,"cb_edit_yn","Value")

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )

   // enable/disable edit in all columns
   aeval(o_browse:aColumns, { | oCol | oCol:lEdit:= lTemp })

   // enable/disable DELETE key to delete/recall a record
   o_browse:SetDeleteMode( lTemp, .F. )
   //  cb must be set again after change setdeletemode, why ???
   o_browse:bPostDel := {|o| o:Refresh( .F. ) }

   // set focus back to 'tbrowse'
   o_Browse:SetFocus()

return nil


// set / clear filter
static function dv_setfilter(cWinname, lNowarning)

   local nRecno := 1, cFilter := ""

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // default allways display a warning
   Default lNowarning := .F.

   // ON : set filter
   if getproperty(cWinname,"cb_filter","Value")

      // get filter
      cFilter := alltrim( getproperty(cWinname,"tb_filter","Value") )

      // Message, no filter defined
      if empty(cFilter)

         // message if necessary
         if !lNowarning
            msginfo("No filter defined.")
         endif
         // uncheck
         setproperty(cWinname,"cb_filter","Value", .F.)

      // set filter
      else

         // activate filter with error trapping
         try
            if ( ValType( &cFilter ) == "L" )
               o_browse:FilterData(cFilter)
               o_browse:ResetVscroll()
            endif

         Catch oError
            MsgStop("Filter expression error :" + crlf + crlf + ;
                       ErrorMessage(oError) ;
                     )
            setproperty(cWinname,"cb_filter","Value", .F.)

         end

      endif

   // OFF : clear filter
   else
      // get current pos dbf
      nRecno := recno()
      // clear filter and browse filter
      cFilter := ""
      o_browse:FilterData("")
      // position on the same record as filtered
      o_browse:GoPos(nRecno)

   endif

   // refresh browse
   o_browse:SetFocus()

return nil


// Seek wizard
static function dv_seek(cWinname)

   local temp, i, r, c1, c2, maxcw, cKey, aFields
   local aColVis, cFtype, cFlen, cFdec

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // construct at each entry a unique form id name so that multiple search forms can be opened.
   LOCAL f_seek := 'f_seek_' + cWinname       // cWinname is already a unique form ID

   // Set focus back to this form if it is already open
   if ISWINDOWDEFINED("'"+f_seek+"'")
      domethod( f_seek, "SETFOCUS")
      return nil
   endif

   // load table structure
   aColVis := (cAlias)->(DBSTRUCT())

   // get KEY from active index
   cKey := (cAlias)->( Indexkey(IndexOrd()) )

   // Exit if no KEY active
   if empty(cKey)
      MsgInfo("Seek impossible, there is no index activ.")
      return nil
   endif

   // ******************************************
   // THE INDEX KEY PARSER IS NOT PERFECT AND PROBABLY HAS TO BE MODIFIED / EXTENDED, see remarks below
   //
   // For the moment i start with the idee that a KEY contains functions and/or udf and only FIELDNAMES.
   // This is maybe not the reality, sometimes program vars are used.
   // We wait for examples to see if modifs are necessary.
   //
   // Function dv_seek2() returns the substituted KEY expression used in DBSEEK()
   //    It does not return the string to seek because there could be functions in it
   //    and they transform maybe the entered data.
   //
   // 15/06/2020
   // Added a option to enter manually the seek expression.
   // Some Keys contains conditional expressions that are very difficult to analyse and to use with
   // the autofill option. Example :
   //   iif(.not. deleted(),doctype+accountrp+bookyear+period+DTOS(date)+str(recno(),6),space(28))
   //
   aFields := {}

   // fill aFields with the at() position and fieldnames used in the cKey
   for i := 1 to len(aColVis)
      if ( temp := at( aColVis[i,DBS_NAME], UPPER(cKey) ) ) <> 0
         aadd( aFields, { temp , aColVis[i,DBS_NAME] } )
      endif
   next i

   // sort this array on the at() pos because controls in the form have to be
   // presented in the same order as they are presented in the Key expression.
   if len(aFields) > 1
      do while i <> len(aFields)
         for i := 1 to len(aFields) - 1
            if aFields[i+1,1] < aFields[i,1]
               temp := aFields[i]
               aFields[i]   := aFields[i+1]
               aFields[i+1] := temp
               exit
            endif
         next i
      enddo
   endif

   // keep only the field names after sort
   aeval( aFields, { |a, i| aFields[i] := a[2] } )
   // debug
   /*
   temp := ""
   temp := aeval( aFields, { |cStr| temp =+ cStr + crlf } )
   msgstop(temp)
   */

   // ******************************************

   // create a form with controls for each fieldname used in the index KEY expression
   //  these controls are used for user input.
   define window &f_seek ;
   AT getproperty(cWinname,"Row")+250, getproperty(cWinname,"Col")+250 ;
   clientarea Max( th_bt_width * 1.5 + GetTextWidth( ,cKey) + 100 + th_w_ctrlgap * 6, th_bt_width * 2 + 250 + th_w_ctrlgap * 6 ), ;
              Max( (len(aFields) + 3) * (th_bt_height + th_w_ctrlgap) + th_w_ctrlgap * 2, (th_bt_height + th_w_ctrlgap) * 7 ) ;
   TITLE 'OTIS - Seek wizard for alias : ' + cAlias ;
   WINDOWTYPE STANDARD ;
   BACKCOLOR th_w_bgcolor ;
   ;//TOPMOST ;
   NOSIZE ;
   ;//NOMINIMIZE ;
   NOMAXIMIZE
   //ON LOSTFOCUS ThisWindow.release

      // min, max form size
      //ThisWindow.MaxHeight := getproperty(ThisWindow.name, "Height")
      //ThisWindow.MinHeight := ThisWindow.MaxHeight

      // background controls
      DEFINE LABEL bg_seek
         ROW    th_w_ctrlgap
         COL    th_bt_width + th_w_ctrlgap * 2
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 3
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2
         VISIBLE .T.
      END LABEL
      // frame around, looks nicer
      define FRAME fr_seek
         row    getproperty(ThisWindow.name, "bg_seek","row")
         col    getproperty(ThisWindow.name, "bg_seek","col") + 1
         width  getproperty(ThisWindow.name, "bg_seek","width") - 1
         Height getproperty(ThisWindow.name, "bg_seek","Height")
      end frame

      // row, col start position for controls
      r  := th_w_ctrlgap * 2
      c1 := th_w_ctrlgap * 3 + th_bt_width
      c2 := c1 + th_bt_width + th_w_ctrlgap * 3
      // max control width
      maxcw := getproperty(ThisWindow.name,"bg_seek", "Width") - th_w_ctrlgap * 5 - th_bt_width

      // display index KEY expression
      DEFINE LABEL Lb_key1
         ROW    r
         COL    c1
         WIDTH  90
         HEIGHT 24
         VALUE "Order Key Expr."
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .T.
      END LABEL
      DEFINE LABEL Lb_key2
         ROW  r
         COL  c2
         WIDTH  200
         HEIGHT 24
         VALUE cKey
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .T.
      END LABEL

      // Use modified seek expression
      r += 24 + th_w_ctrlgap
      DEFINE LABEL Lb_UseModSeekExpr
         ROW    r
         COL    c1
         WIDTH  120
         HEIGHT 24
         VALUE "Expression by hand"
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL
      *
      DEFINE Checkbox cb_UseModSeekExpr
         ROW r
         COL c2
         AUTOSIZE .T.
         HEIGHT 24
         //Caption ' Allow modification of the expression.'
         Caption ' (Disable autofill of seek expression.)'
         LEFTJUSTIFY .F.
         VALUE .F.
         ON CHANGE setproperty(ThisWindow.name, "tb_seekstr", "ENABLED", This.Value )
      END Checkbox

      // display real seek string
      // next row pos
      r += 24 + th_w_ctrlgap
      DEFINE LABEL Lb_seekstr1
         ROW    r
         COL    c1
         WIDTH  90
         HEIGHT 24
         VALUE "Seek expression"
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .T.
      END LABEL
      DEFINE TEXTBOX tb_seekstr
         ROW  r
         COL  c2
         WIDTH getproperty(ThisWindow.name,"ClientWidth") - c2 - th_w_ctrlgap * 2
         HEIGHT 24
         FONTNAME pu_fontname
         FONTSIZE pu_fontsize
         VALUE ""
         ON INIT ( This.Enabled := .F. )
      END TEXTBOX

      // create user input controls
      for i := 1 to len(aFields)

         // next row pos
         r += th_bt_height + th_w_ctrlgap

         // get type of field
         if ( temp := Ascan( aColVis, { |a| a[DBS_NAME] == aFields[i] } ) ) <> 0
            cFtype := aColVis[temp, DBS_TYPE]
            cFlen  := aColVis[temp, DBS_LEN]
            cFdec  := aColVis[temp, DBS_DEC]
         endif

         // label with fieldname
         DEFINE LABEL &("bt_"+aFields[i])
            ROW r
            COL c1
            WIDTH th_bt_width
            HEIGHT 24
            Value aFields[i] + '  ('+lower(cFtype)+')'
            VCENTERALIGN .T.
         END label

         // control is in function of type
         do case

            // C
            case cFtype == 'C'
               DEFINE TEXTBOX &("cs_" + aFields[i])
                  ROW r
                  COL c2
                  WIDTH Min( GetTextWidth( , repl("A", cFlen) ) + 25, maxcw )  // + width correction, if not control width is to small
                  HEIGHT 24
                  FONTNAME pu_fontname
                  FONTSIZE pu_fontsize
                  VALUE NIL
                  MAXLENGTH cFlen
                  ON ENTER dv_seek_keysub(f_seek, cKey, aFields, aColVis)
              END TEXTBOX

            // N
            case cFtype == 'N'
               DEFINE TEXTBOX &("cs_" + aFields[i])
                  ROW r
                  COL c2
                  WIDTH GetTextWidth( , repl("9",cFlen+1))       // 1 extra char, if not control width is to small
                  HEIGHT 24
                  FONTNAME pu_fontname
                  FONTSIZE pu_fontsize
                  VALUE NIL
                  INPUTMASK repl('9',cFlen-if(cFdec<>0, cFdec+1, 0)) + if(cFdec <> 0, "."+repl('9', cFdec), "")
                  ON ENTER dv_seek_keysub(f_seek, cKey, aFields, aColVis)
               END TEXTBOX

            // D
            case cFtype == 'D'
               DEFINE TEXTBOX &("cs_" + aFields[i])
                  ROW r
                  COL c2
                  WIDTH GetTextWidth( , "99999999" )
                  HEIGHT 24
                  FONTNAME pu_fontname
                  FONTSIZE pu_fontsize
                  VALUE NIL
                  INPUTMASK "99/99/99"
                  ON ENTER dv_seek_keysub(f_seek, cKey, aFields, aColVis)
               END TEXTBOX

            // L
            case cFtype == 'L'
               DEFINE CHECKBOX &("cs_" + aFields[i])
                  ROW r
                  COL c2
                  WIDTH 24
                  HEIGHT 24
                  FONTNAME pu_fontname
                  FONTSIZE pu_fontsize
                  VALUE .F.
                  ON ENTER dv_seek_keysub(f_seek, cKey, aFields, aColVis)
               END CHECKBOX

        endcase

      next i

      // button : Seek FIRST
      DEFINE label lb_seekfirst
         ROW th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Seek First"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || dv_seek2(cWinname, f_seek, cKey, aFields, aColVis, .F., getproperty(ThisWindow.name, "cb_UseModSeekExpr", "VALUE") ) }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
      END label

      // button : Seek LAST
      DEFINE label lb_seeklast
         ROW th_w_ctrlgap + (th_bt_height + th_w_ctrlgap) * 1
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Seek Last"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || dv_seek2(cWinname, f_seek, cKey, aFields, aColVis, .T.,getproperty(ThisWindow.name, "cb_UseModSeekExpr", "VALUE") ) }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

      END label

      // button : Exact on/off
      DEFINE label lb_exact
         ROW th_w_ctrlgap + (th_bt_height + th_w_ctrlgap) * 2
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Exact OFF (=)"
         ToolTip "All arguments of type character will be padded to there field lenght when ON."
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         VISIBLE .T.
         ONINIT { || setproperty(ThisWindow.name, "lb_exact","Cargo", .F. ) }
         ACTION { || setproperty(ThisWindow.name, "lb_exact","Cargo", !getproperty(ThisWindow.name, "lb_exact","Cargo") ), ;
                     setproperty(ThisWindow.name, "lb_exact","Value", if(getproperty(ThisWindow.name, "lb_exact","Cargo")," Exact ON (==)"," Exact OFF (=)") ), ;
                     dv_seek_keysub(f_seek, cKey, aFields, aColVis) ;
                }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

      END label

      // button : Copy to filter
      DEFINE label lb_tofilter
         ROW th_w_ctrlgap + (th_bt_height + th_w_ctrlgap) * 3
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " To Filter"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || dv_seek_to_filter(cWinname, aFields, aColVis, getproperty(ThisWindow.name, "lb_exact","Cargo")) }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

      END label

      // button : Clear seek arguments
      DEFINE label lb_clseek
         ROW th_w_ctrlgap + (th_bt_height + th_w_ctrlgap) * 4
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Clear"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || dv_seek_clear(aFields, aColVis) }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

      END label

      // Quit button
      DEFINE LABEL bt_Quit
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Quit"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || ThisWindow.Release, domethod(cWinname, "SETFOCUS") }
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      END label

      // Escape Key
      ON KEY ESCAPE ACTION This.bt_Quit.OnClick  // ThisWindow.Release

   end window

   // activate window
   ACTIVATE WINDOW &f_seek

return nil


// Seek first or last record
static function dv_seek2( cWinname, cWinSeek, cKey, aFields, aColVis, lFirstLast, lUseModifExpr )

   local cSeekstr := ""

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // save current record
   Local nOldRec := (cAlias)->(RecNo())

   // substitut fieldnames by entered values
   if !lUseModifExpr
      cSeekStr := dv_seek_keysub(cWinSeek, cKey, aFields, aColVis)
   else
      cSeekStr := alltrim( getproperty(ThisWindow.name, "tb_seekstr", "VALUE") )
   endif

   // if seek string not empty
   if !empty(cSeekStr)

      // seek
      TRY
         if (cAlias)->( DBSEEK( &(cSeekStr), , lFirstLast ) )
            o_Browse:GoToRec( (cAlias)->( RecNo() ) )
         else
            MsgInfo("Seek not found.")
            o_Browse:GoToRec( (cAlias)->( nOldRec ) )
         endif

      catch oError
         MsgStop("Seek expression error :" + crlf + crlf + ;
                  ErrorMessage(oError) )
      end
      // refresh browse
      o_browse:refresh()

      // bring browse to the front
      //o_browse:SetFocus()
      // and set focus again to seek form
      //DOMETHOD( ThisWindow.name,"SETFOCUS")

   endif

return nil


// copy seek expression to the browse filter control
static function dv_seek_to_filter(cWinname, aFields, aColVis, lExact)

   local i, x, cFilter, cValue

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // ask confirmation
   if MsgOkCancel("Copy to filter")

      // construct filter
      cFilter := ""
      for i := 1 to len(aFields)

         // get field info from structure
         x := Ascan( aColVis, { |a| a[DBS_NAME] == aFields[i] } )

         //
         if !empty( cValue := getproperty( ThisWindow.name, "cs_"+aFields[i], "VALUE") )

            // in function of type of field
            do case
               // C
               case aColVis[x, DBS_TYPE] == "C"
                  cFilter += aFields[i] + if( lExact, "=='", "='") + if( lExact, padr(cValue, aColVis[x, DBS_LEN]), cValue) + "'.and."
               // D
               case aColVis[x, DBS_TYPE] == "D"
                  if cValue <> '  /  /  '
                     cFilter += aFields[i] + "==ctod('"+cValue+"').and."
                  endif
               // N
               case aColVis[x, DBS_TYPE] == "N"
                  cFilter += aFields[i] + "==" + cValue + '.and.'
            endcase

         endif

      next i

      // delete last .and.
      cFilter := left( cFilter, len(cFilter)-5)

      // copy to filter control
      setproperty(cWinname, "tb_filter","Value", cFilter)

   endif

return nil


// Build the seek expression, substitute "fieldnames' with control 'value's
static function dv_seek_keysub(cWinseek, cKey, aFields, aColVis)

   local i, x, cTbValue

   // set seek EXACT on/off flag
   local lExact := getproperty(ThisWindow.name,"lb_exact", "Cargo")

   // replace fieldnames in Key expression by entered values
   for i := 1 to len(aFields)

      // get control value
      cTbValue := getproperty( ThisWindow.name, "cs_"+aFields[i], "VALUE")

      // get field info from structure
      x := Ascan( aColVis, { |a| a[DBS_NAME] == aFields[i] } )

      // if not empty
      if ( aColVis[x, DBS_TYPE] <> "D" .and. !empty(cTbValue) ) ;
         .or. ;
         ( aColVis[x, DBS_TYPE] == "D" .and. !empty(alltrim(strtran(cTbValue,"/",""))) )

         // in function of type convert it to the proper type
         do case

            // num -> str
            case aColVis[x, DBS_TYPE] == "N"
               cTbValue := alltrim(cTbValue)

            // str -> 'ctod(date)'
            case aColVis[x, DBS_TYPE] == "D"
               cTbValue := "CTOD('"+cTbValue+"')"

            // str -> 'str' padded to the same lenght as the field.
            otherwise
               // If seek exact ON
               // padr with spaces,
               cTbValue := "'" + if( lExact, padr(cTbValue, aColVis[x, DBS_LEN]), cTbValue) + "'"
         endcase

         // substitute fieldname by value in expression
         cKey := strtran( cKey, aFields[i], cTbValue)
         // second time because fieldnames in the KEY expression could be lowercase
         cKey := strtran( cKey, lower(aFields[i]), cTbValue)

      // If a empty entry is found exit loop because seek arguments are to be respected
      // from the first to the last argument.
      // If one of them is empty the ones following the empty one have no sense any more.
      // The seek would be unsuccessful.
      else
         // substitut fieldname by ""
         //cKey := strtran( cKey, aFields[i], '""')
         //cKey := strtran( cKey, lower(aFields[i]), '""')
         exit
      endif

   next i

   // cut off non substituted seek arguments in KEY, why, see comment just above.
   if i-1 < len(aFields)
      cKey := substr( cKey, 1, Atnum("+", cKey, i-1)-1)
   endif

   // clear hole seek arg if first entry is empty
   if i == 1 .and. empty(cTbValue)
      cKey := ""
   endif

   // display it
   setproperty( cWinSeek, "tb_seekstr", "value", cKey )

   // debug
   //msginfo(cKey + crlf + &cKey)

return cKey


// Seek : clear all arguments
static function dv_seek_clear(aFields, aColVis)

   local i, temp, cFtype

   // clear all "seek field controls"
   for i := 1 to len(aFields)

      // get type of field
      temp := Ascan( aColVis, { |a| a[DBS_NAME] == aFields[i] } )
      cFtype := aColVis[temp, DBS_TYPE]

      do case
         case cFtype == "C"
            setproperty(ThisWindow.name, "cs_" + aFields[i], "VALUE", "")
         case cFtype == "D"
            setproperty(ThisWindow.name, "cs_" + aFields[i], "VALUE", ctod("  /  /  ") )
         case cFtype == "N"
            setproperty(ThisWindow.name, "cs_" + aFields[i], "VALUE", 0)
         case cFtype == "L"
            setproperty(ThisWindow.name, "cs_" + aFields[i], "VALUE", .F.)
      end case

   next i

   // clear and display real seekstring
   setproperty(ThisWindow.name, "cb_UseModSeekExpr", "VALUE", .F.)
   *
   setproperty(ThisWindow.name, "tb_seekstr", "VALUE", "")
   setproperty(ThisWindow.name, "tb_seekstr", "ENABLED", .F.)

   // set focus to the first field control
   domethod(ThisWindow.name, "cs_" + aFields[1], "setfocus")


return nil


// set order scope
static function dv_scope(cWinname, cAction)

   LOCAL temp, r, c, c1, lRefresh := .T.
   LOCAL cTopExpr, cBottomExpr

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   Local bApply := { ||    // set scope
                           (cAlias)->(ordscope(TOPSCOPE, cTopExpr))
                           (cAlias)->(ordscope(BOTTOMSCOPE, cBottomExpr ))
                           // save scope expressions in the tbrowse cargo prop.
                           temp := getproperty(cWinname,"CARGO")
                           temp[dvc_ScopeTop]    := cTopExpr
                           temp[dvc_ScopeBottom] := cBottomExpr
                           setproperty(cWinname, "CARGO", temp)
                           // set / reset checkbox
                           Setproperty(cWinname, "cb_ordscope_yn","Value", .T.)
                           // goto top and refresh browse
                           o_Browse:GoPos((cAlias)->(DBGOTOP()))
                           o_Browse:refresh()
                           return nil
                   }

   // construct at each entry a unique form id name so that multiple search forms can be opened.
   local f_scope := 'f_scope_' + cWinname       // cWinname is already a unique form ID

   // Retrieve current scope expressions from cargo
   // This scope is not necessary activated for the moment, see scope checkbox.
   cTopExpr    := getproperty(cWinname,"CARGO")[dvc_ScopeTop]     // DBORDERINFO(DBOI_SCOPETOP)
   cBottomExpr := getproperty(cWinname,"CARGO")[dvc_ScopeBottom]  // DBORDERINFO(DBOI_SCOPEBOTTOM)

   // On change checkbox value
   // -------------------------
   if cAction == "ONOFF"

      // if SET
      if getproperty(ThisWindow.name, "cb_ordscope_yn","Value")

         // if any scope defined
         IF !empty(getproperty(cWinname,"CARGO")[dvc_ScopeTop]) .or. !empty(getproperty(cWinname,"CARGO")[dvc_ScopeBottom])

            // set  top / bottom scope
            (cAlias)->(ordscope(TOPSCOPE, cTopExpr))
            (cAlias)->(ordscope(BOTTOMSCOPE, cBottomExpr ))

         // no order scope defined
         else
            lRefresh := .F.
            Setproperty(cWinname, "cb_ordscope_yn","Value", .F.)
            // msginfo("There is no order scope defined.")
            // set a scope
            dv_scope(cWinname, "SET")
         endif

      // if reset
      else
         // clear top / bottom scope
         (cAlias)->(ordscope(TOPSCOPE, nil ))
         (cAlias)->(ordscope(BOTTOMSCOPE, nil ))

      endif

      if lRefresh
         // goto top on a scope change
         o_Browse:GoPos( (cAlias)->(DBGOTOP()))
         o_Browse:GoTop()
         // and refresh browse
         o_Browse:refresh()
         o_Browse:ResetVScroll( .T. )
      endif


   // Set scope expressions
   // ---------------------
   else

      // Set focus back to this form if it is already open
      if ISWINDOWDEFINED("'"+f_scope+"'")
         domethod( f_scope, "SETFOCUS")
         return nil
      endif

      // create form with controls for each fieldname used in the KEY for user input
      define window &f_scope ;
      AT getproperty(cWinname,"Row")+250, getproperty(cWinname,"Col")+250 ;
      clientarea 450, 185 ;
      TITLE 'OTIS - Define order scope for alias : ' + cAlias ;
      BACKCOLOR th_w_bgcolor ;
      NOSIZE ;
      NOMINIMIZE ;
      NOMAXIMIZE ;
      WINDOWTYPE STANDARD

         // background controls
         DEFINE LABEL bg_scope
            ROW    th_w_ctrlgap
            COL    th_bt_width + th_w_ctrlgap * 2
            WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 3
            HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2
            VISIBLE .T.
         END LABEL
         // frame around, looks nicer
         define FRAME fr_scope
            row    getproperty(ThisWindow.name, "bg_scope","row")
            col    getproperty(ThisWindow.name, "bg_scope","col") + 1
            width  getproperty(ThisWindow.name, "bg_scope","width") - 1
            Height getproperty(ThisWindow.name, "bg_scope","Height")
         end frame

         // row, col start position for controls
         r := th_w_ctrlgap * 3
         c := th_w_ctrlgap * 3 + th_bt_width
         c1 := c + 75

         // display order tag name
         DEFINE LABEL Lb_tag1
            ROW    r
            COL    c
            WIDTH  90
            HEIGHT 24
            VALUE "Tag name"
            VISIBLE .T.
            VCENTERALIGN .T.
            AUTOSIZE .T.
         END LABEL
         DEFINE LABEL Lb_tag2
            ROW  r
            COL  c1
            WIDTH  200
            HEIGHT 24
            VALUE ORDNAME( ordnumber() )
            VISIBLE .T.
            VCENTERALIGN .T.
            AUTOSIZE .T.
         END LABEL

         // Top scope
         r += 24 + th_w_ctrlgap
         DEFINE LABEL lblFor
             ROW       r
             COL       c
             VALUE     "Top"
             AUTOSIZE .T.
         END LABEL
         *
         DEFINE EDITBOX edtTop
             ROW       r
             COL       c1
             WIDTH     getproperty(ThisWindow.name,"ClientWidth") - c1 - th_w_ctrlgap * 2
             HEIGHT    45
             VALUE     cTopExpr
             NOHSCROLLBAR .T.
             ONCHANGE  ( cTopExpr := AllTrim( getproperty(ThisWindow.name,"edtTop","Value" ) ) )
         END EDITBOX

         // Bottom scope
         r += 32 + 30
         DEFINE LABEL lblBottom
             ROW       r
             COL       c
             VALUE     "Bottom"
             AUTOSIZE .T.
         END LABEL
         *
         DEFINE EDITBOX edtBottom
             ROW       r
             COL       c1
             WIDTH     getproperty(ThisWindow.name,"ClientWidth") - c1 - th_w_ctrlgap * 2
             HEIGHT    45
             VALUE     cBottomExpr
             NOHSCROLLBAR .T.
             ONCHANGE  ( cBottomExpr := AllTrim( getproperty(ThisWindow.name,"edtBottom","Value" ) ) )
         END EDITBOX

         // button : Scope APPLY
         DEFINE label lb_ordapply
            ROW th_w_ctrlgap
            COL th_w_ctrlgap
            WIDTH th_bt_width
            HEIGHT th_bt_height
            FONTBOLD .T.
            Value " Apply"
            VCENTERALIGN .T.
            //CENTERALIGN .T.
            VISIBLE .T.
            ACTION Eval( bApply )
            FONTCOLOR th_bt_fontcol
            BACKCOLOR th_bt_bgcol
            ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
            ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
         END label

         // button : Scope RELEASE
         DEFINE label lb_ordrelease
            ROW th_w_ctrlgap + (th_bt_height + th_w_ctrlgap) * 1
            COL th_w_ctrlgap
            WIDTH th_bt_width
            HEIGHT th_bt_height
            FONTBOLD .T.
            Value " Release"
            VCENTERALIGN .T.
            //CENTERALIGN .T.
            VISIBLE .T.
            ACTION { || Setproperty(cWinname, "cb_ordscope_yn","Value", .F.), ;
                        (cAlias)->(ordscope(TOPSCOPE, nil)), ;
                        (cAlias)->(ordscope(BOTTOMSCOPE, nil)), ;
                        o_Browse:GoPos((cAlias)->(DBGOTOP())), ;
                        o_Browse:refresh() ;
                   }
            FONTCOLOR th_bt_fontcol
            BACKCOLOR th_bt_bgcol
            ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
            ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

         END label

         // button : Scope CLEAR
         DEFINE label lb_ordclear
            ROW th_w_ctrlgap + (th_bt_height + th_w_ctrlgap) * 2
            COL th_w_ctrlgap
            WIDTH th_bt_width
            HEIGHT th_bt_height
            FONTBOLD .T.
            Value " Clear"
            VCENTERALIGN .T.
            //CENTERALIGN .T.
            VISIBLE .T.
            ACTION { || Setproperty(ThisWindow.name, "edtTop","Value", ""), ;
                        Setproperty(ThisWindow.name, "edtBottom","Value", ""), ;
                        temp := getproperty(cWinname,"CARGO"), ;
                        temp[dvc_ScopeTop]    := cTopExpr, ;
                        temp[dvc_ScopeBottom] := cBottomExpr, ;
                        setproperty(cWinname, "CARGO", temp), ;
                        (cAlias)->(ordscope(TOPSCOPE, cTopExpr)), ;
                        (cAlias)->(ordscope(BOTTOMSCOPE, cBottomExpr )), ;
                        Setproperty(cWinname, "cb_ordscope_yn","Value", .F.), ;
                        o_Browse:GoPos((cAlias)->(DBGOTOP())), ;
                        o_Browse:refresh() ;
                   }
            FONTCOLOR th_bt_fontcol
            BACKCOLOR th_bt_bgcol
            ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
            ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                              setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

         END label

         // Quit button
         DEFINE LABEL bt_Quit
            ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
            COL th_w_ctrlgap
            WIDTH th_bt_width
            HEIGHT th_bt_height
            FONTBOLD .T.
            Value "Quit"
            VCENTERALIGN .T.
            CENTERALIGN .T.
            VISIBLE .T.
            ACTION { || ThisWindow.Release, domethod(cWinname,'SETFOCUS') }
            FONTCOLOR th_bt_ohfontcol
            BACKCOLOR th_bt_ohbgcol
         END label

         // Escape Key
         ON KEY ESCAPE ACTION This.bt_Quit.OnClick   // ThisWindow.Release

      end window

      // activate window
      ACTIVATE WINDOW &f_scope

   endif

return nil


/*
// verify Top and Bottom expressions
static function dv_scope2(cTop, cBottom)

   local lOk := .T.

   // test if TOP is a valid expression
   IF !Empty( cTop )
      Try
         lOk := ( ValType( &cTop ) $ "CDNL" )
      catch oError
         lOk := .F.
         MsgStop("Scope TOP expression error :" + crlf + crlf + ;
                ErrorMessage(oError) )
         RETURN lOk
      END
   ENDIF

   // test if BOTTOM is a valid expression
   IF !Empty( cBottom )
      Try
         lOk := ( ValType( &cBottom ) $ "CDNL" )
      catch oError
         lOk := .F.
         MsgStop("Scope BOTTOM expression error :" + crlf + crlf + ;
                ErrorMessage(oError) )
         RETURN lOk
      END
   ENDIF

return lOk
*/

// Goto top, record, bottom
static function dv_goto(cWinname)

   // construct at each entry a unique form id name so that multiple forms can be opened.
   LOCAL f_goto := 'f_goto_' + cWinname       // cWinname is already a unique form ID

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // Set focus back to this form if it is already open
   if ISWINDOWDEFINED("'"+f_goto+"'")
      domethod( f_goto, "SETFOCUS")
      return nil
   endif

   // form
   define window &f_goto ;
      AT getproperty(cWinname,"Row")+250, getproperty(cWinname,"Col")+400 ;
      clientarea th_w_ctrlgap * 3 + th_bt_width * 2, th_w_ctrlgap * 6 + th_bt_height * 4 ;
      TITLE 'OTIS - ' + cAlias ;
      WINDOWTYPE STANDARD ;
      BACKCOLOR th_w_bgcolor ;
      ;//TOPMOST ;
      NOSIZE ;
      NOMINIMIZE ;
      NOMAXIMIZE

      // Goto TOP
      DEFINE LABEL bt_top
         ROW th_w_ctrlgap + ( th_bt_height + th_w_ctrlgap) * 0
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Top"
         //Value " First"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION { || o_Browse:GoTop(), o_Browse:refresh(),;
                     ThisWindow.release,;
                     o_Browse:SetFocus() }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
      END label

      // Goto record
      DEFINE LABEL bt_record
         ROW th_w_ctrlgap + ( th_bt_height + th_w_ctrlgap) * 1
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Goto recno"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION dv_goto2(cWinname)
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
      END label
      // record number
      DEFINE TEXTBOX txb_recno
         ROW th_w_ctrlgap + ( th_bt_height + th_w_ctrlgap) * 1 + ( th_bt_height - 24 )
         COL th_bt_width + th_w_ctrlgap * 2
         WIDTH  th_bt_width
         HEIGHT 24
         NUMERIC .T.
         ON ENTER dv_goto2(cWinname)
         FONTNAME pu_fontname
         FONTSIZE pu_fontsize
         VALUE NIL
      END TEXTBOX

      // Goto Bottom
      DEFINE LABEL bt_bottom
         ROW th_w_ctrlgap + ( th_bt_height + th_w_ctrlgap) * 2
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Bottom"
         //Value " Last"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION { || o_Browse:GoBottom(), o_Browse:refresh(),;
                     ThisWindow.release,;
                     o_Browse:SetFocus() }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
      END label

      // Quit button
      DEFINE LABEL bt_Quit
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Quit"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         ACTION {|| ThisWindow.release, domethod(cWinname, "SETFOCUS")}
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      END label

      // Escape Key
      ON KEY ESCAPE ACTION This.bt_Quit.onclick

   end window

   // activate window
   ACTIVATE WINDOW &f_goto

return nil

//
static function dv_goto2(cWinname)

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )

   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   local lGoto := .F.
   local nRecord := getproperty("f_goto_"+cWinname,"txb_recno","Value")

   // GoBottom if recno to goto > number of records
   if nRecord > (cAlias)->( reccount() )
      nRecord := (cAlias)->( DBGOBOTTOM() )
   endif

   // if recno to goto <> 0
   if nRecord <> 0
      o_Browse:GoToRec( nRecord, .T.)
      //o_Browse:SetFocus()
      lGoto := .T.
   endif

return lGoto


// add / insert n records.
static function dv_ai_rec(cWinname)

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // construct at each entry a unique form id name so that multiple search forms can be opened.
   LOCAL f_ai := 'f_ai_' + cWinname    // cWinname is already a unique form ID

   // Set focus back to this form if it is already open
   if ISWINDOWDEFINED("'"+f_ai+"'")
      domethod( f_ai, "SETFOCUS")
      return nil
   endif

   // create form
   define window &f_ai ;
   AT getproperty(cWinname,"Row")+250, getproperty(cWinname,"Col")+250 ;
   clientarea th_bt_width * 2 + th_w_ctrlgap * 3, th_bt_height * 3 + th_w_ctrlgap * 5 ;
   TITLE 'OTIS - alias : ' + cAlias ;
   WINDOWTYPE STANDARD ;
   BACKCOLOR th_w_bgcolor ;
   ;//TOPMOST ;
   NOSIZE ;
   NOMINIMIZE ;
   NOMAXIMIZE

      // Add
      DEFINE LABEL bt_add
         ROW th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Add"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION {|| hb_ForNext( 1, getproperty(f_ai, "sp_nbrrec", "Value"), { || (cAlias)->(DBAPPEND()) } ), ;
                    o_Browse:GoToRec( (cAlias)->( reccount() ) ), o_Browse:SetFocus() }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
      END label

      // Insert
      DEFINE LABEL bt_insert
         ROW th_w_ctrlgap +  ( th_bt_height + th_w_ctrlgap ) * 1
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Insert"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         ACTION {|| db_insert(cWinname, cAlias, getproperty(f_ai, "sp_nbrrec", "Value")),;
                    db_reindexall(cWinname, cAlias), ;
                    o_Browse:refresh(), o_Browse:SetFocus() }
         // (cAlias)->(dbInsert( , getproperty(f_ai, "sp_nbrrec", "Value") )), ;
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
      END label

      // number of records to add / insert
      DEFINE SPINNER sp_nbrrec
         ROW th_w_ctrlgap + ( th_bt_height * 2 + th_w_ctrlgap) / 2 - 24 / 2
         COL th_bt_width + th_w_ctrlgap * 2
         WIDTH  th_bt_width
         HEIGHT 24
         VALUE 1
         RANGEMIN 1
         RANGEMAX 65535
         FONTNAME pu_fontname
         FONTSIZE pu_fontsize
      END SPINNER

      // Quit
      DEFINE LABEL bt_QUit
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Quit"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         VISIBLE .T.
         ACTION {|| ThisWindow.Release, domethod(cWinname, "SETFOCUS") }
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      END label

      // Escape Key
      ON KEY ESCAPE ACTION This.bt_Quit.onclick

      // Disable 'Insert' key if table use is not EXCLUSIVE
      if (cAlias)->(DBINFO(DBI_SHARED))
         msginfo("Insertion is impossible."+crlf+;
                 "The table is not opened in EXCLUSIVE mode.")
         // try to reopen in excl. mode
         // and enable/disbale insert key
         setproperty(ThisWindow.name, "bt_insert", "Enabled", dv_reopen_excl(cWinname))
      endif

   end window

   // activate window
   ACTIVATE WINDOW &f_ai

return nil

// copy / paste a record
static function dv_cp_rec(cWinname, cAction, lAllFields)

   local i

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // Default copy/paste only visible columns (= fields)
   // set it to .T. if you want that all data is copied independent of column visibility
   default lAllFields := .F.

   // copy record to copypaste buffer
   if cAction == "C"

      // get list of all fields
      aCopyPaste := {}
      for i := 4 to o_browse:nColCount()   // from 4 because 3 first cols are no fieldnames
         if o_browse:aColumns[i]:lVisible .or. lAllFields
            aadd( aCopyPaste, o_browse:aColumns[i]:cField )
         endif
      next i

      // get data from those fields
      for i := 1 to len(aCopyPaste)
         aCopyPaste[i] := { aCopyPaste[i], (cAlias)->(Fieldget(Fieldpos(aCopyPaste[i]))) }
      next i

      // debug
      /*
      temp := ""
      for i := 1 to len(aCopyPaste)
         temp += aCopyPaste[i,1] + " " + XtoC( aCopyPaste[i,2]) + crlf
      next i
      msgstop(temp)
      */

   endif

   // paste from copypaste buffer to the current record
   if cAction == "P"

      // if there is something to paste
      if len(aCopyPaste) <> 0

         // lock record
         if getproperty(cWinname, "cb_filelock_yn","Value") .or. (cAlias)->(dbrlock())

            TRY
               // paste fields found in copy paste array to the current record
               for i := 1 to len(aCopyPaste)
                  (cAlias)->( FieldPut( Fieldpos(aCopyPaste[i,1]), aCopyPaste[i,2] ) )
               next i

               // unlock table only if we did not place a temporary filelock before
               if !getproperty(cWinname, "cb_filelock_yn","Value")
                  (cAlias)->(dbunlock())
               endif

               // refresh tbrowse
               o_Browse:refresh()

            CATCH oERROR
               MsgStop("Paste error :" + crlf + crlf + ;
                          ErrorMessage(oError) ;
                      )
            END

         // error message, record not locked
         else
            msgstop("Paste aborted, record could not be locked.")
         endif

      // there is nothing to paste
      else
         msginfo("There is nothing to paste.")
      endif

   endif

return nil


// clear a record
static function dv_clrec(cWinname)

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // try to clear the record
   try
      // lock the record
      if getproperty(cWinname, "cb_filelock_yn","Value") .or. (cAlias)->(dbrlock())

         // clear data in record
         db_clrrec(cAlias)
         // refresh tbrowse
         o_Browse:refresh()

         // unlock table only if we did not place a temporary filelock before
         if !getproperty(cWinname, "cb_filelock_yn","Value")
            (cAlias)->(dbunlock())
         endif

      endif

   catch oError
      MsgStop("Record clear error :" + crlf + crlf + ;
               ErrorMessage(oError) )
   end

return nil


// Duplicate a record
// ATTENTION it duplicates ony data in function of column visibility
//           see details dv_cp_rec()
static function dv_du_rec(cWinname)

   local lOk := .T., nRecno

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // Verify if file is opened in exclusive mode
   if (cAlias)->(DBINFO(DBI_SHARED))
      msginfo("Duplication is impossible."+crlf+;
              "The table is not opened in EXCLUSIVE mode.")
      // try to reopen exclusive
      lOk := dv_reopen_excl(cWinname)
   endif

   // duplicate
   If lOk
      // copy record
      dv_cp_rec(cWinname, 'C')
      // insert a new one
      db_insert(cWinname, cAlias)
      // save pos
      nRecno := (cAlias)->(Recno())
      // reindex, dbinsert() does not update the index files.
      db_reindexall(cWinname, cAlias)
      // restore pos
      (cAlias)->(DBGOTO(nRecno))
      // paste record
      dv_cp_rec(cWinname, "P")
      // place cursor on the new duplicate line (in reality the old one that is pushed down)
      o_Browse:GoDown()

   endif

return nil


// Push physically down or pull up a record
static function dv_pupd_rec(cWinname, cAction)

   local nRecno, aCopyRec1, aCopyRec2, lDelRec1, lDelRec2

   // define skip direction
   local nSkip := if(cAction=="D", 1, -1)

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // only possible if there is no order actif
   if (cAlias)->(ordnumber()) == 0

      // Only if up or down and not on the last record
      if nSkip < 0 .or. ( nSkip > 0 .and. (cAlias)->(Recno()) < (cAlias)->(Reccount()) )

         // try
         TRY
            // save pos
            nRecno := (cAlias)->(Recno())

            // copy record
            dv_cp_rec(cWinname, 'C', .T.)
            // save data
            aCopyRec1 := aCopyPaste
            // save deleted record status
            lDelRec1 := (cAlias)->(DELETED())

            // skip up / down
            (cAlias)->( DBSKIP(nSkip) )

            // get copy of the new position
            dv_cp_rec(cWinname, 'C', .T.)
            // save data
            aCopyRec2 := aCopyPaste
            // save deleted record status
            lDelRec2 := (cAlias)->(DELETED())
            // fill public copy/paste array with data of 1st record
            aCopyPaste := aCopyRec1
            // paste record 1 into 2
            dv_cp_rec(cWinname, "P")
            // set/reset deleted status
            dv_pupd_deleted(cWinname, cAlias, lDelRec1)

            // back to record that has to be moved up/down
            (cAlias)->(DBGOTO(nRecno))
            // fill public copy / paste array with data of 2nd record
            aCopyPaste := aCopyRec2
            // paste record 2 into 1
            dv_cp_rec(cWinname, "P")
            // set/reset deleted status
            dv_pupd_deleted(cWinname, cAlias, lDelRec2)

            // place tbrowse cursor on the moved record so you can easily
            //   repeat the same operation on the same record and data.
            if nSkip > 0
               o_Browse:GoDown()
            else
               o_Browse:GoUp()
            endif

         //
         Catch oError
            MsgStop("Move Up/Down of a record failed : " + crlf + crlf + ;
                       ErrorMessage(oError) ;
                   )
         end

      endif

   // message, only poss if no order actif
   else
      msginfo("Push down / Pull up a record is only" + crlf + ;
              "possible if there is no order actif.")
   endif

return nil

// change deleted() status of a record
static function dv_pupd_deleted(cWinname, cAlias, lDelStatus)

   // lock record
   if getproperty(cWinname, "cb_filelock_yn","Value") .or. (cAlias)->(dbrlock())

      // change
      if( lDelStatus, (cAlias)->( DBDELETE() ), (cAlias)->( DBRECALL() ) )

      // unlock table only if we did not place a temporary filelock before
      if !getproperty(cWinname, "cb_filelock_yn","Value")
         (cAlias)->(dbunlock())
      endif

   endif

return nil


// delete / recall records extended version with a scope FOR and WHILE clause
static function dv_dr_rec(cWinname)

   local f_dre, r, c, c1
   local cFor := "", cWhile := "", nScope := 3, nNextRecords := 1

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // construct at each entry a unique form id name so that multiple search forms can be opened.
   f_dre := 'f_dre_' + cWinname       // cWinname is already a unique form ID

   // Set focus back to this form if it is already open
   if ISWINDOWDEFINED("'"+f_dre+"'")
      domethod( f_dre, "SETFOCUS")
      return nil
   endif

   // define form
   DEFINE WINDOW &f_dre ;
      AT getproperty(cWinname,"Row")+150, getproperty(cWinname,"Col")+300 ;
      clientarea 450, 200 ;
      TITLE 'OTIS - Delete / Recall extended wizard for alias : ' + cAlias ;
      BACKCOLOR th_w_bgcolor ;
      NOSIZE ;
      NOMAXIMIZE ;
      NOMINIMIZE ;
      WINDOWTYPE STANDARD

      // background controls
      DEFINE LABEL bg_sere
         ROW    th_w_ctrlgap
         COL    th_bt_width + th_w_ctrlgap * 2
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 3
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2
         VISIBLE .T.
      END LABEL
      // frame around, looks nicer
      define FRAME fr_seek
         ROW    th_w_ctrlgap
         COL    th_bt_width + th_w_ctrlgap * 2 + 1
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 3 - 1
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2
      end frame

      // row, col start position for controls
      r := th_w_ctrlgap * 2
      c := th_w_ctrlgap * 3 + th_bt_width
      c1 := c + 75

      // Table
      DEFINE LABEL Label_1
         ROW    r
         COL    c
         WIDTH  60
         HEIGHT 21
         VALUE "Table (alias)"
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL
      // Alias
      DEFINE LABEL Label_11
         ROW    r
         COL    c1
         WIDTH  240
         HEIGHT 21
         VALUE cAlias
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL

      // Scope
      r += 28
      DEFINE LABEL Lb_scope
         ROW    r
         COL    c
         WIDTH  60
         HEIGHT 21
         VALUE "Scope"
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL
      *
      DEFINE RADIOGROUP Rd_Scope
         ROW   r
         COL   c1
         WIDTH 55
         HORIZONTAL .T.
         OPTIONS { "All", "Rest", "Next" }
         VALUE nScope
         ONCHANGE { || nScope := This.Value, ;
                       iif( nScope < 3, setproperty(ThisWindow.name,"sp_nextrecords","Enabled",.F.), setproperty(ThisWindow.name,"sp_nextrecords","Enabled",.T.) ) }
         TABSTOP .T.
      END RADIOGROUP
      // Scope NEXT : number of records
      DEFINE SPINNER sp_nextrecords
         ROW r
         COL c1 + getproperty(ThisWindow.name,"Rd_Scope","Width") * 3 + th_w_ctrlgap
         WIDTH  55
         HEIGHT 22
         VALUE nNextRecords
         RANGEMIN 0
         RANGEMAX 65535
         FONTNAME pu_fontname
         FONTSIZE pu_fontsize
         ONCHANGE { || nNextRecords := getproperty(ThisWindow.name,"sp_nextrecords","Value") }
      END SPINNER

      // For
      r += 30
      DEFINE LABEL lblFor
          ROW       r
          COL       c
          VALUE     "For"
          AUTOSIZE .T.
      END LABEL
      *
      DEFINE EDITBOX edtFor
          ROW       r
          COL       c1
          WIDTH     getproperty(ThisWindow.name,"ClientWidth") - c1 - th_w_ctrlgap * 2
          HEIGHT    45
          VALUE     cFor
          NOHSCROLLBAR .T.
          ONCHANGE  ( cFor := AllTrim( getproperty(ThisWindow.name,"edtFor","Value" ) ) )
      END EDITBOX

      // While
      r += 30 + 30
      DEFINE LABEL lblWhile
          ROW       r
          COL       c
          VALUE     "While"
          AUTOSIZE .T.
      END LABEL
      *
      DEFINE EDITBOX edtWhile
          ROW       r
          COL       c1
          WIDTH     getproperty(ThisWindow.name,"ClientWidth") - c1 - th_w_ctrlgap * 2
          HEIGHT    45
          VALUE     cFor
          NOHSCROLLBAR .T.
          ONCHANGE  ( cWhile := AllTrim( getproperty(ThisWindow.name,"edtWhile","Value" ) ) )
      END EDITBOX

      // button : Delete
      DEFINE label bt_delete
         ROW th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Delete"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || dv_dr_2('D', cWinname, cFor, cWhile, nScope, nNextRecords ), ;
                     o_Browse:refresh() }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

      END label

      // button : Recall
      DEFINE label bt_recall
         ROW th_w_ctrlgap +  ( th_bt_height + th_w_ctrlgap ) * 1
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Recall"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || dv_dr_2( 'R', cWinname, cFor, cWhile, nScope, nNextRecords ), ;
                     o_Browse:refresh() }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

      END label

      // Quit button (allways on the bottom )
      DEFINE LABEL bt_Quit
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Quit"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || ThisWindow.Release, domethod(cWinname, "SETFOCUS") }
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      END label

      // escape key action
      ON KEY ESCAPE ACTION This.bt_Quit.OnClick

   end window

   ACTIVATE WINDOW &f_dre

return nil


// Action delete / recall extended
static function dv_dr_2( cAction, cWinname, cFor, cWhile, nScope, nNextRecords )

   LOCAL bExpr, nRecno, nOldsel
   LOCAL lOk := .T.

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // Warning if deleted option is activated
   if Set( _SET_DELETED)
      MsgInfo("WARNING"+crlf+crlf + ;
              "Deleted records are not displayed because"+crlf + ;
              "option 'Hide Deleted' is activated.")
   endif

   // save the current area nr
   nOldsel := SELECT()

   // select area
   select(cAlias)

   // test if For is a valid expression
   IF !Empty( cFor )
      Try
         lOk := ( ValType( &cFor ) == "L" )
      catch oError
         lOk := .F.
         MsgStop("FOR expression error :" + crlf + crlf + ;
                ErrorMessage(oError) )
         select (nOldsel)
         RETURN lOk
      END
   ENDIF

   // test if WHILE is a valid expression
   IF !Empty( cWhile )
      Try
         lOk := ( ValType( &cWhile ) == "L" )
      catch oError
         lOk := .F.
         MsgStop("WHILE expression error :" + crlf + crlf + ;
                  ErrorMessage(oError) )
         select (nOldsel)
         RETURN lOk
      END
   ENDIF

   // save current recno
   nRecno := Recno()

   // build codeblock in function of cAction
   bExpr := if( cAction == "D", "{|| dbDelete() }", "{|| dbRecall() }" )
   bExpr := &bExpr

   // All conditions are OK, so delete / recall records now
   // syntax used : dbEval( {|| dbDelete() }, <{for}>, <{while}>, <next>, <rec>, <.rest.> )
   //                       {|| dbrecall() }
   if dv_db_action( "DR", cWinname, bExpr, cFor, cWhile, nScope, nNextRecords )

      // go back to start recno
      dbGoTo( nRecno )

      // goto the new browse position if NEXT is used for the scope
      //  only if deleted records are shown
      if nScope == 3 .and. !Set( _SET_DELETED)
         o_browse:Skip(nNextRecords)
      endif

   endif

   // restore prev area
   select (nOldsel)

return nil


// Pack / zap a table
//
// Args  : cAction = "PACK" or "ZAP"
//
static function dv_pack_zap(cWinname, cAction)

   local lOk := .T., lTemp, nReccount, nSecStart

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // only if file was opened EXCLUSIVE (thus not shared)
   if (cAlias)->(DBINFO(DBI_SHARED))

      // error message, not open in exclusive mode
      msgstop("Impossible, the table was not opened in EXCLUSIVE mode.")
      // try to reopen exclusive
      lOK := dv_reopen_excl( cWinname )

   endif

   // ok the table is (re)opened in exclusive mode
   if lOk

      // ask confirmation
      PlayExclamation()
      if msgOkCancel(if( cAction=="PACK", "Pack table alias : ", "Delete all records, ZAP table alias : ") + cAlias)

         lTemp := .T.
         if cAction == "ZAP"
            PlayExclamation()
            lTemp := msgOkCancel("You have chosen to DELETE (ZAP) all data in alias : " + cAlias + crlf + ;
                                 "This operations is not reversible and all data will be lost." + crlf + crlf + ;
                                 "PLEASE CONFIRM.", "Otis", , , 2)
         endif

         if lTemp
            if cAction == "PACK"

               // save reccount and start time
               nReccount := (cAlias)->(reccount())
               nSecStart := seconds()

               WAIT WINDOW ("One moment please, PACK in progress of alias : " + cAlias + ".") NOWAIT
               CursorWait()
               do events

               // pack
               (cAlias)->(__DBPack())

               CursorArrow()
               WAIT CLEAR
               do events

               // message
               msginfo("Pack table " + cAlias + " has finished in " + hb_ntos(seconds()-nSecStart) + " sec." + crlf + crlf + ;
                       "Number of records deleted : " + hb_ntos(nReccount - (cAlias)->(reccount()) ) ;
                      )

               // set focus back to tbrowse because WAIT WINDOW set the focus the main window
               domethod(cWinname, "SETFOCUS")

            elseif cAction == "ZAP"
               (cAlias)->(__DBZap())
            endif

            // number of records has possibly changed
            // ...reload table info
            aOtables := otis_get_area_info()
            // ...refresh dataset tbrowse array
            tb_Otis:SetArray( aOtables )
            tb_Otis:refresh()

         endif

         // refresh browse
         o_Browse:GoTop()
         o_Browse:refresh()
         o_Browse:SetFocus()

      endif

   endif

return nil


// append a file
static function dv_append_file(cWinname)

   //
   local cFilename, nRecno

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // select a file
   // only one file can be selected
   //                        acFilter ,                                     cTitle,            cDefaultPath , lMultiSelect , lNoChangeDir , nIndex
   cFilename := Getfile( { {'Dbf Files','*.DBF'}, {'All Files','*.*'}  } , 'Append DBF file(s)' , ini_lu_folder, .F. ,         .t. )

   // if any file selected
   if !empty(cFilename)

      // append (with error trapping)
      TRY
         // save position
         nRecno := (cAlias)->(RECNO())

         // append file
         WAIT WINDOW ("One moment please, APPEND table in progress, " + cAlias + ".") NOWAIT
         CursorWait()
         do events

         //__dbApp( cFilename, , iif( Empty( cCond ), NIL, hb_macroBlock( cCond ) ), , , , .F., rddSetDefault() )
         (cAlias)->(__dbApp( cFilename))

         CursorArrow()
         WAIT CLEAR
         do events

         // set focus back to tbrowse because WAIT WINDOW set the focus the main window
         domethod(cWinname, "SETFOCUS")

         // reposition
         (cAlias)->(dbGoTo(nRecno))

         // refresh browse
         o_Browse:GoToRec(nRecNo)
         o_Browse:setfocus()
         o_Browse:Refresh()
         o_Browse:ResetVScroll( .T. )
         // and set min max range
         o_Browse:oVScroll:SetRange( 1, ordKeyCount())


      CATCH oError
         MsgStop("OTIS can not append table <"+ alltrim(cFilename) +">."+ crlf + crlf + ;
                 ErrorMessage(oError) )
      end

   endif

return nil


//***********************************************************************************************************************************
//
// Code below is borrowed from "DBFVIEW" from "Grigory Filatov".
// You can find the original code in folder \MiniGUI\SAMPLES\Applications\DBFview.
//
// Parts of it are modified to allow integration in OTIS.
//
//***********************************************************************************************************************************

*------------------------------------------------------------------------------*
Static function dv_Search_Replace( lReplace, cWinname )
*------------------------------------------------------------------------------*

   Local aColumns, r, c

   // tbrowse object of caller form (remember we can open multiple viewers)
   LOCAL o_Browse

   // unique form name / per caller form
   local f_sr

   MEMVAR lFirstFind, ;
         lFind, ;
         cFind, ;
         cFindStr, ;
         cField, ;
         cAlias, ;
         cReplStr, ;
         nCurRec
   Private lFirstFind := .T., ;
           lFind := .T., ;
           cFind := "", ;
           cFindStr, ;
           cField, ;
           cAlias, ;
           cReplStr, ;
           nCurRec

   // construct at each entry a unique form id name so that multiple search forms can be opened.
   f_sr := 'f_sr_' + cWinname       // cWinname is already a unique form ID

   // Set focus back to this form if it is already open
   if ISWINDOWDEFINED("'"+f_sr+"'")
      domethod( f_sr, "SETFOCUS")
      return nil
   endif

   // default : search only
   DEFAULT lReplace := .f.

   // // get tbrowse object from caller form (remember we can open multiple viewers)
   o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get area used in tbrowse
   cAlias := (o_browse:cAlias)

   // At first entry set order to 0 if field to search / replace is a index KEY component.
   /*
   *if lFirstFind .and. nField == 1

      // if order is not 0 set it to 0
      if (cAlias)->(ORDNUMBER()) <> 0
         // message
         Msgstop("Search / Replace is only possible if there is no order selected."+crlf+;
                   "The order number will be set to 0 to continue.")
         // change index combobox
         setproperty(cWinname,"cb_sel_index","Value",1)

         // and change order in tbrowse
         dv_change_order( cWinname )

      endif

   *endif
   */

   //msgstop(cAlias)

   // Init DBF fieldnames array with default option
   aColumns := { "<all columns>" }
   // and add all dbf fieldnames
   Aeval( (cAlias)->( DBstruct() ), {|e| Aadd(aColumns, e[1])})

   // define form
   DEFINE WINDOW &f_sr ;
      AT getproperty(cWinname,"Row")+250, getproperty(cWinname,"Col")+250 ;
      clientarea 460, 240 ;
      ;//TITLE IF(lReplace, "Replace", "Search") ;
      TITLE 'OTIS - Search / Replace wizard for alias : ' + cAlias ;
      BACKCOLOR th_w_bgcolor ;
      ON INIT { || This.Combo_1.DisplayValue := "", This.Combo_2.DisplayValue := "", This.Combo_1.Setfocus } ;
      NOSIZE ;
      NOMAXIMIZE ;
      NOMINIMIZE ;
      ;//TOPMOST ;
      WINDOWTYPE STANDARD

      // background controls
      DEFINE LABEL bg_sere
         ROW    th_w_ctrlgap
         COL    th_bt_width + th_w_ctrlgap * 2
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 3
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2
         VISIBLE .T.
      END LABEL
      // frame around, looks nicer
      define FRAME fr_seek
         ROW    th_w_ctrlgap
         COL    th_bt_width + th_w_ctrlgap * 2 + 1
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 3 - 1
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2
      end frame


      // row, col start position for controls
      r := th_w_ctrlgap * 2
      c := th_w_ctrlgap * 3 + th_bt_width

      // Table
      DEFINE LABEL Label_1
         ROW    r
         COL    c
         WIDTH  60
         HEIGHT 21
         VALUE "Table (alias)"
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL
      // Alias
      DEFINE LABEL Label_11
         ROW    r
         COL    c + 83
         WIDTH  240
         HEIGHT 21
         VALUE cAlias
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL

      // look for
      r += 32
      DEFINE LABEL Label_2
         ROW    r
         COL    c
         WIDTH  60
         HEIGHT 21
         VALUE "Look for"
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL
      // combobox look for
      DEFINE COMBOBOX Combo_1
         ROW    r - 2
         COL    c + 83
         ITEMS aSearch
         VALUE nSearch
         WIDTH 240
         DISPLAYEDIT .T.
         ON DISPLAYCHANGE ( lFirstFind := .T., This.bt_next.Enabled := !Empty(This.Combo_1.DisplayValue) )
         ON CHANGE ( lFirstFind := .T., This.bt_next.Enabled := .T. )
         VISIBLE .T.
      END COMBOBOX

      // Replace with
      r += 34
      DEFINE LABEL Label_3
         ROW    r
         COL    c
         WIDTH  80
         HEIGHT 18
         VALUE "Replace with"
         VISIBLE lReplace
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL
      // combobox "replace with"
      DEFINE COMBOBOX Combo_2
         ROW   r - 2
         COL   c + 83
         ITEMS aReplace
         VALUE nReplace
         WIDTH 240
         DISPLAYEDIT .T.
         ON DISPLAYCHANGE ( This.bt_repl.Enabled := !Empty(This.Combo_1.DisplayValue) .AND. !Empty(This.Combo_2.DisplayValue), ;
            This.bt_replall.Enabled := !Empty(This.Combo_1.DisplayValue) .AND. !Empty(This.Combo_2.DisplayValue) )
         ON CHANGE ( This.bt_repl.Enabled := .t., This.bt_replall.Enabled := .t. )
         VISIBLE lReplace
      END COMBOBOX

      r += 42
      DEFINE FRAME Frame_1
         ROW    r
         COL    c
         WIDTH  98
         HEIGHT 100
         CAPTION "Direction"
         FONTBOLD .T.
         OPAQUE .T.
      END FRAME

      r += 20
      DEFINE RADIOGROUP Radio_1
         ROW   r
         COL   c + 10
         OPTIONS { "Forward", "Backward", "Entire scope" }
         VALUE nDirect
         WIDTH 82
         ONCHANGE ( nDirect := This.Value, lFirstFind := .T. )
         TABSTOP .T.
      END RADIOGROUP

      r -= 20
      DEFINE LABEL Label_4
         ROW    r
         COL    c + 120
         WIDTH  85
         HEIGHT 18
         VALUE "Search in"
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL

      DEFINE COMBOBOX Combo_3
         ROW   r
         COL   c + 203
         ITEMS aColumns
         VALUE nColumns
         WIDTH 120
         ON CHANGE lFirstFind := .T.
      END COMBOBOX

      r += 43
      DEFINE CHECKBOX Check_1
         ROW   r
         COL   c + 120
         WIDTH  200
         CAPTION "Match &case"
         VALUE lMatchCase
         ON CHANGE lFirstFind := .T.
      END CHECKBOX

      r += 24
      DEFINE CHECKBOX Check_2
         ROW   r
         COL   c + 120
         WIDTH  200
         CAPTION "Match &whole word only"
         VALUE lMatchWhole
         ON CHANGE lFirstFind := .T.
      END CHECKBOX

      // button : Find next
      DEFINE label bt_next
         ROW th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "&Search Next"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         VISIBLE .T.
         ACTION dv_sr_FindNext(cWinname, This.Combo_1.DisplayValue, This.Combo_3.Value, ;
                               This.Check_1.Value, This.Check_2.Value)
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

      END label

      // Quit button (allways on the bottom )
      DEFINE LABEL bt_Quit
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Quit"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         VISIBLE .T.
         ACTION ThisWindow.Release
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      END label

      // button : Replace
      DEFINE LABEL bt_repl
         ROW th_w_ctrlgap + ( th_bt_height + th_w_ctrlgap ) * 1
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value IF(lReplace, "&"+"Replace", "&Replace...")
         VCENTERALIGN .T.
         CENTERALIGN .T.
         VISIBLE .T.
         /*ACTION IF(lReplace, DoReplace(o_Browse, This.Combo_1.DisplayValue, This.Combo_2.DisplayValue, ;
                             This.Combo_3.Value, This.Check_1.Value, This.Check_2.Value ), ;
                             ( This.bt_repl.Caption := "&"+"Replace", This.bt_repl.Enabled := .f., ;
                             This.bt_replall.Visible := .t., This.bt_replall.Enabled := .f., This.Label_3.Visible := .t., ;
                             This.Combo_2.Visible := .t., ThisWindow.Title := "Replace", This.Combo_1.Setfocus, lReplace := .t. ))
         */
         // more readable as above
         ACTION { ||
                  IF lReplace
                     dv_sr_DoReplace(cWinname, This.Combo_1.DisplayValue, This.Combo_2.DisplayValue, This.Combo_3.Value, This.Check_1.Value, This.Check_2.Value, .F. )
                  else
                     This.bt_repl.Caption := "&"+"Replace"
                     This.bt_repl.Enabled := .f.
                     This.bt_replall.Visible := .t.
                     This.bt_replall.Enabled := .f.
                     This.Label_3.Visible := .t.
                     This.Combo_2.Visible := .t.
                     ThisWindow.Title := "Replace"
                     This.Combo_1.Setfocus
                     lReplace := .t.
                  endif
                  return nil
                }

         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
      END label

      // button : Replace All
      DEFINE LABEL bt_replall
         ROW th_w_ctrlgap + ( th_bt_height + th_w_ctrlgap ) * 2
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Replace &All"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         VISIBLE lReplace
         ACTION dv_sr_DoReplace(cWinname, This.Combo_1.DisplayValue, This.Combo_2.DisplayValue, ;
                                This.Combo_3.Value, This.Check_1.Value, This.Check_2.Value, .t. )
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}
      END label

      // key actions
      ON KEY RETURN ACTION IF(lReplace, This.bt_repl.OnClick, This.bt_next.OnClick )
      ON KEY ESCAPE ACTION This.bt_Quit.OnClick

      setproperty(ThisWindow.name, "bt_next", "Enabled", .f.)
      setproperty(ThisWindow.name, "bt_repl", "Enabled", !lReplace)
      setproperty(ThisWindow.name, "bt_replall", "Enabled", !lReplace)

   END WINDOW

   //CENTER WINDOW &f_sr
   ACTIVATE WINDOW &f_sr

Return nil


*------------------------------------------------------------------------------*
Static function dv_sr_FindNext(cWinname, cString, nField, lCase, lWhole )
*------------------------------------------------------------------------------*

   MEMVAR lFind, ;
      cFind, ;
      cFindStr, ;
      lFirstFind, cField

   // get tbrowse object from caller form (remember we can open multiple viewers)
   LOCAL o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )

   // get alias from this tbrowse
   LOCAL cAlias := o_Browse:cAlias

   // load dbf structure
   Local aColumns := (cAlias)->( DBstruct() )

   // save current record pos.
   Local nRecno := (cAlias)->( RecNo() ), cType

   // return if no search string specified
   IF EMPTY(cString)
      Return nil

   // add to last used
   ELSEIF ASCAN(aSearch, cString) == 0
      AADD(aSearch, cString)
      This.Combo_1.AddItem(cString)
   ENDIF

   //
   IF !EMPTY(nField)
      nColumns := nField
   ENDIF

   // init case and whole word flags
   lMatchCase := lCase
   lMatchWhole := lWhole

   // init
   lFind := .T.

   // all columns
   IF nField == 1

      cFind := ""

      // first find
      IF lFirstFind

         lFirstFind := .F.

         // scope ALL
         IF nDirect == 3
            (cAlias)->( DbGotop() )
            DO WHILE !(cAlias)->( EoF() )
               cFindStr := IF(lCase, ALLTRIM(cString), UPPER(ALLTRIM(cString)))
               aColumns := (cAlias)->( Scatter() )
               Aeval(aColumns, {|x| cFind += XtoC(x) + " "})
               IF lCase
                  IF cFindStr $ cFind
                     EXIT
                  ENDIF
               ELSE
                  IF cFindStr $ UPPER(cFind)
                     EXIT
                  ENDIF
               ENDIF
               (cAlias)->( DbSkip() )
            ENDDO
            IF (cAlias)->( EoF() )
               lFind := .F.
               (cAlias)->( DbGoto(nRecno) )
               msginfo( "Can not find string"+' "'+cString+'"' )
            ENDIF
         // scope BACKWARD
         ELSEIF nDirect == 2
            (cAlias)->( DbSkip(-1) )
            DO WHILE !(cAlias)->( BoF() )
               cFindStr := IF(lCase, ALLTRIM(cString), UPPER(ALLTRIM(cString)))
               aColumns := (cAlias)->( Scatter() )
               Aeval(aColumns, {|x| cFind += XtoC(x) + " "})
               IF lCase
                  IF cFindStr $ cFind
                     EXIT
                  ENDIF
               ELSE
                  IF cFindStr $ UPPER(cFind)
                     EXIT
                  ENDIF
               ENDIF
               (cAlias)->( DbSkip(-1) )
            ENDDO
            IF (cAlias)->( BoF() )
               lFind := .F.
               (cAlias)->( DbGoto(nRecno) )
               msginfo( "Can not find string"+' "'+cString+'"' )
            ENDIF
         // scope FORWARD
         ELSEIF nDirect == 1
            (cAlias)->( DbSkip() )
            DO WHILE !(cAlias)->( EoF() )
               cFindStr := IF(lCase, ALLTRIM(cString), UPPER(ALLTRIM(cString)))
               aColumns := (cAlias)->( Scatter() )
               Aeval(aColumns, {|x| cFind += XtoC(x) + " "})
               IF lCase
                  IF cFindStr $ cFind
                     EXIT
                  ENDIF
               ELSE
                  IF cFindStr $ UPPER(cFind)
                     EXIT
                  ENDIF
               ENDIF
               (cAlias)->( DbSkip() )
            ENDDO
            IF (cAlias)->( EoF() )
               lFind := .F.
               (cAlias)->( DbGoto(nRecno) )
               msginfo( "Can not find string"+' "'+cString+'"' )
            ENDIF
         ENDIF

      // next finds
      ELSEIF lFind

         // skip in function of scope
         IF nDirect == 2
            (cAlias)->( DbSkip(-1) )
         ELSE
            (cAlias)->( DbSkip() )
         ENDIF

         DO WHILE !IF(nDirect = 2, (cAlias)->( BoF() ), (cAlias)->( EoF() ))
            cFindStr := IF(lCase, ALLTRIM(cString), UPPER(ALLTRIM(cString)))
            aColumns := (cAlias)->( Scatter() )
            Aeval(aColumns, {|x| cFind += XtoC(x) + " "})
            IF lCase
               IF cFindStr $ cFind
                  EXIT
               ENDIF
            ELSE
               IF cFindStr $ UPPER(cFind)
                  EXIT
               ENDIF
            ENDIF
            IF nDirect == 2
               (cAlias)->( DbSkip(-1) )
            ELSE
               (cAlias)->( DbSkip() )
            ENDIF
         ENDDO
         IF (cAlias)->( EoF() ) .OR. (cAlias)->( BoF() )
            lFind := .F.
            (cAlias)->( DbGoto(nRecno) )
            msginfo( "There are no records anymore!" )
         ENDIF
      ENDIF

   // only in a specific field
   ELSE
      cField := aColumns[nField-1][1]
      cType  := aColumns[nField-1][2]

      // search only in field types C,N,D
      IF cType $ "CND"

         // field type = 'C'
         IF cType == "C"

            // find WHOLE WORD ==
            IF lWhole
               cFindStr := cString
               cFind := "ALLTRIM((cAlias)->((&cField)))==M->cFindStr"

            // find CONTAINS $
            ELSE
               cFindStr := IF(lCase, ALLTRIM(cString), UPPER(ALLTRIM(cString)))
               IF lCase
                  cFind := "M->cFindStr $ (cAlias)->((&cField))"
               ELSE
                  cFind := "M->cFindStr $ UPPER((cAlias)->((&cField)))"
               ENDIF
            ENDIF

         // field type = 'N'
         ELSEIF cType == "N"
            cFindStr := VAL(cString)
            cFind := "(cAlias)->((&cField))=M->cFindStr"
            cFind := "(cAlias)->((&cField))=M->cFindStr"

         // field type = 'D'
         ELSEIF cType == "D"
            cFindStr := CTOD(cString)
            cFind := "(cAlias)->((&cField))=M->cFindStr"
         ENDIF

         IF lFirstFind
            lFirstFind := .F.
            // scope ALL
            IF nDirect == 3
               (cAlias)->( __dbLocate({||(&cFind)},,,,.F.) )
               IF (cAlias)->( EoF() )
                  lFind := .F.
                  (cAlias)->( DbGoto(nRecno) )
                  msginfo( "Can not find string"+' "'+cString+'"' )
               ENDIF
            // scope BACKWARD
            ELSEIF nDirect == 2
               (cAlias)->( DbSkip(-1) )
               DO WHILE !(cAlias)->( BoF() )
                  IF &cFind
                     EXIT
                  ENDIF
                  (cAlias)->( DbSkip(-1) )
               ENDDO
               IF (cAlias)->( BoF() )
                  lFind := .F.
                  (cAlias)->( DbGoto(nRecno) )
                  msginfo( "Can not find string"+' "'+cString+'"' )
               ENDIF
            // scope FORWARD
            ELSEIF nDirect == 1
               (cAlias)->( DbSkip() )
               (cAlias)->( __dbLocate({||(&cFind)},,,,.T.) )
               IF (cAlias)->( EoF() )
                  lFind := .F.
                  (cAlias)->( DbGoto(nRecno) )
                  msginfo( "Can not find string"+' "'+cString+'"' )
               ENDIF
            ENDIF

         ELSEIF lFind

            // scope BACKWARD
            IF nDirect == 2
               (cAlias)->( DbSkip(-1) )
               DO WHILE !(cAlias)->( BoF() )
                  IF &cFind
                     EXIT
                  ENDIF
                  (cAlias)->( DbSkip(-1) )
               ENDDO

            // scope ALL & FORWARD
            ELSE
               (cAlias)->( __dbContinue() )
            ENDIF

            IF (cAlias)->( EoF() ) .OR. (cAlias)->( BoF() )
               lFind := .F.
               (cAlias)->( DbGoto(nRecno) )
               msginfo( "There are no records anymore!" )
            ENDIF
         ENDIF
      ENDIF
   ENDIF

   // update tbrowse
   o_Browse:GoToRec( (cAlias)->( RecNo() ) )
   o_Browse:refresh()
   //o_Browse:SetFocus()

Return Nil

*------------------------------------------------------------------------------*
Static function dv_sr_DoReplace(cWinname, cString, cReplace, nField, lCase, lWhole, lAll )
*------------------------------------------------------------------------------*

   MEMVAR lFind, ;
         cFind, ;
         cFindStr, ;
         cField, ;
         cAlias, ;
         cReplStr, ;
         nCurRec

   Local aColumns := (cAlias)->( DBstruct() ), cType, cFld, i, lReplace
   Local nRecno := (cAlias)->( RecNo() )

   // get tbrowse object from caller form (remember we can open multiple viewers)
   LOCAL o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )

   DEFAULT lAll := .f.

   // return if no arguments
   IF EMPTY(cString) .OR. EMPTY(cReplace)
      Return nil

   // add args to last used
   ELSEIF ASCAN(aReplace, cReplace) == 0
      AADD(aReplace, cReplace)
      This.Combo_2.AddItem(cString)
   ENDIF


   // replace with error trapping
   TRY

      // scope ALL
      IF lAll

         IF ASCAN(aSearch, cString) == 0
            AADD(aSearch, cString)
            This.Combo_1.AddItem(cString)
         ENDIF

         // all fields
         IF nField == 1
            IF nDirect == 3
               (cAlias)->( DbGotop() )
               DO WHILE !(cAlias)->( EoF() )
                  aColumns := (cAlias)->( Scatter() )
                  For i := 1 To Len(aColumns)
                     cFld := aColumns[i]
                     IF cType == "N"
                        lReplace := ( cFld = VAL(cString) )
                        IF lReplace
                           (cAlias)->&cField := VAL(cReplace)
                        ENDIF
                     ELSEIF cType == "D"
                        lReplace := ( cFld = CTOD(cString) )
                        IF lReplace
                           (cAlias)->&cField := CTOD(cReplace)
                        ENDIF
                     ELSEIF Valtype( cFld ) == "C"
                        IF lWhole
                           lReplace := ( cFld == cString )
                        ELSE
                           IF lCase
                              lReplace := cString $ cFld
                           ELSE
                              lReplace := UPPER(cString) $ UPPER(cFld)
                           ENDIF
                        ENDIF
                        IF lReplace
                           IF getproperty(cWinname, "cb_filelock_yn","Value") .or. (cAlias)->(dbrlock())
                              cField := (cAlias)->( Field(i) )
                              (cAlias)->&cField := STRTRAN(cFld, cString, cReplace)
                           ENDIF
                           // unlock table only if we did not place a temporary filelock before
                           if !getproperty(cWinname, "cb_filelock_yn","Value")
                              (cAlias)->(dbunlock())
                           endif
                        ENDIF
                     ENDIF
                  Next
                  (cAlias)->( DbSkip() )
               ENDDO
               (cAlias)->( DbGoto(nRecno) )
            ELSEIF nDirect == 2
               (cAlias)->( DbSkip(-1) )
               DO WHILE !(cAlias)->( BoF() )
                  aColumns := (cAlias)->( Scatter() )
                  For i := 1 To Len(aColumns)
                     cFld := aColumns[i]
                     IF cType == "N"
                        lReplace := ( cFld = VAL(cString) )
                        IF lReplace
                           (cAlias)->&cField := VAL(cReplace)
                        ENDIF
                     ELSEIF cType == "D"
                        lReplace := ( cFld = CTOD(cString) )
                        IF lReplace
                           (cAlias)->&cField := CTOD(cReplace)
                        ENDIF
                     ELSEIF Valtype( cFld ) == "C"
                        IF lWhole
                           lReplace := ( cFld == cString )
                        ELSE
                           IF lCase
                              lReplace := cString $ cFld
                           ELSE
                              lReplace := UPPER(cString) $ UPPER(cFld)
                           ENDIF
                        ENDIF
                        IF lReplace
                           IF getproperty(cWinname, "cb_filelock_yn","Value") .or. (cAlias)->(dbrlock())
                              cField := (cAlias)->( Field(i) )
                              (cAlias)->&cField := STRTRAN(cFld, cString, cReplace)
                           ENDIF
                           // unlock table only if we did not place a temporary filelock before
                           if !getproperty(cWinname, "cb_filelock_yn","Value")
                              (cAlias)->(dbunlock())
                           endif
                        ENDIF
                     ENDIF
                  Next
                  (cAlias)->( DbSkip(-1) )
               ENDDO
               (cAlias)->( DbGoto(nRecno) )
            ELSEIF nDirect == 1
               (cAlias)->( DbSkip() )
               DO WHILE !(cAlias)->( EoF() )
                  aColumns := (cAlias)->( Scatter() )
                  For i := 1 To Len(aColumns)
                     cFld := aColumns[i]
                     IF cType == "N"
                        lReplace := ( cFld = VAL(cString) )
                        IF lReplace
                           (cAlias)->&cField := VAL(cReplace)
                        ENDIF
                     ELSEIF cType == "D"
                        lReplace := ( cFld = CTOD(cString) )
                        IF lReplace
                           (cAlias)->&cField := CTOD(cReplace)
                        ENDIF
                     ELSEIF Valtype( cFld ) == "C"
                        IF lWhole
                           lReplace := ( cFld == cString )
                        ELSE
                           IF lCase
                              lReplace := cString $ cFld
                           ELSE
                              lReplace := UPPER(cString) $ UPPER(cFld)
                           ENDIF
                        ENDIF
                        IF lReplace
                           IF getproperty(cWinname, "cb_filelock_yn","Value") .or. (cAlias)->(dbrlock())
                              cField := (cAlias)->( Field(i) )
                              (cAlias)->&cField := STRTRAN(cFld, cString, cReplace)
                           ENDIF
                           // unlock table only if we did not place a temporary filelock before
                           if !getproperty(cWinname, "cb_filelock_yn","Value")
                              (cAlias)->(dbunlock())
                           endif
                        ENDIF
                     ENDIF
                  Next
                  (cAlias)->( DbSkip() )
               ENDDO
               (cAlias)->( DbGoto(nRecno) )
            ENDIF

         // only in a specific field
         ELSE
            cField := aColumns[nField-1][1]
            cType := aColumns[nField-1][2]
            IF nDirect == 3
               (cAlias)->( DbGotop() )
               IF getproperty(cWinname, "cb_filelock_yn","Value") .or. (cAlias)->(Flock())
                  cReplStr := cReplace
                  cFindStr := ALLTRIM(cString)
                  IF cType == "N"
                     (cAlias)->( DBEval({||(cAlias)->&(cField) := VAL(cReplStr)},{||(cAlias)->&(cField)=VAL(cFindStr)},,,,.F.) )
                  ELSEIF cType == "D"
                     (cAlias)->( DBEval({||(cAlias)->&(cField) := CTOD(cReplStr)},{||(cAlias)->&(cField)=CTOD(cFindStr)},,,,.F.) )
                  ELSE
                     IF lWhole
                        (cAlias)->( DBEval({||(cAlias)->&(cField) := STRTRAN((cAlias)->&(cField), cFindStr, cReplStr)},{||(cAlias)->&(cField) == M->cFindStr},,,,.F.) )
                     ELSE
                        IF lCase
                           (cAlias)->( DBEval({||(cAlias)->&(cField) := STRTRAN((cAlias)->&(cField), cFindStr, cReplStr)},{||M->cFindStr $ (cAlias)->&(cField)},,,,.F.) )
                        ELSE
                           (cAlias)->( DBEval({||(cAlias)->&(cField) := STRTRAN((cAlias)->&(cField), cFindStr, cReplStr)},{||UPPER(M->cFindStr) $ UPPER((cAlias)->&(cField))},,,,.F.) )
                        ENDIF
                     ENDIF
                  ENDIF
               ENDIF
            ELSEIF nDirect == 2
               (cAlias)->( DbGotop() )
               IF getproperty(cWinname, "cb_filelock_yn","Value") .or. (cAlias)->(Flock())
                  nCurRec := nRecno
                  cReplStr := cReplace
                  cFindStr := ALLTRIM(cString)
                  IF cType == "N"
                     (cAlias)->( DBEval({||(cAlias)->&(cField) := VAL(cReplStr)},{||(cAlias)->&(cField)=VAL(cFindStr)},{||(cAlias)->( Recno() )<nCurRec},,,.F.) )
                  ELSEIF cType == "D"
                     (cAlias)->( DBEval({||(cAlias)->&(cField) := CTOD(cReplStr)},{||(cAlias)->&(cField)=CTOD(cFindStr)},{||(cAlias)->( Recno() )<nCurRec},,,.F.) )
                  ELSE
                     IF lWhole
                        (cAlias)->( DBEval({||(cAlias)->&(cField) := STRTRAN((cAlias)->&(cField), cFindStr, cReplStr)},{||(cAlias)->&(cField) == M->cFindStr},{||(cAlias)->( Recno() )<nCurRec},,,.F.) )
                     ELSE
                        IF lCase
                           (cAlias)->( DBEval({||(cAlias)->&(cField) := STRTRAN((cAlias)->&(cField), cFindStr, cReplStr)},{||M->cFindStr $ (cAlias)->&(cField)},{||(cAlias)->( Recno() )<nCurRec},,,.F.) )
                        ELSE
                           (cAlias)->( DBEval({||(cAlias)->&(cField) := STRTRAN((cAlias)->&(cField), cFindStr, cReplStr)},{||UPPER(M->cFindStr) $ UPPER((cAlias)->&(cField))},{||(cAlias)->( Recno() )<nCurRec},,,.F.) )
                        ENDIF
                     ENDIF
                  ENDIF
               ENDIF
            ELSEIF nDirect == 1
               IF getproperty(cWinname, "cb_filelock_yn","Value") .or. (cAlias)->(Flock())
                  cReplStr := cReplace
                  cFindStr := ALLTRIM(cString)
                  IF cType == "N"
                     (cAlias)->( DBEval({||(cAlias)->&(cField) := VAL(cReplStr)},{||(cAlias)->&(cField)=VAL(cFindStr)},,,,.T.) )
                  ELSEIF cType == "D"
                     (cAlias)->( DBEval({||(cAlias)->&(cField) := CTOD(cReplStr)},{||(cAlias)->&(cField)=CTOD(cFindStr)},,,,.T.) )
                  ELSE
                     IF lWhole
                        (cAlias)->( DBEval({||(cAlias)->&(cField) := STRTRAN((cAlias)->&(cField), cFindStr, cReplStr)},{||(cAlias)->&(cField) == M->cFindStr},,,,.T.) )
                     ELSE
                        IF lCase
                           (cAlias)->( DBEval({||(cAlias)->&(cField) := STRTRAN((cAlias)->&(cField), cFindStr, cReplStr)},{||M->cFindStr $ (cAlias)->(&(cField))},,,,.T.) )
                        ELSE
                           (cAlias)->( DBEval({||(cAlias)->&(cField) := STRTRAN((cAlias)->&(cField), cFindStr, cReplStr)},{||UPPER(M->cFindStr) $ UPPER((cAlias)->&(cField))},,,,.T.) )
                        ENDIF
                     ENDIF
                  ENDIF
               ENDIF
            ENDIF
            // unlock table only if we did not place a temporary filelock before
            if !getproperty(cWinname, "cb_filelock_yn","Value")
               (cAlias)->(dbunlock())
            endif

            (cAlias)->( DbGoto(nRecno) )
         ENDIF

      // scope find & replace only one
      ELSE

         lFind := .T.
         // find next to replace
         dv_sr_FindNext(cWinname, cString, nField, lCase, lWhole )

         // find & replace only in 1 column
         IF nField == 1
            IF lFind
               aColumns := (cAlias)->( Scatter() )
               For i := 1 To Len(aColumns)
                  cFld := aColumns[i]
                  IF Valtype( cFld ) == "C"
                     IF lCase
                        lReplace := cString $ cFld
                     ELSE
                        lReplace := UPPER(cString) $ UPPER(cFld)
                     ENDIF
                     IF lReplace
                        IF getproperty(cWinname, "cb_filelock_yn","Value") .or. (cAlias)->(dbrlock())
                           cField := (cAlias)->( Field(i) )
                           (cAlias)->&cField := STRTRAN(cFld, cString, cReplace)
                        ENDIF
                        // unlock table only if we did not place a temporary filelock before
                        if !getproperty(cWinname, "cb_filelock_yn","Value")
                           (cAlias)->(dbunlock())
                        endif
                     ENDIF
                  ENDIF
               Next
            ENDIF

         // find & replace in all rows
         ELSE
            cField := aColumns[nField-1][1]
            cType := aColumns[nField-1][2]
            IF lFind .AND. cType $ "CND"
               IF getproperty(cWinname, "cb_filelock_yn","Value") .or. (cAlias)->(dbrlock())
                  IF cType == "N"
                     (cAlias)->&cField := VAL(cReplace)
                  ELSEIF cType == "D"
                     (cAlias)->&cField := CTOD(cReplace)
                  ELSE
                     (cAlias)->&cField := cReplace
                  ENDIF
               ENDIF
            ENDIF
            // unlock table only if we did not place a temporary filelock before
            if !getproperty(cWinname, "cb_filelock_yn","Value")
               (cAlias)->(dbunlock())
            endif
         ENDIF

      ENDIF


   // error catching
   catch oError

      MsgStop("Search & Replace error :" + crlf + crlf + ;
                ErrorMessage(oError) )
   end

   // update tbrowse
   o_Browse:GoToRec( (cAlias)->( RecNo() ) )
   o_Browse:refresh()
   //o_Browse:SetFocus()

Return NIL

//***********************************************************************************************************************************
//
// Basic Code idees below are borrowed from "mgDBU" from "Grigory Filatov".
// You can find the original code in folder C:\MiniGUI\UTILS\mgDBU\DBUEDIT.PRG
//
// Parts of it are modified, updated and improved with new options for integration in OTIS.
//
//***********************************************************************************************************************************

// Replace data ; extended version with EXPRESSION, FOR and WHILE options
static function dv_repl_ext(cWinname)

   local r, c, c1, aFields
   local cField, cValue := "", cExpr := "", cFor := "", cWhile := "", nScope := 3, nNextRecords := 1

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // construct at each entry a unique form id name so that multiple search forms can be opened.
   local f_sre := 'f_sre_' + cWinname       // cWinname is already a unique form ID

   // Set focus back to this form if it is already open
   if ISWINDOWDEFINED("'"+f_sre+"'")
      domethod( f_sre, "SETFOCUS")
      return nil
   endif

   // Init DBF fieldnames array
   aFields := { }
   Aeval( (cAlias)->( DBstruct() ), {|e| Aadd(aFields, e[1])})
   ASORT(aFields)
   cField := aFields[ 1 ]

   // define form
   DEFINE WINDOW &f_sre ;
      AT getproperty(cWinname,"Row")+150, getproperty(cWinname,"Col")+300 ;
      clientarea 450, 365 ;
      TITLE 'OTIS - Extended replace wizard for alias : ' + cAlias ;
      BACKCOLOR th_w_bgcolor ;
      NOSIZE ;
      NOMAXIMIZE ;
      NOMINIMIZE ;
      WINDOWTYPE STANDARD

      // background controls
      DEFINE LABEL bg_sere
         ROW    th_w_ctrlgap
         COL    th_bt_width + th_w_ctrlgap * 2
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 3
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2
         VISIBLE .T.
      END LABEL
      // frame around, looks nicer
      define FRAME fr_seek
         ROW    th_w_ctrlgap
         COL    th_bt_width + th_w_ctrlgap * 2 + 1
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_bt_width - th_w_ctrlgap * 3 - 1
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2
      end frame

      // row, col start position for controls
      r := th_w_ctrlgap * 2
      c := th_w_ctrlgap * 3 + th_bt_width
      c1 := c + 75

      // Table
      DEFINE LABEL Label_1
         ROW    r
         COL    c
         WIDTH  60
         HEIGHT 21
         VALUE "Table (alias)"
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL
      // Alias
      DEFINE LABEL Label_11
         ROW    r
         COL    c1
         WIDTH  240
         HEIGHT 21
         VALUE cAlias
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL

      // Field
      r += 32
      DEFINE LABEL Lb_field
         ROW    r
         COL    c
         WIDTH  60
         HEIGHT 21
         VALUE "Field"
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL
      *
      DEFINE COMBOBOX Combo_3
         ROW   r
         COL   c1
         WIDTH 120
         ITEMS aFields
         VALUE 1
         DISPLAYEDIT .T.
         ONCHANGE ( cField := getproperty(ThisWindow.name, "Combo_3", "Item", getproperty(ThisWindow.name,"Combo_3","Value")))
      END COMBOBOX

      // Scope
      r += 32
      DEFINE LABEL Lb_scope
         ROW    r
         COL    c
         WIDTH  60
         HEIGHT 21
         VALUE "Scope"
         VISIBLE .T.
         VCENTERALIGN .T.
         AUTOSIZE .F.
      END LABEL
      *
      DEFINE RADIOGROUP Rd_Scope
         ROW   r
         COL   c1
         WIDTH 55
         HORIZONTAL .T.
         OPTIONS { "All", "Rest", "Next" }
         VALUE nScope
         ONCHANGE { || nScope := This.Value, ;
                       iif( nScope < 3, setproperty(ThisWindow.name,"sp_nextrecords","Enabled",.F.), setproperty(ThisWindow.name,"sp_nextrecords","Enabled",.T.) ) }
         TABSTOP .T.
      END RADIOGROUP
      // Scope NEXT : number of records
      DEFINE SPINNER sp_nextrecords
         ROW r
         COL c1 + getproperty(ThisWindow.name,"Rd_Scope","Width") * 3 + th_w_ctrlgap
         WIDTH  55
         HEIGHT 22
         VALUE nNextRecords
         RANGEMIN 0
         RANGEMAX 65535
         FONTNAME pu_fontname
         FONTSIZE pu_fontsize
         ONCHANGE { || nNextRecords := getproperty(ThisWindow.name,"sp_nextrecords","Value") }
      END SPINNER

      // value
      r += 37
      DEFINE LABEL lblVal
          ROW       r
          COL       c
          VALUE     "Value"
          AUTOSIZE .T.
      END LABEL
      *
      DEFINE EDITBOX edtVal
          ROW       r
          COL       c1
          WIDTH     getproperty(ThisWindow.name,"ClientWidth") - c1 - th_w_ctrlgap * 2
          HEIGHT    45
          VALUE     cValue
          NOHSCROLLBAR .T.
          ONCHANGE     { || cValue := AllTrim( getproperty(ThisWindow.name,"edtVal","Value") ), ;
                         iif( empty(cValue), ,setproperty(ThisWindow.name,"edtExpr","Value", "" ) )   ;
                       }
          ONLOSTFOCUS  iif( Empty( cValue ), ,setproperty(ThisWindow.name,"edtExpr","Value", "" ) )
      END EDITBOX

      // expression
      r += 32 + 30
      DEFINE LABEL lblExpr
          ROW       r
          COL       c
          VALUE     "Expression"
          AUTOSIZE .T.
      END LABEL
      *
      DEFINE EDITBOX edtExpr
          ROW       r
          COL       c1
          WIDTH     getproperty(ThisWindow.name,"ClientWidth") - c1 - th_w_ctrlgap * 2
          HEIGHT    45
          VALUE     cExpr
          NOHSCROLLBAR .T.
          ONCHANGE     { || cExpr := AllTrim( getproperty(ThisWindow.name,"edtExpr","Value" ) ), ;
                            iif( empty(cExpr), ,setproperty(ThisWindow.name,"edtVal","Value", "" ) ) }
          ONLOSTFOCUS  iif( Empty( cExpr ), ,setproperty(ThisWindow.name,"edtVal","Value", "" ) )
      END EDITBOX

      // For
      r += 32 + 30
      DEFINE LABEL lblFor
          ROW       r
          COL       c
          VALUE     "For"
          AUTOSIZE .T.
      END LABEL
      *
      DEFINE EDITBOX edtFor
          ROW       r
          COL       c1
          WIDTH     getproperty(ThisWindow.name,"ClientWidth") - c1 - th_w_ctrlgap * 2
          HEIGHT    45
          VALUE     cFor
          NOHSCROLLBAR .T.
          ONCHANGE  ( cFor := AllTrim( getproperty(ThisWindow.name,"edtFor","Value" ) ) )
      END EDITBOX

      // While
      r += 32 + 30
      DEFINE LABEL lblWhile
          ROW       r
          COL       c
          VALUE     "While"
          AUTOSIZE .T.
      END LABEL
      *
      DEFINE EDITBOX edtWhile
          ROW       r
          COL       c1
          WIDTH     getproperty(ThisWindow.name,"ClientWidth") - c1 - th_w_ctrlgap * 2
          HEIGHT    45
          VALUE     cFor
          NOHSCROLLBAR .T.
          ONCHANGE  ( cWhile := AllTrim( getproperty(ThisWindow.name,"edtWhile","Value" ) ) )
      END EDITBOX

      // button : Replace
      DEFINE label bt_replace
         ROW th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Replace"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || dv_repl_ext2( cWinname, cField, cFor, cWhile, cValue, cExpr, nScope, nNextRecords ), ;
                     o_Browse:refresh() }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

      END label

      // Quit button (allways on the bottom )
      DEFINE LABEL bt_Quit
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Quit"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || ThisWindow.Release, domethod(cWinname, "SETFOCUS") }
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      END label

      // escape key action
      ON KEY ESCAPE ACTION This.bt_Quit.OnClick

   end window

   ACTIVATE WINDOW &f_sre

return nil

// replace data
static function dv_repl_ext2( cWinname, cField, cFor, cWhile, cValue, cExpr, nScope, nNextRecords )

   LOCAL cFtype, bExpr, nRecno, nOldsel
   LOCAL lOk := .T.

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // save the current area nr
   nOldsel := SELECT()

   // select area
   select(cAlias)

   //
   IF FieldPos( cField ) > 0 .AND. ( !Empty( cValue ) .OR. !Empty( cExpr ) )

      // KEY expression cleanup, it could be that the user used the 'enter' key
      //  delete crlf pairs and white space
      cExpr := alltrim(strtran(cExpr, crlf, ""))
      // test if EXPRESSION is a valid expression
      IF !Empty( cExpr )
         try
            &cExpr
         catch oError
            lOk := .F.
            MsgStop("EXPRESSION expression error :" + crlf + crlf + ;
                  ErrorMessage(oError) )
            select (nOldsel)
            RETURN lOk
         END
      ENDIF

      // FOR expression cleanup, it could be that the user used the 'enter' key
      //  delete crlf pairs and white space
      cFor := alltrim(strtran(cFor, crlf, ""))
      // test if For is a valid expression
      IF !Empty( cFor )
         Try
            lOk := ( ValType( &cFor ) == "L" )
         catch oError
            lOk := .F.
            MsgStop("FOR expression error :" + crlf + crlf + ;
                   ErrorMessage(oError) )
            select (nOldsel)
            RETURN lOk
         END
      ENDIF

      // WHILE expression cleanup, it could be that the user used the 'enter' key
      //  delete crlf pairs and white space
      cWhile := alltrim(strtran(cWhile, crlf, ""))
      // test if WHILE is a valid expression
      IF !Empty( cWhile )
         Try
            lOk := ( ValType( &cWhile ) == "L" )
         catch oError
            lOk := .F.
            MsgStop("WHILE expression error :" + crlf + crlf + ;
                     ErrorMessage(oError) )
            select (nOldsel)
            RETURN lOk
         END
      ENDIF

      // save current recno
      nRecno := Recno()

      // get field type
      cFtype := ValType( &cField )

      // build DBEVAL() codeblock string if a VALUE is specified
      IF !Empty( cValue )

         IF cFtype == "C"
            cValue := '"' + cValue + '"'
         elseif cFtype == "D"
            cValue := 'ctod("'+ cValue + '")'
         *elseif cFtype == "N"
         *   * do nothing
         *elseif cFtype == "L"
         *   * do nothing
         ENDIF
         bExpr := "{||_Field->"+cField+":="+cValue + "}"

      // build DBEVAL() codeblock string if a EXPRESSION is specified
      ELSE
          bExpr := "{||_Field->"+cField+":="+cExpr+"}"
      ENDIF

      // Convert codeblock string to a real codeblock
      try
         //msgstop(bExpr)
         bExpr := &bExpr
      catch oError
         lOk := .F.
         MsgStop("VALUE or EXPRESSION error :" + crlf + crlf + ;
                  ErrorMessage(oError) )
         select (nOldsel)
         RETURN lOk
      end

      // All conditions are OK, so replace data now
      //     remember syntax off DBEVAL( bBlock, [bFor], [bWhile], [nNextRecords], [nRecordnbr], [lRest] )
      if dv_db_action( "RE", cWinname, bExpr, cFor, cWhile, nScope, nNextRecords )

         // go back to start recno
         dbGoTo( nRecno )

         // goto the new browse position if NEXT is used for the scope
         if nScope == 3
            o_browse:Skip(nNextRecords)
         endif

      endif

      // restore area
      select (nOldsel)

   ENDIF

RETURN lOk


// Execute a action on a table in function of a codeblock, a SCOPE and a FOR and WHILE clause
// rem : the proper area must be active before calling this function.
static function dv_db_action( cAction, cWinname, bExpr, cFor, cWhile, nScope, nNextRecords )

   local lOk := .T., lRest

   // check if a file lock is placed or can be placed
   if getproperty(cWinname, "cb_filelock_yn","Value") .or. flock()

      // set scope
      lRest := if( nScope > 1, .T., .F.)

      // change cursor
      CursorWait()
      do events

      // do it
      TRY
         do case

            // no FOR
            // no WHILE
            case Empty( cFor ) .and. Empty( cWhile )
               // ALL or REST
               if nScope < 3
                  dbEval( bExpr, , , , , lRest )
               // n Records
               else
                  dbEval( bExpr, , , nNextRecords )
               endif

            // with FOR
            // no WHILE
            case !Empty( cFor ) .and. Empty( cWhile )
               // ALL or REST
               if nScope < 3
                  dbEval( bExpr, hb_macroBlock( cFor ), , , , lRest )
               // n Records
               else
                  dbEval( bExpr, hb_macroBlock( cFor ), , nNextRecords )
               endif

            // no FOR
            // with WHILE
            case Empty( cFor ) .and. !Empty( cWhile )
               // ALL or REST
               if nScope < 3
                  dbEval( bExpr, , hb_macroBlock( cWhile ), , , lRest )
               // n Records
               else
                  dbEval( bExpr, , hb_macroBlock( cWhile ), nNextRecords )
               endif

            // with FOR
            // with WHILE
            case !Empty( cFor ) .and. !Empty( cWhile )
               // ALL or REST
               if nScope < 3
                  dbEval( bExpr, hb_macroBlock( cFor ), hb_macroBlock( cWhile ), , , lRest )
               // n Records
               else
                  dbEval( bExpr, hb_macroBlock( cFor ), hb_macroBlock( cWhile ), nNextRecords )
               endif

         endcase

      // error message
      CATCH oERROR

         lOk := .F.
         MsgStop(if( cAction=="DR", "Delete / Recall error :", "Replace error :") + crlf + crlf + ;
                 ErrorMessage(oError) )
      end

      // restore cursor
      CursorArrow()
      do events

      // unlock table only if we did not place a temporary filelock before
      if !getproperty(cWinname, "cb_filelock_yn","Value")
         dbunlock()
      endif

   // no file lock, error message
   else
      msgstop("Operation on table is impossible."+crlf + ;
              "For some reason the table / record could not be locked.", "Otis" )
   endif

return lOk


// Set COLUMN VISIBILITY
Static Function dv_ColumnVis( cWinname, aColVis )

   local aTemp, i, f_vi

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // code blocks
   LOCAL bOK := {|| _HMG_DialogCancelled := !tb_Dv_Vis:lHasChanged, DoMethod( f_vi, 'Release' ) }
   LOCAL bSelAll    := { || AEval( aColVis, { |a| a[ 5 ] := .T. } ),     tb_Dv_Vis:lHasChanged := .T., tb_Dv_Vis:Refresh( .F. ) }
   LOCAL bUnSelAll  := { || AEval( aColVis, { |a| a[ 5 ] := .F. } ),     tb_Dv_Vis:lHasChanged := .T., tb_Dv_Vis:Refresh( .F. ) }
   LOCAL bRevSelAll := { || AEval( aColVis, { |a| a[ 5 ] := !a[ 5 ] } ), tb_Dv_Vis:lHasChanged := .T., tb_Dv_Vis:Refresh( .F. ) }

   // construct at each entry a unique form id name so that multiple search forms can be opened.
   f_vi := 'f_vi_' + cWinname       // cWinname is already a unique form ID

   // Set focus back to this form if it is already open
   if ISWINDOWDEFINED("'"+f_vi+"'")
      domethod( f_vi, "SETFOCUS")
      return nil
   endif

   // define form
   DEFINE WINDOW &f_vi ;
      AT getproperty(cWinname,"Row")+150, getproperty(cWinname,"Col")+300 ;
      clientarea 410, 515 ;
      TITLE 'OTIS - Column visibilty editor for alias : ' + cAlias ;
      BACKCOLOR th_w_bgcolor ;
      NOSIZE ;
      NOMAXIMIZE ;
      NOMINIMIZE ;
      WINDOWTYPE STANDARD

      // Tbrowse (with autocols)
      DEFINE TBROWSE tb_Dv_Vis  ;
         AT th_w_ctrlgap * 1, th_bt_width * 1 + th_w_ctrlgap * 2 ;
         WIDTH getproperty(ThisWindow.name,"ClientWidth") - th_bt_width * 1 -  th_w_ctrlgap * 3 ;
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_w_ctrlgap * 2 ;
         COLORS {CLR_BLACK, CLR_WHITE} ;
         SIZE 10 ;
         GRID

         // load array
         :SetArray( aColVis, .T. )

         :lNoHScroll   := .T.
         :lNoGrayBar   := .T.
         :lNoChangeOrd := .T.

         //:nHeightCell  += 2
         :nHeightHead  += 6      // :nHeightCell + GetBorderHeight() / 2
         // HEADER IN BOLD
         MODIFY TBROWSE tb_Dv_Vis HEADER FONT TO FontBold

         // cell margins, add one space left and right
         :nCellMarginLR := 1

         :nWheelLines  := 1
         :lNoMoveCols  := .T.
         :lNoResetPos  := .F.

         :SetColor( { 1, 2, 4, 5, 6 }, { ;
              CLR_BLACK, ;
              CLR_WHITE, ;
              { CLR_WHITE, RGB(210, 210, 220) }, ;
              CLR_WHITE, RGB(51, 153, 255) }, )

         :aColumns[ 5 ]:lEdit := .T.
         :aColumns[ 5 ]:lCheckBox := .T.
         :aColumns[ 5 ]:bLClicked := { |p1,p2,p3,o| p1 := aColVis[o:nAt][5], ;
                                       aColVis[o:nAt][5] := !p1, p2 := NIL,;
                                       p3 := NIL, o:lHasChanged := .T., ;
                                       o:DrawSelect(),;
                                       dv_Apply_ColVis( cWinname, aColVis ) }

         :aColumns[ 5 ]:nEditMove := DT_MOVE_DOWN
         :UserKeys(VK_SPACE, {|ob|
                             Local lRet
                             If ob:nCell == 5
                                ob:lHasChanged := .T.
                                ob:DrawSelect()
                                lRet := .F.
                             EndIf
                             dv_Apply_ColVis( cWinname, aColVis )
                             Return lRet
                           })

         // set header, width of columns and alignement
         aTemp := { { 110, DT_LEFT   , "Field Name" }, ;
                    { 040, DT_CENTER , "Type" }, ;
                    { 040, DT_RIGHT  , "Len " }, ;
                    { 040, DT_RIGHT  , "Dec "}, ;
                    { 035, DT_CENTER , "" };
                  }
         for i := 1 to len(aTemp)
            :aColumns[ i ]:cHeading := aTemp[i,3]
            :SetColSize( i, aTemp[i,1] )
            :aColumns[ i ]:nAlign  := aTemp[i,2]
            :aColumns[ i ]:nHAlign := aTemp[i,2]
         next i

         :ResetVScroll( .T. )
         :GoPos( 1, 5 )

         // Row Colors, fontcolor en/disabled, bg odd or even
         :SetColor( { 1, 2 }, { th_fctb_leven, {|nRow, nCol, oBrw| iif( nRow%2==0, th_bgtb_leven, th_bgtb_lodd )}} )

      end TBROWSE

      /*
      // button : Apply
      DEFINE label bt_apply
         ROW th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Apply"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         VISIBLE .T.
         ACTION dv_Apply_ColVis( cWinname, aColVis )
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

      END label
      */

      // button : Select all
      DEFINE label bt_selall
         ROW th_w_ctrlgap + ( th_bt_height + th_w_ctrlgap ) * 0
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Select All"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || Eval( bSelAll ), dv_Apply_ColVis( cWinname, aColVis ) }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

      END label

      // button : unselect all
      DEFINE label bt_uselall
         ROW th_w_ctrlgap + ( th_bt_height + th_w_ctrlgap ) * 1
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Unselect All"
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || Eval( bUnSelAll ), dv_Apply_ColVis( cWinname, aColVis ) }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

      END label

      // button : Reverse selection
      DEFINE label bt_revsel
         ROW th_w_ctrlgap +  ( th_bt_height + th_w_ctrlgap ) * 2
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value " Reverse Sel."
         VCENTERALIGN .T.
         //CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || eval( bRevSelAll ), dv_Apply_ColVis( cWinname, aColVis ) }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         ONMOUSEHOVER { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol)}
         ONMOUSELEAVE { || setproperty(ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol),;
                           setproperty(ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol)}

      END label

      // Quit button (allways on the bottom)
      DEFINE LABEL bt_Quit
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Quit"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         VISIBLE .T.
         ACTION { || ThisWindow.Release, domethod(cWinname, "SETFOCUS") }
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      END label

      // escape key action
      ON KEY ESCAPE ACTION This.bt_Quit.OnClick

   end window

   ACTIVATE WINDOW &f_vi

RETURN nil


// apply visib.
Static Function dv_Apply_ColVis( cWinname, aColVis )

   local i, lAllSel := .T.

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )

   // set show/hide for each tbrowse col
   For i := 1 To Len(aColVis)

      // i+3 because we display a selector, recordnr and deleted status in the first 3 cols.
      o_Browse:HideColumns( i+3, !aColVis[i][5] )

      // echo hide status of all cols to a flag
      if ! aColVis[i][5]
         lAllsel := .F.
      endif

   Next

   // set col visibility checkbox only of not all cols are selected
   setproperty(cWinname, "cb_colvis_yn", "Value", !lAllsel)

   // if all cols are displayed open also the colvis editor
   // it is also opened when you click on the label of the checkbox
   if lAllSel
      dv_ColumnVis( cWinname, aColVis )
   endif

return nil


// apply ALL visib. (used by checkbox to switch between ALL or only SELECTED col visibility)
Static Function dv_Apply_AllVis( cWinname, aColVis )

   local i

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )

   For i := 1 To Len(aColVis)
      o_Browse:HideColumns( i+3, .F. )       // i+3 because we display a selector, recordnr and deleted status in the first 3 cols.
   Next

return nil


// Reopen a table :
//   Only when in command line or on file double click mode or when
//   we want to change a codepage of a table that is already open.
//
//   in Shared / EXCLUSIVE (default) mode
//   and with Codepage (default is dataset setting)
//
//   used in cases where a operation like PACK,ZAP,... needs this mode
//   and the file was opened in a shared mode,
//   or when we want to change a codepage.
//    (i found no function to change codepage if table is already opened)
//    (only solution : close and reopen with new codepage.)
//
static function dv_reopen_excl( cWinname, lExclusive, cCodepg )

   local lReturn := .F.
   local nArea, cUsename, nRecno, cFilter, nOrdernr

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // defaults
   Default lExclusive := .T.
   Default cCodepg := ini_dbf_codepage


   // test if in standalone and command line mode
   if lStandalone .and. !empty(cCmdline)

      // ask if you want to try to reopen in exclusive mode
      if msgYesno("Do you want to try to reopen table "+cAlias+" in EXCLUSIVE mode ?")

         // get info from the file that was openend by a running program
         nArea    := SELECT()
         cUseName := (cAlias)->( Sx_Tablename() )            // full file/path name
         nRecno   := (cAlias)->(recno())
         cFilter  := (cAlias)->(DBINFO(DBI_DBFILTER))
         nOrdernr := (cAlias)->(INDEXORD())

         // try to
         TRY
            // reopen in exclusive mode
            select (nArea)
            if lExclusive
               USE (cUseName) ALIAS (cAlias) EXCLUSIVE CODEPAGE cCodepg
            else
               USE (cUseName) ALIAS (cAlias)           CODEPAGE cCodepg
            endif
            // set flag
            lReturn := .T.
            // restore order, recno, ....
            ORDSETFOCUS(nOrdernr)
            goto nRecno
            // restore filter
            if !empty(cFilter)
               //DbSetFilter( &("{||" + cFilter + "}" ), cFilter )
               o_browse:FilterData(cFilter)
               o_browse:ResetVscroll()
            endif

            // refresh tbrowse
            o_Browse:refresh()

            // set checkbox 'filelock'
            setproperty( cWinname, "cb_filelock_yn", "Value", .T.)

         Catch oError
            msgstop("Reopen alias "+ cAlias +" in EXCLUSIVE mode was impossible." +;
                    crlf+crlf+;
                    ErrorMessage(oError))
         end

      endif

   endif

return lReturn


// save table as
static function dv_save(cWinname)

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // get rdd to use
   local cRdd := getproperty("form_otis", "cb_defrdd","Item", getproperty( "form_otis", "cb_defrdd", "Value") )

   local i, cFilename, lOk := .T., cFieldList := "All", aSelected

   // if RDDxxx
   if cRdd <> 'LETO'
      //                        acFilter ,                                    cTitle,          cDefaultPath
      cFilename := Putfile( { {'Dbf Files','*.DBF'}, {'All Files','*.*'} } , 'Save DBF file' , hb_FNameDir(Sx_Tablename()) )

      // debug
      //msgstop(cFilename)

   // if RDD LetoDbf
   else
     aSelected := leto_putfile({ {'Dbf Files','*.DBF'}, {'All Files','*.*'} },'Save as', , .F.)
     cFilename := aSelected[1]
   endif

   // if a filename is specified
   if !empty(cFilename)

      // if the file exist, ask confirmation to replace it by the new file
      if file(cFilename)

         PlayExclamation()
         lOk := MsgYesNo("This file exists already."+crlf + crlf + ;
                         "Do you want to overwrite it ?","Save as")

      endif

      // if ok
      if lOk

         // message if control Deleted, Filter or Hide Columns is / are used
         show_msg_filters_used(cWinname)

         // build field list if option is activated
         if getproperty(cWinname, "cb_colvis_yn", "Value")

            cFieldlist := ""
            for i := 4 to o_browse:nColCount()   // from 4 because 3 first cols are no fieldnames
               if o_browse:aColumns[i]:lVisible
                  // dont use fieldname because cols in tbrowse can be moved/reordered by the user
                  // cFieldlist += (cAlias)->(FIELDNAME(i-3)) + ","
                  // get col object fieldname
                  cFieldlist += o_browse:aColumns[i]:cField + ","
               endif
            next i

            // remove last char ,
            cFieldlist := left( cFieldlist, len(cFieldlist)-1 )

            // debug
            //msgstop(cFieldlist)

         endif

         // copy to 'ppo code'
         //   copy to TEST.DBF CODEPAGE ini_dbf_codepage
         //    __dbCopy( "TEST.DBF", { }           ,        ,          ,       ,      , .F.     ,      , , FR850 )
         //    __dbCopy( <(f)>     , { <(fields)> }, <{for}>, <{while}>, <next>, <rec>, <.rest.>, <rdd>, , <cp> )
         try
            // with ALL fields
            if cFieldlist == "All"

               // if RDDxxx
               if cRdd <> 'LETO'
               // __dbCopy( "TEST.DBF", { }, , , , , .F., , , FR850 )
                  __DBCOPY( cFilename ,    , , , , ,    , , , ini_dbf_codepage)
               else
                  leto_DbCopy(cFilename,   , , , , ,    , , ,ini_dbf_codepage)
               endif

            // only with VISIBLE columns (=fields)
            elseif !empty(cFieldlist)
               //msgstop(cFieldlist)

               // if RDDxxx
               if cRdd <> 'LETO'
               // __dbCopy( "TEST.DBF", { }                        , , , , , .F., , , FR850 )
                  __DBCOPY( cFilename, hb_atokens( cFieldlist, ","), , , , ,    , , , ini_dbf_codepage )
               else
                  leto_dbcopy(cFilename, hb_atokens( cFieldlist, ","), , , , ,    , , , ini_dbf_codepage )
               endif

            // message, fieldlist is empty
            else
               msginfo("Nothing is saved because there are no fields selected.")
            endif

         Catch oError
            MsgStop("Save as error :" + crlf + crlf + ;
                     ErrorMessage(oError) )
         end

      endif

   endif

return nil


//
// Export DBf to a Csv file
//
static function dv_export(cWinname)

   // get tbrowse object from caller form (remember we can open multiple viewers)
   local o_Browse := GetBrowseObj( "tb_Dv_Browse", cWinname )
   // get alias name from tbrowse object
   local cAlias := o_Browse:cAlias

   // get rdd to use
   local cRdd := getproperty("form_otis", "cb_defrdd","Item", getproperty( "form_otis", "cb_defrdd", "Value") )

   local i, cFilename, lOk := .T., aFieldList

   // Get destination filename
   //                        acFilter ,                                      cTitle,        cDefaultPath              nochdir  def fn                                , nIndex, lOverwr
   cFilename := Putfile( { {'Csv Files','*.csv'}, {'All Files','*.*'} } , 'Save as CSV' , hb_FNameDir(Sx_Tablename()),        , hb_FNameExtSet(Sx_Tablename())+'.csv' )

   // if a filename is specified
   if !empty(cFilename)

      // if the file exist, ask confirmation to overwrite
      if file(cFilename)
         PlayExclamation()
         lOk := MsgYesNo("This file exists already."+crlf + crlf + ;
                         "Do you want to overwrite it ?","Save as")
      endif

      // if ok
      if lOk

         // message if control Deleted, Filter or Hide Columns is / are used
         show_msg_filters_used(cWinname)

         // build limited field list if option is activated
         if getproperty(cWinname, "cb_colvis_yn", "Value")

            aFieldlist := {}
            for i := 4 to o_browse:nColCount()   // from 4 because 3 first cols are no fieldnames
               if o_browse:aColumns[i]:lVisible
                  // dont use fieldname because cols in tbrowse can be moved/reordered by the user
                  // get col object fieldname
                  aadd(aFieldlist, o_browse:aColumns[i]:cField )
               endif
            next i

         endif

         // Export to a csv file
         SaveToCsv( cAlias, aFieldlist, cFilename )

      endif

   endif

return nil


// show message, filters are actif
static function show_msg_filters_used(cWinname)

   if getproperty(cWinname, "cb_filter", "Value") ;
      .or. ;
      getproperty(cWinname, "cb_deleted_yn", "Value") ;
      .or. ;
      getproperty(cWinname, "cb_colvis_yn", "Value") ;
      .or. ;
      getproperty(cWinname, "cb_ordscope_yn", "Value")

      msginfo("Warning, one or more option(s) :"+crlf+crlf+;
              "   Hide Deleted"+crlf+;
              "   Filter"+crlf+;
              "   Hide Columns" + crlf + ;
              "   Order Scope" + crlf + crlf + ;
              "are activated." +crlf+crlf+;
              "Only records and or fields that are visible are saved.")
   endif

return nil

//
// Export a dbf to a csv file
//
// Args : cAlias         dbf alias name
//        aColumns       array with column names to export, default all columns if not passed
//        cFile          Destination filename
//        cDelim         Csv delimiter, default ';'
//        lFromTop       set to .F. if to export from the current record position
//
// Rem  : 1. This function export data from top or from a certain recno(). (see arg. lFromTop)
//           The caller must thus keep care of the record position before calling this function.
//
//        2. MEMO FIELDS ARE REMOVED for export because they have no fixed structure.
//
// Example :
//        use C:\MiniGUI\SAMPLES\minigui_mysamples\Dbf2Csv\factven
//
//        all fields
//           SaveToCsv( Alias(), , hb_FNameExtSet(Sx_Tablename(), 'csv') )
//
//        some fields only
//           SaveToCsv( Alias(), {"NRFACT","JNLFACT","REFERCL"} , hb_FNameExtSet(Sx_Tablename(), 'csv') )
//
//        Some fields only and starting from record and another delimiter
//          goto 32000
//          SaveToCsv( Alias(), {"NRFACT","JNLFACT","REFERCL"} , hb_FNameExtSet(Sx_Tablename(), 'csv'), ':' , .F. )
//
Static function SaveToCsv( cAlias, aColumns, cFile, cDelim, lFromTop )

   local cWinName := "wn_export"

   memvar lAbort_export
   private lAbort_export := .F.

   // form
   DEFINE WINDOW &cWinName ;
      row 0 ;
      col 0 ;
      clientarea 350, 75 ;
      TITLE 'Export : ' + _GetCompactPath(sx_tablename() + '.csv', 45) ;
      WINDOWTYPE MODAL ;
      NOSIZE ;
      NOSYSMENU ;
      on init SaveToCsv_run(cWinName, cAlias, aColumns, cFile, cDelim, lFromTop ) ;
      ON RELEASE SaveToCsv_close()

      // progressbar
      @ 20, 25 PROGRESSBAR csv_PgBar ;
               RANGE 0, 100 ;
               WIDTH 300 HEIGHT 26 ;
               TOOLTIP "Progress"

      // escape to abort
      ON KEY ESCAPE ACTION ThisWindow.Release

   end window

   // activate window
   CENTER WINDOW &cWinName
   ACTIVATE WINDOW &cWinName

return .T.

// release export win
static function SaveToCsv_close()
   lAbort_export := .T.
   //msgdebug("stopped " , lAbort_export )
return .T.


// function : on init
Static function SaveToCsv_run(cWinname, cAlias, aColumns, cFile, cDelim, lFromTop )

   Local aTemp,;
         nFhandle, ;
         lReturn := .F.,;
         cBuffer := "",;
         nSeconds := seconds(), ;
         nPg_Barr_Step_Cnt, nPgbarr_refresh_cnt,;
         nExport_cnt := 0

   // save area
   local nOldSel := select()
   local nOldrecno := recno()

   // defaults
   default aColumns := {}
   default cDelim   := ";"
   default lFromTop := .T.

   // Create a new csv file
   // msgdebug(cFile)

   // if handle obtained
   if (nFhandle := FCreate(cFile)) > 0

      // select area
      select (cAlias)

      // from current record position or from top
      if lFromTop
         dbgotop()
      endif

      // progressbar step value
      nPg_Barr_Step_Cnt := ( reccount() - recno()) / 100
      nPgbarr_refresh_cnt := nPg_Barr_Step_Cnt

      // If no field list passed create array with all columns names
      if len(aColumns) == 0
         aColumns := DBstruct()
         //msgdebug(aColumns)
         // remove memo fields and keep only fieldnames
         aTemp := {}
         AEval( aColumns, { |a| if( a[2] <> "M", aadd(aTemp, a[1]), nil )  })
         aColumns := aTemp
      endif
      //msgdebug(aColumns)

      // write 'columns names' header on first line
      cBuffer := ""
      AEval( aColumns, { |a| cBuffer += a + cDelim } )
      cBuffer := remright(cBuffer, cDelim) + crlf
      FWRITE( nFhandle, cBuffer )

      // write data in function of columns list to export
      do while !eof() .and. !lAbort_export

         // export a record
         cBuffer := ""

         // no trimm
         //AEval( aColumns, { |a| cBuffer += hb_ValToStr(hb_fieldget(a)) + cDelim } )
         // alltrimm
         AEval( aColumns, { |a| cBuffer += alltrim(hb_ValToStr(hb_fieldget(a))) + cDelim } )

         cBuffer := remright( cBuffer, cDelim) + crlf
         FWRITE( nFhandle, cBuffer )

         // next record
         nExport_cnt++
         dbskip()

         // refresh progressbar
         nPgbarr_refresh_cnt--
         if nPgbarr_refresh_cnt <= 0
            setproperty(cWinname,"csv_PgBar","value", getproperty(cWinname,"csv_PgBar","value") + 1 )
            nPgbarr_refresh_cnt := nPg_Barr_Step_Cnt
            do events
         endif

      enddo

      //msgdebug("end loop")

      // close destination file
      FCLOSE(nFhandle)

      // restore area
      select (nOldSel)
      goto nOldrecno

      // set flag
      lReturn := .T.

   ENDIF

   // release main window
   if !lAbort_export

      // hide main window
      domethod( cWinname,"hide")

      // message end in xx sec.
      if lReturn
         msginfo("Exported " + hb_ntos(nExport_cnt) +  " records in " + hb_ntos(seconds() - nSeconds) + " sec.", "Export to csv")
      endif

      // close
      domethod( cWinname,"release")

   else
      msginfo("Export aborted", "Export to csv")

   endif

Return lReturn

//***********************************************************************************************************************************
//
// Some parts and idees of the structure editor below is borrowed from "MGDBU" from "Grigory Filatov".
//    You can find the original code in folder C:\MiniGUI\UTILS\mgDBU\MGDBU.PRG
//
// Parts of it are modified for integration in OTIS.
//    the visual part
//    added extended field types
//
//***********************************************************************************************************************************
   * Procedure ------------------------

// Structure Editor
//
// Mode  : If called from the 'Inspector' keyword "DV" is passed
//         In that case the structure of the current table under edit is loaded in the structure editor
//
Static function Struct_Editor(cWinname, mode)

   Local aButtons, r, c, i
   LOCAL aNames := { "Field Name", "Type", "Len", "Dec" }

   PUBLIC aStruct := {}

   // defaults
   Default cWinname := ""
   Default mode := ""

   // Set focus back to this form if it is already open
   if ISWINDOWDEFINED("frmStructEdit")
      domethod( "frmStructEdit", "SETFOCUS")
      return nil
   endif

   // Plugin mode, error message "not allowed".
   if !lStandAlone
      msgstop("You can not use the structure editor in Plugin mode.")

   // Standalone mode
   else

      // define form
      DEFINE WINDOW frmStructEdit;
         AT 0, 0 ;
         CLIENTAREA 370 + th_bt_width + th_w_ctrlgap * 2, 600;
         TITLE "OTIS - Structure Editor";
         BACKCOLOR th_w_bgcolor ;
         WINDOWTYPE STANDARD ;
         ON SIZE     se_resize() ;
         ON MAXIMIZE se_resize() ;
         ON MINIMIZE se_resize() ;
         ON INTERACTIVECLOSE se_release()

         // set min,max width
         ThisWindow.MaxWidth := getproperty(ThisWindow.name, "Width")
         ThisWindow.MinWidth := ThisWindow.MaxWidth

         // define browse to fill with structure data
         DEFINE TBROWSE BRW_2 ;
            AT th_bt_height + th_w_ctrlgap * 2, th_bt_width + th_w_ctrlgap * 2 ;
            WIDTH  frmStructEdit.ClientWidth - th_bt_width - th_w_ctrlgap * 3 ;
            HEIGHT frmStructEdit.ClientHeight - th_bt_height - th_w_ctrlgap * 3 ;
            SELECTOR .T. ;
            ARRAY aStruct ;
            HEADERS aNames

            :lNoHScroll   := .T.
            :lNoGrayBar   := .T.
            :lNoChangeOrd := .T.
            :nHeightCell  += 2
            :nHeightHead  := :nHeightCell + GetBorderHeight() / 2
            :nWheelLines  := 1
            :lNoMoveCols  := .T.
            :lNoResetPos  := .F.

            :SetColor( { 1, 2, 4, 5, 6 }, { ;
               CLR_BLACK, ;
               CLR_WHITE, ;
               { CLR_WHITE, RGB(210, 210, 220) }, ;
                  CLR_WHITE, RGB(21, 113, 173) }, )

            For i := 1 To Len( aNames )
               If i > 2
                  :aColumns[ i ]:nHAlign := DT_CENTER
                  :aColumns[ i ]:nAlign  := DT_CENTER
               Else
                  :aColumns[ i ]:nHAlign := DT_LEFT
               EndIf
            Next

            // add column with recno
            ADD COLUMN TO BRW_2  ;
               HEADER "#" ;
               DATA  BRW_2:nLogicPos ;
               SIZE 20 PIXELS ;
               3DLOOK TRUE,TRUE,FALSE ;                  // cels, header, footer
               ALIGN DT_CENTER,DT_CENTER,DT_CENTER ;     // cells, header, footer
               COLORS CLR_BLACK, CLR_HGRAY

            //:AdjColumns()
            :aColumns[1]:nWidth := 95
            :aColumns[2]:nWidth := 125
            :aColumns[3]:nWidth := 40
            :aColumns[4]:nWidth := 40

            // key functions
            :bKeyDown := { |nKey| If( nKey == VK_DELETE, ( BRW_2:Del() ), ;
                                 If( nKey == VK_INSERT, se_aim_field( se_insert, BRW_2:cParentWnd ), Nil ) ) }
            :blDblClick := { || se_aim_field( se_modify, BRW_2:cParentWnd ) }

            // init flag
            :lHasChanged  := .F.

            // cell margins, add one space left and right
            :nCellMarginLR := 1

            // Row Colors, fontcolor en/disabled, bg odd or even
            :SetColor( { 1, 2 }, { th_fctb_leven, {|nRow, nCol, oBrw| iif( nRow%2==0, th_bgtb_leven, th_bgtb_lodd )}} )

         END TBROWSE

         // label "Struct. of"
         DEFINE LABEL lb_structof
            ROW th_w_ctrlgap
            COL th_w_ctrlgap
            WIDTH th_bt_width
            HEIGHT 24
            FONTCOLOR th_bt_ohfontcol
            BACKCOLOR th_bt_ohbgcol
            FONTBOLD .F.
            FONTSIZE 10
            Value " Structure of"
            VCENTERALIGN .T.
         END label

         // textbox "empty" or with the dbf name if we imported a structure.
         DEFINE TEXTBOX tb_tbname
            ROW       th_w_ctrlgap
            COL       th_w_ctrlgap * 2 + th_bt_width
            WIDTH     frmStructEdit.ClientWidth - th_bt_width - th_w_ctrlgap * 3
            HEIGHT    23
            VALUE     "<no name>"
            READONLY .T.
         END TEXTBOX

         // Define left menu buttons
         //            "Value Label"     "menu_keyword" (used by dispatcher)
         aButtons := { ;
                     { "Append"           , "se_af" } , ;
                     { "Insert"           , "se_if" } , ;
                     { "Modify"           , "se_mf" } , ;
                     { "Delete"           , "se_df" } , ;
                     { "-"                , ""      } , ;
                     { "Move Up"          , "se_up" } , ;
                     { "Move Down"        , "se_dn" } , ;
                     { "-"                , ""      } , ;
                     { "Load structure"   , "se_is" } , ;
                     { "Clear structure"  , "se_cl" } , ;
                     { "-"                , ""      } , ;
                     { "? Field types"    , "se_fthelp" }, ;
                     { "? Table limits"   , "se_tblhelp" }   ;
                     }

         // init row, col position for a serie top left buttons
         r := th_w_ctrlgap * 2 + th_bt_height
         c := th_w_ctrlgap
         // draw menu buttons
         draw_menu( r, c, aButtons, "frmStructEdit" )

         // Button Save (as)
         DEFINE Label bt_save
            ROW  getproperty(ThisWindow.name,"ClientHeight") - ( th_bt_height + th_w_ctrlgap ) * 2
            COL  th_w_ctrlgap
            WIDTH th_bt_width
            HEIGHT th_bt_height
            FONTBOLD .T.
            FONTCOLOR th_bt_fontcol
            BACKCOLOR th_bt_bgcol
            Value "Save (as)"
            VCENTERALIGN .T.
            CENTERALIGN .T.
            ACTION se_saveas(BRW_2:aArray, cWinname)
            // font and background color when onhover / onleave
            ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                              setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
            ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                              setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
         END label

         // Button : Exit
         DEFINE LABEL bt_Quit
            ROW  getproperty(ThisWindow.name,"ClientHeight") - ( th_bt_height + th_w_ctrlgap) * 1
            COL  th_w_ctrlgap
            WIDTH th_bt_width
            HEIGHT th_bt_height
            FONTBOLD .T.
            FONTCOLOR th_bt_fontcol
            BACKCOLOR th_bt_bgcol
            Value "Quit"
            VCENTERALIGN .T.
            CENTERALIGN .T.
            ACTION ThisWindow.release  // se_release()
            FONTCOLOR th_bt_ohfontcol
            BACKCOLOR th_bt_ohbgcol
         END label

         // escape key = quit
         ON KEY ESCAPE ACTION { || This.bt_Quit.OnClick, domethod(cWinname, "SETFOCUS")}  // ThisWindow.Release

      END WINDOW

      // if mode == 'DV'
      if mode == "DV"
         // load structure of current opened table
         aStruct := DBSTRUCT()
         // translate field type to a full word type
         aStruct := FTypeToWord(aStruct)
         // set new browse array
         se_init_browse(aStruct)
         // set name in textbox
         frmStructEdit.tb_tbname.value := alltrim(Sx_Tablename())
      endif

      //CENTER WINDOW frmStructEdit
      setproperty( "frmStructEdit","Row", GetDesktopHeight()/2 - getproperty("frmStructEdit", "Height")/2 )
      setproperty( "frmStructEdit","Col", GetDesktopWidth()/2  - getproperty("frmStructEdit", "Width")/2 )

      // activate
      ACTIVATE WINDOW frmStructEdit

   Endif

RETURN NIL


// 'Save as' structure
static function se_saveas(aStruct, cWinname)

   local i, cTemp
   local lOk := .T.
   local cSaveToDbf, cTempFn
   local nArea, cUnderEditDbfName
   local lError := .F.

   local cHasFocus := FocusedWindow.Name
   LOCAL oBrw := GetBrowseObj( "BRW_2", "frmStructEdit" )
   Local oDvBrowse := GetBrowseObj( "tb_Dv_Browse", cWinname )

   // get alias name
   local cAlias := Alias()

   // fill array with all possible extensions for a table and the related files
   local aExtensions := { ".dbf", ".cdx", ".ntx", ".nsx", ".dbt", ".fpt", ".smt" }

   // save autopen status and active it for cdx management
   local lAutopen := Set( _SET_AUTOPEN, .T. )

   // debug
   //msgdebug(aStruct)
   //msgdebug(Cwinname)

   // if minimum 1 field defined
   IF BRW_2:nLen > 0 .and. !empty(BRW_2:aArray[1,1])

      // get from user filename to save to
      cSaveToDbf := PutFile( { {"File DBF (*.DBF)", "*.DBF"}, {'All Files','*.*'} }, 'New table...', GetCurrentFolder() )

      // If a file is selected or a new name is entered
      IF !Empty( cSaveToDbf )

         // msgdebug(cSaveToDbf, alltrim(Sx_Tablename()))

         // if 'Save to' filename is the same as the one currently open
         if cSaveToDbf == alltrim(Sx_Tablename())

            // confirm replacement of current table under edit
            PlayExclamation()
            if msgYesNo("Attention :" + crlf + crlf + ;
                        "You choose to change the structure of the file that is currently open." + crlf + crlf + ;
                        "Do you want to close, change the structure, append data and reopen this file ?" )

               // create temp filename, is the same but with a random nbr in it.
               // Att. without extension, reason see below.
               cTempFn := Sx_Tablename()
               cTempFn := hb_FNameDir(cTempFn) + hb_FNameName(cTempFn) + '_' + hb_ntos(random())

               // save properties of table that is undergoing a structure change.
               nArea  := SELECT()
               cUnderEditDbfName := cFileNoExt( (cAlias)->( Sx_Tablename() ) )
               //msgdebug(cUnderEditDbfName)

               // convert fieldtype full word to a single char
               AEval( aStruct, { |a, i| aStruct[i][2] := Left( a[2], 1 ) } )

               // create temp dbf with the new structure
               // dbt, fpt or smt will also be created
               DBCreate( cTempFn, aStruct, rddSetDefault() )

               // close table under edit
               use

               // open temp (new struct) and append from original (old struct)
               select(nArea)
               use (cTempFn) EXCLUSIVE CODEPAGE ini_dbf_codepage

               // Append data from old structure
               //  append without any index opened because this takes a huge time for large files
               //  test with a 1.5GB table and 7 tags showed a big difference of
               //   10min (with a cdx) and only 2 min (without cdx) included reindexing.
               TRY
                  WAIT WINDOW ("Append data from the old table into the new structure ...") NOWAIT
                  CursorWait()
                  do events

                  APPEND from (cUnderEditDbfName) CODEPAGE ini_dbf_codepage

                  CursorArrow()
                  WAIT CLEAR
                  do events

               // reindex error message
               Catch oError
                  // set flag
                  lError := .T.
                  // msg
                  MsgStop("Append data from old structure failed :" + crlf + crlf + ;
                           ErrorMessage(oError) )

               end

               // close temp
               use

               // Method used if we modify the structure of the current open file
               // Condition : table and index must have the same name.
               // The temp file has now the new structure and data of the old table.
               // we rename the only original file from .dbf to .bak,
               // idem memo files of type .dbt (dbase), .fpt (foxpro), .smt (hiper six)
               // we leave index names as they are so it is not necessary to recreate all tags
               // they are opened again when we reopen the new table.
               // The table is reindexed after opening.
               //
               // delete first all previous .bak files if any
               for i := 1 to len(aExtensions)
                  hb_FileDelete(cUnderEditDbfName + aExtensions[i] + ".bak")
               next i
               // create a .bak of dbf under edit and related files
               for i := 1 to len(aExtensions)
                  FRENAME( cUnderEditDbfName + aExtensions[i], cUnderEditDbfName + aExtensions[i] + ".bak" )
               next i

               // rename the new structure temp names to the original name idem for memo files and index files
               for i := 1 to len(aExtensions)
                  FRENAME( cTempFn + aExtensions[i], cUnderEditDbfName + aExtensions[i])
               next i

               // Create a new cdx file (copied from the old one)
               // if the old structure had also a cdx file with the same name
               if file( cUnderEditDbfName + ORDBAGEXT() + ".bak" )
                  hb_FCopy(cUnderEditDbfName + ORDBAGEXT() + ".bak", cUnderEditDbfName + ORDBAGEXT())
               endif

               // reopen the file that has now a new structure
               // the cdx file will be opened also if there is one with the same name.
               // the cdx is the old version renamed cdx file
               // so we have to reindex
               use (cSaveToDbf) ALIAS (cAlias) EXCLUSIVE CODEPAGE ini_dbf_codepage

               // reindex if any index open
               TRY
                  WAIT WINDOW ("Reindex in progress ...") NOWAIT
                  CursorWait()
                  do events

                  // reindex
                  DBREINDEX()

                  CursorArrow()
                  WAIT CLEAR
                  do events

               // reindex error message
               Catch oError
                  MsgStop("Reindex failed after a structure modification :" + crlf + crlf + ;
                           ErrorMessage(oError) )
               end

               // reset struct. modified flag
               oBrw:lHasChanged := .F.

               // reset flag, saving is done
               lOk := .F.

               // msg structure is updated
               PlayExclamation()
               msginfo("The structure update has finished.")

               // If in cmdline mode
               //  Close this dv_viewer window and restart viewer with the new structure.
               //  Don't forget to setup Otis.exe as the default program to use for dbf file.
               //   (didn't find a method to reload the modified structure in the current)
               //   (tbrowse() so the simplest methode is to reopen Otis.)
               if !empty(cCmdline)

                  // close file with new structure
                  close all
                  // reopen by execute default application defined in windows
                  execute file (cSaveToDbf)

                  // Close Otis by closing this dv_viewer window.
                  // remember we are in cmdline mode
                  domethod(cWinname, "release")

               // dbf is opened via dataset manager
               // close and reopen it with new structure
               else
                  // close current area
                  cTemp := { sx_tablename(), alias() }
                  use
                  // reopen the modified table with the same alias and area number
                  USE (cTemp[1]) ALIAS (cTemp[2]) CODEPAGE ini_dbf_codepage

                  // Exit the struct editor and this dv_viewer window
                  domethod("frmStructEdit", "release")
                  domethod(cWinname, "release")

                  // and reopen with new structure
                  otis_dv()

               endif

            // save is annulated
            else
               lOk := .F.
            endif

         endif

         // Create a NEW or Overwrite a table that is opened for the moment.
         if lOk

            // get "save to" filename without extension
            cTemp := cFileNoExt(cSaveToDbf)

            // If file exists already rename it to .bak
            IF File( cSaveToDbf )

               PlayExclamation()
               if MsgYesNo("Attention :" + crlf + crlf +;
                           "This file exists already and will be renamed to *.bak" + crlf + crlf +;
                           "All data will be lost, do you want to continue ?")

                  // delete first previous .bak files if any
                  for i := 1 to len(aExtensions)
                     hb_FileDelete(cTemp + aExtensions[i] + ".bak")
                  next i

                  // and rename existing one to .bak
                  for i := 1 to len(aExtensions)
                     FRENAME( cTemp + aExtensions[i], cTemp + aExtensions[i] + ".bak" )
                  next i

               // abort
               else
                  lOk := .F.
               endif

            ENDIF

            // if not aborted
            if lOk

               // convert fieldtype full word to a single char
               //msgdebug(aStruct)
               AEval( aStruct, { |a, i| aStruct[i][2] := Left( a[2], 1 ) } )

               // create dbf
               //msgdebug(cSaveToDbf, aStruct, rddSetDefault())
               DBCreate( cSaveToDbf, aStruct, rddSetDefault() )

               // reset flag changes are saved
               oBrw:lHasChanged := .F.

            endif

         endif

      ENDIF

   endif

   // Restore autopen
   Set( _SET_AUTOPEN, lAutopen)

return nil

// Structure editor release
static function se_release()

   local lReturn := .T.

   // close allways field editor form
   if ISWINDOWDEFINED("FieldNew")
      DoMethod( 'FieldNew', 'Release' )
   endif

   // if changed ask confirmation to quit and discard changes
   If BRW_2:lHasChanged
      PlayExclamation()
      IF msgOkCancel( "Do you want to discard the changes ?" )
         domethod( "frmStructEdit","release")
      else
         lReturn := .F.
      endif
   else
      domethod( "frmStructEdit","release")
   endif

return lReturn


// Struct.Editor form resize
static function se_resize()

   // update height "structure" grid table
   setproperty(ThisWindow.name, "BRW_2","Height", getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap * 3)

   // repos Cancel and Save as OKbutton
   setproperty(ThisWindow.name, "bt_save","row",   getproperty(ThisWindow.name,"ClientHeight") - ( th_bt_height + th_w_ctrlgap ) * 2 )
   setproperty(ThisWindow.name, "bt_Quit","row", getproperty(ThisWindow.name,"ClientHeight") - ( th_bt_height + th_w_ctrlgap ) * 1)

return nil


/*
  EXTENDED field type info
  Copied from sample in C:\MiniGUI\SAMPLES\BASIC\ExFldTps

  Type Short
  Code Name     Width (Bytes)     Description
  ---- -------  ----------------- -------------------------------------------------------------------
   D   Date     3, 4 or 8          Date
   M   Memo     4 or 8             Memo
   +   AutoInc  4                  Auto increment
   =   ModTime  8                  Last modified date & time of this record
   ^   RowVers  8                  Row version number; modification count of this record
   @   DayTime  8                  Date & Time
   T   Time     4                  Only time (use @ for Date and Time)
   I   Integer  1, 2, 3, 4 or 8    Signed Integer ( Width :  )" },;
   V   Variant  3, 4, 6 or more    Variable type Field
   Y   Currency 8                  converted to a 64 bit integer (I) with implied 4 decimal
   B   Double   8                  Floating point / 64 bit binary
*/

// Form to Add a new field,
//         Insert a new field,
//         Modify a existing one
//
static function se_aim_field( nMode, cFormName )

  MEMVAR BRW_2

  LOCAL lChanges := .F.
  LOCAL nColumn := BRW_2:nAt
  LOCAL cField, cType, nLen, nDec
  LOCAL nType, cType2
  local aFldDescr

   // Action code block for 'Apply' button
  local bConfirm := { ||
                     // if a field definition has changed
                     if lChanges

                        // message if fieldname is not unique
                        if AScan( BRW_2:aArray, { |a| a[1] == cField } ) > 0 .and. nMode <> se_modify

                           MsgStop( "This field name exists already.")
                           domethod("FieldNew","edtFld","SetFocus")

                        // ok, fieldname is unique
                        else
                           // message if no fieldname specified
                           if empty(cField)
                              MsgStop( "No fieldname specified.")
                              domethod("FieldNew","edtFld","SetFocus")

                           // fieldname is specified
                           else
                              // message, no spaces allowed in fieldname
                              if at(" ", alltrim(cField)) <> 0
                                 MsgStop( "A fieldname can not contain spaces.")
                                 domethod("FieldNew","edtFld","SetFocus")

                              // fieldname no spaces in it
                              else
                                 // fieldname max len = 10
                                 if len(alltrim(cField)) > 10
                                    MsgStop( "Fieldname lenght is maximum 10 characters.")
                                    domethod("FieldNew","edtFld","SetFocus")

                                 // ok, len < 10
                                 else
                                    // verify for invalid chars
                                    if len(charonly("_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", cField)) <> len(cField)
                                       MsgStop( "Only the following characters, 0..9, A..Z, are allowed in a fieldname.")
                                       domethod("FieldNew","edtFld","SetFocus")

                                    // no invalid chars
                                    else

                                       // error message if len == 0
                                       if nLen == 0
                                          setproperty("FieldNew","edtLen","BackColor", RED )
                                          MsgStop( "Field lenght can not be 0.")
                                          setproperty("FieldNew","edtLen","BackColor", WHITE )
                                          domethod("FieldNew","edtLen","SetFocus")

                                       // store field def in tbrowse array
                                       else
                                          cType2 := left(aTypes[nType,2],1) + " - " + aTypes[nType,1]
                                          se_AddUpdateFld( nMode, cField, cType2, nLen, nDec, cFormName )
                                          setproperty("FieldNew","edtFld","Value", "")
                                          domethod("FieldNew","edtFld","SetFocus")

                                          // if we where in modif mode, release form
                                          if nMode == se_modify
                                             ThisWindow.Release
                                          endif

                                       endif

                                    endif

                                 endif

                              endif

                           endif

                        endif

                     // nothing changed, release
                     else
                        ThisWindow.Release
                     endif

                     return nil
                    }

  // return if nothing to modify
  if nMode == se_modify .OR. nMode == se_insert
     IF Empty( nColumn ) .OR. ( nColumn == 1 .AND. Empty( BRW_2:aArray[ nColumn ][ 1 ] ) )
       RETURN nil
     ENDIF
  endif

   // init combobox array with full field type description
   aFldDescr := {}
   Aeval( aTypes, {|aSub| aadd( aFldDescr, aSub[1] ) } )


   // Release it if it was already opened
   //  the menu button is be used as a toggle to open and close this form.
   if ISWINDOWDEFINED("FieldNew")
      domethod( "FieldNew", "RELEASE")
      return nil
   endif


  // init gets with empty for append/insert
  if nMode <> se_modify
     cField  := ""
     cType   := "C"
     nLen    := 10
     nDec    := 0
     //nType   := AScan( aTypes, cType )
     nType   := 1

   // if modify init with current values
   else
      cField  := BRW_2:aArray[ nColumn ][ 1 ]
      cType   := BRW_2:aArray[ nColumn ][ 2 ]
      nLen    := BRW_2:aArray[ nColumn ][ 3 ]
      nDec    := BRW_2:aArray[ nColumn ][ 4 ]
      *
      nType   := AScan( aTypes, { |a| alltrim(a[2] + " - " + a[1]) == alltrim(cType) } )
      IF nType == 0
         nType := 1
      ENDIF
   endif

  DEFINE WINDOW FieldNew;
      row getproperty("frmStructEdit", "row") + 200 ;
      col getproperty("frmStructEdit", "col") + 200 ;
      CLIENTAREA 345 + th_w_ctrlgap * 2 ,100 +th_w_ctrlgap * 2 ;
      TITLE "OTIS - New Table - " + {"Append","Insert","Modify"}[nMode] + " field";
      backcolor th_w_bgcolor ;
      WINDOWTYPE STANDARD ;
      NOSIZE ;
      NOMINIMIZE ;
      NOMAXIMIZE ;
      ON INIT FieldNew.edtFld.Setfocus

      ON KEY ESCAPE ACTION FieldNew.Release

      // background controls
      DEFINE LABEL bg_controls
         ROW    th_w_ctrlgap
         COL    th_w_ctrlgap
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_w_ctrlgap * 2
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap * 3
         VISIBLE .T.
      END LABEL
      // frame around, looks nicer
      define FRAME fr_controls
         ROW    th_w_ctrlgap
         COL    th_w_ctrlgap + 1
         WIDTH  getproperty(ThisWindow.name,"bg_controls","Width") - 1
         HEIGHT getproperty(ThisWindow.name,"bg_controls","Height")
      end frame

      // field name
      DEFINE LABEL lblFld
          ROW       15
          COL       15
          VALUE     "Field name (10c)"
          AUTOSIZE .T.
      END LABEL

      DEFINE TEXTBOX edtFld
          ROW       35
          COL       15
          WIDTH     95
          HEIGHT    23
          VALUE     cField
          MAXLENGTH 10
          UPPERCASE .T.
          ONCHANGE  iif( Left( FieldNew.edtFld.Value, 1 ) $ "0123456789", FieldNew.edtFld.Value := "", ;
                    ( lChanges := .T., cField := AllTrim( FieldNew.edtFld.Value ) ) )
      END TEXTBOX

      // field type
      DEFINE LABEL lblTyp
          ROW       15
          COL       120
          VALUE     "Type"
          AUTOSIZE .T.
      END LABEL

      DEFINE COMBOBOX cmbTyp
          ROW       35
          COL       120
          WIDTH     115
          HEIGHT    180
          ITEMS     aFldDescr
          VALUE     nType
          ONCHANGE  ( lChanges := .T., ;
                      cType := left(atypes[This.Value,2],1), nType := This.Value, ;
                      se_OnTypeChange( This.Value, ThisWindow.Name ) )
      END COMBOBOX

      // field len
      DEFINE LABEL lblLen
          ROW       15
          COL       245
          VALUE     "Len."
          AUTOSIZE .T.
      END LABEL
      DEFINE TEXTBOX edtLen
          ROW        35
          COL        245
          WIDTH      45
          HEIGHT     23
          VALUE      nLen
          ONCHANGE   ( lChanges := .T., nLen := FieldNew.edtLen.Value )
          NUMERIC    .T.
          RIGHTALIGN .T.
      END TEXTBOX

      // field dec.
      DEFINE LABEL lblDec
          ROW       15
          COL       300
          VALUE     "Dec."
          AUTOSIZE .T.
      END LABEL
      DEFINE TEXTBOX edtDec
          ROW        35
          COL        300
          WIDTH      35
          HEIGHT     23
          VALUE      nDec
          ONCHANGE   ( lChanges := .T., nDec := FieldNew.edtDec.Value )
          NUMERIC    .T.
          RIGHTALIGN .T.
      END TEXTBOX

      // Apply button
      DEFINE Label bt_Confirm
         ROW  getproperty(ThisWindow.name,"ClientHeight") - ( th_bt_height + th_w_ctrlgap ) * 1
         COL  th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Apply"
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         VCENTERALIGN .T.
         CENTERALIGN .T.
         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
         // action codeblock
         ACTION eval( bConfirm )

      END label

      // Help button
      DEFINE Label bt_sehelp
         ROW  getproperty(ThisWindow.name,"ClientHeight") - ( th_bt_height + th_w_ctrlgap ) * 1
         COL  th_bt_width + (th_w_ctrlgap * 2)
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "?  Field types"
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         VCENTERALIGN .T.
         CENTERALIGN .T.
         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
         // action codeblock
         ACTION se_helpfldtype()

      END label

      // Quit button
      DEFINE Label bt_quit
         ROW  getproperty(ThisWindow.name,"ClientHeight") - ( th_bt_height + th_w_ctrlgap ) * 1
         COL getproperty(ThisWindow.name,"ClientWidth") - ( th_bt_width + th_w_ctrlgap ) * 1
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Quit"
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         VCENTERALIGN .T.
         CENTERALIGN .T.
         ACTION    ThisWindow.Release
      END label

      // Enter key = 'Apply' key
      ON KEY RETURN ACTION This.bt_Confirm.OnClick

  END WINDOW

  // enable/disable "len" and "dec"
  FieldNew.edtLen.Enabled := aTypes[nType,3] == 0
  FieldNew.edtDec.Enabled := nType == 2

  //CENTER WINDOW FieldNew
  ACTIVATE WINDOW FieldNew

RETURN nil


// Struct. Edit DELETE a field def.
//  but display a warnig it is used in a index KEY or FOR expression.
static function se_del_field(cFormName)

   local i, nPos, cWarning, cFieldname

   // load index info
   local aIndexInfo := collect_index_info(Alias())[3]

   // get tbrowse object
   LOCAL oBrw := GetBrowseObj( "BRW_2", cFormName )

   // get row pos.
   nPos := oBrw:nAT

   // and fieldname from table
   cFieldname := alltrim( oBrw:aArray[ oBrw:nAT ][ 1 ] )

   // check if used in a KEY or FOR expression
   cWarning := ""
   for i := 1 to len(aIndexInfo)
      if cFieldname $ aIndexInfo[i, OI_KEY] + "," + aIndexInfo[i, OI_FOR]
         // add warning to text display below in the msgOkCancel() dialog
         cWarning := "ATTENTION" + crlf + crlf + "Field '"+ cFieldname +"' is used in the Key" + crlf + ;
                     "or FOR expression in order number " + hb_ntos(i) + "." + crlf + crlf

      endif
   next i

   // Ask confirmation
   PlayExclamation()
   if MsgOkCancel( cWarning + "Do you want to delete field '" + cFieldname + "'.", "Otis" )

      // position
      oBrw:GoPos(nPos)           // this positioning should not be necessary but for one reason or another
                                 // the first call of :del() is deleting always the first entry in the tbrowse array.
                                 // Even the cursor is placed on line 1 in the tbrowse array. BUG ????
                                 // it is no longer necessary when we delete others afterwards.
                                 // :nAT position is respected.
      // delete row
      oBrw:Del(nPos)

      *// minimum 1 empty entry
      *if oBrw:nLen == 0
      *   oBrw:AddItem(  )
      *endif

      oBrw:lHasChanged := .T.

   endif

   // set new row pos.
   oBrw:GoPos( if( nPos > oBrw:nLen, oBrw:nLen, oBrw:nAT ) )
   oBrw:SetFocus()

return nil


// update tbrowse array with new/modified field definition
static function se_AddUpdateFld( nMode, cField, cType, nLen, nDec, cFormName )

  LOCAL oBrw := GetBrowseObj( "BRW_2", cFormName )

  // append
  IF nMode == se_append
    oBrw:AddItem( { cField, cType, nLen, nDec } )
    oBrw:GoPos(oBrw:nLen)

  // insert
  ELSEIF nMode == se_insert
    oBrw:Insert( { cField, cType, nLen, nDec } )

  // Modify
  ELSEIF nMode == se_modify
   oBrw:aArray[oBrw:nAt] := { cField, cType, nLen, nDec }
   oBrw:refresh()
  ENDIF

  oBrw:lHasChanged := .T.

RETURN nil

// Field type change :
//    enable / disable some controls in function of type of field
//    and init field len.
static function se_OnTypeChange( nType, cWin )

   local nLen

   // enable/disable field len, variable if len=0
   SetProperty( cWin, "edtLen", "Enabled", aTypes[nType,3] == 0 )

   // enable/disable field dec
   SetProperty( cWin, "edtDec", "Enabled", ( nType == 2 ) )

   // init len with default value from field types array
   nLen := aTypes[nType,3]

   // if len == 0, len is variable, set default to 10
   if nLen == 0
      nLen := 10
   endif

   // set new len
   SetProperty( cWin, "edtLen", "Value", nLen )

   // set field decimals always to 0
   SetProperty( cWin, "edtDec", "Value", 0 )

RETURN nil


// shift field up / down
//
// Args : U = up
//        D = down
//
static function se_field_ud( cSense )

   Local temp, i
   LOCAL oBrw := GetBrowseObj( "BRW_2", "frmStructEdit" )
   Local nSense

   // check if on top or bottom and set sense
   if cSense == "U"
      nSense := -1
      if obrw:nAt == 1
         return nil
      endif
   else
      nSense := 1
      if obrw:nAt == obrw:nLen
         return nil
      endif
   endif

   // get current row position
   i := oBrw:nAt
   // save current contents
   temp := oBrw:aArray[i]
   // copy previous or next to current
   oBrw:aArray[i] := oBrw:aArray[i+nSense]
   // copy saved to prev or next
   oBrw:aArray[i+nSense] := temp

   // new browse position
   oBrw:GoPos(i+nSense)

   // set changed flag
   oBrw:lHasChanged := .T.

return nil


// structure editor :  load structure of a existing table
static function se_load_struct(cFormName)

   local cFn, nOldsel, cRdd
   LOCAL oBrw := GetBrowseObj( "BRW_2", cFormName )

   // Select a table
   cFn := Getfile( { {'Dbf Files','*.DBF'}, {'All Files','*.*'} } , 'Open DBF file(s)')

   // if a file selected
   if !empty(cFn)

      // save current area
      nOldsel := Select()

      // get current actif Rdd
      cRdd := getproperty("form_otis", "cb_defrdd","Item", getproperty( "form_otis", "cb_defrdd", "Value") )

      // if rdd = leto set it to dbfcdx
      if cRdd == 'LETO'
         cRdd := 'DBFCDX'
      endif

      Try
         // open table
         use (cFn) ALIAS IMPSTRUCT READONLY NEW VIA(cRdd) CODEPAGE ini_dbf_codepage
         // get structure
         aStruct := DBSTRUCT()
         // close
         use

         // translate field type to a full word type
         aStruct := FTypeToWord(aStruct)

         // set new browse array
         se_init_browse(aStruct)

         // structure changed
         oBrw:lHasChanged := .T.

      Catch oError
         MsgStop("OTIS can not load the structure."+crlf+crlf+ ;
                 "The file is probably opened by this or"+crlf+;
                 "another program in exclusive mode,"+crlf+;
                 "the wrong Rdd is used or"+crlf+;
                 "a unknown field type is found.";
                )
         return nil
      end

      // restore area
      select (nOldsel)

      // set name in textbox
      frmStructEdit.tb_tbname.value := cFn

   endif

return nil


// Translate Field type letter to a full word type string
static function FTypeToWord(aStruct)

   local i, x, temp

   // translate type of field into a full field type description
   //  ex C -> C - Character
   for i := 1 to len(aStruct)

      // construct search arg. "Type + Len"
      temp := aStruct[i,2] + strzero(aStruct[i,3],2)
      // correct if var LEN, detected by 00
      if left(temp,1) $ "C,N" .or. ( left(temp,1)=="V" .and. aStruct[i,3] > 6 )
         temp := left(temp,1) + "00"
      endif
      //msgstop(temp)
      // search full field type text
      x := AScan( aTypes, { |a| a[2] + strzero(a[3],2) == temp } )
      // update structure array
      if x <> 0
         aStruct[i,2] := aStruct[i,2] + " - " + aTypes[ x, 1 ]
      // invalid field type detected
      else
         msgstop("A unknown field type is detected : " + temp )
         aStruct[i,2] := aStruct[i,2] + " - UNKNOWN"
      endif
   next i

return aStruct


// structure editor : clear structure
static function se_clear_struct()

   // ask confirmation
   PlayExclamation()
   if MsgYesNo( "Do you want to clear the structure ?" )
      // set a empty browse array and refresh
      se_init_browse({ {"","","",""} })

      // clear textbox with table name of loaded structure
      setproperty("frmStructEdit", "tb_tbname","Value", "")
   endif

return nil


// structure editor : load a new structure array in the tbrowse
static function se_init_browse(aStruct)

   local oBrw

   // set a empty browse array and refresh display
   oBrw := GetBrowseObj( "BRW_2", "frmStructEdit" )
   oBrw:lHasChanged := .F.
   oBrw:SetArray(aStruct)
   oBrw:refresh()
   oBrw:Gotop()

return nil


// show help screen with extended field types
static function se_helpfldtype()

   local cInfo := "Source, see sample in C:\MiniGUI\SAMPLES\BASIC\ExFldTps |"                                                             + ;
                  " |"                                                                                                                    + ;
                  "Standard field types |"                                                                                                + ;
                  "---------------------- |"                                                                                              + ;
                  " |"                                                                                                                    + ;
                  "  Code %T1 Type %T1    Width %T2 Description |"                                                                        + ;
                  "  ----- %T1 ---------- %T1    ----------------- %T1 --------------------------------------------------------------- |" + ;
                  "  C %T1 Character %T1    1...65534 %T2 Character |"                                                                    + ;
                  "  N %T1 Numeric %T1    1...32 %T2 Numeric |"                                                                           + ;
                  "  D %T1 Date %T1    8,3,4 %T2 Date, 8 standard, 3 and 4 extended |"                                                    + ;
                  "  L %T1 Logical %T1    1 %T2 Logical |"                                                                                + ;
                  "  M %T1 Memo %T1    10 or 4 %T2 Memo, 10 standard, 4 extended |"                                                       + ;
                  " |"                                                                                                                    + ;
                  " |"                                                                                                                    + ;
                  "Extended field types |"                                                                                                + ;
                  "---------------------- |"                                                                                              + ;
                  " |"                                                                                                                    + ;
                  "  Code %T1 Type %T1    Width %T2 Description |"                                                                        + ;
                  "  ----- %T1 ---------- %T1    ----------------- %T1 --------------------------------------------------------------- |" + ;
                  "  + %T1 AutoInc  %T1    4 %T2 Auto increment |"                                                                        + ;
                  "  = %T1 ModTime  %T1    8 %T2 Last modified date & time of this record |"                                              + ;
                  "  ^ %T1 RowVers  %T1    8 %T2 Row version number, modification count of this record |"                                 + ;
                  "  @ %T1 DayTime  %T1    8 %T2 Date & Time |"                                                                           + ;
                  "  T %T1 Time     %T1    4 %T2 Only time (use @ for Date and Time) |"                                                   + ;
                  "  I %T1 Integer  %T1    1, 2, 3, 4 or 8 %T1 Signed Integer |"                                                          + ;
                  "  V %T1 Variant  %T1    3, 4, 6...254 %T1 Variable type Field |"                                                       + ;
                  "  Y %T1 Currency %T1    8 %T2 Converted to a 64 bit integer (I) with implied 4 decimal |"                              + ;
                  "  B %T1 Double   %T1    8 %T2 Floating point / 64 bit binary |"

   // show it
   show_help(cInfo, 600, 500)

return nil

// show help screen with table size limits
static function se_helptbl()


   local cInfo := "Table size limits" + "|" + ;
                  "------------------" + "|" + ;
                  " Max record size %T1  %T2 65535 bytes (64 MB)" + "|" + ;
                  " Max number of records %T2 4,294,967,295 (4 Billion)" + "|" + ;
                  " Max .dbf file size %T1  %T2 256 TB" + "|" + ;
                  " Max DBT memo file size %T2 2 TB" + "|" + ;
                  " Max FPT memo file size %T2 256 GB" + "|" + ;
                  " Max SMT memo file size %T2 128 GB" + "|" + ;
                  " Max NTX file size (standard) %T2 4GB" + "|" + ;
                  " Max NTX file size (increased) %T2 4TB" + "|" + ;
                  " Max CDX file size %T1  %T2 4GB"

   // show it
   show_help(cInfo, 450, 250)

return nil

//***********************************************************************************************************************************
   * Procedure ------------------------

// Leto_GetFile
static function leto_getfile(aFileMask, cTitel, cPath, lMultiSelect )

return leto_gpfile("GET", aFileMask, cTitel, cPath, lMultiSelect )

// Leto_PutFile
static function leto_putfile(aFileMask, cTitel, cPath, lMultiSelect )

return leto_gpfile("PUT", aFileMask, cTitel, cPath, lMultiSelect )



//                    aFileMask,                                   cTitle,            cPath,         lMultiSelect
// leto_Getfile( { {'Dbf Files','*.DBF'}, {'All Files','*.*'} } , 'Open DBF file(s)' , ini_lu_folder, .t. )
//
static function leto_gpfile(cAction, aFileMask, cTitel, cPath, lMultiSelect )

   LOCAL aTemp, cItems, i, r, c, aMask := {}, aFiles := {}

   // Defaults
   default aFileMask    := { {'All Files','*.*'} }
   default cTitel       := "LetoDbf"
   default cPath        := "\"
   default lMultiSelect := .F.

   // Fill file mask combobox array
   for i := 1 to len(aFileMask)
      aadd(aMask, aFileMask[i,1] + ",   " + aFileMask[i,2])
   next i

   // form
   DEFINE WINDOW f_gpfile ;
      ;//row getproperty("form_otis", "row") + 200 ;
      ;//col getproperty("form_otis", "col") + 200 ;
      row 200 ;
      col 500 ;
      clientarea 750, 550 ;
      TITLE 'Otis - ' + cTitel ;
      WINDOWTYPE MODAL ;
      NOSIZE ;
      BACKCOLOR th_w_bgcolor

      // init row, col position for other buttons
      r := th_w_ctrlgap
      c := th_w_ctrlgap

      // path
      define TEXTBOX tb_path
         row r
         col c
         height 23
         width getproperty(ThisWindow.name,"ClientWidth") - th_w_ctrlgap * 2
         VALUE ""
         readonly .T.
      end textbox

      // Connexion tree view
      r += th_w_ctrlgap + 23
      DEFINE TREE Tree_1 ;
         ROW    r ;
         COL    th_w_ctrlgap ;
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") / 3 - th_w_ctrlgap * 3 ;
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - 23 * 2 - th_bt_height - th_w_ctrlgap * 5 ;
         ONCHANGE Leto_getfiles( getproperty( "f_gpfile","Tree_1", "cargo", f_gpfile.Tree_1.Value ), ;
                                 aFileMask[ This.cb_FileMask.Value, 2 ], ;
                               "tree on change" )

         //NODEIMAGES { "folder.bmp" }
         //ITEMIMAGES { "documents.bmp" }
         //ITEMIDS
      END TREE

      // Files grid
      DEFINE GRID Grid_1
         ROW      r
         COL      getproperty(ThisWindow.name, "Tree_1", "Width") + th_w_ctrlgap * 2
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - getproperty(ThisWindow.name, "Tree_1", "Width") - th_w_ctrlgap * 3
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - 23 * 2 - th_bt_height - th_w_ctrlgap * 5
         HEADERS {'Name','Modified on', 'Size'}
         WIDTHS { 145, 135, 95 }
         ITEMS {{"","",""}}
         CELLNAVIGATION .F.
         JUSTIFY { BROWSE_JTFY_LEFT, BROWSE_JTFY_LEFT, BROWSE_JTFY_RIGHT }
         ALLOWEDIT   .F.
         ALLOWSORT   .T.
         NOLINES .T.
         VALUE    1
         ON CHANGE { || aTemp := leto_otis_getitems(),;
                        cItems := "",;
                        aeval( aTemp, { | str | cItems += '"' + str + '" ' } ), ;
                        setproperty(ThisWindow.name, "tb_filename", "Value", cItems) }

         // Multiselect GET / PUT
         MULTISELECT lMultiselect
         // dbl mouse click
         ON DBLCLICK { || aFiles := leto_otis_getitems(), ThisWindow.release }

      END GRID

      // Filename(s) selected in grid
      define TEXTBOX tb_filename
         row getproperty(ThisWindow.name,"ClientHeight") - 23 - th_bt_height - th_w_ctrlgap * 2
         col th_w_ctrlgap
         height 23
         width getproperty(ThisWindow.name,"ClientWidth") - getproperty(ThisWindow.name, "Tree_1", "Width") - th_w_ctrlgap * 3
         VALUE ""
      end textbox

      // combobox file mask
      define COMBOBOX cb_filemask
         row getproperty(ThisWindow.name,"ClientHeight") - 23 - th_bt_height - th_w_ctrlgap * 2
         col getproperty(ThisWindow.name,"ClientWidth") - th_w_ctrlgap * 1 - 150
         height 140
         width 150
         FONTSIZE 10
         DISPLAYEDIT .F.
         ONCHANGE Leto_getfiles(getproperty( "f_gpfile","Tree_1", "cargo", f_gpfile.Tree_1.Value ), ;
                                 aFileMask[ This.cb_FileMask.Value, 2 ], ;
                                "Filemask on change" )
         Items aMask
         VALUE 1
      end COMBOBOX

      // refresh button
      DEFINE LABEL bt_refresh
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL th_w_ctrlgap
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "F5 - Refresh"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         ACTION Leto_Build_Data_Tree( cPath, aFileMask )
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
      END label

      // Cancel button
      DEFINE LABEL bt_Cancel
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL getproperty(ThisWindow.name,"ClientWidth") - ( th_bt_width + th_w_ctrlgap ) * 1
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Cancel"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         ACTION ThisWindow.release
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      END label

      // Open / save button
      DEFINE LABEL bt_OpenSave
         ROW getproperty(ThisWindow.name, "ClientHeight") - th_bt_height - th_w_ctrlgap
         COL getproperty(ThisWindow.name, "ClientWidth") - ( th_bt_width + th_w_ctrlgap ) * 2
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value if( cAction == "GET", "Open", "Save" )
         VCENTERALIGN .T.
         CENTERALIGN .T.
         //ACTION { || aFiles := if( cAction == "GET", leto_otis_getitems(), leto_otis_save()), ThisWindow.release }
         ACTION { || aFiles := leto_otis_getitems(), ThisWindow.release }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
      END label


      ON KEY ESCAPE ACTION ThisWindow.Release
      ON KEY F5     ACTION This.bt_refresh.onclick

   end window

   // fill the tree with all Letodbf server connexions and there data structure.
   Leto_Build_Data_Tree( cPath, aFileMask )

   // activate window
   ACTIVATE WINDOW f_gpfile

RETURN( aFiles )


// Fill a array with files to open
static function leto_otis_getitems()

   local temp, i, aValues, aFiles := {}

   // debug
   //msgstop(valtype(This.Grid_1.Value))

   // Grid return a array if multiselect is on
   if valtype(This.Grid_1.Value) == "A"

      // if anything in the grid and anything selected
      if This.Grid_1.ItemCount <> 0 .and. len(This.Grid_1.Value) <> 0

         // get array with all selected items (record nbr in grid)
         aValues := This.Grid_1.Value
         // fill array with filenames
         for i := 1 to len(aValues)
            aadd( aFiles, This.Grid_1.Cargo + "\" + This.grid_1.cell( aValues[i] , 1 ) )
         next i

      endif

   // and returns a numeric value if multiselect is off
   else
      // if anything in the grid and anything selected
      if This.Grid_1.ItemCount <> 0 .and. This.Grid_1.Value <> 0
         aadd( aFiles, This.Grid_1.Cargo + "\" + This.grid_1.cell( This.grid_1.value, 1 ) )

      // nothing selected but a new entre could be entered in the textbox
      else
         // get textbox and add ext if necc.
         temp := getproperty(ThisWindow.name, "tb_filename", "Value")
         if empty( hb_fNameExt( temp ) )
            temp := temp + '.dbf'
         endif
         // copy to function return array
         aadd( aFiles, This.Grid_1.Cargo + "\" + temp )
      endif
   endif

   // debug
   //msgstop(len(aFiles))
   //msgstop(aFiles)

return aFiles


*********************************************************
static function Leto_Build_Data_Tree(cPath, aFileMask)
*********************************************************

   // get row,col, width and height of current grid
   local r := getproperty( "f_gpfile","Tree_1", "row")
   local c := getproperty( "f_gpfile","Tree_1", "col")
   local w := getproperty( "f_gpfile","Tree_1", "width")
   local h := getproperty( "f_gpfile","Tree_1", "height")

   // debug
   //msgstop("rebuild tree")

   // defaults
   default cPath := "\"

   // release tree
   f_gpfile.Tree_1.Release

   // rebuild it
   DEFINE TREE Tree_1 PARENT f_gpfile ;
      ROW    r ;
      COL    c ;
      WIDTH  w ;
      HEIGHT h ;
      ;//ONINIT Leto_Build_Data_Tree( cPath ) ;
      ONCHANGE Leto_getfiles( getproperty( "f_gpfile","Tree_1", "cargo", f_gpfile.Tree_1.Value ), ;
                              aFileMask[ This.cb_FileMask.Value, 2 ], ;
                              f_gpfile.Tree_1.Value, "tree on change" )

      // main node in tree is letodbf connexion ID
      Node "LetoDbf conn. ID : " + hb_ntos(leto_connect())

         // and add all folders to this tree
         Leto_getDirNames(cPath)

      End Node

   end tree

   // enable screen refresh and set focus
   f_gpfile.Tree_1.EnableUpdate
   f_gpfile.Tree_1.Value := f_gpfile.Tree_1.FirstItemValue
   f_gpfile.Tree_1.SetFocus

   // expand tree
   //f_gpfile.Tree_1.Expand ( f_gpfile.Tree_1.RootValue )        // 1ste node
   // or
   f_gpfile.Tree_1.Expand(f_gpfile.Tree_1.Value, .T.)           // all nodes

RETURN nil


****************************************************************
static function Leto_getDirNames( cPath )
****************************************************************

   Local cMask     := "", ;
         cAttr     := "", ;
         aFullList      , ;
         aDir      := {}, ;
         xItem

   // path ends always with '\' char.
   If !( Right( cPath, 1 ) == '\' )
      cPath += '\'
   Endif

   // debug
   //msgstop(cPath)

   // build array with all sorted files and folder in the passed path
   if !Empty( aFullList := ASort( leto_directory( cPath+"*.*", ( 'D' + cAttr ) ),,, ;
                                  { | x, y | Upper( x[ F_NAME ] ) < Upper( y[ F_NAME ] ) } ) )
      // keep only foldernames
      For each xItem in aFullList
        If 'D' $ xItem[ F_ATTR ] .and.  !( xItem[ F_NAME ] == '.' ) .and. !( xItem[ F_NAME ] == '..' )
           AAdd( aDir, xItem[ F_NAME ] )
        Endif
      Next

   Endif

   // Process the resulting directory listing. In this case, recursive
   // call the procedure to scan dir levels below
   If !Empty( aDir )

      For each xItem in aDir
         // create a node for this folder entry
         Node xItem CARGO (cPath + xItem)
            //msgstop(cPath + xItem + crlf + hb_ntos(getproperty( "f_gpfile", "Tree_1","ItemCount")) )
            // save the full path in the CARGO property of each node
            // setproperty( "f_gpfile", "Tree_1", "CARGO", getproperty( "f_gpfile", "Tree_1","ItemCount"), cPath + xItem )
            //msgstop( getproperty( "f_gpfile", "Tree_1", "CARGO", getproperty( "f_gpfile", "Tree_1","ItemCount") ) )
            // and search for sub folders (recursive call)
            Leto_getDirNames( cPath + xItem )
         End Node

      Next

   Endif

RETURN nil


//
****************************************************************
static function Leto_getfiles(cPath, cMask, cCallId)
****************************************************************

   local temp, i, cSize, aDir := {}, cFullPath

   Default cPath := "\"

   // debug
   cCallId := cCallId      // to prevent -w2 warnings
   // msgstop(cPath + crlf + cMask + crlf + cCallId)

   // display path
   f_gpfile.tb_path.value := cPath

   // fully clear grid
   f_gpfile.Grid_1.DisableUpdate
   f_gpfile.Grid_1.DeleteAllItems

   //
   cFullPath := cPath + "\" + cMask

   // cleanup cMask to prevent double \\
   cFullPath := strtran(cFullPath, "\\", "\")

   // fill with all filenames in function of filemask
   //msgstop(cFullPath)
   aDir := leto_directory(cFullPath, "D")
   //aDir := leto_directory(cFullPath)

   // if any entry found
   if len(aDir) > 0

      if len(aDir) > 0

         for i := 1 to len(aDir)

            // subdir, do nothing
            if "D" $ aDir[i, F_ATTR ] .and. "." <> aDir[i,1]

               //f_gpfile.Grid_1.AddItem( { "[" + aDir[i,1] + "]", "", "" } )

            // file
            elseif "." <> aDir[i,1]

               // format date & time string
               temp := strtran(hb_TSToStr(aDir[i,3]), "/", "-")
               temp := substr(temp, 1, at(".", temp) - 1 )

               // format size
               cSize := hb_ntos( int( aDir[i,2] / 1000 ) ) + ' kb'

               // add to grid
               f_gpfile.Grid_1.AddItem( { aDir[i,1], temp, cSize } )
               f_gpfile.Grid_1.Cargo := cPath

            endif

         next i

      endif

   endif

   // enable grid
   f_gpfile.Grid_1.EnableUpdate

return nil


//***********************************************************************************************************************************
//** Function used everywhere in Otis ***********************************************************************************************
//***********************************************************************************************************************************

   * Procedure ------------------------

// Search and return browse object in a form
//
//   example oBrw := GetBrowseObj( "BRW_2", cFormName )
//
static FUNCTION GetBrowseObj( cBrw, cParent )

  LOCAL oBrw, i

  If ( i := GetControlIndex( cBrw, cParent ) ) > 0
     oBrw := _HMG_aControlIds [ i ]
  EndIf

RETURN oBrw


//
// Draw menu buttons on the left side of a form :
//  The len of the array define automatically the number of buttons to display.
//   [ {value, keyword} ] 2dim array : Value of label (button)
//                                     keyword used as button ID and used for the menu dispatcher.
//
//  Entry "-" can be used to display a separator line between buttons.
//  Entry "|" can be used in menu string to split into 2 buttons with equal size
//  Entry "|>" can be used in menu string to split into 1 large 90% size and 1 small 10% size button for extended functions
//
//  This permits to change on the fly, menu position, add/insert a new menu, ...etc.
//  Do not forget to update function mn_dispatch() if you make changes.
//
//  Args : start row & col
//         array with button data
//
static function draw_menu( nRow, nCol, aButtons, cWinname )

   local i, temp, nSize

   // debug
   // msgstop('Entry draw_menu : ' + cWinname)

   *
   for i := 1 to len(aButtons)

      // use menu keyword as ID for buttons
      temp :=  "bt_"+ aButtons[i,2]

      // Display menu if is not a seperator line
      if left(aButtons[i,1],1) <> "-"

         // define label button
         if at("|", aButtons[i,1]) == 0

            DEFINE LABEL &temp
               ROW nRow
               COL nCol
               WIDTH th_bt_width
               HEIGHT th_bt_height
               FONTBOLD .T.
               FONTCOLOR th_bt_fontcol
               BACKCOLOR th_bt_bgcol
               Value " "+ aButtons[i,1]
               if ! crlf $ aButtons[i,1]              // WORKAROUND, don't set VCENTERALIGN if multi-line value is used
                  VCENTERALIGN .T.                    // with it multi-line does not work.
               endif

               // set label action, call menu dispatcher with some arguments
               cMacro := "'" + aButtons[i,2] + "'"
               cMacro1 := "'" + cWinname + "'"
               //ACTION mn_dispatch( &cMacro., ThisWindow.name )
               ACTION mn_dispatch( &cMacro., &cMacro1 )

               // font and background color when onhover / onleave
               cMacro := '"'+temp+'"'
               ONMOUSEHOVER { || setproperty(ThisWindow.name, &cMacro, "BACKCOLOR", th_bt_ohbgcol),;
                                 setproperty(ThisWindow.name, &cMacro, "FONTCOLOR", th_bt_ohfontcol)}
               ONMOUSELEAVE { || setproperty(ThisWindow.name, &cMacro, "BACKCOLOR", th_bt_bgcol),;
                                 setproperty(ThisWindow.name, &cMacro, "FONTCOLOR", th_bt_fontcol)}
            END label

         // Split menu into 2 half size buttons
         else
            // determine width of split buttons, 50/50% or 90/10%
            nSize := if( at("|>", aButtons[i,1]) == 0, 0.5 , 0.1 )

            // left menu
            DEFINE LABEL &(temp+"_L")
               ROW nRow
               COL nCol
               WIDTH (th_bt_width * (1-nSize)) - th_w_ctrlgap / 2
               HEIGHT th_bt_height
               FONTBOLD .T.
               FONTCOLOR th_bt_fontcol
               BACKCOLOR th_bt_bgcol
               Value " "+ substr( aButtons[i,1], 1, at("|",aButtons[i,1]) - 1)
               if ! crlf $ aButtons[i,1]              // WORKAROUND, don't set VCENTERALIGN if multi-line value is used
                  VCENTERALIGN .T.                    // with it multi-line does not work.
               endif

               // set label action, call menu dispatcher with some arguments
               cMacro := "'" + aButtons[i,2] + "'"
               cMacro1 := "'" + cWinname + "'"
               //ACTION mn_dispatch( &cMacro., ThisWindow.name )
               ACTION mn_dispatch( &cMacro., &cMacro1 )

               // font and background color when onhover / onleave
               cMacro := '"'+temp+'_L"'
               ONMOUSEHOVER { || setproperty(ThisWindow.name, &cMacro, "BACKCOLOR", th_bt_ohbgcol),;
                                 setproperty(ThisWindow.name, &cMacro, "FONTCOLOR", th_bt_ohfontcol)}
               ONMOUSELEAVE { || setproperty(ThisWindow.name, &cMacro, "BACKCOLOR", th_bt_bgcol),;
                                 setproperty(ThisWindow.name, &cMacro, "FONTCOLOR", th_bt_fontcol)}
            END label

            // right menu
            DEFINE LABEL &(temp+"_R")
               ROW nRow
               if nSize == 0.5
                  COL nCol + (th_bt_width * (1-nSize)) + th_w_ctrlgap / 2
                  WIDTH (th_bt_width * nSize) - th_w_ctrlgap / 2
               else
                  COL nCol + (th_bt_width * (1-nSize)) - th_w_ctrlgap / 2 + 2
                  WIDTH (th_bt_width * nSize) + th_w_ctrlgap / 2 - 2
               endif
               HEIGHT th_bt_height
               FONTBOLD .T.
               FONTCOLOR th_bt_fontcol
               BACKCOLOR th_bt_bgcol
               Value " "+ substr( aButtons[i,1], at("|",aButtons[i,1]) + 1)
               if ! crlf $ aButtons[i,1]              // WORKAROUND, don't set VCENTERALIGN if multi-line value is used
                  VCENTERALIGN .T.                    // with it multi-line does not work.
               endif

               // set label action, call menu dispatcher with some arguments
               cMacro := "'" + aButtons[i,3] + "'"
               cMacro1 := "'" + cWinname + "'"
               //ACTION mn_dispatch( &cMacro., ThisWindow.name )
               ACTION mn_dispatch( &cMacro., &cMacro1 )

               // font and background color when onhover / onleave
               cMacro := '"'+temp+'_R"'
               ONMOUSEHOVER { || setproperty(ThisWindow.name, &cMacro, "BACKCOLOR", th_bt_ohbgcol),;
                                 setproperty(ThisWindow.name, &cMacro, "FONTCOLOR", th_bt_ohfontcol)}
               ONMOUSELEAVE { || setproperty(ThisWindow.name, &cMacro, "BACKCOLOR", th_bt_bgcol),;
                                 setproperty(ThisWindow.name, &cMacro, "FONTCOLOR", th_bt_fontcol)}
            END label


         endif

         // next col position
         nRow += th_bt_height + th_w_ctrlgap

      // Or add only a 'gap' if keychar "-" is used for the next button position.
      else

         // draw a small separator line between the 2 gaps,
         //  use i from for next loop to create a unique ID name
         Define label &("lb_sep_"+hb_ntos(i))
            row nRow - 1
            col nCol
            height 1                               // thickness of seperator line
            width th_bt_width                         // same width as a button
            BACKCOLOR th_bt_ohbgcol
         end label

         // update next button row position only with a extra gap.
         nRow += th_w_ctrlgap

      endif

   next i

return nil


// error message, Unable To Open file
static function Uto_file(cFname)
   MsgInfo("Unable to open file <"+ alltrim(cFname)+">."+ crlf + crlf + ;
             "The file or folder name is incorrect or the file no longer exists.")
return nil


//
// Function : ORDCLOSE( [order number to close] )
//
// Purpose  : close a index
//
// Args     : index order number to close
//
// Returns  : the controlling ordernumber
//
// Rem      : - if no Alias name is passed the current area will be used
//            - if no index number is passed to last index file well be closed.
//            - the current area, index and record number are saved on entry and restored on exit.
//
// Attention: - If you close the index that had the focus the new focus will be order number 1.
//            - The record is always positioned on the one that was active before closing.
//              This is also the case if all index files are closed.
//
// Example  : use test.dbf alias TEST new
//            set index to index1.cxd, index2.cdx, index3.cdx
//
//            ORDCLOSE()      will close last index thus index3.cdx in the current area
//            ORDCLOSE(2)     will close index2.cdx in the current area
//                            after it open index order will be, index1.cdx, index3.cdx
//
//            (cAlias)->ORDCLOSE(1)  will close index file number 1 in area cAlias
//
static function ORDCLOSE(nIndexToClose)

   local i, nOldRec, nOldOrdFocus, aIndex := {}

   // Default index nbr to close will be the last index file if not passed.
   if nIndexToClose == nil
      nIndexToClose := sx_indexcount()
   endif

   // debug
   //msgstop(Alias() + ", close index : " + hb_ntos(nIndexToClose))
   //msgstop("Current index number : " + hb_ntos(IndexOrd()) )

   // DO NOTHING if number of index to close is > than the number of open index files.
   if nIndexToClose <= sx_IndexCount()

      // save area context
      nOldRec := recno()
      nOldOrdFocus := IndexOrd()

      // fill array with all open index file names without the one to close.
      for i := 1 to sx_IndexCount()
         if i <> nIndexToClose
            aadd( aIndex, alltrim(Sx_IndexName(i)) )
         endif
      next i
      //msginfo(aIndex)

      // close all index files
      ORDLISTCLEAR()

      // and reopen them without the one that has been closed.
      aeval(aIndex, { |i| OrdListAdd( i ) } )   // dbsetindex() is always ADDITIVE

      // Now, the controlling order is always the first opened index file (if any)
      //   see OrdListAdd()

      // restore area context
      if sx_IndexCount() > 1
         ORDSETFOCUS( if( nIndexToClose == nOldOrdFocus, 1, nOldOrdFocus ) )
      endif
      DBGOTO(nOldrec)

   endif

   // return controlling index number
return Indexord()


// open the "dataset" table always in area nr assigned to it in the settings menu
//   EXCLUSIVE (pack is used sometimes)
//   and ALWAYS via DBFCDX
static function Open_dstable()

   local lError := .T.

   // open it
   TRY
      select (ini_Otisdb_area_nr)
      USE (fn_ds_table) ALIAS ds_table EXCLUSIVE VIA 'DBFCDX'   // no codepage option used, default program/system codepage is used if not passed.

      //msgstop('Otis_ds.dbf is opened in select : ' + hb_ntos(select()) )

   // error, impossible to open OTIS_DS.DBF
   CATCH oError
      msgstop("The dataset table OTIS_DS.DBF could not be opened."+crlf+crlf+Errormessage(oError))
      lError := .F.
   END

return lError


// return a array with the contents of all fields
static FUNCTION Scatter()

  LOCAL aRecord[ fcount() ]

RETURN AEval( aRecord, {|x,n| aRecord[n] := FieldGet( n ), x := NIL } )


// copy the contents of a array to the current record
/*
static FUNCTION Gather( paRecord )

RETURN AEval( paRecord, {|x,n| FieldPut( n, x ) } )
*/


//
// calc COL right uppper corner of a control in function
// of width of passed control
//
static function col_right_off( Windowname, cControlname )

   local nNewCol

   nNewCol := getproperty(Windowname, cControlname ,"col") + getproperty(Windowname, cControlname,"width")

return nNewCol


//
// calc Row left down corner of a control in function
// of height of passed controlname
//
static function row_below_off( Windowname, cControlname )

   local nNewRow

   nNewRow := getproperty(Windowname, cControlname ,"row") + getproperty(Windowname, cControlname,"height")

return nNewRow


// Show table info form
static function show_info(cTablename, cInfo, lModal)

   // construct a new window id name so that multiple windows can be opened
   local form_tii := 'form_tii_' + hb_ntos(int(seconds()*100))

   // default non modal window
   default lModal := .T.

   // show index info in a form
   if lModal
      // modal win type
      define window &form_tii ;
         row 200 ;
         col 350 ;
         Clientarea 500, MIN(th_w_ctrlgap * 2 + th_bt_height + mlcount(cInfo) * 14 + 60, GetDesktopHeight() - 350 ) ;   // 14 = fontsize + spacing (defined by test), 50 window borders
         TITLE cTablename ;
         BACKCOLOR th_w_bgcolor ;
         WINDOWTYPE MODAL ;
         ON SIZE     show_info_resize()
         /*
         ON MAXIMIZE show_info_resize() ;
         ON MINIMIZE show_info_resize()
         */

   // standard win type
   else
      define window &form_tii ;
         AT 200, 350 ;
         Clientarea 500, MIN(th_w_ctrlgap * 2 + th_bt_height + mlcount(cInfo) * 14 + 60, GetDesktopHeight() - 350 ) ;   // 14 = fontsize + spacing (defined by test), 50 window borders
         TITLE cTablename ;
         BACKCOLOR th_w_bgcolor ;
         WINDOWTYPE STANDARD ;
         ON SIZE     show_info_resize() ;
         ON MAXIMIZE show_info_resize() ;
         ON MINIMIZE show_info_resize()
   endif

      // show in a RICHEDITBOX
      DEFINE RICHEDITBOX rtb_tii
         row th_w_ctrlgap
         col th_w_ctrlgap
         width  ThisWindow.ClientWidth  - th_w_ctrlgap * 2
         height ThisWindow.ClientHeight - th_bt_height - th_w_ctrlgap * 3
         Value cInfo
         readonly .T.
         //PLAINTEXT .F.
      end RICHEDITBOX

      // Quit button
      DEFINE LABEL bt_Quit
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL getproperty(ThisWindow.name,"ClientWidth") - ( th_bt_width + th_w_ctrlgap ) * 1
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "Quit"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         ACTION ThisWindow.release
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
      END label

      // Copy to Clipboard
      DEFINE LABEL bt_Clipboard
         ROW getproperty(ThisWindow.name, "ClientHeight") - th_bt_height - th_w_ctrlgap
         COL getproperty(ThisWindow.name, "ClientWidth") - ( th_bt_width + th_w_ctrlgap ) * 2
         WIDTH th_bt_width //* 1.5
         HEIGHT th_bt_height
         FONTBOLD .T.
         Value "To clipboard"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         ACTION { || CopyToClipboard(cInfo), ;
                     msginfo("Done") }
         FONTCOLOR th_bt_fontcol
         BACKCOLOR th_bt_bgcol
         // font and background color when onhover / onleave
         ONMOUSEHOVER { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_ohbgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_ohfontcol ) }
         ONMOUSELEAVE { || setproperty( ThisWindow.name, This.name, "BACKCOLOR", th_bt_bgcol ),;
                           setproperty( ThisWindow.name, This.name, "FONTCOLOR", th_bt_fontcol ) }
      END label

      // Escape Key
      ON KEY ESCAPE ACTION ThisWindow.Release

   end window

   // activate
   ACTIVATE WINDOW &form_tii

return nil


// Change some control rows,cols on resize of form
static function show_info_resize()

   // update width and height editbox table
   setproperty(ThisWindow.name, "rtb_tii", "Width",  getproperty(ThisWindow.name,"ClientWidth") - th_w_ctrlgap * 2)
   setproperty(ThisWindow.name, "rtb_tii", "Height", getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap * 3 )

   // repos menu button
   setproperty(ThisWindow.name, "bt_Quit","Row", getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap )
   setproperty(ThisWindow.name, "bt_Quit","Col", getproperty(ThisWindow.name,"ClientWidth")  - ( th_bt_width + th_w_ctrlgap ) * 1 )
   setproperty(ThisWindow.name, "bt_Clipboard","Row", getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap )
   setproperty(ThisWindow.name, "bt_Clipboard","Col", getproperty(ThisWindow.name,"ClientWidth")  - ( th_bt_width + th_w_ctrlgap ) * 2 )

return nil

// clear all fields in a record
static FUNCTION db_clrrec( cAlias )
   *
   LOCAL i, temp, cTtype, cFldnm

   *
   FOR i:=1 TO (cAlias)->(FCOUNT())
      *
      cFldnm := (cAlias)->(FIELD(i))                 && get fieldname
      *
      cTtype := TYPE(cFldnm)
      DO CASE
         * Char. or Memo
         CASE cTtype="C" .OR. cTtype = "M"
            temp := ""
         * Num.
         CASE cTtype="N"
            temp := 0
         * Date
         CASE cTtype="D"
            temp := CTOD("  /  /  ")
         * Logical
         CASE cTtype="L"
            temp := .F.
      ENDCASE
      *
      (cAlias)->(FIELDPUT(i, temp))
      *
   NEXT i
   *
RETURN NIL


// Show help window
static function show_help(cInfo, nWidth, nHeight)

   local temp, i, cline
   local nMaxLen  := 0
   local nLinecnt := 0

   // add empty header & footer line for spacing
   cInfo := "|" + cInfo + "|"

   // get number of lines
   nLinecnt := NumToken( cInfo, "|" )

   // replace | with crlf and %T. with tabs
   cInfo := strtran(cInfo, "|", crlf)
   cInfo := strtran(cInfo, " %T1 ", chr(9))
   cInfo := strtran(cInfo, " %T2 ", repl(chr(9),2))

   // get maximum len of all lines
   for i := 1 to nLinecnt
      cLine := alltrim(memoline(cInfo, 254, i))
      if ( temp := len(cLine) ) > nMaxLen
         nMaxLen := temp
      endif
   next i
   //msgstop(nMaxLen)

   // Release form if it is already open,
   //  the menu button is be used as a toggle to open and close this form.
   /* MODAL WINDOW THUS NOT NECESSARY
   if ISWINDOWDEFINED("f_help")
      domethod( "f_help", "RELEASE")
      return nil
   endif
   */

   // draw window
   DEFINE WINDOW f_help ;
      at 0,0 ;
      ; //clientarea nMaxlen * 5.6, nLinecnt * 19 ;
      clientarea nWidth, nHeight ;
      TITLE "OTIS - Info" ;
      NOSIZE ;
      ;//NOMINIMIZE ;
      ;//NOMAXIMIZE ;
      WINDOWTYPE MODAL ;
      BACKCOLOR th_w_bgcolor

      // text box
      define EDITBOX eb_info
         ROW    th_w_ctrlgap
         COL    th_w_ctrlgap
         WIDTH  getproperty(ThisWindow.name,"ClientWidth") - th_w_ctrlgap * 2
         HEIGHT getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap * 3
         value cInfo
         readonly .T.
         NOVSCROLLBAR .T.
         NOHSCROLLBAR .T.
      end editbox

      // "Quit" button
      DEFINE LABEL bt_Quit
         ROW getproperty(ThisWindow.name,"ClientHeight") - th_bt_height - th_w_ctrlgap
         COL getproperty(ThisWindow.name,"ClientWidth") - ( th_bt_width + th_w_ctrlgap ) * 1
         WIDTH th_bt_width
         HEIGHT th_bt_height
         FONTBOLD .T.
         FONTCOLOR th_bt_ohfontcol
         BACKCOLOR th_bt_ohbgcol
         Value "Quit"
         VCENTERALIGN .T.
         CENTERALIGN .T.
         ACTION ThisWindow.release
      END label

      // Escape key, release this window
      ON KEY ESCAPE ACTION ThisWindow.Release

   end window

   //CENTER WINDOW
   setproperty( "f_help","Row", GetDesktopHeight() / 2 - getproperty("f_help", "Height") / 2 - GetTaskBarHeight()- 15 )
   setproperty( "f_help","Col", GetDesktopWidth() / 2  - getproperty("f_help", "Width") / 2 -15 )

   // activate
   ACTIVATE WINDOW f_help

return nil

//***********************************************************************************************************************************
   * Procedure ------------------------

//******************************************************************************
// Some window / control metrics
//******************************************************************************
//
//   If you change the values below the layout will
//   be fully adapted to your settings after compilation.
//
static function set_theme(cThemeId)

   default cThemeId := "1"

   do case

      case cThemeId == "2"

         th_w_width      := 1000                     // OTIS main window width
         th_w_height     := 500                      // OTIS main window height
         th_w_ctrlgap    := 08                       // OTIS main window border and controls gap
         th_bt_width     := 100                      // menu button width
         th_bt_height    := 24                       // menu button height

         // colors settings for all windows
         th_w_fontcolor  := {255, 255, 255}          // window font color
         th_w_bgcolor    := {185, 185, 185}          // window bg color

         // colors settings for menu buttons and some controls
         th_bt_fontcol   := {255,255,255}            // font color
         th_bt_bgcol     := {004,099,128}            // bg color
         th_bt_ohfontcol := {000,000,000}            // on hover font color
         th_bt_ohbgcol   := {247,122,084}            // on hover bg color

         // colors tbrowse font and line even/odd
         th_fctb_leven  := rgb(000,000,000)
         th_bgtb_leven  := rgb(255,255,255)
         th_fctb_lodd   := rgb(000,000,000)
         th_bgtb_lodd   := rgb(245,245,245)

      // default theme "1", blue, orange
      Otherwise

         th_w_width     := 1000                    // OTIS main window width
         th_w_height    := 500                     // OTIS main window height
         th_w_ctrlgap   := 08                      // OTIS main window border and control gap
         th_bt_width    := 100                     // menu button width
         th_bt_height   := 24                      // menu button height

         // colors settings for all windows
         th_w_fontcolor  :=  {255, 255, 255}         // window font color
         th_w_bgcolor    :=  {65, 65, 65}            // window bg color

         // colors settings for menu buttons and some controls
         th_bt_fontcol   :=  {255,255,255}           // font color
         th_bt_bgcol     :=  {21, 113, 173}          // TEST bg color
         th_bt_ohfontcol :=  {000,000,000}           // on hover font color
         th_bt_ohbgcol   :=  {240, 169, 0}           // on hover bg color

         // colors tbrowse font and line even/odd
         th_fctb_leven  := rgb(000,000,000)
         th_bgtb_leven  := rgb(255,255,255)
         th_fctb_lodd   := rgb(000,000,000)
         th_bgtb_lodd   := rgb(245,245,245)

         // reset theme to 1 because a invalid value is used in the ini file.
         ini_theme := "1"

   endcase

return nil

//
// Read *.INI file
//
// if it doesn't exists create a empty with all needed sections.
//
// Arguments : fname_ini     MUST BE A FULL FILE NAME : disk + path + name + ext
//                           -------------------------
//             necessary for _GetSectionNames and _GetSection functions
//
// Returns   : 0 file not found, a new one with all sections is created.
//             1 file found but some or no section at all are found,
//               they are created if this is the case.
//             2 file found with all sections, no errors.
//
// Remark    : All public var names used in the ini file must be declared
//             and initialized with a default value before calling these functions.
//
static function FREADINI(fname_ini)

   local nStatus := 0
   Local aSections, aItems, cKey, i, p, temp
   local cinilist := crlf

   // init array
   ar_ini := {}

   //
   // init static arrays with sections and keywords and var names used style ini_xxxxxxx
   // also used by fwriteini() below
   //
   // SECTION NAMES AND PUBLIC VAR NAMES
   //
   // A empty public var name indicates the start of a new ini section
   //
   //              Section & Entry                 public var name
   //              -----------------------------  -----------------------
   // [VERSION]
   aadd(ar_ini, { "[VERSION]"                    , ""                          })
   aadd(ar_ini, { "VERSION_VERSION"              , "ini_version"               })
   aadd(ar_ini, { "VERSION_VERSION_BUILD"        , "ini_versionbuild"          })
   aadd(ar_ini, { "VERSION_VERSION_DATE"         , "ini_versiondate"           })

   // [PROGRAM]
   aadd(ar_ini, { "[PROGRAM]"                    , ""                          })
   aadd(ar_ini, { "PROGRAM_LAST_USED_FOLDER"     , "ini_lu_folder"             })
   aadd(ar_ini, { "PROGRAM_LOCKSCHEME"           , "ini_lockscheme"            })
   aadd(ar_ini, { "PROGRAM_THEME"                , "ini_theme"                 })

   // [CMDLINE]
   aadd(ar_ini, { "[CMDLINE]"                    , ""                          })
   aadd(ar_ini, { "CMDLINE_AUTOPEN"              , "ini_cl_autopen"            })
   aadd(ar_ini, { "CMDLINE_EXCLUSIVE"            , "ini_cl_excl"               })

   // [DATABASE]
   aadd(ar_ini, { "[DATABASE]"                   , ""                          })
   aadd(ar_ini, { "DATABASE_DEFAULT_RDD"         , "ini_default_rdd"           })
   aadd(ar_ini, { "DATABASE_DEFAULT_MEM"         , "ini_default_mem"           })
   aadd(ar_ini, { "DATABASE_OPEN_EXCLUSIVE"      , "ini_lOpen_Exclusive"       })
   aadd(ar_ini, { "DATABASE_CODE_PAGE"           , "ini_dbf_codepage"          })
   aadd(ar_ini, { "DATABASE_ORDBAG_AUTOOPEN"     , "ini_ordbag_autoopen"       })

   // [LETODBF]
   aadd(ar_ini, { "[LETODBF]"                    , ""                          })
   aadd(ar_ini, { "LETODBF_LETO_IPSERVER"        , "ini_leto_ipserver"         })
   aadd(ar_ini, { "LETODBF_LETO_PORTSERVER"      , "ini_leto_portserver"       })

   // [AREA]
   aadd(ar_ini, { "[AREA]"                       , ""                          })
   aadd(ar_ini, { "AREA_AREA_OTIS_DS"            , "ini_Otisdb_area_nr"        })
   aadd(ar_ini, { "AREA_AREA_MIN_SCAN"           , "ini_area_min_scan"         })
   aadd(ar_ini, { "AREA_AREA_MAX_SCAN"           , "ini_area_max_scan"         })
   aadd(ar_ini, { "AREA_AREA_PI_REOPEN_START"    , "ini_area_pi_reopen_start"  })

   // [MOSTRECENT]
   aadd(ar_ini, { "[MOSTRECENT]"                 , ""                          })
   aadd(ar_ini, { "MOSTRECENT_DS1"               , "ini_mr_ds1"                })
   aadd(ar_ini, { "MOSTRECENT_DS2"               , "ini_mr_ds2"                })
   aadd(ar_ini, { "MOSTRECENT_DS3"               , "ini_mr_ds3"                })
   aadd(ar_ini, { "MOSTRECENT_DS4"               , "ini_mr_ds4"                })
   aadd(ar_ini, { "MOSTRECENT_DS5"               , "ini_mr_ds5"                })

   // [THEME]
   //aadd(ar_ini, { "[THEME]"                      , ""                          })
   //aadd(ar_ini, { "THEME_W_FONTCOLOR"            , "th_w_fontcolor"            })

   // check if file exists, if not create it with default data initialized in main.
   if !file(fname_ini)
     *MsgStop('Fichier : ' + fname_ini + " pas trouvé.")
     *nStatus := 0
     FWRITEINI(fname_ini)
   endif

   // get data
   if .T.

     aSections := _GetSectionNames(fname_ini)

     if len(aSections) > 0

         for i=1 to len(aSections)

             aItems:=_GetSection(aSections[i],fname_ini)
             if len(aItems)>0

               for p=1 to len(aItems)

                  * get keyword
                  cKey := UPPER( aSections[i] + '_' + aItems[p,1] )
                  cinilist := cinilist + cKey + ':' + aItems[p,2] + crlf

                  * search keyword array
                  temp := ascan(ar_ini, { |ar_val| ar_val[1] == cKey })

                  * if found assign data to var  (macro used)
                  if temp <> 0
                      &(ar_ini[temp,2]) := aItems[p,2]
                      // translate logical values from string to a real logical
                      if aItems[p,2] == "T" .or. aItems[p,2] == "F"
                         &(ar_ini[temp,2]) := &('.'+aItems[p,2]+'.')
                      endif

                  * error message
                  else
                     MsgStop( fname_ini + ' contains a invalid key.' + crlf + ;
                              'Item : ' + cKey )
                  endif

                  nStatus := 2

               next p

             endif

         next i

     // file exists but has no sections
     else
         MsgStop( 'Ini file : ' + fname_ini +CRLF +"has no sections and cannot be used.")
         nStatus := 1
         // create a new one
         FWRITEINI(fname_ini)
     endif

   endif

RETURN nStatus


//
// Write *.INI file
//
STATIC FUNCTION FWRITEINI(fname_ini)

   local temp, i, cSection := "", cEntry := ""


   // save all params in INI file
   BEGIN INI FILE fname_ini

      for i := 1 to len(ar_ini)

         * get keyword
         temp := ar_ini[i, 1]

        // debug
        *msginfo("keyword : " + temp)

         * section if keyword starts with '['
         if left(temp,1) == '['
            cSection := strtran(strtran(temp,'[',''),']','')

         * else it is a entry, thus save its keyword and his value
         else
            temp := at('_',ar_ini[i,1])
            cEntry := substr( ar_ini[i,1], temp+1 )
            *
            SET SECTION cSection ;
            ENTRY cEntry ;
            TO &(ar_ini[i,2])
         endif

      next i

   END INI

return nil


//***********************************************************************************************************************************
   * Procedure ------------------------

//
// This function Errormessage(oError) is a exact copy of
//               Errormessage() in source file C:\MiniGUI\SOURCE\Errorsys.prg
//
*-----------------------------------------------------------------------------*
STATIC FUNCTION ErrorMessage( oError )
*-----------------------------------------------------------------------------*

   // start error message
   LOCAL cMessage := iif( oError:severity > ES_WARNING, "Error", "Warning" ) + " "
   LOCAL n

   // add subsystem name if available
   IF ISCHARACTER( oError:subsystem )
      cMessage += oError:subsystem()
   ELSE
      cMessage += "???"
   ENDIF

   // add subsystem's error code if available
   IF ISNUMBER( oError:subCode )
      cMessage += "/" + hb_ntos( oError:subCode )
   ELSE
      cMessage += "/???"
   ENDIF

   // add error description if available
   IF ISCHARACTER( oError:description )
      cMessage += "  " + oError:description
   ENDIF

   // add either filename or operation
   DO CASE
   CASE !Empty( oError:filename )
      cMessage += ": " + oError:filename
   CASE !Empty( oError:operation )
      cMessage += ": " + oError:operation
   ENDCASE

   // add OS error code if available
   IF !Empty( oError:osCode )
      cMessage += " (DOS Error " + hb_ntos( oError:osCode ) + ")"
   ENDIF

   IF ValType( oError:args ) == "A"
      cMessage += CRLF
      cMessage += "   Args:" + CRLF
      FOR n := 1 TO Len( oError:args )
         cMessage += ;
            "     [" + hb_ntos( n, 2 ) + "] = " + ValType( oError:args[ n ] ) + ;
            "   " + cValToChar( cValToChar( oError:args[ n ] ) ) + ;
            iif( ValType( oError:args[ n ] ) == "A", " length: " + ;
            hb_ntos( Len( oError:args[ n ] ) ), "" ) + iif( n < Len( oError:args ), CRLF, "" )
      NEXT
   ENDIF

RETURN cMessage
