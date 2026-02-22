//+------------------------------------------------------------------+
//| Pattern2.mqh                                                      |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

// Phase 4: Pattern 2 =======================================================

//+------------------------------------------------------------------+
//| Detect Pattern 2 formations on bar[1] (just closed)                |
//+------------------------------------------------------------------+
void DetectPattern2()
{
   int available = iBars(_Symbol, PERIOD_CURRENT);
   if(available < 6) return; // Need at least 6 bars for formation + 2 prev
   
   // Check for engulfing at bar[1]
   // Formation: [close_bar] + [engulfing] where engulfing = bar[1]
   // Or: [close_bar] + [doji] + [engulfing] where engulfing = bar[1]
   
   ENUM_CANDLE_TYPE eng_type = GetCandleType(1);
   if(eng_type == CANDLE_DOJI) return; // Engulfing can't be doji
   
   // Try 2-candle formation: bar[2] + bar[1]
   TryPattern2Formation(2, -1, 1);
   
   // Try 3-candle formation: bar[3] + bar[2](doji) + bar[1]
   if(available >= 7 && GetCandleType(2) == CANDLE_DOJI)
      TryPattern2Formation(3, 2, 1);
}

//+------------------------------------------------------------------+
//| Try Pattern 2 formation: close_shift + (doji_shift) + eng_shift    |
//+------------------------------------------------------------------+
void TryPattern2Formation(int close_shift, int doji_shift, int eng_shift)
{
   ENUM_CANDLE_TYPE close_type = GetCandleType(close_shift);
   ENUM_CANDLE_TYPE eng_type   = GetCandleType(eng_shift);
   
   if(close_type == CANDLE_DOJI) return;
   
   // Determine direction
   ENUM_DIRECTION zi_dir;
   ENUM_TRADE_DIR trade_dir;
   
   if(close_type == CANDLE_BEARISH && eng_type == CANDLE_BULLISH)
   {
      zi_dir    = DIR_BULLISH;  // Close in bullish ZI
      trade_dir = TRADE_LONG;   // Buy
   }
   else if(close_type == CANDLE_BULLISH && eng_type == CANDLE_BEARISH)
   {
      zi_dir    = DIR_BEARISH;  // Close in bearish ZI
      trade_dir = TRADE_SHORT;  // Sell
   }
   else return; // Invalid combination
   
   // Engulfing check: engulfing body > previous candle body
   int compare_shift = close_shift;
   
   double eng_body = GetBodySize(eng_shift);
   double prev_body = GetBodySize(compare_shift);
   if(eng_body <= prev_body) return; // Not engulfing
   
   // Check if close candle CLOSES within a valid ZI
   double close_price = iClose(_Symbol, PERIOD_CURRENT, close_shift);
   int zi_idx = FindZoneAtClose(close_price, zi_dir);
   
   // If no zone found, check wick exception (pages 12-13)
   bool wick_exception = false;
   if(zi_idx < 0)
   {
      int mitigated_zi_idx = -1;
      wick_exception = CheckP2WickException(close_shift, zi_dir, close_price, mitigated_zi_idx);
      
      if(!wick_exception)
      {
         // NO zone and NO wick exception → NO pattern 2
         g_logger.LogDecision(StringFormat("P2|NOZONE|%s|bar%d|%.1f",
            (trade_dir == TRADE_LONG) ? "L" : "S", close_shift, close_price));
         return;
      }
      
      // Wick exception valid: use the mitigated zone
      zi_idx = mitigated_zi_idx;
      g_logger.LogDecision(StringFormat("DW|%d|%.1f|zi#%d", close_shift, close_price, zi_idx));
   }
   else
   {
      // Zone found: log for diagnostics
      g_logger.LogDecision(StringFormat("P2|ZONE_OK|%s|bar%d|zi#%d|%.1f-%.1f",
         (trade_dir == TRADE_LONG) ? "L" : "S", close_shift, zi_idx,
         g_zi_array[zi_idx].lower_price, g_zi_array[zi_idx].upper_price));
   }
   
   // Pattern 2 confirmed! Now analyze
   AnalyzePattern2(close_shift, doji_shift, eng_shift, zi_dir, trade_dir, zi_idx, wick_exception);
}

