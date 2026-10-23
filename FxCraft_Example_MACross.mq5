//+------------------------------------------------------------------+
//|                                      FxCraft_Example_MACross.mq5 |
//|                    Example EA from FxCraft - https://fxcraft.biz |
//+------------------------------------------------------------------+
//
// PL: Przykładowy EA (program edukacyjny) – przecięcie dwóch średnich kroczących.
//     Działa WYŁĄCZNIE na rachunku demo i w testerze strategii.
//     Licencja: FxCraft Example EA License (plik LICENSE.txt) – bezpłatny, do nauki
//     i testów, udostępniany „tak jak jest”, bez żadnych gwarancji.
//     Program nie stanowi rekomendacji ani doradztwa inwestycyjnego. Handel na rynku
//     Forex i kontraktami CFD wiąże się z wysokim ryzykiem utraty kapitału. Wyniki
//     historyczne i wyniki z testera nie gwarantują przyszłych wyników. FxCraft nie
//     ponosi odpowiedzialności za straty wynikające z użycia programu.
//
// EN: Example EA (educational program) – crossover of two moving averages.
//     Works ONLY on demo accounts and in the Strategy Tester.
//     License: FxCraft Example EA License (LICENSE.txt) – free, for learning and
//     testing, provided "as is", without any warranty.
//     This program is not investment advice or a recommendation. Trading Forex and
//     CFDs involves a high risk of losing capital. Past and backtest results do not
//     guarantee future results. FxCraft is not liable for any losses resulting from
//     the use of this program.
//
// Chcesz używać EA na rachunku rzeczywistym lub go rozbudować? Napisz: https://fxcraft.biz
// Want to use the EA on a live account or extend it? Contact us: https://fxcraft.biz
//
// Zasady / Rules:
//   - sygnał na zamkniętych świecach wybranego TimeFrame: szybka średnia przecina wolną
//     signal on closed bars of the selected TimeFrame: fast MA crosses slow MA
//   - po uruchomieniu EA czeka na pierwsze nowe przecięcie (nie otwiera od razu)
//     after start the EA waits for the first new crossover (no immediate entry)
//   - jedna pozycja naraz; sygnał przeciwny zamyka pozycję i otwiera przeciwną
//     one position at a time; an opposite signal closes it and opens the opposite one
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, FxCraft"
#property link        "https://fxcraft.biz"
#property version     "1.00"
#property description "Example EA from FxCraft: moving average crossover (educational program)."
#property description "DEMO ACCOUNTS AND STRATEGY TESTER ONLY. Provided 'as is', without warranty."
#property description "Not investment advice. Trading Forex/CFDs involves a high risk of losing capital."
#property description "License: FxCraft Example EA License. https://fxcraft.biz"

#include <Trade\Trade.mqh>

//--- Parametry / Inputs
input group "=== Signal ==="
input ENUM_TIMEFRAMES    InpTimeframe    = PERIOD_CURRENT; // TimeFrame
input int                InpFastPeriod   = 10;             // Fast MA period
input int                InpSlowPeriod   = 30;             // Slow MA period
input ENUM_MA_METHOD     InpMAMethod     = MODE_EMA;       // MA method
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE;    // Applied price

input group "=== Orders ==="
input double             InpLots         = 0.10;           // Lot (fixed)
input int                InpStopLoss     = 300;            // Stop Loss (points, 0 = none)
input int                InpTakeProfit   = 600;            // Take Profit (points, 0 = none)
input ulong              InpMagic        = 5010;           // Magic number
input int                InpSlippage     = 10;             // Max slippage (points)

input group "=== Filters ==="
input int                InpMaxSpread    = 30;             // Max spread (points, 0 = off)

//--- Stałe / Constants
#define EA_NAME        "FxCraft Example MACross"
#define LABEL_TITLE    "FxCraftExample_Title"
#define LABEL_SUBTITLE "FxCraftExample_Subtitle"
#define MAX_RETRIES    3

