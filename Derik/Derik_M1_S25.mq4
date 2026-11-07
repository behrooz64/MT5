// Independent Derik scenario EA derived from Derik1.3.mq4 blob 2702cbd745959d306c07a34dd85712830768b3da
//+------------------------------------------------------------------+
//| Expert: Derik1.3 - M1 Scenario 25 / M5 Scenario 22                |
//+------------------------------------------------------------------+
#property strict

// Independent M1 S25 scenario EA
input string TradeSymbol="XAUUSDb";
input ENUM_TIMEFRAMES TF=PERIOD_M1;
input double RiskPercentPerTrade=1.0;
input int Slippage=3;
input int MagicNumber=251301;
input bool UseFiboSignalFilter=true;
input bool ShowFiboOnChart=false;
input bool AllowNewTradeWhilePositionOpen=true;
input int MaxOpenTrades=2;
input int ArrowQueueExpiryBars=2;
input int ArrowRetrySeconds=2;
input int MaxOrderSendRetries=3;
input bool PreventDuplicateArrowTrade=true;
input bool CloseOtherTradesOnSignal=false; // Retained for preset compatibility; new signals never close existing trades.
input bool EnableMaxRiskProtection=true;
input double MaxAggregateRiskPercent=2.0;
input bool EnableMaxDailyLoss=false;
input double MaxDailyLoss=50.0;
input bool ObserverEnabled=true;
input bool LogRejectedSignals=true;
input bool LogOrderErrors=true;
input bool LogFloatingExtremes=true;
input bool NotifyTradeOpened=true;
input bool NotifyTP2=true;
input bool NotifyStopLoss=true;
input bool NotifyOrderErrors=true;
input bool NotifyRejectedSignals=false;
input bool NotifyFiboLevelTouches=false;

// 🔹 Global
string symbol;
datetime lastBar = 0;
string lastStatus = "";
int lastOpenedTicket=-1;
datetime obs2StartedAt=0,obs2LastBar=0;
string obs2Folder="",obs2TradeFile="",obs2PathFile="",obs2ErrorFile="";
double obs2Ratios[10]={0.0,0.236,0.333,0.382,0.5,0.618,0.667,0.785,0.886,1.0};