//+------------------------------------------------------------------+
//| Full Pattern 2 analysis: Fibonacci, ZI/PE search, entry calc       |
//+------------------------------------------------------------------+
void AnalyzePattern2(int close_shift, int doji_shift, int eng_shift,
                     ENUM_DIRECTION zi_dir, ENUM_TRADE_DIR trade_dir,
                     int zi_idx, bool wick_exception)
{
   // FIX 3 (Sec 5.6): Check if engulfing bar closes in opposite ZI → cancel
   if(CheckConfirmBarInOppositeZI(eng_shift, trade_dir))
   {
      g_logger.LogDecision(StringFormat("P2|5.6|%s|bar%d",
         (trade_dir == TRADE_LONG) ? "L" : "S", eng_shift));
      return; // Don't create pattern
   }
   
   PatternInfo pat;
   pat.Reset();
   pat.is_valid       = true;
   pat.type           = PATTERN_2;
   pat.trade_dir      = trade_dir;
   pat.state          = PAT_CONFIRMED;
   pat.bar_formation_start = close_shift;
   pat.bar_engulfing  = eng_shift;
   pat.time_confirmed = iTime(_Symbol, PERIOD_CURRENT, eng_shift);
   pat.zi_index       = zi_idx;
   
   // === FIRST FIBONACCI ===
   // 100% = lowest/highest price of formation + 2 prior candles (wicks included)
   // 0% = engulfing close
   
   int first_bar = close_shift + 2; // 2 candles before formation start
   if(doji_shift > 0) first_bar = close_shift + 2; // Still 2 before close_shift
   
   double extreme_100;
   double level_0 = iClose(_Symbol, PERIOD_CURRENT, eng_shift);
   
   // Determine how many bars are in the formation
   int formation_end = eng_shift;
   int formation_start = close_shift;
   
   // Get extreme across formation + 2 prior candles
   int scan_from = formation_start + 2;
   int scan_to   = formation_end;
   
   if(trade_dir == TRADE_LONG)
   {
      // Buy: 100% = lowest price (wicks)
      extreme_100 = DBL_MAX;
      for(int s = scan_from; s >= scan_to; s--)
      {
         if(s < 0) continue;
         extreme_100 = MathMin(extreme_100, iLow(_Symbol, PERIOD_CURRENT, s));
      }
   }
   else
   {
      // Sell: 100% = highest price (wicks)
      extreme_100 = 0;
      for(int s = scan_from; s >= scan_to; s--)
      {
         if(s < 0) continue;
         extreme_100 = MathMax(extreme_100, iHigh(_Symbol, PERIOD_CURRENT, s));
      }
   }
   
   pat.fib_1.level_0   = level_0;
   pat.fib_1.level_100 = extreme_100;
   pat.fib_1.size_pips = PriceToPips(MathAbs(level_0 - extreme_100));
   
   // Calculate key Fib levels
   pat.fib_1.level_123 = CalcFibLevel(level_0, extreme_100, 1.23);
   pat.fib_1.level_140 = CalcFibLevel(level_0, extreme_100, 1.40);
   pat.fib_1.level_175 = CalcFibLevel(level_0, extreme_100, 1.75);
   pat.fib_1.level_200 = CalcFibLevel(level_0, extreme_100, 2.00);
   
   // === PATTERN SIZE vs INDICATOR ===
   pat.indicator_value    = GetIndicatorValue(eng_shift);
   pat.pattern_size_pips  = pat.fib_1.size_pips;
   
   if(pat.indicator_value <= 0)
   {
      g_logger.LogError("P2|ATR=0");
      return;
   }
   
   pat.size_vs_indicator = pat.pattern_size_pips * g_point / pat.indicator_value;
   
   // SL max level: 175% if ratio >= 1, 200% if ratio < 1
   double sl_max_fib = (pat.size_vs_indicator >= 1.0) ? 1.75 : 2.00;
   double sl_max_price = CalcFibLevel(level_0, extreme_100, sl_max_fib);
   
   // === SEARCH FOR ZI AND PE IN RANGE ===
   // ZI: between 100% and 123%
   // PE: between 100% and 140%
   double range_100 = extreme_100;
   double range_123 = pat.fib_1.level_123;
   double range_140 = pat.fib_1.level_140;
   
   int found_zi = FindZIInFibRange(range_100, range_123, zi_dir);
   int found_pe = FindPEInFibRange(range_100, range_140, zi_dir);
   
   pat.has_zi_in_range = (found_zi >= 0);
   pat.has_pe_in_range = (found_pe >= 0);
   pat.pe_index        = found_pe;
   
   // === SECOND FIBONACCI ===
   double new_100;
   
   if(found_pe >= 0)
   {
      // PE found → prioritize PE (even if ZI also exists)
      // Extend to PE wick extremes
      if(trade_dir == TRADE_LONG)
         new_100 = g_pe_array[found_pe].low_extreme;
      else
         new_100 = g_pe_array[found_pe].high_extreme;
      
      // Cap at SL max level
      if(trade_dir == TRADE_LONG)
         new_100 = MathMax(new_100, sl_max_price); // Can't go lower than max SL
      else
         new_100 = MathMin(new_100, sl_max_price); // Can't go higher than max SL
      
      pat.no_zi_no_pe = false;
      g_logger.LogDecision(StringFormat("DP|#%d|%.1f|%.1f", found_pe, new_100, sl_max_price));
   }
   else if(found_zi >= 0)
   {
      // ZI found → extend to zone extreme (consider grand zone)
      double zi_extreme = GetGrandZoneExtreme(found_zi, zi_dir);
      
      if(trade_dir == TRADE_LONG)
      {
         new_100 = zi_extreme; // Lower extreme of bullish zone
         new_100 = MathMax(new_100, sl_max_price); // Cap
      }
      else
      {
         new_100 = zi_extreme; // Upper extreme of bearish zone
         new_100 = MathMin(new_100, sl_max_price); // Cap
      }
      
      pat.no_zi_no_pe = false;
      g_logger.LogDecision(StringFormat("DZ|#%d|%.1f|%.1f", found_zi, new_100, sl_max_price));
   }
   else
   {
      // No ZI and no PE → section 1.5.3 rules
      pat.no_zi_no_pe = true;
      new_100 = CalcP2NoZINoPE(pat, level_0, extreme_100);
      g_logger.LogDecision(StringFormat("DN|%.1f", new_100));
   }
   
   // Build second Fibonacci
   pat.fib_2.level_0   = level_0;
   pat.fib_2.level_100 = new_100;
   pat.fib_2.size_pips = PriceToPips(MathAbs(level_0 - new_100));
   
   // === CALCULATE ENTRY ===
   double entry_ratio;
   
   if(pat.no_zi_no_pe)
   {
      // Use Pattern 2 size (1st Fib) / indicator for entry table
      entry_ratio = pat.pattern_size_pips * g_point / pat.indicator_value;
   }
   else
   {
      // Use 2nd Fibonacci size / indicator for entry table
      entry_ratio = pat.fib_2.size_pips * g_point / pat.indicator_value;
   }
   
   pat.fib_entry_level = GetEntryFibLevel(entry_ratio, 2);
   
   if(pat.fib_entry_level == 0.0)
   {
      // Direct entry (market order) - use level_0 as estimated entry
      // Actual entry price and TP will be recalculated in PlaceMarketOrder()
      pat.entry_type  = ENTRY_MARKET;
      pat.entry_price = level_0;
   }
   else
   {
      // Limit order at Fibonacci level
      pat.entry_type  = ENTRY_LIMIT;
      pat.entry_price = CalcFibLevel(level_0, new_100, pat.fib_entry_level);
   }
   pat.entry_price = NormalizePrice(pat.entry_price);
   
   // === CALCULATE SL ===
   // SL at 100% of new Fibonacci + 5% tolerance
   double sl_base = new_100;
   double sl_distance = MathAbs(level_0 - new_100);
   double tolerance = sl_distance * 0.05;
   
   if(trade_dir == TRADE_LONG)
      pat.sl_price = sl_base - tolerance;
   else
      pat.sl_price = sl_base + tolerance;
   
   pat.sl_price = NormalizePrice(pat.sl_price);
   pat.sl_size_pips = PriceToPips(MathAbs(pat.entry_price - pat.sl_price));
   pat.sl_tolerance = tolerance;
   
   // === CALCULATE TP ===
   double tp_distance = MathAbs(pat.entry_price - pat.sl_price) * inpTpRatio;
   if(trade_dir == TRADE_LONG)
      pat.tp_price = pat.entry_price + tp_distance;
   else
      pat.tp_price = pat.entry_price - tp_distance;
   pat.tp_price = NormalizePrice(pat.tp_price);
   
   // Initialize tracking fields
   pat.highest_close_since = iClose(_Symbol, PERIOD_CURRENT, eng_shift);
   pat.lowest_close_since  = iClose(_Symbol, PERIOD_CURRENT, eng_shift);
   pat.strict_pe_count     = 0;
   pat.bar_last_update     = eng_shift;
   
   // Register pattern
   RegisterPattern(pat);
}

