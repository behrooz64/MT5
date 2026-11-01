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
string ObserverFiboStatsFile = "";
string ObserverDailySummaryFile = "";
string ObserverLevelReachedFile = "";
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
   double tp2;
   double tp3;
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
   int partialStage;
   string fiboBucketRange;
   string nearestFiboBucket;
   datetime mfeAt;
   datetime maeAt;
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
string ObserverNearestFiboBucket(double price)
{
   int k=ObserverNearestFibo(price);
   if(k<0)return "UNAVAILABLE";
   return DoubleToString(observerRatios[k]*100.0,1);
}
string ObserverFiboBucketRange(double price)
{
   double p[10];
   for(int i=0;i<10;i++)p[i]=ObserverFiboPrice(observerRatios[i]);
   for(int i=0;i<9;i++)
   {
      if(p[i]<=0||p[i+1]<=0)continue;
      double lo=MathMin(p[i],p[i+1]),hi=MathMax(p[i],p[i+1]);
      if(price>=lo&&price<=hi)
         return DoubleToString(observerRatios[i]*100.0,1)+"_"+DoubleToString(observerRatios[i+1]*100.0,1);
   }
   int nearest=ObserverNearestFibo(price);
   if(nearest<0)return "UNAVAILABLE";
   if(nearest==0)return DoubleToString(observerRatios[0]*100.0,1)+"_OUTSIDE";
   if(nearest==9)return "OUTSIDE_"+DoubleToString(observerRatios[9]*100.0,1);
   return DoubleToString(observerRatios[nearest-1]*100.0,1)+"_"+DoubleToString(observerRatios[nearest+1]*100.0,1);
}
string ObserverStatKey(string prefix,string direction,string bucket,int scenario,string tfScope,string day)
{
   string key=prefix+"_"+symbol+"_"+tfScope+"_"+direction+"_"+bucket+"_S"+
      IntegerToString(scenario)+"_"+day;
   StringReplace(key,".","_");StringReplace(key,"%","P");StringReplace(key,"-","_");
   if(StringLen(key)>60)key=StringSubstr(key,0,60);
   return key;
}
double ObserverStatValue(string key)
{
   if(!GlobalVariableCheck(key))return 0.0;
   return GlobalVariableGet(key);
}
void ObserverPersistStats(string direction,string bucket,int scenario,string day,double money)
{
   string a[4],b[4],c[4];
   a[0]=ObserverStatKey("T1N",direction,bucket,-1,"ALLTF","ALL");
   a[1]=ObserverStatKey("T1W",direction,bucket,-1,"ALLTF","ALL");
   a[2]=ObserverStatKey("T1L",direction,bucket,-1,"ALLTF","ALL");
   a[3]=ObserverStatKey("T1P",direction,bucket,-1,"ALLTF","ALL");
   b[0]=ObserverStatKey("T2N",direction,bucket,scenario,"ALLTF","ALL");
   b[1]=ObserverStatKey("T2W",direction,bucket,scenario,"ALLTF","ALL");
   b[2]=ObserverStatKey("T2L",direction,bucket,scenario,"ALLTF","ALL");
   b[3]=ObserverStatKey("T2P",direction,bucket,scenario,"ALLTF","ALL");
   c[0]=ObserverStatKey("T3N",direction,bucket,scenario,observerChartTF,"ALL");
   c[1]=ObserverStatKey("T3W",direction,bucket,scenario,observerChartTF,"ALL");
   c[2]=ObserverStatKey("T3L",direction,bucket,scenario,observerChartTF,"ALL");
   c[3]=ObserverStatKey("T3P",direction,bucket,scenario,observerChartTF,"ALL");
   string groups[3][4];
   for(int x=0;x<4;x++){groups[0][x]=a[x];groups[1][x]=b[x];groups[2][x]=c[x];}
   for(int g=0;g<3;g++)
   {
      GlobalVariableSet(groups[g][0],ObserverStatValue(groups[g][0])+1.0);
      if(money>0)GlobalVariableSet(groups[g][1],ObserverStatValue(groups[g][1])+1.0);
      if(money<0)GlobalVariableSet(groups[g][2],ObserverStatValue(groups[g][2])+1.0);
      GlobalVariableSet(groups[g][3],ObserverStatValue(groups[g][3])+money);
   }
   string dayKeys[4];
   dayKeys[0]=ObserverStatKey("DAYN",direction,bucket,scenario,observerChartTF,day);
   dayKeys[1]=ObserverStatKey("DAYW",direction,bucket,scenario,observerChartTF,day);
   dayKeys[2]=ObserverStatKey("DAYL",direction,bucket,scenario,observerChartTF,day);
   dayKeys[3]=ObserverStatKey("DAYP",direction,bucket,scenario,observerChartTF,day);
   GlobalVariableSet(dayKeys[0],ObserverStatValue(dayKeys[0])+1.0);
   if(money>0)GlobalVariableSet(dayKeys[1],ObserverStatValue(dayKeys[1])+1.0);
   if(money<0)GlobalVariableSet(dayKeys[2],ObserverStatValue(dayKeys[2])+1.0);
   GlobalVariableSet(dayKeys[3],ObserverStatValue(dayKeys[3])+money);
   string row="timeframe="+observerChartTF+", direction="+direction+
      ", fibo_bucket_range="+bucket+", nearest_fibo_bucket=entry_nearest_level"+
      ", scenario_id="+IntegerToString(scenario)+", day_server="+day+
      ", tier1_count="+DoubleToString(ObserverStatValue(a[0]),0)+
      ", tier1_wins="+DoubleToString(ObserverStatValue(a[1]),0)+
      ", tier1_losses="+DoubleToString(ObserverStatValue(a[2]),0)+
      ", tier1_net="+DoubleToString(ObserverStatValue(a[3]),2)+
      ", tier2_count="+DoubleToString(ObserverStatValue(b[0]),0)+
      ", tier2_wins="+DoubleToString(ObserverStatValue(b[1]),0)+
      ", tier2_losses="+DoubleToString(ObserverStatValue(b[2]),0)+
      ", tier2_net="+DoubleToString(ObserverStatValue(b[3]),2)+
      ", tier3_count="+DoubleToString(ObserverStatValue(c[0]),0)+
      ", tier3_wins="+DoubleToString(ObserverStatValue(c[1]),0)+
      ", tier3_losses="+DoubleToString(ObserverStatValue(c[2]),0)+
      ", tier3_net="+DoubleToString(ObserverStatValue(c[3]),2)+
      ", daily_count="+DoubleToString(ObserverStatValue(dayKeys[0]),0)+
      ", daily_wins="+DoubleToString(ObserverStatValue(dayKeys[1]),0)+
      ", daily_losses="+DoubleToString(ObserverStatValue(dayKeys[2]),0)+
      ", daily_net="+DoubleToString(ObserverStatValue(dayKeys[3]),2);
   ObserverWrite(ObserverFiboStatsFile,"bucket_cumulative",row,scenario,TimeCurrent(),0,money);
   ObserverWrite(ObserverDailySummaryFile,"daily_bucket_summary",row,scenario,TimeCurrent(),0,money);
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
   virtualPositions[n].tp2=0.0;
   virtualPositions[n].tp3=0.0;
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
   virtualPositions[n].partialStage=0;
   virtualPositions[n].fiboBucketRange=ObserverFiboBucketRange(entry);
   virtualPositions[n].nearestFiboBucket=ObserverNearestFiboBucket(entry);
   virtualPositions[n].mfeAt=TimeCurrent();
   virtualPositions[n].maeAt=TimeCurrent();
   string name="TP1";
   if(scenario==2)name="TP2";
   if(scenario==3)name="TP3";
   if(scenario==4)name="BREAKEVEN_TP1_THEN_TP2";
   if(scenario==5)name="PARTIAL_TP1_THEN_TP2";
   if(scenario==6)name="EXIT_ON_OPPOSITE_SIGNAL";
   if(scenario==7)name="BE_AFTER_10_POINTS";
   if(scenario==8)name="BE_AFTER_20_POINTS";
   if(scenario==9)name="BE_AFTER_1R";
   if(scenario==10)name="BE_AT_TP2_THEN_TP3";
   if(scenario==11)name="PARTIAL_30_30_40";
   if(scenario==12)name="PARTIAL_25_25_25_25";
   if(scenario==20)name="TP2_FIXED_SL_10_POINTS";
   if(scenario==21)name="TP2_FIXED_SL_20_POINTS";
   if(scenario==22)name="TP2_FIXED_SL_30_POINTS";
   if(scenario==23)name="TP2_ATR_SL_1X";
   if(scenario==24)name="TP2_ATR_SL_1_5X";
   if(scenario==25)name="TP2_SWING_SL_10_BARS";
   string d="signal_id=SIG-"+IntegerToString(sid)+", scenario="+name+
      ", scenario_id="+IntegerToString(scenario)+", timeframe="+observerChartTF+
      ", direction="+(dir==OP_BUY?"BUY":"SELL")+", fibo_id="+observerFiboId+
      ", entry_time="+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+
      ", entry_hour_server="+IntegerToString(TimeHour(TimeCurrent()))+
      ", entry_weekday_server="+IntegerToString(TimeDayOfWeek(TimeCurrent()))+
      ", arrow_price="+DoubleToString(arrow,Digits)+", entry_price="+DoubleToString(entry,Digits)+
      ", spread_points="+DoubleToString((Ask-Bid)/ObserverPointSize(),1)+
      ", fibo_bucket_range="+virtualPositions[n].fiboBucketRange+
      ", nearest_fibo_bucket="+virtualPositions[n].nearestFiboBucket+
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
   double tp4=ObserverLevelByRank(entry,dir,true,4);
   double sl=ObserverLevelByRank(entry,dir,false,1);
   if(tp1<=0)
   {
      ObserverWrite(ObserverSignalsFile,"no_target_ahead",
         "signal_id=SIG-"+IntegerToString(sid)+", timeframe="+observerChartTF+
         ", direction="+(dir==OP_BUY?"BUY":"SELL")+", entry="+DoubleToString(entry,Digits),
         sid,TimeCurrent(),entry,0);
      return;
   }

   // Fibonacci target ladders with the nearest adverse Fibonacci stop.
   ObserverAddScenario(sid,1,dir,entry,arrow,tp1,tp1,sl);
   if(tp2>0)ObserverAddScenario(sid,2,dir,entry,arrow,tp1,tp2,sl);
   if(tp3>0)ObserverAddScenario(sid,3,dir,entry,arrow,tp1,tp3,sl);

   // Break-even variations: first target, fixed 10/20 points, 1R, or TP2.
   if(tp2>0)
   {
      ObserverAddScenario(sid,4,dir,entry,arrow,tp1,tp2,sl);
      ObserverAddScenario(sid,7,dir,entry,arrow,entry+(dir==OP_BUY?1:-1)*10*ObserverPointSize(),tp2,sl);
      ObserverAddScenario(sid,8,dir,entry,arrow,entry+(dir==OP_BUY?1:-1)*20*ObserverPointSize(),tp2,sl);
      if(sl>0)
      {
         double risk=MathAbs(entry-sl);
         ObserverAddScenario(sid,9,dir,entry,arrow,entry+(dir==OP_BUY?1:-1)*risk,tp2,sl);
      }
   }
   if(tp2>0&&tp3>0)ObserverAddScenario(sid,10,dir,entry,arrow,tp2,tp3,sl);

   // Partial-close models: 50%, 30/30/40, and 25/25/25/25.
   if(tp2>0)ObserverAddScenario(sid,5,dir,entry,arrow,tp1,tp2,sl);
   if(tp2>0&&tp3>0)
   {
      ObserverAddScenario(sid,11,dir,entry,arrow,tp1,tp3,sl);
      virtualPositions[virtualCount-1].tp2=tp2;
   }
   if(tp2>0&&tp3>0&&tp4>0)
   {
      ObserverAddScenario(sid,12,dir,entry,arrow,tp1,tp4,sl);
      virtualPositions[virtualCount-1].tp2=tp2;
      virtualPositions[virtualCount-1].tp3=tp3;
   }

   // Alternative stop models, each compared against the same TP2 target.
   if(tp2>0)
   {
      double pt=ObserverPointSize();
      ObserverAddScenario(sid,20,dir,entry,arrow,tp2,tp2,entry-(dir==OP_BUY?1:-1)*10*pt);
      ObserverAddScenario(sid,21,dir,entry,arrow,tp2,tp2,entry-(dir==OP_BUY?1:-1)*20*pt);
      ObserverAddScenario(sid,22,dir,entry,arrow,tp2,tp2,entry-(dir==OP_BUY?1:-1)*30*pt);
      double atr=iATR(symbol,Period(),14,1);
      if(atr>0)
      {
         ObserverAddScenario(sid,23,dir,entry,arrow,tp2,tp2,entry-(dir==OP_BUY?1:-1)*atr);
         ObserverAddScenario(sid,24,dir,entry,arrow,tp2,tp2,entry-(dir==OP_BUY?1:-1)*atr*1.5);
      }
      int swing=(dir==OP_BUY?
         iLowest(symbol,Period(),MODE_LOW,10,1):
         iHighest(symbol,Period(),MODE_HIGH,10,1));
      if(swing>=0)
      {
         double swingSL=(dir==OP_BUY?iLow(symbol,Period(),swing):iHigh(symbol,Period(),swing));
         if((dir==OP_BUY&&swingSL<entry)||(dir==OP_SELL&&swingSL>entry))
            ObserverAddScenario(sid,25,dir,entry,arrow,tp2,tp2,swingSL);
      }
   }
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
      ", exit="+DoubleToString(price,Digits)+", entry_time="+TimeToString(virtualPositions[i].openedAt,TIME_DATE|TIME_SECONDS)+
      ", entry_hour_server="+IntegerToString(TimeHour(virtualPositions[i].openedAt))+
      ", entry_weekday_server="+IntegerToString(TimeDayOfWeek(virtualPositions[i].openedAt))+
      ", exit_time="+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+
      ", duration_seconds="+IntegerToString((int)(TimeCurrent()-virtualPositions[i].openedAt))+
      ", exit_reason="+reason+", result="+result+", average_points="+DoubleToString(avg,1)+
      ", estimated_gross_money="+DoubleToString(money,2)+", currency="+AccountCurrency()+
      ", mfe_points="+DoubleToString(virtualPositions[i].mfe,1)+
      ", mfe_time="+TimeToString(virtualPositions[i].mfeAt,TIME_DATE|TIME_SECONDS)+
      ", mae_points="+DoubleToString(virtualPositions[i].mae,1)+
      ", mae_time="+TimeToString(virtualPositions[i].maeAt,TIME_DATE|TIME_SECONDS)+
      ", fibo_bucket_range="+virtualPositions[i].fiboBucketRange+
      ", nearest_fibo_bucket="+virtualPositions[i].nearestFiboBucket+
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
   string statDay=TimeToString(virtualPositions[i].openedAt,TIME_DATE);StringReplace(statDay,".","-");
   ObserverPersistStats(dir==OP_BUY?"BUY":"SELL",virtualPositions[i].fiboBucketRange,
      virtualPositions[i].scenario,statDay,money);
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
      if(pts>virtualPositions[i].mfe){virtualPositions[i].mfe=pts;virtualPositions[i].mfeAt=TimeCurrent();extreme=true;}
      if(pts<virtualPositions[i].mae){virtualPositions[i].mae=pts;virtualPositions[i].maeAt=TimeCurrent();extreme=true;}
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
      if((sc==4||sc==7||sc==8||sc==9||sc==10)&&hit1&&!virtualPositions[i].be)
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
      if((sc==11||sc==12)&&virtualPositions[i].partialStage<(sc==11?2:3))
      {
         int stage=virtualPositions[i].partialStage;
         double trigger=(stage==0?virtualPositions[i].tp1:
                         (stage==1?virtualPositions[i].tp2:virtualPositions[i].tp3));
         bool stageHit=(trigger>0&&(dir==OP_BUY?mark>=trigger:mark<=trigger));
         if(stageHit)
         {
            double pct=(sc==11?30.0:25.0);
            double lots=MathMin(virtualPositions[i].lots*pct/100.0,virtualPositions[i].remainingLots);
            double partPts=(dir==OP_BUY?trigger-virtualPositions[i].entry:
                                         virtualPositions[i].entry-trigger)/pt;
            virtualPositions[i].realizedPointsLots+=partPts*lots;
            virtualPositions[i].remainingLots-=lots;
            virtualPositions[i].partial=true;
            virtualPositions[i].partialStage++;
            virtualPositions[i].be=true;
            virtualPositions[i].stop=virtualPositions[i].entry;
            ObserverWrite(ObserverVirtualTradesFile,"staged_partial_close",
               "signal_id=SIG-"+IntegerToString(virtualPositions[i].signalId)+
               ", scenario_id="+IntegerToString(sc)+
               ", stage="+IntegerToString(stage+1)+
               ", timeframe="+observerChartTF+
               ", percent="+DoubleToString(pct,1)+
               ", partial_level="+ObserverLevelName(trigger)+
               ", closed_lots="+DoubleToString(lots,2)+
               ", remaining_lots="+DoubleToString(virtualPositions[i].remainingLots,2),
               virtualPositions[i].signalId*10+sc,TimeCurrent(),trigger,0);
         }
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
   if(observerSignalId>=4999)
   {
      ObserverWriteError("signal array capacity reached: 4999");
      return;
   }
   observerSignalId++;int id=observerSignalId;
   GlobalVariableSet("DERIK12_SIGNAL_"+symbol+"_"+observerChartTF,observerSignalId);
   datetime now=TimeCurrent();
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
      if(crossed)
      {
         ObserverWrite(ObserverLevelReachedFile,"level_reached",
            "timeframe="+observerChartTF+", fibo_id="+observerFiboId+
            ", level_percent="+DoubleToString(observerRatios[i]*100.0,1)+
            ", level_price="+DoubleToString(level,Digits)+
            ", previous_bid="+DoubleToString(observerPreviousBid,Digits)+
            ", reached_bid="+DoubleToString(bid,Digits)+
            ", crossing_direction="+(bid>observerPreviousBid?"UP":"DOWN")+
            ", spread_points="+DoubleToString((Ask-Bid)/point,1),
            i,TimeCurrent(),bid,0);
      }
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
   string counterKey="DERIK12_SIGNAL_"+symbol+"_"+observerChartTF;
   if(GlobalVariableCheck(counterKey))observerSignalId=(int)GlobalVariableGet(counterKey);
   // Keep M1 and M5 data in physically separate folders.
   ObserverFolder="Derik1.2\\"+observerChartTF;
   ObserverEventsFile=ObserverFolder+"\\Observer_Events.csv";
   ObserverSummaryFile=ObserverFolder+"\\Observer_Summary.csv";
   ObserverLevelsFile=ObserverFolder+"\\Observer_Levels.csv";
   ObserverScenariosFile=ObserverFolder+"\\Observer_Scenarios.csv";
   ObserverTicksFile=ObserverFolder+"\\Observer_Ticks.csv";
   ObserverErrorsFile=ObserverFolder+"\\Observer_Errors.csv";
   ObserverSignalsFile=ObserverFolder+"\\Observer_Signals.csv";
   ObserverVirtualTradesFile=ObserverFolder+"\\Observer_VirtualTrades.csv";
   ObserverExcursionsFile=ObserverFolder+"\\Observer_Excursions.csv";
   ObserverFiboStatsFile=ObserverFolder+"\\Observer_FiboStats.csv";
   ObserverDailySummaryFile=ObserverFolder+"\\Observer_DailySummary.csv";
   ObserverLevelReachedFile=ObserverFolder+"\\Observer_LevelReached.csv";
   FolderCreate("Derik1.2");
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
   ObserverWrite(ObserverFiboStatsFile,"file_initialized","timeframe="+observerChartTF",-1,TimeCurrent(),Bid,0);
   ObserverWrite(ObserverDailySummaryFile,"file_initialized","timeframe="+observerChartTF",-1,TimeCurrent(),Bid,0);
   ObserverWrite(ObserverLevelReachedFile,"file_initialized","timeframe="+observerChartTF",-1,TimeCurrent(),Bid,0);
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