enum ENUM_Account_State { ACC_STATE_UNKNOWN, ACC_STATE_ALLOWED, ACC_STATE_BLOCKED };
enum ENUM_Open_Result   { OPEN_OK, OPEN_RETRY_LATER, OPEN_GIVE_UP };

//--- Zmienne globalne / Globals
CTrade   _trade;
int      _fastHandle    = INVALID_HANDLE;
int      _slowHandle    = INVALID_HANDLE;
datetime _lastBarTime   = 0;   // ostatnia sprawdzona świeca / last processed bar
// Sygnał powstaje tylko na otwarciu nowej świecy. Gdy otwarcie pozycji się nie uda (spread, requote),
// EA ponawia je na kolejnych tickach, ale najdalej do końca tej świecy (_signalBarTime).
// A signal is created only at the open of a new bar. If opening fails (spread, requote), the EA retries
// on the next ticks, but no longer than until the end of that bar (_signalBarTime).
int      _signal        = 0;   // 1 = BUY, -1 = SELL, 0 = brak / none
datetime _signalBarTime = 0;   // świeca, na której powstał sygnał / bar of the pending signal

//+------------------------------------------------------------------+
//| Inicjalizacja / Initialization                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Tylko demo i tester / Demo and tester only
   if(GetAccountState() == ACC_STATE_BLOCKED)
   {
      ShowDemoOnlyMessage();
      return INIT_FAILED;
   }

   // Kontrola parametrów / Input validation
   if(InpFastPeriod < 1 || InpSlowPeriod <= InpFastPeriod)
   {
      Log("okres wolnej średniej musi być większy niż szybkiej",
          "slow MA period must be greater than fast MA period");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpLots <= 0.0 || InpStopLoss < 0 || InpTakeProfit < 0 || InpSlippage < 0 || InpMaxSpread < 0)
   {
      Log("niepoprawne parametry (lot > 0, pozostałe >= 0)", "invalid inputs (lot > 0, others >= 0)");
      return INIT_PARAMETERS_INCORRECT;
   }

   _fastHandle = iMA(_Symbol, InpTimeframe, InpFastPeriod, 0, InpMAMethod, InpAppliedPrice);
   _slowHandle = iMA(_Symbol, InpTimeframe, InpSlowPeriod, 0, InpMAMethod, InpAppliedPrice);
   if(_fastHandle == INVALID_HANDLE || _slowHandle == INVALID_HANDLE)
   {
      Log("błąd tworzenia wskaźnika " + IntegerToString(GetLastError()),
          "indicator creation error " + IntegerToString(GetLastError()));
      return INIT_FAILED;
   }

   _trade.SetExpertMagicNumber(InpMagic);
   _trade.SetDeviationInPoints((ulong)InpSlippage);
   _trade.SetTypeFillingBySymbol(_Symbol);
   _trade.SetMarginMode();

   CreateLabels();
   Log("przykładowy program edukacyjny – wysokie ryzyko utraty kapitału, tylko rachunek demo i tester",
       "example educational program – high risk of losing capital, demo account and tester only");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Zakończenie / Deinitialization                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, LABEL_TITLE);
   ObjectDelete(0, LABEL_SUBTITLE);
   if(_fastHandle != INVALID_HANDLE)
      IndicatorRelease(_fastHandle);
   if(_slowHandle != INVALID_HANDLE)
      IndicatorRelease(_slowHandle);
}

