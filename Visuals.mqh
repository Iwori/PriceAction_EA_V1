//+------------------------------------------------------------------+
//| Visuals.mqh                                                       |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

// Phase 8: Visuals ==========================================================

//+------------------------------------------------------------------+
//| Master draw function: updates all visual objects                    |
//+------------------------------------------------------------------+
void DrawVisuals()
{
   DrawInterestZones();
   DrawStructuralPoints();
   DrawPatterns();
   DrawComment();
}

//+------------------------------------------------------------------+
//| Draw Interest Zones as rectangles                                  |
//+------------------------------------------------------------------+
void DrawInterestZones()
{
   // FIX Bug 12: Calculate visible chart left edge for label placement
   int visible_bars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   int first_visible = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int left_bar = first_visible;
   if(left_bar >= iBars(_Symbol, PERIOD_CURRENT))
      left_bar = iBars(_Symbol, PERIOD_CURRENT) - 1;
   datetime chart_left = iTime(_Symbol, PERIOD_CURRENT, left_bar);
   
   for(int i = 0; i < g_zi_count; i++)
   {
      string name = StringFormat("PA_ZI_%d", i);
      
      if(!g_zi_array[i].is_valid)
      {
         // Remove dead zone objects
         if(ObjectFind(0, name) >= 0) {
            ObjectDelete(0, name);
            Print(name);
            }
         string lbl = name + "_lbl";
         if(ObjectFind(0, lbl) >= 0) 
            ObjectDelete(0, lbl);
         continue;
      }
      
      datetime t1 = g_zi_array[i].time_created;
      datetime t2 = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds() * 10; // Extend right
      double upper = g_zi_array[i].upper_price;
      double lower = g_zi_array[i].lower_price;
      
      color zone_clr = (g_zi_array[i].direction == DIR_BULLISH) ? inpBullishZoneColor : inpBearishZoneColor;
      
      // Adjust alpha for partial mitigation
      int alpha = 60;
      if(g_zi_array[i].state == ZI_PARTIAL) alpha = 30;
      
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, upper, t2, lower);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
      else
      {
         ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
         ObjectSetDouble(0, name, OBJPROP_PRICE, 0, upper);
         ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
         ObjectSetDouble(0, name, OBJPROP_PRICE, 1, lower);
      }
      
      ObjectSetInteger(0, name, OBJPROP_COLOR, zone_clr);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      
      // Zone label
      string lbl_name = name + "_lbl";
      string base_str = (g_zi_array[i].base_type == ZI_BASE_PE) ? "PE" :
                         (g_zi_array[i].base_type == ZI_BASE_BRAKE) ? "BRK" : "PE+BRK";
      string dir_str  = (g_zi_array[i].direction == DIR_BULLISH) ? "B" : "S";
      string state_str = "";
      if(g_zi_array[i].state == ZI_PARTIAL) state_str = " [P]";
      
      string label_text = StringFormat("ZI%d %s%s %d%s", i, dir_str, base_str,
                                        g_zi_array[i].candles_alive, state_str);
      
      // FIX Bug 12: Place label at visible chart edge if zone origin is off-screen
      datetime lbl_time = t1;
      if(t1 < chart_left)
         lbl_time = chart_left;
      
      if(ObjectFind(0, lbl_name) < 0)
         ObjectCreate(0, lbl_name, OBJ_TEXT, 0, lbl_time, upper);
      
      ObjectSetInteger(0, lbl_name, OBJPROP_TIME, 0, lbl_time);
      ObjectSetDouble(0, lbl_name, OBJPROP_PRICE, 0, upper);
      ObjectSetString(0, lbl_name, OBJPROP_TEXT, label_text);
      ObjectSetInteger(0, lbl_name, OBJPROP_COLOR, zone_clr);
      ObjectSetInteger(0, lbl_name, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, lbl_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lbl_name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, lbl_name, OBJPROP_BACK, false);
   }
}

