//+------------------------------------------------------------------+
//| Expert: ArrowTradeWithFiboTP                                     |
//+------------------------------------------------------------------+
#property strict

// 🔹 Inputs
input string TradeSymbol     = "XAUUSD";       // empty = current chart symbol
input ENUM_TIMEFRAMES TF     = PERIOD_CURRENT; // default: chart timeframe
input double ObserverVirtualLots = 0.10;       // virtual volume only
input double ObserverPartialPercent = 50.0;    // partial-close simulation
input int ObserverMaxVirtualHoldMinutes = 240; // maximum virtual-trade duration
input int ObserverTickSampleMilliseconds = 1000;
input double ObserverFiboTolerancePoints = 2.0;

// 🔹 Global
string symbol;
datetime lastBar = 0;
string lastStatus = "";

// --- Derik1.2 observer: isolated file logging; never changes trading decisions.
datetime observerLastUpArrowTime = 0;
datetime observerLastDownArrowTime = 0;
datetime observerLastUpArrowSeenAt = 0;
datetime observerLastDownArrowSeenAt = 0;
datetime observerStartedAt = 0;
double observerPreviousBid = 0.0;
datetime observerPreviousTickTime = 0;
bool observerLevelNear[10];
double observerLevelMaxAfterTouch[10];
double observerLevelMinAfterTouch[10];
datetime observerLevelTouchTime[10];
string ObserverLevelsFile = "Derik1.2\\Observer_Levels.csv";
string ObserverScenariosFile = "Derik1.2\\Observer_Scenarios.csv";
string ObserverTicksFile = "Derik1.2\\Observer_Ticks.csv";
int observerTrackedTicket = -1;
double observerMaxFloatingProfit = 0.0;
double observerMaxFloatingLoss = 0.0;
datetime observerTradeOpenTime = 0;
double observerTradeOpenPrice = 0.0;
double observerFiboAtEntry[10];
bool observerHasFiboAtEntry = false;
string ObserverFolder = "Derik1.2";
string ObserverEventsFile = "Derik1.2\\Observer_Events.csv";
string ObserverSummaryFile = "Derik1.2\\Observer_Summary.csv";
string ObserverErrorsFile = "Derik1.2\\Observer_Errors.csv";
double observerRatios[10] = {0.0,0.236,0.333,0.382,0.5,0.618,0.667,0.785,0.886,1.0};


string ObserverSignalsFile = "Derik1.2\\Observer_Signals.csv";
string ObserverVirtualTradesFile = "Derik1.2\\Observer_VirtualTrades.csv";
string ObserverExcursionsFile = "Derik1.2\\Observer_Excursions.csv";
string observerChartTF = "";
string observerFiboId = "";
uint observerLastSampleMs = 0;
int observerSignalId = 0;
double observerSignalFiboPrices[5000][10];
int observerSignalRelations[5000][10];

struct VirtualPosition
{
   int signalId;
   int scenario;
   int direction;
   datetime openedAt;
   double entry;
   double tp1;
   double target;
   double stop;
   double initialStop;
   double lots;
   double remainingLots;
   double realizedPointsLots;
   double mfe;
   double mae;
   bool active;
   bool be;
   bool partial;
};
VirtualPosition virtualPositions[];
int virtualCount=0;

