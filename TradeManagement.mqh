//+------------------------------------------------------------------+
//| TradeManagement.mqh                                               |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

// Phase 6: Common Rules =====================================================

//+------------------------------------------------------------------+
//| Manage breakeven for active position                               |
//| Stage 1: ratio >= 1:1.3 OR 2 strict PE → move SL to ZI/PE        |
//|          but NOT past entry level                                  |
//| Stage 2: ratio >= 1:3 → SL can pass entry, move to strict PE or   |
//|          penultimate ZI                                            |
//+------------------------------------------------------------------+
void ManageBreakeven()
{
   if(!inpEnableBreakeven) return;
   if(!g_context.is_busy || g_context.active_ticket == 0) return;
   
   // Select active position
   if(!PositionSelectByTicket(g_context.active_ticket))
   {
      // Position closed externally or by SL/TP
      HandlePositionClosed();
      return;
   }
   
   double entry    = position_info.PriceOpen();
   double current_sl = position_info.StopLoss();
   double current_tp = position_info.TakeProfit();
   ENUM_POSITION_TYPE pos_type = position_info.PositionType();
   
   double bar1_close = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   // Calculate current profit ratio
   double sl_distance = MathAbs(entry - g_context.sl_price_active);
   if(sl_distance == 0) return;
   
   double profit_distance;
   if(pos_type == POSITION_TYPE_BUY)
      profit_distance = bar1_close - entry;
   else
      profit_distance = entry - bar1_close;
   
   double ratio = (sl_distance > 0) ? profit_distance / sl_distance : 0;
   
   // Count strict PE since entry for Stage 1 trigger
   CountStrictPESinceEntry();
   
   // Determine current stage
   if(g_context.be_stage == BE_NONE)
   {
      // Check for Stage 1 trigger
      if(ratio >= 1.3 || g_context.strict_pe_since_entry >= 2)
      {
         g_context.be_stage = BE_STAGE_1;
         g_logger.LogDecision(StringFormat("B1|%.2f|%d",
            ratio, g_context.strict_pe_since_entry));
      }
   }
   
   if(g_context.be_stage == BE_STAGE_1 && ratio >= 3.0)
   {
      g_context.be_stage = BE_STAGE_2;
      g_logger.LogDecision(StringFormat("B2|%.2f", ratio));
   }
   
   // Move SL based on stage
   if(g_context.be_stage == BE_NONE) return;
   
   double new_sl = 0;
   ENUM_DIRECTION friendly_dir = (pos_type == POSITION_TYPE_BUY) ? DIR_BULLISH : DIR_BEARISH;
   
   if(g_context.be_stage == BE_STAGE_1)
   {
      // Move to friendly ZI extreme (priority) or PE extreme
      // Cannot pass entry level
      new_sl = FindBestSLLevel(friendly_dir, false);
      
      if(new_sl == 0) return; // No suitable level found
      
      // Clamp: cannot pass entry
      if(pos_type == POSITION_TYPE_BUY)
         new_sl = MathMin(new_sl, entry);
      else
         new_sl = MathMax(new_sl, entry);
   }
   else // BE_STAGE_2
   {
      // Move to strict PE or PENULTIMATE ZI. Can pass entry.
      new_sl = FindBestSLLevel(friendly_dir, true);
      if(new_sl == 0) return;
   }
   
   new_sl = NormalizePrice(new_sl);
   
   // Only move SL in profitable direction (never widen)
   if(pos_type == POSITION_TYPE_BUY)
   {
      if(new_sl <= current_sl) return; // Don't move SL down
   }
   else
   {
      if(new_sl >= current_sl) return; // Don't move SL up
   }
   
   // Check minimum distance from current price
   double min_dist = symbol_info.StopsLevel() * g_point;
   double current_price = (pos_type == POSITION_TYPE_BUY) ? GetBid() : GetAsk();
   if(MathAbs(current_price - new_sl) < min_dist) return;
   
   // Modify position
   if(trade.PositionModify(g_context.active_ticket, new_sl, current_tp))
   {
      g_logger.LogBE("BREAKEVEN", g_context.active_ticket, current_sl, new_sl);
      g_context.sl_price_active = new_sl;
   }
   else
   {
      g_logger.LogError(StringFormat("BE modify failed: %d (%s)",
         GetLastError(), GetRetcodeDescription(trade.ResultRetcode())));
   }
}

