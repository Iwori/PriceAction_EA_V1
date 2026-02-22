//+------------------------------------------------------------------+
//| OrderExecution.mqh                                                |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

//+------------------------------------------------------------------+
//| Select best pattern from array: most restrictive entry              |
//| Keeps last 3, returns index of best or -1                          |
//+------------------------------------------------------------------+
int SelectBestPattern(int &indices[], int count, ENUM_TRADE_DIR dir)
{
   if(count == 0) return -1;
   
   // If more than 3, keep only the 3 most recent (by confirmation time)
   if(count > 3)
   {
      // Sort by time descending
      for(int a = 0; a < count - 1; a++)
      {
         for(int b = a + 1; b < count; b++)
         {
            if(g_patterns[indices[b]].time_confirmed > g_patterns[indices[a]].time_confirmed)
            {
               int tmp = indices[a]; indices[a] = indices[b]; indices[b] = tmp;
            }
         }
      }
      // Cancel patterns beyond the 3 most recent
      for(int k = 3; k < count; k++)
      {
         CancelPattern(indices[k], "Exceeded 3-pattern limit per direction");
      }
      count = 3;
   }
   
   // Find most restrictive: lowest entry for LONG, highest entry for SHORT
   int best = indices[0];
   double best_entry = g_patterns[best].entry_price;
   
   for(int k = 1; k < count; k++)
   {
      double e = g_patterns[indices[k]].entry_price;
      if(dir == TRADE_LONG && e < best_entry)
      {
         best_entry = e;
         best = indices[k];
      }
      if(dir == TRADE_SHORT && e > best_entry)
      {
         best_entry = e;
         best = indices[k];
      }
   }
   
   return best;
}

//+------------------------------------------------------------------+
//| Cancel patterns that are NOT the selected best                     |
//+------------------------------------------------------------------+
void CancelNonSelected(int &indices[], int count, int selected_idx)
{
   for(int k = 0; k < count; k++)
   {
      int idx = indices[k];
      if(idx == selected_idx) continue;
      if(!g_patterns[idx].is_valid) continue;
      
      // Don't fully cancel, just remove pending order. Keep pattern valid
      // in case the selected one gets cancelled later
      if(g_patterns[idx].ticket > 0 && g_patterns[idx].state == PAT_PENDING)
      {
         if(OrderSelect(g_patterns[idx].ticket))
         {
            trade.OrderDelete(g_patterns[idx].ticket);
            g_logger.LogTrade("ORDER_DEFERRED", g_patterns[idx].ticket, "depri");
            g_context.pending_count = MathMax(0, g_context.pending_count - 1);
         }
         g_patterns[idx].ticket = 0;
         g_patterns[idx].state = PAT_CONFIRMED; // Back to confirmed, ready if selected later
      }
   }
}