string ObserverTFName()
{
   int p=Period();
   if(p==PERIOD_M1)return "M1";
   if(p==PERIOD_M5)return "M5";
   if(p==PERIOD_M15)return "M15";
   if(p==PERIOD_M30)return "M30";
   if(p==PERIOD_H1)return "H1";
   if(p==PERIOD_H4)return "H4";
   if(p==PERIOD_D1)return "D1";
   if(p==PERIOD_W1)return "W1";
   if(p==PERIOD_MN1)return "MN1";
   return "TF"+IntegerToString(p);
}
string ObserverFiboId()
{
   string n="XIT_FIBO";
   if(ObjectFind(0,n)<0||ObjectType(n)!=OBJ_FIBO)return "NO_FIBO";
   datetime t1=(datetime)ObjectGet(n,OBJPROP_TIME1);
   datetime t2=(datetime)ObjectGet(n,OBJPROP_TIME2);
   double p1=ObjectGet(n,OBJPROP_PRICE1),p2=ObjectGet(n,OBJPROP_PRICE2);
   int c=(int)ObjectGetInteger(0,n,OBJPROP_COLOR);
   return "FIB_"+IntegerToString((int)t1)+"_"+IntegerToString((int)t2)+"_"+
          DoubleToString(p1,Digits)+"_"+DoubleToString(p2,Digits)+"_"+IntegerToString(c);
}
void ObserverResetTouches()
{
   for(int i=0;i<10;i++)
   {
      observerLevelNear[i]=false;
      observerLevelMaxAfterTouch[i]=0;
      observerLevelMinAfterTouch[i]=0;
      observerLevelTouchTime[i]=0;
   }
   observerPreviousBid=0;
   observerPreviousTickTime=0;
}
double ObserverLevelByRank(double entry,int direction,bool favorable,int rank)
{
   double candidates[10];int count=0;
   double tol=MarketInfo(symbol,MODE_POINT)*ObserverFiboTolerancePoints;
   for(int i=0;i<10;i++)
   {
      double p=ObserverFiboPrice(observerRatios[i]);
      if(p<=0||MathAbs(p-entry)<=tol)continue;
      bool good=(direction==OP_BUY?p>entry:p<entry);
      if(good==favorable){candidates[count]=p;count++;}
   }
   for(int x=0;x<count-1;x++)
      for(int y=x+1;y<count;y++)
         if(MathAbs(candidates[y]-entry)<MathAbs(candidates[x]-entry))
         {double z=candidates[x];candidates[x]=candidates[y];candidates[y]=z;}
   if(rank<1||rank>count)return 0;
   return candidates[rank-1];
}
string ObserverRelation(double price,double level)
{
   double tol=MarketInfo(symbol,MODE_POINT)*ObserverFiboTolerancePoints;
   if(MathAbs(price-level)<=tol)return "ON";
   return (price>level?"ABOVE":"BELOW");
}
string ObserverLevelName(double price)
{
   int best=-1;double dist=1.0e100;
   for(int i=0;i<10;i++)
   {
      double p=ObserverFiboPrice(observerRatios[i]);
      if(p<=0)continue;
      if(MathAbs(price-p)<dist){dist=MathAbs(price-p);best=i;}
   }
   if(best<0)return "UNAVAILABLE";
   return DoubleToString(observerRatios[best]*100.0,1)+"%";
}
double ObserverMoneyPerPointPerLot()
{
   // In MQL4 MODE_TICKSIZE is expressed in points, not raw price units.
   double ts=MarketInfo(symbol,MODE_TICKSIZE);
   double tv=MarketInfo(symbol,MODE_TICKVALUE);
   if(ts<=0||tv<=0)return 0;
   return tv/ts;
}
void ObserverAddScenario(int sid,int scenario,int dir,double entry,double arrow,double tp1,double target,double sl)
{
   if(virtualCount>=5000)return;
   int n=ArraySize(virtualPositions);
   if(ArrayResize(virtualPositions,n+1)<0)return;
   virtualCount=n+1;
   virtualPositions[n].signalId=sid;
   virtualPositions[n].scenario=scenario;
   virtualPositions[n].direction=dir;
   virtualPositions[n].openedAt=TimeCurrent();
   virtualPositions[n].entry=entry;
   virtualPositions[n].tp1=tp1;
   virtualPositions[n].target=target;
   virtualPositions[n].stop=sl;
   virtualPositions[n].initialStop=sl;
   virtualPositions[n].lots=MathMax(0.0,ObserverVirtualLots);
   virtualPositions[n].remainingLots=MathMax(0.0,ObserverVirtualLots);
   virtualPositions[n].realizedPointsLots=0;
   virtualPositions[n].mfe=0;
   virtualPositions[n].mae=0;
   virtualPositions[n].active=true;
   virtualPositions[n].be=false;
   virtualPositions[n].partial=false;
   string name="TP1";
   if(scenario==2)name="TP2";
   if(scenario==3)name="TP3";
   if(scenario==4)name="BREAKEVEN_TP1_THEN_TP2";
   if(scenario==5)name="PARTIAL_TP1_THEN_TP2";
   if(scenario==6)name="EXIT_ON_OPPOSITE_SIGNAL";
   string d="signal_id=SIG-"+IntegerToString(sid)+", scenario="+name+
      ", scenario_id="+IntegerToString(scenario)+", timeframe="+observerChartTF+
      ", direction="+(dir==OP_BUY?"BUY":"SELL")+", fibo_id="+observerFiboId+
      ", arrow_price="+DoubleToString(arrow,Digits)+", entry_price="+DoubleToString(entry,Digits)+
      ", tp1_price="+DoubleToString(tp1,Digits)+", target_price="+DoubleToString(target,Digits)+
      ", target_fibo="+(target>0?ObserverLevelName(target):"OPPOSITE_SIGNAL")+
      ", initial_stop="+DoubleToString(sl,Digits)+", virtual_lots="+DoubleToString(ObserverVirtualLots,2);
   ObserverWrite(ObserverVirtualTradesFile,"virtual_open",d,sid*10+scenario,TimeCurrent(),entry,0);
   ObserverWrite(ObserverScenariosFile,"scenario_created",d,sid*10+scenario,TimeCurrent(),entry,0);
}
void ObserverMakeScenarios(int sid,int dir,double arrow)
{
   if(ObjectFind(0,"XIT_FIBO")<0||ObjectType("XIT_FIBO")!=OBJ_FIBO)
   {
      ObserverWrite(ObserverSignalsFile,"no_fibo_for_signal",
         "signal_id=SIG-"+IntegerToString(sid)+", timeframe="+observerChartTF,sid,TimeCurrent(),arrow,0);
      return;
   }
   double entry=(dir==OP_BUY?Ask:Bid);
   double tp1=ObserverLevelByRank(entry,dir,true,1);
   double tp2=ObserverLevelByRank(entry,dir,true,2);
   double tp3=ObserverLevelByRank(entry,dir,true,3);
   double sl=ObserverLevelByRank(entry,dir,false,1);
   if(tp1<=0)
   {
      ObserverWrite(ObserverSignalsFile,"no_target_ahead",
         "signal_id=SIG-"+IntegerToString(sid)+", timeframe="+observerChartTF+
         ", direction="+(dir==OP_BUY?"BUY":"SELL")+", entry="+DoubleToString(entry,Digits),
         sid,TimeCurrent(),entry,0);
      return;
   }
   ObserverAddScenario(sid,1,dir,entry,arrow,tp1,tp1,sl);
   if(tp2>0)ObserverAddScenario(sid,2,dir,entry,arrow,tp1,tp2,sl);
   if(tp3>0)ObserverAddScenario(sid,3,dir,entry,arrow,tp1,tp3,sl);
   if(tp2>0)ObserverAddScenario(sid,4,dir,entry,arrow,tp1,tp2,sl);
   if(tp2>0)ObserverAddScenario(sid,5,dir,entry,arrow,tp1,tp2,sl);
   ObserverAddScenario(sid,6,dir,entry,arrow,tp1,0,sl);
}
void ObserverCloseVirtual(int i,double price,string reason)
{
   if(i<0||i>=virtualCount||!virtualPositions[i].active)return;
   int dir=virtualPositions[i].direction;
   double move=(dir==OP_BUY?price-virtualPositions[i].entry:virtualPositions[i].entry-price);
   double points=move/ObserverPointSize();
   double pointsLots=virtualPositions[i].realizedPointsLots+points*virtualPositions[i].remainingLots;
   double avg=(virtualPositions[i].lots>0?pointsLots/virtualPositions[i].lots:0);
   double money=pointsLots*ObserverMoneyPerPointPerLot();
   string result=(money>0?"WIN":(money<0?"LOSS":"BREAKEVEN"));
   string d="signal_id=SIG-"+IntegerToString(virtualPositions[i].signalId)+
      ", scenario_id="+IntegerToString(virtualPositions[i].scenario)+
      ", timeframe="+observerChartTF+", direction="+(dir==OP_BUY?"BUY":"SELL")+
      ", entry="+DoubleToString(virtualPositions[i].entry,Digits)+
      ", exit="+DoubleToString(price,Digits)+", exit_time="+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+
      ", duration_seconds="+IntegerToString((int)(TimeCurrent()-virtualPositions[i].openedAt))+
      ", exit_reason="+reason+", result="+result+", average_points="+DoubleToString(avg,1)+
      ", estimated_gross_money="+DoubleToString(money,2)+", currency="+AccountCurrency()+
      ", mfe_points="+DoubleToString(virtualPositions[i].mfe,1)+
      ", mae_points="+DoubleToString(virtualPositions[i].mae,1)+
      ", initial_sl="+DoubleToString(virtualPositions[i].initialStop,Digits)+
      ", final_sl="+DoubleToString(virtualPositions[i].stop,Digits)+
      ", target_fibo="+(virtualPositions[i].target>0?ObserverLevelName(virtualPositions[i].target):"NONE")+
      ", partial="+(virtualPositions[i].partial?"true":"false")+
      ", breakeven="+(virtualPositions[i].be?"true":"false")+
      ", commission_swap_not_included=true";
   ObserverWrite(ObserverVirtualTradesFile,"virtual_close",d,
      virtualPositions[i].signalId*10+virtualPositions[i].scenario,TimeCurrent(),price,money);
   ObserverWrite(ObserverSummaryFile,"scenario_result",d,
      virtualPositions[i].signalId*10+virtualPositions[i].scenario,TimeCurrent(),price,money);
   ObserverWrite(ObserverScenariosFile,"scenario_result",d,
      virtualPositions[i].signalId*10+virtualPositions[i].scenario,TimeCurrent(),price,money);
   int sid=virtualPositions[i].signalId;
   if(sid>=0 && sid<5000)
   {
      for(int k=0;k<10;k++)
      {
         double lv=observerSignalFiboPrices[sid][k];
         if(lv<=0.0)continue;
         int rel=observerSignalRelations[sid][k];
         string relText=(rel==1?"ABOVE":(rel==-1?"BELOW":(rel==0?"ON":"UNKNOWN")));
         string outcome="signal_id=SIG-"+IntegerToString(sid)+
            ", scenario_id="+IntegerToString(virtualPositions[i].scenario)+
            ", timeframe="+observerChartTF+
            ", direction="+(virtualPositions[i].direction==OP_BUY?"BUY":"SELL")+
            ", level_percent="+DoubleToString(observerRatios[k]*100.0,1)+
            ", level_price_at_signal="+DoubleToString(lv,Digits)+
            ", arrow_relation="+relText+
            ", scenario_result="+result+
            ", estimated_gross_money="+DoubleToString(money,2);
         ObserverWrite(ObserverLevelsFile,"signal_level_outcome",outcome,
            sid*10+virtualPositions[i].scenario,TimeCurrent(),price,money);
      }
   }
   virtualPositions[i].active=false;
}
void ObserverUpdateVirtual()
{
   double pt=ObserverPointSize();if(pt<=0)return;
   for(int i=0;i<virtualCount;i++)
   {
      if(!virtualPositions[i].active)continue;
      int dir=virtualPositions[i].direction;
      double mark=(dir==OP_BUY?Bid:Ask);
      double move=(dir==OP_BUY?mark-virtualPositions[i].entry:virtualPositions[i].entry-mark);
      double pts=move/pt;bool extreme=false;
      if(pts>virtualPositions[i].mfe){virtualPositions[i].mfe=pts;extreme=true;}
      if(pts<virtualPositions[i].mae){virtualPositions[i].mae=pts;extreme=true;}
      if(extreme)
      {
         string ex="signal_id=SIG-"+IntegerToString(virtualPositions[i].signalId)+
            ", scenario_id="+IntegerToString(virtualPositions[i].scenario)+
            ", timeframe="+observerChartTF+", direction="+(dir==OP_BUY?"BUY":"SELL")+
            ", price="+DoubleToString(mark,Digits)+", move_points="+DoubleToString(pts,1)+
            ", mfe_points="+DoubleToString(virtualPositions[i].mfe,1)+
            ", mae_points="+DoubleToString(virtualPositions[i].mae,1)+
            ", nearest_fibo="+ObserverLevelName(mark);
         ObserverWrite(ObserverExcursionsFile,"new_extreme",ex,
            virtualPositions[i].signalId*10+virtualPositions[i].scenario,TimeCurrent(),mark,0);
      }
      int sc=virtualPositions[i].scenario;
      bool hit1=(virtualPositions[i].tp1>0&&
         (dir==OP_BUY?mark>=virtualPositions[i].tp1:mark<=virtualPositions[i].tp1));
      if(sc==4&&hit1&&!virtualPositions[i].be)
      {
         virtualPositions[i].stop=virtualPositions[i].entry;
         virtualPositions[i].be=true;
         ObserverWrite(ObserverVirtualTradesFile,"breakeven_activated",
            "signal_id=SIG-"+IntegerToString(virtualPositions[i].signalId)+
            ", timeframe="+observerChartTF+", trigger_level="+ObserverLevelName(virtualPositions[i].tp1),
            virtualPositions[i].signalId*10+4,TimeCurrent(),mark,0);
      }
      if(sc==5&&hit1&&!virtualPositions[i].partial)
      {
         double pct=MathMax(0,MathMin(100,ObserverPartialPercent));
         double lots=MathMin(virtualPositions[i].lots*pct/100.0,virtualPositions[i].remainingLots);
         double partPts=(dir==OP_BUY?virtualPositions[i].tp1-virtualPositions[i].entry:
                                      virtualPositions[i].entry-virtualPositions[i].tp1)/pt;
         virtualPositions[i].realizedPointsLots+=partPts*lots;
         virtualPositions[i].remainingLots-=lots;
         virtualPositions[i].partial=true;
         virtualPositions[i].be=true;
         virtualPositions[i].stop=virtualPositions[i].entry;
         ObserverWrite(ObserverVirtualTradesFile,"partial_close",
            "signal_id=SIG-"+IntegerToString(virtualPositions[i].signalId)+
            ", timeframe="+observerChartTF+", percent="+DoubleToString(pct,1)+
            ", partial_level="+ObserverLevelName(virtualPositions[i].tp1)+
            ", closed_lots="+DoubleToString(lots,2)+
            ", remaining_lots="+DoubleToString(virtualPositions[i].remainingLots,2),
            virtualPositions[i].signalId*10+5,TimeCurrent(),virtualPositions[i].tp1,0);
      }
      bool stopHit=(virtualPositions[i].stop>0&&
         (dir==OP_BUY?mark<=virtualPositions[i].stop:mark>=virtualPositions[i].stop));
      if(stopHit){ObserverCloseVirtual(i,virtualPositions[i].stop,(virtualPositions[i].be?"BREAKEVEN_STOP":"FIBO_STOP"));continue;}
      bool targetHit=(virtualPositions[i].target>0&&
         (dir==OP_BUY?mark>=virtualPositions[i].target:mark<=virtualPositions[i].target));
      if(targetHit){ObserverCloseVirtual(i,virtualPositions[i].target,(sc==5?"PARTIAL_REMAINDER_TP":"FIBO_TP"));continue;}
      if(ObserverMaxVirtualHoldMinutes>0&&
         TimeCurrent()-virtualPositions[i].openedAt>=ObserverMaxVirtualHoldMinutes*60)
         ObserverCloseVirtual(i,mark,"MAX_HOLD_TIME");
   }
}
void ObserverCloseOpposite(int newDir)
{
   for(int i=0;i<virtualCount;i++)
   {
      if(!virtualPositions[i].active||virtualPositions[i].scenario!=6)continue;
      if(virtualPositions[i].direction==newDir)continue;
      double mark=(virtualPositions[i].direction==OP_BUY?Bid:Ask);
      ObserverCloseVirtual(i,mark,"OPPOSITE_SIGNAL");
   }
}
void ObserverRegisterSignal(int dir,datetime arrowTime,double arrowPrice)
{
   observerSignalId++;int id=observerSignalId;datetime now=TimeCurrent();
   double entry=(dir==OP_BUY?Ask:Bid);
   string d="signal_id=SIG-"+IntegerToString(id)+", timeframe="+observerChartTF+
      ", direction="+(dir==OP_BUY?"BUY":"SELL")+", fibo_id="+observerFiboId+
      ", arrow_time="+TimeToString(arrowTime,TIME_DATE|TIME_SECONDS)+
      ", first_seen="+TimeToString(now,TIME_DATE|TIME_SECONDS)+
      ", arrow_price="+DoubleToString(arrowPrice,Digits)+
      ", executable_entry="+DoubleToString(entry,Digits)+
      ", nearest_fibo="+ObserverNearestFiboText(arrowPrice)+
      ", nearest_level="+ObserverLevelName(arrowPrice);
   ObserverWrite(ObserverSignalsFile,"signal_detected",d,id,now,arrowPrice,0);
   ObserverWrite(ObserverEventsFile,"signal_arrow",d,id,now,arrowPrice,0);
   for(int k=0;k<10;k++)
   {
      double lv=ObserverFiboPrice(observerRatios[k]);if(lv<=0)continue;
      string pos="signal_id=SIG-"+IntegerToString(id)+
         ", timeframe="+observerChartTF+", direction="+(dir==OP_BUY?"BUY":"SELL")+
         ", fibo_id="+observerFiboId+
         ", level_percent="+DoubleToString(observerRatios[k]*100.0,1)+
         ", level_price="+DoubleToString(lv,Digits)+
         ", arrow_price="+DoubleToString(arrowPrice,Digits)+
         ", arrow_relation="+ObserverRelation(arrowPrice,lv);
      if(id>=0 && id<5000)
      {
         observerSignalFiboPrices[id][k]=lv;
         observerSignalRelations[id][k]=(ObserverRelation(arrowPrice,lv)=="ABOVE"?1:
            (ObserverRelation(arrowPrice,lv)=="BELOW"?-1:0));
      }
      ObserverWrite(ObserverLevelsFile,"signal_level_position",pos,id,now,arrowPrice,0);
   }
   ObserverCloseOpposite(dir);
   ObserverMakeScenarios(id,dir,arrowPrice);
}
void ObserverWriteTickTrace()
{
   uint ms=GetTickCount();
   if(observerLastSampleMs!=0&&
      (uint)(ms-observerLastSampleMs)<(uint)MathMax(100,ObserverTickSampleMilliseconds))return;
   observerLastSampleMs=ms;double pt=ObserverPointSize();
   string d="timeframe="+observerChartTF+", fibo_id="+observerFiboId+
      ", bid="+DoubleToString(Bid,Digits)+", ask="+DoubleToString(Ask,Digits)+
      ", spread_points="+DoubleToString((Ask-Bid)/pt,1)+
      ", tick_value="+DoubleToString(MarketInfo(symbol,MODE_TICKVALUE),4)+
      ", tick_size="+DoubleToString(MarketInfo(symbol,MODE_TICKSIZE),Digits)+
      ", sample_uptime_ms="+IntegerToString((int)ms)+", "+ObserverFiboSnapshot();
   ObserverWrite(ObserverTicksFile,"sampled_price",d,-1,TimeCurrent(),Bid,0);
}

