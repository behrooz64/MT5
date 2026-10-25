//+------------------------------------------------------------------+
//|                                                EMAMonitor_v3.mq5    |
//| Research observer v3.10 - validated forward collector and simulations          |
//+------------------------------------------------------------------+
#property strict
#property version   "3.10"
#property description "Research-only market data collector. Configure timeframe per instance; does not send or manage orders."

input ENUM_TIMEFRAMES InpCollectTimeframe = PERIOD_CURRENT; // Set to M1 or M5 per EA instance
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
input int      InpADXPeriod     = 14;
input int      InpBandsPeriod   = 20;
input double   InpBandsDev      = 2.0;
input int      InpMACDFast      = 12;
input int      InpMACDSlow      = 26;
input int      InpMACDSignal    = 9;
input int      InpBreakoutBars  = 20;
input int      InpOutcomeBars   = 40;
input double   InpSimFixedTPPoints = 300.0;
input double   InpSimFixedSLPoints = 300.0;
input double   InpSimATRTPMultiple = 1.5;
input double   InpSimATRSLMultiple = 1.0;
input bool     InpSimTrailingEnabled = true;
input double   InpSimTrailATRMultiple = 1.0;
input int      InpSimMaxBars = 120;
input double   InpSimCostPoints = 30.0;
input double   InpSimBETriggerATRMultiple = 1.0;
input double   InpSimMoneyStopUSD = 25.0; // Approximate simulated stop budget per entry
input double   InpSimAccountBalance = 10000.0; // Assumed balance for percentage-risk simulation
input double   InpSimRiskPercent = 1.0;
input double   InpSimLotSize = 0.01;      // Used only to convert money risk to price distance
input double   InpSimGridStepPoints = 250.0;
input int      InpSimGridMaxAdds = 3;       // Simulated adds after the initial entry; no real orders
input double   InpSimGridTargetPoints = 150.0;
input double   InpSimGridMaxLossPoints = 900.0;
input int      InpHistoryBars   = 2000;
input bool     InpScanHistoryIfFresh = false; // Keep the seven-day forward-test dataset free of historical backfill by default
input bool     InpLogEveryBar   = true;
input string   InpFilePrefix    = "EMAMonitor_v3_1"; // Fresh dataset; preserves v3.00 CSVs untouched

int hFast=INVALID_HANDLE,h50=INVALID_HANDLE,h100=INVALID_HANDLE,h200=INVALID_HANDLE;
int hStoch=INVALID_HANDLE,hRSI=INVALID_HANDLE,hATR=INVALID_HANDLE,hADX=INVALID_HANDLE;
int hBands=INVALID_HANDLE,hMACD=INVALID_HANDLE;
int fBars=INVALID_HANDLE,fEvents=INVALID_HANDLE,fOutcomes=INVALID_HANDLE,fScenarios=INVALID_HANDLE;
datetime lastBarTime=0; // Timestamp of the most recently processed CLOSED bar
datetime lastCurrentBarTime=0; // Current bar timestamp, used only to detect a new bar
bool barsFileWasEmpty=false;

struct Snapshot
{
   MqlRates bar;
   double e15,e50,e100,e200;
   double stMain,stSignal,stPrev,stSigPrev;
   double rsi,rsiPrev,atr,atrPrev,adx,plusDI,minusDI;
   double upper,middle,lower,macdMain,macdSignal,macdPrev,macdSigPrev;
   double priorHigh,priorLow,spreadPoints,tickSize,tickValue;
   bool bull,bear,range;
   bool touch15,touch50,touch100,touch200;
};
struct Track
{
   long id; // linked source event_id, reused as outcome signal_id
   datetime signalTime;
   string eventName;
   int direction; // 1=buy, -1=sell, 0=measure both directions after touch
   double entry;
   int barsSeen;
   double mfePoints,maePoints,upPoints,downPoints;
};
Track tracks[];
struct SimTrack
{
   long eventId;
   datetime signalTime;
   string eventName;
   int direction;
   double entry;
   double atrPrice;
   double fixedTP,fixedSL,atrTP,atrSL;
   double fixedExit,atrExit,trailExit,beExit,moneyExit,rr2Exit,gridExit,pctExit,pyrExit;
   double bestPrice,moneyTP,moneySL,beStop,gridAvgEntry,gridLastAdd,gridTP,gridSL,pctTP,pctSL,pyrAvgEntry,pyrLastAdd,pyrTP,pyrSL;
   int barsSeen;
   int fixedStatus,atrStatus,trailStatus,beStatus,moneyStatus,rr2Status,gridStatus,gridAdds,pctStatus,pyrStatus,pyrAdds;
   bool beActivated;
};
SimTrack simTracks[];
long nextId=1;
long nextEventId=1;
string stateFileName="";
string simStateFileName="";

string PersistentKey(const string suffix)
{
   string key=InpFilePrefix+"_"+SafeName(_Symbol)+"_"+TFName()+"_"+suffix;
   StringReplace(key,"-","_");
   if(StringLen(key)>63) key=StringSubstr(key,0,63);
   return key;
}
long LoadPersistentCounter(const string suffix,const long fallback)
{
   string key=PersistentKey(suffix);
   if(!GlobalVariableCheck(key)) return fallback;
   double value=GlobalVariableGet(key);
   if(value<1.0) return fallback;
   return (long)value;
}
void SavePersistentCounter(const string suffix,const long value)
{
   GlobalVariableSet(PersistentKey(suffix),(double)value);
}

