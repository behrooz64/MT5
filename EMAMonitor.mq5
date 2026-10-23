//+------------------------------------------------------------------+
//|                                                EMAMonitor.mq5    |
//| Independent, non-trading EMA/Stochastic observation EA           |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Logs EMA and Stochastic observations to CSV. Does not trade."

input int      InpFastEMA       = 15;
input int      InpEMA50         = 50;
input int      InpEMA100        = 100;
input int      InpEMA200        = 200;
input int      InpStochK        = 5;
input int      InpStochD        = 3;
input int      InpStochSlowing  = 2;
input double   InpOverbought    = 80.0;
input double   InpOversold      = 20.0;
input int      InpHistoryBars   = 2000;
input int      InpOutcomeBars   = 40;
input bool     InpLogEveryBar   = true;
input string   InpCSVFile       = "EMAMonitor.csv";

int hFast = INVALID_HANDLE, h50 = INVALID_HANDLE;
int h100 = INVALID_HANDLE, h200 = INVALID_HANDLE, hStoch = INVALID_HANDLE;
datetime lastBarTime = 0;
int csvHandle = INVALID_HANDLE;

struct SignalTrack
{
   datetime time;
   int direction;          // 1=buy candidate, -1=sell candidate
   double entry;
   int barsSeen;
   double mfe;
   double mae;
};
SignalTrack tracks[];
int trackCount = 0;

double PipPoint()
{
   // Store raw symbol points consistently; interpretation depends on symbol digits.
   return _Point;
}

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

void WriteHeader()
{
   if(csvHandle==INVALID_HANDLE) return;
   if(FileSize(csvHandle)==0)
   {
      FileWrite(csvHandle,
         "event_time","symbol","timeframe","event_type","direction",
         "open","high","low","close","ema15","ema50","ema100","ema200",
         "close_to_ema15_points","close_to_ema50_points",
         "close_to_ema100_points","close_to_ema200_points",
         "stoch_main","stoch_signal","main_prev","signal_prev",
         "ema_bull_stack","ema_bear_stack","mfe_points","mae_points",
         "outcome_bars_observed");
      FileFlush(csvHandle);
   }
}

string TFName()
{
   return EnumToString((ENUM_TIMEFRAMES)_Period);
}

void AddTrack(const datetime t,const int direction,const double entry)
{
   int n=ArraySize(tracks);
   if(ArrayResize(tracks,n+1)!=n+1) return;
   tracks[n].time=t;
   tracks[n].direction=direction;
   tracks[n].entry=entry;
   tracks[n].barsSeen=0;
   tracks[n].mfe=0.0;
   tracks[n].mae=0.0;
   trackCount=n+1;
}

void UpdateTracks(const MqlRates &bar)
{
   for(int i=ArraySize(tracks)-1;i>=0;i--)
   {
      double favourable=0.0, adverse=0.0;
      if(tracks[i].direction==1)
      {
         favourable=(bar.high-tracks[i].entry)/PipPoint();
         adverse=(tracks[i].entry-bar.low)/PipPoint();
      }
      else
      {
         favourable=(tracks[i].entry-bar.low)/PipPoint();
         adverse=(bar.high-tracks[i].entry)/PipPoint();
      }
      if(favourable>tracks[i].mfe) tracks[i].mfe=favourable;
      if(adverse>tracks[i].mae) tracks[i].mae=adverse;
      tracks[i].barsSeen++;

      if(tracks[i].barsSeen>=InpOutcomeBars)
      {
         if(csvHandle!=INVALID_HANDLE)
         {
            FileWrite(csvHandle,
               TimeToString(tracks[i].time,TIME_DATE|TIME_MINUTES),
               _Symbol,TFName(),"SIGNAL_OUTCOME",
               (tracks[i].direction==1 ? "BUY_CANDIDATE" : "SELL_CANDIDATE"),
               "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
               DoubleToString(tracks[i].mfe,1),DoubleToString(tracks[i].mae,1),
               tracks[i].barsSeen);
         }
         for(int j=i;j<ArraySize(tracks)-1;j++) tracks[j]=tracks[j+1];
         ArrayResize(tracks,ArraySize(tracks)-1);
         trackCount=ArraySize(tracks);
      }
   }
}

