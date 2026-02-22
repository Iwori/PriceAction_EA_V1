//+------------------------------------------------------------------+
//| PriceAction_EA_V1.mq5                                           |
//| Copyright 2026, Iwori Fx.                                       |
//| https://www.mql5.com/en/users/iwori_Fx                          |
//| https://www.freelancer.com/u/iwori                               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Iwori Fx"
#property link      "https://www.mql5.com/en/users/iwori_Fx"
#property link      "https://www.freelancer.com/u/iwori"
#property description "\nPriceAction EA - Price Action Trading System"
#property description "Powered By: Iwori Fx"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| EA Module Includes (order matters: dependencies first)            |
//+------------------------------------------------------------------+
#include "Defines.mqh"
#include "Enums.mqh"
#include "Structures.mqh"
#include "Globals.mqh"
#include "Logger.mqh"
#include "Utilities.mqh"
#include "StructuralPoints.mqh"
#include "InterestZones.mqh"
#include "PatternHelpers.mqh"
#include "Pattern2.mqh"
#include "Pattern3.mqh"
#include "TradeManagement.mqh"
#include "OrderExecution.mqh"
#include "Visuals.mqh"

//+------------------------------------------------------------------+
//| Input Parameters (camelCase as requested)                         |
//+------------------------------------------------------------------+

// --- Risk Management ---
input group "=== Risk Management ==="
input double inpRiskPercent          = 0.5;      // Risk % per trade (balance)
input double inpDailyLossEur         = 0.0;      // Daily loss limit in EUR (0=disabled)
input double inpDailyLossPercent     = 0.0;      // Daily loss limit in % (0=disabled)
input double inpTpRatio              = 4.2;      // TP/SL ratio

// --- Indicator ---
input group "=== Indicator Settings ==="
input int    inpAtrPeriod            = 20;       // ATR period (modular indicator)

// --- Strategy Parameters ---
input group "=== Strategy Parameters ==="
input int    inpWaitCandlesAfterLoss = 13;       // Candles to wait after loss
input int    inpZoneExpireCandles    = 80;        // Zone expiration candles

// --- Trading Hours ---
input group "=== Trading Hours ==="
input string inpSlot1Start           = "08:00";  // Slot 1 start (HH:MM)
input string inpSlot1End             = "12:00";  // Slot 1 end (HH:MM)
input string inpSlot2Start           = "14:00";  // Slot 2 start (HH:MM)
input string inpSlot2End             = "20:00";  // Slot 2 end (HH:MM)
input string inpCloseAllTime         = "21:50";  // Close all positions time (Spain)

// --- Breakeven & Trailing ---
input group "=== Breakeven & Trailing ==="
input bool   inpEnableBreakeven      = true;     // Enable Breakeven
input bool   inpEnableTrailing       = true;     // Enable Trailing Stop

// --- Visual Settings ---
input group "=== Visual Settings ==="
input bool   inpDrawVisuals          = true;     // Draw zones and PE on chart
input color  inpBullishZoneColor     = clrDodgerBlue;   // Bullish zone color
input color  inpBearishZoneColor     = clrTomato;       // Bearish zone color
input color  inpPeNormalColor        = clrGold;          // Normal PE color
input color  inpPeStrictColor        = clrLime;          // Strict PE color

// --- General ---
input group "=== General Settings ==="
input int    inpMagicNumber          = 202602;   // Magic Number
input string inpSymbolOnly           = "";        // Restrict to symbol (empty=current)

