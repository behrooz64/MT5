//+------------------------------------------------------------------+
//|                                                   Kia64.mq5       |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                                                  |
//+------------------------------------------------------------------+

#property description "Owner : Kia64 "
#property link        "https://kia64.ir"
#property description "Kia64 Academy Presentation"
input string AllowedBroker = "AMarkets"; // Allowed broker name fragment; supports AMarkets server variants
#define EXPIRATION_DATE "2027.01.20"
#define CORRECT_PASSWORD "Kia64"

#include <Trade\Trade.mqh>
CTrade m_trade;


input string st ="==Security password=="; // Give Me Code
input string user_password = "";
input string Set = "==========Setting Bot=========";
string KamalEA = "Kia64 UNLIMITED VERSION"; // in
int MagicNumber = 8398;//Magic Number                           // in
int MaxSpread = 500;//Legacy max spread in points (for open a trade)
input bool KiaXAM_EnableSpreadFilter = true; // Enable live spread filter for new entries
input double KiaXAM_MaxSpreadPrice = 2.50; // Maximum Bid/Ask difference in symbol price units

string Separo0="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

string Money = "IF MONEY MANAGEMENT IS FALSE, Kia64 WORK WITH 'Lots'";//MONEY MANAGEMENT SETTINGS  // in
input double Lots = 0.01;//Lots 
double LottoDaTradare;
bool MoneyManagement = false;//Money Management  // in
double RiskPercent = 1;//Risk Percent    //in

double MaxLot = 0;//Max Lot Amount (0 = disabled)    //in


string Separo1="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


string INDICATORS = "INDICATORS SETTINGS";     //in
bool EnableBollingerBands = true;//Enable Bollinger Bands   // in
enum ENUM_BB
  {
   SellAboveAndBuyBelow = 0,//Sell Above and Buy Below
   BuyAboveAndSellBelow = 1,//Buy Above and Sell Below
   UpTrendBuyAndDownTrendSell = 2,//Up Trend Buy and Down Trend Sell
   DownTrendBuyAndUpTrendSell = 3,//Down Trend Buy and Up Trend Sell
   CrossUpCentralBandInUpTrendBuy = 4, //Cross Up Central Band in Up Trend Buy
   CrossDownCentralBandInDownTrendBuy = 5 //Cross Down Central Band in Down Trend Buy
  };
ENUM_BB BollingerBandsStrategies = SellAboveAndBuyBelow;//Bollinger Bands Strategies  // in
enum ENUM_MOMENT
  {
   CurrentPrice = 0,//Current Price
   BarClosePrice = 1//Bar Close Price
  };
ENUM_MOMENT MomentOfTheSignal = BarClosePrice; //Moment of the Signal      //in
int BollingerBandsPeriod = 20;//Bollinger Bands Period                     //in
double BollingerBandsDeviations = 2.0;//Bollinger Bands Deviations         //in
ENUM_APPLIED_PRICE BollingerBandsPrice = PRICE_CLOSE;//Bollinger Bands Price    // in
ENUM_TIMEFRAMES BollingerBandsTimeframe = PERIOD_CURRENT;//Bollinger Bands Timeframe   //in




//ZONA INDICATORI NASCOSTA INIZIO
 string MA_Settings = "------------------------------------------------------------------------------------------------------------------------------------------------------------";//MA Settings
 bool EnableMa = false;//Enable Ma
 int FastMaPeriod = 70;//Fast Ma Period
 int SlowMaPeriod = 100;//Slow Ma Period
 ENUM_MA_METHOD MaMethod = MODE_SMA;//Ma Method
 ENUM_APPLIED_PRICE MaPrice = PRICE_CLOSE;//Ma Price
 ENUM_TIMEFRAMES MaTimeframe = PERIOD_CURRENT;//Ma Timeframe


 string Stochastic_Settings = "------------------------------------------------------------------------------------------------------------------------------------------------------------";//Stochastic Settings
 bool EnableStochastic = false;//Enable Stochastic
 int K_Period = 5;//K Period
 int D_Period = 3;//D Period
 int Slowing = 3;//Slowing
 int UpperLevel = 80;//Upper Level
 int LowerLevel = 20;//Lower Level
 ENUM_MA_METHOD StochasticMethod = MODE_SMA;
 ENUM_STO_PRICE StochasticPrice = STO_LOWHIGH;
 bool StochasticReverseRules = false;//Stochastic Reverse Rules
 ENUM_TIMEFRAMES StochasticTimeframe = PERIOD_CURRENT;//Stochastic Timeframe
enum StochasticValue
  {
   Main = 0,
   Signal = 1
  };
 StochasticValue StochasticMode = Main;//Stochastic Mode


 string CCI_Settings = "------------------------------------------------------------------------------------------------------------------------------------------------------------";//CCI Settings
 bool EnableCCI = false;//Enable CCI
 int CCIPeriods = 14;//CCI Periods
 int CCIUpperLevel = 100;//CCI Upper Level
 int CCILowerLevel = -100;//CCI Lower Level
 bool CCIReverseRules = false;//CCI Reverse Rules
 ENUM_TIMEFRAMES CCITimeframe = PERIOD_CURRENT;//CCI Timeframe
 ENUM_APPLIED_PRICE CCIPrice = PRICE_TYPICAL;//CCI Price


 string Parabolic_Sar =  "------------------------------------------------------------------------------------------------------------------------------------------------------------";//Parabolic Sar
 bool EnableSar = false;//Enable Parabolic Sar
 double SarStep = 0.02;//Sar Step
 double SarMaxStep = 0.2;//Sar Max Step
 ENUM_TIMEFRAMES SarTimeframe = PERIOD_CURRENT;//Sar Timeframe
 bool SarReverseRules = false; //Sar Reverse Rules
 bool SarOnlyOnCrossing = false;//Parabolic Sar Only On Crossing


 string Adx_Settings =  "------------------------------------------------------------------------------------------------------------------------------------------------------------";//Adx Settings
 bool EnableAdx = false;//Enable Adx
 int AdxPeriod = 14;//Adx Period
 int AdxLimit = 30;//Adx Limit
 bool AdxReverseRules = false;//Adx Reverse Rules
 ENUM_MA_METHOD AdxMethod = MODE_SMA;//Adx Method
 ENUM_APPLIED_PRICE AdxPrice = PRICE_CLOSE;//Adx Price
 ENUM_TIMEFRAMES AdxTimeframe = PERIOD_CURRENT;//Adx Timeframe


 string ATR_Settings =  "------------------------------------------------------------------------------------------------------------------------------------------------------------";//Atr Settings
 bool EnableAtr = false;//Enable Atr
 int AtrPeriod = 9;//Atr Period
 int AtrMinPoint = 10;//Atr Min Point
 int AtrMaxPoint = 100;//Atr Max Point
 ENUM_TIMEFRAMES AtrTimeframe = PERIOD_CURRENT;//Atr Timeframe

//ZONA INDICATORI NASCOSTA FINE


string Separo2="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


string orari="TRADING HOUR ON BROKER SERVER TIME";//TRADING HOUR    // in
input bool EnableOrari = false;//Enable Time Filter                    
input int TradingStartHour = 0;//Trading Start Hour                      
input int TradingStartMinute = 0;//Trading Start Minute                  
input int TradingStopHour = 9;//Trading Stop Hour                         
input int TradingStopMinute = 0;//Trading Stop Minute                     
input bool CloseOutHour = false;//Close everything Out of hours           
int coefstart;
int coefstop;

string Separo3="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

string Days="TRADING DAYS";//TRADING DAYS      // in
bool Monday = true;                            // in
bool Tuesday = true;                           // in
bool Wednesday = true;                         // in
bool Thursday = true;                          // in
bool Friday = true;                            // in
bool Saturday = false;                         // in
bool Sunday = false;                           // in

string Separo4="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

string Direction="TRADING DIRECTIONS";//TRADING DIRECTIONS  // in
input bool AllowBuy = true;//Allow Buy                            
input bool AllowSell = true;//Allow Sell                          
input bool AllowBuyAndSellAtSameTime = true; //Allow Buy and Sell at the same time    
bool AllowOrdersFromOthersPairsAtSameTime = true; //Allow Order From Others Charts, At Same Time    // in
string ForTheParameterAbove = "(if it is false, will not open orders if there are Open Trades with a Magic numbers between +10 and -10, Compared to the current Magic Number)";//For This Parameter Above    // in 
string Separo5="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

string TradeSettings="STANDARD TRADING SETTINGS";//TRADE SETTINGS  // in
int MaxBuyOrders = 50;//Max Buy Orders                             // in
int MaxSellOrders = 50;//Max Sell Orders                            // in

bool OneTradeBar = true;//One Trade Bar (if true, open max one trade for bar)     // in
bool DoNotOpenOrdersIfThereIsClosedOrderOnBar = true; //Do Not Open Orders if there is Closed Order On Current Bar     // in
ENUM_TIMEFRAMES OrderTimeframe = PERIOD_CURRENT;//Order Timeframe   (related to One Trade Bar and DoNotOpenOrders...)   // in
int AlternationOpeningBars = 0;//Alternation Opening Bars   (related to One Trade Bar)

string Separo6="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

string GridSettings="GRID TRADING SETTINGS";//GRID SETTINGS  // in

bool EnableGrid = true; //Enable Grid                 // in
bool GridOrdersComplyMaxSpreadConditions = true; //Grid Orders Comply Max Spread Conditions    // in
bool GridOrdersComplyIndicatorsConditions = false; //Grid Orders Comply Indicators Conditions   // in
bool GridOrdersComplyHoursConditions = false; //Grid Orders Comply Hours Conditions         // in
bool GridOrdersComplyWeekDaysConditions = false; //Grid Orders Comply Week Days Conditions   // in


enum tipigestione
  {
   LotsSum = 0,//Lots Sum
   Martingale = 1,//Martingale
   AllLotsSum = 2,//All Lots Sum
   Fix = 3//Fix
  };

tipigestione GridManagement = LotsSum;//Grid Management  // in

double CoefficientGridManagement = 1;//Coefficient Grid Management  // in

int MinDistanzaPiramide = 50;//Min Distance (for the grid orders)    // in
double MinDistanceMultiplier = 1;   //Min Distance Multiplier (multiply Min Distance for each order) // in
bool OneTradeBarGrid = true;//One Trade Bar Grid (if true, open max one trade for bar)   // in

ENUM_TIMEFRAMES NewOpenPeriod = PERIOD_CURRENT;//Grid Order Timeframe (Related to One Trade Bar Grid)   // in

bool MinDistanceOnAtr = false;//Min Distance On Atr     // in
int DistanceAtrPeriod = 9;//Atr Period      // in
double AtrMultiplier = 2;//Atr Multiplier    // in
ENUM_TIMEFRAMES DistanceAtrTimeframe = PERIOD_CURRENT;//Atr Timeframe  // in



string Separo6_5="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


string IndicatorsCloseSettings = "CLOSURE ON INDICATOR";//CLOSURE ON INDICATOR   // in

bool EnableClosingOnBollingerBands = false;//Enable Closing on Bollinger Bands  // in
enum ENUM_CLOSEBB
  {
   CloseOnOppositeSignal = 0,//Close on Opposite Signal
   CloseOnTheCentralBand = 1//Close on Central Band
  };
ENUM_CLOSEBB ClosureType = CloseOnOppositeSignal;//Closure Type    // in
string Note55 = "'Close on Central Band' Work only with 'Sell Above and Buy Below' and 'Buy Above and Sell Below'";//Note:   // in
bool RespectSpreadAllowedWhileClosingOnIndicator = true; //Respect Spread Allowed While Closing On Indicator    // in



string Separo7="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


string TargetSettings = "GAIN/LOSS TARGET SETTINGS";//TARGET SETTINGS   // in
int TakeTarget = 50;//Take Target     // in
int TakeTargetBuy = 0;
int TakeTargetSell = 0;

bool DifferentTakeTargetForFirstOrder = false;   //Different Take Target For First Order   // in
int TakeTargetFirstOrder = 50; //Take Target First Order        // in

bool TakeTargetOnAtr = false;//Take Target On Atr
int TakeTargetAtrPeriod = 9;//Take Target Atr Period
double TakeTargetAtrMultiplier = 2;//Take Target Atr Multiplier
 ENUM_TIMEFRAMES TakeTargetAtrTimeframe = PERIOD_CURRENT;//Take Target Atr Timeframe



int StopTarget = 500;//Stop Target      // in

enum ENUM_STOPTARGET_TYPE
  {
   Default = 0,//Default
   FirstOrder = 1,//First Order
   Disabled = 2 //Disabled
  };

ENUM_STOPTARGET_TYPE StopTargetMode = Disabled;//Stop Target Mode     // in


bool OnlyEndOfBar = false;//Close Trades Only at End Of Bar      // in
datetime EndBar;


enum ClosureModality
  {
   AveragePoint = 0,          //Average Point
   AveragePointWeighted = 1,  //Average Point Weighted
   Breakeven = 2,             //Breakeven
   FixPoint = 3,              //Fix Point
   //LastDD = 7                //LastDD
  };


 ClosureModality CloseMode = AveragePointWeighted;//Close Mode   // in



string MonetaryLoss = "Monetary Loss Settings";//Monetary Loss  // in
input bool MonetaryStopLoss = false;//Enable Monetary Stop Loss     
input bool EveryMicrolot = false;//If true, Multiply Monetary Stop Loss Amount*Start Lot size*100   
input bool StopTradingWhenHit = false;//Stop EA after Monetary loss              
input int MaximumMonetaryLoss = 3000;//Monetary Stop Loss Amount (expressed in the account currency)   

string PercentageLoss = "Percentage Loss Settings";//Percentage Loss // in
input bool CloseInPercentageLoss = false;//Enable Close In Percentage Loss   
input bool StopTradingAfterPercentageLoss = false;//Stop EA After Percentage Loss  
input int LossPercentage = 30;//Loss Amount in Percentage    


string Separo8="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


string Average_Trailing_Stop = "--------------------------";//Average Virtual Trailing Stop    // in
bool EnableAverageTrailingStop = false;//Enable Average Trailing Stop    // in
bool   AverageOnlyInProfit = true;//Only In Profit      //in
int AverageBrokerCommission = 7;//Broker Commission    // in
int    AverageTrailingStop  =50;  //Average Trailing Stop Value   // in
int    AverageTrailingStep  =10;   //Average Trailing Step Value   // in


string Separo9="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

string CloseSettings="CLOSE TRADING SETTINGS";//CLOSE TRADE SETTINGS   // in


bool FreezesAllFriday = false;//Freezes All Friday // in
int FreezesHour = 18;//Freezes Hour     // in
bool CloseFriday = false;//Close Friday Night   // in
int CloseFridayHour = 18;//Close Friday Hour    // in
bool ForcedCloseFriday = false;//Forced Close Friday Night  //in
int ForcedCloseFridayHour = 23;//Forced Close Friday Hour     // in






string Separo10="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
string GraphicSettings = "GRAPHIC SETTINGS"; //GRAPHIC SETTINGS // in

string CustomComment = "Kia64";//Custom Comment (each order will show this comment in the trades) //in

bool ShowPanel = true; //Show Panel // in
bool ShowButton = false;//Show Button  // in
bool CustomChart = true;//Custom Chart   // in
 int SpreadValueForAlert = 10; //Spread Value for Alert
 int LatencyValueForAlert = 30000;//Latency Value for Alert in Microseconds (1000 = 1 Milliseconds)
bool SiamoInTestOscuro = false;

string Separo11="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

string Optimization = "OPTIMIZATION SETTINGS";//OPTIMIZATION   // in
int MinimumTrades = 100;//Minimum Trades for "OnTester" result  // in


bool AllowNetting = false;//Allow Trading on Netting Account  // in


//ADATTAMENTI MT5

double Bid_ = 0;	
double Ask_ = 0;	
ENUM_ORDER_TYPE OP_BUY = ORDER_TYPE_BUY;	
ENUM_ORDER_TYPE OP_SELL = ORDER_TYPE_SELL;	




int OnInit()
  {
//---
//==================================coder robo ===============================
 string broker_name = AccountInfoString(ACCOUNT_SERVER);

    if (StringFind(broker_name,AllowedBroker) < 0)
    {
        Print("This Expert only works on broker servers containing: ", AllowedBroker);
        ExpertRemove();
        return(INIT_FAILED); 
    }

    Print("Expert is activated. Brokerage is allowed : ", broker_name);
    
    
    
 if (CheckExpiration())
   {
      Print("تاریخ انقضای اکسپرت به پایان رسیده است!");
      ExpertRemove(); // اکسپرت را غیرفعال می‌کند
      return INIT_FAILED; // خطا در شروع
   }
   
  //  GetTradeInfo();
    if(user_password != CORRECT_PASSWORD)
       {
          Print("رمز عبور اشتباه است! لطفاً رمز عبور صحیح را وارد کنید.");
          ExpertRemove();
          return INIT_FAILED;
       }
     Print(" password is corect ");
//=================================================================================  
m_trade.SetExpertMagicNumber(MagicNumber);
// Use the filling policy reported by the active chart symbol for CTrade operations.
m_trade.SetTypeFillingBySymbol(_Symbol);

Bid_ = Bid();
Ask_ = Ask();
KiaXAMLogSymbolSpecs();







CommentoInit();



if(CustomChart)
{
ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);
ChartSetInteger(0,CHART_COLOR_FOREGROUND,clrWhiteSmoke);
ChartSetInteger(0,CHART_SHOW_GRID,0);
ChartSetInteger(0,CHART_COLOR_GRID,clrWhiteSmoke);
ChartSetInteger(0,CHART_COLOR_CHART_UP,clrAqua);
ChartSetInteger(0,CHART_COLOR_CHART_DOWN,clrDarkOrange);
// Hollow bearish candle body, matching the chart background.
ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,clrBlack);
ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,clrBlack);
ChartSetInteger(0,CHART_SHOW_ASK_LINE,1);
ChartSetInteger(0,CHART_COLOR_BID,clrAqua);
ChartSetInteger(0,CHART_COLOR_ASK,clrRed);
ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
}
LottoDaTradare = Lots;

