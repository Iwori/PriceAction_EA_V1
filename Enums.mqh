//+------------------------------------------------------------------+
//| Enums.mqh                                                         |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+

// Candle classification
enum ENUM_CANDLE_TYPE
{
   CANDLE_BULLISH = 0,   // Close > Open
   CANDLE_BEARISH = 1,   // Close < Open
   CANDLE_DOJI    = 2    // Close == Open
};

// Interest zone base type
enum ENUM_ZI_BASE
{
   ZI_BASE_PE     = 0,   // Based on structural point
   ZI_BASE_BRAKE  = 1,   // Based on brake (frenazo)
   ZI_BASE_BOTH   = 2    // Both PE and brake
};

// Direction for zones, PE, patterns
enum ENUM_DIRECTION
{
   DIR_BULLISH = 0,      // Bullish
   DIR_BEARISH = 1       // Bearish
};

// Structural point type
enum ENUM_PE_TYPE
{
   PE_NORMAL = 0,        // Normal: 1 empty space on at least one side
   PE_STRICT = 1         // Strict: 2+ empty spaces on both sides
};

// Zone mitigation state
enum ENUM_ZI_STATE
{
   ZI_ACTIVE          = 0,  // Fully active, never mitigated
   ZI_PARTIAL         = 1,  // Partially mitigated (reduced zone)
   ZI_MITIGATED       = 2,  // Completely mitigated (dead)
   ZI_EXPIRED         = 3   // Expired after N candles
};

// Pattern type
enum ENUM_PATTERN_TYPE
{
   PATTERN_2 = 2,        // Pattern 2
   PATTERN_3 = 3         // Pattern 3
};

// Pattern analysis state
enum ENUM_PATTERN_STATE
{
   PAT_NONE           = 0,  // No pattern
   PAT_FORMATION      = 1,  // Formation detected, analyzing
   PAT_WAITING_BREAK  = 2,  // Pattern 3: waiting for break above/below ZI
   PAT_CONFIRMED      = 3,  // Pattern confirmed, calculating entry
   PAT_PENDING        = 4,  // Order placed, waiting activation
   PAT_ACTIVE         = 5,  // Trade is active (open position)
   PAT_CANCELLED      = 6,  // Cancelled by rules
   PAT_CLOSED         = 7   // Trade closed (SL/TP/manual)
};

// Trade direction
enum ENUM_TRADE_DIR
{
   TRADE_LONG  = 0,      // Buy / Buy Limit
   TRADE_SHORT = 1       // Sell / Sell Limit
};

// Breakeven stage
enum ENUM_BE_STAGE
{
   BE_NONE       = 0,    // No BE yet
   BE_STAGE_1    = 1,    // Ratio 1:1.3 reached or 2 strict PE, SL can move to ZI/PE but not past entry
   BE_STAGE_2    = 2     // Ratio 1:3 reached, SL can move past entry level
};

// Entry type
enum ENUM_ENTRY_TYPE
{
   ENTRY_MARKET = 0,     // Market order (direct entry)
   ENTRY_LIMIT  = 1      // Limit order (23%, 38%, 50%, 61%)
};
//+------------------------------------------------------------------+
