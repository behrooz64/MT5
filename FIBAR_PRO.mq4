//+------------------------------------------------------------------+
//| Expert: Derik1.3 - M1 Scenario 25 / M5 Scenario 22                |
//+------------------------------------------------------------------+
#property strict

// 🔹 Inputs
input string TradeSymbol     = "XAUUSD";       // namad
const ENUM_TIMEFRAMES TF    = PERIOD_M1;      // FIBAR PRO is fixed to M1
input double LotSize         = 0.1;            // hajm
input int Slippage           = 3;              // slippage
input bool ShowDashboard    = true;           // show FIBAR PRO dashboard
input bool UseFiboLevels     = true;           // estefade az fibo baraye TP/SL
input double CustomTP        = 100;            // TP agar fibo off
input double CustomSL        = 50;             // SL agar fibo off

// 🔹 Global
string symbol;
datetime lastBar = 0;
string lastStatus = "";

// --- Derik1.1 observer: isolated file logging; never changes trading decisions.
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
string ObserverLevelsFile = "Derik1.3\\Observer_Levels.csv";
string ObserverScenariosFile = "Derik1.3\\Observer_Scenarios.csv";
string ObserverTicksFile = "Derik1.3\\Observer_Ticks.csv";
int observerTrackedTicket = -1;
double observerMaxFloatingProfit = 0.0;
double observerMaxFloatingLoss = 0.0;
datetime observerTradeOpenTime = 0;
double observerTradeOpenPrice = 0.0;
double observerFiboAtEntry[10];
bool observerHasFiboAtEntry = false;
string ObserverFolder = "Derik1.3";
string ObserverEventsFile = "Derik1.3\\Observer_Events.csv";
string ObserverSummaryFile = "Derik1.3\\Observer_Summary.csv";
string ObserverErrorsFile = "Derik1.3\\Errors.csv";
string ObserverTradeLogFile = "Derik1.3\\TradeLog.csv";
string ObserverDailyFile = "Derik1.3\\DailySummary.csv";
string observerChartTF = "";
double observerRatios[10] = {0.0,0.236,0.333,0.382,0.5,0.618,0.667,0.785,0.886,1.0};

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
   int h = FileOpen(fileName, FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE, ';');
   if(h == INVALID_HANDLE) return;
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
      if(ObjectFind(0,n)<0 || ObjectType(n)!=OBJ_ARROW) continue;
      datetime at=(datetime)ObjectGet(n,OBJPROP_TIME1);
      double p=ObjectGet(n,OBJPROP_PRICE1);
      if(at<=0) continue;
      if(i==0 && at!=observerLastUpArrowTime)
      {
         observerLastUpArrowTime=at;
         observerLastUpArrowSeenAt=TimeCurrent();
         ObserverWrite(ObserverEventsFile,"signal_arrow","direction=BUY; object=UpArrow; object_time="+TimeToString(at,TIME_DATE|TIME_SECONDS)+"; first_observed_time="+TimeToString(observerLastUpArrowSeenAt,TIME_DATE|TIME_SECONDS)+"; "+ObserverNearestFiboText(p)+"; "+ObserverFiboSnapshot(),-1,observerLastUpArrowSeenAt,p,0);
      }
      if(i==1 && at!=observerLastDownArrowTime)
      {
         observerLastDownArrowTime=at;
         observerLastDownArrowSeenAt=TimeCurrent();
         ObserverWrite(ObserverEventsFile,"signal_arrow","direction=SELL; object=DownArrow; object_time="+TimeToString(at,TIME_DATE|TIME_SECONDS)+"; first_observed_time="+TimeToString(observerLastDownArrowSeenAt,TIME_DATE|TIME_SECONDS)+"; "+ObserverNearestFiboText(p)+"; "+ObserverFiboSnapshot(),-1,observerLastDownArrowSeenAt,p,0);
      }
   }
}

string ObserverGV(string kind,int ticket)
{
   return "Derik11_"+kind+"_"+IntegerToString(ticket);
}

