//+------------------------------------------------------------------+
//|                                                EMAMonitor.mq5    |
//| Research observer: strategy families, features and forward stats  |
//| This EA is diagnostic only. It never sends orders.                |
//+------------------------------------------------------------------+
#property strict
#property version   "2.00"
#property description "Non-trading research observer for independent strategy-family signals."

input int      InpFastEMA       = 15;
input int      InpEMA50         = 50;
input int      InpEMA100        = 100;
input int      InpEMA200        = 200;
input int      InpStochK        = 5;
input int      InpStochD        = 3;
input int      InpStochSlowing  = 2;
input double   InpOverbought    = 80.0;
input double   InpOversold      = 20.0;
input int      InpRSIPeriod     = 14;
input double   InpRSIOverbought = 70.0;
input double   InpRSIOversold   = 30.0;
input int      InpATRPeriod     = 14;
input int      InpBandsPeriod   = 20;
input double   InpBandsDev      = 2.0;
input int      InpMACDFast      = 12;
input int      InpMACDSlow      = 26;
input int      InpMACDSignal    = 9;
input int      InpBreakoutBars  = 20;
input double   InpGridATRStep   = 1.0;
input int      InpHistoryBars   = 2000;
input int      InpOutcomeBars   = 40;
input bool     InpLogEveryBar   = true;
input string   InpCSVFile       = "EMAMonitor_Research.csv";

int hFast=INVALID_HANDLE, h50=INVALID_HANDLE, h100=INVALID_HANDLE, h200=INVALID_HANDLE;
int hStoch=INVALID_HANDLE, hRSI=INVALID_HANDLE, hATR=INVALID_HANDLE;
int hBands=INVALID_HANDLE, hMACD=INVALID_HANDLE;
int csvHandle=INVALID_HANDLE;
datetime lastBarTime=0;
bool freshResearchFile=true;

struct SignalTrack
{
   datetime time;
   string model;
   int direction;
   double entry;
   int barsSeen;
   double mfe;
   double mae;
};
SignalTrack tracks[];

double PointSize() { return _Point; }

bool ReadValue(const int handle,const int buffer,const int shift,double &value)
{
   double temp[];
   ArraySetAsSeries(temp,true);
   if(CopyBuffer(handle,buffer,shift,1,temp)!=1) return false;
   value=temp[0];
   return (value!=EMPTY_VALUE);
}

bool ReadBar(const int shift,MqlRates &bar)
{
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   if(CopyRates(_Symbol,_Period,shift,1,rates)!=1) return false;
   bar=rates[0];
   return true;
}

string TFName() { return EnumToString((ENUM_TIMEFRAMES)_Period); }
string BoolText(const bool v) { return (v ? "1" : "0"); }

void WriteHeader()
{
   if(csvHandle==INVALID_HANDLE || FileSize(csvHandle)>0) return;
   FileWrite(csvHandle,
      "event_time","symbol","timeframe","row_type","model_id","direction",
      "open","high","low","close","ema15","ema50","ema100","ema200",
      "atr_points","rsi","bb_upper","bb_middle","bb_lower","macd_main","macd_signal",
      "stoch_main","stoch_signal","ema_bull_stack","ema_bear_stack",
      "touch_ema15","touch_ema50","touch_ema100","touch_ema200",
      "trend_pullback_buy","trend_pullback_sell","ema_cross_buy","ema_cross_sell",
      "stoch_reversal_buy","stoch_reversal_sell","rsi_reversal_buy","rsi_reversal_sell",
      "bb_reversal_buy","bb_reversal_sell","breakout_buy","breakout_sell",
      "macd_momentum_buy","macd_momentum_sell","atr_expansion","grid_step_points",
      "mfe_points","mae_points","outcome_bars");
   FileFlush(csvHandle);
}

void AddTrack(const datetime t,const string model,const int direction,const double entry)
{
   int n=ArraySize(tracks);
   if(ArrayResize(tracks,n+1)!=n+1) return;
   tracks[n].time=t; tracks[n].model=model; tracks[n].direction=direction;
   tracks[n].entry=entry; tracks[n].barsSeen=0; tracks[n].mfe=0.0; tracks[n].mae=0.0;
}

void WriteOutcome(const SignalTrack &tr)
{
   if(csvHandle==INVALID_HANDLE) return;
   // 48 columns total: six identifying fields, 39 empty market/signal fields, three outcome fields.
   FileWrite(csvHandle,
      TimeToString(tr.time,TIME_DATE|TIME_MINUTES),_Symbol,TFName(),"OUTCOME",
      tr.model,(tr.direction==1 ? "BUY" : "SELL"),
      "","","","","","","","","","","","","","","","","","","","","","","","","","","","","","","","","","","","","","","",
      DoubleToString(tr.mfe,1),DoubleToString(tr.mae,1),tr.barsSeen);
}