string ObserverSafe(string value)
{
   StringReplace(value, ";", ",");
   StringReplace(value, "\r", " ");
   StringReplace(value, "\n", " ");
   return value;
}

void ObserverWrite(string fileName, string eventType, string detail, int ticket, datetime eventTime, double price, double net)
{
   FolderCreate(ObserverFolder);
   ResetLastError();
   int h = FileOpen(fileName, FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE, ';');
   if(h == INVALID_HANDLE)
   {
      int err=GetLastError();
      Print("Derik1.2 CSV open failed: ",fileName," error=",err);
      return;
   }
   if(FileSize(h) == 0)
      FileWrite(h, "server_time","event","detail","ticket","price","net_profit_swap_commission");
   FileSeek(h, 0, SEEK_END);
   FileWrite(h, TimeToString(eventTime,TIME_DATE|TIME_SECONDS), eventType, ObserverSafe(detail),
             IntegerToString(ticket), DoubleToString(price,Digits), DoubleToString(net,2));
   FileFlush(h);
   FileClose(h);
}

void ObserverWriteError(string detail)
{
   ObserverWrite(ObserverErrorsFile,"observer_error",detail,-1,TimeCurrent(),0,0);
}

double ObserverFiboPrice(double ratio)
{
   string objName = "XIT_FIBO";
   if(ObjectFind(0,objName)<0 || ObjectType(objName)!=OBJ_FIBO) return 0.0;
   double p1=ObjectGet(objName,OBJPROP_PRICE1), p2=ObjectGet(objName,OBJPROP_PRICE2);
   if(p1==0 || p2==0) return 0.0;
   int c=(int)ObjectGetInteger(0,objName,OBJPROP_COLOR);
   bool rev=(c==clrRed || c==clrBlue);
   return rev ? p2+(p1-p2)*ratio : p1+(p2-p1)*ratio;
}