double observerRatios[10]={0.0,0.236,0.333,0.382,0.5,0.618,0.667,0.785,0.886,1.0};
string ObserverSafe(string value)
{
   StringReplace(value, ";", ",");
   StringReplace(value, "\r", " ");
   StringReplace(value, "\n", " ");
   return value;
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

void ObserverError13(string detail){ Obs2Error(detail); }
double ObserverTP2_13(int dir,double entry)
{
   double best1=0,best2=0,d1=1.0e100,d2=1.0e100,tol=MarketInfo(symbol,MODE_POINT)*2.0;
   for(int i=0;i<10;i++){double p=ObserverFiboPrice(observerRatios[i]);if(p<=0||MathAbs(p-entry)<=tol)continue;
      if((dir==OP_BUY&&p<=entry)||(dir==OP_SELL&&p>=entry))continue;double d=MathAbs(p-entry);
      if(d<d1){best2=best1;d2=d1;best1=p;d1=d;}else if(d<d2){best2=p;d2=d;}}
   return best2;
}
bool ObserverLevels13(int dir,double entry,double &sl,double &tp)
{
   double pt=MarketInfo(symbol,MODE_POINT);if(pt<=0)return false;
   tp=ObserverTP2_13(dir,entry);
   if(tp<=0){ObserverError13("scenario_rejected: TP2 unavailable");return false;}
   if(Period()==PERIOD_M1){
      if(iBars(symbol,PERIOD_M1)<11){ObserverError13("scenario_rejected: fewer than 11 M1 bars");return false;}
      int ix=(dir==OP_BUY?iLowest(symbol,PERIOD_M1,MODE_LOW,10,1):iHighest(symbol,PERIOD_M1,MODE_HIGH,10,1));
      if(ix<0){ObserverError13("scenario_rejected: swing lookup failed");return false;}
      sl=(dir==OP_BUY?iLow(symbol,PERIOD_M1,ix):iHigh(symbol,PERIOD_M1,ix));
   }else if(Period()==PERIOD_M5)sl=entry-(dir==OP_BUY?1.0:-1.0)*30.0*pt;
   else{ObserverError13("scenario_rejected: only M1/M5 supported");return false;}
   sl=NormalizeDouble(sl,Digits);tp=NormalizeDouble(tp,Digits);
   if((dir==OP_BUY&&!(sl<entry&&tp>entry))||(dir==OP_SELL&&!(sl>entry&&tp<entry))){
      ObserverError13("scenario_rejected: invalid SL/TP geometry");return false;}
   return true;
}
bool ExecuteScenarioBuy13(double sl,double tp,double lots){return ExecuteBuy(sl,tp,lots);}
bool ExecuteScenarioSell13(double sl,double tp,double lots){return ExecuteSell(sl,tp,lots);}
string ObserverGV13(string k,int t){return "D13_"+k+"_"+IntegerToString(t);}
void ObserverTradeRow13(string ev,int ticket,int dir,datetime ot,double op,double sl,double tp,double px,string why,
                        double gross,double floating,double maxp,double minp,double mfe,double mae,int seconds)
{
   string row=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+";"+ev+";"+IntegerToString(ticket)+";"+symbol+";"+observerChartTF+";"+
      (Period()==PERIOD_M1?"25":"22")+";"+(dir==OP_BUY?"BUY":"SELL")+";"+TimeToString(ot,TIME_DATE|TIME_SECONDS)+";"+
      DoubleToString(op,Digits)+";"+DoubleToString(sl,Digits)+";"+DoubleToString(tp,Digits)+";"+DoubleToString(px,Digits)+";"+
      why+";"+DoubleToString(gross,2)+";"+DoubleToString(floating,2)+";"+DoubleToString(maxp,2)+";"+DoubleToString(minp,2)+";"+
      DoubleToString(mfe,1)+";"+DoubleToString(mae,1)+";"+IntegerToString(seconds);
   ObserverWriteCompact(ObserverTradeLogFile,
      "server_time;event;ticket;symbol;timeframe;scenario;direction;open_time;open_price;initial_sl;tp2;price;exit_reason;gross_profit;floating_profit_gross;max_floating_profit;max_floating_loss;mfe_points;mae_points;duration_seconds",row);
}
void ObserverTrackLive13()
{
   double pt=MarketInfo(symbol,MODE_POINT);if(pt<=0)return;
   for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(OrderSymbol()!=symbol||OrderType()>OP_SELL)continue;
      int t=OrderTicket(),dir=OrderType();string seen=ObserverGV13("seen",t),kp=ObserverGV13("maxp",t),kl=ObserverGV13("maxl",t);
      string kmf=ObserverGV13("mfe",t),kma=ObserverGV13("mae",t),ks=ObserverGV13("sl",t),kt=ObserverGV13("tp",t);
      bool first=!GlobalVariableCheck(seen);double mark=(dir==OP_BUY?Bid:Ask);
      double pts=(dir==OP_BUY?mark-OrderOpenPrice():OrderOpenPrice()-mark)/pt;
      double fl=OrderProfit(); // gross floating P/L, excluding swap and commission
      double maxp=first?fl:GlobalVariableGet(kp),minp=first?fl:GlobalVariableGet(kl);
      double mfe=first?MathMax(0,pts):GlobalVariableGet(kmf),mae=first?MathMin(0,pts):GlobalVariableGet(kma);
      bool changed=first;if(fl>maxp){maxp=fl;changed=true;}if(fl<minp){minp=fl;changed=true;}
      if(pts>mfe){mfe=pts;changed=true;}if(pts<mae){mae=pts;changed=true;}
      GlobalVariableSet(seen,1);GlobalVariableSet(kp,maxp);GlobalVariableSet(kl,minp);GlobalVariableSet(kmf,mfe);GlobalVariableSet(kma,mae);
      if(first){GlobalVariableSet(ks,OrderStopLoss());GlobalVariableSet(kt,OrderTakeProfit());}
      if(changed)ObserverTradeRow13(first?"TRADE_FIRST_SEEN":"FLOATING_EXTREME",t,dir,OrderOpenTime(),OrderOpenPrice(),
         GlobalVariableGet(ks),GlobalVariableGet(kt),mark,"OPEN",0,fl,maxp,minp,mfe,mae,(int)(TimeCurrent()-OrderOpenTime()));
   }
}
void ObserverDaily13(datetime ct,double gross)
{
   string day=TimeToString(ct,TIME_DATE);StringReplace(day,".","_");StringReplace(day,"-","_");
   string pre="D13DAY_"+symbol+"_"+observerChartTF+"_"+day;StringReplace(pre,".","_");
   string kn=pre+"_N",kw=pre+"_W",kl=pre+"_L",ks=pre+"_SUM",kgw=pre+"_GW",kgl=pre+"_GL";
   double n=GlobalVariableCheck(kn)?GlobalVariableGet(kn):0,w=GlobalVariableCheck(kw)?GlobalVariableGet(kw):0;
   double l=GlobalVariableCheck(kl)?GlobalVariableGet(kl):0,s=GlobalVariableCheck(ks)?GlobalVariableGet(ks):0;
   double gw=GlobalVariableCheck(kgw)?GlobalVariableGet(kgw):0,gl=GlobalVariableCheck(kgl)?GlobalVariableGet(kgl):0;
   n++;s+=gross;if(gross>0){w++;gw+=gross;}else if(gross<0){l++;gl+=gross;}
   GlobalVariableSet(kn,n);GlobalVariableSet(kw,w);GlobalVariableSet(kl,l);GlobalVariableSet(ks,s);GlobalVariableSet(kgw,gw);GlobalVariableSet(kgl,gl);
   ObserverWriteCompact(ObserverDailyFile,"server_date;symbol;timeframe;trades;wins;losses;gross_wins;gross_losses;net_gross",
      day+";"+symbol+";"+observerChartTF+";"+DoubleToString(n,0)+";"+DoubleToString(w,0)+";"+DoubleToString(l,0)+";"+
      DoubleToString(gw,2)+";"+DoubleToString(gl,2)+";"+DoubleToString(s,2));
}
void ObserverClosed13()
{
   for(int i=0;i<OrdersHistoryTotal();i++){if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))continue;
      if(OrderSymbol()!=symbol||OrderType()>OP_SELL||OrderCloseTime()<=0)continue;
      if(observerStartedAt>0&&OrderCloseTime()<observerStartedAt)continue;
      int t=OrderTicket();string done=ObserverGV13("closed",t);if(GlobalVariableCheck(done))continue;
      int dir=OrderType();datetime ot=OrderOpenTime(),ct=OrderCloseTime();
      double maxp=GlobalVariableCheck(ObserverGV13("maxp",t))?GlobalVariableGet(ObserverGV13("maxp",t)):0;
      double minp=GlobalVariableCheck(ObserverGV13("maxl",t))?GlobalVariableGet(ObserverGV13("maxl",t)):0;
      double mfe=GlobalVariableCheck(ObserverGV13("mfe",t))?GlobalVariableGet(ObserverGV13("mfe",t)):0;
      double mae=GlobalVariableCheck(ObserverGV13("mae",t))?GlobalVariableGet(ObserverGV13("mae",t)):0;
      double sl=GlobalVariableCheck(ObserverGV13("sl",t))?GlobalVariableGet(ObserverGV13("sl",t)):OrderStopLoss();
      double tp=GlobalVariableCheck(ObserverGV13("tp",t))?GlobalVariableGet(ObserverGV13("tp",t)):OrderTakeProfit();
      double gross=OrderProfit(),tol=MarketInfo(symbol,MODE_POINT)*3;string why="OTHER_OR_MANUAL";
      if(tp>0&&MathAbs(OrderClosePrice()-tp)<=tol)why="TP2";else if(sl>0&&MathAbs(OrderClosePrice()-sl)<=tol)why="STOP_LOSS";
      ObserverTradeRow13("TRADE_CLOSED",t,dir,ot,OrderOpenPrice(),sl,tp,OrderClosePrice(),why,gross,0,maxp,minp,mfe,mae,(int)(ct-ot));
      ObserverDaily13(ct,gross);GlobalVariableSet(done,1);
   }
}
void ObserverTick()
{
   if(observerStartedAt==0)observerStartedAt=TimeCurrent();
   ObserverCheckArrows();ObserverTrackLive13();ObserverClosed13();
}



