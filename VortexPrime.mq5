//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

// Include necessary libraries and headers
#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Arrays/ArrayDouble.mqh>
#include <Math/Stat/Math.mqh>
#include <Generic\HashMap.mqh>

// Input parameters for the EA
static input long    InpMagicnumber    = 234234;      // Unique identifier for the EA's orders

input double         InpLotSize        = 0.1;     // Starting lot size for the first trade
input double         InpLotMultiply    = 2.0;      // Multiplier applied to the lot size for subsequent trades
input double         InpMaxLotSize     = 0.8;     // Maximum allowable lot size for any individual trade
input double         InpMaxAccLot      = 8;        // Maximum cumulative lot size for all open trades combined

input int            InpGridStep       = 100;      // Distance in points between grid levels for opening new trades
input double         InpGridMultiply   = 1.5;      // Multiplier applied to the grid step for subsequent trades
input double         InpMaxGrid        = 5000;     // Maximum allowable grid step distance

input int            InpTakeProfit     = 700;      // Target profit in points at which to close trades
input int            InpMATicket       = 5;        // Maximum number of open orders before the special close condition is applied
input double         InpPercentTP      = -50;       // Percentage of InpTakeProfit to be applied when special close condition
input int            InpPeriod         = 3600;     // Period in seconds between orders

// Input parameters for Stochastic indicator
input int            InpStoKPeriod  = 5;              // Stochastic K-period
input int            InpStoDPeriod  = 3;              // Stochastic D-period
input int            InpStoSlowing  = 3;              // Sto final smoothing
input ENUM_MA_METHOD InpStoMAMethod = MODE_SMA;       // Stochastic type of smoothing
input ENUM_STO_PRICE InpStoPrice    = STO_LOWHIGH;    // Stochastic calculation method
input double         InpStoLevel    = 45;             // Stochastic level
input bool           InpStoActive   = true;           // Enable/Disable Stochastic indicator

// Input parameters for RSI indicator
input int                  InpRSIMAPeriod = 14;             // RSI averaging period
input ENUM_APPLIED_PRICE   InpRSIAppPrice = PRICE_CLOSE;    // RSI type of price or handle
input double               InpRSILevel    = 30;             // RSI level
input bool                 InpRSIActive   = true;          // Enable/Disable RSI indicator

// Input parameters for CCI indicator
input int                  InpCCIMAPeriod = 14;             // CCI averaging period
input ENUM_APPLIED_PRICE   InpCCIAppPrice = PRICE_TYPICAL;  // CCI type of price or handle
input double               InpCCILevel    = 100;            // CCI level
input bool                 InpCCIActive   = true;          // Enable/Disable CCI indicator

// Input parameters for MACD indicator
input int                  InpMACDFastPeriod    = 12;             // MACD fast average period
input int                  InpMACDSlowPeriod    = 26;             // MACD slow average period
input int                  InpMACDSignalPeriod  = 9;              // MACD signal average period
input ENUM_APPLIED_PRICE   InpMACDAppPrice      = PRICE_CLOSE;    // MACD type of price or handle
input double               InpMACDLevel         = 0.0007;         // MACD level
input ENUM_TIMEFRAMES      InpMACDTimeFrame     = PERIOD_H1;      // MACD timeframe
input bool                 InpMACDActive        = true;           // Enable/Disable MACD indicator

// Input parameters for D1 Stochastic indicator
input int            InpHardStoKPeriod  = 5;             // D1 Stochastic K-period
input int            InpHardStoDPeriod  = 3;             // D1 Stochastic D-period
input int            InpHardStoSlowing  = 3;             // D1 Stochastic final smoothing
input ENUM_MA_METHOD InpHardStoMAMethod = MODE_SMA;      // D1 Stochastic type of smoothing
input ENUM_STO_PRICE InpHardStoPrice    = STO_LOWHIGH;   // D1 Stochastic calculation method
input double         InpHardStoLevel    = 45;            // D1 Stochastic level
input bool           InpHardStoActive   = true;          // Enable/Disable D1 Stochastic

input bool           InpOptimizeMode    = false;         // Optimize mode (disables Print function)