//+------------------------------------------------------------------+
//| Draw Structural Points as arrow markers                            |
//+------------------------------------------------------------------+
void DrawStructuralPoints()
{
   for(int i = 0; i < g_pe_count; i++)
   {
      string name = StringFormat("PA_PE_%d", i);
      string line_name = StringFormat("PA_PEL_%d", i);
      
      if(!g_pe_array[i].is_valid)
      {
         if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
         if(ObjectFind(0, line_name) >= 0) ObjectDelete(0, line_name);
         continue;
      }
      
      color pe_clr = (g_pe_array[i].pe_type == PE_STRICT) ? inpPeStrictColor : inpPeNormalColor;
      int arrow_code = (g_pe_array[i].direction == DIR_BULLISH) ? 233 : 234; // Up/Down arrow
      
      datetime pe_time = g_pe_array[i].time_last;
      double pe_level  = g_pe_array[i].level;
      
      // FIX Bug 11: Place arrow OUTSIDE the wick extremes, not at PE level
      double arrow_offset = GetIndicatorValue(1) * 0.15;
      if(arrow_offset <= 0) arrow_offset = g_point * 20;
      
      double arrow_price;
      if(g_pe_array[i].direction == DIR_BULLISH)
         arrow_price = g_pe_array[i].low_extreme - arrow_offset;
      else
         arrow_price = g_pe_array[i].high_extreme + arrow_offset;
      
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_ARROW, 0, pe_time, arrow_price);
      
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, pe_time);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, arrow_price);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrow_code);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR,
         (g_pe_array[i].direction == DIR_BULLISH) ? ANCHOR_TOP : ANCHOR_BOTTOM);
      ObjectSetInteger(0, name, OBJPROP_COLOR, pe_clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      
      // FIX Bug 10: Short fixed-length line instead of extending to current bar
      datetime line_end = pe_time + PeriodSeconds() * PE_LINE_BARS;
      
      if(ObjectFind(0, line_name) < 0)
         ObjectCreate(0, line_name, OBJ_TREND, 0, pe_time, pe_level, line_end, pe_level);
      
      ObjectSetInteger(0, line_name, OBJPROP_TIME, 0, pe_time);
      ObjectSetDouble(0, line_name, OBJPROP_PRICE, 0, pe_level);
      ObjectSetInteger(0, line_name, OBJPROP_TIME, 1, line_end);
      ObjectSetDouble(0, line_name, OBJPROP_PRICE, 1, pe_level);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, pe_clr);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, line_name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
      
      // Tooltip with PE info
      string tip = StringFormat("PE#%d %s %s | Level=%.5f | L=%d R=%d%s",
         i,
         (g_pe_array[i].direction == DIR_BULLISH) ? "BULL" : "BEAR",
         (g_pe_array[i].pe_type == PE_STRICT) ? "STRICT" : "NORMAL",
         pe_level, g_pe_array[i].empty_left, g_pe_array[i].empty_right,
         g_pe_array[i].has_doji ? " +Doji" : "");
      ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
   }
}

//+------------------------------------------------------------------+
//| Draw Pattern entry/SL/TP levels                                    |
//+------------------------------------------------------------------+
void DrawPatterns()
{
   for(int i = 0; i < g_pat_count; i++)
   {
      string prefix = StringFormat("PA_PAT_%d", i);
      string entry_name = prefix + "_entry";
      string sl_name    = prefix + "_sl";
      string tp_name    = prefix + "_tp";
      string fib0_name  = prefix + "_fib0";
      string fib100_name= prefix + "_fib100";
      
      // FIX Bug 13: Only draw patterns in drawable states
      bool should_draw = g_patterns[i].is_valid &&
                         (g_patterns[i].state == PAT_CONFIRMED ||
                          g_patterns[i].state == PAT_PENDING ||
                          g_patterns[i].state == PAT_ACTIVE);
      
      if(!should_draw)
      {
         // Remove objects for dead/cancelled/closed patterns
         ObjectDelete(0, entry_name);
         ObjectDelete(0, sl_name);
         ObjectDelete(0, tp_name);
         ObjectDelete(0, fib0_name);
         ObjectDelete(0, fib100_name);
         
         // FIX Bug 13: Ensure terminal states are marked invalid
         // so their slot can be reused and objects stay deleted
         if(g_patterns[i].state == PAT_CANCELLED || g_patterns[i].state == PAT_CLOSED)
            g_patterns[i].is_valid = false;
         
         continue;
      }
      
      datetime t_start = g_patterns[i].time_confirmed;
      if(t_start == 0) continue;
      datetime t_end   = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds() * 15;
      
      bool is_buy = (g_patterns[i].trade_dir == TRADE_LONG);
      string pat_label = (g_patterns[i].type == PATTERN_2) ? "P2" : "P3";
      string dir_label = is_buy ? "BUY" : "SELL";
      
      color entry_clr = is_buy ? clrRoyalBlue : clrOrangeRed;
      color sl_clr    = clrRed;
      color tp_clr    = clrLimeGreen;
      color fib_clr   = clrGray;
      
      // Entry level
      DrawHorizontalLine(entry_name, t_start, t_end, g_patterns[i].entry_price,
                         entry_clr, STYLE_SOLID, 2,
                         StringFormat("%s %s Entry %.5f", pat_label, dir_label, g_patterns[i].entry_price));
      
      // SL level
      DrawHorizontalLine(sl_name, t_start, t_end, g_patterns[i].sl_price,
                         sl_clr, STYLE_DASH, 1,
                         StringFormat("SL %.5f (%.1f pips)", g_patterns[i].sl_price, g_patterns[i].sl_size_pips));
      
      // TP level
      DrawHorizontalLine(tp_name, t_start, t_end, g_patterns[i].tp_price,
                         tp_clr, STYLE_DASH, 1,
                         StringFormat("TP %.5f", g_patterns[i].tp_price));
      
      // Fibonacci 0% and 100% reference
      DrawHorizontalLine(fib0_name, t_start, t_end, g_patterns[i].fib_1.level_0,
                         fib_clr, STYLE_DOT, 1,
                         StringFormat("Fib 0%% %.5f", g_patterns[i].fib_1.level_0));
      
      DrawHorizontalLine(fib100_name, t_start, t_end, g_patterns[i].fib_1.level_100,
                         fib_clr, STYLE_DOT, 1,
                         StringFormat("Fib 100%% %.5f", g_patterns[i].fib_1.level_100));
   }
}