void ObserverCaptureOpenTrades()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=symbol || OrderType()>OP_SELL) continue;
      int ticket=OrderTicket();
      double net=OrderProfit()+OrderSwap()+OrderCommission();
      string side=(OrderType()==OP_BUY ? "BUY" : "SELL");
      string gvMaxP=ObserverGV("maxp",ticket), gvMaxL=ObserverGV("maxl",ticket);
      bool first=(GlobalVariableCheck(gvMaxP)==false || GlobalVariableCheck(gvMaxL)==false);
      if(first)
      {
         GlobalVariableSet(gvMaxP,net);
         GlobalVariableSet(gvMaxL,net);
         ObserverWrite(ObserverEventsFile,"trade_open_observed",
            "direction="+side+"; lots="+DoubleToString(OrderLots(),2)+"; open_time="+TimeToString(OrderOpenTime(),TIME_DATE|TIME_SECONDS)+
            "; duration_seconds=0; "+ObserverNearestFiboText(OrderOpenPrice())+"; "+ObserverFiboSnapshot()+
            "; extrema_note=tracking_started_when_observer_first_saw_trade",
            ticket,OrderOpenTime(),OrderOpenPrice(),net);
      }
      double maxP=GlobalVariableGet(gvMaxP), maxL=GlobalVariableGet(gvMaxL);
      bool changed=false;
      if(net>maxP) { maxP=net; GlobalVariableSet(gvMaxP,maxP); changed=true; }
      if(net<maxL) { maxL=net; GlobalVariableSet(gvMaxL,maxL); changed=true; }
      if(changed)
         ObserverWrite(ObserverSummaryFile,"floating_extreme",
            "direction="+side+"; max_floating_profit_sampled="+DoubleToString(maxP,2)+
            "; max_floating_loss_sampled="+DoubleToString(maxL,2)+"; current_net="+DoubleToString(net,2)+
            "; "+ObserverNearestFiboText(OrderType()==OP_BUY ? Bid : Ask),
            ticket,TimeCurrent(),OrderType()==OP_BUY ? Bid : Ask,net);
      observerTrackedTicket=ticket;
      observerTradeOpenTime=OrderOpenTime();
      observerTradeOpenPrice=OrderOpenPrice();
      observerMaxFloatingProfit=maxP;
      observerMaxFloatingLoss=maxL;
   }
}

