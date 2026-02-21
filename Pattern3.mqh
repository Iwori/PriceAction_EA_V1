//+------------------------------------------------------------------+
//| Pattern3.mqh                                                      |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

// Phase 5: Pattern 3 =======================================================

//+------------------------------------------------------------------+
//| Detect Pattern 3 initial formation on bar[1]                       |
//| Formation: candle closes in opposite ZI + frenazo candle           |
//+------------------------------------------------------------------+
void DetectPattern3()
{
   int available = iBars(_Symbol, PERIOD_CURRENT);
   if(available < 5) return;
   
   // Check bar[2] = candle that closes in ZI, bar[1] = frenazo
   ENUM_CANDLE_TYPE bar2_type = GetCandleType(2);
   ENUM_CANDLE_TYPE bar1_type = GetCandleType(1);
   
   if(bar2_type == CANDLE_DOJI) return; // First candle must be directional
   
   // Pattern 3 for BUYS: bullish candle closes in bearish ZI + bearish/doji frenazo
   if(bar2_type == CANDLE_BULLISH && (bar1_type == CANDLE_BEARISH || bar1_type == CANDLE_DOJI))
   {
      double close_bar2 = iClose(_Symbol, PERIOD_CURRENT, 2);
      int zi_idx = FindZoneAtClose(close_bar2, DIR_BEARISH);
      
      // FIX 2: Wick exception requires real mitigated zone
      if(zi_idx < 0)
      {
         int mitigated_zi_idx = -1;
         bool wick_ok = CheckP2WickException(2, DIR_BEARISH, close_bar2, mitigated_zi_idx);
         
         if(wick_ok && mitigated_zi_idx >= 0)
            zi_idx = mitigated_zi_idx; // Use real mitigated zone data
         else
            zi_idx = -1; // No valid zone → no P3
      }
      
      if(zi_idx >= 0)
         InitPattern3(2, 1, DIR_BEARISH, TRADE_LONG, zi_idx);
   }
   
   // Pattern 3 for SELLS: bearish candle closes in bullish ZI + bullish/doji frenazo
   if(bar2_type == CANDLE_BEARISH && (bar1_type == CANDLE_BULLISH || bar1_type == CANDLE_DOJI))
   {
      double close_bar2 = iClose(_Symbol, PERIOD_CURRENT, 2);
      int zi_idx = FindZoneAtClose(close_bar2, DIR_BULLISH);
      
      // FIX 2: Same fix for SELL direction
      if(zi_idx < 0)
      {
         int mitigated_zi_idx = -1;
         bool wick_ok = CheckP2WickException(2, DIR_BULLISH, close_bar2, mitigated_zi_idx);
         
         if(wick_ok && mitigated_zi_idx >= 0)
            zi_idx = mitigated_zi_idx;
         else
            zi_idx = -1;
      }
      
      if(zi_idx >= 0)
         InitPattern3(2, 1, DIR_BULLISH, TRADE_SHORT, zi_idx);
   }
}