//+------------------------------------------------------------------+
//| Główna pętla / Main loop                                         |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsAccountOk())
      return;

   datetime barTime = iTime(_Symbol, InpTimeframe, 0);
   if(barTime == 0)
      return;

   // Pierwszy tick: tylko zapamiętaj świecę – EA czeka na nowe przecięcie
   // First tick: remember the bar only – the EA waits for a new crossover
   if(_lastBarTime == 0)
   {
      _lastBarTime = barTime;
      return;
   }

   // Nowa świeca: sprawdź przecięcie na świecach zamkniętych / New bar: check crossover on closed bars
   if(barTime != _lastBarTime)
   {
      int signal = 0;
      if(!ReadSignal(signal))
         return;   // dane niegotowe – ponowienie na kolejnym ticku / data not ready – retry on next tick
      _lastBarTime   = barTime;
      _signal        = signal;
      _signalBarTime = barTime;
      if(signal != 0)
         Log("sygnał " + SignalName(signal), "signal " + SignalName(signal));
   }

   // Sygnał jest ważny do końca świecy / The signal is valid until the end of the bar
   if(_signal != 0 && _signalBarTime == barTime)
      ExecuteSignal();
}

//+------------------------------------------------------------------+
//| Sygnał: 1 = BUY, -1 = SELL, 0 = brak / Signal                    |
//+------------------------------------------------------------------+
bool ReadSignal(int &signal)
{
   double fast[], slow[];
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   // indeks 0 = świeca 1 (ostatnia zamknięta), indeks 1 = świeca 2
   // index 0 = bar 1 (last closed), index 1 = bar 2
   if(CopyBuffer(_fastHandle, 0, 1, 2, fast) != 2 || CopyBuffer(_slowHandle, 0, 1, 2, slow) != 2)
      return false;

   signal = 0;
   if(fast[1] <= slow[1] && fast[0] > slow[0])
      signal = 1;
   else if(fast[1] >= slow[1] && fast[0] < slow[0])
      signal = -1;
   return true;
}

string SignalName(int signal)
{
   return (signal > 0) ? "BUY" : "SELL";
}

//+------------------------------------------------------------------+
//| Wykonanie sygnału / Signal execution                             |
//+------------------------------------------------------------------+
void ExecuteSignal()
{
   bool isBuy = (_signal > 0);
   ENUM_POSITION_TYPE sameType     = isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   ENUM_POSITION_TYPE oppositeType = isBuy ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;

   // Sygnał przeciwny zamyka pozycję / An opposite signal closes the position
   if(CountPositions(oppositeType) > 0 && !ClosePositions(oppositeType))
      return;   // ponowienie na kolejnym ticku / retry on next tick

   // Jedna pozycja naraz / One position at a time
   if(CountPositions(sameType) > 0)
   {
      _signal = 0;
      return;
   }

   if(!IsSpreadOk())
      return;   // ponowienie w tej świecy / retry within this bar

   ENUM_Open_Result result = OpenPosition(isBuy);
   if(result != OPEN_RETRY_LATER)
      _signal = 0;
}

//+------------------------------------------------------------------+
//| Otwarcie pozycji rynkowej / Open a market position               |
//+------------------------------------------------------------------+
ENUM_Open_Result OpenPosition(bool isBuy)
{
   // Lot liczony tuż przed otwarciem / Lot calculated right before opening
   double lots = NormalizeLots(InpLots);

   for(int attempt = 1; attempt <= MAX_RETRIES; attempt++)
   {
      double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(!IsVolumeLimitOk(isBuy, lots) || !HasEnoughMargin(isBuy, lots, price))
         return OPEN_GIVE_UP;

      double sl, tp;
      CalcStops(isBuy, price, sl, tp);

      bool sent = isBuy ? _trade.Buy(lots, _Symbol, price, sl, tp, EA_NAME)
                        : _trade.Sell(lots, _Symbol, price, sl, tp, EA_NAME);
      uint retcode = _trade.ResultRetcode();
      if(sent && (retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED))
      {
         string details = SignalName(isBuy ? 1 : -1) + " " + DoubleToString(lots, LotDigits()) +
                          " SL=" + DoubleToString(sl, _Digits) + " TP=" + DoubleToString(tp, _Digits);
         Log("otwarto " + details, "opened " + details);
         return OPEN_OK;
      }

      string error = IntegerToString(retcode) + " (" + _trade.ResultRetcodeDescription() + ")";
      Log("błąd otwarcia " + error + ", próba " + IntegerToString(attempt),
          "open error " + error + ", attempt " + IntegerToString(attempt));
      if(!IsRetryable(retcode))
         return OPEN_GIVE_UP;
      Sleep(500);
   }
   return OPEN_RETRY_LATER;
}