void ProcessBar(const int shift,const bool updateTracks)
{
   MqlRates bar;
   if(!ReadBar(shift,bar)) return;

   double e15,e50,e100,e200,main0,sig0,main1,sig1;
   if(!ReadValue(hFast,0,shift,e15) || !ReadValue(h50,0,shift,e50) ||
      !ReadValue(h100,0,shift,e100) || !ReadValue(h200,0,shift,e200) ||
      !ReadValue(hStoch,0,shift,main0) || !ReadValue(hStoch,1,shift,sig0) ||
      !ReadValue(hStoch,0,shift+1,main1) || !ReadValue(hStoch,1,shift+1,sig1))
      return;

   bool bull=(e50>e100 && e100>e200);
   bool bear=(e50<e100 && e100<e200);
   bool crossUp=(main1<=sig1 && main0>sig0);
   bool crossDown=(main1>=sig1 && main0<sig0);
   bool buyCandidate=(bull && crossUp && main0<InpOversold);
   bool sellCandidate=(bear && crossDown && main0>InpOverbought);

   string eventType="BAR";
   string direction="NONE";
   if(buyCandidate) { eventType="BUY_CANDIDATE"; direction="BUY"; }
   else if(sellCandidate) { eventType="SELL_CANDIDATE"; direction="SELL"; }
   else if(crossUp) eventType="STOCH_CROSS_UP";
   else if(crossDown) eventType="STOCH_CROSS_DOWN";
   else if(bar.low<=e15 && bar.high>=e15) eventType="TOUCH_EMA15";
   else if(bar.low<=e50 && bar.high>=e50) eventType="TOUCH_EMA50";
   else if(bar.low<=e100 && bar.high>=e100) eventType="TOUCH_EMA100";
   else if(bar.low<=e200 && bar.high>=e200) eventType="TOUCH_EMA200";

   if(csvHandle!=INVALID_HANDLE && (InpLogEveryBar || eventType!="BAR"))
   {
      FileWrite(csvHandle,
         TimeToString(bar.time,TIME_DATE|TIME_MINUTES),_Symbol,TFName(),
         eventType,direction,
         DoubleToString(bar.open,_Digits),DoubleToString(bar.high,_Digits),
         DoubleToString(bar.low,_Digits),DoubleToString(bar.close,_Digits),
         DoubleToString(e15,_Digits),DoubleToString(e50,_Digits),
         DoubleToString(e100,_Digits),DoubleToString(e200,_Digits),
         DoubleToString((bar.close-e15)/_Point,1),
         DoubleToString((bar.close-e50)/_Point,1),
         DoubleToString((bar.close-e100)/_Point,1),
         DoubleToString((bar.close-e200)/_Point,1),
         DoubleToString(main0,2),DoubleToString(sig0,2),
         DoubleToString(main1,2),DoubleToString(sig1,2),
         (bull ? "true" : "false"),(bear ? "true" : "false"),
         "", "", "");
   }

   if(updateTracks)
   {
      if(buyCandidate) AddTrack(bar.time,1,bar.close);
      if(sellCandidate) AddTrack(bar.time,-1,bar.close);
      UpdateTracks(bar);
   }
}

int OnInit()
{
   hFast=iMA(_Symbol,_Period,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   h50=iMA(_Symbol,_Period,InpEMA50,0,MODE_EMA,PRICE_CLOSE);
   h100=iMA(_Symbol,_Period,InpEMA100,0,MODE_EMA,PRICE_CLOSE);
   h200=iMA(_Symbol,_Period,InpEMA200,0,MODE_EMA,PRICE_CLOSE);
   hStoch=iStochastic(_Symbol,_Period,InpStochK,InpStochD,InpStochSlowing,MODE_SMA,STO_LOWHIGH);

   if(hFast==INVALID_HANDLE || h50==INVALID_HANDLE || h100==INVALID_HANDLE ||
      h200==INVALID_HANDLE || hStoch==INVALID_HANDLE)
   {
      Print("EMAMonitor: failed to create indicator handle(s). Error=",GetLastError());
      return INIT_FAILED;
   }

   csvHandle=FileOpen(InpCSVFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
   if(csvHandle==INVALID_HANDLE)
   {
      Print("EMAMonitor: could not open CSV file. Error=",GetLastError());
      return INIT_FAILED;
   }
   FileSeek(csvHandle,0,SEEK_END);
   WriteHeader();

   int bars=Bars(_Symbol,_Period);
   int scan=MathMin(InpHistoryBars,bars-2);
   for(int shift=scan;shift>=1;shift--)
      ProcessBar(shift,false);

   lastBarTime=iTime(_Symbol,_Period,0);
   Print("EMAMonitor: started on ",_Symbol," ",TFName(),
         ". No orders will be sent. CSV: MQL5/Files/",InpCSVFile);
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
   Print("EMAMonitor: stopped.");
}