string ObserverFiboSnapshot()
{
   string s="fibo_object=XIT_FIBO";
   if(ObjectFind(0,"XIT_FIBO")<0 || ObjectType("XIT_FIBO")!=OBJ_FIBO)
      return s+"; fibo_available=false";
   double p1=ObjectGet("XIT_FIBO",OBJPROP_PRICE1), p2=ObjectGet("XIT_FIBO",OBJPROP_PRICE2);
   int c=(int)ObjectGetInteger(0,"XIT_FIBO",OBJPROP_COLOR);
   s += "; fibo_available=true; price1="+DoubleToString(p1,Digits)+"; price2="+DoubleToString(p2,Digits);
   s += "; color="+IntegerToString(c);
   for(int i=0;i<10;i++)
      s += "; L"+DoubleToString(observerRatios[i]*100.0,1)+"="+DoubleToString(ObserverFiboPrice(observerRatios[i]),Digits);
   return s;
}

int ObserverNearestFibo(double price)
{
   double bestDist=1.0e100;
   int best=-1;
   for(int i=0;i<10;i++)
   {
      double p=ObserverFiboPrice(observerRatios[i]);
      if(p==0.0) continue;
      double d=MathAbs(price-p);
      if(d<bestDist) { bestDist=d; best=i; }
   }
   return best;
}

