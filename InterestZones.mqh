//+------------------------------------------------------------------+
//| InterestZones.mqh                                                 |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

// Phase 3: Interest Zones ===================================================

//+------------------------------------------------------------------+
//| Register a zone into the global array                              |
//| Returns index on success, -1 on failure                            |
//+------------------------------------------------------------------+
int RegisterZone(ENUM_DIRECTION dir, ENUM_ZI_BASE base, double upper, double lower,
                 int bar_created_shift, datetime time_creator_dt, int pe_idx, bool incl_doji)
{
   // Check for duplicate or merge with existing zone at same location
   // Check ALL zones including mitigated/expired to prevent re-creation
   for(int i = 0; i < g_zi_count; i++)
   {
      if(g_zi_array[i].direction != dir) continue;
      
      // For valid zones: compare current bounds
      if(g_zi_array[i].is_valid)
      {
         if(MathAbs(g_zi_array[i].upper_price - upper) < g_point &&
            MathAbs(g_zi_array[i].lower_price - lower) < g_point)
         {
            if(g_zi_array[i].base_type != base && base != ZI_BASE_BOTH)
               g_zi_array[i].base_type = ZI_BASE_BOTH;
            return i; // Already exists
         }
      }
      
      // For mitigated/expired zones: compare original bounds to prevent re-creation
      if(!g_zi_array[i].is_valid &&
         (g_zi_array[i].state == ZI_MITIGATED || g_zi_array[i].state == ZI_EXPIRED))
      {
         if(MathAbs(g_zi_array[i].original_upper - upper) < g_point &&
            MathAbs(g_zi_array[i].original_lower - lower) < g_point)
         {
            return -1; // Zone existed and was mitigated/expired, do not re-create
         }
      }
   }
   
   // Find free slot or expand
   // IMPORTANT: only reuse slots that were Reset() or never used,
   // NOT mitigated/expired slots (they hold dedup data)
   int idx = -1;
   for(int i = 0; i < g_zi_count; i++)
   {
      if(!g_zi_array[i].is_valid &&
         g_zi_array[i].state != ZI_MITIGATED &&
         g_zi_array[i].state != ZI_EXPIRED)
      {
         idx = i;
         break;
      }
   }
   if(idx < 0)
   {
      if(g_zi_count >= ArraySize(g_zi_array))
      {
         ArrayResize(g_zi_array, g_zi_count + 50);
         for(int i = g_zi_count; i < g_zi_count + 50; i++) g_zi_array[i].Reset();
      }
      idx = g_zi_count;
      g_zi_count++;
   }
   
   g_zi_array[idx].is_valid       = true;
   g_zi_array[idx].direction      = dir;
   g_zi_array[idx].base_type      = base;
   g_zi_array[idx].state          = ZI_ACTIVE;
   g_zi_array[idx].upper_price    = upper;
   g_zi_array[idx].lower_price    = lower;
   g_zi_array[idx].original_upper = upper;
   g_zi_array[idx].original_lower = lower;
   g_zi_array[idx].bar_created    = bar_created_shift;
   g_zi_array[idx].time_created   = iTime(_Symbol, PERIOD_CURRENT, bar_created_shift);
   g_zi_array[idx].bar_creator    = bar_created_shift;
   g_zi_array[idx].time_creator   = time_creator_dt;
   g_zi_array[idx].candles_alive  = bar_created_shift;
   g_zi_array[idx].pe_index       = pe_idx;
   g_zi_array[idx].includes_doji  = incl_doji;
   
   g_logger.LogZone("CREATED", idx, g_zi_array[idx]);
   return idx;
}