void ObserverCheckRecentlyClosed()
{
   int total=OrdersHistoryTotal();
   for(int i=0;i<total;i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderSymbol()!=symbol || OrderType()>OP_SELL || OrderCloseTime()<=0) continue;
      if(observerStartedAt>0 && OrderCloseTime()<observerStartedAt) continue;
      int ticket=OrderTicket();
      string doneGV=ObserverGV("closed",ticket);
      if(GlobalVariableCheck(doneGV)) continue;
      datetime ot=OrderOpenTime(), ct=OrderCloseTime();
      double net=OrderProfit()+OrderSwap()+OrderCommission();
      string side=(OrderType()==OP_BUY ? "BUY" : "SELL");
      string maxPGV=ObserverGV("maxp",ticket), maxLGV=ObserverGV("maxl",ticket);
      double maxP=GlobalVariableCheck(maxPGV) ? GlobalVariableGet(maxPGV) : 0.0;
      double maxL=GlobalVariableCheck(maxLGV) ? GlobalVariableGet(maxLGV) : 0.0;
      int hour=TimeHour(ot);
      string hourKey=IntegerToString(hour);
      string nGV="h_n_"+hourKey, wGV="h_w_"+hourKey, lGV="h_l_"+hourKey, sumGV="h_sum_"+hourKey, winGV="h_win_"+hourKey, lossGV="h_loss_"+hourKey;
      double n=GlobalVariableCheck(ObserverGV(nGV,0)) ? GlobalVariableGet(ObserverGV(nGV,0)) : 0;
      double w=GlobalVariableCheck(ObserverGV(wGV,0)) ? GlobalVariableGet(ObserverGV(wGV,0)) : 0;
      double l=GlobalVariableCheck(ObserverGV(lGV,0)) ? GlobalVariableGet(ObserverGV(lGV,0)) : 0;
      double sum=GlobalVariableCheck(ObserverGV(sumGV,0)) ? GlobalVariableGet(ObserverGV(sumGV,0)) : 0;
      double winsum=GlobalVariableCheck(ObserverGV(winGV,0)) ? GlobalVariableGet(ObserverGV(winGV,0)) : 0;
      double losssum=GlobalVariableCheck(ObserverGV(lossGV,0)) ? GlobalVariableGet(ObserverGV(lossGV,0)) : 0;
      n++;
      if(net>0) { w++; winsum+=net; } else if(net<0) { l++; losssum+=net; }
      sum+=net;
      GlobalVariableSet(ObserverGV(nGV,0),n); GlobalVariableSet(ObserverGV(wGV,0),w); GlobalVariableSet(ObserverGV(lGV,0),l);
      GlobalVariableSet(ObserverGV(sumGV,0),sum); GlobalVariableSet(ObserverGV(winGV,0),winsum); GlobalVariableSet(ObserverGV(lossGV,0),losssum);
      double winPct=(n>0 ? 100.0*w/n : 0), lossPct=(n>0 ? 100.0*l/n : 0);
      double avgWin=(w>0 ? winsum/w : 0), avgLoss=(l>0 ? losssum/l : 0), avgNet=(n>0 ? sum/n : 0);
      string details="direction="+side+"; open_time="+TimeToString(ot,TIME_DATE|TIME_SECONDS)+
         "; close_time="+TimeToString(ct,TIME_DATE|TIME_SECONDS)+"; duration_seconds="+IntegerToString((int)(ct-ot))+
         "; open_price="+DoubleToString(OrderOpenPrice(),Digits)+"; close_price="+DoubleToString(OrderClosePrice(),Digits)+
         "; lots="+DoubleToString(OrderLots(),2)+"; gross_profit="+DoubleToString(OrderProfit(),2)+
         "; swap="+DoubleToString(OrderSwap(),2)+"; commission="+DoubleToString(OrderCommission(),2)+
         "; net_profit="+DoubleToString(net,2)+"; max_floating_profit_sampled="+DoubleToString(maxP,2)+
         "; max_floating_loss_sampled="+DoubleToString(maxL,2)+"; entry_"+ObserverNearestFiboText(OrderOpenPrice())+
         "; exit_"+ObserverNearestFiboText(OrderClosePrice())+"; "+ObserverFiboSnapshot();
      ObserverWrite(ObserverEventsFile,"trade_closed",details,ticket,ct,OrderClosePrice(),net);
      ObserverWrite(ObserverSummaryFile,"hourly_performance",
         "entry_hour_server_time="+hourKey+"; trades="+DoubleToString(n,0)+"; wins="+DoubleToString(w,0)+
         "; losses="+DoubleToString(l,0)+"; win_percent="+DoubleToString(winPct,2)+"; loss_percent="+DoubleToString(lossPct,2)+
         "; average_net="+DoubleToString(avgNet,2)+"; average_win="+DoubleToString(avgWin,2)+
         "; average_loss="+DoubleToString(avgLoss,2)+"; cumulative_net="+DoubleToString(sum,2),
         ticket,ct,OrderClosePrice(),net);
      GlobalVariableSet(doneGV,ct);
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

void ObserverTrackTradePriceExcursions()
{
   double point=ObserverPointSize();
   double pip=ObserverPipSize();
   if(point<=0 || pip<=0) return;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=symbol || OrderType()>OP_SELL) continue;
      int ticket=OrderTicket();
      bool isBuy=(OrderType()==OP_BUY);
      double mark=(isBuy ? Bid : Ask);
      double signedMove=(isBuy ? mark-OrderOpenPrice() : OrderOpenPrice()-mark);
      double movePoints=signedMove/point;
      double movePips=signedMove/pip;
      string maxFavGV=ObserverGV("mfepts",ticket);
      string maxAdvGV=ObserverGV("maepts",ticket);
      bool first=(!GlobalVariableCheck(maxFavGV) || !GlobalVariableCheck(maxAdvGV));
      double maxFav=GlobalVariableCheck(maxFavGV) ? GlobalVariableGet(maxFavGV) : 0.0;
      double maxAdv=GlobalVariableCheck(maxAdvGV) ? GlobalVariableGet(maxAdvGV) : 0.0;
      bool newExtreme=false;
      if(first || movePoints>maxFav) { maxFav=movePoints; GlobalVariableSet(maxFavGV,maxFav); newExtreme=true; }
      if(first || movePoints<maxAdv) { maxAdv=movePoints; GlobalVariableSet(maxAdvGV,maxAdv); newExtreme=true; }
      if(newExtreme)
      {
         double net=OrderProfit()+OrderSwap()+OrderCommission();
         ObserverWriteLevel("trade_price_extreme",
            "direction="+(isBuy ? "BUY" : "SELL")+
            "; lots="+DoubleToString(OrderLots(),2)+
            "; open_price="+DoubleToString(OrderOpenPrice(),Digits)+
            "; mark_price="+DoubleToString(mark,Digits)+
            "; move_points_signed="+DoubleToString(movePoints,1)+
            "; move_pips_signed="+DoubleToString(movePips,1)+
            "; max_favorable_points="+DoubleToString(maxFav,1)+
            "; max_adverse_points="+DoubleToString(maxAdv,1)+
            "; floating_net_money="+DoubleToString(net,2)+
            "; nearest_fibo="+ObserverNearestFiboText(mark)+
            "; "+ObserverFiboSnapshot()+
            "; sampling=every_tick_when_EA_receives_tick",
            TimeCurrent(),mark,ticket);
      }
   }
}