string ObserverNearestFiboText(double price)
{
   int i=ObserverNearestFibo(price);
   if(i<0) return "nearest_fibo=unavailable";
   return "nearest_fibo="+DoubleToString(observerRatios[i]*100.0,1)+"%; fibo_price="+DoubleToString(ObserverFiboPrice(observerRatios[i]),Digits);
}


void ObserverCheckArrows()
{
   string names[2]={"UpArrow","DownArrow"};
   for(int i=0;i<2;i++)
   {
      string n=names[i];
      if(ObjectFind(0,n)<0||ObjectType(n)!=OBJ_ARROW)continue;
      datetime at=(datetime)ObjectGet(n,OBJPROP_TIME1);
      double p=ObjectGet(n,OBJPROP_PRICE1);
      if(at<=0||p<=0)continue;
      if(i==0&&at!=observerLastUpArrowTime)
      {observerLastUpArrowTime=at;observerLastUpArrowSeenAt=TimeCurrent();ObserverRegisterSignal(OP_BUY,at,p);}
      if(i==1&&at!=observerLastDownArrowTime)
      {observerLastDownArrowTime=at;observerLastDownArrowSeenAt=TimeCurrent();ObserverRegisterSignal(OP_SELL,at,p);}
   }
}

double ObserverPointSize()
{
   return MarketInfo(symbol, MODE_POINT);
}