//+------------------------------------------------------------------+
//| Detect zones based on PE (section 1.3.1)                           |
//| For each valid PE: if 1st candle body < 2nd candle body → zone     |
//+------------------------------------------------------------------+
void DetectZonesPE()
{
   for(int i = 0; i < g_pe_count; i++)
   {
      if(!g_pe_array[i].is_valid) continue;
      
      // Skip if PE is too old (zone would be born expired)
      int pe_age = iBarShift(_Symbol, PERIOD_CURRENT, g_pe_array[i].time_created);
      if(pe_age < 0 || pe_age >= inpZoneExpireCandles) continue;
      
      // Check if zone already exists for this PE
      bool already_has_zone = false;
      for(int z = 0; z < g_zi_count; z++)
      {
         if(g_zi_array[z].pe_index == i)  // Check even invalid ones to avoid re-creating
         { already_has_zone = true; break; }
      }
      if(already_has_zone) continue;
      
      // Get formation bar shifts from times (shifts move, times don't)
      int first_shift = iBarShift(_Symbol, PERIOD_CURRENT, g_pe_array[i].time_first);
      int last_shift  = iBarShift(_Symbol, PERIOD_CURRENT, g_pe_array[i].time_last);
      if(first_shift < 0 || last_shift < 0) continue;
      
      double body_first = GetBodySize(first_shift);
      double body_last  = GetBodySize(last_shift);
      
      // Zone condition: 1st candle body < 2nd candle body
      if(body_first >= body_last) continue;
      
      // Zone boundaries = ENTIRE smaller candle (wicks included)
      // The smaller candle is the first one (bearish for bullish PE, bullish for bearish PE)
      double zone_upper, zone_lower;
      bool incl_doji = false;
      
      if(g_pe_array[i].has_doji)
      {
         // PE with Doji: include Doji in zone boundaries
         // First candle = first_shift, Doji = first_shift - 1 (or last_shift + 1)
         int doji_shift = first_shift - 1; // Doji is between first and last
         if(doji_shift < 0 || doji_shift <= last_shift) 
            doji_shift = last_shift + 1;   // Try the other position
         
         if(doji_shift > 0 && doji_shift < iBars(_Symbol, PERIOD_CURRENT))
         {
            zone_upper = MathMax(iHigh(_Symbol, PERIOD_CURRENT, first_shift),
                                 iHigh(_Symbol, PERIOD_CURRENT, doji_shift));
            zone_lower = MathMin(iLow(_Symbol, PERIOD_CURRENT, first_shift),
                                 iLow(_Symbol, PERIOD_CURRENT, doji_shift));
            incl_doji = true;
         }
         else
         {
            zone_upper = iHigh(_Symbol, PERIOD_CURRENT, first_shift);
            zone_lower = iLow(_Symbol, PERIOD_CURRENT, first_shift);
         }
      }
      else
      {
         // Normal PE: zone = first candle only
         zone_upper = iHigh(_Symbol, PERIOD_CURRENT, first_shift);
         zone_lower = iLow(_Symbol, PERIOD_CURRENT, first_shift);
      }
      
      // The zone creator is the candle that confirms the PE (creates right empty space)
      int confirm_shift = iBarShift(_Symbol, PERIOD_CURRENT, g_pe_array[i].time_created);
      datetime tc = g_pe_array[i].time_created;
      
      RegisterZone(g_pe_array[i].direction, ZI_BASE_PE, zone_upper, zone_lower,
                   confirm_shift, tc, i, incl_doji);
   }
}

//+------------------------------------------------------------------+
//| Detect zones based on brake/frenazo (section 1.3.2)                |
//| Scans for valid formations and checks break condition               |
//+------------------------------------------------------------------+
void DetectZonesBrake()
{
   int available_bars = iBars(_Symbol, PERIOD_CURRENT);
   int max_shift = (g_bar_count <= 1) ? ZI_SCAN_INIT : ZI_SCAN_NORMAL;
   if(max_shift > available_bars - BRAKE_MAX_LEN - 2)
      max_shift = available_bars - BRAKE_MAX_LEN - 2;
   if(max_shift < 1) return;
   
   // Scan for formations ending at each shift
   // The "last candle" of a brake formation must be the same direction as first
   for(int shift = 1; shift <= max_shift; shift++)
   {
      ENUM_CANDLE_TYPE last_type = GetCandleType(shift);
      if(last_type == CANDLE_DOJI) continue; // Last candle must be directional
      
      // Try bullish ZI (first=bullish, last=bullish) and bearish ZI (first=bearish, last=bearish)
      if(last_type == CANDLE_BULLISH)
         TryBrakeFormation(shift, DIR_BULLISH);
      else
         TryBrakeFormation(shift, DIR_BEARISH);
   }
}

