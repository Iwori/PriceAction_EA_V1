//+------------------------------------------------------------------+
//| Utilities.mqh                                                     |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

//+------------------------------------------------------------------+
//| Utility: Modular indicator value (isolated for future changes)     |
//+------------------------------------------------------------------+
double GetIndicatorValue(int shift)
{
   // Currently uses ATR(20) - can be replaced with any indicator
   if(g_atr_handle == INVALID_HANDLE) return 0;
   
   double buffer[];
   ArraySetAsSeries(buffer, true);
   
   if(CopyBuffer(g_atr_handle, 0, shift, 1, buffer) != 1)
   {
      g_logger.LogError(StringFormat("Failed to read indicator at shift %d", shift));
      return 0;
   }
   
   return buffer[0];
}

//+------------------------------------------------------------------+
//| Utility: Convert price distance to pips                            |
//+------------------------------------------------------------------+
double PriceToPips(double price_distance)
{
   if(g_point == 0) return 0;
   return MathAbs(price_distance) / g_point;
}

//+------------------------------------------------------------------+
//| Utility: Convert pips to price distance                            |
//+------------------------------------------------------------------+
double PipsToPrice(double pips)
{
   return pips * g_point;
}

//+------------------------------------------------------------------+
//| Utility: Classify candle type                                      |
//+------------------------------------------------------------------+
ENUM_CANDLE_TYPE GetCandleType(int shift)
{
   double open_price  = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close_price = iClose(_Symbol, PERIOD_CURRENT, shift);
   
   if(close_price > open_price)  return CANDLE_BULLISH;
   if(close_price < open_price)  return CANDLE_BEARISH;
   return CANDLE_DOJI;
}

//+------------------------------------------------------------------+
//| Utility: Get candle body size (absolute)                           |
//+------------------------------------------------------------------+
double GetBodySize(int shift)
{
   return MathAbs(iClose(_Symbol, PERIOD_CURRENT, shift) - iOpen(_Symbol, PERIOD_CURRENT, shift));
}

//+------------------------------------------------------------------+
//| Utility: Get candle body top (higher of open/close)                |
//+------------------------------------------------------------------+
double GetBodyTop(int shift)
{
   return MathMax(iOpen(_Symbol, PERIOD_CURRENT, shift), iClose(_Symbol, PERIOD_CURRENT, shift));
}

//+------------------------------------------------------------------+
//| Utility: Get candle body bottom (lower of open/close)              |
//+------------------------------------------------------------------+
double GetBodyBottom(int shift)
{
   return MathMin(iOpen(_Symbol, PERIOD_CURRENT, shift), iClose(_Symbol, PERIOD_CURRENT, shift));
}

//+------------------------------------------------------------------+
//| Utility: New bar detection                                         |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(current_bar_time == g_last_bar_time)
      return false;
   
   g_last_bar_time = current_bar_time;
   return true;
}

//+------------------------------------------------------------------+
//| Utility: Parse time string "HH:MM" to hour and minute              |
//+------------------------------------------------------------------+
bool ParseTimeString(string time_str, int &hour, int &minute)
{
   string parts[];
   int count = StringSplit(time_str, ':', parts);
   if(count != 2) return false;
   
   hour   = (int)StringToInteger(parts[0]);
   minute = (int)StringToInteger(parts[1]);
   
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Utility: Check if current time is within trading hours              |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int current_minutes = dt.hour * 60 + dt.min;
   
   int slot1_start = g_slot1_start_hour * 60 + g_slot1_start_min;
   int slot1_end   = g_slot1_end_hour   * 60 + g_slot1_end_min;
   int slot2_start = g_slot2_start_hour * 60 + g_slot2_start_min;
   int slot2_end   = g_slot2_end_hour   * 60 + g_slot2_end_min;
   
   if(current_minutes >= slot1_start && current_minutes < slot1_end) return true;
   if(current_minutes >= slot2_start && current_minutes < slot2_end) return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Utility: Check and execute daily close                             |
//+------------------------------------------------------------------+
void CheckDailyClose()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int current_minutes = dt.hour * 60 + dt.min;
   int close_minutes   = g_close_hour * 60 + g_close_min;
   
   if(current_minutes >= close_minutes)
   {
      // Check if we already closed today
      static datetime last_close_date = 0;
      datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
      if(today == last_close_date) return;
      
      g_logger.LogDecision(StringFormat("$C|%02d:%02d", dt.hour, dt.min));
      
      // Close all positions for this symbol with our magic number
      CloseAllPositions();
      
      // Delete all pending orders
      DeleteAllPendingOrders();
      
      last_close_date = today;
      
      // Reset pattern states
      for(int i = 0; i < g_pat_count; i++)
      {
         if(g_patterns[i].is_valid && 
            (g_patterns[i].state == PAT_PENDING || g_patterns[i].state == PAT_CONFIRMED))
         {
            g_patterns[i].state = PAT_CANCELLED;
            g_patterns[i].is_valid = false;
            g_logger.LogCancel("Daily close", i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Utility: Close all positions for this symbol                       |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!position_info.SelectByIndex(i)) continue;
      if(position_info.Symbol() != _Symbol) continue;
      if(position_info.Magic() != inpMagicNumber) continue;
      
      ulong ticket = position_info.Ticket();
      g_logger.LogTrade("CLOSE_DAILY", ticket, "dc");
      
      if(!trade.PositionClose(ticket))
         g_logger.LogError(StringFormat("Failed to close position #%I64u: %d", ticket, GetLastError()));
      else
         g_context.is_busy = false;
   }
}

//+------------------------------------------------------------------+
//| Utility: Delete all pending orders for this symbol                 |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!order_info.SelectByIndex(i)) continue;
      if(order_info.Symbol() != _Symbol) continue;
      if(order_info.Magic() != inpMagicNumber) continue;
      
      ulong ticket = order_info.Ticket();
      g_logger.LogTrade("DELETE_DAILY", ticket, "dc");
      
      if(!trade.OrderDelete(ticket))
         g_logger.LogError(StringFormat("Failed to delete order #%I64u: %d", ticket, GetLastError()));
   }
   
   g_context.pending_count = 0;
}