//+------------------------------------------------------------------+
//| Find best SL level from friendly ZI and PE                         |
//| stage2: if true, use strict PE and penultimate ZI, can pass entry  |
//+------------------------------------------------------------------+
double FindBestSLLevel(ENUM_DIRECTION friendly_dir, bool stage2)
{
   double best_zi_level = 0;
   double best_pe_level = 0;
   double entry = g_context.entry_price_active;
   bool is_buy = (g_context.active_direction == TRADE_LONG);
   
   // Find ZI levels
   if(!stage2)
   {
      // Stage 1: any friendly ZI between entry and current price
      best_zi_level = FindLatestFriendlyZILevel(friendly_dir, is_buy);
   }
   else
   {
      // Stage 2: PENULTIMATE friendly ZI (skip the nearest one)
      best_zi_level = FindPenultimateFriendlyZILevel(friendly_dir, is_buy);
   }
   
   // Find PE levels
   if(!stage2)
   {
      // Stage 1: any PE extreme
      best_pe_level = FindLatestFriendlyPELevel(friendly_dir, is_buy, false);
   }
   else
   {
      // Stage 2: strict PE only
      best_pe_level = FindLatestFriendlyPELevel(friendly_dir, is_buy, true);
   }
   
   // Prioritize ZI over PE
   if(best_zi_level != 0) return best_zi_level;
   if(best_pe_level != 0) return best_pe_level;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Find the latest friendly ZI level for SL placement                 |
//+------------------------------------------------------------------+
double FindLatestFriendlyZILevel(ENUM_DIRECTION dir, bool is_buy)
{
   double best = 0;
   datetime latest_time = 0;
   
   for(int i = 0; i < g_zi_count; i++)
   {
      if(!g_zi_array[i].is_valid) continue;
      if(g_zi_array[i].direction != dir) continue;
      
      double level;
      if(is_buy)
         level = g_zi_array[i].lower_price; // SL below bullish ZI
      else
         level = g_zi_array[i].upper_price; // SL above bearish ZI
      
      // Must be between entry and current price direction
      double current_price = (is_buy) ? GetBid() : GetAsk();
      if(is_buy)
      {
         if(level < g_context.entry_price_active - MathAbs(g_context.entry_price_active - g_context.sl_price_active))
            continue; // Too far below
         if(level > current_price) continue;
      }
      else
      {
         if(level > g_context.entry_price_active + MathAbs(g_context.entry_price_active - g_context.sl_price_active))
            continue;
         if(level < current_price) continue;
      }
      
      if(g_zi_array[i].time_created > latest_time)
      {
         latest_time = g_zi_array[i].time_created;
         best = level;
      }
   }
   return best;
}

//+------------------------------------------------------------------+
//| Find penultimate friendly ZI level (skip most recent)              |
//| "Penultimate" = second-to-last formed ZI that is between           |
//|  entry and current price (profitable side only)                    |
//+------------------------------------------------------------------+
double FindPenultimateFriendlyZILevel(ENUM_DIRECTION dir, bool is_buy)
{
   // Collect all valid friendly ZI on the profitable side
   datetime times[];
   double levels[];
   int count = 0;
   
   double current_price = is_buy ? GetBid() : GetAsk();
   double entry = g_context.entry_price_active;
   
   for(int i = 0; i < g_zi_count; i++)
   {
      if(!g_zi_array[i].is_valid) continue;
      if(g_zi_array[i].direction != dir) continue;
      
      double level = is_buy ? g_zi_array[i].lower_price : g_zi_array[i].upper_price;
      
      // Must be on the profitable side of current price
      if(is_buy && level > current_price) continue;
      if(!is_buy && level < current_price) continue;
      
      ArrayResize(times, count + 1);
      ArrayResize(levels, count + 1);
      times[count] = g_zi_array[i].time_created;
      levels[count] = level;
      count++;
   }
   
   if(count < 2) return 0; // Not enough zones for penultimate
   
   // Sort by time descending (most recent first)
   for(int a = 0; a < count - 1; a++)
   {
      for(int b = a + 1; b < count; b++)
      {
         if(times[b] > times[a])
         {
            datetime tmp_t = times[a]; times[a] = times[b]; times[b] = tmp_t;
            double tmp_l = levels[a]; levels[a] = levels[b]; levels[b] = tmp_l;
         }
      }
   }
   
   // Return penultimate (index 1 = second most recent)
   return levels[1];
}

//+------------------------------------------------------------------+
//| Find latest friendly PE level for SL                               |
//+------------------------------------------------------------------+
double FindLatestFriendlyPELevel(ENUM_DIRECTION dir, bool is_buy, bool strict_only)
{
   double best = 0;
   datetime latest_time = 0;
   
   for(int i = 0; i < g_pe_count; i++)
   {
      if(!g_pe_array[i].is_valid) continue;
      if(g_pe_array[i].direction != dir) continue;
      if(strict_only && g_pe_array[i].pe_type != PE_STRICT) continue;
      
      double level;
      if(is_buy)
         level = g_pe_array[i].low_extreme; // SL at lows of bullish PE
      else
         level = g_pe_array[i].high_extreme; // SL at highs of bearish PE
      
      double current_price = is_buy ? GetBid() : GetAsk();
      if(is_buy && level > current_price) continue;
      if(!is_buy && level < current_price) continue;
      
      if(g_pe_array[i].time_created > latest_time)
      {
         latest_time = g_pe_array[i].time_created;
         best = level;
      }
   }
   return best;
}

//+------------------------------------------------------------------+
//| Count strict PE formed since entry (for BE Stage 1 trigger)        |
//+------------------------------------------------------------------+
void CountStrictPESinceEntry()
{
   if(!g_context.is_busy) return;
   
   ENUM_DIRECTION friendly = (g_context.active_direction == TRADE_LONG) ? DIR_BULLISH : DIR_BEARISH;
   int count = 0;
   
   // Get actual position open time
   datetime entry_time = 0;
   if(PositionSelectByTicket(g_context.active_ticket))
      entry_time = (datetime)PositionGetInteger(POSITION_TIME);
   
   if(entry_time == 0) entry_time = g_context.last_daily_reset; // Fallback
   
   for(int i = 0; i < g_pe_count; i++)
   {
      if(!g_pe_array[i].is_valid) continue;
      if(g_pe_array[i].direction != friendly) continue;
      if(g_pe_array[i].pe_type != PE_STRICT) continue;
      
      // PE must be formed AFTER position was opened
      if(g_pe_array[i].time_created > entry_time)
         count++;
   }
   
   g_context.strict_pe_since_entry = count;
}

//+------------------------------------------------------------------+
//| Manage trailing stop (same logic as BE but continuously updates)    |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!inpEnableTrailing) return;
   if(!g_context.is_busy || g_context.active_ticket == 0) return;
   if(g_context.be_stage == BE_NONE) return; // Trailing only after BE activated
   
   // Trailing is effectively the same as breakeven management
   // The ManageBreakeven already moves SL to latest ZI/PE levels
   // This function handles the "continuous" aspect on each bar
   // Already covered by ManageBreakeven() being called each bar
   
   // Additional trailing: if user has manually moved SL, respect it
   if(!PositionSelectByTicket(g_context.active_ticket)) return;
   
   double current_sl = position_info.StopLoss();
   
   // If user moved SL beyond what EA would set, don't interfere (rule: absolute freedom)
   // We track this by comparing with our last known SL
   if(g_context.active_direction == TRADE_LONG)
   {
      if(current_sl > g_context.sl_price_active)
         g_context.sl_price_active = current_sl; // User moved SL up, respect it
   }
   else
   {
      if(current_sl < g_context.sl_price_active)
         g_context.sl_price_active = current_sl; // User moved SL down
   }
}