double ObserverPipSize()
{
   int digits=(int)MarketInfo(symbol, MODE_DIGITS);
   double point=ObserverPointSize();
   if(digits==3 || digits==5) return point*10.0;
   return point;
}

void ObserverWriteLevel(string eventType,string detail,datetime at,double price,int ticket)
{
   ObserverWrite(ObserverLevelsFile,eventType,detail,ticket,at,price,0.0);
}


void ObserverWriteTickTrace()
{
   double point=ObserverPointSize();
   double pip=ObserverPipSize();
   string detail="bid="+DoubleToString(Bid,Digits)+
      "; ask="+DoubleToString(Ask,Digits)+
      "; spread_points="+DoubleToString((Ask-Bid)/point,1)+
      "; point_size="+DoubleToString(point,Digits)+
      "; pip_size="+DoubleToString(pip,Digits)+
      "; tick_value="+DoubleToString(MarketInfo(symbol,MODE_TICKVALUE),4)+
      "; tick_size="+DoubleToString(MarketInfo(symbol,MODE_TICKSIZE),Digits)+
      "; "+ObserverFiboSnapshot();
   ObserverWrite(ObserverTicksFile,"price_tick",detail,-1,TimeCurrent(),Bid,0.0);
}

void ObserverTrackFiboTouches()
{
   double bid=Bid;
   double point=ObserverPointSize();
   if(point<=0 || bid<=0) return;
   double tolerance=point*2.0;
   for(int i=0;i<10;i++)
   {
      double level=ObserverFiboPrice(observerRatios[i]);
      if(level<=0) continue;
      double dist=MathAbs(bid-level);
      bool crossed=false;
      if(observerPreviousBid>0)
      {
         double lo=MathMin(observerPreviousBid,bid), hi=MathMax(observerPreviousBid,bid);
         crossed=(level>=lo && level<=hi);
      }
      bool near=(dist<=tolerance);
      if((crossed || (near && !observerLevelNear[i])) && !observerLevelNear[i])
      {
         observerLevelTouchTime[i]=TimeCurrent();
         observerLevelMaxAfterTouch[i]=bid;
         observerLevelMinAfterTouch[i]=bid;
         string crossing=(bid>observerPreviousBid ? "upward" : (bid<observerPreviousBid ? "downward" : "near_start"));
         ObserverWriteLevel("fibo_touch",
            "level_percent="+DoubleToString(observerRatios[i]*100.0,1)+
            "; level_price="+DoubleToString(level,Digits)+
            "; bid="+DoubleToString(bid,Digits)+
            "; previous_bid="+DoubleToString(observerPreviousBid,Digits)+
            "; crossing="+crossing+
            "; gap_points="+DoubleToString(MathAbs(bid-observerPreviousBid)/point,1)+
            "; tolerance_points=2; tick_time_gap_seconds="+IntegerToString((int)(TimeCurrent()-observerPreviousTickTime))+
            "; "+ObserverFiboSnapshot(),TimeCurrent(),bid,-1);
         observerLevelNear[i]=true;
      }
      if(observerLevelTouchTime[i]>0)
      {
         if(bid>observerLevelMaxAfterTouch[i]) observerLevelMaxAfterTouch[i]=bid;
         if(bid<observerLevelMinAfterTouch[i]) observerLevelMinAfterTouch[i]=bid;
      }
      if(observerLevelNear[i] && dist>tolerance*3.0 && observerLevelTouchTime[i]>0)
      {
         ObserverWriteLevel("fibo_touch_reaction",
            "level_percent="+DoubleToString(observerRatios[i]*100.0,1)+
            "; level_price="+DoubleToString(level,Digits)+
            "; touch_time="+TimeToString(observerLevelTouchTime[i],TIME_DATE|TIME_SECONDS)+
            "; reaction_time="+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+
            "; elapsed_seconds="+IntegerToString((int)(TimeCurrent()-observerLevelTouchTime[i]))+
            "; max_price_since_touch="+DoubleToString(observerLevelMaxAfterTouch[i],Digits)+
            "; min_price_since_touch="+DoubleToString(observerLevelMinAfterTouch[i],Digits)+
            "; max_favorable_from_level_points="+DoubleToString((observerLevelMaxAfterTouch[i]-level)/point,1)+
            "; max_adverse_from_level_points="+DoubleToString((observerLevelMinAfterTouch[i]-level)/point,1)+
            "; current_price="+DoubleToString(bid,Digits)+
            "; current_distance_from_level_points="+DoubleToString((bid-level)/point,1)+
            "; reaction_direction="+(bid>level ? "above_level" : "below_level")+
            "; "+ObserverFiboSnapshot(),TimeCurrent(),bid,-1);
         observerLevelTouchTime[i]=0;
         observerLevelNear[i]=false;
      }
      else if(dist>tolerance*3.0) observerLevelNear[i]=false;
   }
   observerPreviousBid=bid;
   observerPreviousTickTime=TimeCurrent();
}


