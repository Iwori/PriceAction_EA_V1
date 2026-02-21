//+------------------------------------------------------------------+
//| Logger.mqh                                                        |
//| Copyright 2026, Iwori Fx.                                         |
//| https://www.mql5.com/en/users/iwori_Fx                            |
//| https://www.freelancer.com/u/iwori                                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"

//+------------------------------------------------------------------+
//| Debug Logger Class (Backtest only)                                 |
//+------------------------------------------------------------------+
class CDebugLogger
{
private:
   int            m_handle;
   bool           m_active;
   string         m_filename;
   
   // Compact timestamp: DDHHMM
   string TS()
   {
      MqlDateTime dt;
      TimeCurrent(dt);
      return StringFormat("%02d%02d%02d", dt.day, dt.hour, dt.min);
   }
   
   // Short price: remove trailing zeros
   string P(double price)
   {
      string s = DoubleToString(price, g_digits);
      // Strip trailing zeros after decimal
      if(StringFind(s, ".") >= 0)
      {
         int len = StringLen(s);
         while(len > 1 && StringGetCharacter(s, len-1) == '0') len--;
         if(StringGetCharacter(s, len-1) == '.') len--;
         s = StringSubstr(s, 0, len);
      }
      return s;
   }
   
   // Direction short: B=Bull, R=Bear
   string D(int dir) { return (dir == DIR_BULLISH) ? "B" : "R"; }
   
   // Trade direction short: L=Long, S=Short
   string TD(int tdir) { return (tdir == TRADE_LONG) ? "L" : "S"; }
   
public:
   CDebugLogger() : m_handle(INVALID_HANDLE), m_active(false), m_filename("") {}
   ~CDebugLogger() { Close(); }
   