//+------------------------------------------------------------------+
//| Initialize a Pattern 3 in WAITING_BREAK state                      |
//+------------------------------------------------------------------+
void InitPattern3(int close_shift, int brake_shift, ENUM_DIRECTION zi_dir,
                  ENUM_TRADE_DIR trade_dir, int zi_idx)
{
   // Get ZI size for the 2x rule
   // FIX 2: For mitigated zones, use original bounds to get the real size
   double zi_size = 0;
   double zi_upper = 0, zi_lower = 0;
   
   if(zi_idx >= 0)
   {
      // Use original bounds if available (mitigated zones have shrunk current bounds)
      if(g_zi_array[zi_idx].original_upper > 0 && g_zi_array[zi_idx].original_lower > 0)
      {
         zi_upper = g_zi_array[zi_idx].original_upper;
         zi_lower = g_zi_array[zi_idx].original_lower;
      }
      else
      {
         zi_upper = g_zi_array[zi_idx].upper_price;
         zi_lower = g_zi_array[zi_idx].lower_price;
      }
      zi_size = zi_upper - zi_lower;
   }
   
   // FIX 2: Reject if no valid zone size (regardless of zi_idx)
   if(zi_size <= 0)
   {
      g_logger.LogDecision(StringFormat("P3|noZI|idx%d", zi_idx));
      return;
   }
   
   // Measure initial P3 size from frenazo candle
   double p3_high = iHigh(_Symbol, PERIOD_CURRENT, brake_shift);
   double p3_low  = iLow(_Symbol, PERIOD_CURRENT, brake_shift);
   double p3_size = p3_high - p3_low;
   
   // Check 2x rule immediately
   if(p3_size > 2.0 * zi_size)
   {
      g_logger.LogDecision(StringFormat("p3sz|%.0f|%.0f",
         PriceToPips(p3_size), PriceToPips(zi_size)));
      return;
   }
   
   // Create pattern in WAITING_BREAK state
   PatternInfo pat;
   pat.Reset();
   pat.is_valid           = true;
   pat.type               = PATTERN_3;
   pat.trade_dir          = trade_dir;
   pat.state              = PAT_WAITING_BREAK;
   pat.bar_formation_start= close_shift;
   pat.time_confirmed     = 0; // Not yet confirmed
   pat.zi_index           = zi_idx;
   pat.p3_zi_size_pips    = PriceToPips(zi_size);
   pat.pattern_size_pips  = PriceToPips(p3_size);
   
   // Store P3 extremes in fib_1 temporarily
   pat.fib_1.level_0   = p3_high; // Top of P3
   pat.fib_1.level_100 = p3_low;  // Bottom of P3
   
   // FIX 2: Always store ZI bounds for break detection (use original bounds for mitigated)
   pat.highest_close_since = zi_upper;
   pat.lowest_close_since  = zi_lower;
   
   RegisterPattern(pat);
}