//+------------------------------------------------------------------+
//| Calculate SL level for Pattern 2 when no ZI/PE found (sec 1.5.3)   |
//+------------------------------------------------------------------+
double CalcP2NoZINoPE(PatternInfo &pat, double level_0, double extreme_100)
{
   ENUM_TRADE_DIR dir = pat.trade_dir;
   double fib_100 = extreme_100;
   
   // Check last 70 bars for prior trend
   bool has_trend = false;
   for(int i = 1; i <= 70; i++)
   {
      if(i >= iBars(_Symbol, PERIOD_CURRENT)) break;
      double bar_close = iClose(_Symbol, PERIOD_CURRENT, i);
      double bar_open  = iOpen(_Symbol, PERIOD_CURRENT, i);
      
      if(dir == TRADE_LONG)
      {
         // Bullish pattern: trend exists if any bar closed/opened below 100%
         if(bar_close < fib_100 || bar_open < fib_100)
         { has_trend = true; break; }
      }
      else
      {
         // Bearish pattern: trend exists if any bar closed/opened above 100%
         if(bar_close > fib_100 || bar_open > fib_100)
         { has_trend = true; break; }
      }
   }
   
   pat.has_prior_trend = has_trend;
   double sl_fib_level;
   
   if(has_trend)
   {
      // Pattern 2 size vs 2.5x indicator
      double ratio_25 = pat.pattern_size_pips * g_point / pat.indicator_value;
      if(ratio_25 < 2.5)
         sl_fib_level = 1.40;
      else
         sl_fib_level = 1.23;
   }
   else
   {
      // No prior trend
      sl_fib_level = 1.15;
   }
   
   g_logger.LogDecision(StringFormat("DN|%s|%.2f",
      has_trend ? "Y" : "N", sl_fib_level));
   
   return CalcFibLevel(level_0, extreme_100, sl_fib_level);
}
//+------------------------------------------------------------------+