//+------------------------------------------------------------------+
//| Ceny SL/TP z kontrolą stop level / SL/TP prices with stop level  |
//+------------------------------------------------------------------+
void CalcStops(bool isBuy, double price, double &sl, double &tp)
{
   double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   sl = 0.0;
   tp = 0.0;

   if(isBuy)
   {
      if(InpStopLoss > 0)
         sl = MathMin(price - InpStopLoss * _Point, bid - minDist);
      if(InpTakeProfit > 0)
         tp = MathMax(price + InpTakeProfit * _Point, bid + minDist);
   }
   else
   {
      if(InpStopLoss > 0)
         sl = MathMax(price + InpStopLoss * _Point, ask + minDist);
      if(InpTakeProfit > 0)
         tp = MathMin(price - InpTakeProfit * _Point, ask - minDist);
   }

   double slWanted = (InpStopLoss > 0) ? price + (isBuy ? -1 : 1) * InpStopLoss * _Point : 0.0;
   double tpWanted = (InpTakeProfit > 0) ? price + (isBuy ? 1 : -1) * InpTakeProfit * _Point : 0.0;
   if(MathAbs(sl - slWanted) > _Point / 2 || MathAbs(tp - tpWanted) > _Point / 2)
      Log("SL/TP powiększone do minimalnej odległości brokera", "SL/TP widened to the broker minimum distance");

   sl = NormalizePrice(sl);
   tp = NormalizePrice(tp);
}

//+------------------------------------------------------------------+
//| Wolne środki / Free margin check                                 |
//+------------------------------------------------------------------+
bool HasEnoughMargin(bool isBuy, double lots, double price)
{
   double margin = 0.0;
   if(!OrderCalcMargin(isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lots, price, margin))
   {
      Log("błąd obliczenia depozytu " + IntegerToString(GetLastError()),
          "margin calculation error " + IntegerToString(GetLastError()));
      return false;
   }
   if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      Log("za mało wolnych środków", "not enough free margin");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Filtr spreadu / Spread filter                                    |
//+------------------------------------------------------------------+
bool IsSpreadOk()
{
   if(InpMaxSpread <= 0)
      return true;
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= InpMaxSpread)
      return true;

   // komunikat raz na świecę / message once per bar
   static datetime lastLogBar = 0;
   if(lastLogBar != _signalBarTime)
   {
      lastLogBar = _signalBarTime;
      string values = IntegerToString(spread) + " > " + IntegerToString(InpMaxSpread);
      Log("spread za wysoki: " + values, "spread too high: " + values);
   }
   return false;
}

//+------------------------------------------------------------------+
//| Pozycje tego EA / Positions of this EA                           |
//+------------------------------------------------------------------+
bool IsOwnPosition()
{
   return PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == (long)InpMagic;
}

int CountPositions(ENUM_POSITION_TYPE type)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || !IsOwnPosition())
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type)
         count++;
   }
   return count;
}

// true, gdy wszystkie pozycje danego typu zostały zamknięte / true when all positions of the type were closed
bool ClosePositions(ENUM_POSITION_TYPE type)
{
   bool allClosed = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsOwnPosition())
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;
      if(!ClosePositionWithRetry(ticket))
         allClosed = false;
   }
   return allClosed;
}