// Compact observer: three CSV files only; OHLC path sampling, never tick-by-tick.
string Obs2GV(string kind,int ticket,int index){return "D2_"+IntegerToString(MagicNumber)+"_"+kind+"_"+IntegerToString(ticket)+"_"+IntegerToString(index);}
void Obs2Write(string fileName,string header,string row)
{
   if(!ObserverEnabled)return;FolderCreate(obs2Folder);
   int h=FileOpen(fileName,FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(h==INVALID_HANDLE)return;if(FileSize(h)==0)FileWriteString(h,header+"\r\n");
   FileSeek(h,0,SEEK_END);if(row!="")FileWriteString(h,row+"\r\n");FileFlush(h);FileClose(h);
}
void Obs2Error(string detail)
{
   if(!ObserverEnabled||!LogOrderErrors)return;
   Obs2Write(obs2ErrorFile,"server_time;symbol;timeframe;scenario;event;detail",
      TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+";"+symbol+";M1;25;ERROR;"+ObserverSafe(detail));
}
void Obs2Reject(string detail)
{
   if(ObserverEnabled&&LogRejectedSignals)
      Obs2Write(obs2ErrorFile,"server_time;symbol;timeframe;scenario;event;detail",
         TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+";"+symbol+";M1;25;REJECTED;"+ObserverSafe(detail));
   if(NotifyRejectedSignals)SendNotification("Derik_M1_S25 rejected: "+detail);
}
string Obs2NearestFrozenText(int ticket,double price)
{
   double best=1.0e100,lp=0;int ix=-1;
   for(int i=0;i<10;i++){string k=Obs2GV("fib",ticket,i);if(!GlobalVariableCheck(k))continue;
      double p=GlobalVariableGet(k);if(p<=0)continue;double d=MathAbs(price-p);if(d<best){best=d;lp=p;ix=i;}}
   return ix<0?"unavailable":DoubleToString(obs2Ratios[ix]*100.0,1)+"% @ "+DoubleToString(lp,Digits);
}
void Obs2RegisterTrade(int ticket,int direction,double entry,double sl,double tp)
{
   if(!ObserverEnabled||!OrderSelect(ticket,SELECT_BY_TICKET))return;
   for(int i=0;i<10;i++){GlobalVariableSet(Obs2GV("fib",ticket,i),ObserverFiboPrice(obs2Ratios[i]));GlobalVariableSet(Obs2GV("hit",ticket,i),0);}
   GlobalVariableSet(Obs2GV("maxp",ticket,0),OrderProfit());GlobalVariableSet(Obs2GV("minp",ticket,0),OrderProfit());
   GlobalVariableSet(Obs2GV("mfe",ticket,0),0);GlobalVariableSet(Obs2GV("mae",ticket,0),0);GlobalVariableSet(Obs2GV("seen",ticket,0),1);
   string row=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+";ENTRY;"+IntegerToString(ticket)+";"+symbol+";M1;25;"+
      (direction==OP_BUY?"BUY":"SELL")+";"+TimeToString(OrderOpenTime(),TIME_DATE|TIME_SECONDS)+";"+
      DoubleToString(entry,Digits)+";"+DoubleToString(sl,Digits)+";"+DoubleToString(tp,Digits)+";"+
      ObserverSafe(Obs2NearestFrozenText(ticket,entry))+";;;;;0;0;0;0;0";
   Obs2Write(obs2TradeFile,"server_time;event;ticket;symbol;timeframe;scenario;direction;open_time;open_price;initial_sl;tp2;entry_fibo_level;exit_price;exit_fibo_level;exit_reason;gross_profit;floating_profit;max_floating_profit;max_floating_loss;mfe_points;mae_points;duration_seconds",row);
}
void Obs2TrackClosedBar()
{
   datetime barTime=iTime(symbol,TF,1);if(barTime<=0||barTime==obs2LastBar)return;obs2LastBar=barTime;
   double hi=iHigh(symbol,TF,1),lo=iLow(symbol,TF,1),point=MarketInfo(symbol,MODE_POINT);if(point<=0)return;
   for(int pos=OrdersTotal()-1;pos>=0;pos--)
   {
      if(!OrderSelect(pos,SELECT_BY_POS,MODE_TRADES))continue;
      if(OrderSymbol()!=symbol||OrderMagicNumber()!=MagicNumber||OrderType()>OP_SELL)continue;
      int ticket=OrderTicket(),direction=OrderType();
      if(!GlobalVariableCheck(Obs2GV("seen",ticket,0)))Obs2RegisterTrade(ticket,direction,OrderOpenPrice(),OrderStopLoss(),OrderTakeProfit());
      if(barTime<=OrderOpenTime())continue;
      double favorable=(direction==OP_BUY?hi-OrderOpenPrice():OrderOpenPrice()-lo)/point;
      double adverse=(direction==OP_BUY?lo-OrderOpenPrice():OrderOpenPrice()-hi)/point;
      string kf=Obs2GV("mfe",ticket,0),ka=Obs2GV("mae",ticket,0);double oldF=GlobalVariableGet(kf),oldA=GlobalVariableGet(ka);
      if(favorable>oldF)GlobalVariableSet(kf,favorable);if(adverse<oldA)GlobalVariableSet(ka,adverse);
      int touchedCount=0;
      for(int j=0;j<10;j++){double p=GlobalVariableGet(Obs2GV("fib",ticket,j));if(p>0&&GlobalVariableGet(Obs2GV("hit",ticket,j))<0.5&&lo<=p&&hi>=p)touchedCount++;}
      for(int j=0;j<10;j++)
      {
         string hk=Obs2GV("hit",ticket,j);double p=GlobalVariableGet(Obs2GV("fib",ticket,j));
         if(p<=0||GlobalVariableGet(hk)>0.5||lo>p||hi<p)continue;GlobalVariableSet(hk,1);
         string status=(touchedCount>1?"same_bar_ambiguous":"single_level_touch");
         string row=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+";"+IntegerToString(ticket)+";"+symbol+";M1;25;"+
            TimeToString(barTime,TIME_DATE|TIME_SECONDS)+";"+DoubleToString(obs2Ratios[j]*100.0,1)+";"+
            DoubleToString(p,Digits)+";"+DoubleToString(hi,Digits)+";"+DoubleToString(lo,Digits)+";"+status+";"+
            (direction==OP_BUY?"BUY":"SELL");
         Obs2Write(obs2PathFile,"server_time;ticket;symbol;timeframe;scenario;bar_time;level_percent;level_price;bar_high;bar_low;touch_status;direction",row);
         if(NotifyFiboLevelTouches)SendNotification("Derik_M1_S25 ticket "+IntegerToString(ticket)+" touched Fibo "+DoubleToString(obs2Ratios[j]*100.0,1)+"%");
      }
      double floating=OrderProfit(),maxp=GlobalVariableGet(Obs2GV("maxp",ticket,0)),minp=GlobalVariableGet(Obs2GV("minp",ticket,0));
      if(floating>maxp)GlobalVariableSet(Obs2GV("maxp",ticket,0),floating);if(floating<minp)GlobalVariableSet(Obs2GV("minp",ticket,0),floating);
      if(LogFloatingExtremes&&(favorable>oldF||adverse<oldA))
      {
         string row=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+";BAR_EXTREME;"+IntegerToString(ticket)+";"+symbol+";M1;25;"+
            (direction==OP_BUY?"BUY":"SELL")+";"+TimeToString(OrderOpenTime(),TIME_DATE|TIME_SECONDS)+";"+
            DoubleToString(OrderOpenPrice(),Digits)+";"+DoubleToString(OrderStopLoss(),Digits)+";"+
            DoubleToString(OrderTakeProfit(),Digits)+";;;OPEN;0;"+DoubleToString(floating,2)+";"+
            DoubleToString(MathMax(maxp,floating),2)+";"+DoubleToString(MathMin(minp,floating),2)+";"+
            DoubleToString(MathMax(oldF,favorable),1)+";"+DoubleToString(MathMin(oldA,adverse),1)+";"+
            IntegerToString((int)(TimeCurrent()-OrderOpenTime()));
         Obs2Write(obs2TradeFile,"server_time;event;ticket;symbol;timeframe;scenario;direction;open_time;open_price;initial_sl;tp2;entry_fibo_level;exit_price;exit_fibo_level;exit_reason;gross_profit;floating_profit;max_floating_profit;max_floating_loss;mfe_points;mae_points;duration_seconds",row);
      }
   }
}
void Obs2CheckClosed()
{
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))continue;
      if(OrderSymbol()!=symbol||OrderMagicNumber()!=MagicNumber||OrderType()>OP_SELL||OrderCloseTime()<obs2StartedAt)continue;
      int ticket=OrderTicket();string done=Obs2GV("closed",ticket,0);if(GlobalVariableCheck(done))continue;
      double sl=OrderStopLoss(),tp=OrderTakeProfit(),tol=MarketInfo(symbol,MODE_POINT)*3;string reason="OTHER_OR_MANUAL";
      if(tp>0&&MathAbs(OrderClosePrice()-tp)<=tol)reason="TP2";else if(sl>0&&MathAbs(OrderClosePrice()-sl)<=tol)reason="STOP_LOSS";
      double maxp=GlobalVariableCheck(Obs2GV("maxp",ticket,0))?GlobalVariableGet(Obs2GV("maxp",ticket,0)):0;
      double minp=GlobalVariableCheck(Obs2GV("minp",ticket,0))?GlobalVariableGet(Obs2GV("minp",ticket,0)):0;
      double mfe=GlobalVariableCheck(Obs2GV("mfe",ticket,0))?GlobalVariableGet(Obs2GV("mfe",ticket,0)):0;
      double mae=GlobalVariableCheck(Obs2GV("mae",ticket,0))?GlobalVariableGet(Obs2GV("mae",ticket,0)):0;
      string exitLevel=Obs2NearestFrozenText(ticket,OrderClosePrice());double gross=OrderProfit();
      string row=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+";EXIT;"+IntegerToString(ticket)+";"+symbol+";M1;25;"+
         (OrderType()==OP_BUY?"BUY":"SELL")+";"+TimeToString(OrderOpenTime(),TIME_DATE|TIME_SECONDS)+";"+
         DoubleToString(OrderOpenPrice(),Digits)+";"+DoubleToString(sl,Digits)+";"+DoubleToString(tp,Digits)+";"+
         ObserverSafe(Obs2NearestFrozenText(ticket,OrderOpenPrice()))+";"+DoubleToString(OrderClosePrice(),Digits)+";"+
         ObserverSafe(exitLevel)+";"+reason+";"+DoubleToString(gross,2)+";0;"+DoubleToString(maxp,2)+";"+
         DoubleToString(minp,2)+";"+DoubleToString(mfe,1)+";"+DoubleToString(mae,1)+";"+
         IntegerToString((int)(OrderCloseTime()-OrderOpenTime()));
      Obs2Write(obs2TradeFile,"server_time;event;ticket;symbol;timeframe;scenario;direction;open_time;open_price;initial_sl;tp2;entry_fibo_level;exit_price;exit_fibo_level;exit_reason;gross_profit;floating_profit;max_floating_profit;max_floating_loss;mfe_points;mae_points;duration_seconds",row);
      if(reason=="TP2"&&NotifyTP2)SendNotification("Derik_M1_S25 TP2 ticket="+IntegerToString(ticket)+" gross="+DoubleToString(gross,2)+" fibo="+exitLevel);
      if(reason=="STOP_LOSS"&&NotifyStopLoss)SendNotification("Derik_M1_S25 SL ticket="+IntegerToString(ticket)+" gross="+DoubleToString(gross,2)+" fibo="+exitLevel);
      GlobalVariableSet(done,1);
   }
}
void Obs2Tick(){Obs2TrackClosedBar();Obs2CheckClosed();}