void ObserverTick()
{
   string current=ObserverFiboId();
   if(current!=observerFiboId)
   {
      observerFiboId=current;ObserverResetTouches();
      ObserverWrite(ObserverEventsFile,"fibo_structure_changed",
         "timeframe="+observerChartTF+", fibo_id="+observerFiboId+
         ", snapshot="+ObserverFiboSnapshot(),-1,TimeCurrent(),Bid,0);
   }
   ObserverCheckArrows();
   ObserverWriteTickTrace();
   ObserverTrackFiboTouches();
   ObserverUpdateVirtual();
}


int OnInit()
{
   symbol=Symbol();observerChartTF=ObserverTFName();
   observerStartedAt=TimeCurrent();observerFiboId=ObserverFiboId();
   FolderCreate(ObserverFolder);
   ObserverWrite(ObserverEventsFile,"observer_started",
      "version=Derik1.2, mode=OBSERVER_ONLY, symbol="+symbol+
      ", chart_timeframe="+observerChartTF+
      ", configured_timeframe="+IntegerToString((int)TF)+
      ", no_real_orders=true, virtual_lots="+DoubleToString(ObserverVirtualLots,2),
      -1,TimeCurrent(),Bid,0);
   ObserverWrite(ObserverSignalsFile,"file_initialized","timeframe="+observerChartTF,-1,TimeCurrent(),Bid,0);
   ObserverWrite(ObserverVirtualTradesFile,"file_initialized","timeframe="+observerChartTF,-1,TimeCurrent(),Bid,0);
   ObserverWrite(ObserverExcursionsFile,"file_initialized","timeframe="+observerChartTF,-1,TimeCurrent(),Bid,0);
   ObserverWrite(ObserverScenariosFile,"file_initialized","timeframe="+observerChartTF,-1,TimeCurrent(),Bid,0);
   ObserverWrite(ObserverLevelsFile,"observer_started",
      "timeframe="+observerChartTF+
      ", point_size="+DoubleToString(MarketInfo(symbol,MODE_POINT),Digits)+
      ", tick_value="+DoubleToString(MarketInfo(symbol,MODE_TICKVALUE),2)+
      ", tick_size="+DoubleToString(MarketInfo(symbol,MODE_TICKSIZE),Digits)+
      ", account_currency="+AccountCurrency(),-1,TimeCurrent(),Bid,0);
   Print("Derik1.2 observer-only started on "+symbol+" "+observerChartTF);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   ObserverWrite(ObserverEventsFile,"observer_stopped",
      "timeframe="+observerChartTF+", reason="+IntegerToString(reason)+
      ", virtual_scenario_records="+IntegerToString(virtualCount),
      -1,TimeCurrent(),Bid,0);
   Print("Derik1.2 observer-only stopped on "+symbol+" "+observerChartTF);
}
void OnTick()
{
   if(TradeSymbol!=""&&Symbol()!=TradeSymbol)return;
   if(TF!=PERIOD_CURRENT&&Period()!=(int)TF)return;
   ObserverTick();
}