void UpdateTracks(const MqlRates &bar)
{
   for(int i=ArraySize(tracks)-1;i>=0;i--)
   {
      double favourable,adverse;
      if(tracks[i].direction==1)
      {
         favourable=(bar.high-tracks[i].entry)/PointSize();
         adverse=(tracks[i].entry-bar.low)/PointSize();
      }
      else
      {
         favourable=(tracks[i].entry-bar.low)/PointSize();
         adverse=(bar.high-tracks[i].entry)/PointSize();
      }
      if(favourable>tracks[i].mfe) tracks[i].mfe=favourable;
      if(adverse>tracks[i].mae) tracks[i].mae=adverse;
      tracks[i].barsSeen++;
      if(tracks[i].barsSeen>=InpOutcomeBars)
      {
         SignalTrack finished=tracks[i];
         WriteOutcome(finished);
         for(int j=i;j<ArraySize(tracks)-1;j++) tracks[j]=tracks[j+1];
         ArrayResize(tracks,ArraySize(tracks)-1);
      }
   }
}

void LogBar(const MqlRates &bar,const string rowType,const string model,const string direction,
   const double e15,const double e50,const double e100,const double e200,
   const double atr,const double rsi,const double upper,const double middle,const double lower,
   const double macdMain,const double macdSignal,const double stMain,const double stSignal,
   const bool bull,const bool bear,const bool t15,const bool t50,const bool t100,const bool t200,
   const bool pbBuy,const bool pbSell,const bool crossBuy,const bool crossSell,
   const bool stBuy,const bool stSell,const bool rsiBuy,const bool rsiSell,
   const bool bbBuy,const bool bbSell,const bool boBuy,const bool boSell,
   const bool macdBuy,const bool macdSell,const bool atrExpand,const double gridStep)
{
   if(csvHandle==INVALID_HANDLE) return;
   FileWrite(csvHandle,
      TimeToString(bar.time,TIME_DATE|TIME_MINUTES),_Symbol,TFName(),rowType,model,direction,
      DoubleToString(bar.open,_Digits),DoubleToString(bar.high,_Digits),
      DoubleToString(bar.low,_Digits),DoubleToString(bar.close,_Digits),
      DoubleToString(e15,_Digits),DoubleToString(e50,_Digits),
      DoubleToString(e100,_Digits),DoubleToString(e200,_Digits),
      DoubleToString(atr/PointSize(),1),DoubleToString(rsi,2),
      DoubleToString(upper,_Digits),DoubleToString(middle,_Digits),DoubleToString(lower,_Digits),
      DoubleToString(macdMain,_Digits),DoubleToString(macdSignal,_Digits),
      DoubleToString(stMain,2),DoubleToString(stSignal,2),BoolText(bull),BoolText(bear),
      BoolText(t15),BoolText(t50),BoolText(t100),BoolText(t200),
      BoolText(pbBuy),BoolText(pbSell),BoolText(crossBuy),BoolText(crossSell),
      BoolText(stBuy),BoolText(stSell),BoolText(rsiBuy),BoolText(rsiSell),
      BoolText(bbBuy),BoolText(bbSell),BoolText(boBuy),BoolText(boSell),
      BoolText(macdBuy),BoolText(macdSell),BoolText(atrExpand),
      DoubleToString(gridStep/PointSize(),1),"","","");
}

void AddIfSignal(const bool condition,const datetime t,const string model,const int direction,const double entry)
{
   if(condition) AddTrack(t,model,direction,entry);
}

