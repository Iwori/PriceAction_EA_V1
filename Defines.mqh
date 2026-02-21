//+------------------------------------------------------------------+
//| Defines.mqh                                                       |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

//+------------------------------------------------------------------+
//| Defines                                                           |
//+------------------------------------------------------------------+
#define EA_NAME           "PriceAction EA"
#define EA_VERSION        "1.00"
#define MAX_ZONES         200
#define MAX_PE            200
#define MAX_PATTERNS      10
#define MAX_PENDING       2
#define MAX_GRAND_ZONES   50
#define PE_LOOKBACK       4      // Candles to check for empty spaces
#define ZONE_EXPIRE_DEF   80     // Default zone expiration candles
#define WAIT_CANDLES_DEF  13     // Default wait after loss
#define ATR_PERIOD_DEF    20     // Default ATR period
#define TP_RATIO_DEF      4.2   // Default TP/SL ratio
#define IMPULSE_MIN_BARS  4      // Min bars for impulse (Pattern 3 rule 1.6.4)
#define PE_SCAN_NORMAL    8      // Normal PE scan depth each new bar
#define PE_SCAN_INIT      90     // Deep scan on first bar: must cover zone expiration window + margin
#define ZI_SCAN_NORMAL    10     // Normal zone scan depth each new bar
#define ZI_SCAN_INIT      90     // Deep scan on first bar: must cover zone expiration window + margin
#define BRAKE_MAX_LEN     7      // Max candles in a brake formation (5 brake + 2 bookends)
#define PE_LINE_BARS      10     // PE level line length in bars
//+------------------------------------------------------------------+