void ObserverCheckArrowTradeLink()
{
   // Associate a newly observed arrow with trades opened within +/- 5 seconds.
   // This is a time-window association, not proof that the arrow caused the trade.
   datetime now=TimeCurrent();
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=symbol || OrderType()>OP_SELL) continue;
      datetime ot=OrderOpenTime();
      string linkGV=ObserverGV("arrowlink",OrderTicket());
      if(GlobalVariableCheck(linkGV)) continue;
      string matched="none";
      int matchedDirection=-1;
      if(observerLastUpArrowSeenAt>0 && MathAbs((double)(ot-observerLastUpArrowSeenAt))<=5.0)
      { matched="UpArrow"; matchedDirection=OP_BUY; }
      if(observerLastDownArrowSeenAt>0 && MathAbs((double)(ot-observerLastDownArrowSeenAt))<=5.0)
      { matched="DownArrow"; matchedDirection=OP_SELL; }
      if(matched=="none" && (TimeCurrent()-ot)<5) continue;
      string status=(matched=="none" ? "no_arrow_within_5s" :
                     ((matchedDirection==OrderType()) ? "direction_matches" : "direction_mismatch"));
      ObserverWrite(ObserverEventsFile,"arrow_trade_association",
         "arrow_object="+matched+"; association_status="+status+
         "; trade_open_time="+TimeToString(ot,TIME_DATE|TIME_SECONDS)+
         "; seconds_from_up_arrow_observed="+(observerLastUpArrowSeenAt>0 ? DoubleToString((double)(ot-observerLastUpArrowSeenAt),0) : "na")+
         "; seconds_from_down_arrow_observed="+(observerLastDownArrowSeenAt>0 ? DoubleToString((double)(ot-observerLastDownArrowSeenAt),0) : "na"),
         OrderTicket(),now,OrderOpenPrice(),OrderProfit()+OrderSwap()+OrderCommission());
      GlobalVariableSet(linkGV,now);
   }
}

void ObserverWriteScenarioNote(string detail,int ticket,datetime at,double price)
{
   ObserverWrite(ObserverScenariosFile,"scenario_input",detail,ticket,at,price,0.0);
}