//+------------------------------------------------------------------+
//| Handle position closed (SL/TP/manual) - detect loss                |
//+------------------------------------------------------------------+
void HandlePositionClosed()
{
   if(!g_context.is_busy) return;
   
   // Position no longer exists - check deal history for result
   ulong ticket = g_context.active_ticket;
   
   // Look in history for the closing deal
   datetime from_time = g_context.last_daily_reset;
   if(from_time == 0) from_time = TimeCurrent() - 86400;
   
   HistorySelect(from_time, TimeCurrent());
   
   double profit = 0;
   bool found = false;
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0) continue;
      
      if(HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) == (long)ticket ||
         HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) == inpMagicNumber)
      {
         long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT)
         {
            profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) +
                     HistoryDealGetDouble(deal_ticket, DEAL_SWAP) +
                     HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
            found = true;
            break;
         }
      }
   }
   
   g_logger.LogTrade("POSITION_CLOSED", ticket, StringFormat("%.2f", profit));
   
   // FIX: Invalidate the pattern that was driving this position.
   // Without this, the pattern stays in PAT_ACTIVE forever and its
   // entry/SL/TP lines accumulate on the chart indefinitely.
   for(int i = 0; i < g_pat_count; i++)
   {
      if(!g_patterns[i].is_valid) continue;
      if(g_patterns[i].state == PAT_ACTIVE && g_patterns[i].ticket == ticket)
      {
         g_patterns[i].state = PAT_CLOSED;
         g_patterns[i].is_valid = false;
         g_logger.LogPattern("CLOSED", i, g_patterns[i]);
         break;
      }
   }
   
   // Reset trade context
   g_context.is_busy = false;
   g_context.active_ticket = 0;
   g_context.be_stage = BE_NONE;
   g_context.strict_pe_since_entry = 0;
   
   // If loss, trigger 13-candle wait
   if(found && profit < 0)
   {
      g_context.daily_loss_eur += MathAbs(profit);
      g_context.is_waiting_after_loss = true;
      g_context.wait_candles_remaining = inpWaitCandlesAfterLoss;
      g_context.bar_last_loss = 0; // Current bar
      
      g_logger.LogDecision(StringFormat("$L|%.2f|%d",
         profit, inpWaitCandlesAfterLoss));
      
      NotifyUser(StringFormat("Position closed with loss (%.2f). Waiting %d candles.",
         profit, inpWaitCandlesAfterLoss));
   }
   else if(found && profit >= 0)
   {
      NotifyUser(StringFormat("Position closed with profit (%.2f).", profit));
   }
}