//Orari
coefstart = Hour_trade_Calculator(TradingStartHour,TradingStartMinute);
coefstop = Hour_trade_Calculator(TradingStopHour,TradingStopMinute);


//Take Target
TakeTargetBuy = TakeTarget;
TakeTargetSell = TakeTarget;



//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert onchart event function                                |
//+------------------------------------------------------------------+




void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {



   if(sparam== "ButtonCloseAll")
      {
      EliminaOrdiniFifo(MagicNumber); 
      ObjectSetInteger(0,"ButtonCloseAll",OBJPROP_STATE,false);    
      }

   if(sparam== "ButtonCloseBuy")
      {
      EliminaOrdiniFifo(MagicNumber,OP_BUY); 
      ObjectSetInteger(0,"ButtonCloseBuy",OBJPROP_STATE,false);    
      }
      
   if(sparam== "ButtonCloseSell")
      {
      EliminaOrdiniFifo(MagicNumber,OP_SELL); 
      ObjectSetInteger(0,"ButtonCloseSell",OBJPROP_STATE,false);    
      }
  }


















//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
ObjectsDeleteAll(0,-1,OBJ_BUTTON);
ObjectsDeleteAll(0,-1,OBJ_LABEL);
ObjectsDeleteAll(0,-1,OBJ_EDIT);
ObjectsDeleteAll(0,-1,OBJ_RECTANGLE_LABEL);







  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   Kia64UpdateSessionObserver();


if ( !AllowNetting &&  IsTesting() && AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING && (StringFind(_Symbol,"XAUUSD") > -1 || StringFind(_Symbol,"EURUSD") > -1) &&  StringFind(AccountInfoString(ACCOUNT_SERVER),"eta") > -1 )
{
Comment("Your account is netting, if you want to continue anyway Enable the 'Allow Netting' setting");
return ;
}


Bid_ = Bid();
Ask_ = Ask();


if (MoneyManagement)
LottoDaTradare = MoneySize();
else
LottoDaTradare=Lots;

Commento();

if ( FreezesAllFriday && Hour() > FreezesHour && DayOfWeek() == 5 )
{
return;
}




int ordinibuy = (int) OrdiniAperti(MagicNumber,OP_BUY);
int ordinisell = (int) OrdiniAperti(MagicNumber,OP_SELL);

      if ( DifferentTakeTargetForFirstOrder )
      {
            if ( ordinibuy <= 1 )
            {
            TakeTargetBuy = TakeTargetFirstOrder;
            }
            else
            if ( ordinibuy > 1 )
            {
            TakeTargetBuy = TakeTarget;
            }
            
            if ( ordinisell <= 1 )
            {
            TakeTargetSell = TakeTargetFirstOrder;
            }
            else
            if ( ordinisell > 1 )
            {
            TakeTargetSell = TakeTarget;
            }
      }


bool ordiniapertibuy = ordinibuy < 1;
bool ordiniapertisell = ordinisell < 1;
if ( ordiniapertibuy )
{
HLineMove(0,"TargetLineBuy",EMPTY_VALUE);
HLineMove(0,"StopLineBuy",EMPTY_VALUE);
}
if ( ordiniapertisell )
{
HLineMove(0,"TargetLineSell",EMPTY_VALUE);
HLineMove(0,"StopLineSell",EMPTY_VALUE);
}
if (!OnlyEndOfBar || (EndBar < iTime(_Symbol,OrderTimeframe,0)) )
{

      if ( TakeTargetOnAtr )
      {
      TakeTargetBuy = NormalizeDouble(TakeTargetAtrMultiplier*iatr(_Symbol,TakeTargetAtrTimeframe,TakeTargetAtrPeriod,1),_Digits);
      TakeTargetSell = NormalizeDouble(TakeTargetAtrMultiplier*iatr(_Symbol,TakeTargetAtrTimeframe,TakeTargetAtrPeriod,1),_Digits);
      }
      
      
      double prezzomediobuy = 0;
      double prezzomediosell = 0;
      if ( CloseMode == AveragePoint )
      PrezzoMedio(prezzomediobuy,prezzomediosell);
      else if ( CloseMode == AveragePointWeighted )
      PrezzoMedioPonderato(prezzomediobuy,prezzomediosell);
      else if ( CloseMode == FixPoint )
      PuntiFissiMonetari();
      else if ( CloseMode == Breakeven )
      {
      breakeven(ordinibuy,ordinisell);
      if ( ordinibuy == 1 || ordinisell == 1 )
         {
         PrezzoMedioPonderato(prezzomediobuy,prezzomediosell);
         }
      }
      /*else if ( CloseMode == LastDD )
      UltimoDrawdown();*/

      
      if ( prezzomediobuy > 0)
      {
      
         if ( prezzomediobuy+(TakeTargetBuy*_Point) < Bid_  )
         {
          KiaXAMLogCloseDiagnostic("AVERAGE_WEIGHTED_TAKE_PROFIT","BUY",prezzomediobuy,prezzomediobuy+(TakeTargetBuy*_Point));
          EliminaOrdiniFifo(MagicNumber,OP_BUY);
          }
      
         if ( StopTargetMode == Default &&  prezzomediobuy-(StopTarget*_Point) > Bid_  )
         EliminaOrdiniFifo(MagicNumber,OP_BUY);
         
        
         if (  StopTargetMode == FirstOrder && PrezzoPrimoOrdineBuy()-(StopTarget*_Point) > Bid_ )
         EliminaOrdiniFifo(MagicNumber,OP_BUY);
      
HLineMove(0,"TargetLineBuy",prezzomediobuy+(TakeTargetBuy*_Point));
if ( StopTargetMode == Default )
HLineMove(0,"StopLineBuy",prezzomediobuy-(StopTarget*_Point));
if ( StopTargetMode == FirstOrder )
HLineMove(0,"StopLineBuy",PrezzoPrimoOrdineBuy()-(StopTarget*_Point));

      }
      if ( prezzomediosell > 0)
      {
      
         if (  prezzomediosell-(TakeTargetSell*_Point) > Ask_  )
         {
          KiaXAMLogCloseDiagnostic("AVERAGE_WEIGHTED_TAKE_PROFIT","SELL",prezzomediosell,prezzomediosell-(TakeTargetSell*_Point));
          EliminaOrdiniFifo(MagicNumber,OP_SELL);
          }
      
         if ( StopTargetMode == Default && prezzomediosell+(StopTarget*_Point) < Ask_  )
         EliminaOrdiniFifo(MagicNumber,OP_SELL);
         
        
         if ( StopTargetMode == FirstOrder && PrezzoPrimoOrdineSell()+(StopTarget*_Point) < Ask_  )
         EliminaOrdiniFifo(MagicNumber,OP_SELL);
         
HLineMove(0,"TargetLineSell",prezzomediosell-(TakeTargetSell*_Point));
if ( StopTargetMode == Default )
HLineMove(0,"StopLineSell",prezzomediosell+(StopTarget*_Point));
if ( StopTargetMode == FirstOrder )
HLineMove(0,"StopLineSell",PrezzoPrimoOrdineSell()+(StopTarget*_Point));
      }
      if (MonetaryStopLoss)
      {
               double profit = CalcolaProfitto(MagicNumber);
               //CHIUSURA ORDINI PIRAMIDALI IN PERDITA
               if (LottoDaTradare<0.01)
               LottoDaTradare = 0.01;
               if (profit < ( (EveryMicrolot)? (MaximumMonetaryLoss*(LottoDaTradare*100)) :  MaximumMonetaryLoss)*-1 )
               {
               KiaXAMLogCloseDiagnostic("MONETARY_STOP_LOSS","ALL",0.0,0.0);
                EliminaOrdiniFifo(MagicNumber);
               if (StopTradingWhenHit)
               {
               Comment("Stop Trading When Hit, I removed the Expert, to continue insert it again");
               ExpertRemove();
               }               
               }
                  
               
      }



EndBar = TimeCurrent();
}




if (CloseInPercentageLoss )
{
double profit = CalcolaProfitto(MagicNumber);

   if (  LossPercentage < ((-1*profit)/AccountBalance())*100 )
   {
      KiaXAMLogCloseDiagnostic("PERCENTAGE_LOSS_PROTECTION","ALL",0.0,0.0);
       EliminaOrdiniFifo(MagicNumber);
      if ( StopTradingAfterPercentageLoss )
      {
         Comment("Stop Trading After Percentage Loss, I removed the Expert, to continue insert it again");
         ExpertRemove();
      }
   }
}





//APERTURA ORDINI PIRAMIDALI
if (ordinibuy < MaxBuyOrders && OrdineInPerdita(OP_BUY,ordinibuy))
OrdinoUn(OP_BUY);
if (ordinisell < MaxSellOrders && OrdineInPerdita(OP_SELL,ordinisell))
OrdinoUn(OP_SELL);



if ( EnableClosingOnBollingerBands && !(ordiniapertibuy && ordiniapertisell) )
CloseOnIndicatorSignal();


int Oggi = DayOfWeek();
if (ForcedCloseFriday && Oggi == 5 && Hour()/*-(utc-2)*/>ForcedCloseFridayHour )
{
EliminaOrdiniFifo(MagicNumber);
return;
} 

if (CloseFriday && Oggi == 5 && Hour()/*-(utc-2)*/>CloseFridayHour )
{
if (CalcolaProfitto(MagicNumber) > 0 )
EliminaOrdiniFifo(MagicNumber);
return;
} 



bool KiaXAMSpreadOK = (MaxSpread*_Point >= Ask_-Bid_) && KiaXAMSpreadAllowed();
if (MaxSpread*_Point < Ask_-Bid_)
   Kia64TradeDiagnostic("Entry blocked by legacy points spread limit; current_points="+DoubleToString((Ask_-Bid_)/_Point,1)+"; maximum_points="+DoubleToString(MaxSpread,1));


if ( EnableAverageTrailingStop )
AverageTrailingStopFunction();



bool OrarioAbilitato = true;
if (EnableOrari)
OrarioAbilitato = Hour_trade_allowed(coefstart,coefstop);
if (CloseOutHour && EnableOrari && !OrarioAbilitato)
{
EliminaOrdiniFifo(MagicNumber);
}
if ( !OrarioAbilitato )
{
   Kia64TradeDiagnostic("Entry blocked: trading-hours filter.");
   return;
}



bool AtrAbilitato = true;
if ( EnableAtr )
{
double Atr = iatr(_Symbol,AtrTimeframe,AtrPeriod,1);
AtrAbilitato = Atr > AtrMinPoint*_Point && Atr < AtrMaxPoint*_Point;
}
if (!AtrAbilitato)
{
   Kia64TradeDiagnostic("Entry blocked: ATR filter.");
   return;
}




bool ExtraIndicatorsBuy = extraindicatorsbuy();
bool ExtraIndicatorsSell = extraindicatorssell();




if (GridManagement == AllLotsSum)
LottoDaTradare = NormalizeDouble( LottoDaTradare+ (LottoDaTradare *OrdiniAperti(MagicNumber)*CoefficientGridManagement),2);//GestioneOrdini( LottoDaTradare, OP_BUY);



bool Kia64BuyEntryAllowed = KiaXAMSpreadOK && ordiniapertibuy && ExtraIndicatorsBuy && !OrdiniApertiSuBarra(MagicNumber,AlternationOpeningBars) && !ordiniapertichiusisubarra(MagicNumber,AlternationOpeningBars) && !ordinichiusisubarra(MagicNumber,AlternationOpeningBars,"OP BUY") && OrdiniApertiGlobale() && FifoModality(OP_BUY,ordinibuy,ordinisell) && DayCheck(Oggi) && AllowBuy;
if(Kia64BuyEntryAllowed) Ordine(OP_BUY,LottoDaTradare,Ask_,0,0,MagicNumber,0);
else Kia64TradeDiagnostic("BUY not sent: one or more original entry conditions are false; open_buy="+string(ordiniapertibuy)+"; indicators="+string(ExtraIndicatorsBuy)+"; allowed="+string(AllowBuy));

bool Kia64SellEntryAllowed = KiaXAMSpreadOK && ordiniapertisell && ExtraIndicatorsSell && !OrdiniApertiSuBarra(MagicNumber,AlternationOpeningBars) && !ordiniapertichiusisubarra(MagicNumber,AlternationOpeningBars) && !ordinichiusisubarra(MagicNumber,AlternationOpeningBars, "OP SELL") && OrdiniApertiGlobale() && FifoModality(OP_SELL,ordinibuy,ordinisell) && DayCheck(Oggi) && AllowSell;
if(Kia64SellEntryAllowed) Ordine(OP_SELL,LottoDaTradare,Bid_,0,0,MagicNumber,0);
else Kia64TradeDiagnostic("SELL not sent: one or more original entry conditions are false; open_sell="+string(ordiniapertisell)+"; indicators="+string(ExtraIndicatorsSell)+"; allowed="+string(AllowSell));


//Resetto Lotto
LottoDaTradare=Lots;

//Fine on tick
  }




double OrdiniAperti(int Magic)
{

int NumeroOrdini = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
if (OrderMagicNumber() == Magic && OrderSymbol() == Symbol())
NumeroOrdini++;
}
}
return NumeroOrdini;
}



bool OrdiniApertiGlobale()
{

if ( AllowOrdersFromOthersPairsAtSameTime )
return true;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
         if ( OrderSymbol() == _Symbol && OrderMagicNumber() == MagicNumber )
         continue;
         if (OrderMagicNumber() < MagicNumber+10 && OrderMagicNumber() > MagicNumber-10 )
         return false;
      }
   }
return true;
}





bool ordiniapertichiusisubarra (int Magic,int AlternanzaBarre = 0)
{

if(!OneTradeBar)
return false;

if ( !HistorySelect(0,TimeCurrent()) )
return true;
int total = HistoryDealsTotal();
for ( int i = total-1 ; i >= total-100 ; i--)
{
if(HistoryDealGetTicket(i)<=0)
continue; //interrompo l'esecuzione del ciclo e lo continuo col valore del contatore successivo
ulong id = HistoryDealGetTicket(i);
if (HistoryDealGetString(id,DEAL_SYMBOL) == Symbol () && HistoryDealGetInteger(id,DEAL_MAGIC) == Magic && HistoryDealGetInteger(id,DEAL_TIME) >= iTime(Symbol(),OrderTimeframe,AlternanzaBarre) && HistoryDealGetInteger(id,DEAL_ENTRY) == 0 )
{
return true;
break;   //esco dal ciclo for
}
else if ( HistoryDealGetInteger(id,DEAL_TIME) < iTime(Symbol(),OrderTimeframe,AlternanzaBarre))
{
return false;
}
}
return (false);
}



double OrdiniApertiSuBarra(int Magic, int AlternanzaBarre = 0)
{

if (!OneTradeBar)
return false; 

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
if (OrderMagicNumber() == Magic && OrderSymbol() == Symbol() && OrderOpenTime () >= iTime(Symbol(),OrderTimeframe,AlternanzaBarre))
return true;
}
}
return false;
}




bool ordinichiusisubarra(int Magic, int AlternanzaBarre = 0,string IngressoType = "") //ordinichiusisubarra
{

if(!DoNotOpenOrdersIfThereIsClosedOrderOnBar)
return false;

if ( !HistorySelect(0,TimeCurrent()) )
return true;
int total = HistoryDealsTotal();
for ( int i = total-1 ; i >= total-100 ; i--)
{
if(HistoryDealGetTicket(i)<=0)
continue; //interrompo l'esecuzione del ciclo e lo continuo col valore del contatore successivo
ulong id = HistoryDealGetTicket(i);

if (HistoryDealGetString(id,DEAL_SYMBOL) == Symbol () && HistoryDealGetInteger(id,DEAL_MAGIC) == Magic && HistoryDealGetInteger(id,DEAL_TIME) >= iTime(Symbol(),OrderTimeframe,AlternanzaBarre) && HistoryDealGetInteger(id,DEAL_ENTRY) == 1 )
{
return true;
break;   //esco dal ciclo for
}
else if (HistoryDealGetInteger(id,DEAL_TIME)  < iTime(Symbol(),OrderTimeframe,AlternanzaBarre))
{
return false;
}
}
return (false);
}






bool ordiniapertichiusisubarragrid (int Magic, int cmd)
{

if(!OneTradeBarGrid)
return false;

if ( !HistorySelect(0,TimeCurrent()) )
return true;
int total = HistoryDealsTotal();
for ( int i = total-1 ; i >= total-100 ; i--)
{
if(HistoryDealGetTicket(i)<=0)
continue; //interrompo l'esecuzione del ciclo e lo continuo col valore del contatore successivo
ulong id = HistoryDealGetTicket(i);
if (HistoryDealGetString(id,DEAL_SYMBOL) == Symbol () && HistoryDealGetInteger(id,DEAL_MAGIC) == Magic && HistoryDealGetInteger(id,DEAL_TYPE) == cmd && HistoryDealGetInteger(id,DEAL_TIME)  >= iTime(Symbol(),NewOpenPeriod,0)&& HistoryDealGetInteger(id,DEAL_ENTRY) == 0 )
{
return true;
break;   //esco dal ciclo for
}
else if (HistoryDealGetInteger(id,DEAL_TIME) < iTime(Symbol(),NewOpenPeriod,0))
{
return false;
}
}
return (false);
}