int OnInit()
{
   if(Symbol()!=TradeSymbol || Period()!=TF || TF!=PERIOD_M1)
   {
      Print("Derik_M1_S25 requires "+TradeSymbol+" on M1.");
      return(INIT_FAILED);
   }
   symbol=TradeSymbol;
   obs2StartedAt=TimeCurrent();
   obs2Folder="Derik_M1_S25";
   obs2TradeFile=obs2Folder+"\\TradeLog.csv";
   obs2PathFile=obs2Folder+"\\FiboPath.csv";
   obs2ErrorFile=obs2Folder+"\\Errors.csv";
   FolderCreate(obs2Folder);
   if(ObserverEnabled)
   {
      Obs2Write(obs2TradeFile,"server_time;event;ticket;symbol;timeframe;scenario;direction;open_time;open_price;initial_sl;tp2;entry_fibo_level;exit_price;exit_fibo_level;exit_reason;gross_profit;floating_profit;max_floating_profit;max_floating_loss;mfe_points;mae_points;duration_seconds","");
      Obs2Write(obs2PathFile,"server_time;ticket;symbol;timeframe;scenario;bar_time;level_percent;level_price;bar_high;bar_low;touch_status;direction","");
      Obs2Write(obs2ErrorFile,"server_time;symbol;timeframe;scenario;event;detail","");
   }
   lastBar=iTime(symbol,TF,0);
   ChartSetInteger(0,CHART_EVENT_OBJECT_CREATE,true);
   EventSetMillisecondTimer(200);
   Print("Derik_M1_S25 initialized. Magic="+IntegerToString(MagicNumber));
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("Derik_M1_S25 stopped. reason="+IntegerToString(reason));
}
void OnTick()
{
   if(Symbol()!=TradeSymbol || Period()!=TF) return;
   if(ObserverEnabled) Obs2TrackClosedBar();
   Obs2CheckClosed();
   CaptureVisibleArrows();
   ProcessArrowQueue();
   datetime currentBar=iTime(symbol,TF,0);
   if(currentBar==lastBar) return;
   lastBar=currentBar;
   if(ShowFiboOnChart) ShowFiboLevelsOnChart();
}

