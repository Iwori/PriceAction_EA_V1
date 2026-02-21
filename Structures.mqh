//+------------------------------------------------------------------+
//| Structures.mqh                                                    |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+

// Structural Point data
struct StructuralPoint
{
   bool           is_valid;          // Whether this PE is active/valid
   ENUM_DIRECTION direction;         // Bullish or Bearish
   ENUM_PE_TYPE   pe_type;           // Normal or Strict
   double         level;             // PE level price
   double         high_extreme;      // Highest price of PE candles (wicks included)
   double         low_extreme;       // Lowest price of PE candles (wicks included)
   int            empty_left;        // Empty spaces found on left side (0-4)
   int            empty_right;       // Empty spaces found on right side (0-4)
   int            bar_index_first;   // Bar index of first candle in formation
   int            bar_index_last;    // Bar index of last candle in formation
   datetime       time_created;      // Time when PE was confirmed (right space created)
   int            bar_created;       // Bar index when PE was confirmed
   bool           has_doji;          // Whether formation includes a Doji
   datetime       time_first;        // Time of first candle in formation (permanent ID)
   datetime       time_last;         // Time of last candle in formation (permanent ID)
   
   void Reset()
   {
      is_valid = false;
      direction = DIR_BULLISH;
      pe_type = PE_NORMAL;
      level = 0;
      high_extreme = 0;
      low_extreme = 0;
      empty_left = 0;
      empty_right = 0;
      bar_index_first = -1;
      bar_index_last = -1;
      time_created = 0;
      bar_created = -1;
      has_doji = false;
      time_first = 0;
      time_last = 0;
   }
};

// Interest Zone data
struct InterestZone
{
   bool           is_valid;          // Zone exists and is not expired/fully mitigated
   ENUM_DIRECTION direction;         // Bullish or Bearish
   ENUM_ZI_BASE   base_type;        // PE-based, Brake-based, or both
   ENUM_ZI_STATE  state;            // Active, partial, mitigated, expired
   double         upper_price;       // Upper extreme of zone
   double         lower_price;       // Lower extreme of zone
   double         original_upper;    // Original upper before partial mitigation
   double         original_lower;    // Original lower before partial mitigation
   int            bar_created;       // Bar index when zone was confirmed
   datetime       time_created;      // Time when zone was confirmed
   int            bar_creator;       // Bar index of the candle that creates the zone
   int            candles_alive;     // Counter for expiration (incremented each new bar)
   int            pe_index;          // Index in PE array if PE-based (-1 if not)
   bool           includes_doji;     // If PE-based with Doji, Doji is part of zone
   datetime       time_creator;      // Time of the candle that creates/confirms the zone
   
   void Reset()
   {
      is_valid = false;
      direction = DIR_BULLISH;
      base_type = ZI_BASE_PE;
      state = ZI_ACTIVE;
      upper_price = 0;
      lower_price = 0;
      original_upper = 0;
      original_lower = 0;
      bar_created = -1;
      time_created = 0;
      bar_creator = -1;
      candles_alive = 0;
      pe_index = -1;
      includes_doji = false;
      time_creator = 0;
   }
};

// Grand Zone: overlapping zones treated as one
struct GrandZone
{
   bool           is_valid;
   ENUM_DIRECTION direction;
   double         upper_price;       // Upper extreme of combined zones
   double         lower_price;       // Lower extreme of combined zones
   int            zone_indices[];    // Indices of zones that form this grand zone
   int            zone_count;        // Number of zones in this group
   
   void Reset()
   {
      is_valid = false;
      direction = DIR_BULLISH;
      upper_price = 0;
      lower_price = 0;
      ArrayResize(zone_indices, 0);
      zone_count = 0;
   }
};

// Fibonacci analysis data
struct FibonacciData
{
   double         level_0;           // 0% level (engulfing close / pattern extreme)
   double         level_100;         // 100% level (pattern low/high)
   double         size_pips;         // Size in pips from 0% to 100%
   double         level_123;         // 123% level
   double         level_140;         // 140% level
   double         level_175;         // 175% level
   double         level_200;         // 200% level
   
   void Reset()
   {
      level_0 = 0;
      level_100 = 0;
      size_pips = 0;
      level_123 = 0;
      level_140 = 0;
      level_175 = 0;
      level_200 = 0;
   }
};

// Pattern data
struct PatternInfo
{
   bool              is_valid;
   ENUM_PATTERN_TYPE type;              // Pattern 2 or 3
   ENUM_TRADE_DIR    trade_dir;         // Long or Short
   ENUM_PATTERN_STATE state;
   ENUM_ENTRY_TYPE   entry_type;        // Market or Limit
   
   // Formation bars
   int               bar_formation_start; // First bar of formation
   int               bar_engulfing;       // Engulfing bar (P2) or break bar (P3)
   datetime          time_confirmed;
   
   // Fibonacci data
   FibonacciData     fib_1;             // First Fibonacci (pattern size)
   FibonacciData     fib_2;             // Second Fibonacci (adjusted with ZI/PE)
   double            pattern_size_pips;  // Pattern size in pips
   double            pattern_size_extended_pips; // Extended pattern size (P3 with overlapping ZI)
   
   // Indicator value
   double            indicator_value;    // ATR value at engulfing/first candle
   double            size_vs_indicator;  // pattern_size / indicator_value
   
   // Trade levels
   double            entry_price;
   double            sl_price;
   double            tp_price;
   double            sl_size_pips;
   double            fib_entry_level;    // Fibonacci % for entry (0, 0.23, 0.38, 0.50, 0.61)
   double            sl_tolerance;       // 5% tolerance on SL
   