double OrdiniApertiSuBarraGrid(int Magic, int cmd)
{

if (!OneTradeBarGrid)
return false; 

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
if (OrderMagicNumber() == Magic && OrderSymbol() == Symbol() && OrderType() == cmd && OrderOpenTime () >= iTime(Symbol(),NewOpenPeriod,0))
return true;
}
}
return false;
}



//////////////////////////////////////////////SEZIONE CHIUSURA ORDINI///////////////////////////////////////

void EliminaOrdini(int Magic,int cmd)
{

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
if(OrderMagicNumber()== Magic && OrderSymbol() == Symbol())
{
if (MathAbs(OrderType()-cmd)<0.1)
Elimina(OrderType());
}
}
}
}




void EliminaOrdini(int Magic)
{



   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
if (OrderMagicNumber() == Magic && OrderSymbol() == Symbol())
Elimina(OrderType());
}
}
}






void Elimina(int cmd)
{

if ( cmd < 1.5)
{
if (!OrderClose(OrderTicket(),OrderLots(),0,Black))
{
for(int i=0;i<5;i++)
  {
   Sleep(5000);
   if (OrderClose(OrderTicket(),OrderLots(),0,Black))
   return;
  }

}
}
}










void EliminaOrdiniFifo(int Magic,int cmd)
{
   KiaXAMLogCloseDiagnostic("GENERIC_CLOSE_FUNCTION","SIDE_"+IntegerToString(cmd),0.0,0.0);
int Ticket[];
ArrayResize(Ticket,PositionsTotal());

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
         if(OrderMagicNumber()== Magic && OrderSymbol() == Symbol())
         {
            if (MathAbs(OrderType()-cmd)<0.1)
            Ticket[i] = OrderTicket();
         }
      }
   }



   for(int i = 0; i < ArraySize(Ticket); i++)
   {
            if(PositionGetTicket(Ticket[i]))
            EliminaFifo(Ticket[i],OrderLots(),0,clrBlack,OrderType());
   }


//Elimina(OrderType());
EliminaOrdini(Magic,cmd);
}



void EliminaOrdiniFifo(int Magic)
{
   KiaXAMLogCloseDiagnostic("GENERIC_CLOSE_FUNCTION","ALL",0.0,0.0);
int Ticket[];
ArrayResize(Ticket,PositionsTotal());

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
         if(OrderMagicNumber()== Magic && OrderSymbol() == Symbol())
         {
            Ticket[i] = OrderTicket();
         }
      }
   }



   for(int i = 0; i < ArraySize(Ticket); i++)
   {
            if(PositionGetTicket(Ticket[i]))
            EliminaFifo(Ticket[i],OrderLots(),0,clrBlack,OrderType());
   }


//Elimina(OrderType());

EliminaOrdini(Magic);
}





void EliminaFifo(int Ticket,double Orderlots,int slippage,color colore,int cmd)
{

if ( cmd < 1.5)
{
if (!OrderClose(Ticket,Orderlots,slippage,colore))
{
for(int i=0;i<5;i++)
  {
   Sleep(5000);
   if (OrderClose(Ticket,Orderlots,slippage,colore))
   return;
  }
}
}
}




bool OrderClose(ulong ticketordine, double lottidachiudere, int slippage,color colore)
{





return m_trade.PositionClose(ticketordine);


MqlTradeRequest Trade;
    ZeroMemory(Trade);
MqlTradeResult Risultati;
    ZeroMemory(Risultati);


   if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
     {
      //--- prepare request for close BUY position
      Trade.type =ORDER_TYPE_SELL;
      Trade.price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
     }
   else
     {
      //--- prepare request for close SELL position
      Trade.type =ORDER_TYPE_BUY;
      Trade.price=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
     }
//--- setting request
   Trade.action   =TRADE_ACTION_DEAL;
   Trade.position =ticketordine;
   Trade.symbol   =_Symbol;
   Trade.volume   =PositionGetDouble(POSITION_VOLUME);
   Trade.magic    =MagicNumber;
   Trade.deviation=10;
          Trade.type_filling = ORDER_FILLING_IOC;
//--- close position
bool invio= OrderSend(Trade,Risultati);



if (Risultati.retcode == 10030 )
{
Sleep(1000);
   Trade.type_filling = ORDER_FILLING_RETURN;
   ZeroMemory(Risultati);

   bool ritentoprimo = OrderSend(Trade,Risultati);

      if (Risultati.retcode == 10030 )
      {
      Sleep(1000);
      Trade.type_filling = ORDER_FILLING_FOK;
      ZeroMemory(Risultati);      
      bool ritentosecondo = OrderSend(Trade,Risultati); 
      }
}




/*



Gestore.PositionClose(ticketordine);
*/
if (Risultati.deal > 1)
return true;
else
return false;

}







//////////////////////////////////////////////FINE SEZIONE CHIUSURA ORDINI///////////////////////////////////////











void PrezzoMedio(double &PrezzoMedioBuy,double &PrezzoMedioSell)
{
double Prezzobuy = 0;
int contatorebuy = 0;
double Prezzosell = 0;
int contatoresell = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
if (OrderMagicNumber() == MagicNumber && OrderSymbol() == _Symbol )
   {
   int tipo = OrderType();
      if ( tipo == OP_BUY)
      {
      Prezzobuy += OrderOpenPrice();
      contatorebuy++;
      }
      else if ( tipo == OP_SELL)
      {
      Prezzosell += OrderOpenPrice();
      contatoresell++;
      }
      
   }
}
}
if ( contatorebuy > 0)
PrezzoMedioBuy = Prezzobuy/contatorebuy;
if ( contatoresell > 0)
PrezzoMedioSell = Prezzosell/contatoresell;
}




void PrezzoMedioPonderato(double &PrezzoMedioBuy,double &PrezzoMedioSell)
{
double Prezzobuy = 0;
double LottoBuy = 0;
double Prezzosell = 0;
double LottoSell = 0;

double SwapBuy = SymbolInfoDouble(_Symbol,SYMBOL_SWAP_LONG);
double SwapSell =  SymbolInfoDouble(_Symbol,SYMBOL_SWAP_SHORT);

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
if (OrderMagicNumber() == MagicNumber && OrderSymbol() == _Symbol )
   {
   int tipo = OrderType();
   double orderlots = OrderLots();
      if ( tipo == OP_BUY)
      {
      Prezzobuy += PuntoDiIngressoBuy(SwapBuy)*orderlots;
      LottoBuy += orderlots;
      }
      else if ( tipo == OP_SELL)
      {
      Prezzosell += PuntoDiIngressoSell(SwapSell)*orderlots;
      LottoSell += orderlots;
      }
      
   }
}
}
if ( LottoBuy > 0)
PrezzoMedioBuy = Prezzobuy/LottoBuy;
if ( LottoSell > 0)
PrezzoMedioSell = Prezzosell/LottoSell;
}

double PuntoDiIngressoBuy(double SwapBuy)
{

if ( SymbolInfoInteger(_Symbol,SYMBOL_SWAP_MODE)  >= 3 )
return OrderOpenPrice();


int orarioapertura = (int)OrderOpenTime();
int orarioattuale = (int) TimeCurrent();
double differenza = orarioattuale-orarioapertura;
double giorni = 0;

if (differenza > 0)
{
differenza = (differenza/5)*7;
giorni = differenza/86400;
}
else
giorni = 0;

double swappoint = giorni * SwapBuy;

return OrderOpenPrice()-swappoint*_Point;
}

double PuntoDiIngressoSell(double SwapSell)
{


if ( SymbolInfoInteger(_Symbol,SYMBOL_SWAP_MODE)  >= 3 )
return OrderOpenPrice();


int orarioapertura = (int)OrderOpenTime();
int orarioattuale = (int)TimeCurrent();
double differenza = orarioattuale-orarioapertura;
double giorni = 0;

if (differenza > 0)
{
differenza = (differenza/5)*7;
giorni = differenza/86400;
}
else
giorni = 0;

double swappoint = giorni * SwapSell;
return OrderOpenPrice()+swappoint*_Point;
}





void breakeven(int ordinibuy, int ordinisell)
{


double profittobuy = 0;
double profittosell = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
if (OrderMagicNumber() == MagicNumber && OrderSymbol() == _Symbol )
   {
   int tipo = OrderType();
   double orderlots = OrderLots();

            if ( tipo == OP_BUY)
            {
            profittobuy += OrderCommission()+OrderSwap()+OrderProfit();
            }
            else if ( tipo == OP_SELL)
            {
            profittosell += OrderCommission()+OrderSwap()+OrderProfit();
            }
   }
}
}

if ( ordinibuy > 1 && profittobuy > 0)
EliminaOrdiniFifo(MagicNumber,OP_BUY);
if ( ordinisell > 1 && profittosell > 0)
EliminaOrdiniFifo(MagicNumber,OP_SELL);


}







/*
void breakeven(int ordinibuy, int ordinisell)
{
double Commissioni = 0;
double PrezzoMedioBuy = 0;
double PrezzoMedioSell = 0;
double Prezzobuy = 0;
double LottoBuy = 0;
double Prezzosell = 0;
double LottoSell = 0;

for(int i = OrdersTotal()-1; i >= 0; i--)
{
if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
{
if (OrderMagicNumber() == MagicNumber && OrderSymbol() == _Symbol )
   {
   int tipo = OrderType();
   double orderlots = OrderLots();

            if ( tipo == OP_BUY)
            {
            Prezzobuy += OrderOpenPrice()*orderlots;
            LottoBuy += orderlots;
            }
            else if ( tipo == OP_SELL)
            {
            Prezzosell += OrderOpenPrice()*orderlots;
            LottoSell += orderlots;
            }
   if (orderlots > 0)
   Commissioni = OrderCommission()/orderlots ;
   }
}
}

double NewTakeTargetBuy = 0;
double NewStopTargetBuy = 0;
double NewTakeTargetSell = 0;
double NewStopTargetSell = 0;


if ( ordinibuy == 1 )
{
      if (   LottoBuy > 0)
      {
      PrezzoMedioBuy = (Prezzobuy/LottoBuy);
      NewTakeTargetBuy = TakeTarget/(LottoBuy*100);
      NewStopTargetBuy = StopTarget/(LottoBuy*100);
      }
}
else
{
      if ( LottoBuy > 0 )
      {
      PrezzoMedioBuy = (Prezzobuy/LottoBuy);
      NewTakeTargetBuy = 0;
      NewStopTargetBuy = StopTarget/(LottoBuy*100);
      Print( PrezzoMedioBuy," = ( ",Prezzobuy," / ",LottoBuy,")");
      }
}

if ( ordinisell == 1 )
{
      if ( LottoSell > 0)
      {
      PrezzoMedioSell = (Prezzosell/LottoSell);
      NewTakeTargetSell = TakeTarget/(LottoSell*100);
      NewStopTargetSell = StopTarget/(LottoSell*100);
      }
}
else
{
      if ( LottoSell > 0)
      {
      PrezzoMedioSell = (Prezzosell/LottoSell);
      NewTakeTargetSell = 0;
      NewStopTargetSell = StopTarget/(LottoSell*100);
      }
}



NewTakeTargetBuy += Commissioni;
NewTakeTargetSell += Commissioni;
NewStopTargetBuy += Commissioni;
NewStopTargetSell += Commissioni;


if ( LottoBuy > 0)
{
Print ( PrezzoMedioBuy," +( ",NewTakeTargetBuy," * ",_Point," ) < ",Bid);
   if ( PrezzoMedioBuy+(NewTakeTargetBuy*_Point) < Bid  )
   {
   EliminaOrdiniFifo(MagicNumber,OP_BUY);
   Print("Sono Entrato In Take Profit");
   }

   if ( PrezzoMedioBuy-(NewStopTargetBuy*_Point) > Bid  )
   EliminaOrdiniFifo(MagicNumber,OP_BUY);


}
if ( LottoSell > 0)
{

   if (  PrezzoMedioSell-(NewTakeTargetSell*_Point) > Ask  )
   EliminaOrdiniFifo(MagicNumber,OP_SELL);

   if ( PrezzoMedioSell+(NewStopTargetSell*_Point) < Ask  )
   EliminaOrdiniFifo(MagicNumber,OP_SELL);

}

}
*/




double OrdiniAperti(int Magic,int cmd)
{
int NumeroOrdini = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
if(OrderMagicNumber()== Magic && OrderSymbol() == Symbol())
{
if (MathAbs(OrderType()-cmd)<0.1)
NumeroOrdini++;
}
}
}
return NumeroOrdini;
}



int Ordine(int cmd, double lotti, double prezzo, double stoploss, double takeprofit, int Magic, datetime expiration)
{
int ticket=0;

if (!CheckVolumeValue(lotti))
return -1;


if ( !CheckMoneyForTrade(_Symbol,lotti, cmd))
return -1;

if ( !IsNewOrderAllowed())
return -1;


if(cmd == OP_BUY )
ticket = InvioOrdine(Symbol(),cmd,lotti,prezzo,0,0,CustomComment,Magic,expiration,Blue);
else
ticket = InvioOrdine(Symbol(),cmd,lotti,prezzo,0,0,CustomComment,Magic,expiration,Red);


return ticket;
}





//==================================================================
// KIA XAM: live symbol specification and spread checks
// This filter affects NEW entries only. Position management/closing continues.
//==================================================================
#define KIAXAM_SYMBOL_INFO_FILE "KiaXAM_SymbolInfo.csv"
#define KIAXAM_CLOSE_DIAG_FILE "KiaXAM_CloseDiagnostics.csv"
datetime KiaXAMLastSpreadBlockLog = 0;

// Diagnostic only: records close-trigger context without changing trade decisions.
void KiaXAMLogCloseDiagnostic(string reason, string side, double referencePrice, double targetPrice)
{
   MqlTick tick;
   bool hasTick = SymbolInfoTick(_Symbol,tick);
   double bid = hasTick ? tick.bid : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = hasTick ? tick.ask : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double spread = (bid > 0.0 && ask >= bid) ? ask-bid : 0.0;
   double floatingProfit = 0.0, totalLots = 0.0;
   int count = 0;
   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      floatingProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      totalLots += PositionGetDouble(POSITION_VOLUME);
      count++;
   }
   int h=FileOpen(KIAXAM_CLOSE_DIAG_FILE,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(h==INVALID_HANDLE)
   {
      Kia64TradeDiagnostic("KiaXAM close diagnostic file open failed; error="+IntegerToString(GetLastError()));
      return;
   }
   if(FileSize(h)==0)
      FileWrite(h,"timestamp","symbol","timeframe","reason","side","reference_price","target_price","bid","ask","spread_price","target_gap_price","position_count","total_lots","floating_profit","account_currency","only_end_of_bar","close_mode","take_target_points");
   FileSeek(h,0,SEEK_END);
   FileWrite(h,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),_Symbol,EnumToString((ENUM_TIMEFRAMES)_Period),reason,side,
      DoubleToString(referencePrice,_Digits),DoubleToString(targetPrice,_Digits),DoubleToString(bid,_Digits),DoubleToString(ask,_Digits),
      DoubleToString(spread,_Digits),DoubleToString(targetPrice-referencePrice,_Digits),IntegerToString(count),DoubleToString(totalLots,2),
      DoubleToString(floatingProfit,2),AccountInfoString(ACCOUNT_CURRENCY),(OnlyEndOfBar ? "true" : "false"),
      IntegerToString((int)CloseMode),IntegerToString(TakeTarget));
   FileFlush(h);
   FileClose(h);
}

bool KiaXAMSpreadAllowed()
{
   if(!KiaXAM_EnableSpreadFilter) return true;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.ask <= 0.0 || tick.bid <= 0.0 || tick.ask < tick.bid)
   {
      datetime now = TimeCurrent();
      if(now - KiaXAMLastSpreadBlockLog >= 300)
      {
         Kia64TradeDiagnostic("KiaXAM entry blocked: live Bid/Ask quote unavailable.");
         KiaXAMLastSpreadBlockLog = now;
      }
      return false;
   }
   double liveSpread = tick.ask - tick.bid;
   if(liveSpread <= KiaXAM_MaxSpreadPrice) return true;
   datetime now = TimeCurrent();
   if(now - KiaXAMLastSpreadBlockLog >= 300)
   {
      Kia64TradeDiagnostic("KiaXAM entry blocked by live spread filter; symbol="+_Symbol+
                           "; spread_price="+DoubleToString(liveSpread,_Digits)+
                           "; max_spread_price="+DoubleToString(KiaXAM_MaxSpreadPrice,_Digits)+
                           "; spread_points="+DoubleToString(liveSpread/_Point,1));
      KiaXAMLastSpreadBlockLog = now;
   }
   return false;
}