void OnTimer()
{
   if(Symbol()!=TradeSymbol || Period()!=TF) return;
   CaptureVisibleArrows();
   ProcessArrowQueue();
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_CREATE && (sparam=="UpArrow" || sparam=="DownArrow"))
      QueueArrowFromObject(sparam);
}

string ArrowTradeKey(string direction,datetime arrowTime,double arrowPrice)
{
   double pt=MarketInfo(symbol,MODE_POINT);if(pt<=0)pt=Point;
   return "D13A_"+IntegerToString(MagicNumber)+"_"+IntegerToString((int)arrowTime)+"_"+
          IntegerToString((int)MathRound(arrowPrice/pt))+"_"+direction;
}
int CountOwnOpenTrades()
{
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)&&OrderSymbol()==symbol&&
         OrderMagicNumber()==MagicNumber&&OrderType()<=OP_SELL)count++;
   return count;
}
double OrderRiskMoney(int type,double entry,double sl,double lots)
{
   double point=MarketInfo(symbol,MODE_POINT);
   double tickSizePrice=MarketInfo(symbol,MODE_TICKSIZE)*point;
   double tickValue=MarketInfo(symbol,MODE_TICKVALUE);
   if(point<=0||tickSizePrice<=0||tickValue<=0||sl<=0||lots<=0)return 1.0e100;
   return MathAbs(entry-sl)/tickSizePrice*tickValue*lots;
}
double CurrentOpenRiskMoney()
{
   double total=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)&&OrderSymbol()==symbol&&
         OrderMagicNumber()==MagicNumber&&OrderType()<=OP_SELL)
         total+=OrderRiskMoney(OrderType(),OrderOpenPrice(),OrderStopLoss(),OrderLots());
   return total;
}
bool CalculateRiskLot(double entry,double sl,double &lots)
{
   lots=0;
   double equity=AccountEquity(),point=MarketInfo(symbol,MODE_POINT);
   double tickSizePrice=MarketInfo(symbol,MODE_TICKSIZE)*point;
   double tickValue=MarketInfo(symbol,MODE_TICKVALUE);
   double minLot=MarketInfo(symbol,MODE_MINLOT),maxLot=MarketInfo(symbol,MODE_MAXLOT);
   double lotStep=MarketInfo(symbol,MODE_LOTSTEP);
   if(equity<=0||point<=0||tickSizePrice<=0||tickValue<=0||lotStep<=0||
      minLot<=0||maxLot<minLot||sl<=0||MathAbs(entry-sl)<point*0.5||RiskPercentPerTrade<=0)
   {Obs2Reject("risk_lot_calculation_invalid_market_or_inputs");return false;}
   double riskBudget=equity*RiskPercentPerTrade/100.0;
   double riskPerLot=MathAbs(entry-sl)/tickSizePrice*tickValue;
   if(riskBudget<=0||riskPerLot<=0)
   {Obs2Reject("risk_lot_calculation_invalid_risk_value");return false;}
   double rawLots=riskBudget/riskPerLot;
   if(rawLots<minLot)
   {
      Obs2Reject("minimum_lot_exceeds_risk_budget;equity="+DoubleToString(equity,2)+
                 ";risk_budget="+DoubleToString(riskBudget,2)+
                 ";minimum_lot="+DoubleToString(minLot,3)+
                 ";minimum_lot_risk="+DoubleToString(riskPerLot*minLot,2));
      return false;
   }
   double steppedLots=MathFloor(MathMin(rawLots,maxLot)/lotStep+1.0e-8)*lotStep;
   int lotDigits=0;
   while(lotDigits<8&&MathAbs(lotStep-NormalizeDouble(lotStep,lotDigits))>1.0e-8)lotDigits++;
   lots=NormalizeDouble(steppedLots,lotDigits);
   if(lots<minLot||lots<=0){lots=0;Obs2Reject("calculated_lot_below_broker_minimum");return false;}
   double estimatedRisk=OrderRiskMoney(OP_BUY,entry,sl,lots);
   if(estimatedRisk>riskBudget+0.01)
   {lots=0;Obs2Reject("calculated_lot_exceeds_per_trade_risk;estimated="+DoubleToString(estimatedRisk,2)+
                      ";budget="+DoubleToString(riskBudget,2));return false;}
   return true;
}
double TodayClosedGross()
{
   datetime dayStart=StringToTime(TimeToString(TimeCurrent(),TIME_DATE));double total=0;
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)&&OrderSymbol()==symbol&&
         OrderMagicNumber()==MagicNumber&&OrderType()<=OP_SELL&&OrderCloseTime()>=dayStart)
         total+=OrderProfit();
   return total;
}
bool CanOpenAnotherTrade(double entry,double sl,double lots)
{
   int count=CountOwnOpenTrades();
   if(!AllowNewTradeWhilePositionOpen&&!CloseOtherTradesOnSignal&&count>0)
   {Obs2Reject("position_already_open");return false;}
   if(count>=MaxOpenTrades){Obs2Reject("max_open_trades_reached;count="+IntegerToString(count));return false;}
   if(EnableMaxDailyLoss&&TodayClosedGross()<=-MathAbs(MaxDailyLoss))
   {Obs2Reject("max_daily_loss_reached");return false;}
   if(EnableMaxRiskProtection)
   {
      double proposed=OrderRiskMoney(OP_BUY,entry,sl,lots);
      double current=CurrentOpenRiskMoney();
      double limit=AccountEquity()*MaxAggregateRiskPercent/100.0;
      if(proposed>=1.0e99||current+proposed>limit+0.01)
      {Obs2Reject("aggregate_risk_limit;current="+DoubleToString(current,2)+
                  ";proposed="+DoubleToString(proposed,2)+";limit="+DoubleToString(limit,2));return false;}
   }
   return true;
}
void CloseOwnTradesOnSignal()
{
   if(!CloseOtherTradesOnSignal)return;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(OrderSymbol()!=symbol||OrderMagicNumber()!=MagicNumber||OrderType()>OP_SELL)continue;
      RefreshRates();double px=(OrderType()==OP_BUY?Bid:Ask);
      if(!OrderClose(OrderTicket(),OrderLots(),px,Slippage,clrNONE))
         Obs2Error("close_on_signal_failed;ticket="+IntegerToString(OrderTicket())+
                   ";error="+IntegerToString(GetLastError()));
   }
}
string ArrowQueueBase(string direction,datetime arrowTime,double arrowPrice)
{
   double pt=MarketInfo(symbol,MODE_POINT);if(pt<=0)pt=Point;
   long ticks=(long)MathRound(arrowPrice/pt);
   return "D13Q_"+IntegerToString(MagicNumber)+"_"+IntegerToString((int)arrowTime)+"_"+
          IntegerToString((int)ticks)+"_"+direction;
}
void QueueArrowSnapshot(string direction,datetime arrowTime,double arrowPrice)
{
   if(arrowTime<=0||arrowPrice<=0)return;
   string base=ArrowQueueBase(direction,arrowTime,arrowPrice);
   string stateKey=base+"_S";
   if(GlobalVariableCheck(stateKey))return;
   string tradeKey=ArrowTradeKey(direction,arrowTime,arrowPrice);
   if(PreventDuplicateArrowTrade&&GlobalVariableCheck(tradeKey))
   {GlobalVariableSet(stateKey,1);return;}
   GlobalVariableSet(base+"_T",(double)arrowTime);
   GlobalVariableSet(base+"_P",arrowPrice);
   GlobalVariableSet(base+"_D",(direction=="BUY"?1:0));
   GlobalVariableSet(base+"_N",0);
   GlobalVariableSet(base+"_A",0);
   GlobalVariableSet(stateKey,0);
   if(ObserverEnabled)
      Obs2Write(obs2ErrorFile,"server_time;symbol;timeframe;scenario;event;detail",
         TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+";"+symbol+";M1;25;ARROW_DETECTED;"+
         direction+";"+TimeToString(arrowTime,TIME_DATE|TIME_SECONDS)+";"+DoubleToString(arrowPrice,Digits));
}
void QueueArrowFromObject(string objName)
{
   if(ObjectFind(0,objName)<0||ObjectType(objName)!=OBJ_ARROW)return;
   datetime arrowTime=(datetime)ObjectGet(objName,OBJPROP_TIME1);
   double arrowPrice=ObjectGet(objName,OBJPROP_PRICE1);
   QueueArrowSnapshot(objName=="UpArrow"?"BUY":"SELL",arrowTime,arrowPrice);
}
void CaptureVisibleArrows()
{
   int total=ObjectsTotal(0,0,-1);
   for(int i=total-1;i>=0;i--)
   {
      string name=ObjectName(0,i,0,-1);
      if(name!="UpArrow"&&name!="DownArrow")continue;
      if(ObjectType(name)!=OBJ_ARROW)continue;
      QueueArrowFromObject(name);
   }
}
void QueueRetry(string base)
{
   GlobalVariableSet(base+"_N",(double)(TimeLocal()+MathMax(1,ArrowRetrySeconds)));
}
void QueueReject(string base,string reason)
{
   GlobalVariableSet(base+"_S",2);
   Obs2Reject("arrow_event_rejected;"+reason);
}
bool ProcessArrowSnapshot(string base,string direction,datetime arrowTime,double arrowPrice,double level38,bool fiboOk)
{
   string stateKey=base+"_S";
   if(!GlobalVariableCheck(stateKey)||GlobalVariableGet(stateKey)!=0)return true;
   string tradeKey=ArrowTradeKey(direction,arrowTime,arrowPrice);
   if(PreventDuplicateArrowTrade&&GlobalVariableCheck(tradeKey))
   {GlobalVariableSet(stateKey,1);return true;}
   int shift=iBarShift(symbol,TF,arrowTime,false);
   if(shift<0||shift>ArrowQueueExpiryBars)
   {QueueReject(base,"arrow_expired;bar_shift="+IntegerToString(shift));return true;}
   if(!fiboOk){QueueRetry(base);return false;}
   if(UseFiboSignalFilter&&((direction=="BUY"&&!(arrowPrice<level38))||
      (direction=="SELL"&&!(arrowPrice>level38))))
   {QueueReject(base,"signal_filter_rejected;direction="+direction);return true;}
   double entry=(direction=="BUY"?Ask:Bid),sl=0,tp=0;
   int type=(direction=="BUY"?OP_BUY:OP_SELL);
   if(!ObserverLevels13(type,NormalizeDouble(entry,Digits),sl,tp))
   {QueueRetry(base);return false;}
   if((direction=="BUY"&&!(sl<entry&&tp>entry))||(direction=="SELL"&&!(sl>entry&&tp<entry)))
   {QueueReject(base,"invalid_SL_TP_geometry");return true;}
   double lots=0;
   if(!CalculateRiskLot(entry,sl,lots))
   {QueueReject(base,"risk_lot_calculation_rejected");return true;}
   if(!CanOpenAnotherTrade(entry,sl,lots))
   {QueueRetry(base);return false;}
   bool opened=(direction=="BUY"?ExecuteScenarioBuy13(sl,tp,lots):ExecuteScenarioSell13(sl,tp,lots));
   if(!opened||lastOpenedTicket<0)
   {
      int attempts=(int)GlobalVariableGet(base+"_A")+1;
      GlobalVariableSet(base+"_A",attempts);
      if(attempts>=MaxOrderSendRetries)QueueReject(base,"order_send_retries_exhausted;attempts="+IntegerToString(attempts));
      else QueueRetry(base);
      return false;
   }
   if(PreventDuplicateArrowTrade)GlobalVariableSet(tradeKey,1);
   GlobalVariableSet(stateKey,1);
   if(OrderSelect(lastOpenedTicket,SELECT_BY_TICKET))
   {
      Obs2RegisterTrade(lastOpenedTicket,type,OrderOpenPrice(),OrderStopLoss(),OrderTakeProfit());
      if(NotifyTradeOpened)SendNotification("Derik_M1_S25 "+direction+" | ticket="+IntegerToString(lastOpenedTicket)+
         " | lot="+DoubleToString(OrderLots(),2)+" | entry="+DoubleToString(OrderOpenPrice(),Digits)+
         " | SL="+DoubleToString(OrderStopLoss(),Digits)+" | TP2="+DoubleToString(OrderTakeProfit(),Digits)+
         " | entry fibo="+Obs2NearestFrozenText(lastOpenedTicket,OrderOpenPrice()));
   }
   return true;
}
void ProcessArrowQueue()
{
   double level0=0,level38=0,level61=0;
   bool fiboOk=GetFiboLevels(level0,level38,level61);
   string prefix="D13Q_"+IntegerToString(MagicNumber)+"_";
   for(int i=GlobalVariablesTotal()-1;i>=0;i--)
   {
      string stateKey=GlobalVariableName(i);
      if(StringFind(stateKey,prefix)!=0||StringLen(stateKey)<3)continue;
      if(StringSubstr(stateKey,StringLen(stateKey)-2)!="_S")continue;
      if(GlobalVariableGet(stateKey)!=0)continue;
      string base=StringSubstr(stateKey,0,StringLen(stateKey)-2);
      double nextTry=GlobalVariableCheck(base+"_N")?GlobalVariableGet(base+"_N"):0;
      if(nextTry>TimeLocal())continue;
      if(!GlobalVariableCheck(base+"_T")||!GlobalVariableCheck(base+"_P")||!GlobalVariableCheck(base+"_D"))
      {GlobalVariableSet(stateKey,2);continue;}
      datetime arrowTime=(datetime)GlobalVariableGet(base+"_T");
      double arrowPrice=GlobalVariableGet(base+"_P");
      string direction=(GlobalVariableGet(base+"_D")>0.5?"BUY":"SELL");
      ProcessArrowSnapshot(base,direction,arrowTime,arrowPrice,level38,fiboOk);
   }
}
bool GetFiboLevels(double &level0, double &level38, double &level61)
{
   string objName = "XIT_FIBO";
   if (ObjectFind(0, objName) < 0 || ObjectType(objName) != OBJ_FIBO)
   {
      ;
      return false;
   }

   double price1 = ObjectGet(objName, OBJPROP_PRICE1);
   double price2 = ObjectGet(objName, OBJPROP_PRICE2);
   if (price1 == 0 || price2 == 0)
   {
      ;
      return false;
   }

   int fiboColor = ObjectGetInteger(0, objName, OBJPROP_COLOR);
   bool reverse = (fiboColor == clrRed || fiboColor == clrBlue);


   level0  = reverse ? price2 : price1;
   level38 = reverse ? price2 + (price1 - price2) * 0.382 : price1 + (price2 - price1) * 0.382;
   level61 = reverse ? price2 + (price1 - price2) * 0.618 : price1 + (price2 - price1) * 0.618;

   ;
   return true;
}