//+------------------------------------------------------------------+
//| Try to execute a pattern: place order or enter market               |
//+------------------------------------------------------------------+
void TryExecutePattern(int pat_idx)
{
   if(!g_patterns[pat_idx].is_valid) return;
   
   // [v3] MONOTASK SAFETY: re-verify no position is open before ANY action
   if(g_context.is_busy) return;
   
   // [v3] Double-check: scan actual positions (catches out-of-sync edge cases)
   for(int p = 0; p < PositionsTotal(); p++)
   {
      if(!position_info.SelectByIndex(p)) continue;
      if(position_info.Symbol() != _Symbol) continue;
      if(position_info.Magic() != inpMagicNumber) continue;
      
      // Position exists! Sync and abort
      g_context.is_busy = true;
      g_context.active_ticket = position_info.Ticket();
      g_context.active_direction = (position_info.PositionType() == POSITION_TYPE_BUY) ? 
                                    TRADE_LONG : TRADE_SHORT;
      g_context.entry_price_active = position_info.PriceOpen();
      g_context.sl_price_active    = position_info.StopLoss();
      g_context.tp_price_active    = position_info.TakeProfit();
      g_logger.LogDecision(StringFormat("MONO_BLOCK|#%I64u", position_info.Ticket()));
      return;
   }
   
   // 13-candle wait: don't place orders yet, but pattern stays valid
   if(g_context.is_waiting_after_loss)
   {
      // Check if the optimal entry moment has passed
      if(g_patterns[pat_idx].entry_type == ENTRY_LIMIT)
      {
         double current_price = (g_patterns[pat_idx].trade_dir == TRADE_LONG) ? GetBid() : GetAsk();
         bool entry_passed = false;
         
         if(g_patterns[pat_idx].trade_dir == TRADE_LONG && current_price < g_patterns[pat_idx].entry_price)
            entry_passed = true; // Price went below limit buy → would have been activated
         if(g_patterns[pat_idx].trade_dir == TRADE_SHORT && current_price > g_patterns[pat_idx].entry_price)
            entry_passed = true;
         
         if(entry_passed)
         {
            // Would have entered but couldn't due to 13-candle rule → cancel
            CancelPattern(pat_idx, "Entry moment passed during 13-candle wait");
            return;
         }
      }
      else // ENTRY_MARKET
      {
         // Market entries can't wait → cancel
         CancelPattern(pat_idx, "Market entry cannot wait for 13-candle rule");
         return;
      }
      
      return; // Still waiting, keep pattern for later
   }
   
   // Trading hours check
   if(!IsWithinTradingHours())
   {
      // Outside trading hours: don't place new orders
      // But keep the pattern alive
      return;
   }
   
   // Check if order already placed
   if(g_patterns[pat_idx].state == PAT_PENDING && g_patterns[pat_idx].ticket > 0)
   {
      // Verify order still exists
      if(!OrderSelect(g_patterns[pat_idx].ticket))
      {
         // Order filled or deleted
         if(PositionSelectByTicket(g_patterns[pat_idx].ticket))
         {
            // Position opened! Set context
            SetActivePosition(pat_idx);
         }
         else
         {
            // Order AND position gone: check if it was a flash position
            // (filled + closed by SL/TP between OnTick calls within same bar)
            if(CheckFlashPosition(pat_idx))
               return; // Flash position handled: loss recorded, 13-candle wait triggered
            
            // Order was deleted (by user, expired, or other reason)
            g_patterns[pat_idx].state = PAT_CANCELLED;
            g_patterns[pat_idx].is_valid = false;
            g_patterns[pat_idx].ticket = 0;
            g_logger.LogDecision(StringFormat("ord_gone|#%d", pat_idx));
         }
      }
      return; // Order is pending, wait for activation
   }
   
   // Place new order (only if no active position — monotask rule)
   if(g_patterns[pat_idx].state == PAT_CONFIRMED)
   {
      // [v3] Final monotask gate before placing order
      if(g_context.is_busy)
      {
         // Position already open, don't place new orders
         return;
      }
      
      if(g_patterns[pat_idx].entry_type == ENTRY_MARKET)
         PlaceMarketOrder(pat_idx);
      else
         PlaceLimitOrder(pat_idx);
   }
}

