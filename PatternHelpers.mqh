//+------------------------------------------------------------------+
//| PatternHelpers.mqh                                                |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

// Phase 4 & 5: Shared helpers ===============================================

//+------------------------------------------------------------------+
//| Find a valid zone at a given close price and direction              |
//| Returns zone index or -1                                           |
//+------------------------------------------------------------------+
int FindZoneAtClose(double close_price, ENUM_DIRECTION dir)
{
   for(int i = 0; i < g_zi_count; i++)
   {
      if(!g_zi_array[i].is_valid) continue;
      if(g_zi_array[i].direction != dir) continue;
      if(close_price >= g_zi_array[i].lower_price && close_price <= g_zi_array[i].upper_price)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Find valid ZI touching between two Fibonacci levels                |
//| Returns zone index or -1. Considers grand zones.                   |
//+------------------------------------------------------------------+
int FindZIInFibRange(double fib_low, double fib_high, ENUM_DIRECTION dir)
{
   // fib_low/fib_high: absolute prices of the range to search
   double range_bottom = MathMin(fib_low, fib_high);
   double range_top    = MathMax(fib_low, fib_high);
   
   for(int i = 0; i < g_zi_count; i++)
   {
      if(!g_zi_array[i].is_valid) continue;
      if(g_zi_array[i].direction != dir) continue;
      
      // Any overlap with the range
      if(g_zi_array[i].lower_price <= range_top && g_zi_array[i].upper_price >= range_bottom)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Find valid PE whose level is between two Fibonacci prices           |
//| Returns PE index or -1                                             |
//+------------------------------------------------------------------+
int FindPEInFibRange(double fib_low, double fib_high, ENUM_DIRECTION dir)
{
   double range_bottom = MathMin(fib_low, fib_high);
   double range_top    = MathMax(fib_low, fib_high);
   
   for(int i = 0; i < g_pe_count; i++)
   {
      if(!g_pe_array[i].is_valid) continue;
      if(g_pe_array[i].direction != dir) continue;
      
      if(g_pe_array[i].level >= range_bottom && g_pe_array[i].level <= range_top)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Get the full extent of overlapping zones starting from a zone      |
//| Returns the grand zone extreme (lower for bullish, upper for bear) |
//+------------------------------------------------------------------+
double GetGrandZoneExtreme(int zi_index, ENUM_DIRECTION dir)
{
   // Find the grand zone containing this zone
   for(int g = 0; g < g_gz_count; g++)
   {
      if(!g_grand_zones[g].is_valid) continue;
      if(g_grand_zones[g].direction != dir) continue;
      
      for(int k = 0; k < g_grand_zones[g].zone_count; k++)
      {
         if(g_grand_zones[g].zone_indices[k] == zi_index)
         {
            // Found it
            if(dir == DIR_BULLISH)
               return g_grand_zones[g].lower_price; // Bottom of combined zone
            else
               return g_grand_zones[g].upper_price; // Top of combined zone
         }
      }
   }
   
   // Not in a grand zone, return own extreme
   if(dir == DIR_BULLISH)
      return g_zi_array[zi_index].lower_price;
   else
      return g_zi_array[zi_index].upper_price;
}

//+------------------------------------------------------------------+
//| Calculate entry Fibonacci level from size/indicator ratio           |
//| table_type: 2 = Pattern 2 table, 3 = Pattern 3 table              |
//+------------------------------------------------------------------+
double GetEntryFibLevel(double ratio, int table_type)
{
   if(table_type == 2)
   {
      // Pattern 2 entry table (pages 16-17)
      if(ratio <= 1.3)  return 0.0;   // Direct entry
      if(ratio <= 1.6)  return 0.23;
      if(ratio <= 2.8)  return 0.38;
      if(ratio <= 3.5)  return 0.50;
      return 0.61;
   }
   else // Pattern 3
   {
      // Pattern 3 entry table (page 23)
      if(ratio < 1.5)   return 0.33;
      if(ratio < 2.5)   return 0.40;
      if(ratio < 3.5)   return 0.50;
      return 0.61;
   }
}

//+------------------------------------------------------------------+
//| Get Pattern 3 SL Fibonacci level for "normal situation"            |
//+------------------------------------------------------------------+
double GetP3SLFibLevel(double ratio)
{
   // Page 23 SL table
   if(ratio <= 0.5)  return 3.0;   // 300%
   if(ratio <= 0.85) return 2.2;   // 220%
   if(ratio <= 1.0)  return 2.0;   // 200%
   return 1.5;                      // 150%
}

//+------------------------------------------------------------------+
//| Find mitigated zone whose ORIGINAL bounds cover close_price        |
//| Used by wick exception: the zone was mitigated but only by wicks   |
//| of the 2 candles immediately before the close candle               |
//| Returns zone index or -1                                           |
//+------------------------------------------------------------------+
int FindMitigatedZoneForWickException(int close_bar_shift, ENUM_DIRECTION zi_dir, double close_price)
{
   int bar_prev1 = close_bar_shift + 1;
   int bar_prev2 = close_bar_shift + 2;
   int available = iBars(_Symbol, PERIOD_CURRENT);
   
   if(bar_prev2 >= available) return -1;
   
   datetime time_prev2 = iTime(_Symbol, PERIOD_CURRENT, bar_prev2);
   
   // Pre-fetch bar data for prev1 and prev2
   double prev1_high = iHigh(_Symbol, PERIOD_CURRENT, bar_prev1);
   double prev1_low  = iLow(_Symbol, PERIOD_CURRENT, bar_prev1);
   double prev2_high = iHigh(_Symbol, PERIOD_CURRENT, bar_prev2);
   double prev2_low  = iLow(_Symbol, PERIOD_CURRENT, bar_prev2);
   
   for(int i = 0; i < g_zi_count; i++)
   {
      if(g_zi_array[i].direction != zi_dir) continue;
      
      // FIX 1: Only FULLY MITIGATED zones qualify for wick exception.
      // ZI_PARTIAL zones are still valid with reduced bounds — if close_price
      // falls outside those bounds, it means close is in the mitigated portion,
      // which is NOT a valid "close in zone". Allowing ZI_PARTIAL here was
      // the root cause of false P2/P3 detections.
      if(g_zi_array[i].state != ZI_MITIGATED) continue;
      
      // Recency check 1: zone must have been created BEFORE bar_prev2
      if(g_zi_array[i].time_created > time_prev2) continue;
      
      // Recency check 2: reject very old zones
      int zone_age_bars = iBarShift(_Symbol, PERIOD_CURRENT, g_zi_array[i].time_created);
      if(zone_age_bars < 0 || zone_age_bars > inpZoneExpireCandles + 10) continue;
      
      // Original bounds must cover close_price
      if(close_price < g_zi_array[i].original_lower || close_price > g_zi_array[i].original_upper) continue;
      
      // FIX 2: Verify that bar_prev1 or bar_prev2 actually CAUSED the mitigation.
      // The spec says "zone recently mitigated by wicks of the 2 previous candles".
      // If the zone was mitigated by a different bar, wick exception doesn't apply.
      bool prev1_caused = false, prev2_caused = false;
      if(zi_dir == DIR_BULLISH)
      {
         // Bullish zone: full mitigation = bar low <= original lower
         prev1_caused = (prev1_low <= g_zi_array[i].original_lower);
         prev2_caused = (prev2_low <= g_zi_array[i].original_lower);
      }
      else
      {
         // Bearish zone: full mitigation = bar high >= original upper
         prev1_caused = (prev1_high >= g_zi_array[i].original_upper);
         prev2_caused = (prev2_high >= g_zi_array[i].original_upper);
      }
      if(!prev1_caused && !prev2_caused) continue;
      
      // At least one of prev1/prev2 overlaps with original bounds
      bool prev1_overlaps = (prev1_low <= g_zi_array[i].original_upper && 
                             prev1_high >= g_zi_array[i].original_lower);
      bool prev2_overlaps = (prev2_low <= g_zi_array[i].original_upper && 
                             prev2_high >= g_zi_array[i].original_lower);
      
      if(!prev1_overlaps && !prev2_overlaps) continue;
      
      // Verify: the 2 bars have WICK (not body) at close_price level
      bool has_wick_at_level = false;
      bool body_at_level = false;
      
      for(int b = bar_prev1; b <= bar_prev2; b++)
      {
         double body_top    = GetBodyTop(b);
         double body_bottom = GetBodyBottom(b);
         double bar_high    = iHigh(_Symbol, PERIOD_CURRENT, b);
         double bar_low     = iLow(_Symbol, PERIOD_CURRENT, b);
         
         // Body crosses close_price → disqualifies entire exception
         if(close_price >= body_bottom && close_price <= body_top)
         {
            body_at_level = true;
            break;
         }
         
         // Check if wick reaches close_price
         if(zi_dir == DIR_BULLISH)
         {
            if(close_price >= bar_low && close_price < body_bottom)
               has_wick_at_level = true;
         }
         else
         {
            if(close_price <= bar_high && close_price > body_top)
               has_wick_at_level = true;
         }
      }
      
      // Only valid if wick touched but body didn't
      if(has_wick_at_level && !body_at_level)
      {
         g_logger.LogDecision(StringFormat("WE|zi#%d|%s|age%d|%.1f",
            i, (zi_dir == DIR_BULLISH) ? "B" : "R", zone_age_bars, close_price));
         return i;
      }
   }
   
   return -1;
}

//+------------------------------------------------------------------+
//| Check P2 wick exception: 2 candles before formation                |
//| mitigate ZI with wick only (not body) at close level               |
//| Returns true if a real mitigated zone was found at close_price     |
//| and the mitigation was by wicks only (not bodies) of prior bars    |
//| out_zi_idx receives the mitigated zone index if found              |
//+------------------------------------------------------------------+
bool CheckP2WickException(int close_bar_shift, ENUM_DIRECTION zi_dir, double close_price, int &out_zi_idx)
{
   out_zi_idx = FindMitigatedZoneForWickException(close_bar_shift, zi_dir, close_price);
   
   if(out_zi_idx >= 0)
   {
      g_logger.LogDecision(StringFormat("DW|wick_exc|zi#%d|%.1f", out_zi_idx, close_price));
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Overload: backward-compatible version (without out_zi_idx)         |
//+------------------------------------------------------------------+
bool CheckP2WickException(int close_bar_shift, ENUM_DIRECTION zi_dir, double close_price)
{
   int dummy_idx;
   return CheckP2WickException(close_bar_shift, zi_dir, close_price, dummy_idx);
}

//+------------------------------------------------------------------+
//| Sec 5.6: Check if confirming bar closes in opposite ZI             |
//| For BUY: engulfing/break bar must NOT close in bearish ZI          |
//| For SELL: engulfing/break bar must NOT close in bullish ZI         |
//| Returns true if pattern should be CANCELLED                        |
//+------------------------------------------------------------------+
bool CheckConfirmBarInOppositeZI(int bar_shift, ENUM_TRADE_DIR trade_dir)
{
   double bar_close = iClose(_Symbol, PERIOD_CURRENT, bar_shift);
   
   // Opposite ZI direction: BUY trade → bearish ZI, SELL trade → bullish ZI
   ENUM_DIRECTION opposite_zi_dir = (trade_dir == TRADE_LONG) ? DIR_BEARISH : DIR_BULLISH;
   
   for(int z = 0; z < g_zi_count; z++)
   {
      if(!g_zi_array[z].is_valid) continue;
      if(g_zi_array[z].direction != opposite_zi_dir) continue;
      
      if(bar_close >= g_zi_array[z].lower_price && bar_close <= g_zi_array[z].upper_price)
      {
         g_logger.LogDecision(StringFormat("5.6|CANCEL|%s|zi#%d|%.1f",
            (trade_dir == TRADE_LONG) ? "L" : "S", z, bar_close));
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Register a pattern into the global array                           |
//| Returns index or -1                                                |
//+------------------------------------------------------------------+
int RegisterPattern(const PatternInfo &pat)
{
   int idx = -1;
   for(int i = 0; i < g_pat_count; i++)
   {
      if(!g_patterns[i].is_valid) { idx = i; break; }
   }
   if(idx < 0)
   {
      if(g_pat_count >= ArraySize(g_patterns))
      {
         ArrayResize(g_patterns, g_pat_count + 10);
         for(int i = g_pat_count; i < g_pat_count + 10; i++) g_patterns[i].Reset();
      }
      idx = g_pat_count;
      g_pat_count++;
   }
   
   g_patterns[idx] = pat;
   g_logger.LogPattern("REGISTERED", idx, g_patterns[idx]);
   return idx;
}
//+------------------------------------------------------------------+