bool ExecuteBuy(double sl,double tp,double lots)
{
   double price=NormalizeDouble(Ask,Digits);ResetLastError();lastOpenedTicket=-1;
   int ticket=OrderSend(symbol,OP_BUY,lots,price,Slippage,sl,tp,"Derik_M1_S25",MagicNumber,0,clrGreen);
   if(ticket<0){int err=GetLastError();lastOpenedTicket=-1;ObserverError13("OrderSend BUY failed;error="+IntegerToString(err));
      if(NotifyOrderErrors)SendNotification("Derik_M1_S25 BUY OrderSend error "+IntegerToString(err));return false;}
   lastOpenedTicket=ticket;return true;
}
bool ExecuteSell(double sl,double tp,double lots)
{
   double price=NormalizeDouble(Bid,Digits);ResetLastError();lastOpenedTicket=-1;
   int ticket=OrderSend(symbol,OP_SELL,lots,price,Slippage,sl,tp,"Derik_M1_S25",MagicNumber,0,clrRed);
   if(ticket<0){int err=GetLastError();lastOpenedTicket=-1;ObserverError13("OrderSend SELL failed;error="+IntegerToString(err));
      if(NotifyOrderErrors)SendNotification("Derik_M1_S25 SELL OrderSend error "+IntegerToString(err));return false;}
   lastOpenedTicket=ticket;return true;
}
void CheckClosedOrders()
{
   for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if (OrderSymbol() == symbol && OrderType() <= OP_SELL)
         {
            if (OrderCloseTime() > lastBar)
            {
               string reason = "";
               if (OrderProfit() > 0)
                  reason = "TP gerefte shod";
               else if (OrderProfit() < 0)
                  reason = "SL khorde";
               else
                  reason = "manual baste shod";

               string msg = "baste shodan: Ticket# " + IntegerToString(OrderTicket()) + " | " + reason;
               Print(msg);
               SendNotification(msg);
               Alert(msg);
            }
         }
      }
   }
}