   bool Init(string symbol, ENUM_TIMEFRAMES tf)
   {
      m_active = (bool)MQLInfoInteger(MQL_TESTER);
      if(!m_active) return true;
      
      string tf_str = EnumToString(tf);
      StringReplace(tf_str, "PERIOD_", "");
      
      MqlDateTime dt;
      TimeCurrent(dt);
      string date_str = StringFormat("%04d%02d%02d_%02d%02d%02d",
                                     dt.year, dt.mon, dt.day,
                                     dt.hour, dt.min, dt.sec);
      
      m_filename = StringFormat("PriceAction_EA_Debug_%s_%s_%s.log",
                                symbol, tf_str, date_str);
      
      m_handle = FileOpen(m_filename, FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_ANSI);
      if(m_handle == INVALID_HANDLE)
      {
         Print("ERROR: Could not create debug log file: ", m_filename, " Error: ", GetLastError());
         m_active = false;
         return false;
      }
      
      // Header (human-readable, not compact)
      W(StringFormat("# %s v%s | %s %s | %s", EA_NAME, EA_VERSION, symbol, tf_str,
        TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS)));
      return true;
   }
   
   // Low-level write with compact timestamp
   void W(string msg)
   {
      if(!m_active || m_handle == INVALID_HANDLE) return;
      FileWriteString(m_handle, TS() + "|" + msg + "\n");
      FileFlush(m_handle);
   }
   
   // Raw write (no timestamp, for header)
   void WR(string msg)
   {
      if(!m_active || m_handle == INVALID_HANDLE) return;
      FileWriteString(m_handle, msg + "\n");
      FileFlush(m_handle);
   }
   
   // === INIT / PARAMS ===
   void LogInputParameters()
   {
      if(!m_active) return;
      W(StringFormat("$I|%s|%s|%.0f|%.2f|%.2f|%d|%d|%d|%s-%s|%s-%s|%s|%d|%d|%d",
         _Symbol, EnumToString((ENUM_TIMEFRAMES)Period()),
         AccountInfoDouble(ACCOUNT_BALANCE), inpRiskPercent, inpTpRatio,
         inpAtrPeriod, inpWaitCandlesAfterLoss, inpZoneExpireCandles,
         inpSlot1Start, inpSlot1End, inpSlot2Start, inpSlot2End, inpCloseAllTime,
         inpEnableBreakeven, inpEnableTrailing, inpMagicNumber));
      W(StringFormat("$S|%.5f|%.6f|%d|%.2f|%.2f|%.2f|%.2f|%d",
         g_tick_size, g_tick_value, g_stops_level,
         SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
         SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX),
         SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP),
         SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE),
         (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE)));
   }
   
   // === PE ===
   void LogPE(string action, int index, const StructuralPoint &pe)
   {
      if(!m_active) return;
      // PE|#id|B/R|N/S|level|eL|eR|bar
      W(StringFormat("PE|#%d|%s|%s|%s|%d|%d|%d",
         index, D(pe.direction),
         (pe.pe_type == PE_STRICT) ? "S" : "N",
         P(pe.level), pe.empty_left, pe.empty_right, pe.bar_created));
   }
   
   // === ZONES ===
   void LogZone(string action, int index, const InterestZone &zone)
   {
      if(!m_active) return;
      string code;
      if(action == "CREATED")              code = "ZC";
      else if(action == "PARTIAL_MITIG")   code = "ZP";
      else if(action == "MITIGATED_FULL")  code = "ZF";
      else if(action == "MITIGATED_SHRUNK") code = "ZP";
      else if(action == "EXPIRED")         code = "ZX";
      else if(action == "HIST_MITIGATED_FULL")   code = "ZH";
      else if(action == "HIST_MITIGATED_SHRUNK")  code = "ZH";
      else code = "Z?";
      
      string base = (zone.base_type == ZI_BASE_PE) ? "P" :
                     (zone.base_type == ZI_BASE_BRAKE) ? "K" : "X";
      
      if(code == "ZC" || code == "ZH")
         W(StringFormat("%s|#%d|%s|%s|%s|%s|%d", code, index,
            D(zone.direction), base, P(zone.upper_price), P(zone.lower_price), zone.bar_created));
      else if(code == "ZP")
         W(StringFormat("%s|#%d|%s|%s|%d", code, index,
            P(zone.upper_price), P(zone.lower_price), zone.bar_created));
      else if(code == "ZF")
         W(StringFormat("%s|#%d|%d", code, index, zone.bar_created));
      else if(code == "ZX")
         W(StringFormat("%s|#%d|%d", code, index, zone.bar_created));
   }
   
   // === PATTERNS ===
   void LogPattern(string action, int index, const PatternInfo &pat)
   {
      if(!m_active) return;
      string pt = (pat.type == PATTERN_2) ? "2" : "3";
      
      if(action == "REGISTERED" || action == "P3_ANALYZED")
      {
         if(pat.state == PAT_WAITING_BREAK)
            W(StringFormat("P3W|#%d|%.0f", index, pat.pattern_size_pips));
         else
            W(StringFormat("PR|#%d|%s|%s|%.0f|%.1f|%s|%s|%s", index, pt, TD(pat.trade_dir),
               pat.pattern_size_pips, pat.indicator_value,
               P(pat.entry_price), P(pat.sl_price), P(pat.tp_price)));
      }
   }
   
   // === CANCELLATIONS ===
   void LogCancel(string reason, int pattern_index)
   {
      if(!m_active) return;
      // Map verbose reasons to compact codes
      string code;
      if(StringFind(reason, "2.5x") >= 0 || StringFind(reason, ">2.5") >= 0)        code = "adv";
      else if(StringFind(reason, "opposite ZI") >= 0)                                 code = "zi";
      else if(StringFind(reason, "3-pattern") >= 0)                                   code = "3lim";
      else if(StringFind(reason, "moment passed") >= 0)                               code = "13w";
      else if(StringFind(reason, "cannot wait") >= 0)                                 code = "13m";
      else if(StringFind(reason, "SL crossed") >= 0)                                  code = "slx";
      else if(StringFind(reason, "strict") >= 0 && StringFind(reason, "PE") >= 0)     code = "2pe";
      else if(StringFind(reason, "P3 size") >= 0 || StringFind(reason, "2x ZI") >= 0) code = "p3sz";
      else if(StringFind(reason, "impulse") >= 0 || StringFind(reason, "1.6.4") >= 0) code = "imp";
      else if(StringFind(reason, "Daily") >= 0 || StringFind(reason, "daily") >= 0)   code = "dc";
      else code = reason; // Fallback: raw text
      
      W(StringFormat("PX|#%d|%s", pattern_index, code));
   }
   
   // === TRADES ===
   void LogTrade(string action, ulong ticket, string details)
   {
      if(!m_active) return;
      // Compact trade events
      string code;
      if(action == "ORDER_ADD")            code = "TA+";
      else if(action == "ORDER_DELETE")    code = "TD";
      else if(action == "DEAL_ADD")        code = "TF";
      else if(action == "POSITION_CLOSED") code = "TC";
      else if(action == "MARKET_ORDER")    code = "TM";
      else if(action == "LIMIT_ORDER")     code = "TL";
      else if(action == "ORDER_MONO")      code = "TO";
      else if(action == "REQUEST_RESULT")  code = "TR";
      else if(action == "ORDER_CANCELLED") code = "TX";
      else if(action == "RECOVERED")       code = "$R";
      else if(action == "RECOVERED_PENDING") code = "$RP";
      else code = action; // Fallback
      
      W(StringFormat("%s|#%I64u|%s", code, ticket, details));
   }
   
   // === BREAKEVEN ===
   void LogBE(string action, ulong ticket, double old_sl, double new_sl)
   {
      if(!m_active) return;
      W(StringFormat("BE|#%I64u|%s|%s", ticket, P(old_sl), P(new_sl)));
   }
   
   // === DECISIONS (compact specific methods) ===
   void LogDecision(string msg)
   {
      if(!m_active) return;
      W(StringFormat("D|%s", msg));
   }
   
   // === NEW BAR ===
   void LogNewBar(int bar_count, datetime bar_time)
   {
      // Suppressed in compact mode to save space (bar info implicit in timestamps)
      // Uncomment for ultra-verbose:
      // if(!m_active) return;
      // W(StringFormat("NB|%d", bar_count));
   }
   
   // === ERRORS ===
   void LogError(string msg)
   {
      if(!m_active) return;
      W(StringFormat("$E|%s", msg));
   }
   
   // === LEGACY: category log (for brake and other misc) ===
   void Log(string category, string msg)
   {
      if(!m_active) return;
      // Map legacy categories to compact
      if(category == "BRAKE")   W(StringFormat("K|%s", msg));
      else if(category == "NOTIFY") W(StringFormat("N|%s", msg));
      else if(category == "SYSTEM") W(StringFormat("$|%s", msg));
      else W(StringFormat("%s|%s", category, msg));
   }
   
   // Close file
   void Close()
   {
      if(m_handle != INVALID_HANDLE)
      {
         W("$|END");
         FileClose(m_handle);
         m_handle = INVALID_HANDLE;
      }
      m_active = false;
   }
   
   bool IsActive() const { return m_active; }
   string GetFilename() const { return m_filename; }
};

// Global logger instance
CDebugLogger g_logger;
//+------------------------------------------------------------------+