void ProcessBar(const int shift,const bool collectOutcomes)
{
   MqlRates bar,prev;
   if(!ReadBar(shift,bar) || !ReadBar(shift+1,prev)) return;

   double e15,e50,e100,e200,stMain,stSignal,stPrev,stSigPrev,rsi,rsiPrev,atr,atrPrev;
   double upper,middle,lower,macdMain,macdSignal,macdPrev,macdSigPrev;
   if(!ReadValue(hFast,0,shift,e15) || !ReadValue(h50,0,shift,e50) ||
      !ReadValue(h100,0,shift,e100) || !ReadValue(h200,0,shift,e200) ||
      !ReadValue(hStoch,0,shift,stMain) || !ReadValue(hStoch,1,shift,stSignal) ||
      !ReadValue(hStoch,0,shift+1,stPrev) || !ReadValue(hStoch,1,shift+1,stSigPrev) ||
      !ReadValue(hRSI,0,shift,rsi) || !ReadValue(hRSI,0,shift+1,rsiPrev) ||
      !ReadValue(hATR,0,shift,atr) || !ReadValue(hATR,0,shift+1,atrPrev) ||
      !ReadValue(hBands,0,shift, middle) || !ReadValue(hBands,1,shift, upper) ||
      !ReadValue(hBands,2,shift, lower) ||
      !ReadValue(hMACD,0,shift,macdMain) || !ReadValue(hMACD,1,shift,macdSignal) ||
      !ReadValue(hMACD,0,shift+1,macdPrev) || !ReadValue(hMACD,1,shift+1,macdSigPrev))
      return;

   bool bull=(e50>e100 && e100>e200);
   bool bear=(e50<e100 && e100<e200);
   bool t15=(bar.low<=e15 && bar.high>=e15);
   bool t50=(bar.low<=e50 && bar.high>=e50);
   bool t100=(bar.low<=e100 && bar.high>=e100);
   bool t200=(bar.low<=e200 && bar.high>=e200);
   bool stCrossUp=(stPrev<=stSigPrev && stMain>stSignal);
   bool stCrossDown=(stPrev>=stSigPrev && stMain<stSignal);

   bool pbBuy=(bull && t15 && bar.close>e15 && bar.close>bar.open);
   bool pbSell=(bear && t15 && bar.close<e15 && bar.close<bar.open);
   bool crossBuy=(e15>e50 && prev.close<=e15 && bar.close>e15);
   bool crossSell=(e15<e50 && prev.close>=e15 && bar.close<e15);
   bool stBuy=(stCrossUp && stPrev<InpOversold);
   bool stSell=(stCrossDown && stPrev>InpOverbought);
   bool rsiBuy=(rsiPrev<InpRSIOversold && rsi>=InpRSIOversold);
   bool rsiSell=(rsiPrev>InpRSIOverbought && rsi<=InpRSIOverbought);
   bool bbBuy=(bar.low<=lower && bar.close>lower);
   bool bbSell=(bar.high>=upper && bar.close<upper);
   bool boBuy=false,boSell=false;
   double highs[],lows[];
   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   if(CopyHigh(_Symbol,_Period,shift+1,InpBreakoutBars,highs)==InpBreakoutBars &&
      CopyLow(_Symbol,_Period,shift+1,InpBreakoutBars,lows)==InpBreakoutBars)
   {
      double hh=highs[ArrayMaximum(highs)],ll=lows[ArrayMinimum(lows)];
      boBuy=(bar.close>hh); boSell=(bar.close<ll);
   }
   bool macdBuy=(macdMain>macdSignal && macdPrev<=macdSigPrev);
   bool macdSell=(macdMain<macdSignal && macdPrev>=macdSigPrev);
   bool atrExpand=(atrPrev>0.0 && atr>atrPrev*1.10);
   double gridStep=atr*InpGridATRStep;

   if(InpLogEveryBar || pbBuy || pbSell || crossBuy || crossSell || stBuy || stSell ||
      rsiBuy || rsiSell || bbBuy || bbSell || boBuy || boSell || macdBuy || macdSell ||
      t15 || t50 || t100 || t200)
      LogBar(bar,"BAR_FEATURES","ALL","NONE",e15,e50,e100,e200,atr,rsi,upper,middle,lower,
         macdMain,macdSignal,stMain,stSignal,bull,bear,t15,t50,t100,t200,
         pbBuy,pbSell,crossBuy,crossSell,stBuy,stSell,rsiBuy,rsiSell,bbBuy,bbSell,
         boBuy,boSell,macdBuy,macdSell,atrExpand,gridStep);

   if(collectOutcomes)
   {
      // Update existing tracks before adding today's signals. This avoids counting the
      // signal candle's high/low as post-entry movement when entry is assumed at close.
      UpdateTracks(bar);
      AddIfSignal(pbBuy,bar.time,"EMA_TREND_PULLBACK",1,bar.close);
      AddIfSignal(pbSell,bar.time,"EMA_TREND_PULLBACK",-1,bar.close);
      AddIfSignal(crossBuy,bar.time,"EMA_CROSS",1,bar.close);
      AddIfSignal(crossSell,bar.time,"EMA_CROSS",-1,bar.close);
      AddIfSignal(stBuy,bar.time,"STOCH_REVERSAL",1,bar.close);
      AddIfSignal(stSell,bar.time,"STOCH_REVERSAL",-1,bar.close);
      AddIfSignal(rsiBuy,bar.time,"RSI_REVERSAL",1,bar.close);
      AddIfSignal(rsiSell,bar.time,"RSI_REVERSAL",-1,bar.close);
      AddIfSignal(bbBuy,bar.time,"BOLLINGER_REENTRY",1,bar.close);
      AddIfSignal(bbSell,bar.time,"BOLLINGER_REENTRY",-1,bar.close);
      AddIfSignal(boBuy,bar.time,"RANGE_BREAKOUT",1,bar.close);
      AddIfSignal(boSell,bar.time,"RANGE_BREAKOUT",-1,bar.close);
      AddIfSignal(macdBuy,bar.time,"MACD_MOMENTUM",1,bar.close);
      AddIfSignal(macdSell,bar.time,"MACD_MOMENTUM",-1,bar.close);
   }
}