void KiaXAMLogSymbolSpecs()
{
   MqlTick tick;
   bool hasTick = SymbolInfoTick(_Symbol,tick);
   double bid = hasTick ? tick.bid : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = hasTick ? tick.ask : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double spreadPrice = (bid > 0.0 && ask >= bid) ? ask-bid : 0.0;
   long digits=0, spreadPoints=0, spreadFloat=0, fillingFlags=0, executionMode=0, tradeMode=0, stopsLevel=0;
   SymbolInfoInteger(_Symbol,SYMBOL_DIGITS,digits);
   SymbolInfoInteger(_Symbol,SYMBOL_SPREAD,spreadPoints);
   SymbolInfoInteger(_Symbol,SYMBOL_SPREAD_FLOAT,spreadFloat);
   SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE,fillingFlags);
   SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE,executionMode);
   SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE,tradeMode);
   SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL,stopsLevel);
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double contractSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   double volumeMin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double volumeMax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double volumeStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   int handle=FileOpen(KIAXAM_SYMBOL_INFO_FILE,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(handle==INVALID_HANDLE)
   {
      Kia64TradeDiagnostic("KiaXAM could not open symbol-spec file; last_error="+IntegerToString(GetLastError()));
      return;
   }
   if(FileSize(handle)==0)
      FileWrite(handle,"timestamp","account_server","account_currency","account_margin_mode","symbol","timeframe",
                "bid","ask","spread_price","spread_points","digits","point","tick_size","tick_value","contract_size",
                "volume_min","volume_max","volume_step","spread_floating","filling_flags","execution_mode",
                "trade_mode","stops_level","max_spread_price","commission_note");
   FileSeek(handle,0,SEEK_END);
   FileWrite(handle,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),AccountInfoString(ACCOUNT_SERVER),
             AccountInfoString(ACCOUNT_CURRENCY),IntegerToString((int)AccountInfoInteger(ACCOUNT_MARGIN_MODE)),
             _Symbol,EnumToString((ENUM_TIMEFRAMES)_Period),DoubleToString(bid,(int)digits),
             DoubleToString(ask,(int)digits),DoubleToString(spreadPrice,(int)digits),IntegerToString((int)spreadPoints),
             IntegerToString((int)digits),DoubleToString(point,8),DoubleToString(tickSize,8),DoubleToString(tickValue,8),
             DoubleToString(contractSize,4),DoubleToString(volumeMin,4),DoubleToString(volumeMax,4),
             DoubleToString(volumeStep,4),IntegerToString((int)spreadFloat),IntegerToString((int)fillingFlags),
             IntegerToString((int)executionMode),IntegerToString((int)tradeMode),IntegerToString((int)stopsLevel),
             DoubleToString(KiaXAM_MaxSpreadPrice,(int)digits),
             "Not exposed as a universal live symbol property; verify account contract/commission schedule");
   FileFlush(handle);
   FileClose(handle);
}

//==================================================================
// KIA64 TRADE DIAGNOSTICS
// Set to 0 to disable diagnostic messages, or remove this section
// and the Kia64TradeDiagnostic() calls to remove diagnostics entirely.
// This section only reports trade-request details; it does not decide
// entry/exit signals or change money-management rules.
//==================================================================
// File-based diagnostics and performance journal. No diagnostic text is sent to Experts.
#define KIA64_TRADE_DIAGNOSTICS 1
#define KIA64_EVENT_LOG_FILE "Kia64_TradeHistory.csv"
#define KIA64_PERFORMANCE_FILE "Kia64_Performance.csv"

void Kia64AppendCsvRow(string file_name, string row_type, string details)
{
   int handle = FileOpen(file_name, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ';');
   if(handle == INVALID_HANDLE) return;
   if(FileSize(handle) == 0)
   {
      FileWrite(handle, "timestamp", "event_type", "symbol", "timeframe", "magic", "details");
   }
   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), row_type, _Symbol,
             EnumToString((ENUM_TIMEFRAMES)_Period), IntegerToString(MagicNumber), details);
   FileFlush(handle);
   FileClose(handle);
}

void Kia64AppendPerformanceRow(string row_type, ulong deal_ticket, datetime deal_time,
                               double volume, double price, double profit, double swap,
                               double commission, string details)
{
   int handle = FileOpen(KIA64_PERFORMANCE_FILE, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ';');
   if(handle == INVALID_HANDLE) return;
   if(FileSize(handle) == 0)
      FileWrite(handle, "timestamp", "record_type", "deal_ticket", "symbol", "magic", "volume",
                "price", "profit", "swap", "commission", "net_result", "balance", "equity", "details");
   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle, TimeToString(deal_time, TIME_DATE|TIME_SECONDS), row_type,
             IntegerToString((long)deal_ticket), _Symbol, IntegerToString(MagicNumber),
             DoubleToString(volume, 2), DoubleToString(price, _Digits),
             DoubleToString(profit, 2), DoubleToString(swap, 2), DoubleToString(commission, 2),
             DoubleToString(profit+swap+commission, 2),
             DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2),
             DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2), details);
   FileFlush(handle);
   FileClose(handle);
}

// Suppress repeated identical diagnostic messages for five minutes.
string Kia64LoggedDiagnosticKeys[128];
datetime Kia64LoggedDiagnosticTimes[128];
int Kia64DiagnosticSlot = 0;

void Kia64TradeDiagnostic(string message)
{
   if(KIA64_TRADE_DIAGNOSTICS != 1) return;

   datetime now = TimeCurrent();
   for(int i=0; i<128; i++)
   {
      if(Kia64LoggedDiagnosticKeys[i] == message)
      {
         if(now - Kia64LoggedDiagnosticTimes[i] < 300) return;
         Kia64LoggedDiagnosticTimes[i] = now;
         Kia64AppendCsvRow(KIA64_EVENT_LOG_FILE, "DIAGNOSTIC", message);
         return;
      }
   }

   int slot = Kia64DiagnosticSlot;
   Kia64LoggedDiagnosticKeys[slot] = message;
   Kia64LoggedDiagnosticTimes[slot] = now;
   Kia64DiagnosticSlot = (Kia64DiagnosticSlot + 1) % 128;
   Kia64AppendCsvRow(KIA64_EVENT_LOG_FILE, "DIAGNOSTIC", message);
}

// Independent observer: request failures and actual deal events are written to files only.
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(KIA64_TRADE_DIAGNOSTICS != 1) return;

   if(trans.type == TRADE_TRANSACTION_REQUEST)
   {
      bool failed = (result.retcode != TRADE_RETCODE_DONE &&
                     result.retcode != TRADE_RETCODE_PLACED &&
                     result.retcode != TRADE_RETCODE_DONE_PARTIAL);
      if(failed)
         Kia64AppendCsvRow(KIA64_EVENT_LOG_FILE, "ORDER_REJECTED",
                           "symbol="+request.symbol+"; type="+IntegerToString((int)request.type)+
                           "; volume="+DoubleToString(request.volume,2)+
                           "; retcode="+IntegerToString((int)result.retcode)+
                           "; comment="+result.comment+
                           "; order="+IntegerToString((long)result.order)+
                           "; deal="+IntegerToString((long)result.deal));
   }

   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal > 0 && HistoryDealSelect(trans.deal))
   {
      string deal_symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
      long deal_magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
      if(deal_magic == MagicNumber)
      {
         datetime deal_time = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
         double volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
         double price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
         double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
         double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
         double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
         long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         string kind = (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) ? "CLOSED_DEAL" : "OPEN_OR_IN_DEAL";
         Kia64AppendPerformanceRow(kind, trans.deal, deal_time, volume, price, profit, swap,
                                   commission, "entry="+IntegerToString((int)entry)+"; deal_symbol="+deal_symbol);
      }
   }
}


//==================================================================
// KIA64 SESSION OBSERVER V3
// Reporting only: this block does not make or modify trade decisions.
// Output file is written under the terminal's MQL5/Files directory.
// Session times use broker-server time.
//==================================================================
#define KIA64_SESSION_FILE "Kia64_SessionAnalysis.csv"
datetime Kia64SessionLastSnapshotHour = 0;
double Kia64SessionPeakEquity = 0.0;
double Kia64SessionMaxEquityDrawdown = 0.0;

string Kia64SessionName(int hour, int &sessionStart, int &sessionEnd)
{
   if(hour < 6)  { sessionStart=0;  sessionEnd=6;  return "00-06"; }
   if(hour < 12) { sessionStart=6;  sessionEnd=12; return "06-12"; }
   if(hour < 16) { sessionStart=12; sessionEnd=16; return "12-16"; }
   if(hour < 20) { sessionStart=16; sessionEnd=20; return "16-20"; }
   sessionStart=20; sessionEnd=24; return "20-24";
}

void Kia64UpdateSessionObserver()
{
   datetime now = TimeCurrent();
   if(now <= 0) return;

   MqlDateTime nowParts;
   TimeToStruct(now, nowParts);
   MqlDateTime hourParts = nowParts;
   hourParts.min = 0;
   hourParts.sec = 0;
   datetime thisHour = StructToTime(hourParts);
   if(thisHour == Kia64SessionLastSnapshotHour) return;
   Kia64SessionLastSnapshotHour = thisHour;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(Kia64SessionPeakEquity <= 0.0 || equity > Kia64SessionPeakEquity)
      Kia64SessionPeakEquity = equity;
   double currentDD = MathMax(0.0, Kia64SessionPeakEquity - equity);
   if(currentDD > Kia64SessionMaxEquityDrawdown)
      Kia64SessionMaxEquityDrawdown = currentDD;
   double maxDDPercent = (Kia64SessionPeakEquity > 0.0)
                         ? 100.0*Kia64SessionMaxEquityDrawdown/Kia64SessionPeakEquity : 0.0;

   int sessionStartHour=0, sessionEndHour=0;
   string sessionName = Kia64SessionName(nowParts.hour, sessionStartHour, sessionEndHour);
   MqlDateTime startParts = nowParts;
   startParts.hour = sessionStartHour;
   startParts.min = 0;
   startParts.sec = 0;
   datetime sessionStartTime = StructToTime(startParts);

   int closedExitDeals=0, wins=0, losses=0;
   double closedExitNet=0.0, sessionDealNet=0.0;
   if(HistorySelect(sessionStartTime, now))
   {
      int totalDeals = HistoryDealsTotal();
      for(int d=0; d<totalDeals; d++)
      {
         ulong dealTicket = HistoryDealGetTicket(d);
         if(dealTicket == 0) continue;
         if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
         if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;

         double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         double dealSwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
         double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         double dealNet = dealProfit + dealSwap + dealCommission;
         sessionDealNet += dealNet;

         long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY)
         {
            closedExitDeals++;
            closedExitNet += dealNet;
            if(dealNet > 0.0) wins++;
            else if(dealNet < 0.0) losses++;
         }
      }
   }

   int openPositions=0;
   double openLots=0.0, floatingProfit=0.0;
   for(int p=PositionsTotal()-1; p>=0; p--)
   {
      ulong positionTicket = PositionGetTicket(p);
      if(positionTicket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      openPositions++;
      openLots += PositionGetDouble(POSITION_VOLUME);
      floatingProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }

   double spreadPoints = (_Point > 0.0) ? (Ask_ - Bid_)/_Point : 0.0;
   int handle = FileOpen(KIA64_SESSION_FILE,
                         FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ';');
   if(handle == INVALID_HANDLE) return;

   if(FileSize(handle) == 0)
   {
      FileWrite(handle, "snapshot_time", "server_date", "symbol", "timeframe", "magic",
                "session_server_time", "session_start_hour", "session_end_hour",
                "closed_exit_deal_records", "wins_by_exit_record", "losses_by_exit_record",
                "closed_exit_net_in_session", "all_deal_cashflow_in_session",
                "open_positions", "open_lots", "floating_profit_swap",
                "balance", "equity", "spread_points",
                "max_observed_equity_drawdown_since_attach", "max_observed_equity_drawdown_percent");
   }

   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle,
             TimeToString(now, TIME_DATE|TIME_SECONDS),
             TimeToString(now, TIME_DATE),
             _Symbol,
             EnumToString((ENUM_TIMEFRAMES)_Period),
             IntegerToString(MagicNumber),
             sessionName,
             IntegerToString(sessionStartHour),
             IntegerToString(sessionEndHour),
             IntegerToString(closedExitDeals),
             IntegerToString(wins),
             IntegerToString(losses),
             DoubleToString(closedExitNet, 2),
             DoubleToString(sessionDealNet, 2),
             IntegerToString(openPositions),
             DoubleToString(openLots, 2),
             DoubleToString(floatingProfit, 2),
             DoubleToString(balance, 2),
             DoubleToString(equity, 2),
             DoubleToString(spreadPoints, 1),
             DoubleToString(Kia64SessionMaxEquityDrawdown, 2),
             DoubleToString(maxDDPercent, 2));
   FileFlush(handle);
   FileClose(handle);
}


int InvioOrdine(string simbolo,int cmd,double lotti, double prezzo, double stoploss, double takeprofit,string comment,int Magic,datetime espirazione,color colore)
{
   MqlTradeRequest Trade;
   ZeroMemory(Trade);
   MqlTradeResult Risultati;
   ZeroMemory(Risultati);

   Trade.action = TRADE_ACTION_DEAL;
   Trade.magic = Magic;
   Trade.symbol = simbolo;
   Trade.volume = lotti;
   Trade.price = prezzo;
   Trade.sl = stoploss;
   Trade.tp = takeprofit;
   Trade.deviation = 10;
   Trade.type = (ENUM_ORDER_TYPE)cmd;
   Trade.comment = comment;

   // Select only filling modes supported by this symbol/execution mode.
   long fillingFlags = 0;
   long executionMode = 0;
   if(!SymbolInfoInteger(simbolo,SYMBOL_FILLING_MODE,fillingFlags) ||
      !SymbolInfoInteger(simbolo,SYMBOL_TRADE_EXEMODE,executionMode))
   {
      Kia64TradeDiagnostic("Cannot read filling/execution mode for "+simbolo+
                           "; last_error="+IntegerToString(GetLastError()));
      return -1;
   }

   ENUM_ORDER_TYPE_FILLING fillingModes[3];
   int fillingCount = 0;

   // Request/Instant execution allows IOC and FOK regardless of symbol flags.
   // Market/Exchange execution must respect the symbol's advertised filling flags.
   if(executionMode == SYMBOL_TRADE_EXECUTION_REQUEST ||
      executionMode == SYMBOL_TRADE_EXECUTION_INSTANT)
   {
      fillingModes[fillingCount++] = ORDER_FILLING_IOC;
      fillingModes[fillingCount++] = ORDER_FILLING_FOK;
      fillingModes[fillingCount++] = ORDER_FILLING_RETURN;
   }
   else
   {
      if((fillingFlags & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
         fillingModes[fillingCount++] = ORDER_FILLING_IOC;
      if((fillingFlags & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
         fillingModes[fillingCount++] = ORDER_FILLING_FOK;
      // RETURN is prohibited for Market Execution, but allowed for Exchange Execution.
      if(executionMode == SYMBOL_TRADE_EXECUTION_EXCHANGE)
         fillingModes[fillingCount++] = ORDER_FILLING_RETURN;
   }

   if(fillingCount == 0)
   {
      Kia64TradeDiagnostic("No supported filling mode found for "+simbolo+
                           "; flags="+IntegerToString((int)fillingFlags)+
                           "; execution="+IntegerToString((int)executionMode));
      return -1;
   }

   Kia64TradeDiagnostic("Request: symbol="+simbolo+
                        "; side="+string(cmd==ORDER_TYPE_BUY ? "BUY" : "SELL")+
                        "; volume="+DoubleToString(lotti,2)+
                        "; filling_flags="+IntegerToString((int)fillingFlags)+
                        "; execution="+IntegerToString((int)executionMode));

   for(int attempt=0; attempt<fillingCount; attempt++)
   {
      Trade.type_filling = fillingModes[attempt];
      ZeroMemory(Risultati);
      ResetLastError();

      bool sent = OrderSend(Trade,Risultati);

      Kia64TradeDiagnostic("Attempt "+IntegerToString(attempt+1)+
                           "; filling="+IntegerToString((int)Trade.type_filling)+
                           "; OrderSend="+string(sent ? "true" : "false")+
                           "; retcode="+IntegerToString((int)Risultati.retcode)+
                           "; comment="+Risultati.comment+
                           "; last_error="+IntegerToString(GetLastError())+
                           "; order="+IntegerToString((int)Risultati.order)+
                           "; deal="+IntegerToString((int)Risultati.deal));

      // Retry with another supported mode only for unsupported filling mode.
      if(Risultati.retcode == 10030)
         continue;

      break;
   }

   if(Risultati.retcode != TRADE_RETCODE_DONE &&
      Risultati.retcode != TRADE_RETCODE_DONE_PARTIAL &&
      Risultati.retcode != TRADE_RETCODE_PLACED)
   {
      Kia64TradeDiagnostic("Trade request failed; final retcode="+
                           IntegerToString((int)Risultati.retcode)+
                           "; comment="+Risultati.comment);
      return -1;
   }

   int ticket = (int)Risultati.deal;
   Sleep(800);
   return ticket;
}



bool CheckVolumeValue(double &volume)
  {

int LotDigit=2;
if ( MathAbs( SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) - 0.1 ) < 0.001  )
LotDigit = 1;
if ( MathAbs( SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) - 1 ) < 0.001  )
LotDigit = 0;
if ( MathAbs( SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) - 0.01 ) < 0.001  )
LotDigit = 2;


volume = NormalizeDouble(volume,LotDigit);

//--- minimal allowed volume for trade operations
   double min_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   if(volume<min_volume)
     {
     volume = min_volume;
     if(volume<min_volume)
      return(false);
     }

//--- maximal allowed volume of trade operations
   double max_volume= (MaxLot==0)?SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX):MaxLot;
   if(volume>max_volume)
     {
      if (max_volume != 0)
      {
     
          volume = max_volume;
          if(volume>max_volume)
          return(false);

      }

     }

//--- get minimal step of volume changing
   double volume_step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);

   if ( volume_step < 0.01 )
   volume_step = 0.01;
   if ( volume < 0.01 )
   volume = 0.01;

   int ratio=(int)MathRound(volume/volume_step);
   if(MathAbs(ratio*volume_step-volume)>0.0000001)
     {
         
      return(false);
     }

volume = NormalizeDouble(volume,LotDigit);

   return(true);
  }

bool CheckMoneyForTrade(string symb, double lots,int type)
  {
   double free_margin=AccountFreeMarginCheck(symb,type, lots);
   //-- if there is not enough money
   if(free_margin<0)
     {
      string oper=(type==OP_BUY)? "Buy":"Sell";
      return(false);
     }
   //--- checking successful
   return(true);
  }

bool IsNewOrderAllowed()
{
//--- get the number of pending orders allowed on the account
   int max_allowed_orders=(int)AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);

