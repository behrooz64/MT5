//+------------------------------------------------------------------+
//| Expert: ArrowTradeWithFiboTP                                     |
//+------------------------------------------------------------------+
#property strict

// 🔹 Inputs
input string TradeSymbol     = "XAUUSD";       // namad
input ENUM_TIMEFRAMES TF     = PERIOD_M1;      // timeframe
input double LotSize         = 0.1;            // hajm
input int Slippage           = 3;              // slippage
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
string ObserverLevelsFile = "Derik1.1\\Observer_Levels.csv";
string ObserverScenariosFile = "Derik1.1\\Observer_Scenarios.csv";
int observerTrackedTicket = -1;
double observerMaxFloatingProfit = 0.0;
double observerMaxFloatingLoss = 0.0;
datetime observerTradeOpenTime = 0;
double observerTradeOpenPrice = 0.0;
double observerFiboAtEntry[10];
bool observerHasFiboAtEntry = false;
string ObserverFolder = "Derik1.1";
string ObserverEventsFile = "Derik1.1\\Observer_Events.csv";
string ObserverSummaryFile = "Derik1.1\\Observer_Summary.csv";
string ObserverErrorsFile = "Derik1.1\\Observer_Errors.csv";
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


void ObserverTick()
{
   if(observerStartedAt==0) observerStartedAt=TimeCurrent();
   ObserverCheckArrows();
   ObserverTrackFiboTouches();
   ObserverCaptureOpenTrades();
   ObserverTrackTradePriceExcursions();
   ObserverCheckArrowTradeLink();
   ObserverCheckRecentlyClosed();
}


int OnInit()
{
   symbol = Symbol();
   FolderCreate(ObserverFolder);
   ObserverWrite(ObserverEventsFile,"observer_started","version=Derik1.1; sampling=every_tick; note=only_ticks_received_while_EA_is_running", -1,TimeCurrent(),Bid,0.0);
   ObserverWriteLevel("observer_started","point_size="+DoubleToString(MarketInfo(symbol,MODE_POINT),Digits)+
      "; pip_size="+DoubleToString(ObserverPipSize(),Digits)+
      "; digits="+IntegerToString((int)MarketInfo(symbol,MODE_DIGITS))+
      "; tick_value="+DoubleToString(MarketInfo(symbol,MODE_TICKVALUE),2)+
      "; tick_size="+DoubleToString(MarketInfo(symbol,MODE_TICKSIZE),Digits)+
      "; account_currency="+AccountCurrency(),TimeCurrent(),Bid,-1);
   Print("EA shoroo shod rooye " + symbol);
   SendNotification(" EA shoroo shod rooye " + symbol);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Print("payan - EA ghat shod rooye " + symbol);
   SendNotification("payan - EA ghat shod rooye " + symbol);
}

void OnTick()
{
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
               ExecuteBuy(level_0, level_61);
               ObjectSetText(objName, "Traded", 0, "Arial", clrNONE);
               Print("movafagh: Buy ejra shod ba TP/SL az fibo");
               SendNotification("Buy ejra shod ba TP/SL az fibo");
               Alert("Buy ejra shod → TP: " + DoubleToString(level_61, Digits));
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
               ExecuteSell(level_0, level_61);
               ObjectSetText(objName, "Traded", 0, "Arial", clrNONE);
               Print("movafagh: Sell ejra shod ba TP/SL az fibo");
               SendNotification("Sell ejra shod ba TP/SL az fibo");
               Alert("Sell ejra shod → TP: " + DoubleToString(level_61, Digits));
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

void ExecuteBuy(double sl, double tp)
{
   double price = NormalizeDouble(Ask, Digits);
   int ticket = OrderSend(symbol, OP_BUY, LotSize, price, Slippage, sl, tp, "Buy from UpArrow", 0, 0, clrGreen);
   if (ticket < 0)
   {
      Print("hkata: Buy failed → " + IntegerToString(GetLastError()));
      SendNotification("hkata: Buy failed → " + IntegerToString(GetLastError()));
   }
}

void ExecuteSell(double sl, double tp)
{
   double price = NormalizeDouble(Bid, Digits);
   int ticket = OrderSend(symbol, OP_SELL, LotSize, price, Slippage, sl, tp, "Sell from DownArrow", 0, 0, clrRed);
   if (ticket < 0)
   {
      Print("hkata: Sell failed → " + IntegerToString(GetLastError()));
      SendNotification("hkata: Sell failed → " + IntegerToString(GetLastError()));
   }
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