bool ClosePositionWithRetry(ulong ticket)
{
   string ticketText = "#" + IntegerToString((long)ticket);
   // Za blisko ceny (freeze level) – bez żądania, ponowienie na kolejnym ticku
   // Too close to the market (freeze level) – no request, retry on the next tick
   if(PositionSelectByTicket(ticket) && IsPositionFrozen())
   {
      LogFrozen(ticket);
      return false;
   }
   for(int attempt = 1; attempt <= MAX_RETRIES; attempt++)
   {
      if(_trade.PositionClose(ticket, (ulong)InpSlippage))
      {
         uint retcode = _trade.ResultRetcode();
         if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED)
         {
            Log("zamknięto pozycję " + ticketText, "position closed " + ticketText);
            return true;
         }
      }
      uint err = _trade.ResultRetcode();
      string error = IntegerToString(err) + " (" + _trade.ResultRetcodeDescription() + ") " + ticketText;
      Log("błąd zamknięcia " + error + ", próba " + IntegerToString(attempt),
          "close error " + error + ", attempt " + IntegerToString(attempt));
      if(!IsRetryable(err))
         return false;
      Sleep(500);
   }
   return false;
}

// Błędy, przy których warto ponowić zlecenie / Errors worth retrying
bool IsRetryable(uint retcode)
{
   return retcode == TRADE_RETCODE_REQUOTE || retcode == TRADE_RETCODE_PRICE_CHANGED ||
          retcode == TRADE_RETCODE_PRICE_OFF || retcode == TRADE_RETCODE_TOO_MANY_REQUESTS;
}

//+------------------------------------------------------------------+
//| Lot i ceny / Lot and prices                                      |
//+------------------------------------------------------------------+
// Lot zaokrąglony w dół do kroku lota i przycięty do min./maks. brokera; liczba miejsc po przecinku
// z kroku lota, np. krok 0.01 -> 2, 0.05 -> 2, 0.5 -> 1, 1 -> 0, 0.001 -> 3 (0.12 przy kroku 0.05 -> 0.10).
// Lot rounded down to the lot step and clamped to broker min/max; decimal places from the lot step.
double NormalizeLots(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step > 0.0)
      lots = MathFloor(lots / step + 1e-9) * step;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   return NormalizeDouble(lots, LotDigits());
}

int LotDigits()
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   return (step > 0.0) ? (int)MathMax(0, MathCeil(-MathLog10(step) - 1e-9)) : 2;
}

double NormalizePrice(double price)
{
   if(price <= 0.0)
      return 0.0;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize > 0.0)
      price = MathRound(price / tickSize) * tickSize;
   return NormalizeDouble(price, _Digits);
}

//+------------------------------------------------------------------+
//| Limit wolumenu na instrumencie / Symbol volume limit             |
//+------------------------------------------------------------------+
// SYMBOL_VOLUME_LIMIT: maks. łączny wolumen pozycji i zleceń oczekujących w jednym kierunku na instrumencie
// (wszystkich, nie tylko tego EA); 0 = bez limitu.
// SYMBOL_VOLUME_LIMIT: max. total volume of positions and pending orders in one direction on the symbol
// (all of them, not only this EA's); 0 = no limit.
bool IsVolumeLimitOk(bool isBuy, double lots)
{
   double limit = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   if(limit <= 0.0)
      return true;

   double volume = lots;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      bool positionBuy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      if(positionBuy == isBuy)
         volume += PositionGetDouble(POSITION_VOLUME);
   }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderGetTicket(i) == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      bool orderBuy = (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_STOP_LIMIT);
      if(orderBuy == isBuy)
         volume += OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   if(volume <= limit + 1e-8)
      return true;

   string values = DoubleToString(volume, LotDigits()) + " > " + DoubleToString(limit, LotDigits());
   Log("przekroczony limit wolumenu na instrumencie: " + values, "symbol volume limit exceeded: " + values);
   return false;
}