//+------------------------------------------------------------------+
//| Update pending Pattern 3: check for break, size growth, cancel     |
//+------------------------------------------------------------------+
void UpdatePendingPattern3()
{
   double bar_close = iClose(_Symbol, PERIOD_CURRENT, 1);
   double bar_high  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double bar_low   = iLow(_Symbol, PERIOD_CURRENT, 1);
   ENUM_CANDLE_TYPE bar_type = GetCandleType(1);
   
   for(int i = 0; i < g_pat_count; i++)
   {
      if(!g_patterns[i].is_valid) continue;
      if(g_patterns[i].type != PATTERN_3) continue;
      if(g_patterns[i].state != PAT_WAITING_BREAK) continue;
      
      ENUM_TRADE_DIR dir = g_patterns[i].trade_dir;
      double p3_top = g_patterns[i].fib_1.level_0;
      double p3_bot = g_patterns[i].fib_1.level_100;
      double zi_size_price = g_patterns[i].p3_zi_size_pips * g_point;
      
      // Update P3 size with new brake-direction candles
      bool is_brake_candle = false;
      if(dir == TRADE_LONG && (bar_type == CANDLE_BEARISH || bar_type == CANDLE_DOJI))
         is_brake_candle = true;
      if(dir == TRADE_SHORT && (bar_type == CANDLE_BULLISH || bar_type == CANDLE_DOJI))
         is_brake_candle = true;
      
      if(is_brake_candle)
      {
         // Extend P3 extremes
         double new_top = MathMax(p3_top, bar_high);
         double new_bot = MathMin(p3_bot, bar_low);
         g_patterns[i].fib_1.level_0   = new_top;
         g_patterns[i].fib_1.level_100 = new_bot;
         
         double new_size = new_top - new_bot;
         g_patterns[i].pattern_size_pips = PriceToPips(new_size);
         
         // Check 2x cancellation (zi_size_price guaranteed > 0 by InitPattern3 fix)
         if(zi_size_price > 0 && new_size > 2.0 * zi_size_price)
         {
            g_patterns[i].state    = PAT_CANCELLED;
            g_patterns[i].is_valid = false;
            g_logger.LogCancel(StringFormat("P3 size %.1f > 2x ZI %.1f",
               PriceToPips(new_size), g_patterns[i].p3_zi_size_pips), i);
            continue;
         }
      }
      
      // Check for break confirmation
      bool confirmed = false;
      if(dir == TRADE_LONG)
      {
         // Need candle to close ABOVE upper extreme of bearish ZI
         double zi_upper = g_patterns[i].highest_close_since;
         if(bar_close > zi_upper) confirmed = true;
      }
      else
      {
         // Need candle to close BELOW lower extreme of bullish ZI  
         double zi_lower = g_patterns[i].lowest_close_since;
         if(bar_close < zi_lower) confirmed = true;
      }
      
      if(confirmed)
      {
         g_logger.LogDecision(StringFormat("P3K|#%d|%.1f", i, bar_close));
         g_patterns[i].bar_engulfing    = 1; // The break bar
         g_patterns[i].time_confirmed   = iTime(_Symbol, PERIOD_CURRENT, 1);
         AnalyzePattern3(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Full Pattern 3 analysis after break confirmation                   |
//+------------------------------------------------------------------+
void AnalyzePattern3(int pat_idx)
{
   
   double p3_top = g_patterns[pat_idx].fib_1.level_0;
   double p3_bot = g_patterns[pat_idx].fib_1.level_100;
   ENUM_TRADE_DIR dir = g_patterns[pat_idx].trade_dir;
   
   // FIX 3 (Sec 5.6): Check if break bar closes in opposite ZI → cancel
   if(CheckConfirmBarInOppositeZI(1, dir))
   {
      g_patterns[pat_idx].state    = PAT_CANCELLED;
      g_patterns[pat_idx].is_valid = false;
      g_logger.LogCancel("P3 sec 5.6: break bar in opposite ZI", pat_idx);
      return;
   }
   
   // Check impulse rule 1.6.4
   if(!CheckP3ImpulseRule(pat_idx))
   {
      g_patterns[pat_idx].state    = PAT_CANCELLED;
      g_patterns[pat_idx].is_valid = false;
      g_logger.LogCancel("P3 impulse rule 1.6.4", pat_idx);
      return;
   }
   
   // === FIRST FIBONACCI ===
   if(dir == TRADE_LONG)
   {
      g_patterns[pat_idx].fib_1.level_100 = p3_bot;  // 100% at bottom
      g_patterns[pat_idx].fib_1.level_0   = p3_top;  // 0% at top
   }
   else
   {
      g_patterns[pat_idx].fib_1.level_100 = p3_top;  // 100% at top
      g_patterns[pat_idx].fib_1.level_0   = p3_bot;  // 0% at bottom
   }
   g_patterns[pat_idx].fib_1.size_pips = PriceToPips(p3_top - p3_bot);
   
   // Get indicator value at the first candle of the pattern
   int first_bar_shift = iBarShift(_Symbol, PERIOD_CURRENT,
      iTime(_Symbol, PERIOD_CURRENT, g_patterns[pat_idx].bar_formation_start));
   if(first_bar_shift < 0) first_bar_shift = g_patterns[pat_idx].bar_formation_start;
   
   g_patterns[pat_idx].indicator_value = GetIndicatorValue(first_bar_shift);
   if(g_patterns[pat_idx].indicator_value <= 0)
   {
      g_logger.LogError("P3|ATR=0");
      g_patterns[pat_idx].state = PAT_CANCELLED;
      g_patterns[pat_idx].is_valid = false;
      return;
   }
   
   // === CHECK FOR OVERLAPPING FRIENDLY ZI (amplified size) ===
   ENUM_DIRECTION friendly_dir = (dir == TRADE_LONG) ? DIR_BULLISH : DIR_BEARISH;
   double amp_top = p3_top;
   double amp_bot = p3_bot;
   g_patterns[pat_idx].p3_has_zi_overlap = false;
   
   // Search for friendly ZI that overlaps with the P3 range
   bool found_overlap = true;
   while(found_overlap)
   {
      found_overlap = false;
      for(int z = 0; z < g_zi_count; z++)
      {
         if(!g_zi_array[z].is_valid) continue;
         if(g_zi_array[z].direction != friendly_dir) continue;
         
         // Check overlap with current amplified range
         if(g_zi_array[z].lower_price <= amp_top && g_zi_array[z].upper_price >= amp_bot)
         {
            double new_top = MathMax(amp_top, g_zi_array[z].upper_price);
            double new_bot = MathMin(amp_bot, g_zi_array[z].lower_price);
            
            // Also include any grand zone this ZI belongs to
            double gz_extreme_lo = GetGrandZoneExtreme(z, friendly_dir);
            if(friendly_dir == DIR_BULLISH)
               new_bot = MathMin(new_bot, gz_extreme_lo);
            else
               new_top = MathMax(new_top, gz_extreme_lo);
            
            if(new_top != amp_top || new_bot != amp_bot)
            {
               amp_top = new_top;
               amp_bot = new_bot;
               g_patterns[pat_idx].p3_has_zi_overlap = true;
               found_overlap = true;
            }
         }
      }
   }
   
   double use_size, use_top, use_bot;
   if(g_patterns[pat_idx].p3_has_zi_overlap)
   {
      use_top = amp_top;
      use_bot = amp_bot;
      g_patterns[pat_idx].pattern_size_extended_pips = PriceToPips(amp_top - amp_bot);
      use_size = g_patterns[pat_idx].pattern_size_extended_pips;
      g_logger.LogDecision(StringFormat("p3amp|%.0f|%.0f", use_size, g_patterns[pat_idx].pattern_size_pips));
   }
   else
   {
      use_top = p3_top;
      use_bot = p3_bot;
      use_size = g_patterns[pat_idx].pattern_size_pips;
   }
   
   // Update fib_1 with potentially amplified size
   if(dir == TRADE_LONG)
   {
      g_patterns[pat_idx].fib_1.level_100 = use_bot;
      g_patterns[pat_idx].fib_1.level_0   = use_top;
   }
   else
   {
      g_patterns[pat_idx].fib_1.level_100 = use_top;
      g_patterns[pat_idx].fib_1.level_0   = use_bot;
   }
   g_patterns[pat_idx].fib_1.size_pips = PriceToPips(use_top - use_bot);
   
   // === ENTRY CALCULATION ===
   double entry_ratio = use_size * g_point / g_patterns[pat_idx].indicator_value;
   g_patterns[pat_idx].size_vs_indicator = entry_ratio;
   g_patterns[pat_idx].fib_entry_level = GetEntryFibLevel(entry_ratio, 3);
   
   g_patterns[pat_idx].entry_type  = ENTRY_LIMIT;
   g_patterns[pat_idx].entry_price = CalcFibLevel(g_patterns[pat_idx].fib_1.level_0, g_patterns[pat_idx].fib_1.level_100, g_patterns[pat_idx].fib_entry_level);
   g_patterns[pat_idx].entry_price = NormalizePrice(g_patterns[pat_idx].entry_price);
   
   // === SL CALCULATION ===
   double sl_ratio = use_size * g_point / g_patterns[pat_idx].indicator_value;
   double sl_fib_normal = GetP3SLFibLevel(sl_ratio);
   double sl_normal_price = CalcFibLevel(g_patterns[pat_idx].fib_1.level_0, g_patterns[pat_idx].fib_1.level_100, sl_fib_normal);
   
   // Check for PE and ZI exceptions in SL range
   double sl_final = CalcP3SLWithExceptions(g_patterns[pat_idx], sl_normal_price, sl_fib_normal, friendly_dir);
   
   // Apply 5% tolerance
   double sl_distance = MathAbs(g_patterns[pat_idx].fib_1.level_0 - sl_final);
   double tolerance = sl_distance * 0.05;
   
   if(dir == TRADE_LONG)
      g_patterns[pat_idx].sl_price = sl_final - tolerance;
   else
      g_patterns[pat_idx].sl_price = sl_final + tolerance;
   
   g_patterns[pat_idx].sl_price = NormalizePrice(g_patterns[pat_idx].sl_price);
   g_patterns[pat_idx].sl_size_pips = PriceToPips(MathAbs(g_patterns[pat_idx].entry_price - g_patterns[pat_idx].sl_price));
   g_patterns[pat_idx].sl_tolerance = tolerance;
   
   // === TP ===
   double tp_distance = MathAbs(g_patterns[pat_idx].entry_price - g_patterns[pat_idx].sl_price) * inpTpRatio;
   if(dir == TRADE_LONG)
      g_patterns[pat_idx].tp_price = g_patterns[pat_idx].entry_price + tp_distance;
   else
      g_patterns[pat_idx].tp_price = g_patterns[pat_idx].entry_price - tp_distance;
   g_patterns[pat_idx].tp_price = NormalizePrice(g_patterns[pat_idx].tp_price);
   
   // Initialize tracking (reset for post-confirmation tracking)
   g_patterns[pat_idx].highest_close_since = iClose(_Symbol, PERIOD_CURRENT, 1);
   g_patterns[pat_idx].lowest_close_since  = iClose(_Symbol, PERIOD_CURRENT, 1);
   g_patterns[pat_idx].strict_pe_count     = 0;
   g_patterns[pat_idx].bar_last_update     = 1;
   
   g_patterns[pat_idx].state = PAT_CONFIRMED;
   g_logger.LogPattern("P3_ANALYZED", pat_idx, g_patterns[pat_idx]);
}

//+------------------------------------------------------------------+
//| Calculate P3 SL considering PE and ZI exceptions (sec 1.6.3)       |
//+------------------------------------------------------------------+
double CalcP3SLWithExceptions(PatternInfo &pat, double sl_normal, double sl_fib_level,
                               ENUM_DIRECTION friendly_dir)
{
   double fib_0   = pat.fib_1.level_0;
   double fib_100 = pat.fib_1.level_100;
   ENUM_TRADE_DIR dir = pat.trade_dir;
   
   // Search between 100% and SL normal level for PE
   double search_from = fib_100;
   double search_to   = sl_normal;
   
   int found_pe = FindPEInFibRange(search_from, search_to, friendly_dir);
   
   // Search for ZI that the SL level touches
   // The ZI must NOT be touching the pattern range (0%-100%)
   int found_zi_sl = -1;
   for(int z = 0; z < g_zi_count; z++)
   {
      if(!g_zi_array[z].is_valid) continue;
      if(g_zi_array[z].direction != friendly_dir) continue;
      
      // ZI must be touched by SL level
      double sl_check = sl_normal;
      if(dir == TRADE_LONG)
      {
         if(sl_check >= g_zi_array[z].lower_price && sl_check <= g_zi_array[z].upper_price)
         {
            // Check it's NOT overlapping with pattern range (would have been amplified)
            if(!(g_zi_array[z].lower_price <= pat.fib_1.level_0 &&
                 g_zi_array[z].upper_price >= pat.fib_1.level_100))
            {
               found_zi_sl = z;
               break;
            }
         }
      }
      else
      {
         if(sl_check >= g_zi_array[z].lower_price && sl_check <= g_zi_array[z].upper_price)
         {
            if(!(g_zi_array[z].upper_price >= pat.fib_1.level_0 &&
                 g_zi_array[z].lower_price <= pat.fib_1.level_100))
            {
               found_zi_sl = z;
               break;
            }
         }
      }
   }
   
   // Priority: if both PE and ZI → ZI takes priority
   if(found_zi_sl >= 0)
   {
      // ZI exception: cover entire zone, create new Fibonacci
      double zi_extreme;
      double gz_extreme = GetGrandZoneExtreme(found_zi_sl, friendly_dir);
      
      if(dir == TRADE_LONG)
      {
         zi_extreme = MathMin(g_zi_array[found_zi_sl].lower_price, gz_extreme);
         // New Fib: 100% at ZI lower, 0% at pattern top
         double new_fib_size = pat.fib_1.level_0 - zi_extreme;
         double new_ratio = PriceToPips(new_fib_size) * g_point / pat.indicator_value;
         
         // New entry level
         if(new_ratio < 2.5)
            pat.fib_entry_level = 0.50;
         else
            pat.fib_entry_level = 0.61;
         
         // Recalculate entry with new Fib
         pat.fib_2.level_0   = pat.fib_1.level_0;
         pat.fib_2.level_100 = zi_extreme;
         pat.fib_2.size_pips = PriceToPips(new_fib_size);
         
         pat.entry_price = CalcFibLevel(pat.fib_2.level_0, pat.fib_2.level_100, pat.fib_entry_level);
         pat.entry_price = NormalizePrice(pat.entry_price);
         
         // SL at 105% of new Fib
         double sl_zi = CalcFibLevel(pat.fib_2.level_0, pat.fib_2.level_100, 1.05);
         
         g_logger.LogDecision(StringFormat("p3_sl_zi|#%d|%.1f|%.1f",
            found_zi_sl, pat.entry_price, sl_zi));
         return sl_zi;
      }
      else
      {
         zi_extreme = MathMax(g_zi_array[found_zi_sl].upper_price, gz_extreme);
         double new_fib_size = zi_extreme - pat.fib_1.level_0;
         double new_ratio = PriceToPips(new_fib_size) * g_point / pat.indicator_value;
         
         if(new_ratio < 2.5)
            pat.fib_entry_level = 0.50;
         else
            pat.fib_entry_level = 0.61;
         
         pat.fib_2.level_0   = pat.fib_1.level_0;
         pat.fib_2.level_100 = zi_extreme;
         pat.fib_2.size_pips = PriceToPips(new_fib_size);
         
         pat.entry_price = CalcFibLevel(pat.fib_2.level_0, pat.fib_2.level_100, pat.fib_entry_level);
         pat.entry_price = NormalizePrice(pat.entry_price);
         
         double sl_zi = CalcFibLevel(pat.fib_2.level_0, pat.fib_2.level_100, 1.05);
         
         g_logger.LogDecision(StringFormat("p3_sl_zi|#%d|%.1f|%.1f",
            found_zi_sl, pat.entry_price, sl_zi));
         return sl_zi;
      }
   }
   else if(found_pe >= 0)
   {
      // PE exception: SL shortens to PE extremes, but NEVER extends beyond normal
      double pe_sl;
      if(dir == TRADE_LONG)
      {
         pe_sl = g_pe_array[found_pe].low_extreme;
         // PE can only shorten SL (bring it closer to entry)
         pe_sl = MathMax(pe_sl, sl_normal); // sl_normal is more negative, so max = closer
      }
      else
      {
         pe_sl = g_pe_array[found_pe].high_extreme;
         pe_sl = MathMin(pe_sl, sl_normal);
      }
      
      g_logger.LogDecision(StringFormat("p3_sl_pe|#%d|%.1f|%.1f",
         found_pe, sl_normal, pe_sl));
      return pe_sl;
   }
   
   // No exceptions: use normal SL
   return sl_normal;
}

//+------------------------------------------------------------------+
//| Check P3 impulse rule (section 1.6.4)                              |
//| Returns true if pattern is ALLOWED, false if rejected              |
//+------------------------------------------------------------------+
bool CheckP3ImpulseRule(int pat_idx)
{
   ENUM_TRADE_DIR dir = g_patterns[pat_idx].trade_dir;
   int available = iBars(_Symbol, PERIOD_CURRENT);
   
   // For BUYS: previous impulse is bearish. Find it.
   // For SELLS: previous impulse is bullish.
   // An impulse = directional candle + 2+ intermediate candles + directional candle that breaks
   
   // Start from the pattern formation and look backwards
   int start_shift = g_patterns[pat_idx].bar_formation_start + 1;
   
   // Find the last opposite impulse of 4+ bars
   int impulse_start = -1, impulse_end = -1;
   
   if(dir == TRADE_LONG)
   {
      // Looking for bearish impulse: find first bullish candle, then bearish sequence
      // Simplified: find the swing high before the pattern and swing low
      // The impulse goes from last bullish impulse close to lowest bearish close
      
      // Find highest close (bullish) looking back from pattern
      double highest_close = 0;
      int highest_bar = start_shift;
      
      for(int s = start_shift; s < MathMin(start_shift + 100, available); s++)
      {
         double c = iClose(_Symbol, PERIOD_CURRENT, s);
         if(c > highest_close) { highest_close = c; highest_bar = s; }
         
         // Stop if we find a significant bullish impulse (4+ bars)
         if(s > start_shift + IMPULSE_MIN_BARS && c > highest_close * 0.99)
            break;
      }
      
      // Impulse: from highest_bar close to the lowest close before pattern
      double lowest_close = DBL_MAX;
      int lowest_bar = start_shift;
      for(int s = start_shift; s < highest_bar; s++)
      {
         double c = iClose(_Symbol, PERIOD_CURRENT, s);
         if(c < lowest_close) { lowest_close = c; lowest_bar = s; }
      }
      
      if(highest_bar <= lowest_bar) return true; // No clear impulse
      
      impulse_start = highest_bar;
      impulse_end   = lowest_bar;
   }
   else
   {
      // Looking for bullish impulse
      double lowest_close = DBL_MAX;
      int lowest_bar = start_shift;
      
      for(int s = start_shift; s < MathMin(start_shift + 100, available); s++)
      {
         double c = iClose(_Symbol, PERIOD_CURRENT, s);
         if(c < lowest_close) { lowest_close = c; lowest_bar = s; }
         if(s > start_shift + IMPULSE_MIN_BARS && c < lowest_close * 1.01)
            break;
      }
      
      double highest_close = 0;
      int highest_bar = start_shift;
      for(int s = start_shift; s < lowest_bar; s++)
      {
         double c = iClose(_Symbol, PERIOD_CURRENT, s);
         if(c > highest_close) { highest_close = c; highest_bar = s; }
      }
      
      if(lowest_bar <= highest_bar) return true;
      
      impulse_start = lowest_bar;
      impulse_end   = highest_bar;
   }
   
   int impulse_bars = impulse_start - impulse_end;
   if(impulse_bars < IMPULSE_MIN_BARS) return true; // Too small, not a real impulse
   
   // Measure impulse size
   double impulse_high = 0, impulse_low = DBL_MAX;
   for(int s = impulse_end; s <= impulse_start; s++)
   {
      impulse_high = MathMax(impulse_high, iClose(_Symbol, PERIOD_CURRENT, s));
      impulse_low  = MathMin(impulse_low, iClose(_Symbol, PERIOD_CURRENT, s));
   }
   double impulse_size = impulse_high - impulse_low;
   
   // Get indicator at midpoint
   int midpoint_bar = impulse_end + impulse_bars / 2;
   double ind_at_mid = GetIndicatorValue(midpoint_bar);
   
   if(ind_at_mid <= 0) return true;
   
   double impulse_ratio = impulse_size / ind_at_mid;
   g_patterns[pat_idx].p3_impulse_bars = impulse_bars;
   g_patterns[pat_idx].p3_impulse_vs_indicator = impulse_ratio;
   
   g_logger.LogDecision(StringFormat("imp|%d|%.0f|%.1f|%.2f",
      impulse_bars, PriceToPips(impulse_size), ind_at_mid, impulse_ratio));
   
   if(impulse_ratio >= 6.0)
   {
      g_logger.LogDecision("imp|VETO");
      return false;
   }
   
   return true;
}
//+------------------------------------------------------------------+
