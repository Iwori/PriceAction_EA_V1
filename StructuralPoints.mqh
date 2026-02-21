//+------------------------------------------------------------------+
//| StructuralPoints.mqh                                              |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

//+------------------------------------------------------------------+
//| Placeholder functions for future phases                            |
//+------------------------------------------------------------------+

// Phase 2: Structural Points ================================================

//+------------------------------------------------------------------+
//| Detect structural points on each new bar                           |
//| Scans formations that may now have right-side empty spaces         |
//+------------------------------------------------------------------+
void DetectStructuralPoints()
{
   int available_bars = iBars(_Symbol, PERIOD_CURRENT);
   
   // Deep scan on first bar, narrow scan afterwards
   int max_shift = (g_bar_count <= 1) ? PE_SCAN_INIT : PE_SCAN_NORMAL;
   
   // Clamp to available data (need room for left-side check: +4 +2 for formation)
   if(max_shift > available_bars - PE_LOOKBACK - 3)
      max_shift = available_bars - PE_LOOKBACK - 3;
   if(max_shift < 2) return;
   
   // Scan for formations: last candle from shift 2 to max_shift
   // Shift 2 = minimum to have 1 right-side closed bar (shift 1)
   for(int shift = 2; shift <= max_shift; shift++)
   {
      // Try all possible PE formations ending at this shift
      // A) 2-candle formation: shifts (shift+1, shift)
      // B) 3-candle with doji: shifts (shift+2, shift+1, shift)
      
      TryRegisterPE(shift, false); // 2-candle attempt
      TryRegisterPE(shift, true);  // 3-candle attempt
   }
}