   // Relevant ZI/PE
   int               zi_index;           // Zone that triggered the pattern (-1 if none)
   int               pe_index;           // PE near pattern (-1 if none)
   bool              has_zi_in_range;    // ZI found between 100-123%
   bool              has_pe_in_range;    // PE found between 100-140%
   bool              no_zi_no_pe;        // Rule 1.5.3 / no ZI no PE case
   bool              has_prior_trend;    // For P2 rule 1.5.3: trend in last 70 bars
   
   // Pattern 3 specific
   double            p3_zi_size_pips;    // Size of ZI reacting to
   bool              p3_has_zi_overlap;  // ZI overlaps with P3 frenazo
   int               p3_impulse_bars;    // Previous impulse bar count (rule 1.6.4)
   double            p3_impulse_vs_indicator; // Impulse size / indicator at midpoint
   
   // Cancellation tracking
   double            highest_close_since;  // Highest bull close since confirmation (for buy)
   double            lowest_close_since;   // Lowest bear close since confirmation (for sell)
   int               strict_pe_count;      // Strict PE count after pattern (cancel at 2)
   int               bar_last_update;      // Last bar this pattern was updated
   int               retry_count;          // Retry counter for failed order placement
   
   // Order tracking
   ulong             ticket;              // Order/position ticket
   
   void Reset()
   {
      is_valid = false;
      type = PATTERN_2;
      trade_dir = TRADE_LONG;
      state = PAT_NONE;
      entry_type = ENTRY_LIMIT;
      bar_formation_start = -1;
      bar_engulfing = -1;
      time_confirmed = 0;
      fib_1.Reset();
      fib_2.Reset();
      pattern_size_pips = 0;
      pattern_size_extended_pips = 0;
      indicator_value = 0;
      size_vs_indicator = 0;
      entry_price = 0;
      sl_price = 0;
      tp_price = 0;
      sl_size_pips = 0;
      fib_entry_level = 0;
      sl_tolerance = 0;
      zi_index = -1;
      pe_index = -1;
      has_zi_in_range = false;
      has_pe_in_range = false;
      no_zi_no_pe = false;
      has_prior_trend = false;
      p3_zi_size_pips = 0;
      p3_has_zi_overlap = false;
      p3_impulse_bars = 0;
      p3_impulse_vs_indicator = 0;
      highest_close_since = 0;
      lowest_close_since = DBL_MAX;
      strict_pe_count = 0;
      bar_last_update = -1;
      retry_count = 0;
      ticket = 0;
   }
};

// Trade context: global EA state
struct TradeContext
{
   bool           is_busy;              // Monotask: position open on this symbol
   ulong          active_ticket;        // Active position ticket (0 if none)
   ENUM_TRADE_DIR active_direction;     // Direction of active position
   
   // Pending orders
   int            pending_count;        // Number of pending orders (max 2)
   ulong          pending_tickets[];    // Pending order tickets
   
   // Post-loss waiting
   bool           is_waiting_after_loss;
   int            wait_candles_remaining;
   int            bar_last_loss;        // Bar index of last loss
   
   // Daily loss tracking
   double         daily_loss_eur;       // Accumulated daily loss in EUR
   double         daily_balance_start;  // Balance at start of day
   datetime       last_daily_reset;     // Last date when daily loss was reset
   
   // Breakeven tracking (for active position)
   ENUM_BE_STAGE  be_stage;
   int            strict_pe_since_entry; // Strict PE formed since entry
   double         entry_price_active;    // Entry price of active position
   double         sl_price_active;       // Current SL of active position
   double         tp_price_active;       // Current TP of active position
   
   // Pattern priority: last 3 patterns per direction
   int            recent_long_patterns[];  // Indices in pattern array (up to 3)
   int            recent_short_patterns[]; // Indices in pattern array (up to 3)
   
   void Reset()
   {
      is_busy = false;
      active_ticket = 0;
      active_direction = TRADE_LONG;
      pending_count = 0;
      ArrayResize(pending_tickets, 0);
      is_waiting_after_loss = false;
      wait_candles_remaining = 0;
      bar_last_loss = -1;
      daily_loss_eur = 0;
      daily_balance_start = 0;
      last_daily_reset = 0;
      be_stage = BE_NONE;
      strict_pe_since_entry = 0;
      entry_price_active = 0;
      sl_price_active = 0;
      tp_price_active = 0;
      ArrayResize(recent_long_patterns, 0);
      ArrayResize(recent_short_patterns, 0);
   }
};

// Brake formation pending confirmation (waiting for break)
struct BrakePending
{
   bool           is_valid;
   ENUM_DIRECTION direction;         // Bullish or Bearish
   double         brake_high;        // Highest price of brake candles (wicks) - break level for bullish
   double         brake_low;         // Lowest price of brake candles (wicks) - break level for bearish
   double         brake_close_limit; // Close price limit for invalidation
   double         zone_upper;        // Zone upper extreme (from brake candles)
   double         zone_lower;        // Zone lower extreme (from brake candles)
   datetime       time_first;        // Time of first candle in formation (for dedup)
   datetime       time_last;         // Time of last candle in formation (for dedup)
   datetime       time_creator;      // Will be set to the candle that breaks the level
   
   void Reset()
   {
      is_valid = false;
      direction = DIR_BULLISH;
      brake_high = 0;
      brake_low = 0;
      brake_close_limit = 0;
      zone_upper = 0;
      zone_lower = 0;
      time_first = 0;
      time_last = 0;
      time_creator = 0;
   }
};
//+------------------------------------------------------------------+