int OnInit()
{
   if(InpHistoryBars<10 || InpOutcomeBars<1 || InpBreakoutBars<2 ||
      InpGridATRStep<=0.0 || InpBandsPeriod<2)
   {
      Print("EMAMonitor: invalid input parameter(s).");
      return INIT_PARAMETERS_INCORRECT;
   }

   hFast=iMA(_Symbol,_Period,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   h50=iMA(_Symbol,_Period,InpEMA50,0,MODE_EMA,PRICE_CLOSE);
   h100=iMA(_Symbol,_Period,InpEMA100,0,MODE_EMA,PRICE_CLOSE);
   h200=iMA(_Symbol,_Period,InpEMA200,0,MODE_EMA,PRICE_CLOSE);
   hStoch=iStochastic(_Symbol,_Period,InpStochK,InpStochD,InpStochSlowing,MODE_SMA,STO_LOWHIGH);
   hRSI=iRSI(_Symbol,_Period,InpRSIPeriod,PRICE_CLOSE);
   hATR=iATR(_Symbol,_Period,InpATRPeriod);
   hBands=iBands(_Symbol,_Period,InpBandsPeriod,0,InpBandsDev,PRICE_CLOSE);
   hMACD=iMACD(_Symbol,_Period,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE);

   if(hFast==INVALID_HANDLE || h50==INVALID_HANDLE || h100==INVALID_HANDLE ||
      h200==INVALID_HANDLE || hStoch==INVALID_HANDLE || hRSI==INVALID_HANDLE ||
      hATR==INVALID_HANDLE || hBands==INVALID_HANDLE || hMACD==INVALID_HANDLE)
   {
      Print("EMAMonitor: failed to create indicator handle(s). Error=",GetLastError());
      return INIT_FAILED;
   }

   csvHandle=FileOpen(InpCSVFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(csvHandle==INVALID_HANDLE)
   {
      Print("EMAMonitor: could not open research CSV. Error=",GetLastError());
      return INIT_FAILED;
   }
   freshResearchFile=(FileSize(csvHandle)==0);
   FileSeek(csvHandle,0,SEEK_END);
   WriteHeader();

   if(freshResearchFile)
   {
      int bars=Bars(_Symbol,_Period);
      int scan=MathMin(InpHistoryBars,bars-2);
      // Historical bars are processed oldest-to-newest for consistent outcome tracking.
      for(int shift=scan;shift>=1;shift--)
         ProcessBar(shift,true);
   }

   lastBarTime=iTime(_Symbol,_Period,0);
   FileFlush(csvHandle);
   Print("EMAMonitor v2.00 started: ",_Symbol," ",TFName(),
      ". Diagnostic only; no orders. Output: MQL5/Files/",InpCSVFile);
   return INIT_SUCCEEDED;
}

void OnTick()
{
   datetime t=iTime(_Symbol,_Period,0);
   if(t==0 || t==lastBarTime) return;
   lastBarTime=t;
   ProcessBar(1,true);
   if(csvHandle!=INVALID_HANDLE) FileFlush(csvHandle);
}

void OnDeinit(const int reason)
{
   if(csvHandle!=INVALID_HANDLE)
   {
      FileFlush(csvHandle);
      FileClose(csvHandle);
      csvHandle=INVALID_HANDLE;
   }
   if(hFast!=INVALID_HANDLE) IndicatorRelease(hFast);
   if(h50!=INVALID_HANDLE) IndicatorRelease(h50);
   if(h100!=INVALID_HANDLE) IndicatorRelease(h100);
   if(h200!=INVALID_HANDLE) IndicatorRelease(h200);
   if(hStoch!=INVALID_HANDLE) IndicatorRelease(hStoch);
   if(hRSI!=INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hATR!=INVALID_HANDLE) IndicatorRelease(hATR);
   if(hBands!=INVALID_HANDLE) IndicatorRelease(hBands);
   if(hMACD!=INVALID_HANDLE) IndicatorRelease(hMACD);
   Print("EMAMonitor: stopped.");
}