//+------------------------------------------------------------------+
//| Try to detect and register a PE formation ending at last_shift     |
//| force_3candle: if true, only check 3-candle (with doji) formation  |
//+------------------------------------------------------------------+
void TryRegisterPE(int last_shift, bool force_3candle)
{
   int available_bars = iBars(_Symbol, PERIOD_CURRENT);
   
   ENUM_CANDLE_TYPE last_type = GetCandleType(last_shift);
   
   // Last candle of PE must be bullish or bearish, never doji
   if(last_type == CANDLE_DOJI) return;
   
   int prev_shift = last_shift + 1;
   if(prev_shift >= available_bars) return;
   
   ENUM_CANDLE_TYPE prev_type = GetCandleType(prev_shift);
   
   ENUM_DIRECTION dir;
   bool has_doji = false;
   int first_shift;
   double pe_level, high_ext, low_ext;
   
   if(!force_3candle)
   {
      // === 2-candle formation ===
      // Bullish PE: bearish + bullish
      // Bearish PE: bullish + bearish
      // Doji as prev → not valid for 2-candle
      if(prev_type == CANDLE_DOJI) return;
      
      if(prev_type == CANDLE_BEARISH && last_type == CANDLE_BULLISH)
      {
         dir = DIR_BULLISH;
         first_shift = prev_shift;
         
         // PE level: MIN(close of bearish, open of bullish) - no wicks
         pe_level = MathMin(iClose(_Symbol, PERIOD_CURRENT, prev_shift),
                            iOpen(_Symbol, PERIOD_CURRENT, last_shift));
         
         // Extremes including wicks (for SL calculations later)
         high_ext = MathMax(iHigh(_Symbol, PERIOD_CURRENT, prev_shift),
                            iHigh(_Symbol, PERIOD_CURRENT, last_shift));
         low_ext  = MathMin(iLow(_Symbol, PERIOD_CURRENT, prev_shift),
                            iLow(_Symbol, PERIOD_CURRENT, last_shift));
      }
      else if(prev_type == CANDLE_BULLISH && last_type == CANDLE_BEARISH)
      {
         dir = DIR_BEARISH;
         first_shift = prev_shift;
         
         // PE level: MAX(close of bullish, open of bearish)
         pe_level = MathMax(iClose(_Symbol, PERIOD_CURRENT, prev_shift),
                            iOpen(_Symbol, PERIOD_CURRENT, last_shift));
         
         high_ext = MathMax(iHigh(_Symbol, PERIOD_CURRENT, prev_shift),
                            iHigh(_Symbol, PERIOD_CURRENT, last_shift));
         low_ext  = MathMin(iLow(_Symbol, PERIOD_CURRENT, prev_shift),
                            iLow(_Symbol, PERIOD_CURRENT, last_shift));
      }
      else return; // No valid 2-candle formation
   }
   else
   {
      // === 3-candle formation (with doji in middle) ===
      if(prev_type != CANDLE_DOJI) return; // Middle must be doji
      
      int prev2_shift = last_shift + 2;
      if(prev2_shift >= available_bars) return;
      
      ENUM_CANDLE_TYPE prev2_type = GetCandleType(prev2_shift);
      
      // Bullish PE: bearish + doji + bullish
      if(prev2_type == CANDLE_BEARISH && last_type == CANDLE_BULLISH)
      {
         dir = DIR_BULLISH;
         has_doji = true;
         first_shift = prev2_shift;
         
         // PE level: MIN(close bearish, close doji, open bullish)
         pe_level = MathMin(MathMin(iClose(_Symbol, PERIOD_CURRENT, prev2_shift),
                                    iClose(_Symbol, PERIOD_CURRENT, prev_shift)),
                            iOpen(_Symbol, PERIOD_CURRENT, last_shift));
         
         high_ext = MathMax(MathMax(iHigh(_Symbol, PERIOD_CURRENT, prev2_shift),
                                    iHigh(_Symbol, PERIOD_CURRENT, prev_shift)),
                            iHigh(_Symbol, PERIOD_CURRENT, last_shift));
         low_ext  = MathMin(MathMin(iLow(_Symbol, PERIOD_CURRENT, prev2_shift),
                                    iLow(_Symbol, PERIOD_CURRENT, prev_shift)),
                            iLow(_Symbol, PERIOD_CURRENT, last_shift));
      }
      // Bearish PE: bullish + doji + bearish
      else if(prev2_type == CANDLE_BULLISH && last_type == CANDLE_BEARISH)
      {
         dir = DIR_BEARISH;
         has_doji = true;
         first_shift = prev2_shift;
         
         // PE level: MAX(close bullish, close doji, open bearish)
         pe_level = MathMax(MathMax(iClose(_Symbol, PERIOD_CURRENT, prev2_shift),
                                    iClose(_Symbol, PERIOD_CURRENT, prev_shift)),
                            iOpen(_Symbol, PERIOD_CURRENT, last_shift));
         
         high_ext = MathMax(MathMax(iHigh(_Symbol, PERIOD_CURRENT, prev2_shift),
                                    iHigh(_Symbol, PERIOD_CURRENT, prev_shift)),
                            iHigh(_Symbol, PERIOD_CURRENT, last_shift));
         low_ext  = MathMin(MathMin(iLow(_Symbol, PERIOD_CURRENT, prev2_shift),
                                    iLow(_Symbol, PERIOD_CURRENT, prev_shift)),
                            iLow(_Symbol, PERIOD_CURRENT, last_shift));
      }
      else return; // No valid 3-candle formation
   }
   
   // Formation found - check if already registered
   datetime time_f = iTime(_Symbol, PERIOD_CURRENT, first_shift);
   datetime time_l = iTime(_Symbol, PERIOD_CURRENT, last_shift);
   
   if(IsPEAlreadyRegistered(time_f, time_l, dir))
      return;
   
   // Check left empty spaces (4 bars before first candle of formation)
   int left_spaces = CountEmptySpacesLeft(pe_level, dir, first_shift);
   if(left_spaces <= 0) return; // No space or invalidated
   
   // Check right empty spaces (4 bars after last candle of formation)
   int right_spaces = CountEmptySpacesRight(pe_level, dir, last_shift);
   if(right_spaces <= 0) return; // No space or invalidated
   
   // PE confirmed! Determine type
   ENUM_PE_TYPE pe_type = (left_spaces >= 2 && right_spaces >= 2) ? PE_STRICT : PE_NORMAL;
   
   // Find which bar created the right-side empty space (the confirming bar)
   int confirm_bar = FindConfirmingBar(pe_level, dir, last_shift);
   datetime time_confirmed = (confirm_bar > 0) ? iTime(_Symbol, PERIOD_CURRENT, confirm_bar) : TimeCurrent();
   
   // Register
   int idx = RegisterPE(dir, pe_type, pe_level, high_ext, low_ext,
                         left_spaces, right_spaces, first_shift, last_shift,
                         has_doji, time_confirmed, confirm_bar, time_f, time_l);
   
   if(idx >= 0)
      g_logger.LogPE("DETECTED", idx, g_pe_array[idx]);
}