//+------------------------------------------------------------------+
//| Place a market order for a pattern                                 |
//+------------------------------------------------------------------+
void PlaceMarketOrder(int pat_idx)
{
   symbol_info.Refresh();
   
   // For market orders, update entry_price to current market price
   double actual_entry;
   if(g_patterns[pat_idx].trade_dir == TRADE_LONG)
      actual_entry = GetAsk();
   else
      actual_entry = GetBid();
   
   if(actual_entry <= 0)
   {
      g_patterns[pat_idx].retry_count++;
      if(g_patterns[pat_idx].retry_count >= 3)
      {
         g_logger.LogError(StringFormat("P#%d: Cannot get market price after %d retries", 
            pat_idx, g_patterns[pat_idx].retry_count));
         CancelPattern(pat_idx, "No market price available");
      }
      return;
   }
   
   // Update entry, SL distance, and recalculate TP with actual price
   g_patterns[pat_idx].entry_price = NormalizePrice(actual_entry);
   
   // Validate SL is on correct side of entry after price update
   bool sl_valid = true;
   if(g_patterns[pat_idx].trade_dir == TRADE_LONG && g_patterns[pat_idx].sl_price >= actual_entry)
      sl_valid = false;
   if(g_patterns[pat_idx].trade_dir == TRADE_SHORT && g_patterns[pat_idx].sl_price <= actual_entry)
      sl_valid = false;
   
   if(!sl_valid)
   {
      g_logger.LogError(StringFormat("P#%d: SL=%.1f on wrong side of Entry=%.1f for %s. Cancelling.",
         pat_idx, g_patterns[pat_idx].sl_price, actual_entry,
         (g_patterns[pat_idx].trade_dir == TRADE_LONG) ? "LONG" : "SHORT"));
      CancelPattern(pat_idx, "SL crossed entry (price moved)");
      return;
   }
   
   g_patterns[pat_idx].sl_size_pips = PriceToPips(MathAbs(actual_entry - g_patterns[pat_idx].sl_price));
   
   double tp_distance = MathAbs(actual_entry - g_patterns[pat_idx].sl_price) * inpTpRatio;
   if(g_patterns[pat_idx].trade_dir == TRADE_LONG)
      g_patterns[pat_idx].tp_price = actual_entry + tp_distance;
   else
      g_patterns[pat_idx].tp_price = actual_entry - tp_distance;
   g_patterns[pat_idx].tp_price = NormalizePrice(g_patterns[pat_idx].tp_price);
   
   double sl_distance = MathAbs(actual_entry - g_patterns[pat_idx].sl_price);
   double tp_dist_abs = MathAbs(actual_entry - g_patterns[pat_idx].tp_price);
   
   // Validate minimum stops distance
   double min_stop_distance = g_stops_level * g_point;
   if(min_stop_distance > 0 && (sl_distance < min_stop_distance || tp_dist_abs < min_stop_distance))
   {
      g_logger.LogError(StringFormat("P#%d: SL(%.1f) or TP(%.1f) < StopsLevel(%.1f). Cancelling.",
         pat_idx, sl_distance / g_point, tp_dist_abs / g_point, (double)g_stops_level));
      CancelPattern(pat_idx, "SL/TP too close (stops level)");
      return;
   }
   
   double lots = CalculateLotSize(sl_distance);
   if(lots <= 0)
   {
      g_logger.LogError(StringFormat("P#%d: Lot size calculation failed", pat_idx));
      return;
   }
   
   g_logger.LogDecision(StringFormat("TM|#%d|%.1f|%.1f|%.1f|%.0f|%.2f",
      pat_idx, actual_entry, g_patterns[pat_idx].sl_price, g_patterns[pat_idx].tp_price,
      sl_distance / g_point, lots));
   
   bool success = false;
   if(g_patterns[pat_idx].trade_dir == TRADE_LONG)
   {
      success = trade.Buy(lots, _Symbol, 0, g_patterns[pat_idx].sl_price, g_patterns[pat_idx].tp_price,
                          StringFormat("%s P%d", EA_NAME, (int)g_patterns[pat_idx].type));
   }
   else
   {
      success = trade.Sell(lots, _Symbol, 0, g_patterns[pat_idx].sl_price, g_patterns[pat_idx].tp_price,
                           StringFormat("%s P%d", EA_NAME, (int)g_patterns[pat_idx].type));
   }
   
   if(success && trade.ResultRetcode() == TRADE_RETCODE_DONE)
   {
      g_patterns[pat_idx].ticket = trade.ResultOrder();
      g_patterns[pat_idx].state  = PAT_ACTIVE;
      
      g_logger.LogTrade("MARKET_ORDER", g_patterns[pat_idx].ticket,
         StringFormat("%s|%.2f|%.1f|%.1f|%.1f",
            (g_patterns[pat_idx].trade_dir == TRADE_LONG) ? "L" : "S",
            lots, trade.ResultPrice(), g_patterns[pat_idx].sl_price, g_patterns[pat_idx].tp_price));
      
      SetActivePosition(pat_idx);
      
      NotifyUser(StringFormat("%s %s opened at %.5f | SL=%.5f | TP=%.5f",
         (g_patterns[pat_idx].type == PATTERN_2) ? "P2" : "P3",
         (g_patterns[pat_idx].trade_dir == TRADE_LONG) ? "BUY" : "SELL",
         trade.ResultPrice(), g_patterns[pat_idx].sl_price, g_patterns[pat_idx].tp_price));
   }
   else
   {
      g_logger.LogError(StringFormat("Market order failed: %d (%s)",
         trade.ResultRetcode(), GetRetcodeDescription(trade.ResultRetcode())));
      CancelPattern(pat_idx, StringFormat("Market order error %d", trade.ResultRetcode()));
   }
}

