//+------------------------------------------------------------------+
//| Globals.mqh                                                       |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

//+------------------------------------------------------------------+
//| Global Variables                                                   |
//+------------------------------------------------------------------+

// Trade objects
CTrade         trade;
CPositionInfo  position_info;
COrderInfo     order_info;
CSymbolInfo    symbol_info;
CAccountInfo   account_info;

// Data arrays
StructuralPoint g_pe_array[];
InterestZone    g_zi_array[];
GrandZone       g_grand_zones[];
PatternInfo     g_patterns[];
BrakePending    g_brake_pending[];

int             g_pe_count     = 0;
int             g_zi_count     = 0;
int             g_gz_count     = 0;
int             g_pat_count    = 0;
int             g_brake_count  = 0;

// Trade context
TradeContext    g_context;

// Indicator handle
int             g_atr_handle   = INVALID_HANDLE;

// New bar detection
datetime        g_last_bar_time = 0;
int             g_bar_count     = 0;    // Total bars processed since init

// Time control
int             g_slot1_start_hour, g_slot1_start_min;
int             g_slot1_end_hour,   g_slot1_end_min;
int             g_slot2_start_hour, g_slot2_start_min;
int             g_slot2_end_hour,   g_slot2_end_min;
int             g_close_hour,       g_close_min;

// Symbol info cache
double          g_point;
int             g_digits;
double          g_tick_size;
double          g_tick_value;
int             g_stops_level;         // Minimum distance for SL/TP in points

// Debug logger
bool            g_is_tester    = false;
int             g_log_handle   = INVALID_HANDLE;
string          g_log_filename = "";
//+------------------------------------------------------------------+
