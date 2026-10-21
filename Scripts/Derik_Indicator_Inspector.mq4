//+------------------------------------------------------------------+
//| Derik_Indicator_Inspector.mq4                                    |
//| MT4 / MQL4 utility: exports chart objects and iCustom buffers.   |
//| NOTE: generic buffer scan assumes the indicator has NO inputs.   |
//| If it has inputs, add them to the iCustom() call in this script.  |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

extern string IndicatorName = "";       // Name under MQL4/Indicators, without .ex4
extern int    IndicatorTimeframe = 0;    // 0 = current chart timeframe
extern int    BufferCount = 8;           // Buffer indices to inspect: 0..BufferCount-1
extern int    BarsToScan = 500;          // Number of recent bars to inspect
extern bool   ExportChartObjects = true;
extern bool   ExportBuffers = true;

string SafeFilePart(string value)
{
   StringReplace(value, " ", "_");
   StringReplace(value, "/", "_");
   StringReplace(value, "\\", "_");
   StringReplace(value, ":", "_");
   return value;
}

string TimeframeLabel(int tf)
{
   if(tf == 0) tf = Period();
   return IntegerToString(tf);
}

int OnStart()
{
   string symbolPart = SafeFilePart(Symbol());
   string stamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   StringReplace(stamp, ".", "-");
   StringReplace(stamp, ":", "-");
   StringReplace(stamp, " ", "_");

   string objectsFile = "Derik_Objects_" + symbolPart + "_" + stamp + ".csv";
   string buffersFile = "Derik_Buffers_" + symbolPart + "_" + stamp + ".csv";

   if(ExportChartObjects)
   {
      int objectHandle = FileOpen(objectsFile, FILE_WRITE|FILE_CSV|FILE_ANSI, ';');
      if(objectHandle == INVALID_HANDLE)
      {
         Print("Derik Inspector: cannot open objects report. Error=", GetLastError());
      }
      else
      {
         FileWrite(objectHandle, "ChartSymbol", "ChartPeriod", "Index", "Name",
                   "Type", "Description", "Time1", "Price1", "Time2", "Price2",
                   "Color", "Style", "Width", "Text", "Tooltip");
         int total = ObjectsTotal(0, 0, -1);
         for(int i = 0; i < total; i++)
         {
            string name = ObjectName(0, i, 0, -1);
            if(name == "") continue;

            int type = (int)ObjectGetInteger(0, name, OBJPROP_TYPE);
            datetime t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME1);
            datetime t2 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME2);
            double p1 = ObjectGetDouble(0, name, OBJPROP_PRICE1);
            double p2 = ObjectGetDouble(0, name, OBJPROP_PRICE2);
            color objColor = (color)ObjectGetInteger(0, name, OBJPROP_COLOR);
            int style = (int)ObjectGetInteger(0, name, OBJPROP_STYLE);
            int width = (int)ObjectGetInteger(0, name, OBJPROP_WIDTH);
            string description = ObjectDescription(name);
            string objText = ObjectGetString(0, name, OBJPROP_TEXT);
            string tooltip = ObjectGetString(0, name, OBJPROP_TOOLTIP);

            FileWrite(objectHandle, Symbol(), Period(), i, name, type, description,
                      TimeToString(t1, TIME_DATE|TIME_SECONDS), DoubleToString(p1, Digits),
                      TimeToString(t2, TIME_DATE|TIME_SECONDS), DoubleToString(p2, Digits),
                      IntegerToString((int)objColor), style, width, objText, tooltip);
         }
         FileClose(objectHandle);
         Print("Derik Inspector: object report saved to MQL4/Files/", objectsFile);
      }
   }

   if(ExportBuffers)
   {
      if(StringLen(IndicatorName) == 0)
      {
         Print("Derik Inspector: set IndicatorName to scan buffers. Object export can still be used.");
         return(0);
      }

      int tf = IndicatorTimeframe;
      if(tf == 0) tf = Period();

      int bars = BarsToScan;
      if(bars < 1) bars = 1;
      if(BufferCount < 1) BufferCount = 1;
      if(BufferCount > 64) BufferCount = 64;

      int bufferHandle = FileOpen(buffersFile, FILE_WRITE|FILE_CSV|FILE_ANSI, ';');
      if(bufferHandle == INVALID_HANDLE)
      {
         Print("Derik Inspector: cannot open buffer report. Error=", GetLastError());
         return(0);
      }

      FileWrite(bufferHandle, "Symbol", "Timeframe", "Indicator", "BufferIndex",
                "Shift", "BarTime", "Value", "IsEmpty");
      int availableBars = iBars(Symbol(), tf);
      if(bars > availableBars) bars = availableBars;

      for(int mode = 0; mode < BufferCount; mode++)
      {
         for(int shift = 0; shift < bars; shift++)
         {
            ResetLastError();
            // This generic call works only when the custom indicator has no external inputs.
            double value = iCustom(Symbol(), tf, IndicatorName, mode, shift);
            int err = GetLastError();
            bool isEmpty = (value == EMPTY_VALUE || value == 2147483647.0);

            FileWrite(bufferHandle, Symbol(), tf, IndicatorName, mode, shift,
                      TimeToString(iTime(Symbol(), tf, shift), TIME_DATE|TIME_SECONDS),
                      DoubleToString(value, 8), isEmpty);

            if(err != 0)
               Print("Derik Inspector: iCustom error ", err,
                     " for buffer ", mode, ", shift ", shift,
                     ". Indicator inputs may be required.");
         }
      }

      FileClose(bufferHandle);
      Print("Derik Inspector: buffer report saved to MQL4/Files/", buffersFile);
   }

   Print("Derik Inspector finished. Reports are in the terminal's MQL4/Files folder.");
   return(0);
}
//+------------------------------------------------------------------+