//--- if there is no limitation, return true; you can send an order
   if(max_allowed_orders==0) return(true);

//--- if we passed to this line, then there is a limitation; find out how many orders are already placed
   int orders=OrdersTotal();

//--- return the result of comparing
   return(orders<max_allowed_orders);
}


double OnTester()
  {
double ret=0;


if (TesterStatistics(STAT_TRADES) < MinimumTrades)
return(0);
double MaxDrawDown = TesterStatistics(STAT_BALANCE_DD);
if (TesterStatistics(STAT_EQUITY_DD) > MaxDrawDown)
MaxDrawDown = TesterStatistics(STAT_EQUITY_DD);
if (MaxDrawDown > 0)
return(TesterStatistics(STAT_PROFIT)/MaxDrawDown);
else
return (0);


   return(ret);
  }



//Money Management
double MoneySize()
{
double lottaggio = 0.01;
lottaggio = (AccountBalance()/100000)*RiskPercent;

if (lottaggio < 0.01)
lottaggio = 0.01;

return NormalizeDouble(lottaggio,2);
}



bool extraindicatorsbuy()
{


int MODE_MAIN = BASE_LINE;
int MODE_UPPER = UPPER_BAND;
int MODE_LOWER = LOWER_BAND;


if ( EnableBollingerBands )
{
   if ( BollingerBandsStrategies == SellAboveAndBuyBelow )
   {
      if ( ibands(MODE_LOWER,MomentOfTheSignal) <  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal) ||  ibands(MODE_LOWER,MomentOfTheSignal+1) >  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal+1) ) //MODE_MAIN per la centrale
      return false;
   }
   if ( BollingerBandsStrategies == BuyAboveAndSellBelow )
   {
      if ( ibands(MODE_UPPER,MomentOfTheSignal) >  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal) ||  ibands(MODE_UPPER,MomentOfTheSignal+1) <  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal+1)  ) //MODE_MAIN per la centrale
      return false;
   }
   if ( BollingerBandsStrategies == UpTrendBuyAndDownTrendSell )
   {
         if ( ibands(MODE_MAIN,MomentOfTheSignal) < ibands(MODE_MAIN,MomentOfTheSignal+1) || ibands(MODE_MAIN,MomentOfTheSignal+1) < ibands(MODE_MAIN,MomentOfTheSignal+2) || ibands(MODE_MAIN,MomentOfTheSignal+2) < ibands(MODE_MAIN,MomentOfTheSignal+3)  
         ||  ibands(MODE_MAIN,MomentOfTheSignal+3) < ibands(MODE_MAIN,MomentOfTheSignal+4)  ||  ibands(MODE_MAIN,MomentOfTheSignal+4) < ibands(MODE_MAIN,MomentOfTheSignal+5)  ||  ibands(MODE_MAIN,MomentOfTheSignal+5) < ibands(MODE_MAIN,MomentOfTheSignal+6)
          ||  ibands(MODE_MAIN,MomentOfTheSignal+6) < ibands(MODE_MAIN,MomentOfTheSignal+7)  ||  ibands(MODE_MAIN,MomentOfTheSignal+7) < ibands(MODE_MAIN,MomentOfTheSignal+8)  ||  ibands(MODE_MAIN,MomentOfTheSignal+8) > ibands(MODE_MAIN,MomentOfTheSignal+9)  ) //MODE_MAIN per la centrale
         return false;
   }
   if ( BollingerBandsStrategies == DownTrendBuyAndUpTrendSell )
   {
         if ( ibands(MODE_MAIN,MomentOfTheSignal) > ibands(MODE_MAIN,MomentOfTheSignal+1) || ibands(MODE_MAIN,MomentOfTheSignal+1) > ibands(MODE_MAIN,MomentOfTheSignal+2) || ibands(MODE_MAIN,MomentOfTheSignal+2) > ibands(MODE_MAIN,MomentOfTheSignal+3)  || ibands(MODE_MAIN,MomentOfTheSignal+3) > ibands(MODE_MAIN,MomentOfTheSignal+4) 
          || ibands(MODE_MAIN,MomentOfTheSignal+4) > ibands(MODE_MAIN,MomentOfTheSignal+5)  || ibands(MODE_MAIN,MomentOfTheSignal+5) > ibands(MODE_MAIN,MomentOfTheSignal+6)  || ibands(MODE_MAIN,MomentOfTheSignal+6) > ibands(MODE_MAIN,MomentOfTheSignal+7) 
           || ibands(MODE_MAIN,MomentOfTheSignal+7) > ibands(MODE_MAIN,MomentOfTheSignal+8)  || ibands(MODE_MAIN,MomentOfTheSignal+8) < ibands(MODE_MAIN,MomentOfTheSignal+9)  ) //MODE_MAIN per la centrale
         return false;
   }
   if ( BollingerBandsStrategies == CrossUpCentralBandInUpTrendBuy )
   {
         if ( iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal) < ibands(MODE_MAIN,MomentOfTheSignal) || iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal+1) > ibands(MODE_MAIN,MomentOfTheSignal+1) //incrocio verso l'alto
         || ibands(MODE_MAIN,MomentOfTheSignal) < ibands(MODE_MAIN,MomentOfTheSignal+1) || ibands(MODE_MAIN,MomentOfTheSignal+1) < ibands(MODE_MAIN,MomentOfTheSignal+2) || ibands(MODE_MAIN,MomentOfTheSignal+2) < ibands(MODE_MAIN,MomentOfTheSignal+3) 
          || ibands(MODE_MAIN,MomentOfTheSignal+3) < ibands(MODE_MAIN,MomentOfTheSignal+4)  || ibands(MODE_MAIN,MomentOfTheSignal+4) < ibands(MODE_MAIN,MomentOfTheSignal+5) 
         )
         return false;
   }
   if ( BollingerBandsStrategies == CrossDownCentralBandInDownTrendBuy )
   {
         if ( iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal) > ibands(MODE_MAIN,MomentOfTheSignal) || iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal+1) < ibands(MODE_MAIN,MomentOfTheSignal+1) //incrocio verso l'alto
         || ibands(MODE_MAIN,MomentOfTheSignal) > ibands(MODE_MAIN,MomentOfTheSignal+1) || ibands(MODE_MAIN,MomentOfTheSignal+1) > ibands(MODE_MAIN,MomentOfTheSignal+2) || ibands(MODE_MAIN,MomentOfTheSignal+2) > ibands(MODE_MAIN,MomentOfTheSignal+3) 
          || ibands(MODE_MAIN,MomentOfTheSignal+3) > ibands(MODE_MAIN,MomentOfTheSignal+4)  || ibands(MODE_MAIN,MomentOfTheSignal+4) > ibands(MODE_MAIN,MomentOfTheSignal+5) 
         )
         return false;
   }
}

if ( EnableMa )
{
   if ( imaFast(1) > imaLow(1) )
   return false;
}

if ( EnableAdx )
{
   if ( (iadx(1) < AdxLimit && !AdxReverseRules)  || ( iadx(1) > AdxLimit && AdxReverseRules ))
   return false;
}

if ( EnableSar )
{
   if ( SarReverseRules )
   {
      if ( SarOnlyOnCrossing )
      {
         if ( isar(1) < iClose(_Symbol,SarTimeframe,1) || isar(2) > iClose(_Symbol,SarTimeframe,2) )
         return false;
      }
      else
      {
         if ( isar(1) < iClose(_Symbol,SarTimeframe,1) )
         return false;
      }
   }
   else
   {
      if ( SarOnlyOnCrossing )
      {
         if ( isar(1) > iClose(_Symbol,SarTimeframe,1) || isar(2) < iClose(_Symbol,SarTimeframe,2) )
         return false;
      }
      else
      {
         if ( isar(1) > iClose(_Symbol,SarTimeframe,1) )
         return false;
      }
   }
}

if ( EnableStochastic )
{ 
   if ( StochasticReverseRules )
   {
      if ( istoc(StochasticMode,1) < UpperLevel )
      return false;    
   }
   else
   {
      if ( istoc(StochasticMode,1) > LowerLevel )
      return false;      
   }
}

if ( EnableCCI )
{ 
   if ( CCIReverseRules )
   {
      if ( icci(1) < CCIUpperLevel )
      return false;    
   }
   else
   {
      if ( icci(1) > CCILowerLevel )
      return false;      
   }
}

return true;
}



bool extraindicatorssell()
{

int MODE_MAIN = BASE_LINE;
int MODE_UPPER = UPPER_BAND;
int MODE_LOWER = LOWER_BAND;


if ( EnableBollingerBands )
{
   if ( BollingerBandsStrategies == SellAboveAndBuyBelow )
   {
      if ( ibands(MODE_UPPER,MomentOfTheSignal) >  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal)  || ibands(MODE_UPPER,MomentOfTheSignal+1) <  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal+1)  ) //MODE_MAIN per la centrale
      return false;
   }
   if ( BollingerBandsStrategies == BuyAboveAndSellBelow )
   {
      if ( ibands(MODE_LOWER,MomentOfTheSignal) <  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal) ||  ibands(MODE_LOWER,MomentOfTheSignal+1) >  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal+1) ) //MODE_MAIN per la centrale
      return false;
   }
   if ( BollingerBandsStrategies == UpTrendBuyAndDownTrendSell )
   {
         if ( ibands(MODE_MAIN,MomentOfTheSignal) > ibands(MODE_MAIN,MomentOfTheSignal+1) || ibands(MODE_MAIN,MomentOfTheSignal+1) > ibands(MODE_MAIN,MomentOfTheSignal+2) || ibands(MODE_MAIN,MomentOfTheSignal+2) > ibands(MODE_MAIN,MomentOfTheSignal+3)  || ibands(MODE_MAIN,MomentOfTheSignal+3) > ibands(MODE_MAIN,MomentOfTheSignal+4) 
          || ibands(MODE_MAIN,MomentOfTheSignal+4) > ibands(MODE_MAIN,MomentOfTheSignal+5)  || ibands(MODE_MAIN,MomentOfTheSignal+5) > ibands(MODE_MAIN,MomentOfTheSignal+6)  || ibands(MODE_MAIN,MomentOfTheSignal+6) > ibands(MODE_MAIN,MomentOfTheSignal+7) 
           || ibands(MODE_MAIN,MomentOfTheSignal+7) > ibands(MODE_MAIN,MomentOfTheSignal+8)  || ibands(MODE_MAIN,MomentOfTheSignal+8) < ibands(MODE_MAIN,MomentOfTheSignal+9)  ) //MODE_MAIN per la centrale
         return false;
   }
   if ( BollingerBandsStrategies == DownTrendBuyAndUpTrendSell )
   {
         if ( ibands(MODE_MAIN,MomentOfTheSignal) < ibands(MODE_MAIN,MomentOfTheSignal+1) || ibands(MODE_MAIN,MomentOfTheSignal+1) < ibands(MODE_MAIN,MomentOfTheSignal+2) || ibands(MODE_MAIN,MomentOfTheSignal+2) < ibands(MODE_MAIN,MomentOfTheSignal+3)  
         ||  ibands(MODE_MAIN,MomentOfTheSignal+3) < ibands(MODE_MAIN,MomentOfTheSignal+4)  ||  ibands(MODE_MAIN,MomentOfTheSignal+4) < ibands(MODE_MAIN,MomentOfTheSignal+5)  ||  ibands(MODE_MAIN,MomentOfTheSignal+5) < ibands(MODE_MAIN,MomentOfTheSignal+6)
          ||  ibands(MODE_MAIN,MomentOfTheSignal+6) < ibands(MODE_MAIN,MomentOfTheSignal+7)  ||  ibands(MODE_MAIN,MomentOfTheSignal+7) < ibands(MODE_MAIN,MomentOfTheSignal+8)  ||  ibands(MODE_MAIN,MomentOfTheSignal+8) > ibands(MODE_MAIN,MomentOfTheSignal+9)  ) //MODE_MAIN per la centrale
         return false;
   }
   if ( BollingerBandsStrategies == CrossUpCentralBandInUpTrendBuy )
   {
         if ( iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal) > ibands(MODE_MAIN,MomentOfTheSignal) || iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal+1) < ibands(MODE_MAIN,MomentOfTheSignal+1) //incrocio verso l'alto
         || ibands(MODE_MAIN,MomentOfTheSignal) > ibands(MODE_MAIN,MomentOfTheSignal+1) || ibands(MODE_MAIN,MomentOfTheSignal+1) > ibands(MODE_MAIN,MomentOfTheSignal+2) || ibands(MODE_MAIN,MomentOfTheSignal+2) > ibands(MODE_MAIN,MomentOfTheSignal+3) 
          || ibands(MODE_MAIN,MomentOfTheSignal+3) > ibands(MODE_MAIN,MomentOfTheSignal+4)  || ibands(MODE_MAIN,MomentOfTheSignal+4) > ibands(MODE_MAIN,MomentOfTheSignal+5) 
         )
         return false;
   }
   if ( BollingerBandsStrategies == CrossDownCentralBandInDownTrendBuy )
   {
         if ( iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal) < ibands(MODE_MAIN,MomentOfTheSignal) || iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal+1) > ibands(MODE_MAIN,MomentOfTheSignal+1) //incrocio verso l'alto
         || ibands(MODE_MAIN,MomentOfTheSignal) < ibands(MODE_MAIN,MomentOfTheSignal+1) || ibands(MODE_MAIN,MomentOfTheSignal+1) < ibands(MODE_MAIN,MomentOfTheSignal+2) || ibands(MODE_MAIN,MomentOfTheSignal+2) < ibands(MODE_MAIN,MomentOfTheSignal+3) 
          || ibands(MODE_MAIN,MomentOfTheSignal+3) < ibands(MODE_MAIN,MomentOfTheSignal+4)  || ibands(MODE_MAIN,MomentOfTheSignal+4) < ibands(MODE_MAIN,MomentOfTheSignal+5) 
         )
         return false;
   }
}

if ( EnableMa )
{
   if ( imaFast(1)  < imaLow(1) )
   return false;
}

if ( EnableAdx )
{
   if ( (iadx(1) < AdxLimit && !AdxReverseRules)  || ( iadx(1) > AdxLimit && AdxReverseRules ) )
   return false;
}

if ( EnableSar )
{
   if ( SarReverseRules )
   {
      if ( SarOnlyOnCrossing )
      {
         if ( isar(1) > iClose(_Symbol,SarTimeframe,1) || isar(2) < iClose(_Symbol,SarTimeframe,2) )
         return false;
      }
      else
      {
         if ( isar(1) > iClose(_Symbol,SarTimeframe,1) )
         return false;
      }
   }
   else
   {
      if ( SarOnlyOnCrossing )
      {
         if ( isar(1) < iClose(_Symbol,SarTimeframe,1) || isar(2) > iClose(_Symbol,SarTimeframe,2) )
         return false;
      }
      else
      {
         if ( isar(1) < iClose(_Symbol,SarTimeframe,1) )
         return false;
      }
   }
}


if ( EnableStochastic )
{ 
   if ( StochasticReverseRules )
   {
      if ( istoc(StochasticMode,1) > LowerLevel )
      return false;    
   }
   else
   {
      if ( istoc(StochasticMode,1) < UpperLevel  )
      return false;      
   }
}

if ( EnableCCI )
{ 
   if ( CCIReverseRules )
   {
      if ( icci(1) > CCILowerLevel )
      return false;    
   }
   else
   {
      if ( icci(1) < CCIUpperLevel  )
      return false;      
   }
}


return true;
}