//+------------------------------------------------------------------+
//| Count empty spaces on LEFT side of PE formation                    |
//| Checks 4 bars before first_shift, right to left                    |
//| Returns: space count (0 = none found), -1 = invalidated            |
//+------------------------------------------------------------------+
int CountEmptySpacesLeft(double pe_level, ENUM_DIRECTION dir, int first_shift)
{
   int available_bars = iBars(_Symbol, PERIOD_CURRENT);
   int spaces = 0;
   
   for(int i = 1; i <= PE_LOOKBACK; i++)
   {
      int bar = first_shift + i;
      if(bar >= available_bars) break;
      
      double bar_high  = iHigh(_Symbol, PERIOD_CURRENT, bar);
      double bar_low   = iLow(_Symbol, PERIOD_CURRENT, bar);
      double bar_open  = iOpen(_Symbol, PERIOD_CURRENT, bar);
      double bar_close = iClose(_Symbol, PERIOD_CURRENT, bar);
      
      if(dir == DIR_BULLISH)
      {
         // Bullish PE: level is LOW. Empty = candle entirely above PE level
         if(bar_low > pe_level)
         {
            spaces++;  // Empty space found
         }
         else
         {
            // Candle reaches PE level. Check if body crosses (open/close at or below)
            if(bar_open <= pe_level || bar_close <= pe_level)
            {
               // Body crosses PE level
               if(spaces == 0) return -1; // Invalidated: body cross before any space
               return spaces;             // Stop counting, keep what we have
            }
            // Only wick touches → not a space, continue checking
         }
      }
      else // DIR_BEARISH
      {
         // Bearish PE: level is HIGH. Empty = candle entirely below PE level
         if(bar_high < pe_level)
         {
            spaces++;
         }
         else
         {
            if(bar_open >= pe_level || bar_close >= pe_level)
            {
               if(spaces == 0) return -1;
               return spaces;
            }
         }
      }
   }
   
   return spaces;
}

//+------------------------------------------------------------------+
//| Count empty spaces on RIGHT side of PE formation                   |
//| Checks 4 bars after last_shift, left to right (decreasing shift)   |
//| Only counts CLOSED bars (shift >= 1)                               |
//| Returns: space count (0 = none found), -1 = invalidated            |
//+------------------------------------------------------------------+
int CountEmptySpacesRight(double pe_level, ENUM_DIRECTION dir, int last_shift)
{
   int spaces = 0;
   
   for(int i = 1; i <= PE_LOOKBACK; i++)
   {
      int bar = last_shift - i;
      if(bar < 1) break; // Only closed bars (shift >= 1)
      
      double bar_high  = iHigh(_Symbol, PERIOD_CURRENT, bar);
      double bar_low   = iLow(_Symbol, PERIOD_CURRENT, bar);
      double bar_open  = iOpen(_Symbol, PERIOD_CURRENT, bar);
      double bar_close = iClose(_Symbol, PERIOD_CURRENT, bar);
      
      if(dir == DIR_BULLISH)
      {
         if(bar_low > pe_level)
         {
            spaces++;
         }
         else
         {
            if(bar_open <= pe_level || bar_close <= pe_level)
            {
               if(spaces == 0) return -1;
               return spaces;
            }
         }
      }
      else // DIR_BEARISH
      {
         if(bar_high < pe_level)
         {
            spaces++;
         }
         else
         {
            if(bar_open >= pe_level || bar_close >= pe_level)
            {
               if(spaces == 0) return -1;
               return spaces;
            }
         }
      }
   }
   
   return spaces;
}