//+------------------------------------------------------------------+
//| Utility: Check daily loss limit                                    |
//+------------------------------------------------------------------+
bool CheckDailyLossLimit()
{
   // EUR limit
   if(inpDailyLossEur > 0 && g_context.daily_loss_eur >= inpDailyLossEur)
      return false;
   
   // Percent limit
   if(inpDailyLossPercent > 0 && g_context.daily_balance_start > 0)
   {
      double loss_pct = (g_context.daily_loss_eur / g_context.daily_balance_start) * 100.0;
      if(loss_pct >= inpDailyLossPercent)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Utility: Reset daily loss at new trading day                       |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_context.last_daily_reset)
   {
      g_context.daily_loss_eur = 0;
      g_context.daily_balance_start = account_info.Balance();
      g_context.last_daily_reset = today;
      g_logger.LogDecision(StringFormat("$D|%.0f", g_context.daily_balance_start));
   }
}

//+------------------------------------------------------------------+
//| Utility: Update zone expiration counters                           |
//+------------------------------------------------------------------+
void UpdateZoneExpiration()
{
   // Expire old zones
   for(int i = 0; i < g_zi_count; i++)
   {
      if(!g_zi_array[i].is_valid) continue;
      if(g_zi_array[i].state == ZI_MITIGATED || g_zi_array[i].state == ZI_EXPIRED) continue;
      
      g_zi_array[i].candles_alive++;
      
      if(g_zi_array[i].candles_alive >= inpZoneExpireCandles)
      {
         g_zi_array[i].state = ZI_EXPIRED;
         g_zi_array[i].is_valid = false;
         g_logger.LogZone("EXPIRED", i, g_zi_array[i]);
      }
   }
   
   // Expire old PEs (no zone generation possible beyond expiration limit)
   for(int i = 0; i < g_pe_count; i++)
   {
      if(!g_pe_array[i].is_valid) continue;
      int pe_shift = iBarShift(_Symbol, PERIOD_CURRENT, g_pe_array[i].time_created);
      if(pe_shift < 0 || pe_shift > inpZoneExpireCandles)
      {
         g_pe_array[i].is_valid = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Utility: Update post-loss wait counter                             |
//+------------------------------------------------------------------+
void UpdateWaitCounter()
{
   if(!g_context.is_waiting_after_loss) return;
   
   g_context.wait_candles_remaining--;
   
   if(g_context.wait_candles_remaining <= 0)
   {
      g_context.is_waiting_after_loss = false;
      g_context.wait_candles_remaining = 0;
      g_logger.LogDecision("wait_done");
   }
   else
   {
      g_logger.LogDecision(StringFormat("wait|%d", g_context.wait_candles_remaining));
   }
}

//+------------------------------------------------------------------+
//| Utility: Recover state after restart (VPS ready)                   |
//+------------------------------------------------------------------+
void RecoverExistingState()
{
   g_logger.LogDecision("$R|check");
   
   // Check existing positions
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!position_info.SelectByIndex(i)) continue;
      if(position_info.Symbol() != _Symbol) continue;
      if(position_info.Magic() != inpMagicNumber) continue;
      
      // Found our position - set monotask flag
      g_context.is_busy = true;
      g_context.active_ticket = position_info.Ticket();
      g_context.entry_price_active = position_info.PriceOpen();
      g_context.sl_price_active = position_info.StopLoss();
      g_context.tp_price_active = position_info.TakeProfit();
      g_context.active_direction = (position_info.PositionType() == POSITION_TYPE_BUY) ? TRADE_LONG : TRADE_SHORT;
      
      g_logger.LogTrade("RECOVERED", g_context.active_ticket,
         StringFormat("%s|%.1f|%.1f|%.1f",
            (g_context.active_direction == TRADE_LONG) ? "L" : "S",
            g_context.entry_price_active, g_context.sl_price_active, g_context.tp_price_active));
      
      Print(EA_NAME, ": Recovered existing position #", g_context.active_ticket);
      break; // Monotask: only one position
   }
   
   // Check existing pending orders
   g_context.pending_count = 0;
   ArrayResize(g_context.pending_tickets, 0);
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!order_info.SelectByIndex(i)) continue;
      if(order_info.Symbol() != _Symbol) continue;
      if(order_info.Magic() != inpMagicNumber) continue;
      
      int new_size = ArraySize(g_context.pending_tickets) + 1;
      ArrayResize(g_context.pending_tickets, new_size);
      g_context.pending_tickets[new_size - 1] = order_info.Ticket();
      g_context.pending_count++;
      
      g_logger.LogTrade("RECOVERED_PENDING", order_info.Ticket(),
         StringFormat("%.1f|%.1f|%.1f",
            order_info.PriceOpen(), order_info.StopLoss(), order_info.TakeProfit()));
      
      Print(EA_NAME, ": Recovered pending order #", order_info.Ticket());
   }
}