// Recover the largest numeric ID from an existing CSV without changing its contents.
// The first row is treated as a header. CSV fields are consumed in their written order.
long MaxIdInCsv(const string fileName,const int fieldCount,const int idField)
{
   int f=FileOpen(fileName,FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(f==INVALID_HANDLE) return 0;
   // Skip header fields.
   for(int h=0;h<fieldCount && !FileIsEnding(f);h++) FileReadString(f);
   long maxId=0;
   while(!FileIsEnding(f))
   {
      string idText="";
      bool rowHasData=false;
      for(int col=0;col<fieldCount;col++)
      {
         if(FileIsEnding(f)) break;
         string value=FileReadString(f);
         if(value!="") rowHasData=true;
         if(col==idField) idText=value;
      }
      if(!rowHasData) break;
      long id=(long)StringToInteger(idText);
      if(id>maxId) maxId=id;
   }
   FileClose(f);
   return maxId;
}
datetime LoadPersistentBarTime()
{
   string key=PersistentKey("LASTBAR");
   if(!GlobalVariableCheck(key)) return 0;
   return (datetime)GlobalVariableGet(key);
}
void SavePersistentBarTime(const datetime value)
{
   GlobalVariableSet(PersistentKey("LASTBAR"),(double)value);
}

ENUM_TIMEFRAMES CollectTF(){ return (InpCollectTimeframe==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpCollectTimeframe); }
string TFName(){ return EnumToString(CollectTF()); }
string SafeName(string s)
{
   StringReplace(s,"/","_"); StringReplace(s,"\\","_"); StringReplace(s,":","_");
   StringReplace(s," ","_"); StringReplace(s,".","_");
   return s;
}
string MakeFile(const string kind)
{
   return InpFilePrefix+"_"+SafeName(_Symbol)+"_"+TFName()+"_"+kind+".csv";
}
string B(const bool v){ return v ? "1" : "0"; }
double Pts(const double priceMove){ return priceMove/_Point; }

bool ReadVal(const int handle,const int buffer,const int shift,double &v)
{
   double a[]; ArraySetAsSeries(a,true);
   if(CopyBuffer(handle,buffer,shift,1,a)!=1) return false;
   v=a[0]; return v!=EMPTY_VALUE;
}
bool ReadRate(const int shift,MqlRates &bar)
{
   MqlRates a[]; ArraySetAsSeries(a,true);
   if(CopyRates(_Symbol,CollectTF(),shift,1,a)!=1) return false;
   bar=a[0]; return true;
}
bool LoadSnapshot(const int shift,Snapshot &s)
{
   MqlRates prev;
   if(!ReadRate(shift,s.bar) || !ReadRate(shift+1,prev)) return false;
   if(!ReadVal(hFast,0,shift,s.e15) || !ReadVal(h50,0,shift,s.e50) ||
      !ReadVal(h100,0,shift,s.e100) || !ReadVal(h200,0,shift,s.e200) ||
      !ReadVal(hStoch,0,shift,s.stMain) || !ReadVal(hStoch,1,shift,s.stSignal) ||
      !ReadVal(hStoch,0,shift+1,s.stPrev) || !ReadVal(hStoch,1,shift+1,s.stSigPrev) ||
      !ReadVal(hRSI,0,shift,s.rsi) || !ReadVal(hRSI,0,shift+1,s.rsiPrev) ||
      !ReadVal(hATR,0,shift,s.atr) || !ReadVal(hATR,0,shift+1,s.atrPrev) ||
      !ReadVal(hADX,0,shift,s.adx) || !ReadVal(hADX,1,shift,s.plusDI) ||
      !ReadVal(hADX,2,shift,s.minusDI) ||
      !ReadVal(hBands,0,shift,s.middle) || !ReadVal(hBands,1,shift,s.upper) ||
      !ReadVal(hBands,2,shift,s.lower) ||
      !ReadVal(hMACD,0,shift,s.macdMain) || !ReadVal(hMACD,1,shift,s.macdSignal) ||
      !ReadVal(hMACD,0,shift+1,s.macdPrev) || !ReadVal(hMACD,1,shift+1,s.macdSigPrev))
      return false;

   double hs[],ls[]; ArraySetAsSeries(hs,true); ArraySetAsSeries(ls,true);
   if(CopyHigh(_Symbol,CollectTF(),shift+1,InpBreakoutBars,hs)!=InpBreakoutBars ||
      CopyLow(_Symbol,CollectTF(),shift+1,InpBreakoutBars,ls)!=InpBreakoutBars) return false;
   s.priorHigh=hs[ArrayMaximum(hs)]; s.priorLow=ls[ArrayMinimum(ls)];
   s.spreadPoints=(double)s.bar.spread;
   // Some brokers omit historical spread in MqlRates; only then use current quote as fallback.
   if(s.spreadPoints<=0.0) s.spreadPoints=(double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   s.tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   s.tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);
    if(s.tickValue<=0.0) s.tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   s.bull=(s.e50>s.e100 && s.e100>s.e200);
   s.bear=(s.e50<s.e100 && s.e100<s.e200);
   s.range=(s.adx<20.0 && MathAbs(s.e50-s.e100)<s.atr*0.50);
   s.touch15=(s.bar.low<=s.e15 && s.bar.high>=s.e15);
   s.touch50=(s.bar.low<=s.e50 && s.bar.high>=s.e50);
   s.touch100=(s.bar.low<=s.e100 && s.bar.high>=s.e100);
   s.touch200=(s.bar.low<=s.e200 && s.bar.high>=s.e200);
   return true;
}

void WriteBarHeader()
{
   FileWrite(fBars,"event_time","symbol","timeframe","open","high","low","close","tick_volume",
   "spread_points","tick_size","tick_value","ema15","ema50","ema100","ema200",
   "close_to_ema15_points","close_to_ema50_points","close_to_ema100_points","close_to_ema200_points",
   "touch_ema15","touch_ema50","touch_ema100","touch_ema200","ema_bull_stack","ema_bear_stack",
   "stoch_main","stoch_signal","stoch_main_prev","stoch_signal_prev","stoch_cross_up","stoch_cross_down",
   "stoch_oversold","stoch_overbought","rsi","rsi_prev","rsi_oversold","rsi_overbought",
   "atr_price","atr_points","adx","plus_di","minus_di","market_regime","bb_upper","bb_middle","bb_lower",
   "bb_width_points","macd_main","macd_signal","macd_cross_up","macd_cross_down",
   "prior_high","prior_low","breakout_up","breakout_down","ema15_slope_points","ema50_slope_points",
   "ema100_slope_points","ema200_slope_points");
}
void WriteEventHeader()
{
   FileWrite(fEvents,"event_time","symbol","timeframe","event_id","event_type","direction",
   "reference_price","ema_value","distance_points","open","high","low","close",
   "ema15","ema50","ema100","ema200","touch_ema15","touch_ema50","touch_ema100","touch_ema200",
   "trend_bull","trend_bear","market_regime","stoch_main","stoch_signal","rsi","atr_points","adx",
   "bb_upper","bb_middle","bb_lower","macd_main","macd_signal","spread_points","details");
}
void WriteOutcomeHeader()
{
   FileWrite(fOutcomes,"signal_id","signal_time","symbol","timeframe","event_type","direction",
   "entry_price","horizon_bars","bars_observed","mfe_favourable_points","mae_adverse_points",
   "max_up_points","max_down_points","last_close","outcome_status");
}
void WriteScenarioHeader()
{
   FileWrite(fScenarios,"event_id","signal_time","symbol","timeframe","event_type","direction",
   "entry_price","scenario","tp_points","sl_points","bars_held","gross_points","estimated_cost_points",
   "net_points","exit_price","exit_reason","atr_at_entry_points","trailing_enabled");
}
bool BarAlreadyLogged(const datetime barTime)
{
   int h=FileOpen(MakeFile("Bars"),FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(h==INVALID_HANDLE) return false;
   // Bars rows have a fixed schema; event_time is the first field.
   for(int i=0;i<59 && !FileIsEnding(h);i++) FileReadString(h);
   string target=TimeToString(barTime,TIME_DATE|TIME_SECONDS);
   bool found=false;
   while(!FileIsEnding(h))
   {
      string t=FileReadString(h);
      if(t=="") break;
      for(int col=1;col<59 && !FileIsEnding(h);col++) FileReadString(h);
      if(t==target) { found=true; break; }
   }
   FileClose(h);
   return found;
}
void WriteBar(const Snapshot &s,const int shift)
{
   if(fBars==INVALID_HANDLE || BarAlreadyLogged(s.bar.time)) return;
   double p15=0,p50=0,p100=0,p200=0;
   double old15,old50,old100,old200;
   if(ReadVal(hFast,0,shift+1,old15)) p15=Pts(s.e15-old15);
   if(ReadVal(h50,0,shift+1,old50)) p50=Pts(s.e50-old50);
   if(ReadVal(h100,0,shift+1,old100)) p100=Pts(s.e100-old100);
   if(ReadVal(h200,0,shift+1,old200)) p200=Pts(s.e200-old200);
   bool stUp=(s.stPrev<=s.stSigPrev && s.stMain>s.stSignal);
   bool stDown=(s.stPrev>=s.stSigPrev && s.stMain<s.stSignal);
   bool macUp=(s.macdPrev<=s.macdSigPrev && s.macdMain>s.macdSignal);
   bool macDown=(s.macdPrev>=s.macdSigPrev && s.macdMain<s.macdSignal);
   double bbWidth=Pts(s.upper-s.lower);
   string regime=s.bull ? "UPTREND" : (s.bear ? "DOWNTREND" : (s.range ? "RANGE" : "TRANSITION"));
   FileWrite(fBars,TimeToString(s.bar.time,TIME_DATE|TIME_SECONDS),_Symbol,TFName(),
   DoubleToString(s.bar.open,_Digits),DoubleToString(s.bar.high,_Digits),DoubleToString(s.bar.low,_Digits),
   DoubleToString(s.bar.close,_Digits),s.bar.tick_volume,DoubleToString(s.spreadPoints,1),
   DoubleToString(s.tickSize,_Digits),DoubleToString(s.tickValue,4),
   DoubleToString(s.e15,_Digits),DoubleToString(s.e50,_Digits),DoubleToString(s.e100,_Digits),DoubleToString(s.e200,_Digits),
   DoubleToString(Pts(s.bar.close-s.e15),1),DoubleToString(Pts(s.bar.close-s.e50),1),
   DoubleToString(Pts(s.bar.close-s.e100),1),DoubleToString(Pts(s.bar.close-s.e200),1),
   B(s.touch15),B(s.touch50),B(s.touch100),B(s.touch200),B(s.bull),B(s.bear),
   DoubleToString(s.stMain,3),DoubleToString(s.stSignal,3),DoubleToString(s.stPrev,3),DoubleToString(s.stSigPrev,3),
   B(stUp),B(stDown),B(s.stMain<=InpOversold),B(s.stMain>=InpOverbought),
   DoubleToString(s.rsi,3),DoubleToString(s.rsiPrev,3),B(s.rsi<=InpRSIOversold),B(s.rsi>=InpRSIOverbought),
   DoubleToString(s.atr,_Digits),DoubleToString(Pts(s.atr),1),DoubleToString(s.adx,3),
   DoubleToString(s.plusDI,3),DoubleToString(s.minusDI,3),regime,
   DoubleToString(s.upper,_Digits),DoubleToString(s.middle,_Digits),DoubleToString(s.lower,_Digits),
   DoubleToString(bbWidth,1),DoubleToString(s.macdMain,10),DoubleToString(s.macdSignal,10),
   B(macUp),B(macDown),DoubleToString(s.priorHigh,_Digits),DoubleToString(s.priorLow,_Digits),
   B(s.bar.close>s.priorHigh),B(s.bar.close<s.priorLow),
   DoubleToString(p15,1),DoubleToString(p50,1),DoubleToString(p100,1),DoubleToString(p200,1));
}
bool EventAlreadyLogged(const datetime eventTime,const string eventType)
{
   // Idempotency key: timestamp + symbol + timeframe + event type.
   // Read-only scan of the existing event CSV; the file is never rewritten.
   string fileName=MakeFile("Events");
   int h=FileOpen(fileName,FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(h==INVALID_HANDLE) return false;
   // Events header has 36 fields; event_time=0, symbol=1, timeframe=2, event_type=4.
   for(int i=0;i<36 && !FileIsEnding(h);i++) FileReadString(h);
   string targetTime=TimeToString(eventTime,TIME_DATE|TIME_SECONDS);
   bool found=false;
   while(!FileIsEnding(h))
   {
      string rowTime="",rowSymbol="",rowTF="",rowType="";
      bool hasData=false;
      for(int col=0;col<36;col++)
      {
         if(FileIsEnding(h)) break;
         string value=FileReadString(h);
         if(value!="") hasData=true;
         if(col==0) rowTime=value;
         else if(col==1) rowSymbol=value;
         else if(col==2) rowTF=value;
         else if(col==4) rowType=value;
      }
      if(!hasData) break;
      if(rowTime==targetTime && rowSymbol==_Symbol && rowTF==TFName() && rowType==eventType)
      { found=true; break; }
   }
   FileClose(h);
   return found;
}

bool WriteEvent(const Snapshot &s,const string name,const string dir,const double refPrice,
                const double ema,const string details)
{
   if(fEvents==INVALID_HANDLE) return false;
   if(EventAlreadyLogged(s.bar.time,name)) return false;
   double dist=(ema!=0.0 ? Pts(s.bar.close-ema) : 0.0);
   string regime=s.bull ? "UPTREND" : (s.bear ? "DOWNTREND" : (s.range ? "RANGE" : "TRANSITION"));
   FileWrite(fEvents,TimeToString(s.bar.time,TIME_DATE|TIME_SECONDS),_Symbol,TFName(),
   (string)nextEventId,name,dir,DoubleToString(refPrice,_Digits),DoubleToString(ema,_Digits),DoubleToString(dist,1),
   DoubleToString(s.bar.open,_Digits),DoubleToString(s.bar.high,_Digits),DoubleToString(s.bar.low,_Digits),
   DoubleToString(s.bar.close,_Digits),DoubleToString(s.e15,_Digits),DoubleToString(s.e50,_Digits),
   DoubleToString(s.e100,_Digits),DoubleToString(s.e200,_Digits),B(s.touch15),B(s.touch50),B(s.touch100),B(s.touch200),
   B(s.bull),B(s.bear),regime,DoubleToString(s.stMain,3),DoubleToString(s.stSignal,3),
   DoubleToString(s.rsi,3),DoubleToString(Pts(s.atr),1),DoubleToString(s.adx,3),
   DoubleToString(s.upper,_Digits),DoubleToString(s.middle,_Digits),DoubleToString(s.lower,_Digits),
   DoubleToString(s.macdMain,10),DoubleToString(s.macdSignal,10),
   DoubleToString(s.spreadPoints,1),details);
   nextEventId++; SavePersistentCounter("EVENTID",nextEventId);
   return true;
}
void AddScenarioTrack(const Snapshot &s,const string name,const int dir,const double entry,const long sourceEventId)
{
   if(dir==0 || fScenarios==INVALID_HANDLE) return;
   int n=ArraySize(simTracks); if(ArrayResize(simTracks,n+1)!=n+1) return;
   simTracks[n].eventId=sourceEventId; simTracks[n].signalTime=s.bar.time; simTracks[n].eventName=name;
   simTracks[n].direction=dir; simTracks[n].entry=entry; simTracks[n].atrPrice=s.atr;
   simTracks[n].fixedTP=InpSimFixedTPPoints*_Point; simTracks[n].fixedSL=InpSimFixedSLPoints*_Point;
   simTracks[n].atrTP=s.atr*InpSimATRTPMultiple; simTracks[n].atrSL=s.atr*InpSimATRSLMultiple;
   simTracks[n].fixedExit=0; simTracks[n].atrExit=0; simTracks[n].trailExit=0;
   simTracks[n].beExit=0; simTracks[n].moneyExit=0; simTracks[n].rr2Exit=0; simTracks[n].gridExit=0; simTracks[n].pctExit=0; simTracks[n].pyrExit=0;
   simTracks[n].gridAvgEntry=entry; simTracks[n].gridLastAdd=entry;
   simTracks[n].gridTP=InpSimGridTargetPoints*_Point; simTracks[n].gridSL=InpSimGridMaxLossPoints*_Point;
   simTracks[n].gridAdds=0;
   simTracks[n].pyrAvgEntry=entry; simTracks[n].pyrLastAdd=entry;
   simTracks[n].pyrTP=InpSimGridTargetPoints*_Point; simTracks[n].pyrSL=InpSimGridMaxLossPoints*_Point;
   simTracks[n].pyrAdds=0;
   simTracks[n].bestPrice=entry; simTracks[n].barsSeen=0;
   simTracks[n].fixedStatus=0; simTracks[n].atrStatus=0; simTracks[n].trailStatus=0;
   simTracks[n].beStatus=0; simTracks[n].moneyStatus=0; simTracks[n].rr2Status=0; simTracks[n].gridStatus=0; simTracks[n].pctStatus=0; simTracks[n].pyrStatus=0; simTracks[n].beActivated=false;
   simTracks[n].beStop=entry-s.dir*s.atr*InpSimATRSLMultiple;
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);
    if(tickValue<=0.0) tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double moneyPerPoint=(tickSize>0.0 ? tickValue*_Point/tickSize : 0.0);
   double moneySLPoints=(moneyPerPoint>0.0 && InpSimLotSize>0.0 ? InpSimMoneyStopUSD/(moneyPerPoint*InpSimLotSize) : InpSimFixedSLPoints);
   simTracks[n].moneySL=moneySLPoints*_Point;
   simTracks[n].moneyTP=simTracks[n].moneySL*1.5;
   double pctRiskUSD=InpSimAccountBalance*InpSimRiskPercent/100.0;
   double pctSLPoints=(moneyPerPoint>0.0 && InpSimLotSize>0.0 ? pctRiskUSD/(moneyPerPoint*InpSimLotSize) : InpSimFixedSLPoints);
   simTracks[n].pctSL=pctSLPoints*_Point;
   simTracks[n].pctTP=simTracks[n].pctSL*1.5;
}
void AddTrack(const Snapshot &s,const string name,const int dir,const double entry,const long sourceEventId)
{
   int n=ArraySize(tracks); if(ArrayResize(tracks,n+1)!=n+1) return;
   tracks[n].id=sourceEventId; tracks[n].signalTime=s.bar.time; tracks[n].eventName=name;
   tracks[n].direction=dir; tracks[n].entry=entry; tracks[n].barsSeen=0;
   tracks[n].mfePoints=0; tracks[n].maePoints=0; tracks[n].upPoints=0; tracks[n].downPoints=0;
   AddScenarioTrack(s,name,dir,entry,sourceEventId);
}
void AddEventTrack(const Snapshot &s,const string name,const int dir,const double entry,const string details)
{
   if(!WriteEvent(s,name,(dir==1?"BUY":(dir==-1?"SELL":"BOTH")),entry,0,details)) return;
   // WriteEvent increments nextEventId only after a successful append; link the pending outcome
   // to the exact event ID just written, rather than an unrelated independent counter.
   long sourceEventId=nextEventId-1;
   AddTrack(s,name,dir,entry,sourceEventId);
}
void WriteTrackState()
{
   if(stateFileName=="") return;
   int f=FileOpen(stateFileName,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(f==INVALID_HANDLE) { Print("EMAMonitor v3: cannot save pending state ",GetLastError()); return; }
   FileWrite(f,"id","signal_time","event_type","direction","entry","bars_seen","mfe_points","mae_points","up_points","down_points");
   for(int i=0;i<ArraySize(tracks);i++)
      FileWrite(f,(string)tracks[i].id,TimeToString(tracks[i].signalTime,TIME_DATE|TIME_SECONDS),
         tracks[i].eventName,tracks[i].direction,DoubleToString(tracks[i].entry,_Digits),
         tracks[i].barsSeen,DoubleToString(tracks[i].mfePoints,1),DoubleToString(tracks[i].maePoints,1),
         DoubleToString(tracks[i].upPoints,1),DoubleToString(tracks[i].downPoints,1));
   FileFlush(f); FileClose(f);
}
void SaveScenarioState()
{
   if(simStateFileName=="") return;
   int f=FileOpen(simStateFileName,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(f==INVALID_HANDLE){Print("EMAMonitor v3: cannot save scenario state ",GetLastError());return;}
   FileWrite(f,"event_id","signal_time","event_type","direction","entry","atr_price","fixed_tp","fixed_sl","atr_tp","atr_sl",
      "fixed_exit","atr_exit","trail_exit","best_price","bars_seen","fixed_status","atr_status","trail_status",
      "be_exit","money_exit","money_tp","money_sl","be_stop","be_status","money_status","be_activated",
      "rr2_exit","grid_exit","grid_avg_entry","grid_last_add","grid_tp","grid_sl","rr2_status","grid_status","grid_adds",
      "pct_exit","pct_tp","pct_sl","pct_status","pyr_exit","pyr_avg_entry","pyr_last_add","pyr_tp","pyr_sl","pyr_status","pyr_adds");
   for(int i=0;i<ArraySize(simTracks);i++)
   {
      SimTrack st=simTracks[i];
      FileWrite(f,(string)st.eventId,TimeToString(st.signalTime,TIME_DATE|TIME_SECONDS),st.eventName,st.direction,
         DoubleToString(st.entry,_Digits),DoubleToString(st.atrPrice,_Digits),DoubleToString(st.fixedTP,_Digits),
         DoubleToString(st.fixedSL,_Digits),DoubleToString(st.atrTP,_Digits),DoubleToString(st.atrSL,_Digits),
         DoubleToString(st.fixedExit,_Digits),DoubleToString(st.atrExit,_Digits),DoubleToString(st.trailExit,_Digits),
         DoubleToString(st.bestPrice,_Digits),st.barsSeen,st.fixedStatus,st.atrStatus,st.trailStatus,
         DoubleToString(st.beExit,_Digits),DoubleToString(st.moneyExit,_Digits),DoubleToString(st.moneyTP,_Digits),
         DoubleToString(st.moneySL,_Digits),DoubleToString(st.beStop,_Digits),st.beStatus,st.moneyStatus,B(st.beActivated),
         DoubleToString(st.rr2Exit,_Digits),DoubleToString(st.gridExit,_Digits),DoubleToString(st.gridAvgEntry,_Digits),
         DoubleToString(st.gridLastAdd,_Digits),DoubleToString(st.gridTP,_Digits),DoubleToString(st.gridSL,_Digits),
         st.rr2Status,st.gridStatus,st.gridAdds,DoubleToString(st.pctExit,_Digits),
         DoubleToString(st.pctTP,_Digits),DoubleToString(st.pctSL,_Digits),st.pctStatus,
         DoubleToString(st.pyrExit,_Digits),DoubleToString(st.pyrAvgEntry,_Digits),DoubleToString(st.pyrLastAdd,_Digits),
         DoubleToString(st.pyrTP,_Digits),DoubleToString(st.pyrSL,_Digits),st.pyrStatus,st.pyrAdds);
   }
   FileFlush(f);FileClose(f);
}
void LoadScenarioState()
{
   if(simStateFileName=="") return;
   int f=FileOpen(simStateFileName,FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(f==INVALID_HANDLE) return;
   if(!FileIsEnding(f)) for(int h=0;h<46 && !FileIsEnding(f);h++) FileReadString(f);
   while(!FileIsEnding(f))
   {
      string idText=FileReadString(f); if(idText=="") break;
      string timeText=FileReadString(f),name=FileReadString(f),dirText=FileReadString(f);
      string entryText=FileReadString(f),atrText=FileReadString(f),ftp=FileReadString(f),fsl=FileReadString(f);
      string atp=FileReadString(f),asl=FileReadString(f),fexit=FileReadString(f),aexit=FileReadString(f);
      string texit=FileReadString(f),best=FileReadString(f),bars=FileReadString(f);
      string fs=FileReadString(f),atrStatusText=FileReadString(f),ts=FileReadString(f);
      string bex=FileReadString(f),moneyx=FileReadString(f),mtp=FileReadString(f),msl=FileReadString(f),bstop=FileReadString(f);
      string bes=FileReadString(f),mstatus=FileReadString(f),bactive=FileReadString(f);
      string rr2x=FileReadString(f),gridx=FileReadString(f),gavg=FileReadString(f),glast=FileReadString(f);
      string gtp=FileReadString(f),gsl=FileReadString(f),rr2s=FileReadString(f),grids=FileReadString(f),gadds=FileReadString(f);
      string pexit=FileReadString(f),ptp=FileReadString(f),psl=FileReadString(f),pstatus=FileReadString(f);
      string pyrexit=FileReadString(f),pyravg=FileReadString(f),pyrlast=FileReadString(f),pyrtp=FileReadString(f),pyrsl=FileReadString(f),pyrs=FileReadString(f),pyra=FileReadString(f);
      if(idText=="" || timeText=="") continue;
      int n=ArraySize(simTracks);if(ArrayResize(simTracks,n+1)!=n+1)break;
      simTracks[n].eventId=(long)StringToInteger(idText);simTracks[n].signalTime=StringToTime(timeText);
      simTracks[n].eventName=name;simTracks[n].direction=(int)StringToInteger(dirText);
      simTracks[n].entry=StringToDouble(entryText);simTracks[n].atrPrice=StringToDouble(atrText);
      simTracks[n].fixedTP=StringToDouble(ftp);simTracks[n].fixedSL=StringToDouble(fsl);
      simTracks[n].atrTP=StringToDouble(atp);simTracks[n].atrSL=StringToDouble(asl);
      simTracks[n].fixedExit=StringToDouble(fexit);simTracks[n].atrExit=StringToDouble(aexit);
      simTracks[n].trailExit=StringToDouble(texit);simTracks[n].bestPrice=StringToDouble(best);
      simTracks[n].barsSeen=(int)StringToInteger(bars);simTracks[n].fixedStatus=(int)StringToInteger(fs);
      simTracks[n].atrStatus=(int)StringToInteger(atrStatusText);simTracks[n].trailStatus=(int)StringToInteger(ts);
      simTracks[n].beExit=StringToDouble(bex);simTracks[n].moneyExit=StringToDouble(moneyx);
      simTracks[n].moneyTP=StringToDouble(mtp);simTracks[n].moneySL=StringToDouble(msl);simTracks[n].beStop=StringToDouble(bstop);
      simTracks[n].beStatus=(int)StringToInteger(bes);simTracks[n].moneyStatus=(int)StringToInteger(mstatus);
      simTracks[n].beActivated=(StringToInteger(bactive)!=0);
      simTracks[n].rr2Exit=StringToDouble(rr2x);simTracks[n].gridExit=StringToDouble(gridx);
      simTracks[n].gridAvgEntry=StringToDouble(gavg);simTracks[n].gridLastAdd=StringToDouble(glast);
      simTracks[n].gridTP=StringToDouble(gtp);simTracks[n].gridSL=StringToDouble(gsl);
      simTracks[n].rr2Status=(int)StringToInteger(rr2s);simTracks[n].gridStatus=(int)StringToInteger(grids);
      simTracks[n].gridAdds=(int)StringToInteger(gadds);simTracks[n].pctExit=StringToDouble(pexit);
      simTracks[n].pctTP=StringToDouble(ptp);simTracks[n].pctSL=StringToDouble(psl);
      simTracks[n].pctStatus=(int)StringToInteger(pstatus);simTracks[n].pyrExit=StringToDouble(pyrexit);
      simTracks[n].pyrAvgEntry=StringToDouble(pyravg);simTracks[n].pyrLastAdd=StringToDouble(pyrlast);
      simTracks[n].pyrTP=StringToDouble(pyrtp);simTracks[n].pyrSL=StringToDouble(pyrsl);
      simTracks[n].pyrStatus=(int)StringToInteger(pyrs);simTracks[n].pyrAdds=(int)StringToInteger(pyra);
   }
   FileClose(f);
}
void LoadTrackState()
{
   if(stateFileName=="") return;
   int f=FileOpen(stateFileName,FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(f==INVALID_HANDLE) return;
   // Skip the header row (10 fields).
   if(!FileIsEnding(f))
      for(int h=0;h<10 && !FileIsEnding(f);h++) FileReadString(f);
   while(!FileIsEnding(f))
   {
      string idText=FileReadString(f); if(idText=="") break;
      string timeText=FileReadString(f);
      string eventName=FileReadString(f);
      string dirText=FileReadString(f);
      string entryText=FileReadString(f);
      string barsText=FileReadString(f);
      string mfeText=FileReadString(f);
      string maeText=FileReadString(f);
      string upText=FileReadString(f);
      string downText=FileReadString(f);
      if(idText=="" || timeText=="") continue;
      int n=ArraySize(tracks);
      if(ArrayResize(tracks,n+1)!=n+1) break;
      tracks[n].id=(long)StringToInteger(idText);
      tracks[n].signalTime=StringToTime(timeText);
      tracks[n].eventName=eventName;
      tracks[n].direction=(int)StringToInteger(dirText);
      tracks[n].entry=StringToDouble(entryText);
      tracks[n].barsSeen=(int)StringToInteger(barsText);
      tracks[n].mfePoints=StringToDouble(mfeText);
      tracks[n].maePoints=StringToDouble(maeText);
      tracks[n].upPoints=StringToDouble(upText);
      tracks[n].downPoints=StringToDouble(downText);
      if(tracks[n].id>=nextId) nextId=tracks[n].id+1;
   }
   FileClose(f);
   SavePersistentCounter("TRACKID",nextId);
}
bool OutcomeAlreadyLogged(const long eventId,const datetime signalTime,const string eventType)
{
   int h=FileOpen(MakeFile("Outcomes"),FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(h==INVALID_HANDLE) return false;
   for(int i=0;i<15 && !FileIsEnding(h);i++) FileReadString(h);
   string targetId=(string)eventId;
   string targetTime=TimeToString(signalTime,TIME_DATE|TIME_SECONDS);
   bool found=false;
   while(!FileIsEnding(h))
   {
      string id=FileReadString(h);
      if(id=="") break;
      string rowTime="",rowType="";
      for(int col=1;col<15 && !FileIsEnding(h);col++)
      {
         string value=FileReadString(h);
         if(col==1) rowTime=value;
         else if(col==4) rowType=value;
      }
      // Old outcomes used a separate counter; match the full identity to avoid false collisions.
      if(id==targetId && rowTime==targetTime && rowType==eventType)
      { found=true; break; }
   }
   FileClose(h); return found;
}
void UpdateTracks(const MqlRates &bar)
{
   for(int i=ArraySize(tracks)-1;i>=0;i--)
   {
      double up=Pts(bar.high-tracks[i].entry);
      double down=Pts(tracks[i].entry-bar.low);
      if(up>tracks[i].upPoints) tracks[i].upPoints=up;
      if(down>tracks[i].downPoints) tracks[i].downPoints=down;
      // Directionless EMA-touch events retain independent up/down excursion data.
      // MFE/MAE are not assigned for BOTH because favourable/adverse has no unique meaning.
      if(tracks[i].direction!=0)
      {
         double fav=(tracks[i].direction==1?up:down);
         double adv=(tracks[i].direction==1?down:up);
         if(fav>tracks[i].mfePoints) tracks[i].mfePoints=fav;
         if(adv>tracks[i].maePoints) tracks[i].maePoints=adv;
      }
      tracks[i].barsSeen++;
      if(tracks[i].barsSeen>=InpOutcomeBars)
      {
         if(fOutcomes!=INVALID_HANDLE && !OutcomeAlreadyLogged(tracks[i].id,tracks[i].signalTime,tracks[i].eventName))
         {
            string mfeText=(tracks[i].direction==0 ? "NA" : DoubleToString(tracks[i].mfePoints,1));
            string maeText=(tracks[i].direction==0 ? "NA" : DoubleToString(tracks[i].maePoints,1));
            FileWrite(fOutcomes,(string)tracks[i].id,TimeToString(tracks[i].signalTime,TIME_DATE|TIME_SECONDS),
            _Symbol,TFName(),tracks[i].eventName,(tracks[i].direction==1?"BUY":(tracks[i].direction==-1?"SELL":"BOTH")),
            DoubleToString(tracks[i].entry,_Digits),InpOutcomeBars,tracks[i].barsSeen,
            mfeText,maeText,DoubleToString(tracks[i].upPoints,1),DoubleToString(tracks[i].downPoints,1),
            DoubleToString(bar.close,_Digits),"COMPLETE");
         }
         for(int j=i;j<ArraySize(tracks)-1;j++) tracks[j]=tracks[j+1];
         ArrayResize(tracks,ArraySize(tracks)-1);
      }
   }
   WriteTrackState();
}
void WriteScenarioResult(const SimTrack &st,const string scenario,const double tp,const double sl,
                         const double exitPrice,const string reason)
{
   if(fScenarios==INVALID_HANDLE) return;
   double gross=(exitPrice-st.entry)/_Point*st.direction;
   double cost=InpSimCostPoints;
   FileWrite(fScenarios,(string)st.eventId,TimeToString(st.signalTime,TIME_DATE|TIME_SECONDS),_Symbol,TFName(),
      st.eventName,(st.direction==1?"BUY":"SELL"),DoubleToString(st.entry,_Digits),scenario,
      DoubleToString(tp/_Point,1),DoubleToString(sl/_Point,1),st.barsSeen,DoubleToString(gross,1),
      DoubleToString(cost,1),DoubleToString(gross-cost,1),DoubleToString(exitPrice,_Digits),reason,
      DoubleToString(Pts(st.atrPrice),1),B(InpSimTrailingEnabled));
}
void UpdateScenarioTracks(const MqlRates &bar)
{
   for(int i=ArraySize(simTracks)-1;i>=0;i--)
   {
      SimTrack st=simTracks[i];
      st.barsSeen++;
      double priorBest=st.bestPrice;
      double fixedTPPrice=st.entry+st.direction*st.fixedTP;
      double fixedSLPrice=st.entry-st.direction*st.fixedSL;
      double atrTPPrice=st.entry+st.direction*st.atrTP;
      double atrSLPrice=st.entry-st.direction*st.atrSL;
      // Conservative OHLC assumption: if TP and SL occur in the same candle, SL wins.
      if(st.fixedStatus==0)
      {
         bool hitSL=(st.direction==1?bar.low<=fixedSLPrice:bar.high>=fixedSLPrice);
         bool hitTP=(st.direction==1?bar.high>=fixedTPPrice:bar.low<=fixedTPPrice);
         if(hitSL){st.fixedStatus=-1;st.fixedExit=fixedSLPrice;WriteScenarioResult(st,"FIXED_TP_SL",st.fixedTP,st.fixedSL,st.fixedExit,"SL");}
         else if(hitTP){st.fixedStatus=1;st.fixedExit=fixedTPPrice;WriteScenarioResult(st,"FIXED_TP_SL",st.fixedTP,st.fixedSL,st.fixedExit,"TP");}
      }
      if(st.atrStatus==0)
      {
         bool hitSL=(st.direction==1?bar.low<=atrSLPrice:bar.high>=atrSLPrice);
         bool hitTP=(st.direction==1?bar.high>=atrTPPrice:bar.low<=atrTPPrice);
         if(hitSL){st.atrStatus=-1;st.atrExit=atrSLPrice;WriteScenarioResult(st,"ATR_TP_SL",st.atrTP,st.atrSL,st.atrExit,"SL");}
         else if(hitTP){st.atrStatus=1;st.atrExit=atrTPPrice;WriteScenarioResult(st,"ATR_TP_SL",st.atrTP,st.atrSL,st.atrExit,"TP");}
      }
      if(st.trailStatus==0)
      {
         double trailDist=st.atrPrice*InpSimTrailATRMultiple;
         double trailStop=(st.direction==1?priorBest-trailDist:priorBest+trailDist);
         bool hitTrail=(InpSimTrailingEnabled && (st.direction==1?bar.low<=trailStop:bar.high>=trailStop));
         bool hitTP=(st.direction==1?bar.high>=atrTPPrice:bar.low<=atrTPPrice);
         bool hitInitialSL=(st.direction==1?bar.low<=atrSLPrice:bar.high>=atrSLPrice);
         if(hitInitialSL){st.trailStatus=-1;st.trailExit=atrSLPrice;WriteScenarioResult(st,"ATR_TP_TRAIL",st.atrTP,st.atrSL,st.trailExit,"INITIAL_SL");}
         else if(hitTP){st.trailStatus=1;st.trailExit=atrTPPrice;WriteScenarioResult(st,"ATR_TP_TRAIL",st.atrTP,st.atrSL,st.trailExit,"TP");}
         else if(hitTrail){st.trailStatus=-1;st.trailExit=trailStop;WriteScenarioResult(st,"ATR_TP_TRAIL",st.atrTP,trailDist,st.trailExit,"TRAILING_STOP");}
      }

      if(st.beStatus==0)
      {
         double beTP=st.entry+st.direction*st.atrTP;
         double initialSL=st.entry-st.direction*st.atrSL;
         bool hitInitial=(st.direction==1?bar.low<=initialSL:bar.high>=initialSL);
         bool hitTarget=(st.direction==1?bar.high>=beTP:bar.low<=beTP);
         bool hitBE=(st.beActivated && (st.direction==1?bar.low<=st.beStop:bar.high>=st.beStop));
         if(hitInitial){st.beStatus=-1;st.beExit=initialSL;WriteScenarioResult(st,"ATR_BREAK_EVEN",st.atrTP,st.atrSL,st.beExit,"INITIAL_SL");}
         else if(hitTarget){st.beStatus=1;st.beExit=beTP;WriteScenarioResult(st,"ATR_BREAK_EVEN",st.atrTP,st.atrSL,st.beExit,"TP");}
         else if(hitBE){st.beStatus=2;st.beExit=st.beStop;WriteScenarioResult(st,"ATR_BREAK_EVEN",st.atrTP,st.atrSL,st.beExit,"BREAK_EVEN_STOP");}
         // Activate only after this candle has been evaluated, avoiding same-bar look-ahead.
         double beTrigger=st.entry+st.direction*st.atrPrice*InpSimBETriggerATRMultiple;
         bool reachedTrigger=(st.direction==1?bar.high>=beTrigger:bar.low<=beTrigger);
         if(st.beStatus==0 && reachedTrigger && !st.beActivated){st.beActivated=true;st.beStop=st.entry;}
      }
      if(st.moneyStatus==0)
      {
         double moneyTPPrice=st.entry+st.direction*st.moneyTP;
         double moneySLPrice=st.entry-st.direction*st.moneySL;
         bool hitMoneySL=(st.direction==1?bar.low<=moneySLPrice:bar.high>=moneySLPrice);
         bool hitMoneyTP=(st.direction==1?bar.high>=moneyTPPrice:bar.low<=moneyTPPrice);
         if(hitMoneySL){st.moneyStatus=-1;st.moneyExit=moneySLPrice;WriteScenarioResult(st,"MONEY_RISK_1_5R",st.moneyTP,st.moneySL,st.moneyExit,"MONEY_STOP");}
         else if(hitMoneyTP){st.moneyStatus=1;st.moneyExit=moneyTPPrice;WriteScenarioResult(st,"MONEY_RISK_1_5R",st.moneyTP,st.moneySL,st.moneyExit,"TP_1_5R");}
      }


      if(st.pctStatus==0)
      {
         double pctTPPrice=st.entry+st.direction*st.pctTP;
         double pctSLPrice=st.entry-st.direction*st.pctSL;
         bool hitPctSL=(st.direction==1?bar.low<=pctSLPrice:bar.high>=pctSLPrice);
         bool hitPctTP=(st.direction==1?bar.high>=pctTPPrice:bar.low<=pctTPPrice);
         if(hitPctSL){st.pctStatus=-1;st.pctExit=pctSLPrice;WriteScenarioResult(st,"PERCENT_RISK_1_5R",st.pctTP,st.pctSL,st.pctExit,"PERCENT_RISK_STOP");}
         else if(hitPctTP){st.pctStatus=1;st.pctExit=pctTPPrice;WriteScenarioResult(st,"PERCENT_RISK_1_5R",st.pctTP,st.pctSL,st.pctExit,"TP_1_5R");}
      }
      if(st.rr2Status==0)
      {
         double rrTP=st.entry+st.direction*st.fixedSL*2.0;
         double rrSL=st.entry-st.direction*st.fixedSL;
         bool hitSL=(st.direction==1?bar.low<=rrSL:bar.high>=rrSL);
         bool hitTP=(st.direction==1?bar.high>=rrTP:bar.low<=rrTP);
         if(hitSL){st.rr2Status=-1;st.rr2Exit=rrSL;WriteScenarioResult(st,"FIXED_RR_2R",st.fixedSL*2.0,st.fixedSL,st.rr2Exit,"SL");}
         else if(hitTP){st.rr2Status=1;st.rr2Exit=rrTP;WriteScenarioResult(st,"FIXED_RR_2R",st.fixedSL*2.0,st.fixedSL,st.rr2Exit,"TP_2R");}
      }
      if(st.gridStatus==0)
      {
         double gridTPPrice=st.gridAvgEntry+st.direction*st.gridTP;
         double gridSLPrice=st.entry-st.direction*st.gridSL;
         bool hitGridSL=(st.direction==1?bar.low<=gridSLPrice:bar.high>=gridSLPrice);
         bool hitGridTP=(st.direction==1?bar.high>=gridTPPrice:bar.low<=gridTPPrice);
         SimTrack gridResult=st;
         gridResult.entry=st.gridAvgEntry;
         if(hitGridSL){st.gridStatus=-1;st.gridExit=gridSLPrice;gridResult.entry=st.gridAvgEntry;WriteScenarioResult(gridResult,"GRID_AVERAGING_SIM",st.gridTP,st.gridSL,st.gridExit,"MAX_LOSS");}
         else if(hitGridTP){st.gridStatus=1;st.gridExit=gridTPPrice;WriteScenarioResult(gridResult,"GRID_AVERAGING_SIM",st.gridTP,st.gridSL,st.gridExit,"AVERAGE_ENTRY_TP");}
         else if(st.gridAdds<InpSimGridMaxAdds)
         {
            double addPrice=st.gridLastAdd-st.direction*InpSimGridStepPoints*_Point;
            bool addTriggered=(st.direction==1?bar.low<=addPrice:bar.high>=addPrice);
            if(addTriggered)
            {
               int oldCount=st.gridAdds+1;
               st.gridAvgEntry=(st.gridAvgEntry*oldCount+addPrice)/(oldCount+1);
               st.gridLastAdd=addPrice;
               st.gridAdds++;
            }
         }
      }

      if(st.pyrStatus==0)
      {
         double pyrTPPrice=st.pyrAvgEntry+st.direction*st.pyrTP;
         double pyrSLPrice=st.entry-st.direction*st.pyrSL;
         bool hitPyrSL=(st.direction==1?bar.low<=pyrSLPrice:bar.high>=pyrSLPrice);
         bool hitPyrTP=(st.direction==1?bar.high>=pyrTPPrice:bar.low<=pyrTPPrice);
         SimTrack pyrResult=st;
         pyrResult.entry=st.pyrAvgEntry;
         if(hitPyrSL){st.pyrStatus=-1;st.pyrExit=pyrSLPrice;WriteScenarioResult(pyrResult,"PYRAMIDING_SIM",st.pyrTP,st.pyrSL,st.pyrExit,"MAX_LOSS");}
         else if(hitPyrTP){st.pyrStatus=1;st.pyrExit=pyrTPPrice;WriteScenarioResult(pyrResult,"PYRAMIDING_SIM",st.pyrTP,st.pyrSL,st.pyrExit,"AVERAGE_ENTRY_TP");}
         else if(st.pyrAdds<InpSimGridMaxAdds)
         {
            double addPrice=st.pyrLastAdd+st.direction*InpSimGridStepPoints*_Point;
            bool addTriggered=(st.direction==1?bar.high>=addPrice:bar.low<=addPrice);
            if(addTriggered)
            {
               int oldCount=st.pyrAdds+1;
               st.pyrAvgEntry=(st.pyrAvgEntry*oldCount+addPrice)/(oldCount+1);
               st.pyrLastAdd=addPrice;
               st.pyrAdds++;
            }
         }
      }
      // Update the favorable extreme only after evaluating stops for this completed bar,
      // avoiding same-bar future information in the trailing-stop test.
      if(st.direction==1 && bar.high>st.bestPrice) st.bestPrice=bar.high;
      if(st.direction==-1 && bar.low<st.bestPrice) st.bestPrice=bar.low;
      if(st.barsSeen>=InpSimMaxBars)
      {
         if(st.fixedStatus==0){st.fixedStatus=2;st.fixedExit=bar.close;WriteScenarioResult(st,"FIXED_TP_SL",st.fixedTP,st.fixedSL,bar.close,"TIME_EXIT");}
         if(st.atrStatus==0){st.atrStatus=2;st.atrExit=bar.close;WriteScenarioResult(st,"ATR_TP_SL",st.atrTP,st.atrSL,bar.close,"TIME_EXIT");}
         if(st.trailStatus==0){st.trailStatus=2;st.trailExit=bar.close;WriteScenarioResult(st,"ATR_TP_TRAIL",st.atrTP,st.atrSL,bar.close,"TIME_EXIT");}
         if(st.beStatus==0){st.beStatus=2;st.beExit=bar.close;WriteScenarioResult(st,"ATR_BREAK_EVEN",st.atrTP,st.atrSL,bar.close,"TIME_EXIT");}
         if(st.moneyStatus==0){st.moneyStatus=2;st.moneyExit=bar.close;WriteScenarioResult(st,"MONEY_RISK_1_5R",st.moneyTP,st.moneySL,bar.close,"TIME_EXIT");}
         if(st.rr2Status==0){st.rr2Status=2;st.rr2Exit=bar.close;WriteScenarioResult(st,"FIXED_RR_2R",st.fixedSL*2.0,st.fixedSL,bar.close,"TIME_EXIT");}
         if(st.pctStatus==0){st.pctStatus=2;st.pctExit=bar.close;WriteScenarioResult(st,"PERCENT_RISK_1_5R",st.pctTP,st.pctSL,bar.close,"TIME_EXIT");}
         if(st.gridStatus==0){st.gridStatus=2;st.gridExit=bar.close;SimTrack gridResult=st;gridResult.entry=st.gridAvgEntry;WriteScenarioResult(gridResult,"GRID_AVERAGING_SIM",st.gridTP,st.gridSL,bar.close,"TIME_EXIT");}
         if(st.pyrStatus==0){st.pyrStatus=2;st.pyrExit=bar.close;SimTrack pyrResult=st;pyrResult.entry=st.pyrAvgEntry;WriteScenarioResult(pyrResult,"PYRAMIDING_SIM",st.pyrTP,st.pyrSL,bar.close,"TIME_EXIT");}
      }
      bool done=(st.fixedStatus!=0 && st.atrStatus!=0 && st.trailStatus!=0 && st.beStatus!=0 && st.moneyStatus!=0 && st.rr2Status!=0 && st.gridStatus!=0 && st.pctStatus!=0 && st.pyrStatus!=0);
      if(done){for(int j=i;j<ArraySize(simTracks)-1;j++)simTracks[j]=simTracks[j+1];ArrayResize(simTracks,ArraySize(simTracks)-1);}
      else simTracks[i]=st;
   }
   SaveScenarioState();
}
void EmitSignals(const Snapshot &s,const int shift)
{
   bool stUp=(s.stPrev<=s.stSigPrev && s.stMain>s.stSignal);
   bool stDown=(s.stPrev>=s.stSigPrev && s.stMain<s.stSignal);
   bool rsiBuy=(s.rsiPrev<InpRSIOversold && s.rsi>=InpRSIOversold);
   bool rsiSell=(s.rsiPrev>InpRSIOverbought && s.rsi<=InpRSIOverbought);
   bool bbBuy=(s.bar.low<=s.lower && s.bar.close>s.lower);
   bool bbSell=(s.bar.high>=s.upper && s.bar.close<s.upper);
   bool macBuy=(s.macdPrev<=s.macdSigPrev && s.macdMain>s.macdSignal);
   bool macSell=(s.macdPrev>=s.macdSigPrev && s.macdMain<s.macdSignal);
   bool boBuy=(s.bar.close>s.priorHigh),boSell=(s.bar.close<s.priorLow);
   double ema[4]; ema[0]=s.e15;ema[1]=s.e50;ema[2]=s.e100;ema[3]=s.e200;
   int emaHandles[4]; emaHandles[0]=hFast;emaHandles[1]=h50;emaHandles[2]=h100;emaHandles[3]=h200;
   string ename[4]; ename[0]="EMA15";ename[1]="EMA50";ename[2]="EMA100";ename[3]="EMA200";
   MqlRates priorBar; bool havePrior=ReadRate(shift+1,priorBar);
   bool touch[4]; touch[0]=s.touch15;touch[1]=s.touch50;touch[2]=s.touch100;touch[3]=s.touch200;
   for(int i=0;i<4;i++)
   {
      if(touch[i])
      {
         string reaction="TOUCH_ONLY";
         if(s.bar.close>ema[i] && s.bar.close>s.bar.open) reaction="CLOSE_ABOVE_BULL_CANDLE";
         else if(s.bar.close<ema[i] && s.bar.close<s.bar.open) reaction="CLOSE_BELOW_BEAR_CANDLE";
         AddEventTrack(s,"TOUCH_"+ename[i],0,s.bar.close,reaction);
         if(s.bar.close>ema[i] && s.bar.close>s.bar.open)
            AddEventTrack(s,"BOUNCE_UP_"+ename[i],1,s.bar.close,"Touch and bullish close above EMA; heuristic only");
         if(s.bar.close<ema[i] && s.bar.close<s.bar.open)
            AddEventTrack(s,"BOUNCE_DOWN_"+ename[i],-1,s.bar.close,"Touch and bearish close below EMA; heuristic only");
      }
      double prevEma=0;
      if(havePrior && ReadVal(emaHandles[i],0,shift+1,prevEma))
      {
         if(priorBar.close<=prevEma && s.bar.close>ema[i])
            WriteEvent(s,"PRICE_CROSS_ABOVE_"+ename[i],"BUY",s.bar.close,ema[i],"Prior close was at/below prior EMA; current close is above current EMA");
         if(priorBar.close>=prevEma && s.bar.close<ema[i])
            WriteEvent(s,"PRICE_CROSS_BELOW_"+ename[i],"SELL",s.bar.close,ema[i],"Prior close was at/above prior EMA; current close is below current EMA");
      }
   }
   if(stUp) AddEventTrack(s,"STOCH_CROSS_UP",1,s.bar.close,"Stochastic main crossed above signal");
   if(stDown) AddEventTrack(s,"STOCH_CROSS_DOWN",-1,s.bar.close,"Stochastic main crossed below signal");
   if(stUp && s.stPrev<InpOversold) AddEventTrack(s,"STOCH_OVERSOLD_REVERSAL_BUY",1,s.bar.close,"Cross up from oversold zone");
   if(stDown && s.stPrev>InpOverbought) AddEventTrack(s,"STOCH_OVERBOUGHT_REVERSAL_SELL",-1,s.bar.close,"Cross down from overbought zone");
   if(rsiBuy) AddEventTrack(s,"RSI_EXIT_OVERSOLD_BUY",1,s.bar.close,"RSI crossed back above oversold threshold");
   if(rsiSell) AddEventTrack(s,"RSI_EXIT_OVERBOUGHT_SELL",-1,s.bar.close,"RSI crossed back below overbought threshold");
   if(bbBuy) AddEventTrack(s,"BOLLINGER_REENTRY_BUY",1,s.bar.close,"Low touched/broke lower band and close returned above");
   if(bbSell) AddEventTrack(s,"BOLLINGER_REENTRY_SELL",-1,s.bar.close,"High touched/broke upper band and close returned below");
   if(boBuy) AddEventTrack(s,"RANGE_BREAKOUT_BUY",1,s.bar.close,"Close exceeded prior N-bar high");
   if(boSell) AddEventTrack(s,"RANGE_BREAKOUT_SELL",-1,s.bar.close,"Close fell below prior N-bar low");
   if(macBuy) AddEventTrack(s,"MACD_CROSS_BUY",1,s.bar.close,"MACD main crossed above signal");
   if(macSell) AddEventTrack(s,"MACD_CROSS_SELL",-1,s.bar.close,"MACD main crossed below signal");
   if(s.bull && s.touch15 && s.bar.close>s.e15 && s.bar.close>s.bar.open)
      AddEventTrack(s,"EMA_TREND_PULLBACK_BUY",1,s.bar.close,"Bull EMA stack + EMA15 touch + bullish close");
   if(s.bear && s.touch15 && s.bar.close<s.e15 && s.bar.close<s.bar.open)
      AddEventTrack(s,"EMA_TREND_PULLBACK_SELL",-1,s.bar.close,"Bear EMA stack + EMA15 touch + bearish close");
   if(s.adx<20.0) WriteEvent(s,"LOW_ADX_RANGE_CANDIDATE","NONE",s.bar.close,0,"ADX below 20; range candidate, not definitive");
   if(s.adx>=25.0) WriteEvent(s,"HIGH_ADX_TREND_CANDIDATE",(s.plusDI>s.minusDI?"BUY":"SELL"),s.bar.close,0,"ADX >= 25; directional bias from DI lines");
   if(s.atr>0 && s.atrPrev>0 && s.atr>s.atrPrev*1.10)
      WriteEvent(s,"ATR_EXPANSION","NONE",s.bar.close,0,"ATR increased by more than 10 percent versus prior bar");
}
bool ProcessBar(const int shift,const bool collect)
{
   Snapshot s;
   if(!LoadSnapshot(shift,s)) return false;
   if(collect) { UpdateTracks(s.bar); UpdateScenarioTracks(s.bar); }
   if(InpLogEveryBar || s.touch15 || s.touch50 || s.touch100 || s.touch200) WriteBar(s,shift);
   if(collect) EmitSignals(s,shift);
   return true;
}
int OnInit()
{
   if(InpHistoryBars<10 || InpOutcomeBars<1 || InpBreakoutBars<2 || InpBandsPeriod<2 || InpADXPeriod<2 ||
      InpSimFixedTPPoints<=0 || InpSimFixedSLPoints<=0 || InpSimATRTPMultiple<=0 || InpSimATRSLMultiple<=0 ||
      InpSimTrailATRMultiple<=0 || InpSimBETriggerATRMultiple<=0 || InpSimMoneyStopUSD<=0 || InpSimAccountBalance<=0 || InpSimRiskPercent<=0 || InpSimLotSize<=0 || InpSimGridStepPoints<=0 || InpSimGridMaxAdds<0 || InpSimGridTargetPoints<=0 || InpSimGridMaxLossPoints<=0 || InpSimMaxBars<1 || InpSimCostPoints<0)
      return INIT_PARAMETERS_INCORRECT;
   string accountCurrency=AccountInfoString(ACCOUNT_CURRENCY);
   if(accountCurrency!="USD")
      Print("EMAMonitor v3.10 WARNING: InpSimMoneyStopUSD is denominated in USD but account currency is ",accountCurrency,
            ". Money-stop simulation is not USD-accurate on this account; percentage-risk uses account currency.");
   hFast=iMA(_Symbol,CollectTF(),InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   h50=iMA(_Symbol,CollectTF(),InpEMA50,0,MODE_EMA,PRICE_CLOSE);
   h100=iMA(_Symbol,CollectTF(),InpEMA100,0,MODE_EMA,PRICE_CLOSE);
   h200=iMA(_Symbol,CollectTF(),InpEMA200,0,MODE_EMA,PRICE_CLOSE);
   hStoch=iStochastic(_Symbol,CollectTF(),InpStochK,InpStochD,InpStochSlowing,MODE_SMA,STO_LOWHIGH);
   hRSI=iRSI(_Symbol,CollectTF(),InpRSIPeriod,PRICE_CLOSE);
   hATR=iATR(_Symbol,CollectTF(),InpATRPeriod);
   hADX=iADX(_Symbol,CollectTF(),InpADXPeriod);
   hBands=iBands(_Symbol,CollectTF(),InpBandsPeriod,0,InpBandsDev,PRICE_CLOSE);
   hMACD=iMACD(_Symbol,CollectTF(),InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE);
   if(hFast==INVALID_HANDLE||h50==INVALID_HANDLE||h100==INVALID_HANDLE||h200==INVALID_HANDLE||
      hStoch==INVALID_HANDLE||hRSI==INVALID_HANDLE||hATR==INVALID_HANDLE||hADX==INVALID_HANDLE||
      hBands==INVALID_HANDLE||hMACD==INVALID_HANDLE)
   { Print("EMAMonitor v3: indicator handle error ",GetLastError()); return INIT_FAILED; }

   string barsName=MakeFile("Bars"),eventsName=MakeFile("Events"),outName=MakeFile("Outcomes"),scenarioName=MakeFile("Scenarios");
   stateFileName=MakeFile("PendingState");
   simStateFileName=MakeFile("ScenarioState_v3"); // New schema; preserve older state files untouched
   LoadTrackState();
   LoadScenarioState();
   fBars=FileOpen(barsName,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   fEvents=FileOpen(eventsName,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   fOutcomes=FileOpen(outName,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   fScenarios=FileOpen(scenarioName,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(fBars==INVALID_HANDLE||fEvents==INVALID_HANDLE||fOutcomes==INVALID_HANDLE||fScenarios==INVALID_HANDLE)
   { Print("EMAMonitor v3: output file open error ",GetLastError()); return INIT_FAILED; }
   barsFileWasEmpty=(FileSize(fBars)==0);
   if(barsFileWasEmpty) WriteBarHeader();
   if(FileSize(fEvents)==0) WriteEventHeader();
   if(FileSize(fOutcomes)==0) WriteOutcomeHeader();
   if(FileSize(fScenarios)==0) WriteScenarioHeader();
   FileSeek(fBars,0,SEEK_END); FileSeek(fEvents,0,SEEK_END); FileSeek(fOutcomes,0,SEEK_END); FileSeek(fScenarios,0,SEEK_END);

   if(InpScanHistoryIfFresh && barsFileWasEmpty)
   {
      int total=Bars(_Symbol,CollectTF());
       int scan=MathMin(InpHistoryBars,total-InpBreakoutBars-3);
       for(int shift=scan;shift>=1;shift--)
       {
          if(!ProcessBar(shift,true))
          { Print("EMAMonitor v3.10: history scan paused; indicator data not ready at shift ",shift); break; }
       }
   }
   long trackFromFiles=MaxIdInCsv(outName,15,0)+1;
   long eventFromFiles=MaxIdInCsv(eventsName,36,3)+1;
   // Outcome IDs are linked to source event IDs. Recover the next event sequence from both files.
   nextId=MathMax(nextId,LoadPersistentCounter("TRACKID",1));
   nextId=MathMax(nextId,trackFromFiles);
   nextEventId=MathMax(LoadPersistentCounter("EVENTID",1),eventFromFiles);
   nextEventId=MathMax(nextEventId,MaxIdInCsv(eventsName,36,3)+1);
   SavePersistentCounter("TRACKID",nextId);
   SavePersistentCounter("EVENTID",nextEventId);
   // LASTBAR means the latest fully processed CLOSED bar, not the current forming bar.
   datetime currentBar=iTime(_Symbol,CollectTF(),0);
   datetime latestClosedBar=iTime(_Symbol,CollectTF(),1);
   datetime savedCheckpoint=LoadPersistentBarTime();
   if(barsFileWasEmpty && InpScanHistoryIfFresh)
   {
      lastBarTime=latestClosedBar;
      SavePersistentBarTime(lastBarTime);
   }
   else
   {
      lastBarTime=savedCheckpoint;
      if(lastBarTime==0)
      {
         // No reliable checkpoint: begin from latest closed bar; do not backfill accidentally.
         lastBarTime=latestClosedBar;
         SavePersistentBarTime(lastBarTime);
      }
   }
   lastCurrentBarTime=currentBar;
   // Flush output before saving any new checkpoint.
   Print("EMAMonitor_v3 v3.10 started in collection-only mode: ",_Symbol," ",TFName(),
      ". No orders are sent. Files: ",barsName," | ",eventsName," | ",outName," | ",scenarioName);
   return INIT_SUCCEEDED;
}
void OnTick()
{
   datetime currentBar=iTime(_Symbol,CollectTF(),0);
   if(currentBar==0 || currentBar==lastCurrentBarTime) return;

   int startShift=1;
   if(lastBarTime>0)
   {
      int checkpointShift=iBarShift(_Symbol,CollectTF(),lastBarTime,false);
      if(checkpointShift>1) startShift=checkpointShift-1;
      else if(checkpointShift<0)
      {
         int total=Bars(_Symbol,CollectTF());
         startShift=MathMax(1,MathMin(InpHistoryBars,total-InpBreakoutBars-3));
         Print("EMAMonitor v3.10: checkpoint not present in loaded history; attempting bounded recovery from ",startShift," bars.");
      }
   }

   // Process missed closed bars oldest-to-newest. Advance checkpoint only after
   // successful processing and flushing all output files.
   for(int shift=startShift;shift>=1;shift--)
   {
      datetime closedBarTime=iTime(_Symbol,CollectTF(),shift);
      if(closedBarTime==0 || closedBarTime<=lastBarTime) continue;
      if(!ProcessBar(shift,true))
      {
         Print("EMAMonitor v3.10: data not ready; will retry closed bar ",TimeToString(closedBarTime,TIME_DATE|TIME_SECONDS));
         return;
      }
      FileFlush(fBars);FileFlush(fEvents);FileFlush(fOutcomes);FileFlush(fScenarios);
      SaveScenarioState();
      lastBarTime=closedBarTime;
      SavePersistentBarTime(lastBarTime);
   }
   lastCurrentBarTime=currentBar;
}

void WriteScenarioStats()
{
   string inputName=MakeFile("Scenarios");
   string outputName=MakeFile("ScenarioStats");
   int r=FileOpen(inputName,FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(r==INVALID_HANDLE) { Print("EMAMonitor v3: cannot read scenario results for statistics ",GetLastError()); return; }

   string names[9]; names[0]="FIXED_TP_SL"; names[1]="ATR_TP_SL"; names[2]="ATR_TP_TRAIL";
   names[3]="ATR_BREAK_EVEN"; names[4]="MONEY_RISK_1_5R"; names[5]="FIXED_RR_2R"; names[6]="GRID_AVERAGING_SIM"; names[7]="PERCENT_RISK_1_5R"; names[8]="PYRAMIDING_SIM";
   long count[9],wins[9],losses[9];
   double grossProfit[9],grossLoss[9],netTotal[9],equity[9],peak[9],maxDD[9];
   ArrayInitialize(count,0); ArrayInitialize(wins,0); ArrayInitialize(losses,0);
   ArrayInitialize(grossProfit,0.0); ArrayInitialize(grossLoss,0.0); ArrayInitialize(netTotal,0.0);
   ArrayInitialize(equity,0.0); ArrayInitialize(peak,0.0); ArrayInitialize(maxDD,0.0);

   // Scenario CSV contains 18 columns. Skip the header before reading result rows.
   for(int h=0;h<18 && !FileIsEnding(r);h++) FileReadString(r);
   while(!FileIsEnding(r))
   {
      string fields[18];
      bool hasData=false;
      for(int col=0;col<18;col++)
      {
         if(FileIsEnding(r)) break;
         fields[col]=FileReadString(r);
         if(fields[col]!="") hasData=true;
      }
      if(!hasData) break;
      int idx=-1;
      for(int k=0;k<9;k++) if(fields[7]==names[k]) { idx=k; break; }
      if(idx<0) continue;
      double net=StringToDouble(fields[13]);
      count[idx]++;
      netTotal[idx]+=net;
      if(net>0.0) { wins[idx]++; grossProfit[idx]+=net; }
      else if(net<0.0) { losses[idx]++; grossLoss[idx]+=-net; }
      equity[idx]+=net;
      if(equity[idx]>peak[idx]) peak[idx]=equity[idx];
      double dd=peak[idx]-equity[idx];
      if(dd>maxDD[idx]) maxDD[idx]=dd;
   }
   FileClose(r);

   int w=FileOpen(outputName,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(w==INVALID_HANDLE) { Print("EMAMonitor v3: cannot write scenario statistics ",GetLastError()); return; }
   FileWrite(w,"scenario","closed_simulations","wins","losses","win_rate_percent","net_points",
      "average_net_points","positive_net_points","negative_net_points","profit_factor","max_drawdown_points",
      "cost_model_points_per_trade","symbol","timeframe","note");
   for(int k=0;k<9;k++)
   {
      double winRate=(count[k]>0 ? 100.0*(double)wins[k]/(double)count[k] : 0.0);
      double expectancy=(count[k]>0 ? netTotal[k]/(double)count[k] : 0.0);
      double pf=(grossLoss[k]>0.0 ? grossProfit[k]/grossLoss[k] : (grossProfit[k]>0.0 ? -1.0 : 0.0));
      string pfText=(pf<0.0 ? "NO_LOSSES" : DoubleToString(pf,3));
      FileWrite(w,names[k],count[k],wins[k],losses[k],DoubleToString(winRate,2),
         DoubleToString(netTotal[k],1),DoubleToString(expectancy,2),DoubleToString(grossProfit[k],1),
         DoubleToString(grossLoss[k],1),pfText,DoubleToString(maxDD[k],1),
         DoubleToString(InpSimCostPoints,1),_Symbol,TFName(),
         "Research simulation only; estimated flat cost, not actual spread/commission/slippage; money-risk conversion depends on symbol tick value, account currency and lot size; grid/pyramiding assume simplified equal-size adds; drawdown is not portfolio equity drawdown");
   }
   FileFlush(w); FileClose(w);
}

void OnDeinit(const int reason)
{
   WriteTrackState();
   if(fScenarios!=INVALID_HANDLE) FileFlush(fScenarios);
   WriteScenarioStats();
   SaveScenarioState();
   if(fBars!=INVALID_HANDLE){FileFlush(fBars);FileClose(fBars);}
   if(fEvents!=INVALID_HANDLE){FileFlush(fEvents);FileClose(fEvents);}
   if(fOutcomes!=INVALID_HANDLE){FileFlush(fOutcomes);FileClose(fOutcomes);}
   if(fScenarios!=INVALID_HANDLE){FileFlush(fScenarios);FileClose(fScenarios);}
   if(hFast!=INVALID_HANDLE)IndicatorRelease(hFast);
   if(h50!=INVALID_HANDLE)IndicatorRelease(h50);
   if(h100!=INVALID_HANDLE)IndicatorRelease(h100);
   if(h200!=INVALID_HANDLE)IndicatorRelease(h200);
   if(hStoch!=INVALID_HANDLE)IndicatorRelease(hStoch);
   if(hRSI!=INVALID_HANDLE)IndicatorRelease(hRSI);
   if(hATR!=INVALID_HANDLE)IndicatorRelease(hATR);
   if(hADX!=INVALID_HANDLE)IndicatorRelease(hADX);
   if(hBands!=INVALID_HANDLE)IndicatorRelease(hBands);
   if(hMACD!=INVALID_HANDLE)IndicatorRelease(hMACD);
   Print("EMAMonitor_v3 v3.10 stopped. No trading functions were used.");
}