//+------------------------------------------------------------------+
//| Find which bar created the first right-side empty space             |
//| (The bar whose CLOSE confirms the PE exists)                       |
//+------------------------------------------------------------------+
int FindConfirmingBar(double pe_level, ENUM_DIRECTION dir, int last_shift)
{
   for(int i = 1; i <= PE_LOOKBACK; i++)
   {
      int bar = last_shift - i;
      if(bar < 1) break;
      
      if(dir == DIR_BULLISH)
      {
         if(iLow(_Symbol, PERIOD_CURRENT, bar) > pe_level)
            return bar; // This bar created empty space
      }
      else
      {
         if(iHigh(_Symbol, PERIOD_CURRENT, bar) < pe_level)
            return bar;
      }
   }
   return last_shift; // Fallback
}

//+------------------------------------------------------------------+
//| Check if a PE with same formation bars is already registered        |
//+------------------------------------------------------------------+
bool IsPEAlreadyRegistered(datetime time_first, datetime time_last, ENUM_DIRECTION dir)
{
   for(int i = 0; i < g_pe_count; i++)
   {
      if(!g_pe_array[i].is_valid) continue;
      if(g_pe_array[i].time_first == time_first &&
         g_pe_array[i].time_last  == time_last  &&
         g_pe_array[i].direction  == dir)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Register a confirmed PE into the global array                      |
//| Returns index on success, -1 on failure                            |
//+------------------------------------------------------------------+
int RegisterPE(ENUM_DIRECTION dir, ENUM_PE_TYPE type, double level,
               double high_ext, double low_ext, int empty_left, int empty_right,
               int first_shift, int last_shift, bool has_doji,
               datetime time_confirmed, int bar_confirmed,
               datetime time_first, datetime time_last)
{
   // Find a free slot or expand
   int idx = -1;
   
   // First try to reuse an invalid slot
   for(int i = 0; i < g_pe_count; i++)
   {
      if(!g_pe_array[i].is_valid)
      {
         idx = i;
         break;
      }
   }
   
   // No free slot, use next position
   if(idx < 0)
   {
      if(g_pe_count >= ArraySize(g_pe_array))
      {
         // Array full - expand by 50
         ArrayResize(g_pe_array, g_pe_count + 50);
         for(int i = g_pe_count; i < g_pe_count + 50; i++)
            g_pe_array[i].Reset();
      }
      idx = g_pe_count;
      g_pe_count++;
   }
   
   // Fill data
   g_pe_array[idx].is_valid       = true;
   g_pe_array[idx].direction      = dir;
   g_pe_array[idx].pe_type        = type;
   g_pe_array[idx].level          = level;
   g_pe_array[idx].high_extreme   = high_ext;
   g_pe_array[idx].low_extreme    = low_ext;
   g_pe_array[idx].empty_left     = empty_left;
   g_pe_array[idx].empty_right    = empty_right;
   g_pe_array[idx].bar_index_first= first_shift;   // Snapshot shift at detection time
   g_pe_array[idx].bar_index_last = last_shift;     // Snapshot shift at detection time
   g_pe_array[idx].time_created   = time_confirmed;
   g_pe_array[idx].bar_created    = bar_confirmed;
   g_pe_array[idx].has_doji       = has_doji;
   g_pe_array[idx].time_first     = time_first;
   g_pe_array[idx].time_last      = time_last;
   
   return idx;
}
//+------------------------------------------------------------------+