//+------------------------------------------------------------------+
//| Check all cancellation rules for pending patterns                  |
//+------------------------------------------------------------------+
void CheckPatternCancellations()
{
   for(int i = 0; i < g_pat_count; i++)
   {
      if(!g_patterns[i].is_valid) continue;
      if(g_patterns[i].state != PAT_CONFIRMED && g_patterns[i].state != PAT_PENDING) continue;
      
      // Rule 1: 2+ strict PE after pattern → cancel
      if(CheckCancelByStrictPE(i))
      {
         CancelPattern(i, "2+ strict PE formed after pattern");
         continue;
      }
      
      // Rule 2: Price advances >2.5x pattern size
      if(CheckCancelByPriceAdvance(i))
      {
         CancelPattern(i, "Price advanced >2.5x pattern size");
         continue;
      }
      
      // Rule 3: Highest/lowest close in opposite ZI
      if(CheckCancelByCloseInZI(i))
      {
         CancelPattern(i, "Extreme close in opposite ZI");
         continue;
      }
   }
}

//+------------------------------------------------------------------+
//| Cancel Rule 1: 2+ strict PE same direction after pattern           |
//+------------------------------------------------------------------+
bool CheckCancelByStrictPE(int pat_idx)
{
   
   ENUM_DIRECTION cancel_dir;
   if(g_patterns[pat_idx].trade_dir == TRADE_LONG)
      cancel_dir = DIR_BULLISH;  // Buy Limit → 2 bullish strict PE cancel
   else
      cancel_dir = DIR_BEARISH;  // Sell Limit → 2 bearish strict PE cancel
   
   int strict_count = 0;
   datetime pat_time = g_patterns[pat_idx].time_confirmed;
   
   for(int i = 0; i < g_pe_count; i++)
   {
      if(!g_pe_array[i].is_valid) continue;
      if(g_pe_array[i].direction != cancel_dir) continue;
      if(g_pe_array[i].pe_type != PE_STRICT) continue;
      if(g_pe_array[i].time_created <= pat_time) continue; // Must be after pattern
      
      strict_count++;
      if(strict_count >= 2) return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Cancel Rule 2: Price advance >2.5x pattern size from reference     |
//+------------------------------------------------------------------+
bool CheckCancelByPriceAdvance(int pat_idx)
{
   double bar1_close = iClose(_Symbol, PERIOD_CURRENT, 1);
   ENUM_CANDLE_TYPE bar1_type = GetCandleType(1);
   
   // Reference point: engulfing close (P2) or P3 top/bottom
   double ref_price;
   double max_advance;
   
   if(g_patterns[pat_idx].type == PATTERN_2)
   {
      ref_price = g_patterns[pat_idx].fib_1.level_0; // Engulfing close
      max_advance = g_patterns[pat_idx].pattern_size_pips * g_point * 2.5;
   }
   else // PATTERN_3
   {
      double use_size = (g_patterns[pat_idx].pattern_size_extended_pips > 0) ?
                         g_patterns[pat_idx].pattern_size_extended_pips : g_patterns[pat_idx].pattern_size_pips;
      max_advance = use_size * g_point * 2.5;
      
      if(g_patterns[pat_idx].trade_dir == TRADE_LONG)
         ref_price = g_patterns[pat_idx].fib_1.level_0;  // Top of P3
      else
         ref_price = g_patterns[pat_idx].fib_1.level_100; // Bottom of P3 (which is level_0 for sells)
   }
   
   if(g_patterns[pat_idx].trade_dir == TRADE_LONG)
   {
      // Buy: check if bullish candle closed above ref + 2.5x
      if(bar1_type == CANDLE_BULLISH && bar1_close > ref_price + max_advance)
         return true;
      
      // Track highest bullish close
      if(bar1_type == CANDLE_BULLISH && bar1_close > g_patterns[pat_idx].highest_close_since)
         g_patterns[pat_idx].highest_close_since = bar1_close;
   }
   else
   {
      // Sell: check if bearish candle closed below ref - 2.5x
      if(bar1_type == CANDLE_BEARISH && bar1_close < ref_price - max_advance)
         return true;
      
      if(bar1_type == CANDLE_BEARISH && bar1_close < g_patterns[pat_idx].lowest_close_since)
         g_patterns[pat_idx].lowest_close_since = bar1_close;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Cancel Rule 3: Highest/lowest close since pattern is in opp ZI     |
//+------------------------------------------------------------------+
bool CheckCancelByCloseInZI(int pat_idx)
{
   double bar1_close = iClose(_Symbol, PERIOD_CURRENT, 1);
   ENUM_CANDLE_TYPE bar1_type = GetCandleType(1);
   
   if(g_patterns[pat_idx].trade_dir == TRADE_LONG)
   {
      // Buy: the highest bullish close must NOT be in a bearish ZI
      if(bar1_type == CANDLE_BULLISH && bar1_close >= g_patterns[pat_idx].highest_close_since)
      {
         // Check if this close is inside a BEARISH ZI created BEFORE the pattern
         for(int z = 0; z < g_zi_count; z++)
         {
            if(!g_zi_array[z].is_valid) continue;
            if(g_zi_array[z].direction != DIR_BEARISH) continue;
            
            // ZI must have been created BEFORE the pattern
            if(g_zi_array[z].time_created >= g_patterns[pat_idx].time_confirmed) continue;
            
            if(bar1_close >= g_zi_array[z].lower_price && bar1_close <= g_zi_array[z].upper_price)
               return true;
         }
      }
   }
   else
   {
      // Sell: the lowest bearish close must NOT be in a bullish ZI
      if(bar1_type == CANDLE_BEARISH && bar1_close <= g_patterns[pat_idx].lowest_close_since)
      {
         for(int z = 0; z < g_zi_count; z++)
         {
            if(!g_zi_array[z].is_valid) continue;
            if(g_zi_array[z].direction != DIR_BULLISH) continue;
            if(g_zi_array[z].time_created >= g_patterns[pat_idx].time_confirmed) continue;
            
            if(bar1_close >= g_zi_array[z].lower_price && bar1_close <= g_zi_array[z].upper_price)
               return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Cancel a pattern: mark invalid, delete pending order if exists      |
//+------------------------------------------------------------------+
void CancelPattern(int pat_idx, string reason)
{
   g_patterns[pat_idx].state = PAT_CANCELLED;
   g_patterns[pat_idx].is_valid = false;
   g_logger.LogCancel(reason, pat_idx);
   
   // Delete pending order if one was placed
   if(g_patterns[pat_idx].ticket > 0)
   {
      if(OrderSelect(g_patterns[pat_idx].ticket))
      {
         trade.OrderDelete(g_patterns[pat_idx].ticket);
         g_logger.LogTrade("ORDER_CANCELLED", g_patterns[pat_idx].ticket, reason);
         g_context.pending_count = MathMax(0, g_context.pending_count - 1);
      }
      g_patterns[pat_idx].ticket = 0;
   }
   
   NotifyUser(StringFormat("Pattern cancelled: %s", reason));
}

//+------------------------------------------------------------------+
//| Prioritize among valid patterns and execute orders                  |
//| Rules:                                                             |
//|  - Among last 3 same-direction: most restrictive entry wins        |
//|  - Different directions: both can coexist (first activated wins)    |
//|  - Monotask: no new position if one open                           |
//|  - 13-candle wait after loss                                       |
//|  - Trading hours check                                             |
//+------------------------------------------------------------------+
void PrioritizeAndExecute()
{
   // First, check if position is still alive
   if(g_context.is_busy && g_context.active_ticket > 0)
   {
      if(!PositionSelectByTicket(g_context.active_ticket))
         HandlePositionClosed();
   }
   
   // Monotask check: if position open, only manage it, no new entries
   if(g_context.is_busy) return;
   
   // ADDITIONAL SAFETY: verify no position exists with our magic number
   // (catches cases where is_busy got out of sync)
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!position_info.SelectByIndex(i)) continue;
      if(position_info.Symbol() != _Symbol) continue;
      if(position_info.Magic() != inpMagicNumber) continue;
      
      // Found an active position we didn't know about — sync context
      g_context.is_busy = true;
      g_context.active_ticket = position_info.Ticket();
      g_context.active_direction = (position_info.PositionType() == POSITION_TYPE_BUY) ? 
                                    TRADE_LONG : TRADE_SHORT;
      g_context.entry_price_active = position_info.PriceOpen();
      g_context.sl_price_active    = position_info.StopLoss();
      g_context.tp_price_active    = position_info.TakeProfit();
      
      g_logger.LogDecision(StringFormat("MONO_SYNC|#%I64u|%s",
         g_context.active_ticket,
         (g_context.active_direction == TRADE_LONG) ? "L" : "S"));
      return; // Position found, don't place new orders
   }
   
   // Collect valid confirmed patterns by direction
   int long_indices[];
   int short_indices[];
   int long_count = 0, short_count = 0;
   
   for(int i = 0; i < g_pat_count; i++)
   {
      if(!g_patterns[i].is_valid) continue;
      if(g_patterns[i].state != PAT_CONFIRMED && g_patterns[i].state != PAT_PENDING) continue;
      
      if(g_patterns[i].trade_dir == TRADE_LONG)
      {
         ArrayResize(long_indices, long_count + 1);
         long_indices[long_count] = i;
         long_count++;
      }
      else
      {
         ArrayResize(short_indices, short_count + 1);
         short_indices[short_count] = i;
         short_count++;
      }
   }
   
   // Keep only last 3 per direction, prioritize most restrictive
   int best_long  = SelectBestPattern(long_indices, long_count, TRADE_LONG);
   int best_short = SelectBestPattern(short_indices, short_count, TRADE_SHORT);
   
   // Cancel non-selected patterns (remove their pending orders)
   CancelNonSelected(long_indices, long_count, best_long);
   CancelNonSelected(short_indices, short_count, best_short);
   
   // Try to place/manage the selected patterns
   // CRITICAL: Re-check g_context.is_busy after EACH execution attempt
   // because a market order could fill immediately
   if(best_long >= 0)
   {
      TryExecutePattern(best_long);
   }
   
   // MONOTASK GATE: If the long order just opened a position, don't try short
   if(g_context.is_busy) return;
   
   if(best_short >= 0)
   {
      TryExecutePattern(best_short);
   }
}
//+------------------------------------------------------------------+