//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   // Check symbol restriction
   if(inpSymbolOnly != "" && inpSymbolOnly != _Symbol)
   {
      Print(EA_NAME, ": Symbol mismatch. EA restricted to ", inpSymbolOnly, " but loaded on ", _Symbol);
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Cache symbol info
   symbol_info.Name(_Symbol);
   symbol_info.Refresh();
   g_point     = symbol_info.Point();
   g_digits    = symbol_info.Digits();
   g_tick_size = symbol_info.TickSize();
   g_tick_value= symbol_info.TickValue();
   g_stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   
   // Initialize trade object
   trade.SetExpertMagicNumber(inpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetMarginMode();
   
   // Create ATR indicator handle (modular indicator function)
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, inpAtrPeriod);
   if(g_atr_handle == INVALID_HANDLE)
   {
      Print(EA_NAME, ": Failed to create ATR indicator. Error: ", GetLastError());
      return INIT_FAILED;
   }
   
   // Parse time strings
   if(!ParseTimeString(inpSlot1Start, g_slot1_start_hour, g_slot1_start_min) ||
      !ParseTimeString(inpSlot1End,   g_slot1_end_hour,   g_slot1_end_min)   ||
      !ParseTimeString(inpSlot2Start, g_slot2_start_hour, g_slot2_start_min) ||
      !ParseTimeString(inpSlot2End,   g_slot2_end_hour,   g_slot2_end_min)   ||
      !ParseTimeString(inpCloseAllTime, g_close_hour,     g_close_min))
   {
      Print(EA_NAME, ": Invalid time format in inputs. Use HH:MM");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Allocate arrays
   ArrayResize(g_pe_array, MAX_PE);
   ArrayResize(g_zi_array, MAX_ZONES);
   ArrayResize(g_grand_zones, MAX_GRAND_ZONES);
   ArrayResize(g_patterns, MAX_PATTERNS);
   ArrayResize(g_brake_pending, MAX_ZONES);
   
   // Reset all data
   for(int i = 0; i < MAX_PE; i++)      g_pe_array[i].Reset();
   for(int i = 0; i < MAX_ZONES; i++)   g_zi_array[i].Reset();
   for(int i = 0; i < MAX_GRAND_ZONES; i++) g_grand_zones[i].Reset();
   for(int i = 0; i < MAX_PATTERNS; i++) g_patterns[i].Reset();
   for(int i = 0; i < MAX_ZONES; i++)   g_brake_pending[i].Reset();
   
   g_pe_count = 0;
   g_zi_count = 0;
   g_gz_count = 0;
   g_pat_count = 0;
   g_brake_count = 0;
   g_bar_count = 0;
   g_last_bar_time = 0;
   
   // Reset trade context
   g_context.Reset();
   
   // Detect tester mode
   g_is_tester = (bool)MQLInfoInteger(MQL_TESTER);
   
   // Initialize debug logger (only active in backtest)
   g_logger.Init(_Symbol, (ENUM_TIMEFRAMES)Period());
   g_logger.LogInputParameters();
   
   // Recovery: check for existing positions/orders from previous session
   RecoverExistingState();
   
   // Set timer for daily close check (every 30 seconds)
   if(!g_is_tester)
      EventSetTimer(30);
   
   Print(EA_NAME, " v", EA_VERSION, " initialized on ", _Symbol, " ", EnumToString((ENUM_TIMEFRAMES)Period()));
   Print("Magic Number: ", inpMagicNumber, " | Risk: ", inpRiskPercent, "% | Tester: ", g_is_tester);
   
   if(g_logger.IsActive())
      Print("Debug log file: ", g_logger.GetFilename(), " (Common\\Files)");
   
   ChartRedraw();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Log shutdown
   g_logger.Log("SYSTEM", StringFormat("EA shutting down. Reason: %d", reason));
   
   // Release indicator handle
   if(g_atr_handle != INVALID_HANDLE)
   {
      IndicatorRelease(g_atr_handle);
      g_atr_handle = INVALID_HANDLE;
   }
   
   // Stop timer
   EventKillTimer();
   
   // Clean chart objects if drawing was enabled
   if(inpDrawVisuals)
      CleanChartObjects();
   
   // Close logger
   g_logger.Close();
   
   Print(EA_NAME, " removed from ", _Symbol);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| OnTick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar (main logic runs on bar close only)
   if(!IsNewBar())
   {
      // Between bars: only check if daily close time reached (tester mode)
      if(g_is_tester)
         CheckDailyClose();
      return;
   }
   
   // New bar confirmed
   g_bar_count++;
   g_logger.LogNewBar(g_bar_count, g_last_bar_time);
   
   // Update symbol info
   symbol_info.Refresh();
   
   // Check daily loss limit
   if(!CheckDailyLossLimit())
   {
      g_logger.LogDecision("daily_limit");
      return;
   }
   
   // Check daily close time
   CheckDailyClose();
   
   // Reset daily loss at new day
   CheckDailyReset();
   
   // Update zone expiration counters
   UpdateZoneExpiration();
   
   // Update post-loss wait counter
   UpdateWaitCounter();
   
   //=== PHASE 2: Detect Structural Points ===
   DetectStructuralPoints();
   
   //=== PHASE 3a: Detect Interest Zones (creation) ===
   DetectZonesPE();
   DetectZonesBrake();
   ProcessBrakePending();
   
   // On first bar, run historical mitigation BEFORE pattern detection
   // so deep-scan zones that should be dead don't trigger false patterns
   if(g_bar_count == 1)
      RunHistoricalMitigation();
   
   // Build grand zones for pattern detection
   BuildGrandZones();
   
   //=== PHASE 4: Detect Pattern 2 (BEFORE mitigation) ===
   DetectPattern2();
   
   //=== PHASE 5: Detect Pattern 3 (BEFORE mitigation) ===
   DetectPattern3();
   UpdatePendingPattern3();
   
   //=== PHASE 3b: NOW apply mitigation for future bars ===
   UpdateMitigation();
   BuildGrandZones(); // Rebuild after mitigation changes bounds
   
   //=== PHASE 6: Manage open trades ===
   ManageBreakeven();
   ManageTrailingStop();
   CheckPatternCancellations();
   PrioritizeAndExecute();
   
   //=== PHASE 8: Draw visuals ===
   if(inpDrawVisuals) DrawVisuals();
}

//+------------------------------------------------------------------+
//| OnTimer - Check daily close (live trading)                         |
//+------------------------------------------------------------------+
void OnTimer()
{
   CheckDailyClose();
}

//+------------------------------------------------------------------+
//| OnTradeTransaction - Track order/position events for logging       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Only process if logger is active (backtest mode)
   if(!g_logger.IsActive()) return;
   
   // Log based on transaction type
   switch(trans.type)
   {
      case TRADE_TRANSACTION_ORDER_ADD:
         g_logger.LogTrade("ORDER_ADD", trans.order,
            StringFormat("%.2f|%.1f|%.1f|%.1f",
               trans.volume, trans.price, trans.price_sl, trans.price_tp));
         break;
         
      case TRADE_TRANSACTION_ORDER_UPDATE:
         g_logger.LogTrade("ORDER_UPDATE", trans.order,
            StringFormat("%.2f|%.1f|%.1f|%.1f",
               trans.volume, trans.price, trans.price_sl, trans.price_tp));
         break;
         
      case TRADE_TRANSACTION_ORDER_DELETE:
         g_logger.LogTrade("ORDER_DELETE", trans.order, "del");
         break;
         
      case TRADE_TRANSACTION_DEAL_ADD:
      {
         string deal_type_str;
         switch(trans.deal_type)
         {
            case DEAL_TYPE_BUY:     deal_type_str = "B";     break;
            case DEAL_TYPE_SELL:    deal_type_str = "S";     break;
            default:                deal_type_str = "?"; break;
         }
         g_logger.LogTrade("DEAL_ADD", trans.deal,
            StringFormat("%s|%.2f|%.1f|#%I64u",
               deal_type_str, trans.volume, trans.price, trans.position));
         break;
      }
      
      case TRADE_TRANSACTION_POSITION:
         g_logger.LogTrade("POSITION_UPDATE", trans.position,
            StringFormat("%.2f|%.1f|%.1f|%.1f",
               trans.volume, trans.price, trans.price_sl, trans.price_tp));
         break;
         
      case TRADE_TRANSACTION_HISTORY_ADD:
      {
         if(trans.order > 0)
            g_logger.LogTrade("HISTORY_ADD", trans.order, "hist");
         break;
      }
      
      default:
         break;
   }
   
   if(trans.type == TRADE_TRANSACTION_REQUEST && result.retcode != 0)
   {
      g_logger.LogTrade("REQUEST_RESULT", result.order,
         StringFormat("%d|#%I64u|%.1f|%.2f",
            result.retcode, result.deal, result.price, result.volume));
   }
}
//+------------------------------------------------------------------+
