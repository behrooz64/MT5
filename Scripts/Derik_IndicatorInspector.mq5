//+------------------------------------------------------------------+
//| Derik_IndicatorInspector.mq5                                     |
//| Diagnostic script for inspecting an MT5 custom indicator.        |
//| Writes CSV reports to MQL5/Files.                                 |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs
#property version   "1.00"
#property description "Logs chart objects and readable indicator-buffer values to CSV."

input string IndicatorName       = "";     // Indicator path/name relative to MQL5/Indicators, without .ex5
input int    BarsToScan           = 100;    // Number of recent bars to record per readable buffer
input int    BufferScanLimit      = 64;     // Buffer indexes to probe (0..limit-1)
input int    PollSeconds          = 1;      // Seconds between live snapshots
input bool   KeepRunning          = true;   // Continue monitoring until script is stopped

int      g_indicator_handle = INVALID_HANDLE;
string   g_objects_file;
string   g_buffers_file;

// Append a row to a CSV file. Files are created under MQL5/Files.
int OpenCsvAppend(const string file_name)
{
   int handle = FileOpen(file_name, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
   {
      Print("Derik inspector: cannot open ", file_name, ", error=", GetLastError());
      return INVALID_HANDLE;
   }
   FileSeek(handle, 0, SEEK_END);
   return handle;
}

string SafeTimestamp()
{
   return TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS);
}

void WriteHeadersIfEmpty()
{
   if(!FileIsExist(g_objects_file))
   {
      int f = FileOpen(g_objects_file, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, ',');
      if(f != INVALID_HANDLE)
      {
         FileWrite(f, "timestamp", "symbol", "period", "object_name", "object_type",
                   "text", "price_0", "time_0", "color");
         FileClose(f);
      }
   }

   if(!FileIsExist(g_buffers_file))
   {
      int f = FileOpen(g_buffers_file, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, ',');
      if(f != INVALID_HANDLE)
      {
         FileWrite(f, "timestamp", "symbol", "period", "indicator", "buffer_index",
                   "bar_shift", "bar_time", "value");
         FileClose(f);
      }
   }
}

void LogChartObjects()
{
   int f = OpenCsvAppend(g_objects_file);
   if(f == INVALID_HANDLE)
      return;

   const int total = ObjectsTotal(0, -1, -1);
   const string stamp = SafeTimestamp();

   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i, -1, -1);
      if(name == "")
         continue;

      long type_value = ObjectGetInteger(0, name, OBJPROP_TYPE);
      string object_text = ObjectGetString(0, name, OBJPROP_TEXT);
      double price0 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      long time0 = ObjectGetInteger(0, name, OBJPROP_TIME, 0);
      long color_value = ObjectGetInteger(0, name, OBJPROP_COLOR);

      FileWrite(f, stamp, _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period),
                name, EnumToString((ENUM_OBJECT)type_value), object_text,
                DoubleToString(price0, _Digits),
                TimeToString((datetime)time0, TIME_DATE|TIME_SECONDS),
                (string)color_value);
   }

   FileClose(f);
}

void LogIndicatorBuffers()
{
   if(g_indicator_handle == INVALID_HANDLE)
      return;

   int f = OpenCsvAppend(g_buffers_file);
   if(f == INVALID_HANDLE)
      return;

   int bars = BarsToScan;
   if(bars < 1)
      bars = 1;

   const int available_bars = Bars(_Symbol, (ENUM_TIMEFRAMES)_Period);
   if(available_bars > 0 && bars > available_bars)
      bars = available_bars;

   const string stamp = SafeTimestamp();

   for(int buffer_index = 0; buffer_index < BufferScanLimit; buffer_index++)
   {
      double values[];
      ArraySetAsSeries(values, true);
      ResetLastError();
      int copied = CopyBuffer(g_indicator_handle, buffer_index, 0, bars, values);

      if(copied <= 0)
         continue; // Unsupported or unavailable buffer; continue probing other indexes.

      for(int shift = 0; shift < copied; shift++)
      {
         double value = values[shift];
         if(value == EMPTY_VALUE)
            continue;

         datetime bar_time = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
         FileWrite(f, stamp, _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period),
                   IndicatorName, buffer_index, shift,
                   TimeToString(bar_time, TIME_DATE|TIME_SECONDS),
                   DoubleToString(value, _Digits));
      }
   }

   FileClose(f);
}

void OnStart()
{
   if(StringTrimLeft(IndicatorName) == "" || StringTrimRight(IndicatorName) == "")
   {
      Print("Derik inspector: set IndicatorName in the script inputs, then run again.");
      return;
   }

   if(BufferScanLimit < 1 || BufferScanLimit > 512)
   {
      Print("Derik inspector: BufferScanLimit must be between 1 and 512.");
      return;
   }

   if(BarsToScan < 1)
   {
      Print("Derik inspector: BarsToScan must be at least 1.");
      return;
   }

   string safe_symbol = _Symbol;
   StringReplace(safe_symbol, "/", "_");
   StringReplace(safe_symbol, "\\", "_");

   g_objects_file = "Derik_Objects_" + safe_symbol + "_" +
                    EnumToString((ENUM_TIMEFRAMES)_Period) + ".csv";
   g_buffers_file = "Derik_Buffers_" + safe_symbol + "_" +
                    EnumToString((ENUM_TIMEFRAMES)_Period) + ".csv";

   WriteHeadersIfEmpty();

   ResetLastError();
   g_indicator_handle = iCustom(_Symbol, (ENUM_TIMEFRAMES)_Period, IndicatorName);
   if(g_indicator_handle == INVALID_HANDLE)
   {
      Print("Derik inspector: iCustom failed for '", IndicatorName,
            "'. Check the indicator path and whether it requires input parameters. Error=",
            GetLastError());
      Print("Reports (if created): ", g_objects_file, " and ", g_buffers_file);
      return;
   }

   Print("Derik inspector started. Indicator=", IndicatorName,
         "; object report=MQL5/Files/", g_objects_file,
         "; buffer report=MQL5/Files/", g_buffers_file,
         ". Stop the script to end monitoring.");

   do
   {
      LogChartObjects();
      LogIndicatorBuffers();
      if(!KeepRunning)
         break;

      int wait_seconds = PollSeconds;
      if(wait_seconds < 1)
         wait_seconds = 1;

      for(int second = 0; second < wait_seconds && !IsStopped(); second++)
         Sleep(1000);
   }
   while(!IsStopped());

   if(g_indicator_handle != INVALID_HANDLE)
      IndicatorRelease(g_indicator_handle);

   Print("Derik inspector stopped. CSV reports are in MQL5/Files.");
}