/**
 * @class VortexPrimeExpert
 * @brief Manages and operates on a collection of trading positions.
 *
 * This class provides methods to manage and interact with trading positions in the MetaTrader platform.
 * It allows for operations such as loading tickets, calculating profits, managing lots, and closing orders.
 */
class VortexPrimeExpert:public CObject{
private:
   long type;           ///< Type of positions managed by the expert advisor.
   ulong ticketArr[];   ///< Array to store ticket numbers of managed positions.
   bool status;         ///< Current status of the expert advisor.
public:
   /**
    * @brief Constructor for VortexPrimeExpert.
    * @param inpType Type of the trading position to manage.
    *
    * Initializes the class with a specified type and loads existing tickets.
    */
   VortexPrimeExpert(long inpType){
      type = inpType;
      this.loadTickets();
   }
   
   /**
    * @brief Loads tickets for positions that match the specified type and magic number.
    * @return True if tickets are successfully loaded, false otherwise.
    *
    * This method populates the ticketArr with tickets of positions that match the given type and magic number.
    */
   bool loadTickets(){
      int realTotal = 0;
      int totalTicket = PositionsTotal();
      ArrayResize(ticketArr,totalTicket);
      for(int i = 0;i<totalTicket;i++){
         ulong positionTicket = PositionGetTicket(i);
         if(positionTicket<=0){Print("Failed to get ticket");return false;}
         if(!PositionSelectByTicket(positionTicket)){Print("Failed to select by ticket");return false;}
         if(InpMagicnumber != PositionGetInteger(POSITION_MAGIC)){continue;}
         if(Symbol() != PositionGetString(POSITION_SYMBOL)){continue;}
         if(type != PositionGetInteger(POSITION_TYPE)){continue;}
         
         ticketArr[realTotal] = positionTicket;
         realTotal++;
      }
      ArrayResize(ticketArr,realTotal);
      return true;
   }
   
   /**
    * @brief Calculates the total profit from all positions.
    * @return Total profit from all positions.
    */
   double getProfit(){
      double profit = 0;
      for(int i = 0;i<ArraySize(ticketArr);i++){
         PositionSelectByTicket(ticketArr[i]);
         profit += PositionGetDouble(POSITION_PROFIT);
      }
      return profit;
   }

   /**
    * @brief Gets the profit of a specific position by its index.
    * @param i Index of the position in the ticket array.
    * @return Profit of the position if index is valid, -1 otherwise.
    */
   double getProfitByIndex(int i){
      if(i < 0 || i >= ArraySize(ticketArr)){return -1;}
      PositionSelectByTicket(ticketArr[i]);
      return PositionGetDouble(POSITION_PROFIT);
   }
   
   /**
    * @brief Calculates the total accumulated lots from all positions.
    * @return Total accumulated lots from all positions.
    */
   double getAccLots(){
      double accLots = 0;
      for(int i = 0;i<ArraySize(ticketArr);i++){
         PositionSelectByTicket(ticketArr[i]);
         accLots += PositionGetDouble(POSITION_VOLUME);
      }
      return accLots;
   }
   
   /**
    * @brief Copies the current ticket array to a destination array.
    * @param dstArr Destination array to copy tickets to.
    * @return Number of tickets copied.
    */
   int getTicketArr(ulong& dstArr[]){
      ArrayResize(dstArr,ArraySize(ticketArr));
      return ArrayCopy(dstArr,ticketArr,0,0);
   }
   
   /**
    * @brief Gets the number of tickets currently in the array.
    * @return Number of tickets in the array.
    */
   int getTicketCount(){
      return ArraySize(ticketArr);
   }
   
   /**
    * @brief Sets the ticket array with a source array.
    * @param srcArr Source array to copy tickets from.
    * @return True if tickets are successfully set, false otherwise.
    */
   bool setTicketArr(ulong& srcArr[]){
      ArrayResize(ticketArr,ArraySize(srcArr));
      return ArrayCopy(ticketArr,srcArr,0,0) >= 0;
   }

   /**
    * @brief Gets the type of trading position managed by this instance.
    * @return Type of trading position.
    */
   long getType(){
      return type;
   }
   