//+------------------------------------------------------------------+
//| Place a limit order for a pattern                                  |
//+------------------------------------------------------------------+
void PlaceLimitOrder(int pat_idx)
{
   
   // Verify entry level is still valid (price hasn't passed it)
   symbol_info.Refresh();
   double current_ask = GetAsk();
   double current_bid = GetBid();
   
   if(g_patterns[pat_idx].trade_dir == TRADE_LONG)
   {
      // Buy Limit: entry must be below current ask
      if(g_patterns[pat_idx].entry_price >= current_ask)
      {
         // Price already at or below entry → convert to market?
         // Only if price is within acceptable range (not too far past)
         if(current_ask <= g_patterns[pat_idx].entry_price + g_patterns[pat_idx].sl_tolerance)
         {
            g_logger.LogDecision(StringFormat("lim2mkt|#%d|L", pat_idx));
            PlaceMarketOrder(pat_idx);
            return;
         }
         else
         {
            CancelPattern(pat_idx, "Price passed limit entry too far");
            return;
         }
      }
   }
   else
   {
      // Sell Limit: entry must be above current bid
      if(g_patterns[pat_idx].entry_price <= current_bid)
      {
         if(current_bid >= g_patterns[pat_idx].entry_price - g_patterns[pat_idx].sl_tolerance)
         {
            g_logger.LogDecision(StringFormat("lim2mkt|#%d|S", pat_idx));
            PlaceMarketOrder(pat_idx);
            return;
         }
         else
         {
            CancelPattern(pat_idx, "Price passed limit entry too far");
            return;
         }
      }
   }
   
   double sl_distance = MathAbs(g_patterns[pat_idx].entry_price - g_patterns[pat_idx].sl_price);
   double tp_dist_abs = MathAbs(g_patterns[pat_idx].entry_price - g_patterns[pat_idx].tp_price);
   
   // Validate minimum stops distance
   double min_stop_distance = g_stops_level * g_point;
   if(min_stop_distance > 0 && (sl_distance < min_stop_distance || tp_dist_abs < min_stop_distance))
   {
      g_logger.LogError(StringFormat("P#%d: SL(%.1f) or TP(%.1f) < StopsLevel(%.1f). Cancelling.",
         pat_idx, sl_distance / g_point, tp_dist_abs / g_point, (double)g_stops_level));
      CancelPattern(pat_idx, "SL/TP too close (stops level)");
      return;
   }
   
   double lots = CalculateLotSize(sl_distance);
   if(lots <= 0)
   {
      g_logger.LogError(StringFormat("P#%d: Lot size calculation failed", pat_idx));
      return;
   }
   
   g_logger.LogDecision(StringFormat("TL|#%d|%.1f|%.1f|%.1f|%.0f|%.2f",
      pat_idx, g_patterns[pat_idx].entry_price, g_patterns[pat_idx].sl_price, 
      g_patterns[pat_idx].tp_price, sl_distance / g_point, lots));
   
   // Check max pending orders (2 max: 1 buy limit + 1 sell limit)
   if(g_context.pending_count >= MAX_PENDING)
   {
      g_logger.LogDecision(StringFormat("max_pend|#%d", pat_idx));
      return;
   }
   
   bool success = false;
   if(g_patterns[pat_idx].trade_dir == TRADE_LONG)
   {
      success = trade.BuyLimit(lots, g_patterns[pat_idx].entry_price, _Symbol, g_patterns[pat_idx].sl_price, g_patterns[pat_idx].tp_price,
                               ORDER_TIME_GTC, 0, StringFormat("%s P%d", EA_NAME, (int)g_patterns[pat_idx].type));
   }
   else
   {
      success = trade.SellLimit(lots, g_patterns[pat_idx].entry_price, _Symbol, g_patterns[pat_idx].sl_price, g_patterns[pat_idx].tp_price,
                                ORDER_TIME_GTC, 0, StringFormat("%s P%d", EA_NAME, (int)g_patterns[pat_idx].type));
   }
   
   if(success && (trade.ResultRetcode() == TRADE_RETCODE_PLACED || 
                  trade.ResultRetcode() == TRADE_RETCODE_DONE))
   {
      g_patterns[pat_idx].ticket = trade.ResultOrder();
      g_patterns[pat_idx].state  = PAT_PENDING;
      g_context.pending_count++;
      
      g_logger.LogTrade("LIMIT_ORDER", g_patterns[pat_idx].ticket,
         StringFormat("%s|%.2f|%.1f|%.1f|%.1f",
            (g_patterns[pat_idx].trade_dir == TRADE_LONG) ? "L" : "S",
            lots, g_patterns[pat_idx].entry_price, g_patterns[pat_idx].sl_price, g_patterns[pat_idx].tp_price));
      
      NotifyUser(StringFormat("%s %s limit placed at %.5f | SL=%.5f | TP=%.5f",
         (g_patterns[pat_idx].type == PATTERN_2) ? "P2" : "P3",
         (g_patterns[pat_idx].trade_dir == TRADE_LONG) ? "BUY" : "SELL",
         g_patterns[pat_idx].entry_price, g_patterns[pat_idx].sl_price, g_patterns[pat_idx].tp_price));
   }
   else
   {
      g_logger.LogError(StringFormat("Limit order failed: %d (%s)",
         trade.ResultRetcode(), GetRetcodeDescription(trade.ResultRetcode())));
      CancelPattern(pat_idx, StringFormat("Limit order error %d", trade.ResultRetcode()));
   }
}