//+------------------------------------------------------------------+
//| Try to identify a brake formation ending at last_shift              |
//| dir = direction of the zone (BULLISH or BEARISH)                   |
//+------------------------------------------------------------------+
void TryBrakeFormation(int last_shift, ENUM_DIRECTION dir)
{
   int available_bars = iBars(_Symbol, PERIOD_CURRENT);
   ENUM_CANDLE_TYPE expected_bookend = (dir == DIR_BULLISH) ? CANDLE_BULLISH : CANDLE_BEARISH;
   ENUM_CANDLE_TYPE expected_brake   = (dir == DIR_BULLISH) ? CANDLE_BEARISH : CANDLE_BULLISH;
   
   // Try brake lengths from 1 to 3 candles between the two bookend candles
   for(int brake_len = 1; brake_len <= 3; brake_len++)
   {
      int first_shift = last_shift + brake_len + 1;
      if(first_shift >= available_bars) continue;
      
      // First candle must match direction
      if(GetCandleType(first_shift) != expected_bookend) continue;
      
      // Validate the brake candles between first and last
      bool valid_pattern = false;
      int brake_shifts[];
      ArrayResize(brake_shifts, brake_len);
      
      for(int b = 0; b < brake_len; b++)
         brake_shifts[b] = last_shift + brake_len - b; // From left to right
      
      // Check pattern validity
      valid_pattern = ValidateBrakePattern(brake_shifts, brake_len, expected_brake);
      if(!valid_pattern) continue;
      
      // Formation found! Calculate times for dedup
      datetime t_first = iTime(_Symbol, PERIOD_CURRENT, first_shift);
      datetime t_last  = iTime(_Symbol, PERIOD_CURRENT, last_shift);
      
      // Dedup check FIRST: already registered, pending, or rejected?
      if(IsBrakeAlreadyProcessed(t_first, t_last, dir)) continue;
      
      // Check 1.5x body rule (condition from page 7)
      if(!CheckBrakeBodyRule(first_shift, brake_shifts, brake_len, dir))
      {
         // Register as rejected so we don't re-check every bar
         AddBrakeRejected(dir, t_first, t_last);
         continue;
      }
      
      // Calculate brake candle extremes
      double brake_high = 0, brake_low = DBL_MAX;
      double brake_close_min = DBL_MAX, brake_close_max = 0;
      
      for(int b = 0; b < brake_len; b++)
      {
         int s = brake_shifts[b];
         brake_high = MathMax(brake_high, iHigh(_Symbol, PERIOD_CURRENT, s));
         brake_low  = MathMin(brake_low,  iLow(_Symbol, PERIOD_CURRENT, s));
         double bc  = iClose(_Symbol, PERIOD_CURRENT, s);
         brake_close_min = MathMin(brake_close_min, bc);
         brake_close_max = MathMax(brake_close_max, bc);
      }
      
      // Zone boundaries = brake candles range (wicks included)
      double zone_upper = brake_high;
      double zone_lower = brake_low;
      
      // Check immediate confirmation (break)
      double close_last = iClose(_Symbol, PERIOD_CURRENT, last_shift);
      
      if(dir == DIR_BULLISH)
      {
         // Last bullish candle must close ABOVE brake high
         if(close_last > brake_high)
         {
            // Immediate zone creation
            RegisterZone(dir, ZI_BASE_BRAKE, zone_upper, zone_lower,
                         last_shift, iTime(_Symbol, PERIOD_CURRENT, last_shift), -1, false);
         }
         else
         {
            // Deferred: add to pending, wait for break
            AddBrakePending(dir, brake_high, brake_low,
                            brake_close_min, // Invalidation: close below lowest close of brake
                            zone_upper, zone_lower, t_first, t_last);
         }
      }
      else // DIR_BEARISH
      {
         // Last bearish candle must close BELOW brake low
         if(close_last < brake_low)
         {
            RegisterZone(dir, ZI_BASE_BRAKE, zone_upper, zone_lower,
                         last_shift, iTime(_Symbol, PERIOD_CURRENT, last_shift), -1, false);
         }
         else
         {
            AddBrakePending(dir, brake_high, brake_low,
                            brake_close_max, // Invalidation: close above highest close of brake
                            zone_upper, zone_lower, t_first, t_last);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Validate brake candle pattern between bookend candles               |
//| expected_brake = BEARISH for bullish ZI, BULLISH for bearish ZI    |
//+------------------------------------------------------------------+
bool ValidateBrakePattern(int &shifts[], int count, ENUM_CANDLE_TYPE expected_brake)
{
   if(count < 1 || count > 3) return false;
   
   ENUM_CANDLE_TYPE types[];
   ArrayResize(types, count);
   for(int i = 0; i < count; i++)
      types[i] = GetCandleType(shifts[i]);
   
   if(count == 1)
   {
      // Valid: 1 brake candle OR 1 doji
      return (types[0] == expected_brake || types[0] == CANDLE_DOJI);
   }
   else if(count == 2)
   {
      // Valid patterns: doji+brake, brake+doji, brake+brake
      if(types[0] == CANDLE_DOJI && types[1] == expected_brake) return true;
      if(types[0] == expected_brake && types[1] == CANDLE_DOJI) return true;
      if(types[0] == expected_brake && types[1] == expected_brake) return true;
      return false;
   }
   else // count == 3
   {
      // Valid: doji+brake+brake, brake+brake+doji
      if(types[0] == CANDLE_DOJI && types[1] == expected_brake && types[2] == expected_brake) return true;
      if(types[0] == expected_brake && types[1] == expected_brake && types[2] == CANDLE_DOJI) return true;
      return false;
   }
}

//+------------------------------------------------------------------+
//| Check 1.5x body rule for brake formation (page 7 conditions)       |
//| Returns true if formation passes (allowed), false if rejected       |
//+------------------------------------------------------------------+
bool CheckBrakeBodyRule(int first_shift, int &brake_shifts[], int brake_count, ENUM_DIRECTION dir)
{
   int available_bars = iBars(_Symbol, PERIOD_CURRENT);
   
   // Find the candle before the formation
   int prev_shift = first_shift + 1;
   if(prev_shift >= available_bars) return true; // No prev candle, allow
   
   ENUM_CANDLE_TYPE prev_type = GetCandleType(prev_shift);
   
   // If prev is Doji, look one more to the left (rule 4)
   if(prev_type == CANDLE_DOJI)
   {
      prev_shift = first_shift + 2;
      if(prev_shift >= available_bars) return true;
      prev_type = GetCandleType(prev_shift);
      if(prev_type == CANDLE_DOJI) return true; // Two Dogis, no limit
   }
   
   ENUM_CANDLE_TYPE first_type = (dir == DIR_BULLISH) ? CANDLE_BULLISH : CANDLE_BEARISH;
   
   // Rule 3: If prev is same direction as first candle → no limit
   if(prev_type == first_type) return true;
   
   // Rule 1 & 2: Prev is opposite direction → check 1.5x limit
   double first_body = GetBodySize(first_shift);
   if(first_body == 0) return true; // Avoid division by zero
   
   // Sum brake candle bodies
   double brake_body_sum = 0;
   for(int i = 0; i < brake_count; i++)
      brake_body_sum += GetBodySize(brake_shifts[i]);
   
   double ratio = brake_body_sum / first_body;
   
   if(ratio > 1.5)
   {
      g_logger.LogDecision(StringFormat("KR|%.2f|%d", ratio, first_shift));
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if a brake formation was already processed                    |
//+------------------------------------------------------------------+
bool IsBrakeAlreadyProcessed(datetime t_first, datetime t_last, ENUM_DIRECTION dir)
{
   // Check existing zones (including mitigated/expired to avoid re-creating)
   for(int i = 0; i < g_zi_count; i++)
   {
      if(g_zi_array[i].direction != dir) continue;
      if(g_zi_array[i].base_type == ZI_BASE_PE) continue; // Only check brake/both
      if(g_zi_array[i].time_created == t_last) return true;
   }
   
   // Check ALL pending brakes (including invalidated/confirmed)
   for(int i = 0; i < g_brake_count; i++)
   {
      if(g_brake_pending[i].direction != dir) continue;
      if(g_brake_pending[i].time_first == t_first &&
         g_brake_pending[i].time_last == t_last) return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Add a brake formation to the pending confirmation list              |
//+------------------------------------------------------------------+
void AddBrakePending(ENUM_DIRECTION dir, double brake_high, double brake_low,
                     double close_limit, double zone_upper, double zone_lower,
                     datetime t_first, datetime t_last)
{
   int idx = -1;
   for(int i = 0; i < g_brake_count; i++)
   {
      if(!g_brake_pending[i].is_valid) { idx = i; break; }
   }
   if(idx < 0)
   {
      if(g_brake_count >= ArraySize(g_brake_pending))
      {
         ArrayResize(g_brake_pending, g_brake_count + 50);
         for(int i = g_brake_count; i < g_brake_count + 50; i++) g_brake_pending[i].Reset();
      }
      idx = g_brake_count;
      g_brake_count++;
   }
   
   g_brake_pending[idx].is_valid = true;
   g_brake_pending[idx].direction = dir;
   g_brake_pending[idx].brake_high = brake_high;
   g_brake_pending[idx].brake_low  = brake_low;
   g_brake_pending[idx].brake_close_limit = close_limit;
   g_brake_pending[idx].zone_upper = zone_upper;
   g_brake_pending[idx].zone_lower = zone_lower;
   g_brake_pending[idx].time_first = t_first;
   g_brake_pending[idx].time_last  = t_last;
   g_brake_pending[idx].time_creator = 0; // Not yet confirmed
   
   g_logger.Log("BRAKE", StringFormat("KP|#%d|%s|%.1f|%.1f|%.1f",
      idx, (dir == DIR_BULLISH) ? "B" : "R",
      (dir == DIR_BULLISH) ? brake_high : brake_low, zone_lower, zone_upper));
}

//+------------------------------------------------------------------+
//| Register a rejected brake (dedup only, immediately invalid)        |
//+------------------------------------------------------------------+
void AddBrakeRejected(ENUM_DIRECTION dir, datetime t_first, datetime t_last)
{
   // Expand array if needed
   if(g_brake_count >= ArraySize(g_brake_pending))
   {
      ArrayResize(g_brake_pending, g_brake_count + 50);
      for(int i = g_brake_count; i < g_brake_count + 50; i++) g_brake_pending[i].Reset();
   }
   int idx = g_brake_count;
   g_brake_count++;
   
   g_brake_pending[idx].Reset();
   g_brake_pending[idx].is_valid   = false; // Already rejected
   g_brake_pending[idx].direction  = dir;
   g_brake_pending[idx].time_first = t_first;
   g_brake_pending[idx].time_last  = t_last;
}

//+------------------------------------------------------------------+
//| Process pending brake formations: check bar[1] for break/invalid   |
//+------------------------------------------------------------------+
void ProcessBrakePending()
{
   if(g_brake_count <= 0) return;
   
   // Check bar[1] (the just-closed bar)
   double bar_close = iClose(_Symbol, PERIOD_CURRENT, 1);
   datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, 1);
   
   for(int i = 0; i < g_brake_count; i++)
   {
      if(!g_brake_pending[i].is_valid) continue;
      
      if(g_brake_pending[i].direction == DIR_BULLISH)
      {
         // Bullish ZI: need candle to close ABOVE brake_high
         if(bar_close > g_brake_pending[i].brake_high)
         {
            // Confirmed! Create zone
            int bar_shift = 1;
            RegisterZone(DIR_BULLISH, ZI_BASE_BRAKE,
                         g_brake_pending[i].zone_upper, g_brake_pending[i].zone_lower,
                         bar_shift, bar_time, -1, false);
            g_brake_pending[i].is_valid = false;
            g_logger.Log("BRAKE", StringFormat("OK|#%d|B", i));
         }
         // Invalidation: candle closes below lowest close of brake candles
         else if(bar_close < g_brake_pending[i].brake_close_limit)
         {
            g_brake_pending[i].is_valid = false;
            g_logger.Log("BRAKE", StringFormat("KA|#%d|B", i));
         }
      }
      else // DIR_BEARISH
      {
         // Bearish ZI: need candle to close BELOW brake_low
         if(bar_close < g_brake_pending[i].brake_low)
         {
            int bar_shift = 1;
            RegisterZone(DIR_BEARISH, ZI_BASE_BRAKE,
                         g_brake_pending[i].zone_upper, g_brake_pending[i].zone_lower,
                         bar_shift, bar_time, -1, false);
            g_brake_pending[i].is_valid = false;
            g_logger.Log("BRAKE", StringFormat("OK|#%d|R", i));
         }
         else if(bar_close > g_brake_pending[i].brake_close_limit)
         {
            g_brake_pending[i].is_valid = false;
            g_logger.Log("BRAKE", StringFormat("KA|#%d|R", i));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update mitigation status for all zones using bar[1]                |
//| Handles partial and complete mitigation                            |
//+------------------------------------------------------------------+
void UpdateMitigation()
{
   double bar_high  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double bar_low   = iLow(_Symbol, PERIOD_CURRENT, 1);
   double bar_close = iClose(_Symbol, PERIOD_CURRENT, 1);
   datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, 1);
   
   for(int i = 0; i < g_zi_count; i++)
   {
      if(!g_zi_array[i].is_valid) continue;
      if(g_zi_array[i].state == ZI_MITIGATED || g_zi_array[i].state == ZI_EXPIRED) continue;
      
      double z_upper = g_zi_array[i].upper_price;
      double z_lower = g_zi_array[i].lower_price;
      
      // FIX Bug 5: Creator candle itself cannot mitigate its own zone
      if(bar_time == g_zi_array[i].time_creator) continue;
      
      // "Next candle after creator" rule (spec 2.4.3)
      datetime next_after_creator = g_zi_array[i].time_creator + PeriodSeconds();
      if(bar_time == next_after_creator)
      {
         if(g_zi_array[i].direction == DIR_BULLISH)
         {
            if(bar_close >= z_lower) continue;
         }
         else
         {
            if(bar_close <= z_upper) continue;
         }
      }
      
      // Complete mitigation: price penetrates through the zone
      // Bullish zone: mitigated if bar low reaches at or below lower bound
      // Bearish zone: mitigated if bar high reaches at or above upper bound
      if((g_zi_array[i].direction == DIR_BULLISH && bar_low <= z_lower) ||
         (g_zi_array[i].direction == DIR_BEARISH && bar_high >= z_upper))
      {
         g_zi_array[i].state = ZI_MITIGATED;
         g_zi_array[i].is_valid = false;
         g_logger.LogZone("MITIGATED_FULL", i, g_zi_array[i]);
         continue;
      }
      
      // Check if bar[1] overlaps with zone (only needed for partial mitigation)
      if(bar_low > z_upper || bar_high < z_lower) continue;
      
      // Calculate overlap
      double overlap_top    = MathMin(bar_high, z_upper);
      double overlap_bottom = MathMax(bar_low, z_lower);
      
      if(overlap_bottom > overlap_top) continue;
      
      // Partial mitigation: shrink zone to untouched portion
      g_zi_array[i].state = ZI_PARTIAL;
      
      if(g_zi_array[i].direction == DIR_BULLISH)
      {
         if(bar_high >= z_upper && bar_low > z_lower)
         {
            g_zi_array[i].upper_price = bar_low;
         }
         else if(bar_low <= z_lower && bar_high < z_upper)
         {
            g_zi_array[i].lower_price = bar_high;
         }
         else if(bar_low > z_lower && bar_high < z_upper)
         {
            double top_piece = z_upper - bar_high;
            double bottom_piece = bar_low - z_lower;
            if(bottom_piece >= top_piece)
               g_zi_array[i].upper_price = bar_low;
            else
               g_zi_array[i].lower_price = bar_high;
         }
      }
      else // DIR_BEARISH
      {
         if(bar_low <= z_lower && bar_high < z_upper)
         {
            g_zi_array[i].lower_price = bar_high;
         }
         else if(bar_high >= z_upper && bar_low > z_lower)
         {
            g_zi_array[i].upper_price = bar_low;
         }
         else if(bar_low > z_lower && bar_high < z_upper)
         {
            double top_piece = z_upper - bar_high;
            double bottom_piece = bar_low - z_lower;
            if(top_piece >= bottom_piece)
               g_zi_array[i].lower_price = bar_high;
            else
               g_zi_array[i].upper_price = bar_low;
         }
      }
      
      // Check if remaining zone is too small (< 1 point)
      if(g_zi_array[i].upper_price - g_zi_array[i].lower_price < g_point)
      {
         g_zi_array[i].state = ZI_MITIGATED;
         g_zi_array[i].is_valid = false;
         g_logger.LogZone("MITIGATED_SHRUNK", i, g_zi_array[i]);
      }
      else
      {
         g_logger.LogZone("PARTIAL_MITIG", i, g_zi_array[i]);
      }
   }
}

//+------------------------------------------------------------------+
//| Run historical mitigation for zones created by deep scan           |
//| Processes bars between zone creation and bar[2] retroactively      |
//+------------------------------------------------------------------+
void RunHistoricalMitigation()
{
   int available = iBars(_Symbol, PERIOD_CURRENT);
   
   for(int i = 0; i < g_zi_count; i++)
   {
      if(!g_zi_array[i].is_valid) continue;
      
      int created_shift = g_zi_array[i].bar_created;
      if(created_shift <= 2) continue;
      
      datetime creator_time = g_zi_array[i].time_creator;
      datetime next_after_creator = creator_time + PeriodSeconds();
      
      for(int s = created_shift - 1; s >= 2; s--)
      {
         if(!g_zi_array[i].is_valid) break;
         if(s >= available) continue;
         
         double bh = iHigh(_Symbol, PERIOD_CURRENT, s);
         double bl = iLow(_Symbol, PERIOD_CURRENT, s);
         double bc = iClose(_Symbol, PERIOD_CURRENT, s);
         datetime bt = iTime(_Symbol, PERIOD_CURRENT, s);
         
         double z_upper = g_zi_array[i].upper_price;
         double z_lower = g_zi_array[i].lower_price;
         
         // FIX Bug 5: Creator candle cannot mitigate its own zone
         if(bt == creator_time) continue;
         
         // "Next candle after creator" rule
         if(bt == next_after_creator)
         {
            if(g_zi_array[i].direction == DIR_BULLISH)
            {
               if(bc >= z_lower) continue;
            }
            else
            {
               if(bc <= z_upper) continue;
            }
         }
         
         // Complete mitigation: price penetrates through the zone
         if((g_zi_array[i].direction == DIR_BULLISH && bl <= z_lower) ||
            (g_zi_array[i].direction == DIR_BEARISH && bh >= z_upper))
         {
            g_zi_array[i].state = ZI_MITIGATED;
            g_zi_array[i].is_valid = false;
            g_logger.LogZone("HIST_MITIGATED_FULL", i, g_zi_array[i]);
            break;
         }
         
         // No overlap check (only needed for partial mitigation)
         if(bl > z_upper || bh < z_lower) continue;
         
         // Partial mitigation
         g_zi_array[i].state = ZI_PARTIAL;
         
         if(g_zi_array[i].direction == DIR_BULLISH)
         {
            if(bh >= z_upper && bl > z_lower)
               g_zi_array[i].upper_price = bl;
            else if(bl <= z_lower && bh < z_upper)
               g_zi_array[i].lower_price = bh;
            else if(bl > z_lower && bh < z_upper)
            {
               double top_piece = z_upper - bh;
               double bottom_piece = bl - z_lower;
               if(bottom_piece >= top_piece)
                  g_zi_array[i].upper_price = bl;
               else
                  g_zi_array[i].lower_price = bh;
            }
         }
         else
         {
            if(bl <= z_lower && bh < z_upper)
               g_zi_array[i].lower_price = bh;
            else if(bh >= z_upper && bl > z_lower)
               g_zi_array[i].upper_price = bl;
            else if(bl > z_lower && bh < z_upper)
            {
               double top_piece = z_upper - bh;
               double bottom_piece = bl - z_lower;
               if(top_piece >= bottom_piece)
                  g_zi_array[i].lower_price = bh;
               else
                  g_zi_array[i].upper_price = bl;
            }
         }
         
         // Check if remaining zone too small
         if(g_zi_array[i].upper_price - g_zi_array[i].lower_price < g_point)
         {
            g_zi_array[i].state = ZI_MITIGATED;
            g_zi_array[i].is_valid = false;
            g_logger.LogZone("HIST_MITIGATED_SHRUNK", i, g_zi_array[i]);
            break;
         }
      }
   }
   
   // Rebuild grand zones after historical mitigation
   BuildGrandZones();
   
   g_logger.LogDecision(StringFormat("hist_done|%d",
      CountValidZones()));
}

//+------------------------------------------------------------------+
//| Count valid zones (utility for logging)                            |
//+------------------------------------------------------------------+
int CountValidZones()
{
   int count = 0;
   for(int i = 0; i < g_zi_count; i++)
      if(g_zi_array[i].is_valid) count++;
   return count;
}

//+------------------------------------------------------------------+
//| Build Grand Zones: group overlapping same-direction zones           |
//| Rebuilds every bar for accuracy                                    |
//+------------------------------------------------------------------+
void BuildGrandZones()
{
   // Reset all grand zones
   for(int i = 0; i < g_gz_count; i++)
      g_grand_zones[i].Reset();
   g_gz_count = 0;
   
   // Track which zones have been assigned to a grand zone
   bool assigned[];
   ArrayResize(assigned, g_zi_count);
   ArrayInitialize(assigned, false);
   
   for(int i = 0; i < g_zi_count; i++)
   {
      if(!g_zi_array[i].is_valid || assigned[i]) continue;
      
      // Start a new grand zone with zone i
      if(g_gz_count >= ArraySize(g_grand_zones))
      {
         ArrayResize(g_grand_zones, g_gz_count + 20);
         for(int k = g_gz_count; k < g_gz_count + 20; k++) g_grand_zones[k].Reset();
      }
      
      int gz_idx = g_gz_count;
      g_grand_zones[gz_idx].is_valid   = true;
      g_grand_zones[gz_idx].direction  = g_zi_array[i].direction;
      g_grand_zones[gz_idx].upper_price= g_zi_array[i].upper_price;
      g_grand_zones[gz_idx].lower_price= g_zi_array[i].lower_price;
      
      ArrayResize(g_grand_zones[gz_idx].zone_indices, 1);
      g_grand_zones[gz_idx].zone_indices[0] = i;
      g_grand_zones[gz_idx].zone_count = 1;
      assigned[i] = true;
      
      // Find all overlapping zones with same direction (iteratively)
      bool found_new = true;
      while(found_new)
      {
         found_new = false;
         for(int j = 0; j < g_zi_count; j++)
         {
            if(!g_zi_array[j].is_valid || assigned[j]) continue;
            if(g_zi_array[j].direction != g_grand_zones[gz_idx].direction) continue;
            
            // Check overlap with current grand zone bounds
            if(g_zi_array[j].lower_price <= g_grand_zones[gz_idx].upper_price &&
               g_zi_array[j].upper_price >= g_grand_zones[gz_idx].lower_price)
            {
               // Overlaps! Add to grand zone
               int cnt = g_grand_zones[gz_idx].zone_count;
               ArrayResize(g_grand_zones[gz_idx].zone_indices, cnt + 1);
               g_grand_zones[gz_idx].zone_indices[cnt] = j;
               g_grand_zones[gz_idx].zone_count = cnt + 1;
               
               // Expand bounds
               g_grand_zones[gz_idx].upper_price = MathMax(g_grand_zones[gz_idx].upper_price,
                                                            g_zi_array[j].upper_price);
               g_grand_zones[gz_idx].lower_price = MathMin(g_grand_zones[gz_idx].lower_price,
                                                            g_zi_array[j].lower_price);
               assigned[j] = true;
               found_new = true; // Bounds expanded, might overlap with more zones
            }
         }
      }
      
      g_gz_count++;
   }
}
//+------------------------------------------------------------------+