   /**
    * @brief Clears the ticket array.
    *
    * Frees the memory allocated for the ticket array.
    */
   void clearTicketArr(){
      ArrayFree(ticketArr);
   }
   
   /**
    * @brief Gets the status of the instance.
    * @return True if the status is valid, false otherwise.
    */
   bool getStatus(){
      return ArraySize(ticketArr)>=0;
   }
   
   /**
    * @brief Checks if the ticket array is empty.
    * @return True if the ticket array is empty, false otherwise.
    */
   bool isTicketsEmpty(){
      return ArraySize(ticketArr) == 0;
   }
   
   /**
    * @brief Closes all positions represented by the ticket array.
    * @return True if all positions are successfully closed, false otherwise.
    */
   bool closeAllOrders(){
      bool flag = true;
      for(int i=ArraySize(ticketArr)-1 ; i>=0 ; i--){
         PositionSelectByTicket( ticketArr[i] );
         if(!trade.PositionClose(ticketArr[i])){
            flag = false;
         }
      }
      return flag;
   }
   
   /**
    * @brief Closes a specific position by its index in the ticket array.
    * @param i Index of the position in the ticket array.
    * @return True if the position is successfully closed, false otherwise.
    */
   bool closeOrderByIndex(int i){
      if (i<0 || i >= ArraySize(ticketArr)){return false;}
      PositionSelectByTicket( ticketArr[i] );
      if(!trade.PositionClose(ticketArr[i])){
            return false;
      }
      return true;
   }
   
   /**
    * @brief Gets the lot size of the last position in the ticket array.
    * @return Lot size of the last position if there are any positions, 0 otherwise.
    */
   double getLastLot(){
      if(ArraySize(ticketArr)==0){return 0;}
      PositionSelectByTicket(ticketArr[ArraySize(ticketArr)-1]);
      return PositionGetDouble(POSITION_VOLUME);
   }
   
   /**
    * @brief Gets the opening price of the last position in the ticket array.
    * @return Opening price of the last position if there are any positions, 0 otherwise.
    */
   double getLastPrice(){
      if(ArraySize(ticketArr)==0){return 0;}
      PositionSelectByTicket(ticketArr[ArraySize(ticketArr)-1]);
      return PositionGetDouble(POSITION_PRICE_OPEN);
   }
   
   /**
    * @brief Gets the opening time of the last position in the ticket array.
    * @return Opening time of the last position if there are any positions, 0 otherwise.
    */
   datetime getLastOpenTime(){
      if(ArraySize(ticketArr)==0){return 0;}
      PositionSelectByTicket(ticketArr[ArraySize(ticketArr)-1]);
      return PositionGetInteger(POSITION_TIME);
   }

   /**
    * @brief Gets the ticket number of the last position in the ticket array.
    * @return Ticket number of the last position if there are any positions, -1 otherwise.
    */
   ulong getLastTicket(){
      if(ArraySize(ticketArr)<=0){return -1;}
      return ticketArr[ArraySize(ticketArr)-1];
   }
};

VortexPrimeExpert buyObj(POSITION_TYPE_BUY);
VortexPrimeExpert sellObj(POSITION_TYPE_SELL);

CTrade trade;
MqlTick currentTick;

bool buySignal;

bool sellSignal;

int handleSto;
bool stoBuySignal;
bool stoSellSignal;
double stoMainBuffer[];
double stoSignalBuffer[];

int handleRSI;
double rsiBuffer[];
bool rsiBuySignal;
bool rsiSellSignal;

int handleCCI;
double cciBuffer[];
bool cciBuySignal;
bool cciSellSignal;

int handleMACD;
double macdMainBuffer[];
double macdMainTempBuffer[];
double macdSignalBuffer[];
double macdSignalTempBuffer[];
bool macdBuySignal;
bool macdSellSignal;

int handleHardSto;
double hardStoMainBuffer[];
double hardStoSignalBuffer[];
bool hardStoSellSignal;
bool hardStoBuySignal;

ulong buyTicketArr[];
ulong sellTicketArr[];
double buyGridArr[];
double sellGridArr[];