//+------------------------------------------------------------------+
//| Check if a pending order was filled and position closed within     |
//| the same bar (flash position). This handles the edge case where    |
//| both OrderSelect and PositionSelectByTicket fail because the       |
//| limit order filled AND the position hit SL/TP between OnTick calls.|
//| Returns true if a flash position was detected and handled.         |
//+------------------------------------------------------------------+
bool CheckFlashPosition(int pat_idx)
{
   ulong order_ticket = g_patterns[pat_idx].ticket;
   
   // Select deal history for today
   datetime from_time = g_context.last_daily_reset;
   if(from_time == 0) from_time = TimeCurrent() - 86400;
   if(!HistorySelect(from_time, TimeCurrent())) return false;
   
   // Pass 1: Find the fill deal (DEAL_ENTRY_IN) for this order ticket
   ulong position_id = 0;
   bool was_filled = false;
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0) continue;
      
      if(HistoryDealGetInteger(deal_ticket, DEAL_ORDER) == (long)order_ticket)
      {
         long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(deal_entry == DEAL_ENTRY_IN)
         {
            position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
            was_filled = true;
            break;
         }
      }
   }
   
   if(!was_filled || position_id == 0) return false;
   
   // Pass 2: Find the closing deal (DEAL_ENTRY_OUT) for this position
   double profit = 0;
   bool was_closed = false;
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0) continue;
      
      if((ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) == position_id)
      {
         long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT)
         {
            profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) +
                     HistoryDealGetDouble(deal_ticket, DEAL_SWAP) +
                     HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
            was_closed = true;
            break;
         }
      }
   }
   
   if(!was_closed) return false;
   
   // --- Flash position confirmed: filled + closed between OnTick calls ---
   g_logger.LogDecision(StringFormat("flash|#%d|pos=%I64u|%.2f", pat_idx, position_id, profit));
   
   // Update pattern state
   g_patterns[pat_idx].state = PAT_CANCELLED;
   g_patterns[pat_idx].is_valid = false;
   g_patterns[pat_idx].ticket = 0;
   
   // Adjust pending count (limit order was consumed)
   g_context.pending_count = MathMax(0, g_context.pending_count - 1);
   
   // Ensure context is clean
   g_context.is_busy = false;
   g_context.active_ticket = 0;
   
   // Log TC for consistency with normal close flow
   g_logger.LogTrade("POSITION_CLOSED", position_id, StringFormat("%.2f", profit));
   
   // Process profit/loss — mirrors HandlePositionClosed logic
   if(profit < 0)
   {
      g_context.daily_loss_eur += MathAbs(profit);
      g_context.is_waiting_after_loss = true;
      g_context.wait_candles_remaining = inpWaitCandlesAfterLoss;
      g_context.bar_last_loss = 0;
      
      g_logger.LogDecision(StringFormat("$L|%.2f|%d", profit, inpWaitCandlesAfterLoss));
      NotifyUser(StringFormat("Position closed with loss (%.2f). Waiting %d candles.",
         profit, inpWaitCandlesAfterLoss));
   }
   else
   {
      NotifyUser(StringFormat("Position closed with profit (%.2f).", profit));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Set active position context when an order is filled                 |
//+------------------------------------------------------------------+
void SetActivePosition(int pat_idx)
{
   
   g_context.is_busy = true;
   g_context.active_ticket = g_patterns[pat_idx].ticket;
   g_context.active_direction = g_patterns[pat_idx].trade_dir;
   g_context.be_stage = BE_NONE;
   g_context.strict_pe_since_entry = 0;
   
   // Get actual fill price from position
   if(PositionSelectByTicket(g_patterns[pat_idx].ticket))
   {
      g_context.entry_price_active = position_info.PriceOpen();
      g_context.sl_price_active    = position_info.StopLoss();
      g_context.tp_price_active    = position_info.TakeProfit();
   }
   else
   {
      g_context.entry_price_active = g_patterns[pat_idx].entry_price;
      g_context.sl_price_active    = g_patterns[pat_idx].sl_price;
      g_context.tp_price_active    = g_patterns[pat_idx].tp_price;
   }
   
   // Cancel all other pending orders (monotask)
   for(int i = 0; i < g_pat_count; i++)
   {
      if(i == pat_idx) continue;
      if(!g_patterns[i].is_valid) continue;
      if(g_patterns[i].state == PAT_PENDING && g_patterns[i].ticket > 0)
      {
         // Don't cancel opposite direction limit (can coexist until one activates)
         // Actually per rules: monotask means once one is OPEN, no other activates
         // But the other limit stays until its activation would be blocked
         // For simplicity: delete all other pendings since we can't have two open
         if(OrderSelect(g_patterns[i].ticket))
         {
            trade.OrderDelete(g_patterns[i].ticket);
            g_logger.LogTrade("ORDER_MONO", g_patterns[i].ticket, "mono");
         }
         g_patterns[i].ticket = 0;
         g_context.pending_count = MathMax(0, g_context.pending_count - 1);
      }
   }
   
   g_context.pending_count = 0; // Reset: all pendings removed
   
   g_logger.LogDecision(StringFormat("pos|#%I64u|%s|%.1f",
      g_context.active_ticket,
      (g_context.active_direction == TRADE_LONG) ? "L" : "S",
      g_context.entry_price_active));
}
//+------------------------------------------------------------------+