void CloseOnIndicatorSignal()
{


if ( RespectSpreadAllowedWhileClosingOnIndicator )
{
bool Spread = MaxSpread*_Point >= Ask_-Bid_;
if (!Spread)
return;
}


int MODE_MAIN = BASE_LINE;
int MODE_UPPER = UPPER_BAND;
int MODE_LOWER = LOWER_BAND;



if ( ClosureType == CloseOnOppositeSignal )
{
   if ( BollingerBandsStrategies == SellAboveAndBuyBelow )
   {
      if ( ibands(MODE_LOWER,MomentOfTheSignal) >  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal)  ) //MODE_MAIN per la centrale
      EliminaOrdiniFifo(MagicNumber,OP_SELL);
   }
   if ( BollingerBandsStrategies == BuyAboveAndSellBelow )
   {
      if ( ibands(MODE_UPPER,MomentOfTheSignal) <  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal)  ) //MODE_MAIN per la centrale
      EliminaOrdiniFifo(MagicNumber,OP_SELL);
   }
   if ( BollingerBandsStrategies == UpTrendBuyAndDownTrendSell || BollingerBandsStrategies == CrossUpCentralBandInUpTrendBuy )
   {
         if ( ibands(MODE_MAIN,MomentOfTheSignal) > ibands(MODE_MAIN,MomentOfTheSignal+1) && ibands(MODE_MAIN,MomentOfTheSignal+1) > ibands(MODE_MAIN,MomentOfTheSignal+2) && ibands(MODE_MAIN,MomentOfTheSignal+2) > ibands(MODE_MAIN,MomentOfTheSignal+3)  
         &&  ibands(MODE_MAIN,MomentOfTheSignal+3) > ibands(MODE_MAIN,MomentOfTheSignal+4)  &&  ibands(MODE_MAIN,MomentOfTheSignal+4) > ibands(MODE_MAIN,MomentOfTheSignal+5)  &&  ibands(MODE_MAIN,MomentOfTheSignal+5) > ibands(MODE_MAIN,MomentOfTheSignal+6)
          &&  ibands(MODE_MAIN,MomentOfTheSignal+6) > ibands(MODE_MAIN,MomentOfTheSignal+7)  &&  ibands(MODE_MAIN,MomentOfTheSignal+7) > ibands(MODE_MAIN,MomentOfTheSignal+8)    ) //MODE_MAIN per la centrale
         EliminaOrdiniFifo(MagicNumber,OP_SELL);
   }
   if ( BollingerBandsStrategies == DownTrendBuyAndUpTrendSell || BollingerBandsStrategies == CrossDownCentralBandInDownTrendBuy  )
   {
         if ( ibands(MODE_MAIN,MomentOfTheSignal) < ibands(MODE_MAIN,MomentOfTheSignal+1) && ibands(MODE_MAIN,MomentOfTheSignal+1) < ibands(MODE_MAIN,MomentOfTheSignal+2) && ibands(MODE_MAIN,MomentOfTheSignal+2) < ibands(MODE_MAIN,MomentOfTheSignal+3)  && ibands(MODE_MAIN,MomentOfTheSignal+3) < ibands(MODE_MAIN,MomentOfTheSignal+4) 
          && ibands(MODE_MAIN,MomentOfTheSignal+4) < ibands(MODE_MAIN,MomentOfTheSignal+5)  && ibands(MODE_MAIN,MomentOfTheSignal+5) < ibands(MODE_MAIN,MomentOfTheSignal+6)  && ibands(MODE_MAIN,MomentOfTheSignal+6) < ibands(MODE_MAIN,MomentOfTheSignal+7) 
           && ibands(MODE_MAIN,MomentOfTheSignal+7) < ibands(MODE_MAIN,MomentOfTheSignal+8)    ) //MODE_MAIN per la centrale
         EliminaOrdiniFifo(MagicNumber,OP_SELL);
   }



   if ( BollingerBandsStrategies == SellAboveAndBuyBelow )
   {
      if ( ibands(MODE_UPPER,MomentOfTheSignal) <  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal) ) //MODE_MAIN per la centrale
      EliminaOrdiniFifo(MagicNumber,OP_BUY);
   }
   if ( BollingerBandsStrategies == BuyAboveAndSellBelow )
   {
      if ( ibands(MODE_LOWER,MomentOfTheSignal) >  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal)  ) //MODE_MAIN per la centrale
      EliminaOrdiniFifo(MagicNumber,OP_BUY);
   }
   if ( BollingerBandsStrategies == UpTrendBuyAndDownTrendSell || BollingerBandsStrategies == CrossUpCentralBandInUpTrendBuy  )
   {
         if ( ibands(MODE_MAIN,MomentOfTheSignal) < ibands(MODE_MAIN,MomentOfTheSignal+1) && ibands(MODE_MAIN,MomentOfTheSignal+1) < ibands(MODE_MAIN,MomentOfTheSignal+2) && ibands(MODE_MAIN,MomentOfTheSignal+2) < ibands(MODE_MAIN,MomentOfTheSignal+3)  && ibands(MODE_MAIN,MomentOfTheSignal+3) < ibands(MODE_MAIN,MomentOfTheSignal+4) 
          && ibands(MODE_MAIN,MomentOfTheSignal+4) < ibands(MODE_MAIN,MomentOfTheSignal+5)  && ibands(MODE_MAIN,MomentOfTheSignal+5) < ibands(MODE_MAIN,MomentOfTheSignal+6)  && ibands(MODE_MAIN,MomentOfTheSignal+6) < ibands(MODE_MAIN,MomentOfTheSignal+7) 
           && ibands(MODE_MAIN,MomentOfTheSignal+7) < ibands(MODE_MAIN,MomentOfTheSignal+8)    ) //MODE_MAIN per la centrale
         EliminaOrdiniFifo(MagicNumber,OP_BUY);
   }
   if ( BollingerBandsStrategies == DownTrendBuyAndUpTrendSell  || BollingerBandsStrategies == CrossDownCentralBandInDownTrendBuy  )
   {
         if ( ibands(MODE_MAIN,MomentOfTheSignal) > ibands(MODE_MAIN,MomentOfTheSignal+1) && ibands(MODE_MAIN,MomentOfTheSignal+1) > ibands(MODE_MAIN,MomentOfTheSignal+2) && ibands(MODE_MAIN,MomentOfTheSignal+2) > ibands(MODE_MAIN,MomentOfTheSignal+3)  
         &&  ibands(MODE_MAIN,MomentOfTheSignal+3) > ibands(MODE_MAIN,MomentOfTheSignal+4)  &&  ibands(MODE_MAIN,MomentOfTheSignal+4) > ibands(MODE_MAIN,MomentOfTheSignal+5)  &&  ibands(MODE_MAIN,MomentOfTheSignal+5) > ibands(MODE_MAIN,MomentOfTheSignal+6)
          &&  ibands(MODE_MAIN,MomentOfTheSignal+6) > ibands(MODE_MAIN,MomentOfTheSignal+7)  &&  ibands(MODE_MAIN,MomentOfTheSignal+7) > ibands(MODE_MAIN,MomentOfTheSignal+8)    ) //MODE_MAIN per la centrale
         EliminaOrdiniFifo(MagicNumber,OP_BUY);
   }
}




if ( ClosureType == CloseOnTheCentralBand )
{
   if ( BollingerBandsStrategies == SellAboveAndBuyBelow )
   {
      if ( ibands(MODE_MAIN,MomentOfTheSignal) >  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal)  ) //MODE_MAIN per la centrale
      EliminaOrdiniFifo(MagicNumber,OP_SELL);
   }
   if ( BollingerBandsStrategies == BuyAboveAndSellBelow )
   {
      if ( ibands(MODE_MAIN,MomentOfTheSignal) <  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal)  ) //MODE_MAIN per la centrale
      EliminaOrdiniFifo(MagicNumber,OP_SELL);
   }

   if ( BollingerBandsStrategies == SellAboveAndBuyBelow )
   {
      if ( ibands(MODE_MAIN,MomentOfTheSignal) <  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal)  ) //MODE_MAIN per la centrale
      EliminaOrdiniFifo(MagicNumber,OP_BUY);
   }
   if ( BollingerBandsStrategies == BuyAboveAndSellBelow )
   {
      if ( ibands(MODE_MAIN,MomentOfTheSignal) >  iClose(_Symbol,BollingerBandsTimeframe,MomentOfTheSignal)  ) //MODE_MAIN per la centrale
      EliminaOrdiniFifo(MagicNumber,OP_BUY);
   }
}
}







int Hour_trade_Calculator(int hour, int minute)
{
return ((hour*60)+minute);
}



bool Hour_trade_allowed(int CoefPartenza, int CoefFine)
{

int CoefOrario = (Hour()*60)+Minute();
   bool trade = false;
   if(CoefPartenza > CoefFine){
     if (CoefOrario >= CoefPartenza || CoefOrario < CoefFine) trade = true;
   } else
     if (CoefOrario >= CoefPartenza && CoefOrario < CoefFine) trade = true;

   return (trade);
}


bool FifoModality(ENUM_ORDER_TYPE siamoin,int buyorder,int sellorder)
{

if (AllowBuyAndSellAtSameTime)
return true;

if ( siamoin == OP_BUY)
{
   if (sellorder > 0)
   return false;
   else
   return true;
}

if ( siamoin == OP_SELL)
{
   if (buyorder > 0)
   return false;
   else
   return true;
}

return true;
}


bool DayCheck(int today)
{

if ( today == 0)
return Sunday;
if ( today == 1)
return Monday;
if ( today == 2)
return Tuesday;
if ( today == 3)
return Wednesday;
if ( today == 4)
return Thursday;
if ( today == 5)
return Friday;
if ( today == 6)
return Saturday;

return true;
}



bool OrdineInPerdita(int cmd, int NumOrdini)
{

double prezzoapertura = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
   if(OrderMagicNumber()== MagicNumber && OrderSymbol() == Symbol() && OrderType() == OP_BUY && OrderType() == cmd)
   {
      if (prezzoapertura == 0)
      prezzoapertura = 100000000;
      if (prezzoapertura > OrderOpenPrice())
      prezzoapertura = OrderOpenPrice();
   }
   if(OrderMagicNumber()== MagicNumber && OrderSymbol() == Symbol() && OrderType() == OP_SELL && OrderType() == cmd)
   {
      if (prezzoapertura < OrderOpenPrice())
      prezzoapertura = OrderOpenPrice();
   }
}
}

if (MathAbs(prezzoapertura -0) < _Point)
return false;

   for(int e = PositionsTotal()-1; e >= 0; e--)
   {
      if(PositionGetTicket(e)>0)
      {
   if(OrderMagicNumber()== MagicNumber && OrderSymbol() == Symbol() && OrderType() == cmd)
   {
   break;
   }
if (e == 0)
return false;
}
}

double MinimalDistance = 0;
if ( MinDistanceOnAtr )
MinimalDistance = AtrMultiplier*iatr(_Symbol,DistanceAtrTimeframe,DistanceAtrPeriod,1);
else
MinimalDistance = MinDistanzaPiramide*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

   for(int i=1;i<NumOrdini;i++)
     {
      MinimalDistance = MinDistanceMultiplier*MinimalDistance;
     }

      if ( cmd == OP_BUY && !ordiniapertichiusisubarragrid(MagicNumber,OP_BUY) && !OrdiniApertiSuBarraGrid(MagicNumber,OP_BUY) &&  ((OneTradeBarGrid)? iOpen(_Symbol,NewOpenPeriod,0) < prezzoapertura -  (MinimalDistance+(Ask_-Bid_))  : prezzoapertura >Ask_ + MinimalDistance)   )
      {
      return true;
      }
      if ( cmd == OP_SELL && !ordiniapertichiusisubarragrid(MagicNumber,OP_SELL) && !OrdiniApertiSuBarraGrid(MagicNumber,OP_SELL) &&   ((OneTradeBarGrid)? iOpen(_Symbol,NewOpenPeriod,0) > prezzoapertura + MinimalDistance : prezzoapertura < Bid_ - MinimalDistance ) )
      {
      return true;
      }


return false;
}




void OrdinoUn(int cmd)
{
double sendlot = 0.01;
if (MoneyManagement)
LottoDaTradare = MoneySize();

if (cmd == OP_BUY)
{
sendlot = GestioneOrdini(LottoDaTradare,OP_BUY);// NormalizeDouble( LottoDaTradare+ (LottoDaTradare *OrdiniAperti(MagicNumber,OP_BUY)*CoefficientePyramide),2);
//Print(Lots," *",OrdiniAperti(MagicNumber,OP_BUY),"*",CoefficientePyramide);
if (CheckVolumeValue(sendlot) && EnableGrid && KiaXAMSpreadAllowed() && ( !GridOrdersComplyMaxSpreadConditions ||  MaxSpread*_Point >= Ask_-Bid_ ) && ( !GridOrdersComplyIndicatorsConditions || extraindicatorsbuy()) && ( !GridOrdersComplyHoursConditions || Hour_trade_allowed(coefstart,coefstop)) && ( !GridOrdersComplyWeekDaysConditions || DayCheck(DayOfWeek())) )
{
Ordine(OP_BUY,sendlot,Ask_,0,0,MagicNumber,0); 
}
}
if (cmd == OP_SELL)
{
sendlot = GestioneOrdini(LottoDaTradare,OP_SELL);//NormalizeDouble( LottoDaTradare+ (LottoDaTradare *OrdiniAperti(MagicNumber,OP_SELL)*CoefficientePyramide),2);
//Print(Lots ,"*",OrdiniAperti(MagicNumber,OP_SELL),"*",CoefficientePyramide);
if (CheckVolumeValue(sendlot) && EnableGrid && ( !GridOrdersComplyMaxSpreadConditions ||  MaxSpread*_Point >= Ask_-Bid_ ) && ( !GridOrdersComplyIndicatorsConditions || extraindicatorssell()) && ( !GridOrdersComplyHoursConditions || Hour_trade_allowed(coefstart,coefstop)) && ( !GridOrdersComplyWeekDaysConditions || DayCheck(DayOfWeek()))  )
Ordine(OP_SELL,sendlot,Bid_,0,0,MagicNumber,0); 
}
}


double GestioneOrdini(double lottaggio,int cmd)
{
   if (GridManagement == LotsSum)
   {
      if (cmd == OP_BUY)
      return NormalizeDouble( lottaggio+ (lottaggio *OrdiniAperti(MagicNumber,OP_BUY)*CoefficientGridManagement),2);
      if (cmd == OP_SELL)
      return NormalizeDouble( lottaggio+ (lottaggio *OrdiniAperti(MagicNumber,OP_SELL)*CoefficientGridManagement),2);
   }

   if(GridManagement == Martingale)
     {
         if (cmd == OP_BUY)
         {
            for(int i=(int)OrdiniAperti(MagicNumber,OP_BUY);i>0;i--)
              {
               lottaggio *= CoefficientGridManagement;
              }
         return NormalizeDouble( lottaggio ,2);
         
         }
         if (cmd == OP_SELL)
         {
         for(int i=(int)OrdiniAperti(MagicNumber,OP_SELL);i>0;i--)
              {
               lottaggio *= CoefficientGridManagement;
              }
         return NormalizeDouble( lottaggio ,2);
         }
     }


   if (GridManagement == AllLotsSum)
   {
      return NormalizeDouble( lottaggio+ (lottaggio *OrdiniAperti(MagicNumber)*CoefficientGridManagement),2);
   }

return lottaggio;
}





double CalcolaProfitto(int Magic)
{

double Profitto = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
if (OrderMagicNumber() == Magic && OrderSymbol() == Symbol())
   {
   Profitto += OrderSwap()+OrderCommission()+OrderProfit();
   }
}
}
return Profitto;
}





void PrezzoMedioPonderatoMonetario()
{

double TotLottiBuy = 0;
double ProfittoBuy = 0;
double TotLottiSell = 0;
double ProfittoSell = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
   {
      if(OrderType() == OP_BUY)
      {
         ProfittoBuy += OrderSwap()+OrderCommission()+OrderProfit();
         TotLottiBuy += OrderLots();
      }
      else if(OrderType() == OP_SELL)
      {
         ProfittoSell += OrderSwap()+OrderCommission()+OrderProfit();
         TotLottiSell += OrderLots();
      }
   }
}
}


   //CHIUSURA ORDINI PIRAMIDALI IN PROFITTO
      if (ProfittoBuy > /*Lots*/TakeTargetBuy*(TotLottiBuy)*MonetaAccount() )
      {
      EliminaOrdiniFifo(MagicNumber,OP_BUY);
      }
      if (ProfittoSell > /*Lots*/TakeTargetSell*(TotLottiSell)*MonetaAccount() )
      {
      EliminaOrdiniFifo(MagicNumber,OP_SELL);
      }

}



/*
void BreakevenMoney()
{

double ProfittoBuy = 0;
double ProfittoSell = 0;
int contaordinibuy = 0;
int contaordinisell = 0;
double lottobuy = 0;
double lottosell = 0;


for(int i = OrdersTotal()-1; i >= 0; i--)
{
if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
{
if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
   {
      if(OrderType() == OP_BUY)
      {
         ProfittoBuy += OrderSwap()+OrderCommission()+OrderProfit();
         contaordinibuy ++;
         lottobuy = OrderLots();
      }
      else if(OrderType() == OP_SELL)
      {
         ProfittoSell += OrderSwap()+OrderCommission()+OrderProfit();
         contaordinisell++;
         lottosell = OrderLots();
      }
   }
}
}


   //CHIUSURA ORDINI PIRAMIDALI IN PROFITTO
   if ( contaordinibuy > 1 )
   {
      if (ProfittoBuy > 0)
      {
      EliminaOrdiniFifo(MagicNumber,OP_BUY);
      }
   }
   else
   {
      if (ProfittoBuy > TakeTarget*(lottobuy)*MonetaAccount() )
      {
      EliminaOrdiniFifo(MagicNumber,OP_BUY);
      }
   }


   if ( contaordinisell > 1 )
   {
      if (ProfittoSell > 0 )
      {
      EliminaOrdiniFifo(MagicNumber,OP_SELL);
      }
   }
   else
   {
      if (ProfittoSell > TakeTarget*(lottosell)*MonetaAccount() )
      {
      EliminaOrdiniFifo(MagicNumber,OP_SELL);
      }
   }


}
*/


void PuntiFissiMonetari()
{

double ProfittoBuy = 0;
double ProfittoSell = 0;
double lottobuy = 100000000000000;
double lottosell = 100000000000000;


   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
   {
      if(OrderType() == OP_BUY)
      {
         ProfittoBuy += OrderSwap()+OrderCommission()+OrderProfit();
         if ( lottobuy > OrderLots() )
         lottobuy = OrderLots();
      }
      else if(OrderType() == OP_SELL)
      {
         ProfittoSell += OrderSwap()+OrderCommission()+OrderProfit();
         if ( lottosell > OrderLots() )
         lottosell = OrderLots();
      }
   }
}
}


   //CHIUSURA ORDINI PIRAMIDALI IN PROFITTO

      if (ProfittoBuy > TakeTargetBuy*(lottobuy)*MonetaAccount() )
      {
      EliminaOrdiniFifo(MagicNumber,OP_BUY);
      }

      if (ProfittoSell > TakeTargetSell*(lottosell)*MonetaAccount() )
      {
      EliminaOrdiniFifo(MagicNumber,OP_SELL);
      }


}



double MonetaAccount()
{
double Risultato=1;
string moneta = AccountCurrency();

if (moneta == "RUB")
Risultato = 68;
if (moneta == "JPY")
Risultato = 113;
if (moneta == "AUD")
Risultato = 1.38;
if (moneta == "HUF")
Risultato = 286;
if (moneta == "PLN")
Risultato = 3.8;
if (moneta == "CNH")
Risultato = 7;
if (moneta == "CNY")
Risultato = 7;
if (moneta == "EUR")
Risultato = 0.87;
if (moneta == "GBP")
Risultato = 0.77;

if(Risultato < 0.5)
Risultato = 1;
return Risultato;
}