//+------------------------------------------------------------------+
//| Utility: Calculate lot size based on risk %                        |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_distance_price)
{
   if(sl_distance_price <= 0) return 0;
   
   double balance    = account_info.Balance();
   double risk_money = balance * (inpRiskPercent / 100.0);
   
   // Use SymbolInfoDouble for reliable values in Strategy Tester
   symbol_info.Refresh();
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tick_value <= 0) tick_value = symbol_info.TickValue();
   if(tick_size  <= 0) tick_size  = symbol_info.TickSize();
   
   if(tick_value <= 0 || tick_size <= 0) return 0;
   
   double sl_ticks  = sl_distance_price / tick_size;
   double lot_size  = risk_money / (sl_ticks * tick_value);
   
   // Diagnostic log (first 5 calls only to avoid spam)
   static int s_lot_calc_count = 0;
   if(s_lot_calc_count < 5)
   {
      g_logger.LogDecision(StringFormat("DL|%.0f|%.0f|%.6f|%.5f|%.5f|%.0f|%.2f",
         balance, risk_money, tick_value, tick_size, sl_distance_price, sl_ticks, lot_size));
      s_lot_calc_count++;
   }
   
   // Normalize lot
   double lot_min   = symbol_info.LotsMin();
   double lot_max   = symbol_info.LotsMax();
   double lot_step  = symbol_info.LotsStep();
   
   if(lot_step == 0) return 0;
   
   lot_size = MathFloor(lot_size / lot_step) * lot_step;
   lot_size = MathMax(lot_size, lot_min);
   lot_size = MathMin(lot_size, lot_max);
   
   // Check available margin
   double margin_required;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lot_size, GetAsk(), margin_required))
      return lot_min; // Fallback to minimum
   
   if(margin_required > account_info.FreeMargin())
   {
      // Reduce lot to fit margin
      double max_affordable = (account_info.FreeMargin() / margin_required) * lot_size;
      lot_size = MathFloor(max_affordable / lot_step) * lot_step;
      lot_size = MathMax(lot_size, lot_min);
      g_logger.LogDecision(StringFormat("DL|margin_adj|%.2f", lot_size));
   }
   
   return lot_size;
}

//+------------------------------------------------------------------+
//| Utility: Normalize price to tick size                               |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
   if(g_tick_size == 0) return NormalizeDouble(price, g_digits);
   return NormalizeDouble(MathRound(price / g_tick_size) * g_tick_size, g_digits);
}

//+------------------------------------------------------------------+
//| Utility: Get Ask price (Strategy Tester compatible)                |
//+------------------------------------------------------------------+
double GetAsk()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0) { symbol_info.Refresh(); ask = symbol_info.Ask(); }
   return ask;
}