// === Derik1.3: selected scenarios + compact gross floating P/L observer ===
string ObserverTFName13(){if(Period()==PERIOD_M1)return "M1";if(Period()==PERIOD_M5)return "M5";return "TF"+IntegerToString(Period());}
void ObserverWriteCompact(string fileName,string header,string row)
{
   FolderCreate(ObserverFolder);
   int h=FileOpen(fileName,FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(h==INVALID_HANDLE)return;
   if(FileSize(h)==0)FileWriteString(h,header+"\r\n");
   FileSeek(h,0,SEEK_END);if(row!="")FileWriteString(h,row+"\r\n");
   FileFlush(h);FileClose(h);
}
void ObserverError13(string detail)
{
   ObserverWriteCompact(ObserverErrorsFile,"server_time;symbol;timeframe;detail",
      TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+";"+symbol+";"+observerChartTF+";"+ObserverSafe(detail));
}
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
bool ExecuteScenarioBuy13(){double en=NormalizeDouble(Ask,Digits),sl=0,tp=0;if(!ObserverLevels13(OP_BUY,en,sl,tp))return false;return ExecuteBuy(sl,tp);}
bool ExecuteScenarioSell13(){double en=NormalizeDouble(Bid,Digits),sl=0,tp=0;if(!ObserverLevels13(OP_SELL,en,sl,tp))return false;return ExecuteSell(sl,tp);}
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




//+------------------------------------------------------------------+
//| FIBAR PRO customer dashboard and chart theme                     |
//+------------------------------------------------------------------+
string FIBAR_PREFIX = "FIBAR_PRO_";
color FIBAR_PURPLE = C'187,131,245';
color FIBAR_BLUE   = C'82,118,185';

void FibarSetLabel(string id,string value,int x,int y,int size,color clr,string font)
{
   string name=FIBAR_PREFIX+id;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetString(0,name,OBJPROP_TEXT,value);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void FibarCreatePanel()
{
   if(!ShowDashboard) return;
   string bg=FIBAR_PREFIX+"BG";
   if(ObjectFind(0,bg)<0) ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,12);
   ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,18);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,292);
   ObjectSetInteger(0,bg,OBJPROP_YSIZE,205);
   ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C'10,10,16');
   ObjectSetInteger(0,bg,OBJPROP_COLOR,FIBAR_PURPLE);
   ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,bg,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,bg,OBJPROP_BACK,false);
   ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);

   FibarSetLabel("TITLE","♛  FIBAR PRO",26,27,16,FIBAR_PURPLE,"Segoe UI Symbol");
   FibarSetLabel("SUBTITLE","ALGORITHMIC TRADING SYSTEM",28,51,7,clrSilver,"Arial");
   FibarSetLabel("DIVIDER","________________________________________",25,66,8,FIBAR_PURPLE,"Arial");
   FibarSetLabel("STATUS","●  ACTIVE",27,82,10,clrLime,"Arial");
   FibarSetLabel("SYMBOL","SYMBOL / TF",27,108,8,clrSilver,"Arial");
   FibarSetLabel("STRATEGY","STRATEGY",27,132,8,clrSilver,"Arial");
   FibarSetLabel("TODAY","TODAY'S PROFIT",27,156,8,clrSilver,"Arial");
   FibarSetLabel("FLOATING","FLOATING P/L",27,180,8,clrSilver,"Arial");
   FibarSetLabel("OPEN","OPEN TRADES",168,108,8,clrSilver,"Arial");
   FibarSetLabel("INDICATOR","INDICATOR",168,132,8,clrSilver,"Arial");
   FibarSetLabel("CONNECTION","CONNECTION",168,156,8,clrSilver,"Arial");
}

double FibarTodayClosedProfit()
{
   double total=0.0;
   datetime dayStart=StrToTime(TimeToString(TimeCurrent(),TIME_DATE));
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderSymbol()!=symbol || OrderType()>OP_SELL) continue;
      if(OrderCloseTime()>=dayStart)
         total+=OrderProfit()+OrderSwap()+OrderCommission();
   }
   return total;
}

void UpdateFibarDashboard()
{
   if(!ShowDashboard) return;
   FibarCreatePanel();

   double floating=0.0;
   int openCount=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=symbol || OrderType()>OP_SELL) continue;
      floating+=OrderProfit()+OrderSwap()+OrderCommission();
      openCount++;
   }

   bool fiboReady=(ObjectFind(0,"XIT_FIBO")>=0 && ObjectType("XIT_FIBO")==OBJ_FIBO);
   bool connected=IsConnected();

   FibarSetLabel("SYMBOL_VALUE",symbol+" / M1",27,119,9,clrWhite,"Arial");
   FibarSetLabel("STRATEGY_VALUE","FIBO SYSTEM",27,143,9,clrWhite,"Arial");
   FibarSetLabel("TODAY_VALUE",DoubleToString(FibarTodayClosedProfit(),2),27,167,9,
                 (FibarTodayClosedProfit()>=0?clrLime:clrTomato),"Arial");
   FibarSetLabel("FLOAT_VALUE",DoubleToString(floating,2),27,191,9,
                 (floating>=0?clrLime:clrTomato),"Arial");
   FibarSetLabel("OPEN_VALUE",IntegerToString(openCount),168,119,9,clrWhite,"Arial");
   FibarSetLabel("INDICATOR_VALUE",(fiboReady?"FIBO READY":"NOT FOUND"),168,143,8,
                 (fiboReady?clrLime:clrTomato),"Arial");
   FibarSetLabel("CONNECTION_VALUE",(connected?"CONNECTED":"OFFLINE"),168,167,8,
                 (connected?clrLime:clrTomato),"Arial");
   ChartRedraw(0);
}

void ApplyFibarChartTheme()
{
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,FIBAR_PURPLE);
   ChartSetInteger(0,CHART_COLOR_CHART_UP,FIBAR_PURPLE);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,FIBAR_BLUE);
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,FIBAR_BLUE);
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,clrSilver);
}