double isar(int Posizione)
{

double SarArray[];

//proprieta
int SarProprietis = iSAR(_Symbol,SarTimeframe,SarStep,SarMaxStep);
// Numero Di Posizione
if (CopyBuffer(SarProprietis,0,Posizione,1,SarArray) < 1)
{
   Sleep(5000);
   if (CopyBuffer(SarProprietis,0,Posizione,1,SarArray) < 1)
   return -1;
}

return SarArray[0];

}






double istoc(int mode, int shift)
{

double StocArray[];

//proprieta
int StocProprietis = iStochastic(_Symbol,StochasticTimeframe,K_Period,D_Period,Slowing,StochasticMethod,StochasticPrice);
// Numero Di Posizione
if (CopyBuffer(StocProprietis,mode,shift,1,StocArray) < 1)
{
   Sleep(5000);
   if (CopyBuffer(StocProprietis,mode,shift,1,StocArray) < 1)
   return -1;
}

return StocArray[0];
}




double icci( int shift)
{

double CCIArray[];

//proprieta
int CCIProprietis = iCCI(_Symbol,CCITimeframe,CCIPeriods,CCIPrice);
// Numero Di Posizione
if (CopyBuffer(CCIProprietis,0,shift,1,CCIArray) < 1)
{
   Sleep(5000);
   if (CopyBuffer(CCIProprietis,0,shift,1,CCIArray) < 1)
   return -1;
}

return CCIArray[0];
}



bool HLineCreate(const long            chart_ID=0,        // chart's ID
                 const string          name="HLine",      // line name
                 const int             sub_window=0,      // subwindow index
                 double                price=0,           // line price
                 const color           clr=clrRed,        // line color
                 const ENUM_LINE_STYLE style=STYLE_SOLID, // line style
                 const int             width=1,           // line width
                 const bool            back=false,        // in the background
                 const bool            selection=true,    // highlight to move
                 const bool            hidden=true,       // hidden in the object list
                 const long            z_order=0)         // priority for mouse click
  {
//--- if the price is not set, set it at the current Bid price level
   if(!price)
      price=SymbolInfoDouble(Symbol(),SYMBOL_BID);
//--- reset the error value
   ResetLastError();
//--- create a horizontal line
   if(!ObjectCreate(chart_ID,name,OBJ_HLINE,sub_window,0,price))
     {
     
      return(false);
     }
//--- set line color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set line display style
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set line width
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the line by mouse
//--- when creating a graphical object using ObjectCreate function, the object cannot be
//--- highlighted and moved by default. Inside this method, selection parameter
//--- is true by default making it possible to highlight and move the object
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }

bool HLineMove(const long   chart_ID=0,   // chart's ID
               const string name="HLine", // line name
               double       price=0)      // line price
  {
//--- if the line price is not set, move it to the current Bid price level
   if(!price)
      price=SymbolInfoDouble(Symbol(),SYMBOL_BID);
//--- reset the error value
   ResetLastError();
//--- move a horizontal line
   if(!ObjectMove(chart_ID,name,0,0,price))
     {
     
      return(false);
     }
//--- successful execution
   return(true);
  }




void CommentoInit()
{


   SiamoInTestOscuro = (!IsVisualMode() && IsTesting());
   
   HLineCreate(0,"TargetLineBuy",0,EMPTY_VALUE,clrGreenYellow,0,1,false,false,false);
   HLineCreate(0,"TargetLineSell",0,EMPTY_VALUE,clrGreenYellow,0,1,false,false,false);
   HLineCreate(0,"StopLineBuy",0,EMPTY_VALUE,clrRed,0,1,false,false,false);
   HLineCreate(0,"StopLineSell",0,EMPTY_VALUE,clrRed,0,1,false,false,false);
   
   if ( EnableAverageTrailingStop )
   {
   HLineCreate(0,"AverageTrailingBuy",0,EMPTY_VALUE,clrYellow,0,1,false,false,false);
   HLineCreate(0,"AverageTrailingSell",0,EMPTY_VALUE,clrYellow,0,1,false,false,false);
   }
   
   
   
   
   if ( ShowButton )
   {
   ButtonCreate(0,"ButtonCloseAll",0,60,30,90,25,CORNER_LEFT_LOWER,"Close All","Arial",12,clrBlack,clrWhite);
   ButtonCreate(0,"ButtonCloseBuy",0,10,65,90,25,CORNER_LEFT_LOWER,"Close Buy","Arial",12,clrWhite,clrBlue);
   ButtonCreate(0,"ButtonCloseSell",0,110,65,90,25,CORNER_LEFT_LOWER,"Close Sell","Arial",12,clrWhite,clrRed);
   }
   
   
   if ( ShowPanel && !SiamoInTestOscuro )
   {
   // Kia64 v1.1 panel: repositioned to the top-left with a dark glass-like appearance.
   // Native MQL5 rectangle labels do not support true blur/transparency.
   RectLabelCreate(0,"RectLabelKevin",0,10,10,320,350,C'24,29,36',BORDER_FLAT,CORNER_LEFT_UPPER,C'72,82,92',STYLE_SOLID,1,false,false,true,0);
   LabelCreate(0,"Kevin1",0,20,20,CORNER_LEFT_UPPER,WindowExpertName(),"Arial",10,C'255,165,65',0,ANCHOR_LEFT);
   LabelCreate(0,"KevinSection1",0,20,43,CORNER_LEFT_UPPER,"ACCOUNT OVERVIEW","Arial",8,C'120,190,220',0,ANCHOR_LEFT);
   LabelCreate(0,"Kevin2",0,20,63,CORNER_LEFT_UPPER,"Account Balance: ","Arial",9,clrWhiteSmoke,0,ANCHOR_LEFT);
   LabelCreate(0,"Kevin3",0,20,82,CORNER_LEFT_UPPER,"Account Equity: ","Arial",9,clrWhiteSmoke,0,ANCHOR_LEFT);
   LabelCreate(0,"Kevin4",0,20,101,CORNER_LEFT_UPPER,"Account Profit/Loss: ","Arial",9,clrWhiteSmoke,0,ANCHOR_LEFT);
   LabelCreate(0,"Kevin8",0,20,120,CORNER_LEFT_UPPER,"Drawdown Percentage: ","Arial",9,clrWhiteSmoke,0,ANCHOR_LEFT);
   LabelCreate(0,"KevinSection2",0,20,143,CORNER_LEFT_UPPER,"EA / MARKET INFO","Arial",8,C'120,190,220',0,ANCHOR_LEFT);
   LabelCreate(0,"Kevin9",0,20,163,CORNER_LEFT_UPPER,"Spread: ","Arial",9,clrWhiteSmoke,0,ANCHOR_LEFT);
   LabelCreate(0,"Kevin10",0,20,182,CORNER_LEFT_UPPER,"Start Lot Size: ","Arial",9,clrWhiteSmoke,0,ANCHOR_LEFT);
   LabelCreate(0,"Kevin11",0,20,201,CORNER_LEFT_UPPER,"Percentage Loss Protection: ","Arial",9,C'255,165,65',0,ANCHOR_LEFT);
   LabelCreate(0,"Kevin12",0,20,220,CORNER_LEFT_UPPER,"Monetary Loss Protection: ","Arial",9,C'255,165,65',0,ANCHOR_LEFT);
   LabelCreate(0,"KevinSection3",0,20,243,CORNER_LEFT_UPPER,"ADDITIONAL PROFIT / LOSS","Arial",8,C'120,190,220',0,ANCHOR_LEFT);
   string Simbolo = StringSubstr(_Symbol,1,5); StringToLower(Simbolo); Simbolo = StringSubstr(_Symbol,0,1)+Simbolo;
   LabelCreate(0,"Kevin5",0,20,263,CORNER_LEFT_UPPER,Simbolo+" Profit/Loss: ","Arial",9,clrWhiteSmoke,0,ANCHOR_LEFT);
   LabelCreate(0,"Kevin6",0,20,282,CORNER_LEFT_UPPER,"MagicN Profit/Loss: ","Arial",9,clrWhiteSmoke,0,ANCHOR_LEFT);
   LabelCreate(0,"Kevin7",0,20,301,CORNER_LEFT_UPPER,"Chart Profit/Loss: ","Arial",9,clrWhiteSmoke,0,ANCHOR_LEFT);
   }




}




void Commento()
{
       if(!SiamoInTestOscuro && ShowPanel)
       {
       
              
       double ProfitSimbol = 0;
       double ProfitMagic = 0;
       double ProfitChart = 0;
       
       CalcolaDati(ProfitSimbol,ProfitMagic, ProfitChart);
       
      LabelTextChange(0,"Kevin2","Account Balance: "+DoubleToString(AccountBalance(),2));
      LabelTextChange(0,"Kevin3","Account Equity: "+DoubleToString(AccountEquity(),2));
      LabelTextChange(0,"Kevin4","Account Profit/Loss: "+DoubleToString(AccountEquity()-AccountBalance(),2));
      
      string Simbolo = StringSubstr(_Symbol,1,5); StringToLower(Simbolo); Simbolo = StringSubstr(_Symbol,0,1)+Simbolo;
      LabelTextChange(0,"Kevin5",Simbolo+" Profit/Loss: "+DoubleToString(ProfitSimbol,2));
      LabelTextChange(0,"Kevin6","MagicN Profit/Loss: "+DoubleToString(ProfitMagic,2));
      LabelTextChange(0,"Kevin7","Chart Profit/Loss: "+DoubleToString(ProfitChart,2));
      
      if ( AccountEquity() != 0 && AccountBalance() != 0 )
      LabelTextChange(0,"Kevin8","Drawdown Percentage: "+DoubleToString(100-(AccountEquity()/AccountBalance())*100,2));
      LabelTextChange(0,"Kevin9","Spread: "+DoubleToString(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD),0));
      LabelTextChange(0,"Kevin10","Start Lot Size: "+DoubleToString(LottoDaTradare,2));
      // This EA does not implement a separate whole-account drawdown protection.
      string percentageProtection = (CloseInPercentageLoss ? "ACTIVE" : "INACTIVE");
      LabelTextChange(0,"Kevin11","Percentage Loss Protection: "+percentageProtection+" ("+IntegerToString(LossPercentage)+"%)");
      string monetaryProtection = (MonetaryStopLoss ? "ACTIVE" : "INACTIVE");
      LabelTextChange(0,"Kevin12","Monetary Loss Protection: "+monetaryProtection+" ($"+IntegerToString(MaximumMonetaryLoss)+")");
      ObjectSetInteger(0,"Kevin11",OBJPROP_COLOR,CloseInPercentageLoss ? C'80,210,130' : C'255,165,65');
      ObjectSetInteger(0,"Kevin12",OBJPROP_COLOR,MonetaryStopLoss ? C'80,210,130' : C'255,165,65');
      
      // Visual-only profit/loss coloring; trading calculations and decisions are unchanged.
      color accountPLColor = (AccountEquity()-AccountBalance() >= 0) ? C'80,210,130' : C'255,95,95';
      color symbolPLColor = (ProfitSimbol >= 0) ? C'80,210,130' : C'255,95,95';
      color magicPLColor = (ProfitMagic >= 0) ? C'80,210,130' : C'255,95,95';
      color chartPLColor = (ProfitChart >= 0) ? C'80,210,130' : C'255,95,95';
      ObjectSetInteger(0,"Kevin4",OBJPROP_COLOR,accountPLColor);
      ObjectSetInteger(0,"Kevin5",OBJPROP_COLOR,symbolPLColor);
      ObjectSetInteger(0,"Kevin6",OBJPROP_COLOR,magicPLColor);
      ObjectSetInteger(0,"Kevin7",OBJPROP_COLOR,chartPLColor);      
      
      
       }
}



void CalcolaDati(double &ProfitSimbol,double &ProfitMagic,double &ProfitChart)
{

ProfitSimbol = 0;
ProfitMagic = 0;
ProfitChart = 0;


   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         {
         ProfitChart += OrderSwap()+OrderCommission()+OrderProfit();
         }
         if ( OrderMagicNumber() == MagicNumber )
         {
         ProfitMagic += OrderSwap()+OrderCommission()+OrderProfit();
         }
         if ( OrderSymbol() == Symbol() )
         {
         ProfitSimbol += OrderSwap()+OrderCommission()+OrderProfit();
         }
      }
   }

}







bool ButtonCreate(const long              chart_ID=0,               // chart's ID
                  const string            name="Button",            // button name
                  const int               sub_window=0,             // subwindow index
                  const int               x=0,                      // X coordinate
                  const int               y=0,                      // Y coordinate
                  const int               width=50,                 // button width
                  const int               height=18,                // button height
                  const ENUM_BASE_CORNER  corner=CORNER_LEFT_UPPER, // chart corner for anchoring
                  const string            text="Button",            // text
                  const string            font="Arial",             // font
                  const int               font_size=10,             // font size
                  const color             clr=clrBlack,             // text color
                  const color             back_clr=C'236,233,216',  // background color
                  const color             border_clr=clrNONE,       // border color
                  const bool              state=false,              // pressed/released
                  const bool              back=false,               // in the background
                  const bool              selection=false,          // highlight to move
                  const bool              hidden=true,              // hidden in the object list
                  const long              z_order=0)                // priority for mouse click
  {
//--- reset the error value
   ResetLastError();
//--- create the button
   if(!ObjectCreate(chart_ID,name,OBJ_BUTTON,sub_window,0,0))
     {
      return(false);
     }
//--- set button coordinates
   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
//--- set button size
   ObjectSetInteger(chart_ID,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(chart_ID,name,OBJPROP_YSIZE,height);
//--- set the chart's corner, relative to which point coordinates are defined
   ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
//--- set the text
   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);
//--- set text font
   ObjectSetString(chart_ID,name,OBJPROP_FONT,font);
//--- set font size
   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size);
//--- set text color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set background color
   ObjectSetInteger(chart_ID,name,OBJPROP_BGCOLOR,back_clr);
//--- set border color
   ObjectSetInteger(chart_ID,name,OBJPROP_BORDER_COLOR,border_clr);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- set button state
   ObjectSetInteger(chart_ID,name,OBJPROP_STATE,state);
//--- enable (true) or disable (false) the mode of moving the button by mouse
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }


double PrezzoPrimoOrdineBuy()
{

double PrezzoPrimoOrdine = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
               if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol() && OrderType() == OP_BUY )
               {
                     if ( OrderOpenPrice() > PrezzoPrimoOrdine )
                     PrezzoPrimoOrdine = OrderOpenPrice();
               }
         }
   }
   
return PrezzoPrimoOrdine;
}


double PrezzoPrimoOrdineSell()
{

double PrezzoPrimoOrdine = 1000000000000;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
               if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol() && OrderType() == OP_SELL )
               {
                     if ( OrderOpenPrice() < PrezzoPrimoOrdine )
                     PrezzoPrimoOrdine = OrderOpenPrice();
               }
         }
   }
   
return PrezzoPrimoOrdine;
}








//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
  void AverageTrailingStopFunction()
  {

double PrezziOrdiniApertiBuy = 0;
int NumeroOrdiniApertiBuy = 0;

double PrezziOrdiniApertiSell = 0;
int NumeroOrdiniApertiSell = 0;


   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(PositionGetTicket(i)>0)
      {
           if (OrderSymbol()== _Symbol && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY) 
           {
           PrezziOrdiniApertiBuy += OrderOpenPrice();
           NumeroOrdiniApertiBuy++;
           }
           else if (OrderSymbol()== _Symbol && OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL) 
             {
              PrezziOrdiniApertiSell += OrderOpenPrice();
              NumeroOrdiniApertiSell++;
             }
        }
     }

//Comment("Prezzo Buy: ",PrezziOrdiniApertiBuy," Numero Buy: ",NumeroOrdiniApertiBuy," Prezzo sell: ",PrezziOrdiniApertiSell," Numero Sell: ",NumeroOrdiniApertiSell);


  if ( NumeroOrdiniApertiBuy > 0 )
  {
  double PrezzoMedio = PrezziOrdiniApertiBuy / NumeroOrdiniApertiBuy;
  AverageTrailingPositions(PrezzoMedio, OP_BUY);
  }
  else
  {
  HLineMove(0,"AverageTrailingBuy",EMPTY_VALUE);
  }
  
  if ( NumeroOrdiniApertiSell > 0 )
  {
  double PrezzoMedio = PrezziOrdiniApertiSell / NumeroOrdiniApertiSell;
  AverageTrailingPositions(PrezzoMedio, OP_SELL);
  }
  else
  {
  HLineMove(0,"AverageTrailingSell",EMPTY_VALUE);
  }
  
  }