//+------------------------------------------------------------------+
//| Utility: Get Bid price (Strategy Tester compatible)                |
//+------------------------------------------------------------------+
double GetBid()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0) { symbol_info.Refresh(); bid = symbol_info.Bid(); }
   return bid;
}

//+------------------------------------------------------------------+
//| Utility: Calculate Fibonacci level                                 |
//+------------------------------------------------------------------+
double CalcFibLevel(double level_0, double level_100, double fib_pct)
{
   // fib_pct: 0.0 = at 0%, 1.0 = at 100%, 1.75 = at 175%, etc.
   return level_0 + (level_100 - level_0) * fib_pct;
}

//+------------------------------------------------------------------+
//| Utility: Check if price is within zone bounds                      |
//+------------------------------------------------------------------+
bool IsPriceInZone(double price, const InterestZone &zone)
{
   if(!zone.is_valid) return false;
   return (price >= zone.lower_price && price <= zone.upper_price);
}

//+------------------------------------------------------------------+
//| Utility: Check if two zones overlap                                |
//+------------------------------------------------------------------+
bool DoZonesOverlap(const InterestZone &z1, const InterestZone &z2)
{
   if(!z1.is_valid || !z2.is_valid) return false;
   if(z1.direction != z2.direction) return false;
   return (z1.lower_price <= z2.upper_price && z2.lower_price <= z1.upper_price);
}

//+------------------------------------------------------------------+
//| Utility: Send notification (push to MT5 mobile)                    |
//+------------------------------------------------------------------+
void NotifyUser(string message)
{
   string full_msg = EA_NAME + " [" + _Symbol + "]: " + message;
   
   // Expert log
   Print(full_msg);
   
   // Push notification (not in tester)
   if(!g_is_tester)
      SendNotification(full_msg);
   
   // Debug log
   g_logger.Log("NOTIFY", message);
}

//+------------------------------------------------------------------+
//| Utility: Get retcode description                                   |
//+------------------------------------------------------------------+
string GetRetcodeDescription(uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_REQUOTE:       return "Requote";
      case TRADE_RETCODE_REJECT:        return "Rejected";
      case TRADE_RETCODE_CANCEL:        return "Cancelled";
      case TRADE_RETCODE_PLACED:        return "Placed";
      case TRADE_RETCODE_DONE:          return "Done";
      case TRADE_RETCODE_DONE_PARTIAL:  return "Partial";
      case TRADE_RETCODE_ERROR:         return "Error";
      case TRADE_RETCODE_TIMEOUT:       return "Timeout";
      case TRADE_RETCODE_INVALID:       return "Invalid request";
      case TRADE_RETCODE_INVALID_VOLUME:return "Invalid volume";
      case TRADE_RETCODE_INVALID_PRICE: return "Invalid price";
      case TRADE_RETCODE_INVALID_STOPS: return "Invalid stops";
      case TRADE_RETCODE_TRADE_DISABLED:return "Trade disabled";
      case TRADE_RETCODE_MARKET_CLOSED: return "Market closed";
      case TRADE_RETCODE_NO_MONEY:      return "No money";
      case TRADE_RETCODE_PRICE_CHANGED: return "Price changed";
      case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too many requests";
      default:                          return StringFormat("Code %d", retcode);
   }
}

//+------------------------------------------------------------------+
//| Utility: Send order with retry loop (slippage handling)            |
//+------------------------------------------------------------------+
bool SendOrderWithRetry(MqlTradeRequest &request, MqlTradeResult &result, int max_retries = 3)
{
   for(int attempt = 1; attempt <= max_retries; attempt++)
   {
      // Refresh prices before each attempt
      symbol_info.Refresh();
      
      if(request.type == ORDER_TYPE_BUY)
         request.price = GetAsk();
      else if(request.type == ORDER_TYPE_SELL)
         request.price = GetBid();
      
      if(OrderSend(request, result))
      {
         if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
         {
            g_logger.LogTrade("ORDER_SENT", result.order,
               StringFormat("%d/%d|OK|%.1f", attempt, max_retries, result.price));
            return true;
         }
      }
      
      g_logger.LogTrade("ORDER_RETRY", 0,
         StringFormat("%d/%d|%d", attempt, max_retries, result.retcode));
      
      if(attempt < max_retries)
         Sleep(500); // Wait before retry
   }
   
   g_logger.LogError(StringFormat("Order failed after %d attempts. Last retcode=%d", max_retries, result.retcode));
   return false;
}

//+------------------------------------------------------------------+
//| Utility: Clean chart objects created by this EA                    |
//+------------------------------------------------------------------+
void CleanChartObjects()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "PA_") == 0) // Our prefix
         ObjectDelete(0, name);
   }
}
//+------------------------------------------------------------------+