//+------------------------------------------------------------------+
//| Helper: Draw or update a horizontal trend line                     |
//+------------------------------------------------------------------+
void DrawHorizontalLine(string name, datetime t1, datetime t2, double price,
                        color clr, ENUM_LINE_STYLE style, int width, string tooltip)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

//+------------------------------------------------------------------+
//| Draw on-chart comment with EA status                               |
//+------------------------------------------------------------------+
void DrawComment()
{
   // Build status string
   string status = "";
   
   status += StringFormat("%s v%s | %s %s\n", EA_NAME, EA_VERSION, _Symbol,
                          EnumToString((ENUM_TIMEFRAMES)Period()));
   status += StringFormat("Magic: %d | Bar: %d\n", inpMagicNumber, g_bar_count);
   status += "─────────────────────────\n";
   
   // Counts
   int active_pe = 0, active_zi = 0, active_pat = 0;
   for(int i = 0; i < g_pe_count; i++)  if(g_pe_array[i].is_valid) active_pe++;
   for(int i = 0; i < g_zi_count; i++)  if(g_zi_array[i].is_valid) active_zi++;
   for(int i = 0; i < g_pat_count; i++) if(g_patterns[i].is_valid) active_pat++;
   
   status += StringFormat("PE: %d | ZI: %d | GZ: %d | Pat: %d\n",
                           active_pe, active_zi, g_gz_count, active_pat);
   
   // Trading state
   if(g_context.is_busy)
   {
      string dir_str = (g_context.active_direction == TRADE_LONG) ? "LONG" : "SHORT";
      status += StringFormat("Position: #%I64u %s\n", g_context.active_ticket, dir_str);
      status += StringFormat("  Entry=%.5f SL=%.5f TP=%.5f\n",
                              g_context.entry_price_active, g_context.sl_price_active, g_context.tp_price_active);
      status += StringFormat("  BE Stage: %d | StrictPE: %d\n",
                              (int)g_context.be_stage, g_context.strict_pe_since_entry);
   }
   else
   {
      status += "Position: NONE\n";
   }
   
   if(g_context.is_waiting_after_loss)
      status += StringFormat("⏳ Wait: %d candles remaining\n", g_context.wait_candles_remaining);
   
   status += StringFormat("Pending orders: %d\n", g_context.pending_count);
   status += StringFormat("Daily loss: %.2f EUR\n", g_context.daily_loss_eur);
   
   // Trading hours
   status += StringFormat("Trading: %s\n", IsWithinTradingHours() ? "IN HOURS" : "OUTSIDE HOURS");
   
   // ATR value
   double atr_val = GetIndicatorValue(1);
   status += StringFormat("ATR(%d): %.5f\n", inpAtrPeriod, atr_val);
   
   // Active patterns summary
   for(int i = 0; i < g_pat_count; i++)
   {
      if(!g_patterns[i].is_valid) continue;
      if(g_patterns[i].state == PAT_CANCELLED || g_patterns[i].state == PAT_CLOSED) continue;
      
      string p_type = (g_patterns[i].type == PATTERN_2) ? "P2" : "P3";
      string p_dir  = (g_patterns[i].trade_dir == TRADE_LONG) ? "BUY" : "SELL";
      string p_state;
      switch(g_patterns[i].state)
      {
         case PAT_WAITING_BREAK: p_state = "WAIT";    break;
         case PAT_CONFIRMED:     p_state = "CONF";    break;
         case PAT_PENDING:       p_state = "PEND";    break;
         case PAT_ACTIVE:        p_state = "ACTIVE";  break;
         default:                p_state = "?";        break;
      }
      
      status += StringFormat("  %s %s [%s] E=%.2f SL=%.2f\n",
                              p_type, p_dir, p_state,
                              g_patterns[i].entry_price, g_patterns[i].sl_price);
   }
   
   Comment(status);
}

//+------------------------------------------------------------------+