//+------------------------------------------------------------------+
//| Ñîïðîâîæäåíèå ïîçèöèè ïðîñòûì òðàëîì                             |
//+------------------------------------------------------------------+
  void AverageTrailingPositions(double PrezzoMedio, int tipo) 
  {
   double pBid, pAsk, pp;
   
   ControlloChiusuraAverageTrailing(tipo);
//----
   pp= SymbolInfoDouble(_Symbol,SYMBOL_POINT);
     if (tipo==OP_BUY) 
     {
      pBid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
        if (!AverageOnlyInProfit || (pBid-PrezzoMedio)>(AverageTrailingStop+AverageBrokerCommission)*pp) 
        {
           if (ObjectGetDouble(0,"AverageTrailingBuy",OBJPROP_PRICE) <pBid-(AverageTrailingStop+AverageTrailingStep-1)*pp || ObjectGetDouble(0,"AverageTrailingBuy",OBJPROP_PRICE) == EMPTY_VALUE) 
           {
            AverageModifyStopLoss(pBid-AverageTrailingStop*pp, OP_BUY);
            return;
           }
        }
     }
     if (tipo==OP_SELL) 
     {
      pAsk=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
        if (!AverageOnlyInProfit || PrezzoMedio-pAsk>(AverageTrailingStop+AverageBrokerCommission)*pp) 
        {
           if ( ObjectGetDouble(0,"AverageTrailingSell",OBJPROP_PRICE) >pAsk+(AverageTrailingStop+AverageTrailingStep-1)*pp || ObjectGetDouble(0,"AverageTrailingSell",OBJPROP_PRICE) == EMPTY_VALUE) 
           {
            AverageModifyStopLoss(pAsk+AverageTrailingStop*pp, OP_SELL);
            return;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Ïåðåíîñ óðîâíÿ StopLoss                                          |
//| Ïàðàìåòðû:                                                       |
//|   ldStopLoss - óðîâåíü StopLoss                                  |
//+------------------------------------------------------------------+
  void AverageModifyStopLoss(double ldStopLoss,int tipo) 
  {
   bool fm;
   fm= HLineMove(0,((tipo == OP_BUY)?"AverageTrailingBuy":"AverageTrailingSell"),ldStopLoss);

  }

   void ControlloChiusuraAverageTrailing(int tipo)
   {
      if ( tipo == OP_BUY && Bid_ < ObjectGetDouble(0,"AverageTrailingBuy",OBJPROP_PRICE) && ObjectGetDouble(0,"AverageTrailingBuy",OBJPROP_PRICE) != EMPTY_VALUE )
      {
      EliminaOrdiniFifo(MagicNumber,tipo);
      }
      if ( tipo == OP_SELL && Ask_ > ObjectGetDouble(0,"AverageTrailingSell",OBJPROP_PRICE) && ObjectGetDouble(0,"AverageTrailingSell",OBJPROP_PRICE) != EMPTY_VALUE  )
      {
      EliminaOrdiniFifo(MagicNumber,tipo);
      }
   }









bool LabelCreate(const long              chart_ID=0,               // chart's ID
                 const string            name="Label",             // label name
                 const int               sub_window=0,             // subwindow index
                 const int               x=0,                      // X coordinate
                 const int               y=0,                      // Y coordinate
                 const ENUM_BASE_CORNER  corner=CORNER_LEFT_UPPER, // chart corner for anchoring
                 const string            text="Label",             // text
                 const string            font="Arial",             // font
                 const int               font_size=10,             // font size
                 const color             clr=clrRed,               // color
                 const double            angle=0.0,                // text slope
                 const ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT_UPPER, // anchor type
                 const bool              back=false,               // in the background
                 const bool              selection=false,          // highlight to move
                 const bool              hidden=true,              // hidden in the object list
                 const long              z_order=0)                // priority for mouse click
  {
//--- reset the error value
   ResetLastError();
//--- create a text label
   if(!ObjectCreate(chart_ID,name,OBJ_LABEL,sub_window,0,0))
     {
      return(false);
     }
//--- set label coordinates
   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
//--- set the chart's corner, relative to which point coordinates are defined
   ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
//--- set the text
   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);
//--- set text font
   ObjectSetString(chart_ID,name,OBJPROP_FONT,font);
//--- set font size
   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size);
//--- set the slope angle of the text
   ObjectSetDouble(chart_ID,name,OBJPROP_ANGLE,angle);
//--- set anchor type
   ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,anchor);
//--- set color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the label by mouse
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Move the text label                                              |
//+------------------------------------------------------------------+
bool LabelMove(const long   chart_ID=0,   // chart's ID
               const string name="Label", // label name
               const int    x=0,          // X coordinate
               const int    y=0)          // Y coordinate
  {
//--- reset the error value
   ResetLastError();
//--- move the text label
   if(!ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x))
     {
      return(false);
     }
   if(!ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y))
     {
      return(false);
     }
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Change corner of the chart for binding the label                 |
//+------------------------------------------------------------------+
bool LabelChangeCorner(const long             chart_ID=0,               // chart's ID
                       const string           name="Label",             // label name
                       const ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER) // chart corner for anchoring
  {
//--- reset the error value
   ResetLastError();
//--- change anchor corner
   if(!ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner))
     {
      return(false);
     }
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Change the object text                                           |
//+------------------------------------------------------------------+
bool LabelTextChange(const long   chart_ID=0,   // chart's ID
                     const string name="Label", // object name
                     const string text="Text")  // text
  {
//--- reset the error value
   ResetLastError();
//--- change object text
   if(!ObjectSetString(chart_ID,name,OBJPROP_TEXT,text))
     {
      return(false);
     }
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Delete a text label                                              |
//+------------------------------------------------------------------+
bool LabelDelete(const long   chart_ID=0,   // chart's ID
                 const string name="Label") // label name
  {
//--- reset the error value
   ResetLastError();
//--- delete the label
   if(!ObjectDelete(chart_ID,name))
     {
      return(false);
     }
//--- successful execution
   return(true);
  }



bool ButtonDelete(const long   chart_ID=0,    // chart's ID
                  const string name="Button") // button name
  {
//--- reset the error value
   ResetLastError();
//--- delete the button
   if(!ObjectDelete(chart_ID,name))
     {
      return(false);
     }
//--- successful execution
   return(true);
  }




bool EditCreate(const long             chart_ID=0,               // chart's ID
                const string           name="Edit",              // object name
                const int              sub_window=0,             // subwindow index
                const int              x=0,                      // X coordinate
                const int              y=0,                      // Y coordinate
                const int              width=50,                 // width
                const int              height=18,                // height
                const string           text="Text",              // text
                const string           font="Arial",             // font
                const int              font_size=10,             // font size
                const ENUM_ALIGN_MODE  align=ALIGN_CENTER,       // alignment type
                const bool             read_only=false,          // ability to edit
                const ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER, // chart corner for anchoring
                const color            clr=clrBlack,             // text color
                const color            back_clr=clrWhite,        // background color
                const color            border_clr=clrNONE,       // border color
                const bool             back=false,               // in the background
                const bool             selection=false,          // highlight to move
                const bool             hidden=true,              // hidden in the object list
                const long             z_order=0)                // priority for mouse click
  {
//--- reset the error value
   ResetLastError();
//--- create edit field
   if(!ObjectCreate(chart_ID,name,OBJ_EDIT,sub_window,0,0))
     {
      return(false);
     }
//--- set object coordinates
   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
//--- set object size
   ObjectSetInteger(chart_ID,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(chart_ID,name,OBJPROP_YSIZE,height);
//--- set the text
   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);
//--- set text font
   ObjectSetString(chart_ID,name,OBJPROP_FONT,font);
//--- set font size
   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size);
//--- set the type of text alignment in the object
   ObjectSetInteger(chart_ID,name,OBJPROP_ALIGN,align);
//--- enable (true) or cancel (false) read-only mode
   ObjectSetInteger(chart_ID,name,OBJPROP_READONLY,read_only);
//--- set the chart's corner, relative to which object coordinates are defined
   ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
//--- set text color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set background color
   ObjectSetInteger(chart_ID,name,OBJPROP_BGCOLOR,back_clr);
//--- set border color
   ObjectSetInteger(chart_ID,name,OBJPROP_BORDER_COLOR,border_clr);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the label by mouse
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Move Edit object                                                 |
//+------------------------------------------------------------------+
bool EditMove(const long   chart_ID=0,  // chart's ID
              const string name="Edit", // object name
              const int    x=0,         // X coordinate
              const int    y=0)         // Y coordinate
  {
//--- reset the error value
   ResetLastError();
//--- move the object
   if(!ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x))
     {
      return(false);
     }
   if(!ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y))
     {
      return(false);
     }
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Resize Edit object                                               |
//+------------------------------------------------------------------+
bool EditChangeSize(const long   chart_ID=0,  // chart's ID
                    const string name="Edit", // object name
                    const int    width=0,     // width
                    const int    height=0)    // height
  {
//--- reset the error value
   ResetLastError();
//--- change the object size
   if(!ObjectSetInteger(chart_ID,name,OBJPROP_XSIZE,width))
     {
      return(false);
     }
   if(!ObjectSetInteger(chart_ID,name,OBJPROP_YSIZE,height))
     {
      return(false);
     }
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Change Edit object's text                                        |
//+------------------------------------------------------------------+
bool EditTextChange(const long   chart_ID=0,  // chart's ID
                    const string name="Edit", // object name
                    const string text="Text") // text
  {
//--- reset the error value
   ResetLastError();
//--- change object text
   if(!ObjectSetString(chart_ID,name,OBJPROP_TEXT,text))
     {
      return(false);
     }
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Return Edit object text                                          |
//+------------------------------------------------------------------+
bool EditTextGet(string      &text,        // text
                 const long   chart_ID=0,  // chart's ID
                 const string name="Edit") // object name
  {
//--- reset the error value
   ResetLastError();
//--- get object text
   if(!ObjectGetString(chart_ID,name,OBJPROP_TEXT,0,text))
     {
      return(false);
     }
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Delete Edit object                                               |
//+------------------------------------------------------------------+
bool EditDelete(const long   chart_ID=0,  // chart's ID
                const string name="Edit") // object name
  {
//--- reset the error value
   ResetLastError();
//--- delete the label
   if(!ObjectDelete(chart_ID,name))
     {
      return(false);
     }
//--- successful execution
   return(true);
  }



bool RectLabelCreate(const long             chart_ID=0,               // chart's ID
                     const string           name="RectLabel",         // label name
                     const int              sub_window=0,             // subwindow index
                     const int              x=0,                      // X coordinate
                     const int              y=0,                      // Y coordinate
                     const int              width=50,                 // width
                     const int              height=18,                // height
                     const color            back_clr=C'236,233,216',  // background color
                     const ENUM_BORDER_TYPE border=BORDER_SUNKEN,     // border type
                     const ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER, // chart corner for anchoring
                     const color            clr=clrRed,               // flat border color (Flat)
                     const ENUM_LINE_STYLE  style=STYLE_SOLID,        // flat border style
                     const int              line_width=1,             // flat border width
                     const bool             back=false,               // in the background
                     const bool             selection=false,          // highlight to move
                     const bool             hidden=true,              // hidden in the object list
                     const long             z_order=0)                // priority for mouse click
  {
//--- reset the error value
   ResetLastError();
//--- create a rectangle label
   if(!ObjectCreate(chart_ID,name,OBJ_RECTANGLE_LABEL,sub_window,0,0))
     {
      return(false);
     }
//--- set label coordinates
   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
//--- set label size
   ObjectSetInteger(chart_ID,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(chart_ID,name,OBJPROP_YSIZE,height);
//--- set background color
   ObjectSetInteger(chart_ID,name,OBJPROP_BGCOLOR,back_clr);
//--- set border type
   ObjectSetInteger(chart_ID,name,OBJPROP_BORDER_TYPE,border);
//--- set the chart's corner, relative to which point coordinates are defined
   ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
//--- set flat border color (in Flat mode)
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set flat border line style
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set flat border width
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,line_width);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the label by mouse
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Move rectangle label                                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Delete the rectangle label                                       |
//+------------------------------------------------------------------+
bool RectLabelDelete(const long   chart_ID=0,       // chart's ID
                     const string name="RectLabel") // label name
  {
//--- reset the error value
   ResetLastError();
//--- delete the label
   if(!ObjectDelete(chart_ID,name))
     {
      return(false);
     }
//--- successful execution
   return(true);
  }










bool IsTesting()
{
return MQLInfoInteger(MQL_TESTER);
}


bool IsDemo()
{
return AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO ;
}



double Bid()
{
return SymbolInfoDouble(_Symbol,SYMBOL_BID);
}
double Ask()
{
return SymbolInfoDouble(_Symbol,SYMBOL_ASK);
}





double OrderStopLoss()
{
return PositionGetDouble(POSITION_SL);
}
double OrderTakeProfit()
{
return PositionGetDouble(POSITION_TP);
}
string OrderSymbol()
{
return PositionGetString(POSITION_SYMBOL);
}
ulong OrderMagicNumber()
{
return PositionGetInteger(POSITION_MAGIC);
}

datetime OrderOpenTime()
{
return PositionGetInteger(POSITION_TIME);
}

double OrderLots()
{
return PositionGetDouble(POSITION_VOLUME); 
}

double OrderProfit()
{
return PositionGetDouble(POSITION_PROFIT); 
}


double OrderOpenPrice()
{
return PositionGetDouble(POSITION_PRICE_OPEN); 
}

int OrderType()
{
return PositionGetInteger(POSITION_TYPE);
}

ulong OrderTicket()
{
return PositionGetInteger(POSITION_TICKET);
}


double OrderSwap()
{
return PositionGetDouble(POSITION_SWAP); 
}
double OrderCommission()
{
return PositionGetDouble(POSITION_COMMISSION); 
}


int Hour()
{
MqlDateTime StrutturaTemporale;
TimeCurrent(StrutturaTemporale);
return (StrutturaTemporale.hour);
}

int Minute()
{
MqlDateTime StrutturaTemporale;
TimeCurrent(StrutturaTemporale);
return (StrutturaTemporale.min);
}


int DayOfWeek()
{
MqlDateTime StrutturaTemporale;
TimeCurrent(StrutturaTemporale);
return (StrutturaTemporale.day_of_week);
}





bool IsTradeAllowed()
{
return MQLInfoInteger(MQL_TRADE_ALLOWED);
}

bool IsVisualMode()
{
return MQLInfoInteger(MQL_VISUAL_MODE);
}



double AccountEquity()
{
return AccountInfoDouble(ACCOUNT_EQUITY);
}

double AccountBalance()
{
return AccountInfoDouble(ACCOUNT_BALANCE);
}



string AccountName()
{
return AccountInfoString(ACCOUNT_NAME);
}


string AccountCurrency()
{
return AccountInfoString(ACCOUNT_CURRENCY);
}

string AccountServer()
{
return AccountInfoString(ACCOUNT_SERVER);
}


string WindowExpertName()
{
return MQLInfoString(MQL_PROGRAM_NAME);
}





double iatr(string Simbolo, ENUM_TIMEFRAMES AtrTimeframeInt,int AtrPeriodsInt, int Posizione)
{

double AtrArray[];

//proprieta
int AtrProprietis = iATR(_Symbol,AtrTimeframeInt,AtrPeriodsInt);
// Numero Di Posizione
if (CopyBuffer(AtrProprietis,0,Posizione,1,AtrArray) < 1)
{
   Sleep(5000);
   if (CopyBuffer(AtrProprietis,0,Posizione,1,AtrArray) < 1)
   return -1;
}

return AtrArray[0];
}



double ibands(int QualeBanda, int MomentoSegnale)
{
double BBArray[];

//proprieta
int BBProprietis = iBands(_Symbol,BollingerBandsTimeframe,BollingerBandsPeriod,0,BollingerBandsDeviations,BollingerBandsPrice);
// Numero Di Posizione
if (CopyBuffer(BBProprietis,QualeBanda,MomentoSegnale,1,BBArray) < 1)
{
   Sleep(5000);
   if (CopyBuffer(BBProprietis,QualeBanda,MomentoSegnale,1,BBArray) < 1)
   return -1;
}

return BBArray[0];
}




double iadx(int Posizione)
{
double adxArray[];

//proprieta
int AdxProprietis = iADX(_Symbol,AdxTimeframe,AdxPeriod);
// Numero Di Posizione
if (CopyBuffer(AdxProprietis,0,Posizione,1,adxArray) < 1)
{
   Sleep(5000);
   if (CopyBuffer(AdxProprietis,0,Posizione,1,adxArray) < 1)
   return -1;
}

return adxArray[0];
}




double imaFast(int Posizione)
{
double imaArray[];

//proprieta
int ImaProprietis = iMA(_Symbol,MaTimeframe,FastMaPeriod,0,MaMethod,MaPrice);
// Numero Di Posizione
if (CopyBuffer(ImaProprietis,0,Posizione,1,imaArray) < 1)
{
   Sleep(5000);
   if (CopyBuffer(ImaProprietis,0,Posizione,1,imaArray) < 1)
   return -1;
}
return imaArray[0];
}


double imaLow(int Posizione)
{
double imaArray[];

//proprieta
int ImaProprietis = iMA(_Symbol,MaTimeframe,SlowMaPeriod,0,MaMethod,MaPrice);
// Numero Di Posizione
if (CopyBuffer(ImaProprietis,0,Posizione,1,imaArray) < 1)
{
   Sleep(5000);
   if (CopyBuffer(ImaProprietis,0,Posizione,1,imaArray) < 1)
   return -1;
}

return imaArray[0];
}






void ObjectSetText(string nome, string valoretesto,color colore = clrNONE)
{
ObjectSetString(0,nome,OBJPROP_TEXT,valoretesto);
if (colore != clrNONE)
{
ObjectSetInteger(0,nome,OBJPROP_COLOR,colore);
}
}




double AccountFreeMarginCheck(string simbol,int tipoordine,double lotsizet)
{
ENUM_ORDER_TYPE tipor = (ENUM_ORDER_TYPE) tipoordine;

   double margin=EMPTY_VALUE;
//---
   if(!OrderCalcMargin(tipor,simbol,lotsizet, (tipor == ORDER_TYPE_BUY)?Ask():Bid(),margin))
      return(EMPTY_VALUE);
//---
   return(margin);
}

//+------------------------------------------------------------------+
//|         tabe marboot be EXPIRATION                               |
//+------------------------------------------------------------------+
bool CheckExpiration()
{
   datetime expiration = StringToTime(EXPIRATION_DATE); // تبدیل تاریخ به datetime
   datetime current = TimeCurrent(); // زمان فعلی
   return current > expiration; // اگر زمان فعلی از تاریخ انقضا گذشته باشد، true برمی‌گرداند
}