void DeleteFibarObjects()
{
   for(int i=ObjectsTotal(0,-1,-1)-1;i>=0;i--)
   {
      string name=ObjectName(0,i,-1,-1);
      if(StringFind(name,FIBAR_PREFIX)==0) ObjectDelete(0,name);
   }
}


int OnInit()
{
   symbol=Symbol();
   if(Period()!=PERIOD_M1)
   {
      ChartSetSymbolPeriod(0,Symbol(),PERIOD_M1);
      return(INIT_SUCCEEDED);
   }
   ApplyFibarChartTheme();
   observerChartTF=ObserverTFName13();observerStartedAt=TimeCurrent();
   ObserverFolder="Derik1.3\\"+observerChartTF;
   ObserverEventsFile=ObserverFolder+"\\Observer_Events.csv";
   ObserverSummaryFile=ObserverFolder+"\\Observer_Summary.csv";
   ObserverErrorsFile=ObserverFolder+"\\Errors.csv";
   ObserverTradeLogFile=ObserverFolder+"\\TradeLog.csv";
   ObserverDailyFile=ObserverFolder+"\\DailySummary.csv";
   ObserverLevelsFile=ObserverFolder+"\\Observer_Levels.csv";
   ObserverScenariosFile=ObserverFolder+"\\Observer_Scenarios.csv";
   ObserverTicksFile=ObserverFolder+"\\Observer_Ticks.csv";
   FolderCreate("Derik1.3");FolderCreate(ObserverFolder);
   ObserverWrite(ObserverEventsFile,"observer_started","version=Derik1.3; mode=LIVE_EA_WITH_COMPACT_OBSERVER; symbol="+symbol+
      "; timeframe="+observerChartTF+"; selected_scenario="+(Period()==PERIOD_M1?"25":(Period()==PERIOD_M5?"22":"UNSUPPORTED"))+
      "; gross_floating_tracking=true; swap_commission_excluded=true",-1,TimeCurrent(),Bid,0);
   ObserverWriteCompact(ObserverTradeLogFile,"server_time;event;ticket;symbol;timeframe;scenario;direction;open_time;open_price;initial_sl;tp2;price;exit_reason;gross_profit;floating_profit_gross;max_floating_profit;max_floating_loss;mfe_points;mae_points;duration_seconds","");
   ObserverWriteCompact(ObserverDailyFile,"server_date;symbol;timeframe;trades;wins;losses;gross_wins;gross_losses;net_gross","");
   Print("FIBAR PRO started on "+symbol+" M1");
   FibarCreatePanel();
   UpdateFibarDashboard();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObserverWrite(ObserverEventsFile,"observer_stopped","timeframe="+observerChartTF+"; reason="+IntegerToString(reason),-1,TimeCurrent(),Bid,0);
   DeleteFibarObjects();
   Print("FIBAR PRO stopped on "+symbol+" M1");
}

void OnTick()
{
   UpdateFibarDashboard();
   if (Symbol() != TradeSymbol || Period() != TF) return;

   ObserverTick();

   datetime currentBar = iTime(symbol, 0, 0);
   if (currentBar == lastBar) return;
   lastBar = currentBar;

   CheckArrowAndTrade();
   CheckClosedOrders();
   ShowFiboLevelsOnChart();


}