//+------------------------------------------------------------------+
//| Poziom zamrożenia / Freeze level                                 |
//+------------------------------------------------------------------+
// SYMBOL_TRADE_FREEZE_LEVEL: serwer nie pozwala zamknąć pozycji ani skasować zlecenia, gdy SL, TP lub cena
// zlecenia są bliżej ceny rynkowej niż poziom zamrożenia (błąd „too close to market”). EA nie wysyła wtedy
// żądania i ponawia na kolejnym ticku.
// SYMBOL_TRADE_FREEZE_LEVEL: the server rejects closing a position or deleting an order when its SL, TP or
// order price is closer to the market than the freeze level ("too close to market"). The EA does not send
// a request then and retries on the next tick.
// Komunikat raz na pozycję/zlecenie / Message once per position/order
void LogFrozen(ulong ticket)
{
   static ulong lastTicket = 0;
   if(ticket == lastTicket)
      return;
   lastTicket = ticket;
   string ticketText = "#" + IntegerToString((long)ticket);
   Log("pozycja/zlecenie " + ticketText + " za blisko ceny (freeze level) – ponowienie później",
       "position/order " + ticketText + " too close to the market (freeze level) – retry later");
}

double FreezeDistance()
{
   return (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
}

// Wybrana pozycja / Selected position
bool IsPositionFrozen()
{
   double freeze = FreezeDistance();
   if(freeze <= 0.0)
      return false;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = PositionGetDouble(POSITION_SL);
   double tp  = PositionGetDouble(POSITION_TP);
   if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      return (tp > 0.0 && tp - bid < freeze) || (sl > 0.0 && bid - sl < freeze);
   return (tp > 0.0 && ask - tp < freeze) || (sl > 0.0 && sl - ask < freeze);
}

//+------------------------------------------------------------------+
//| Tylko demo i tester / Demo and tester only                       |
//+------------------------------------------------------------------+
ENUM_Account_State GetAccountState()
{
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))
      return ACC_STATE_ALLOWED;
   if(AccountInfoInteger(ACCOUNT_LOGIN) == 0)
      return ACC_STATE_UNKNOWN;   // terminal jeszcze niepołączony / terminal not connected yet
   if((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO)
      return ACC_STATE_ALLOWED;
   return ACC_STATE_BLOCKED;      // rachunek rzeczywisty lub konkursowy / real or contest account
}

// Sprawdzane na każdym ticku (np. zmiana konta) / Checked on every tick (e.g. account change)
bool IsAccountOk()
{
   ENUM_Account_State state = GetAccountState();
   if(state == ACC_STATE_ALLOWED)
      return true;
   if(state == ACC_STATE_BLOCKED)
   {
      ShowDemoOnlyMessage();
      ExpertRemove();
   }
   return false;
}

void ShowDemoOnlyMessage()
{
   string message = Msg("To przykładowy EA od FxCraft – działa tylko na rachunku demo i w testerze strategii. " +
                        "Jeśli chcesz używać go na rachunku rzeczywistym lub dopasować do swoich potrzeb, " +
                        "skontaktuj się z nami: https://fxcraft.biz",
                        "This is an example EA from FxCraft – it works only on demo accounts and in the Strategy Tester. " +
                        "If you want to use it on a live account or adapt it to your needs, " +
                        "contact us: https://fxcraft.biz");
   Alert(EA_NAME, ": ", message);
   Print(EA_NAME, ": ", message);
}

//+------------------------------------------------------------------+
//| Komunikaty w języku terminalu / Messages in the terminal language |
//+------------------------------------------------------------------+
string Msg(string pl, string en)
{
   return (TerminalInfoString(TERMINAL_LANGUAGE) == "Polish") ? pl : en;
}

void Log(string pl, string en)
{
   Print(EA_NAME, ": ", Msg(pl, en));
}

//+------------------------------------------------------------------+
//| Etykieta na wykresie / Chart label                               |
//+------------------------------------------------------------------+
void CreateLabels()
{
   CreateLabel(LABEL_TITLE, "Example EA from FxCraft", 13, clrRed, 20);
   CreateLabel(LABEL_SUBTITLE, "DEMO / TESTER ONLY", 9, clrGray, 44);
}

void CreateLabel(string name, string text, int fontSize, color textColor, int yDistance)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDistance);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