void UpdateStatus()
{
   string currentStatus = "";

   if (OrdersTotal() > 0)
      currentStatus = "moamele baz hast - entezaar baraye TP ya SL";
   else
      currentStatus = "amade baraye signal jadid";

   if (currentStatus != lastStatus)
   {
      Print("status: " + currentStatus);
      SendNotification("status: " + currentStatus);
      lastStatus = currentStatus;
  
   }
   
   
}
void ShowFiboLevelsOnChart()
{
   string objName = "XIT_FIBO";
   if (ObjectFind(0, objName) < 0 || ObjectType(objName) != OBJ_FIBO)
      return;

   double price1 = ObjectGet(objName, OBJPROP_PRICE1);
   double price2 = ObjectGet(objName, OBJPROP_PRICE2);
   if (price1 == 0 || price2 == 0)
      return;

   int fiboColor = ObjectGetInteger(0, objName, OBJPROP_COLOR);
   bool reverseFibo = (fiboColor == clrRed || fiboColor == clrBlue);

   double fiboLevels[] = {0.0, 0.236, 0.333, 0.382, 0.5, 0.618, 0.667, 0.785, 0.886, 1.0};
   double levels[];
   ArrayResize(levels, ArraySize(fiboLevels));

   if (reverseFibo)
   {
      for (int i = 0; i < ArraySize(fiboLevels); i++)
         levels[i] = fiboLevels[ArraySize(fiboLevels) - 1 - i];
   }
   else
   {
      ArrayCopy(levels, fiboLevels);
   }

   string baseLabel = "FiboRow_";
   string colorLabel = "FiboColorLabel";
   int fontSize = 9;
   int xOffset = 10;
   int yOffsetStart = 10;
   int rowHeight = 13;
   ENUM_BASE_CORNER cornerPosition = CORNER_LEFT_LOWER;

   for (int i = 0; i < ArraySize(levels); i++)
      ObjectDelete(0, baseLabel + IntegerToString(i));
   ObjectDelete(0, colorLabel);

   string colorName = (fiboColor == clrRed) ? "Red" : (fiboColor == clrBlue) ? "Blue" : "Custom";
   ObjectCreate(0, colorLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, colorLabel, OBJPROP_CORNER, cornerPosition);
   ObjectSetInteger(0, colorLabel, OBJPROP_XDISTANCE, xOffset);
   ObjectSetInteger(0, colorLabel, OBJPROP_YDISTANCE, yOffsetStart);
   ObjectSetInteger(0, colorLabel, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, colorLabel, OBJPROP_COLOR, clrYellow);
   ObjectSetString(0, colorLabel, OBJPROP_TEXT, "Fibo Color: " + colorName);

   for (int i = 0; i < ArraySize(levels); i++)
   {
      double level = levels[i];
      double price = reverseFibo
                     ? price2 + (price1 - price2) * level
                     : price1 + (price2 - price1) * level;

      string percent = DoubleToString(level * 100.0, 1);
      string labelText = percent + "% - " + DoubleToString(price, Digits);
      string labelName = baseLabel + IntegerToString(i);

      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, cornerPosition);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, xOffset);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, yOffsetStart + (i + 1) * rowHeight);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
   }
}