void CheckArrowAndTrade()
{
   double level_0, level_38, level_61;
   bool fiboOk = GetFiboLevels(level_0, level_38, level_61);

   int total = ObjectsTotal();
   for (int i = 0; i < total; i++)
   {
      string objName = ObjectName(i);
      if (ObjectType(objName) != OBJ_ARROW) continue;

      string desc = ObjectDescription(objName);
      if (desc == "Traded")
      {
         Print("radshodan: " + objName + " ghablan trade shode");
         continue;
      }

      double arrowPrice = ObjectGet(objName, OBJPROP_PRICE);

      if (objName == "UpArrow")
      {
         Print("signal: UpArrow peyda shod");
         if (OrdersTotal() == 0)
         {
            if (fiboOk && arrowPrice < level_38)
            {
               if(ExecuteScenarioBuy13())
               {
                  ObjectSetText(objName, "Traded", 0, "Arial", clrNONE);
                  Print("Derik1.3 BUY opened with selected M1/M5 scenario");
                  SendNotification("Derik1.3 BUY opened with selected scenario");
               }
            }
            else if (!UseFiboLevels)
            {
               ExecuteBuyCustom();
               ObjectSetText(objName, "Traded", 0, "Arial", clrNONE);
               Print("movafagh: Buy ejra shod ba TP/SL custom");
               SendNotification("Buy ejra shod ba TP/SL custom");
               Alert("Buy ejra shod → TP: " + DoubleToString(CustomTP, 0));
            }
            else
            {
               Print("radshodan: shart Buy bargharar nist");
            }
         }
         else
         {
            Print("radshodan: moamele baz hast");
         }
         return;
      }

      if (objName == "DownArrow")
      {
         Print("signal: DownArrow peyda shod");
         if (OrdersTotal() == 0)
         {
            if (fiboOk && arrowPrice > level_38)
            {
               if(ExecuteScenarioSell13())
               {
                  ObjectSetText(objName, "Traded", 0, "Arial", clrNONE);
                  Print("Derik1.3 SELL opened with selected M1/M5 scenario");
                  SendNotification("Derik1.3 SELL opened with selected scenario");
               }
            }
            else if (!UseFiboLevels)
            {
               ExecuteSellCustom();
               ObjectSetText(objName, "Traded", 0, "Arial", clrNONE);
               Print("movafagh: Sell ejra shod ba TP/SL custom");
               SendNotification("Sell ejra shod ba TP/SL custom");
               Alert("Sell ejra shod → TP: " + DoubleToString(CustomTP, 0));
            }
            else
            {
               Print("radshodan: shart Sell bargharar nist");
            }
         }
         else
         {
            Print("radshodan: moamele baz hast");
         }
         return;
      }
   }

   Print("radshodan: hich arrow peyda nashod");
}

bool GetFiboLevels(double &level0, double &level38, double &level61)
{
   string objName = "XIT_FIBO";
   if (ObjectFind(0, objName) < 0 || ObjectType(objName) != OBJ_FIBO)
   {
      Print("hkata: Fibo peyda nashod ya type eshtebah");
      return false;
   }

   double price1 = ObjectGet(objName, OBJPROP_PRICE1);
   double price2 = ObjectGet(objName, OBJPROP_PRICE2);
   if (price1 == 0 || price2 == 0)
   {
      Print("hkata: price1 ya price2 sefr hast");
      return false;
   }

   int fiboColor = ObjectGetInteger(0, objName, OBJPROP_COLOR);
   bool reverse = (fiboColor == clrRed || fiboColor == clrBlue);


   level0  = reverse ? price2 : price1;
   level38 = reverse ? price2 + (price1 - price2) * 0.382 : price1 + (price2 - price1) * 0.382;
   level61 = reverse ? price2 + (price1 - price2) * 0.618 : price1 + (price2 - price1) * 0.618;

   Print("fibo: level0=" + DoubleToString(level0, Digits) + ", level38=" + DoubleToString(level38, Digits) + ", level61=" + DoubleToString(level61, Digits));
   return true;
}

bool ExecuteBuy(double sl,double tp)
{
   double price=NormalizeDouble(Ask,Digits);ResetLastError();
   int ticket=OrderSend(symbol,OP_BUY,LotSize,price,Slippage,sl,tp,"Buy from UpArrow",0,0,clrGreen);
   if(ticket<0){int err=GetLastError();ObserverError13("OrderSend BUY failed; error="+IntegerToString(err));
      Print("hkata: Buy failed → "+IntegerToString(err));SendNotification("hkata: Buy failed → "+IntegerToString(err));return false;}
   return true;
}

bool ExecuteSell(double sl,double tp)
{
   double price=NormalizeDouble(Bid,Digits);ResetLastError();
   int ticket=OrderSend(symbol,OP_SELL,LotSize,price,Slippage,sl,tp,"Sell from DownArrow",0,0,clrRed);
   if(ticket<0){int err=GetLastError();ObserverError13("OrderSend SELL failed; error="+IntegerToString(err));
      Print("hkata: Sell failed → "+IntegerToString(err));SendNotification("hkata: Sell failed → "+IntegerToString(err));return false;}
   return true;
}

void ExecuteBuyCustom()
{
   double price = NormalizeDouble(Ask, Digits);
   double tp = price + CustomTP * Point;
   double sl = price - CustomSL * Point;
   ExecuteBuy(sl, tp);
}

void ExecuteSellCustom()
{
   double price = NormalizeDouble(Bid, Digits);
   double tp = price - CustomTP * Point;
   double sl = price + CustomSL * Point;
   ExecuteSell(sl, tp);
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