int OnInit(){
   trade.SetExpertMagicNumber(InpMagicnumber);
   
   buySignal = false;
   sellSignal = false;

   handleSto = iStochastic( NULL,PERIOD_H1,InpStoKPeriod,InpStoDPeriod,InpStoSlowing,InpStoMAMethod,InpStoPrice ); 
   ArrayResize(stoMainBuffer,1);
   ArrayResize(stoSignalBuffer,1);
   
   handleRSI = iRSI(NULL,PERIOD_H1,InpRSIMAPeriod,InpRSIAppPrice);
   ArrayResize(rsiBuffer,1);
   
   handleCCI = iCCI(NULL,PERIOD_H1,InpCCIMAPeriod,InpCCIAppPrice);
   ArrayResize(cciBuffer,1);
   
   handleMACD = iMACD(NULL,InpMACDTimeFrame,InpMACDFastPeriod,InpMACDSlowPeriod,InpMACDSignalPeriod,InpMACDAppPrice);
   ArrayResize(macdMainBuffer,1);
   ArrayResize(macdMainTempBuffer,1);
   ArrayResize(macdSignalBuffer,1);
   ArrayResize(macdSignalTempBuffer,1);
   
   handleHardSto = iStochastic(NULL,PERIOD_D1,InpHardStoKPeriod,InpHardStoDPeriod,InpHardStoSlowing,InpHardStoMAMethod,InpHardStoPrice);
   ArrayResize(hardStoMainBuffer,1);
   ArrayResize(hardStoSignalBuffer,1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
}

void OnTick(){
   if(!SymbolInfoTick(Symbol(),currentTick)){Print("Failed to get tick");return;}
   
   if(IsNewBar()){UpdateIndicatorBuffer();SignalByIndicator();}
   
   if(!buyObj.loadTickets()){Print("Failed to load buyObj tickets for checking close order");}
   else{
      if(CloseOrder(buyObj)){
         buyObj.loadTickets();
         updateGridMap(buyObj,buyTicketArr,buyGridArr);
      }
   }
      
   if(!sellObj.loadTickets()){Print("Failed to load sellObj tickets for checking close order");}
   else{
      if(CloseOrder(sellObj)){
         sellObj.loadTickets();
         updateGridMap(sellObj,sellTicketArr,sellGridArr);
      }
   }
   
   if(!buyObj.loadTickets()){Print("Failed to load buyObj tickets");}
   if(!sellObj.loadTickets()){Print("Failed to load sellObj tickets");}

   if(currentTick.ask<=nextOpenPrice(buyObj) && nextOpenTime(buyObj) <= currentTick.time && buySignal && buyObj.getAccLots() + nextOpenLot(buyObj) < InpMaxAccLot/2 ){
      if(trade.Buy(nextOpenLot(buyObj),NULL,currentTick.ask,0,0,NULL)){
         ulong lastOrder = trade.ResultDeal();
         double nextGrid = nextGridStep(buyObj, buyGridArr);
         ArrayResize(buyTicketArr,ArraySize(buyTicketArr)+1);
         ArrayResize(buyGridArr,ArraySize(buyGridArr)+1);
         buyTicketArr[ArraySize(buyTicketArr)-1] = lastOrder;
         buyGridArr[ArraySize(buyGridArr)-1] = nextGrid;
      }
   }
   
   if(currentTick.bid>=nextOpenPrice(sellObj) && nextOpenTime(sellObj) <= currentTick.time && sellSignal && sellObj.getAccLots() + nextOpenLot(sellObj) < InpMaxAccLot/2 ){
      if(trade.Sell(nextOpenLot(sellObj),NULL,currentTick.bid,0,0,NULL)){
         ulong lastOrder = trade.ResultDeal();
         double nextGrid = nextGridStep(sellObj, sellGridArr);
         ArrayResize(sellTicketArr,ArraySize(sellTicketArr)+1);
         ArrayResize(sellGridArr,ArraySize(sellGridArr)+1);
         sellTicketArr[ArraySize(sellTicketArr)-1] = lastOrder;
         sellGridArr[ArraySize(sellGridArr)-1] = nextGrid;
      }
   }

   double lastBuyGrid, lastSellGrid;
   
   lastBuyGrid = (ArraySize(buyGridArr)==0) ? 0 : buyGridArr[ArraySize(buyGridArr)-1];
   lastSellGrid = (ArraySize(sellGridArr)==0) ? 0 : sellGridArr[ArraySize(sellGridArr)-1];

   Comment("Ask: ",NormalizeDouble(currentTick.ask,5)," nextBuyPrice: ",NormalizeDouble(nextOpenPrice(buyObj),2),  " BuyProfit: ",NormalizeDouble(buyObj.getProfit(),2),  " accBuyLot: ",NormalizeDouble(buyObj.getAccLots(),2),
         "\nBid: ",NormalizeDouble(currentTick.bid,5)," nextSellPrice: ",NormalizeDouble(nextOpenPrice(sellObj),2), " SellProfit: ",NormalizeDouble(sellObj.getProfit(),2), " accSellLot: ",NormalizeDouble(sellObj.getAccLots(),2),
         "\nSpread: ",NormalizeDouble(currentTick.ask - currentTick.bid,6),
         "\nlastestBuyLotSize: ",   buyObj.getLastLot(), " lastestBuyGrid: ",    lastBuyGrid,  " lastestBuyTime: ", buyObj.getLastOpenTime(),  " buyStatus: ",buyObj.getStatus(),  " buySignal: ",   buySignal,
         "\nlastestSellLotSize: ",  sellObj.getLastLot()," lastestSellGrid: ",   lastSellGrid, " lastestSellTime: ",sellObj.getLastOpenTime(), " sellStatus", sellObj.getStatus(), " sellSignal: ",  sellSignal
         );
}

/**
 * @brief Calculates the lot size for the next trade based on the last traded lot size.
 * @param bs Reference to the VortexPrimeExpert instance.
 * @return The calculated lot size for the next trade, ensuring it does not exceed the maximum lot size.
 *
 * This function determines the lot size for the next trade. If there is no previous trade (last lot size is zero),
 * it returns the initial lot size. Otherwise, it multiplies the last lot size by a predefined factor and ensures
 * the result does not exceed the maximum allowable lot size.
 */
double nextOpenLot(VortexPrimeExpert& bs){
   double nextLot = (bs.getLastLot()==0) ? InpLotSize : bs.getLastLot()*InpLotMultiply;
   return (nextLot > InpMaxLotSize) ? InpMaxLotSize : NormalizeDouble(nextLot,2);
}

/**
 * @brief Calculates the opening price for the next trade based on the last traded price.
 * @param bs Reference to the VortexPrimeExpert instance.
 * @return The calculated opening price for the next trade.
 *
 * This function determines the opening price for the next trade. It checks the type of the last position (buy or sell)
 * and adjusts the price by a calculated grid step. If there is no previous trade (last price is zero), it uses the
 * current market price (ask or bid) depending on the trade type.
 */
double nextOpenPrice(VortexPrimeExpert& bs){
   double lastOpenPrice = bs.getLastPrice();
   long type = bs.getType();
   if(lastOpenPrice==0){return (type==POSITION_TYPE_BUY) ? currentTick.ask : currentTick.bid;}
   
   double gridStep;
   
   if(type==POSITION_TYPE_BUY){
      gridStep = nextGridStep(bs, buyGridArr);
   }else{
      gridStep = nextGridStep(bs, sellGridArr);
   }
   return (type==POSITION_TYPE_BUY) ? lastOpenPrice - gridStep*Point() : lastOpenPrice + gridStep*Point();
}

/**
 * @brief Updates the grid mapping arrays with current positions.
 * @param bs Reference to the VortexPrimeExpert instance.
 * @param ticketGridArr Array to store updated ticket numbers.
 * @param gridArr Array to store updated grid steps corresponding to the tickets.
 *
 * This function updates the provided arrays with the current tickets and their associated grid steps. It matches
 * the tickets from the VortexPrimeExpert instance with the given ticket array and updates the grid steps accordingly.
 */
void updateGridMap(VortexPrimeExpert& bs, ulong& ticketGridArr[], double& gridArr[]){
   ulong ticketArr[];
   int sizeArr = bs.getTicketArr(ticketArr);
   double newGrid[]; 
   ArrayResize(newGrid,sizeArr);
   for(int i=0;i<ArraySize(ticketGridArr);i++){
      int idx = ArrayBsearch(ticketArr,ticketGridArr[i]);
      if( 0 <= idx && idx < sizeArr && ticketArr[idx] == ticketGridArr[i] ){
         newGrid[idx] = gridArr[i];
      }
   }
   ArrayFree(ticketGridArr);
   ArrayFree(gridArr);
   ArrayCopy(ticketGridArr,ticketArr,0,0);
   ArrayCopy(gridArr,newGrid,0,0);

}

/**
 * @brief Calculates the next grid step size for positioning based on the current grid steps.
 * @param bs Reference to the VortexPrimeExpert instance.
 * @param gridArr Array containing current grid steps.
 * @return The calculated grid step size for the next trade.
 *
 * This function determines the grid step size for the next trade based on the last grid step size. It multiplies
 * the last grid step by a predefined factor, ensuring it does not exceed the maximum allowed grid size.
 */
double nextGridStep(VortexPrimeExpert& bs, double& gridArr[]){
   double lastGrid = (ArraySize(gridArr)==0) ? 0 : gridArr[ArraySize(gridArr)-1];
   if(lastGrid==0){
      lastGrid = InpGridStep;
   }else if(lastGrid*InpGridMultiply > InpMaxGrid){
      lastGrid = InpMaxGrid;
   }else{
      lastGrid = (int)(lastGrid*InpGridMultiply);
   }
   return lastGrid;
}

/**
 * @brief Calculates the next open time for a trade based on the last trade's open time.
 * @param bs Reference to the VortexPrimeExpert instance.
 * @return The calculated next open time for a trade.
 *
 * This function calculates the next open time by adding a predefined period to the open time of the last trade.
 * This ensures that trades are scheduled appropriately based on the specified interval.
 */
datetime nextOpenTime(VortexPrimeExpert& bs){
   return bs.getLastOpenTime() + InpPeriod;
}

/**
 * @brief Closes orders based on the current status and the number of open tickets.
 * @param bs Reference to the VortexPrimeExpert instance.
 * @return True if orders were successfully closed; otherwise, false.
 *
 * This function manages the closing of orders based on the number of open tickets and specific conditions.
 * If the number of open tickets exceeds the maximum allowed (`InpMATicket`), it attempts to reduce the drawdown
 * and then closes the orders using a specific method. If the number of tickets is within the limit, it directly 
 * calls the method to close orders based on the moving average (MA) conditions.
 */
bool CloseOrder(VortexPrimeExpert& bs){
   if(bs.getStatus()){
      if(bs.getTicketCount() > InpMATicket){
         if(CloseOrderReduceDrawdown(bs)){
            CloseOrderMAOpen(bs);
            return true;
         }else{
            return false;
         }
      }else{
         return CloseOrderMAOpen(bs);
      }
   }
   return false;
}

/**
 * @brief Closes orders based on the moving average (MA) conditions and current profit.
 * @param bs Reference to the VortexPrimeExpert instance.
 * @return True if orders were successfully closed; otherwise, false.
 *
 * This function closes all open orders if the total profit meets or exceeds the target profit based on
 * the moving average (MA) conditions. If the profit condition is satisfied and all orders are closed successfully,
 * it logs the result if optimization mode is not enabled. Otherwise, it prints an error message if closing fails.
 */
bool CloseOrderMAOpen(VortexPrimeExpert& bs){
   double profit = bs.getProfit();
   if(profit >= InpTakeProfit*InpLotSize){
      if(bs.closeAllOrders()){
         if(!InpOptimizeMode){Print( "MA type : ",bs.getType()," profit : ",profit );}
         return true;
      }else{
         Print("MA type : ",bs.getType()," fail to close orders");
      }
   }
   return false;
}

/**
 * @brief Closes orders based on the moving average (MA) conditions and reduces the drawdown.
 * @param bs Reference to the VortexPrimeExpert instance.
 * @return True if orders were successfully closed; otherwise, false.
 *
 * This function attempts to reduce the drawdown by closing orders in pairs. It calculates the profit from the
 * first and last orders and compares it with the target profit. If the profit condition is satisfied, it closes
 * the orders and updates the ticket array. If optimization mode is not enabled, it logs the result.
 */
bool CloseOrderReduceDrawdown(VortexPrimeExpert& bs){
   ulong ticketArr[];
   int staticSize = bs.getTicketArr(ticketArr);
   int realSize = bs.getTicketArr(ticketArr);
   if(realSize<=0){
      Print("close RDD : fail to get tickets");
      return false;
   }
   
   for(int i=0;i<(int)(bs.getTicketCount()/2);i++ ){
      if(realSize<=InpMATicket){
         return true;
      }
      double profit = bs.getProfitByIndex(i) + bs.getProfitByIndex(staticSize-1-i);
      if(profit >= InpTakeProfit*InpLotSize*((100+InpPercentTP)/100)){
         realSize -= bs.closeOrderByIndex(i)+bs.closeOrderByIndex(staticSize-1-i);
         if(!InpOptimizeMode){Print("ReduceDD : ",bs.getType()," | profit : ",profit," | profitDD : ",InpTakeProfit*InpLotSize*((100+InpPercentTP)/100));}
      }else{
         break;
      }
   }
   return false;
}

/**
 * @brief Updates the buffers for all technical indicators with the latest values.
 * 
 * This function retrieves the most recent values for various technical indicators and updates their
 * respective buffers. It copies data from the indicator handles into the appropriate buffers, ensuring
 * that the most up-to-date values are used for further calculations or trading signals.
 */
void UpdateIndicatorBuffer(){
   CopyBuffer( handleSto,MAIN_LINE,0,1,stoMainBuffer );
   CopyBuffer( handleSto,SIGNAL_LINE,0,1,stoSignalBuffer );

   CopyBuffer( handleRSI,MAIN_LINE,0,1,rsiBuffer );
   CopyBuffer( handleCCI,MAIN_LINE,0,1,cciBuffer );
   
   ArrayCopy( macdMainTempBuffer,macdMainBuffer );
   ArrayCopy( macdSignalTempBuffer,macdSignalBuffer );
   CopyBuffer( handleMACD,MAIN_LINE,0,1,macdMainBuffer );
   CopyBuffer( handleMACD,SIGNAL_LINE,0,1,macdSignalBuffer );
   
   CopyBuffer( handleHardSto,MAIN_LINE,0,1,hardStoMainBuffer );
   CopyBuffer( handleHardSto,SIGNAL_LINE,0,1,hardStoSignalBuffer );
}

void SignalByIndicator(){
   HardStoSignal();
   StoSignal();
   RSISignal();
   CCISignal();
   MACDSignal();
   buySignal = ( hardStoBuySignal || !InpHardStoActive ) && 
               ( stoBuySignal || !InpStoActive ) && 
               ( rsiBuySignal || !InpRSIActive ) && 
               ( cciBuySignal || !InpCCIActive ) &&
               ( macdBuySignal || !InpMACDActive );
   sellSignal = ( hardStoSellSignal || !InpHardStoActive ) && 
                ( stoSellSignal || !InpStoActive ) && 
                ( rsiSellSignal || !InpRSIActive ) && 
                ( cciSellSignal || !InpCCIActive ) && 
                ( macdSellSignal || !InpMACDActive );
}

/**
 * @brief Evaluates trading signals based on the values of various technical indicators.
 * 
 * This function generates trading signals by calling individual signal generation functions for
 * each technical indicator (Stochastic Oscillator, RSI, CCI, MACD, and Hard Stochastic Oscillator).
 * It then combines the signals from all indicators to determine the overall buy and sell signals.
 * 
 * The final buy and sell signals are determined by checking if the conditions for each indicator 
 * are met and whether the respective indicators are active based on user inputs.
 */
void StoSignal(){
   stoBuySignal = true;
   stoSellSignal = true;
   
   if(stoMainBuffer[0] >= 50 + InpStoLevel || stoSignalBuffer[0] >= 50 + InpStoLevel ){
      stoBuySignal = false;
   }
   else if( stoMainBuffer[0] <= 50 - InpStoLevel || stoSignalBuffer[0] <= 50 - InpStoLevel ){
      stoSellSignal = false;
   }
}

/**
 * @brief Evaluates trading signals based on the values of the MACD indicator.
 * 
 * This function generates trading signals based on the values of the MACD indicator. It compares the
 * main and signal lines of the MACD indicator with the user-defined MACD level to determine buy and sell signals.
 * The buy signal is generated when the main line crosses above the signal line and both lines are below the MACD level.
 * The sell signal is generated when the main line crosses below the signal line and both lines are above the negative MACD level.
 */
void MACDSignal(){
   macdBuySignal = false;
   macdSellSignal = false;
   if( macdMainBuffer[0] < InpMACDLevel && macdSignalBuffer[0] < InpMACDLevel && macdMainTempBuffer[0] <= macdSignalTempBuffer[0] && macdMainBuffer[0] > macdSignalBuffer[0] ){
      macdBuySignal = true;
   }
   else if( macdMainBuffer[0] > -InpMACDLevel && macdSignalBuffer[0] > -InpMACDLevel && macdMainTempBuffer[0] >= macdSignalTempBuffer[0] && macdMainBuffer[0] < macdSignalBuffer[0] ){
      macdSellSignal = true;
   }
}

/**
 * @brief Evaluates trading signals based on the values of the RSI indicator.
 * 
 * This function generates trading signals based on the values of the RSI indicator. It compares the RSI value
 * with the user-defined RSI level to determine buy and sell signals. The buy signal is generated when the RSI value
 * is below the RSI level, while the sell signal is generated when the RSI value is above the negative RSI level.
 */
void RSISignal(){
   rsiBuySignal = true;
   rsiSellSignal = true;
   if(rsiBuffer[0] >= InpRSILevel + 50){
      rsiBuySignal = false;
   }else if(rsiBuffer[0] <= 50 - InpRSILevel){
      rsiSellSignal = false;
   }
}

/**
 * @brief Evaluates trading signals based on the values of the CCI indicator.
 * 
 * This function generates trading signals based on the values of the CCI indicator. It compares the CCI value
 * with the user-defined CCI level to determine buy and sell signals. The buy signal is generated when the CCI value
 * is below the CCI level, while the sell signal is generated when the CCI value is above the negative CCI level.
 */
void HardStoSignal(){
   hardStoBuySignal = true;
   hardStoSellSignal = true;
   if( hardStoMainBuffer[0] >= 50+InpHardStoLevel || hardStoSignalBuffer[0] >= 50+InpHardStoLevel ){
      hardStoBuySignal = false;
   }else if( hardStoMainBuffer[0] <= 50-InpHardStoLevel || hardStoSignalBuffer[0] <= 50-InpHardStoLevel ){
      hardStoSellSignal = false;
   }
}

/**
 * @brief Evaluates trading signals based on the values of the CCI indicator.
 * 
 * This function generates trading signals based on the values of the CCI indicator. It compares the CCI value
 * with the user-defined CCI level to determine buy and sell signals. The buy signal is generated when the CCI value
 * is below the CCI level, while the sell signal is generated when the CCI value is above the negative CCI level.
 */
void CCISignal(){
   cciBuySignal = true;
   cciSellSignal = true;
   if(cciBuffer[0] >= InpCCILevel){
      cciBuySignal = false;
   }else if(cciBuffer[0] <= -InpCCILevel){
      cciSellSignal = false;
   }
}

/**
 * @brief Checks if a new bar has formed on the chart.
 * @return True if a new bar has formed, false otherwise.
 *
 * This function compares the current time with the previous time to determine if a new bar has formed.
 * It updates the previous time if a new bar is detected and returns the result.
 */
bool IsNewBar(){
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol,PERIOD_H1,0);
   if(previousTime!=currentTime){
      previousTime = currentTime;
      return true;
   }
   return false;
}