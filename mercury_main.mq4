//+------------------------------------------------------------------+
//|                                                   Mercury075.mq4 |
//|                                                         T.Makino |
//| 方針：Mercuryはナンピンマーチンで低リスク・ハイリターンを狙うEA。
//|     急峻なトレンド変化時にはエントリーをしないため、含み損を肥大化させずに
//|     安定着地できる使用。7.3をベースに不具合等を修正。
//|     
//| 結果：7.3の結果
//| 　　　 22/1/3～22/10/31：最大含み損-13,943ドル(-190万円),月利104万円(54.6%)
//| 　　　 22/1/3～22/12/23:最大含み損-48,703ドル(-662万円),月利117万円(17.6%)
//|      21/1/4～22/12/23:最大含み損-69,361ドル(-943万円),月利112万円(11.9%)
//| 　　　 
//+------------------------------------------------------------------+

#include <stdlib.mqh>

#property copyright "T.Makino"
#property link      ""
#property version   "1.00"
#property strict

// enum列挙型宣言
enum ENUM_MA_STATE {
   MAC_NONE = 0,
   MAC_UP_CHANGE,
   MAC_DOWN_CHANGE,
   MAC_UP_CONT,
   MAC_DOWN_CONT,
   MAC_MID_CROSS_UP,
   MAC_MID_CROSS_DOWN,
   MAC_LONG_CROSS_UP,
   MAC_LONG_CROSS_DOWN,
   MAC_TREND_UP,
   MAC_TREND_DOWN,
   MAC_SM_UP_CHANGE,
   MAC_SM_DOWN_CHANGE,
   MAC_ML_UP_CHANGE,
   MAC_ML_DOWN_CHANGE
};

enum ENUM_MA_MODE {
   MAC_SHORT_MIDDLE = 0,
   MAC_MIDDLE_LONG
};

enum ENUM_TREND {
   TREND_NONE = 0,
   TREND_UP_CHANGE,
   TREND_DOWN_CHANGE,
   TREND_KEEP_UP3,
   TREND_KEEP_UP5,
   TREND_KEEP_DOWN3,    //  5
   TREND_KEEP_DOWN5,
   TREND_5IN7_UP,       //  7
   TREND_5IN7_DOWN,     //  8
   TREND_UP_INCREASE,
   TREND_DOWN_INCREASE, // 10
   TREND_DECREASE,
   TREND_ZG_UP,
   TREND_ZG_DOWN,
   TREND_ZG_HIGH,
   TREND_ZG_LOW,
   TREND_UP_RELIABLE,
   TREND_DOWN_RELIABLE,
   TREND_UP_SUDDEN,
   TREND_DOWN_SUDDEN
};

enum ENUM_POSITION_STATE {
   POS_NUTRAL = 0,
   POS_OVER_LIMIT,
   POS_OVER_STOP
};

enum ENUM_PL_STATE {
   PL_NONE = 0,
   PL_OVER_PROFIT,
   PL_HAVING_LOSS
};

enum ENUM_ENTRY_STOP {
   ENTRY_CONTINUE = 0,  // エントリー続行
   ENTRY_STOP           // エントリー停止
};

enum ENUM_ORDER_MODE {
   MODE_NORMAL = 0,     // 通常動作モード
   MODE_NEW_ENTRY_STOP, // 新規エントリー停止(NanpinEntryとCLOSEあり)
   MODE_ALL_ENTRY_STOP,    // ナンピンエントリー停止(CLOSEあり)
   MODE_EA_IDLE         // アイドル状態
};

enum ENUM_ENTRY_TURN {
   TURN_NONE = 0,
   TURN_BUY_ENTRY,
   TURN_SELL_ENTRY
};

enum ENUM_ENTRY_MODE {
   ENTRY_NONE   = 0,
   ENTRY_MODE_0,
   ENTRY_MODE_1,
   ENTRY_MODE_2,
   ENTRY_MODE_3
};

enum ENUM_CLOSE_MODE {
   CLOSE_ALL   = 0,
   CLOSE_BUY,
   CLOSE_SELL,
   CLOSE_BUY_BY_POS,
   CLOSE_SELL_BY_POS
};

enum ENUM_EA_MODE {
   MODE_EA_PAUSE = 0, // PAUSE
   MODE_NANPIN_FWD, // FWD
   MODE_NANPIN_REV, // REV
   MODE_HALF_LS     // 1/2LC
};

// マクロ定義
#define  OBJ_HEAD          (__FILE__ + "_")  // オブジェクトヘッダ名
#define  NAME4LOG          ("■" + __FUNCTION__)  // ログの先頭に出すヘッダ
#define  MAGIC_NO          10441044       // EA識別用マジックナンバー
#define  NUM_OF_TREND      7     // トレンド情報の取得数
#define  MA_PERIOD_SHORT   5     // MA短期の期間
#define  MA_PERIOD_MIDDLE  50    // 基準MA期間
#define  MA_PERIOD_LONG    300    // MA長期の期間
#define  NUM_OF_INHIBIT_PERIOD   4 // 全クローズ後にエントリーを禁止する期間
#define  JUDGE_TREND_WIDTH       5   // 5in7, KEEP5のTREND判定に使用
#define  NUM_OF_NPN_LEVEL  100   // ナンピンレベルの数：WIDTHと掛けると最大エントリー幅になる
#define  NUM_OF_SUDDEN_HISTORY 3 // SUDDEN記録バッファサイズ

#define  SWITCH_SUDDEN_MODE  1     // SUDDEN検知による休止機能の切替(0:無効、1:有効)
#define  SUDDEN_CHANGE_WIDTH 20   // 急激な変化の閾値
#define  EA_RELIABLE_WIDTH   43   // 確実な値幅
#define  EMERGENCY_IDLE_PERIOD 60*24  // 緊急停止(アイドル)の期間
#define  SWITCH_SCALP_MODE 0       // Scalp モードスイッチ
#define  NUM_OF_SCALP_POS  1       // Scalp の数

// 外部パラメータ設定
input int     EA_Pause          = 0;      // EAを一時停止（0:実行、1:一時停止）
input double  _MinLot           = 0.02;   // 最小ロット(0.01単位)
input double  EA_PROFIT         = 10;     // Profit(pips)
input double  EA_PROFIT_SINGLE  = 6.0;     // Profit for Single(pips)
//input double  EA_LOSSCUT        = 7;      // LossCut幅(pips)
double  EA_LOSSCUT        = 7;      // LossCut幅(pips)
// 【参考】ナンピンは　BEYOND-GOではx1.8/800pips
input double  EA_NANPIN_WIDTH   = 16*4;    // ナンピン幅(pips)
input double  EA_NANPIN_WIDTH_S = 16;    // 小さい時の間隔(pips)
input double  EA_NANPIN_RATIO   = 1.6;    // 2回目以降のナンピン幅比(pips)
input double  EA_NANPIN_NARROW_MAX = 20;   // Widthを狭くする最大エントリー数
input int     NUM_OF_POS           = 20;   // 最大ポジション数（BUY/SELLごと)
input ENUM_ORDER_MODE EA_OrderMode = MODE_NORMAL;
//input ENUM_EA_MODE EA_Mode = MODE_NANPIN_FWD; // EAモード(PAUSE:停止,FWD:普通のナンピン,REV:逆方向ナンピン)
ENUM_EA_MODE EA_Mode = MODE_NANPIN_FWD; // EAモード(PAUSE:停止,FWD:普通のナンピン,REV:逆方向ナンピン)

// NANPIN_REV 設定
input double  EA_REV_PROFIT         = 30;   // Profit(pips)
input double  EA_ENTRY_MARGIN       = 150;   // ボーダー越え後にエントリーを許可する幅
input double  EA_REV_NANPIN_WIDTH   = 15;   // ナンピン幅(pips)

double  ProfitNormal;   // Profit(pips)
double  ProfitSingle;   // Profit for Single(pips)
double  LosscutRate;    // LossCut幅(pips)
double  NanpinWidth;    // 初回ナンピン幅(pips)
double  NanpinWidth_S;  // 小さい時の間隔(pips)
double  NanpinWidth_BuyDyna; // ナンピン幅を変える
double  NanpinWidth_SellDyna; // ナンピン幅を変える
double  JudgeTrendWidth;  // KEEP5の判定用
double  ReliableWidth;  // 確実な値幅
double  SuddenChangeWidth;  // 確実な値幅
double  EntryMargin;    // ボーダー越え後にエントリーを許可する幅

// MODE FWD/REV 切替日時
bool  flagNanpinModeByTime     = False;
bool  flagNanpinModeByPosition = False;
//bool  enableModeChngByTime = True;
bool  enableModeChngByTime = False;
// ModeChngByTime の設定時刻（to REV）
const datetime time_to_rev1 = D'2022.11.10 12:30';
const datetime time_to_rev2 = D'2022.12.13 15:20';
const datetime time_to_rev3 = D'2022.12.14 20:50';
// ModeChngByTime の設定時刻（to FWD）
const datetime time_to_fwd1 = D'2022.11.11 01:00';
const datetime time_to_fwd2 = D'2022.12.14 04:00';
const datetime time_to_fwd3 = D'2022.12.15 09:00';
const int      RevOneshotPeriod = 60*6;

// 静的グローバル変数
int  numOfBuyPosition = 0, numOfSellPosition = 0;   // ポジション数
int  prevNumOfBuyPosition = 0, prevNumOfSellPosition = 0;   // ポジション数
double BuyEntryRateMin = 0, SellEntryRateMax = 0;   // ポジションのEntryRateの最安値・最高値を保持
double BuyEntryRateMax = 0, SellEntryRateMin = 0;   // ポジションのEntryRateの最安値・最高値を保持
double lastBuyEntryRate = 0, lastSellEntryRate = 0; // 最後のEntryRateを保持
double currBuyLossTotal = 0, currSellLossTotal = 0;   // 含み損
double currBuyAveRate   = 0, currSellAveRate   = 0;   // Lot加重平均レート
double maxBuyLossTotal = 0, maxSellLossTotal = 0, maxLossTotal = 0;     // 含み損推移記録用
double BuyTotalLots = 0, SellTotalLots = 0;         // ポジションの総ロット数
double infoMinLot = 0, infoMaxLot = 0;
//double _MinLot           = 0.01;    // 最小ロット(0.01単位)
ENUM_ENTRY_TURN   NextEntryTurn = TURN_NONE;   // ナンピン時に買い/売りを交互にさせる（ノーポジション=0, 買い=1, 売り=2）
ENUM_ENTRY_MODE   BuyEntryMode = ENTRY_NONE, SellEntryMode = ENTRY_NONE;
double CurPerPips;  // 1Pipsあたり各国通貨単位に変換する係数
int GoldRatio = 1;
double currAsk, currBid;
ENUM_EA_MODE EA_NanpinMode, OneshotNanpinMode = MODE_NANPIN_FWD;
int countNanpinModeRev = 0;
ENUM_ORDER_MODE OrderModeBuy = MODE_NORMAL, OrderModeSell = MODE_NORMAL;
int  countEaBuyIdle, countEaSellIdle;
double peekHoldHigh, peekHoldLow, peekHoldHighBase, peekHoldLowBase;
int   modeScalpBuy = 0, modeScalpSell = 0;
int   countBuyNanpinPeriod = 0, countSellNanpinPeriod = 0;  // ナンピンの起点となるエントリーからのperiod数
ENUM_TREND  arraySuddenTrend[NUM_OF_SUDDEN_HISTORY];
int tickCount;             // 時刻代わりにOnInitからのtickをcount。


//型宣言
struct stPositionInfo {  // ポジション情報構造体型
   bool     flagEnable;    // Enable=True, Unable=False
   int      ticket_no;     // チケットNo
   int      entry_dir;     // エントリーオーダータイプ
   double   entry_price;   // 約定金額
   double   entry_lot;     // ロット数
   double   set_limit;     // リミットレート：約定設定レート
   double   set_stop;      // ストップレート：損切設定レート
   int      entry_tick;    // エントリー時刻をtickCountで記録
};

struct stTrendInfo {      // 直近のトレンド情報（ index = 0 が確定済の最新）
   double   dataOpen[NUM_OF_TREND];
   double   dataClose[NUM_OF_TREND];
   double   dataHigh[NUM_OF_TREND];
   double   dataLow[NUM_OF_TREND];
   double   dataMaShort[NUM_OF_TREND];
   double   dataMaMiddle[NUM_OF_TREND];
   double   dataMaLong[NUM_OF_TREND];
   double   CandleSize[NUM_OF_TREND];    // 1:陽線、-1：陰線： 0：同値
};

struct stEntryInfo {    // EA_EntryOrder() に渡す情報
   int      order_type;    // OP_BUY / OP_SELL
   double   order_lot;     // Lot数：最小ロットの場合は _MinLot
   double   order_rate;    // 通常は Ask / Bid ( BUY の時 ASK )
   int      splippage;     // スプリッページ：価格ズレ許容範囲(単位0.1pips)
   double   order_stop_rate;  // ストップレート(設定しない時は 0)
   double   order_limit_rate; // リミットレート(設定しない時は 0)
   string   order_comment;    // オーダーコメント 
   int      magic_no;         // マジックナンバー
   datetime order_expire;     // ポジションの有効期限を設定(設定しない時は 0)
   color    arrow_color;      // チャート上のポジションの色
};

// グローバル変数
stTrendInfo   CurrTrendInfo;
stEntryInfo ParamEntryInfo;
stPositionInfo  BuyPositionInfo[], SellPositionInfo[];    // → 動的配列にする為にOnInitでサイズを指定

// ZigZag用設定
#define  ZIG_NUM     10
input int E_Depth       = 12;
input int E_Deviation   = 5;
input int E_Backstep    = 3;
double ZigTop[ZIG_NUM];     //ジグザグのTopホールド用
double ZigBottom[ZIG_NUM];  //ジグザグのBottomホールド用
int TopPoint;
int BottomPoint;


//+------------------------------------------------------------------+
//| OnInit(初期化)イベント
//+------------------------------------------------------------------+
int OnInit()
{
   if (IsDemo() == false) {
      Print("デモ口座でのみ動作します");
      return INIT_FAILED;        // 処理終了
   }
   
   int coe = 1;                                    // 2,4桁表示業者の場合の係数は「1」
   string tmpSymbol = Symbol();

   if(_Digits == 3 || _Digits == 5) {              // 3,5桁表示業者の場合の係数は「10」
       coe = 10;
   }
   CurPerPips = _Point * coe;                    // 1Pipsあたり各国通貨単位に変換する係数
   
   if ( tmpSymbol == "GOLD" || tmpSymbol == "GOLDmicro" ) {
      GoldRatio = 10;
   }
   
   infoMinLot = MarketInfo(Symbol(),MODE_MINLOT);
   infoMaxLot = MarketInfo(Symbol(),MODE_MAXLOT);

   printf("[ConvertParameter] %s coe=%d, CurPerPips=%f, GoldRate=%d, MaxLot=%f, MinLot=%f",
           tmpSymbol, coe, CurPerPips, GoldRatio, infoMaxLot, infoMinLot );
//   _MinLot  = MarketInfo( Symbol(), MODE_MINLOT );    // 最小ロットを取得

   printf("ProfitNormal=%f, ProfitSingle=%f, LosscutRate=%f, NanpinWidth=%f, NanpinWidth_S=%f",
      ProfitNormal,ProfitSingle,LosscutRate,NanpinWidth,NanpinWidth_S);

   // 動的配列のサイズ指定
   ArrayResize( BuyPositionInfo, NUM_OF_POS);
   ArrayResize( SellPositionInfo, NUM_OF_POS);
   
	// 構造体データを初期化
	for ( int i = 0; i < NUM_OF_POS; i++ ) {
   	InitPositionInfo ( BuyPositionInfo[i] );
   	InitPositionInfo ( SellPositionInfo[i] );
	}
	InitEntryInfo ( ParamEntryInfo );
   InitSuddenRecentTrend();
	
   Print("OnInit() Succeeded");
	return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit(アンロード)イベント
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if ( IsTesting() == false ){
      ObjectsDeleteAll(0, OBJ_HEAD);   // 追加したオブジェクトを全削除
   }
}

//+------------------------------------------------------------------+
//| tick受信イベント
//| EA専用のイベント関数
//+------------------------------------------------------------------+
void OnTick()
{
   TaskPeriod();        // ローソク足確定時の処理
//   TaskSetMinPeriod();  // 指定時間足確定時の処理
}

//+------------------------------------------------------------------+
//| ローソク足確定時の処理
//+------------------------------------------------------------------+
void TaskPeriod() {
   static    datetime s_lasttime;             // 最後に記録した時間軸時間
   static int  countTrendUp, countTrendDown;    // ナンピンエントリーを間引く
   static int  countAfterClose;               // クローズ後のPeriod回数
   static ENUM_EA_MODE  currNanpinMode, prevNanpinMode;
   static bool oneShotDynaBuy = false, oneShotDynaSell = false;
   static double oneShotBuyStartRate, oneShotSellStartRate;
   static double baseRateOfBuyNanpin = 0, baseRateOfSellNanpin = 0;
   static ENUM_TREND trend_sudden, trend_sudden_prev;
   static int countSuddenUp, countSuddenDown;

   ENUM_TREND  trend_recent_sudden;

   datetime temptime = iTime( Symbol(), Period() ,0 );  // 現在の時間軸の時間取得
   
   if ( temptime == s_lasttime || EA_OrderMode == MODE_EA_IDLE ) {
     return;                                         // 処理終了
   } else {
      // Period()が切り替わった。Periodでカウントアップする処理はここに入れる
   }
   s_lasttime = temptime;                              // 最後に記録した時間軸時間を保存
   tickCount++;
   //printf( "[%s]ローソク足確定%s" , NAME4LOG , TimeToStr( Time[0] ) );

   // 含み損が出た場合、同じ方向のエントリーを入れるNANPINモード
   // 設定変更を取れるように毎回更新する
   EA_NanpinMode = EA_Mode;

   if ( enableModeChngByTime ) {
      if ( temptime == time_to_rev1 ||
           temptime == time_to_rev2 ||
           temptime == time_to_rev3 ) {
         currNanpinMode = MODE_NANPIN_REV;
         printf("MODE_CHANGE to NANPIN_REV");
      } else if ( temptime == time_to_fwd1 ||
                  temptime == time_to_fwd2 ||
                  temptime == time_to_fwd3 ) {
         currNanpinMode = MODE_NANPIN_FWD;
         printf("MODE_CHANGE to NANPIN_FWD");
      }
      // 時間設定でモードを上書き変更する
      if ( currNanpinMode == MODE_NANPIN_REV || currNanpinMode == MODE_NANPIN_FWD ) {
         EA_NanpinMode = currNanpinMode;
      }
   }

   // 設定値を取得
   ProfitNormal    = EA_PROFIT         * CurPerPips * GoldRatio;
   ProfitSingle    = EA_PROFIT_SINGLE  * CurPerPips * GoldRatio;
   LosscutRate     = EA_LOSSCUT        * CurPerPips * GoldRatio;
   NanpinWidth     = EA_NANPIN_WIDTH   * CurPerPips * GoldRatio;
   NanpinWidth_S   = EA_NANPIN_WIDTH_S * CurPerPips * GoldRatio;
   JudgeTrendWidth = JUDGE_TREND_WIDTH * CurPerPips * GoldRatio;
   ReliableWidth   = EA_RELIABLE_WIDTH * CurPerPips * GoldRatio;
   EntryMargin     = EA_ENTRY_MARGIN   * CurPerPips * GoldRatio;
   SuddenChangeWidth = SUDDEN_CHANGE_WIDTH * CurPerPips * GoldRatio;
   if ( EA_NanpinMode == MODE_NANPIN_REV ) {
      // REV モード時の設定を上書く
      ProfitNormal    = EA_REV_PROFIT         * CurPerPips * GoldRatio;
      NanpinWidth     = EA_REV_NANPIN_WIDTH   * CurPerPips * GoldRatio;
   }
   if ( NanpinWidth_BuyDyna == 0 ) {
      NanpinWidth_BuyDyna  = NanpinWidth_S;
   }
   if ( NanpinWidth_SellDyna == 0 ) {
      NanpinWidth_SellDyna = NanpinWidth_S;
   }

   // インジケータを確認
   int ret_value;
//   bool ret_ZigZag;
//   ENUM_TREND trend_zigzag, trend_zg_highlow;
   ENUM_TREND curr_Trend, trend_power, trend_keep3, trend_keep5, trend_5in7;
   ENUM_TREND trend_reliable;
   ENUM_POSITION_STATE retState = POS_NUTRAL;
   ENUM_MA_STATE ma_sm_cross, ma_cross_Mid, ma_trend, ma_cross_Long;
   bool NoPositionEntry = False;
   int  numOfBuyNanpinLevel = 0, numOfSellNanpinLevel = 0;

   //　トレンド情報を取得
//   ret_ZigZag  = GetZigZagInfo();
   ret_value   = GetTrendInfo( CurrTrendInfo );
   curr_Trend  = CheckTrendChange( CurrTrendInfo );
   trend_keep3 = CheckTrendKeep3( CurrTrendInfo );
   trend_keep5 = CheckTrendKeep5( CurrTrendInfo );
   trend_power = CheckTrendPower( CurrTrendInfo );
   trend_5in7  = CheckTrend5in7( CurrTrendInfo );
   ma_sm_cross = CheckMaCross( CurrTrendInfo, MAC_SHORT_MIDDLE );
   ma_cross_Mid  = CheckMaMidCross( CurrTrendInfo );
   ma_cross_Long = CheckMaLongCross( CurrTrendInfo );
   ma_trend    = CheckMATrend( CurrTrendInfo );
   trend_reliable = CheckTrendReliable( CurrTrendInfo );
   trend_sudden_prev = trend_sudden;
   trend_sudden = CheckSuddenTrend();
//   trend_zigzag = CheckZigzagTrend();
//   trend_zg_hhlow = CheckZigzagHighLow();

   // 含み損の確認
   bool flagBuyEntry = False, flagSellEntry = False;

   // 初期化処理
   ENUM_PL_STATE retPLState = PL_NONE;
   ENUM_PL_STATE retPLStateBuy = PL_NONE, retPLStateSell = PL_NONE;
   currBuyLossTotal = 0;   currSellLossTotal = 0;
   currBuyAveRate   = 0;   currSellAveRate   = 0;
   BuyEntryRateMax  = 0;   BuyEntryRateMin   = 0;
   SellEntryRateMax = 0;   SellEntryRateMin  = 0;
   BuyTotalLots     = 0;   SellTotalLots     = 0;
   BuyEntryMode = ENTRY_NONE; SellEntryMode = ENTRY_NONE;
   currAsk = Ask; currBid = Bid;
   // エントリー変数を初期化
   InitEntryInfo( ParamEntryInfo );
   
   // 現在のポジションから統計情報を更新
   GetPositionStatInfo();
	// 全含み損
   retPLStateBuy  = CheckPLState( currBuyLossTotal );
   retPLStateSell = CheckPLState( currSellLossTotal );
   retPLState     = CheckPLState( currBuyLossTotal + currSellLossTotal );

   // ナンピンの起点となるエントリーからのPeriod数をカウント
   if ( numOfBuyPosition > 0 ) {
      countBuyNanpinPeriod++;
   }
   if ( numOfSellPosition > 0) {
      countSellNanpinPeriod++;
   }
   
   //+------------------------------------------------------------------+
   //|   SUDDENトレンド回避処理
   //+------------------------------------------------------------------+

   // 指標等による急激な変化を検知して IDLE モードに移行
   if ( numOfSellPosition > 0 && 
       ( trend_sudden == TREND_UP_SUDDEN || trend_reliable == TREND_UP_RELIABLE ) ) {
      countEaSellIdle = EMERGENCY_IDLE_PERIOD;
      peekHoldHigh = CurrTrendInfo.dataClose[0];
      if ( peekHoldHighBase == 0 ) {
         peekHoldHighBase = CurrTrendInfo.dataOpen[0];
      }
      baseRateOfSellNanpin = CurrTrendInfo.dataClose[0];
      countSuddenUp++;
      oneShotDynaSell = True;
      SetNewSuddenTrend( TREND_UP_SUDDEN );
      printf("trend_sudden == TREND_UP_SUDDEN");
      SetNewSuddenTrend( TREND_UP_SUDDEN );
   } else if ( numOfBuyPosition > 0 && 
              ( trend_sudden == TREND_DOWN_SUDDEN || trend_reliable == TREND_DOWN_RELIABLE ) ) {
      countEaBuyIdle  = EMERGENCY_IDLE_PERIOD;
      peekHoldLow  = CurrTrendInfo.dataClose[0];
      if ( peekHoldLowBase == 0 ) {
         peekHoldLowBase = CurrTrendInfo.dataOpen[0];
      }
      baseRateOfBuyNanpin = CurrTrendInfo.dataClose[0];
      countSuddenDown++;
      oneShotDynaBuy = True;
      SetNewSuddenTrend( TREND_DOWN_SUDDEN );
      printf("trend_sudden == TREND_DOWN_SUDDEN");
   }
   
   trend_recent_sudden = CheckSuddenRecentTrend();
   
   // 指定期間内にナンピンが進んだ場合、ナンピン幅を大きくする
//   if ( CheckNanpinEntryTime( 2, OP_BUY ) ) {
   if ( countBuyNanpinPeriod <= 20 && numOfBuyPosition >= 2 ){
      oneShotDynaBuy = True;
      oneShotBuyStartRate = lastBuyEntryRate;
      printf("oneShotDynaBuy = True");
   }
//   if ( CheckNanpinEntryTime( 2, OP_SELL ) ) {
   if ( countSellNanpinPeriod <= 20 && numOfSellPosition >= 2 ) {
      oneShotDynaSell = True;
      oneShotSellStartRate = lastSellEntryRate;
      printf("oneShotDynaSell = True");
   }
   
   // ピークホールド
   if ( peekHoldHigh != 0 && CurrTrendInfo.dataClose[0] > peekHoldHigh ) {
      peekHoldHigh = CurrTrendInfo.dataClose[0];
   }
   if ( peekHoldLow  != 0 && CurrTrendInfo.dataClose[0] < peekHoldLow ) {
      peekHoldLow  = CurrTrendInfo.dataClose[0];
   }
   
   // 戻り率により IDLE モード解除
   if ( ( peekHoldLow > 0 && ( currAsk > ( peekHoldLow + peekHoldLowBase ) / 2 ) ) ||
        ( peekHoldLowBase > 0 && CurrTrendInfo.dataClose[0] > peekHoldLowBase ) ||
        ( oneShotBuyStartRate > 0 && CurrTrendInfo.dataClose[0] > oneShotBuyStartRate ) ||
          ma_cross_Long == MAC_LONG_CROSS_UP ||
        ( countSuddenDown > NUM_OF_SUDDEN_HISTORY / 2 && trend_recent_sudden == TREND_UP_SUDDEN ) ||
        ( CurrTrendInfo.dataOpen[0] > CurrTrendInfo.dataMaLong[0] && trend_sudden == TREND_UP_SUDDEN ) ) {
      countEaBuyIdle = 0;
      baseRateOfBuyNanpin = lastBuyEntryRate;
      peekHoldLowBase = 0;
//      oneShotDynaBuy = False;
//      oneShotBuyStartRate = 0;
      printf("BUY IDLE MODE OFF:peekHoldLow=%f",peekHoldLow);
   }
   if ( ( peekHoldHigh > 0 && ( currBid < ( peekHoldHigh + peekHoldHighBase ) / 2 ) ) || 
        ( peekHoldHighBase > 0 && CurrTrendInfo.dataClose[0] < peekHoldHighBase ) ||
        ( oneShotSellStartRate > 0 && CurrTrendInfo.dataClose[0] < oneShotSellStartRate ) ||
          ma_cross_Long == MAC_LONG_CROSS_DOWN ||
        ( countSuddenUp > NUM_OF_SUDDEN_HISTORY / 2 && trend_recent_sudden == TREND_DOWN_SUDDEN ) ||
        ( CurrTrendInfo.dataOpen[0] < CurrTrendInfo.dataMaLong[0] && trend_sudden == TREND_DOWN_SUDDEN ) ) {
      countEaSellIdle = 0;
      baseRateOfSellNanpin = lastSellEntryRate;
      peekHoldHighBase = 0;
//      oneShotDynaSell = False;
//      oneShotSellStartRate = 0;
      printf("SELL IDLE MODE OFF:peekHoldHigh=%f,peekHoldHighBase=%f,oneShotSellStartRate=%f,countSudden=%d",
            peekHoldHigh,peekHoldHighBase,oneShotSellStartRate,countSuddenDown+countSuddenUp);
   }
   
   // ナンピンREVモード移行時の処理
   if ( enableModeChngByTime ) {
      if ( prevNanpinMode != MODE_NANPIN_REV &&
           currNanpinMode == MODE_NANPIN_REV ) {
         if ( BuyTotalLots >= SellTotalLots ) {
            NextEntryTurn = TURN_SELL_ENTRY;
         } else if ( BuyTotalLots < SellTotalLots ) {
            NextEntryTurn = TURN_BUY_ENTRY;
         }   
      }
      prevNanpinMode = currNanpinMode;
   }
   
   //+------------------------------------------------------------------+
   //|   クローズ処理
   //+------------------------------------------------------------------+

   // 利確判定 BUY
   if ( retPLStateBuy != PL_HAVING_LOSS && numOfBuyPosition != 0 ) {
      int ret_NumOfClose;
      if (( numOfBuyPosition >  2 && currBid > currBuyAveRate + ProfitNormal ) ||
          ( numOfBuyPosition <= 2 && currBid > currBuyAveRate + ProfitSingle ) ) {
         ret_NumOfClose = RequestCloseAll( CLOSE_BUY );
         oneShotDynaBuy = False;
      } else if ( modeScalpBuy > 0 ) {
         ret_NumOfClose = RequestCloseAll( CLOSE_BUY_BY_POS );
         modeScalpBuy -= ret_NumOfClose;
         oneShotDynaBuy = False;
         printf("TP BUY:modeScalpBuy, numOfScalp=%d", modeScalpBuy );
      } else{
         retPLStateBuy = PL_NONE;
      }
   }
   // 利確判定 SELL
   if ( retPLStateSell != PL_HAVING_LOSS && numOfSellPosition != 0 ) {
      int ret_NumOfClose;
      if (( numOfSellPosition >  2 && currAsk < currSellAveRate - ProfitNormal ) ||
          ( numOfSellPosition <= 2 && currAsk < currSellAveRate - ProfitSingle ) ) {
         retPLStateSell = PL_OVER_PROFIT;
         ret_NumOfClose = RequestCloseAll( CLOSE_SELL );
         oneShotDynaSell = False;
      } else if ( modeScalpSell > 0 ) {
         ret_NumOfClose = RequestCloseAll( CLOSE_SELL_BY_POS );
         modeScalpSell -= ret_NumOfClose;
         oneShotDynaSell = False;
         printf("TP SELL:modeScalpSell, numOfScalp=%d", modeScalpSell );
      } else {
         retPLStateSell = PL_NONE;
      }
   }
   
   if ( flagNanpinModeByPosition &&
       ( trend_reliable == TREND_UP_RELIABLE || trend_reliable == TREND_DOWN_RELIABLE )) {
      OneshotNanpinMode = MODE_NANPIN_REV;
      countNanpinModeRev = 0;
      printf("Reliable trend occurred, turn to Nanpin REV Mode" );
   } 
   
   // OneshotNanpinMode がREVで指定時間経過してクローズできていない場合、
   // BUY/SELL片一方が利確できる状態なら、FWDに戻して利確させる。
   if ( OneshotNanpinMode == MODE_NANPIN_REV ) {
      if ( countNanpinModeRev++ >= RevOneshotPeriod &&
           ( retPLStateBuy == PL_OVER_PROFIT || retPLStateSell == PL_OVER_PROFIT )) {
         OneshotNanpinMode = MODE_NANPIN_FWD;
         printf("4 Hours Passed from OneshotNanpinMode:REV, turn back to FWD Mode" );
      }
   } else {
      countNanpinModeRev = 0;
   }
     
   // データ集計用
 	printf("[%d]BuyLots,%f,currBuyLoss,%f,SellLots,%f,currSellLoss,%f,currLoss,%f,maxLoss,%f,countSuddenDown,%d,countSuddenUp,%d",
   	      OneshotNanpinMode,BuyTotalLots,currBuyLossTotal,SellTotalLots,currSellLossTotal,
   	      currBuyLossTotal+currSellLossTotal,maxLossTotal,countSuddenDown,countSuddenUp );


   if ( EA_NanpinMode == MODE_NANPIN_FWD && OneshotNanpinMode == MODE_NANPIN_FWD ) {
      // NANPIN_FWD : 含み損が出た場合、同じ方向のエントリーを入れる
//      printf("MODE_FWD");
      
   //+------------------------------------------------------------------+
   //|   エントリー処理  LONG(BUY)
   //+------------------------------------------------------------------+
   
      if ( numOfBuyPosition == 0 && EA_OrderMode != MODE_NEW_ENTRY_STOP ) {
         // ポジションがない状態からの初回のエントリー処理
	      // 上げトレンドを検知 → エントリー
	      BuyEntryMode = ENTRY_MODE_0;
	      countSuddenDown = 0;
         peekHoldLow = 0;
         peekHoldLowBase = 0;
         oneShotBuyStartRate = 0;
      } else {
         // 2回目以降の処理
         if ( retPLStateBuy == PL_HAVING_LOSS && countEaBuyIdle == 0 ) {
            // 含み損がある場合
            
            // NanpinWidth 設定（oneShot で NanpinWidth を置き換える）
            double tmpNanpinWidth;
            tmpNanpinWidth = NanpinWidth_BuyDyna;
            if ( oneShotDynaBuy ) {
               NanpinWidth_BuyDyna = NanpinWidth;
            } else if ( numOfBuyPosition >= 9 ) {
               NanpinWidth_BuyDyna = NanpinWidth;
//               NanpinWidth_BuyDyna = NanpinWidth_S * 4;
            } else {
               NanpinWidth_BuyDyna = NanpinWidth_S;
            }
//            printf("NanpinWidth_BuyDyna=%f,lastBuyEntryRate=%f",NanpinWidth_BuyDyna,lastBuyEntryRate);
//            if ( trend_5in7     != TREND_5IN7_DOWN &&
  //               trend_reliable != TREND_DOWN_RELIABLE ) {
               if ( numOfBuyPosition < NUM_OF_POS &&
                    currAsk < baseRateOfBuyNanpin - NanpinWidth_BuyDyna ) {
//               if ( numOfBuyPosition < EA_NANPIN_NARROW_MAX &&
  //                  currAsk < lastBuyEntryRate - NanpinWidth_S &&
    //                currAsk > BuyEntryRateMax - NanpinWidth ) {
             		BuyEntryMode = ENTRY_MODE_1;
            		modeScalpBuy = 0;
                  if ( oneShotDynaBuy ) {
                     NanpinWidth_BuyDyna = tmpNanpinWidth;
                     oneShotDynaBuy = False;
                     oneShotBuyStartRate = 0;
                  }
               } else if ( numOfBuyPosition < NUM_OF_POS &&
                           currAsk < baseRateOfBuyNanpin - NanpinWidth ) {
             		BuyEntryMode = ENTRY_MODE_2;
            		modeScalpBuy = 0;
               }
    //        }

            peekHoldLow = 0;

         } else if ( countEaBuyIdle == 0 && SWITCH_SCALP_MODE ) {
//            if ( trend_keep5 == TREND_KEEP_UP5 ) {
            if ( trend_5in7 == TREND_5IN7_UP ) {
               if ( numOfBuyPosition < NUM_OF_SCALP_POS ) {
            		BuyEntryMode = ENTRY_MODE_0;
            		modeScalpBuy++;
               }
            } 
         } else {  // else if ( retPLStateBuy == PL_NONE )  と等価
            // PLにまだ変化が出てないので、何もしないで次のPeriodを待つ
         } 
      }
   
   //+------------------------------------------------------------------+
   //|   エントリー処理  SHORT(SELL)
   //+------------------------------------------------------------------+

      if ( numOfSellPosition == 0 && EA_OrderMode != MODE_NEW_ENTRY_STOP ) {
         // ポジションがない状態からの初回のエントリー処理
	      // 下げトレンドを検知
	      SellEntryMode = ENTRY_MODE_0;
	      countSuddenUp = 0;
         peekHoldHigh = 0;
         peekHoldHighBase = 0;
         oneShotSellStartRate = 0;
      } else {
         // 2回目以降の処理
         if ( retPLStateSell == PL_HAVING_LOSS && countEaSellIdle == 0 ) {
            // 含み損がある場合
            
            // NanpinWidth 設定（oneShot で NanpinWidth を置き換える）
            double tmpNanpinWidth;
            tmpNanpinWidth = NanpinWidth_SellDyna;
            if ( oneShotDynaSell ) {
               NanpinWidth_SellDyna = NanpinWidth;
            } else if ( numOfSellPosition >= 9 ) {
               NanpinWidth_SellDyna = NanpinWidth;
//               NanpinWidth_SellDyna = NanpinWidth_S * 4;
            } else {
               NanpinWidth_SellDyna = NanpinWidth_S;
            }
//            printf("NanpinWidth_SellDyna=%f,lastSellEntryRate=%f",NanpinWidth_SellDyna,lastSellEntryRate);
//            if ( trend_5in7     != TREND_5IN7_UP &&
  //               trend_reliable != TREND_UP_RELIABLE ) {
               if ( numOfSellPosition < NUM_OF_POS &&
                    currBid > baseRateOfSellNanpin + NanpinWidth_SellDyna ) {
//               if ( numOfSellPosition < EA_NANPIN_NARROW_MAX &&
  //                  currBid > lastSellEntryRate + NanpinWidth_S &&
    //                currBid < SellEntryRateMin + NanpinWidth ) {
            		SellEntryMode = ENTRY_MODE_1;
            		modeScalpSell = 0;
                  if ( oneShotDynaSell ) {
                     NanpinWidth_SellDyna = tmpNanpinWidth;
                     oneShotDynaSell = False;
                     oneShotSellStartRate = 0;
                  }
               } else if ( numOfSellPosition < NUM_OF_POS &&
                           currBid > baseRateOfSellNanpin + NanpinWidth ) {
             		SellEntryMode = ENTRY_MODE_2;
            		modeScalpSell = 0;
               }
    //        }
            peekHoldHigh = 0;
            
         } else if ( countEaSellIdle == 0 && SWITCH_SCALP_MODE ) {
//            if ( trend_keep5 == TREND_KEEP_DOWN5 ) {
            if ( trend_5in7 == TREND_5IN7_DOWN ) {
               if ( numOfSellPosition < NUM_OF_SCALP_POS ) {
            		SellEntryMode = ENTRY_MODE_0;
            		modeScalpSell++;
               }
            }
         } else {  // else if ( retPLStateSell == PL_NONE )  と等価
            // PLにまだ変化が出てないので、何もしないで次のPeriodを待つ
         }
      }
   }
   else if ( EA_NanpinMode == MODE_NANPIN_REV || OneshotNanpinMode == MODE_NANPIN_REV ){
      // NANPIN_REV : 含み損が出た場合、逆方向のエントリーを入れる
//      printf("MODE_REV");
      
   //+------------------------------------------------------------------+
   //|   メイン処理  逆ナンピンモード
   //+------------------------------------------------------------------+   
   
      if ( numOfBuyPosition == 0 && numOfSellPosition == 0 && 
           EA_OrderMode == MODE_NORMAL && ++countAfterClose > NUM_OF_INHIBIT_PERIOD ) {
         // ポジションがない状態からの初回のエントリー処理
         if ( trend_keep5 == TREND_KEEP_UP5 || trend_5in7 == TREND_5IN7_UP ) {
   	      // 上げトレンドを検知 → エントリー
   	      BuyEntryMode = ENTRY_MODE_0;
         } else if ( trend_keep5 == TREND_KEEP_DOWN5 || trend_5in7 == TREND_5IN7_DOWN ) {
   	      // 下げトレンドを検知
   	      SellEntryMode = ENTRY_MODE_0;
         }
         // パラメータ初期化
         countTrendUp   = 0;
         countTrendDown = 0;
         countAfterClose = 0;
         OneshotNanpinMode = MODE_NANPIN_FWD;
         printf("1st Entry in OneshotNanpinMode:REV, turn back to FWD Mode" );
         
      } else {      
         // 2回目以降の処理
         if ( retPLState == PL_OVER_PROFIT ){
            // 利確ラインを越えてる場合
            // 全ポジションをクローズ
            RequestCloseAll( CLOSE_ALL );
            // パラメータ初期化
            NextEntryTurn = TURN_NONE;
            countTrendUp   = 0;
            countTrendDown = 0;
            OneshotNanpinMode = MODE_NANPIN_FWD;
            printf("Closed All Position in OneshotNanpinMode:REV, turn back to FWD Mode" );

         } else if ( retPLState == PL_HAVING_LOSS ) {
            // 含み損がある場合
            //printf("[HAVING_LOSS]Turn=%d,currAsk-BuyMin =%f,SellMax-currBid=%f,5in7=%d,keep5=%d",
            //      NextEntryTurn,currAsk-BuyEntryRateMin, SellEntryRateMax-currBid,trend_5in7,trend_keep5);

            if ( trend_reliable == TREND_DOWN_RELIABLE ) {
               NextEntryTurn = TURN_SELL_ENTRY;
            } else if ( trend_reliable == TREND_UP_RELIABLE ) {
               NextEntryTurn = TURN_BUY_ENTRY;
            }
            
            if ( NextEntryTurn == TURN_BUY_ENTRY && numOfBuyPosition < NUM_OF_POS &&
                 ( numOfBuyPosition == 0 || currAsk >= lastSellEntryRate + EntryMargin )) {
               // 上げトレンドの場合、買いエントリーを入れる
               if (( numOfBuyPosition == 0 || trend_keep5 == TREND_KEEP_UP5 || 
                     trend_5in7 == TREND_5IN7_UP || trend_reliable == TREND_UP_RELIABLE ) &&
                     countTrendUp++ % 2 != 0 ) {
               //if (( numOfBuyPosition == 0 || trend_keep5 == TREND_KEEP_UP5 ) &&
               //      countTrendUp++ % 2 != 0 ) {
                  BuyEntryMode = ENTRY_MODE_3;
                  printf("MODE_NANPIN_REV:BuyEntryMode = ENTRY_MODE_3");
               }
            } else if ( NextEntryTurn == TURN_SELL_ENTRY && numOfSellPosition < NUM_OF_POS &&
                        ( numOfSellPosition == 0 || currBid <= lastBuyEntryRate - EntryMargin )) {
                 // 下げトレンドの場合、売りエントリーを入れる
               if (( numOfSellPosition == 0 || trend_keep5 == TREND_KEEP_DOWN5 || 
                     trend_5in7 == TREND_5IN7_DOWN || trend_reliable == TREND_DOWN_RELIABLE ) &&
                     countTrendDown++ % 2 != 0 ) {
               //if (( numOfSellPosition == 0 || trend_keep5 == TREND_KEEP_DOWN5 ) &&
               //      countTrendDown++ % 2 != 0 ) {
                  SellEntryMode = ENTRY_MODE_3;
                  printf("MODE_NANPIN_REV:SellEntryMode = ENTRY_MODE_3");
               }
            }
         } else {  // else if ( retPLState == PL_NONE )  と等価
            // PLにまだ変化が出てないので、何もしないで次のPeriodを待つ
         } 
      }
   }
   
//+------------------------------------------------------------------+
//|   エントリー処理  LONG & SHORT
//+------------------------------------------------------------------+

   if ( EA_OrderMode != MODE_ALL_ENTRY_STOP ) {
   
      // 買いエントリー処理
      if ( BuyEntryMode != ENTRY_NONE ) {
         // エントリーフラグが有効
   
   		// 買いのパラメータ設定
   		InitEntryInfo( ParamEntryInfo );    // 初期化
   		ParamEntryInfo.order_type	= OP_BUY;
   		ParamEntryInfo.order_rate	= Ask;
   		ParamEntryInfo.arrow_color	= clrBlue;
   		
         if ( BuyEntryMode == ENTRY_MODE_0 ) {
            // ポジションがない時
            ParamEntryInfo.order_lot	= _MinLot;
         } else if ( BuyEntryMode == ENTRY_MODE_1 ) {
            // ポジション数が少ない時
      		ParamEntryInfo.order_lot
               = _MinLot * MathPow( EA_NANPIN_RATIO, numOfBuyPosition );
//      		   = _MinLot * numOfBuyPosition * EA_NANPIN_RATIO;
//        	     = _MinLot + _MinLot * ( numOfBuyPosition - 1 ) * EA_NANPIN_RATIO;
//      		   = _MinLot * ( BuyEntryRateMax - currAsk ) / NanpinWidth_S * EA_NANPIN_RATIO;
         } else if ( BuyEntryMode == ENTRY_MODE_2 ) {
            // ポジション数が多くなった時
            ParamEntryInfo.order_lot
//               = _MinLot * MathPow( EA_NANPIN_RATIO, numOfBuyPosition );
//      		   = _MinLot * numOfBuyPosition * EA_NANPIN_RATIO;
            	= BuyTotalLots + _MinLot * ( lastBuyEntryRate - currAsk ) / NanpinWidth * EA_NANPIN_RATIO;
         } else if ( BuyEntryMode == ENTRY_MODE_3 ) {
            // 逆ナンピンモードの時
            ParamEntryInfo.order_lot	= SellTotalLots * EA_NANPIN_RATIO - BuyTotalLots;     
         }
   
   		// 買いエントリーをリクエスト
   		int ticketNo = 0;
   		if ( ParamEntryInfo.order_lot >= infoMinLot && ParamEntryInfo.order_lot < infoMaxLot ) {
      		ticketNo = RequestEntryOrder ( ParamEntryInfo );
   		} else {
            NextEntryTurn = TURN_SELL_ENTRY;
   		}
         if ( ticketNo > 0 ) {
   		   // エントリー成功
   		   Sleep(1000); // 情報取得の為にWaitを入れる

         	for ( int i = 0; i < NUM_OF_POS; i++ ) {
         	   if ( BuyPositionInfo[i].flagEnable != True ) {
                  BuyPositionInfo[i].ticket_no = ticketNo;
         		   // ポジション情報を取得
         		   GetPositionInfoByTicket( BuyPositionInfo[i] );
                  lastBuyEntryRate = BuyPositionInfo[i].entry_price;
                  baseRateOfBuyNanpin = lastBuyEntryRate;
                  prevNumOfBuyPosition = numOfBuyPosition;
         		   numOfBuyPosition++;
         		   break;
         		}
            }
   		} else {
   		   // エントリー失敗
   		}
      }
      
      // 売りエントリー処理
      if ( SellEntryMode != ENTRY_NONE ) {
         // エントリーフラグが有効
   		// 売りのパラメータ設定
   		InitEntryInfo( ParamEntryInfo );    // 使用する前に初期化
   		ParamEntryInfo.order_type	= OP_SELL;
   		ParamEntryInfo.order_rate	= Bid;
   		ParamEntryInfo.arrow_color	= clrRed;
   
         if ( SellEntryMode == ENTRY_MODE_0 ) {
            ParamEntryInfo.order_lot	= _MinLot;
         } else if ( SellEntryMode == ENTRY_MODE_1 ) {
            ParamEntryInfo.order_lot
               = _MinLot * MathPow( EA_NANPIN_RATIO, numOfSellPosition );
//               = _MinLot * numOfSellPosition * EA_NANPIN_RATIO;
//               = _MinLot + _MinLot * ( numOfSellPosition - 1 ) * EA_NANPIN_RATIO;
//               = _MinLot * ( currBid - SellEntryRateMin ) / NanpinWidth_S * EA_NANPIN_RATIO;
         } else if ( SellEntryMode == ENTRY_MODE_2 ) {
            ParamEntryInfo.order_lot
//               = _MinLot * MathPow( EA_NANPIN_RATIO, numOfSellPosition );
//               = _MinLot * numOfSellPosition * EA_NANPIN_RATIO;
            	= SellTotalLots + _MinLot * ( currBid - SellEntryRateMin ) / NanpinWidth * EA_NANPIN_RATIO;
         } else if ( SellEntryMode == ENTRY_MODE_3 ) {
            // 逆ナンピンモードの時
            ParamEntryInfo.order_lot	= BuyTotalLots * EA_NANPIN_RATIO - SellTotalLots;
         }
   
   		// 売りエントリーをリクエスト
   		int ticketNo = 0;
   		if ( ParamEntryInfo.order_lot >= infoMinLot && ParamEntryInfo.order_lot < infoMaxLot ) {
      		ticketNo = RequestEntryOrder ( ParamEntryInfo );
   		} else {
            NextEntryTurn = TURN_BUY_ENTRY;
   		}
   		
         if ( ticketNo > 0 ) {
   		   // エントリー成功
   		   Sleep(1000); // 情報取得の為にWaitを入れる
   		   
         	for ( int i = 0; i < NUM_OF_POS; i++ ) {
         	   if ( SellPositionInfo[i].flagEnable != True ) {
                  SellPositionInfo[i].ticket_no = ticketNo;
         		   // ポジション情報を取得
         		   GetPositionInfoByTicket( SellPositionInfo[i] );
                  lastSellEntryRate = SellPositionInfo[i].entry_price;
                  baseRateOfSellNanpin = lastSellEntryRate;
                  prevNumOfSellPosition = numOfSellPosition;
         		   numOfSellPosition++;
         		   break;
      		   }
      		}
   		} else {
   		   // エントリー失敗
   		}
      }
   } else {
      printf("EA_OrderMode = MODE_ALL_ENTRY_STOP");
   }

   if ( countEaSellIdle > 0 ) {
      countEaSellIdle--;
   }
   if ( countEaBuyIdle > 0 ) {
      countEaBuyIdle--;
   }
   
// DispDebugZigZagInfo();
   DispDebugPositionInfo();
}

//+------------------------------------------------------------------+
//| 指定時間足確定時の処理
//+------------------------------------------------------------------+
void TaskSetMinPeriod() {
    static    datetime s_lastset_mintime;               // 最後に記録した時間軸時間
                                                        // staticはこの関数が終了してもデータは保持される

    datetime temptime    = iTime( Symbol(), PERIOD_M30 ,0 );  // 現在の時間軸の時間取得

    if ( temptime == s_lastset_mintime ) {                 // 時間に変化が無い場合
        return;                                         // 処理終了
    }
    s_lastset_mintime = temptime;                          // 最後に記録した時間軸時間を保存

    // ----- 処理はこれ以降に追加 -----------

//    printf( "[%s]指定時間足確定%s" , NAME4LOG , TimeToStr( Time[0] ) );
}

//+------------------------------------------------------------------+
//| 移動平均線のクロス判定
//+------------------------------------------------------------------+
ENUM_MA_STATE MACrossJudge()
{
   ENUM_MA_STATE ret = MAC_NONE;
   
   double base_short_ma_rate;    // 確定した短期移動平均
   double base_middle_ma_rate;   // 確定した長期移動平均
   
   double last_short_ma_rate;    // 前回の短期移動平均
   double last_middle_ma_rate;   // 前回の長期移動平均
   
   // 確定した短期SMAを取得
   base_short_ma_rate = iMA(           // 移動平均算出
                           Symbol(),   // 通貨ペア
                           Period(),   // 時間軸
                           5,          // MAの平均期間
                           0,          // MAシフト
                           MODE_SMA,   // MAの平均化メソッド
                           PRICE_CLOSE,// 適用価格
                           1           // シフト
                           );

   // 確定した長期SMAを取得
   base_middle_ma_rate = iMA(           // 移動平均算出
                           Symbol(),   // 通貨ペア
                           Period(),   // 時間軸
                           25,         // MAの平均期間
                           0,          // MAシフト
                           MODE_SMA,   // MAの平均化メソッド
                           PRICE_CLOSE,// 適用価格
                           1           // シフト
                           );

   // 前回の短期SMAを取得
   last_short_ma_rate = iMA(           // 移動平均算出
                           Symbol(),   // 通貨ペア
                           Period(),   // 時間軸
                           5,          // MAの平均期間
                           0,          // MAシフト
                           MODE_SMA,   // MAの平均化メソッド
                           PRICE_CLOSE,// 適用価格
                           2           // シフト
                           );

   // 前回の長期SMAを取得
   last_middle_ma_rate = iMA(           // 移動平均算出
                           Symbol(),   // 通貨ペア
                           Period(),   // 時間軸
                           25,         // MAの平均期間
                           0,          // MAシフト
                           MODE_SMA,   // MAの平均化メソッド
                           PRICE_CLOSE,// 適用価格
                           2           // シフト
                           );

   // 短期SMAが長期SMAを上抜け/下抜け
   if ( base_short_ma_rate >  base_middle_ma_rate &&
        last_short_ma_rate <= last_middle_ma_rate ){
      ret = MAC_SM_UP_CHANGE;
   } else if ( base_short_ma_rate <  base_middle_ma_rate &&
               last_short_ma_rate >= last_middle_ma_rate ){
      ret = MAC_SM_DOWN_CHANGE;
   } 
   
   return ret;

}


//+------------------------------------------------------------------+
//| エントリーリクエスト
//+------------------------------------------------------------------+
int RequestEntryOrder ( stEntryInfo &in_EntryInfo) 
{

   int ret_TicketNo = -1;    // チケットNo
   
	if ( in_EntryInfo.order_type == OP_SELL ) {
		in_EntryInfo.arrow_color = clrRed;
	}
	
   ret_TicketNo = OrderSend(
					Symbol(),       // 通貨ペア
					in_EntryInfo.order_type,     // オーダータイプ[OP_BUY/OP_SELL]
					in_EntryInfo.order_lot,      // ロット数[0.01単位]
					in_EntryInfo.order_rate,     // オーダープライスレート
					in_EntryInfo.splippage,            // スリップ上限(int)[分解能0.1pips]
					in_EntryInfo.order_stop_rate,              // ストップレート
					in_EntryInfo.order_limit_rate,              // リミットレート
					in_EntryInfo.order_comment,             // オーダーコメント
					in_EntryInfo.magic_no,        // マジックナンバー(識別用))
   				in_EntryInfo.order_expire,
   				in_EntryInfo.arrow_color
					);

	return ret_TicketNo;
}

//+------------------------------------------------------------------+
//| クローズリクエスト
//+------------------------------------------------------------------+
bool RequestCloseOrder ( stPositionInfo &in_Position ) 
{
   bool retValue = False;
   bool retBool = False;
   
   // ポジションを確認
   retBool = OrderSelect( in_Position.ticket_no, SELECT_BY_TICKET );
   
   // ポジション選択失敗時
   if ( retBool == False ) {
      printf( "[%s]不明なチケットNo = %d", NAME4LOG, in_Position.ticket_no);
      InitPositionInfo( in_Position );
      return retValue;
   }
   // ポジションがクローズ済の場合
   if ( OrderCloseTime() > 0 ) {
      printf( "[%s]ポジションクローズ済 チケットNo = %d", NAME4LOG, in_Position.ticket_no );
      InitPositionInfo( in_Position );
      return retValue;
   }
   
   bool     close_bool;       // 注文結果
   double   close_rate = 0;   // 決済価格
   double   close_lot  = 0;   // 決済数量
   color    close_color;      // 色
   
   if ( in_Position.entry_dir == OP_BUY ) {          // 買いででエントリーしていた場合
      close_rate = Bid;                      // Bid
      close_color = clrBlue;
   } else if ( in_Position.entry_dir == OP_SELL ) {  // 売りででエントリーしていた場合
      close_rate = Ask;     
      close_color = clrRed;                 // Ask
   } else {              // 指値でエントリーしていた場合
      return retValue;   // 処理終了
   }
   
   close_bool = OrderClose(
                     in_Position.ticket_no,     // チケットNo
                     in_Position.entry_lot,     // ロット数
                     close_rate,       // クローズ価格
                     20,               // スリップ上限（int)[分解能 0.1pips]
                     close_color       // 色
                     );
   
   if ( close_bool == True ) {
      // クローズ成功
      //printf("[%s]決済オーダー成功。 ticket_no=%d, close_rate=%s",
      //         NAME4LOG, in_Position.ticket_no, DoubleToStr(close_rate,3) );
      
      InitPositionInfo( in_Position );
      retValue = true;
   } else {
      // クローズ失敗
      int      get_error_code    = GetLastError();
      string   error_detail_str  = ErrorDescription(get_error_code);
      
      // エラーログ出力
      printf("[%s]決済オーダーエラー。 エラーコード=%d, エラー内容=%s",
            NAME4LOG, get_error_code, error_detail_str);
      printf("[%s]OrderClose 設定値。 ticket=%d, lot=%f, rate=%f", 
               NAME4LOG, in_Position.ticket_no, in_Position.entry_lot, close_rate);
   }
   
   return retValue;
}

//+------------------------------------------------------------------+
//| 一括クローズリクエスト
//+------------------------------------------------------------------+
int RequestCloseAll ( ENUM_CLOSE_MODE in_mode ) 
{
   int ret_NumOfClose = 0;
   bool ret_CloseOrder = False;

   if ( in_mode == CLOSE_ALL ){
   	for ( int i = 0; i < NUM_OF_POS; i++ ) {
      	if ( BuyPositionInfo[i].flagEnable == True ) {
            ret_CloseOrder = RequestCloseOrder( BuyPositionInfo[i] );
            if (ret_CloseOrder) {
               prevNumOfBuyPosition = numOfBuyPosition;
               numOfBuyPosition--;
               ret_NumOfClose++;
            }
         }
         Sleep(500);
      	if ( SellPositionInfo[i].flagEnable == True ) {
            ret_CloseOrder = RequestCloseOrder( SellPositionInfo[i] );
            if (ret_CloseOrder) {
               prevNumOfSellPosition = numOfSellPosition;
               numOfSellPosition--;
               ret_NumOfClose++;
            }
         }
         Sleep(500);
      }
      lastBuyEntryRate = 0;
      BuyTotalLots  = 0;
      
      lastSellEntryRate = 0;
      SellTotalLots = 0;
      printf("[%s]Close All BUY/SELL Positions",__FUNCTION__);
      ret_CloseOrder = True;
      
      countBuyNanpinPeriod  = 0;
      countSellNanpinPeriod = 0;
         
   } else if ( in_mode == CLOSE_BUY ) {
   	for ( int i = 0; i < NUM_OF_POS; i++ ) {
      	if ( BuyPositionInfo[i].flagEnable == True ) {
            ret_CloseOrder = RequestCloseOrder( BuyPositionInfo[i] );
            if (ret_CloseOrder) {
               prevNumOfBuyPosition = numOfBuyPosition;
               numOfBuyPosition--;
               ret_NumOfClose++;
            }
         }
         Sleep(500);
      }
      lastBuyEntryRate = 0;
      BuyTotalLots  = 0;
      printf("[%s]Close All BUY Positions",__FUNCTION__);
      ret_CloseOrder = True;
      countBuyNanpinPeriod  = 0;

   } else if ( in_mode == CLOSE_SELL ) {
   	for ( int i = 0; i < NUM_OF_POS; i++ ) {
      	if ( SellPositionInfo[i].flagEnable == True ) {
            ret_CloseOrder = RequestCloseOrder( SellPositionInfo[i] );
            if (ret_CloseOrder) {
               prevNumOfSellPosition = numOfSellPosition;
               numOfSellPosition--;
               ret_NumOfClose++;
            }
         }
         Sleep(500);
      }
      lastSellEntryRate = 0;
      SellTotalLots = 0;
      printf("[%s]Close All SELL Positions",__FUNCTION__);
      ret_CloseOrder = True;
      countSellNanpinPeriod = 0;

   } else if ( in_mode == CLOSE_BUY_BY_POS ) {
      int i;
   	for ( i = 0; i < NUM_OF_POS; i++ ) {
      	if ( BuyPositionInfo[i].flagEnable == True && 
      	     currBid > BuyPositionInfo[i].entry_price + ProfitSingle ) {
            ret_CloseOrder = RequestCloseOrder( BuyPositionInfo[i] );
            if (ret_CloseOrder) {
               prevNumOfBuyPosition = numOfBuyPosition;
               numOfBuyPosition--;
               ret_NumOfClose++;
            }
         }
         Sleep(500);
      }
      
      if ( numOfBuyPosition == 0 ){
         countBuyNanpinPeriod  = 0;
      }
      
//      lastBuyEntryRate = 0;
//      BuyTotalLots  = 0;
      printf("[%s]Close BUY Position No.%d",__FUNCTION__ , i );

   } else if ( in_mode == CLOSE_SELL_BY_POS ) {
      int i;
   	for ( i = 0; i < NUM_OF_POS; i++ ) {
      	if ( SellPositionInfo[i].flagEnable == True &&
      	     currAsk < SellPositionInfo[i].entry_price - ProfitSingle ) {
            ret_CloseOrder = RequestCloseOrder( SellPositionInfo[i] );
            if (ret_CloseOrder) {
               prevNumOfSellPosition = numOfSellPosition;
               numOfSellPosition--;
               ret_NumOfClose++;
            }
         }
         Sleep(500);
      }
      
      if ( numOfSellPosition == 0 ) {
         countSellNanpinPeriod = 0;
      }
      
//      lastSellEntryRate = 0;
//      SellTotalLots = 0;
      printf("[%s]Close SELL Position No.%d",__FUNCTION__, i);

   }
   return ret_CloseOrder;
}

//+------------------------------------------------------------------+
//| 新規エントリー
//+------------------------------------------------------------------+
bool EA_EntryOrder( stEntryInfo &in_EntryInfo )
{
   bool     ret         = false;
   int      order_type  = OP_BUY;
   double   order_lot   = _MinLot;
   double   order_rate  = Ask;
   
   if ( in_EntryInfo.order_type == OP_BUY ) {
      order_type = OP_BUY;    // Long エントリー
      order_rate = Ask;
   } else {
      order_type = OP_SELL;   // Short エントリー
      order_rate = Bid;
   }

   int ea_ticket_res = -1;    // チケットNo
   
   ea_ticket_res = OrderSend(
                        Symbol(),       // 通貨ペア
                        order_type,     // オーダータイプ[OP_BUY/OP_SELL]
                        order_lot,      // ロット数[0.01単位]
                        order_rate,     // オーダープライスレート
                        100,            // スリップ上限(int)[分解能0.1pips]
                        0,              // ストップレート
                        0,              // リミットレート
                        "",             // オーダーコメント
                        MAGIC_NO        // マジックナンバー(識別用))
                        );

   if ( ea_ticket_res != -1 ) {
      // デバッグログ出力
//      printf("[%s]エントリーオーダ成功！：ticketNo=%d", NAME4LOG, ea_ticket_res);
      ret = true;
   } else {
      int      get_error_code    = GetLastError();
      string   error_detail_str  = ErrorDescription(get_error_code);
      
      // エラーログ出力
      printf("[%s]エントリーオーダーエラー！エラーコード=%d, エラー内容=%s",
               NAME4LOG, get_error_code, error_detail_str );
               
   }
   
   return ret;                 

}

//+------------------------------------------------------------------+
//| トレンド情報を取得
//+------------------------------------------------------------------+
int GetTrendInfo( stTrendInfo &in_TrendInfo )
{
   int   ret = 0;
   
   for ( int i=0; i < NUM_OF_TREND; i++ ) {
      in_TrendInfo.dataOpen[i]   = Open[i+1];
      in_TrendInfo.dataClose[i]  = Close[i+1];
      in_TrendInfo.dataHigh[i]   = High[i+1];
      in_TrendInfo.dataLow[i]    = Low[i+1];
      in_TrendInfo.dataMaShort[i]    = 
         iMA(Symbol(), Period(), MA_PERIOD_SHORT, 0, MODE_SMA, PRICE_CLOSE, i+1);
      in_TrendInfo.dataMaMiddle[i]   = 
         iMA(Symbol(), Period(), MA_PERIOD_MIDDLE, 0, MODE_SMA, PRICE_CLOSE, i+1);
      in_TrendInfo.dataMaLong[i]     = 
         iMA(Symbol(), Period(), MA_PERIOD_LONG, 0, MODE_SMA, PRICE_CLOSE, i+1);
      in_TrendInfo.CandleSize[i] = in_TrendInfo.dataClose[i] - in_TrendInfo.dataOpen[i];
         
   }

   return ret;    // 現時点ではエラーの想定がない
}

//+------------------------------------------------------------------+
//| 現在のポジション情報から統計情報を更新
//+------------------------------------------------------------------+
int GetPositionStatInfo()
{
   int   ret = 0;

   // 買いポジションの含み損合計・最大最小エントリーレートを取得
	for ( int i = 0; i < NUM_OF_POS; i++ ) {
   	if ( BuyPositionInfo[i].flagEnable == True ) {
   	   currBuyLossTotal += ( currBid - BuyPositionInfo[i].entry_price ) * BuyPositionInfo[i].entry_lot * 100;
   	   currBuyAveRate   += BuyPositionInfo[i].entry_price * BuyPositionInfo[i].entry_lot;
   	   BuyTotalLots     += BuyPositionInfo[i].entry_lot;
		   if ( BuyEntryRateMin == 0 ) {
		      BuyEntryRateMax = BuyPositionInfo[i].entry_price;
		      BuyEntryRateMin = BuyPositionInfo[i].entry_price;
		   } else if ( BuyEntryRateMin > BuyPositionInfo[i].entry_price ) {
		      // ポジションの中の買値MINを取得
		      BuyEntryRateMin = BuyPositionInfo[i].entry_price;
		   } else if ( BuyEntryRateMax < BuyPositionInfo[i].entry_price ) {
		      BuyEntryRateMax = BuyPositionInfo[i].entry_price;
		   }
      }
	}
   if ( BuyTotalLots != 0 ){
   	currBuyAveRate /= BuyTotalLots;
   }
	for ( int i = 0; i < NUM_OF_POS; i++ ) {
   	if ( SellPositionInfo[i].flagEnable == True ) {
   	   currSellLossTotal += ( SellPositionInfo[i].entry_price - currAsk ) * SellPositionInfo[i].entry_lot * 100;
   	   currSellAveRate   += SellPositionInfo[i].entry_price * SellPositionInfo[i].entry_lot;
   	   SellTotalLots     += SellPositionInfo[i].entry_lot;
		   if ( SellEntryRateMax == 0 ) {
		      SellEntryRateMax = SellPositionInfo[i].entry_price;
		      SellEntryRateMin = SellPositionInfo[i].entry_price;
		   } else if ( SellEntryRateMax < SellPositionInfo[i].entry_price ) {
         // ポジションの中の売値MAXを取得
		      SellEntryRateMax = SellPositionInfo[i].entry_price;
		   } else if ( SellEntryRateMin > SellPositionInfo[i].entry_price ) {
		      SellEntryRateMin = SellPositionInfo[i].entry_price;
		   }
	   }
	}
	if ( SellTotalLots != 0 ) {
		currSellAveRate /= SellTotalLots;
	}
	if ( maxLossTotal > currBuyLossTotal + currSellLossTotal ) {
   	maxLossTotal = currBuyLossTotal + currSellLossTotal;
	}
   
   return ret;    // 現時点ではエラーの想定がない
}

//+------------------------------------------------------------------+
//| ナンピンレベルを確認
//+------------------------------------------------------------------+
int GetNanpinLevel( stTrendInfo &in_TrendInfo, int in_order_type, double in_1stEntryRate )
{
   int retValue = 0, i_count;
   double tmpNanpinRate = 0, tmpLastNanpinRate = 0;
   
   if ( in_order_type == OP_BUY ) {
      for ( i_count = 1; i_count < NUM_OF_NPN_LEVEL; i_count++ ){
         if ( i_count < EA_NANPIN_NARROW_MAX ) {
            tmpNanpinRate = in_1stEntryRate - NanpinWidth_S * i_count;
            tmpLastNanpinRate = tmpNanpinRate;
         } else if ( i_count >= EA_NANPIN_NARROW_MAX ) {
            tmpNanpinRate = tmpLastNanpinRate -
                         NanpinWidth * ( i_count - EA_NANPIN_NARROW_MAX );
         }
         if ( in_TrendInfo.dataClose[1] >= tmpNanpinRate &&
              in_TrendInfo.dataClose[0] <  tmpNanpinRate ) {
              break;
          }
      }
      if ( i_count != NUM_OF_NPN_LEVEL ) {
         retValue = i_count;
         printf("[%s] Buy  Nanpin Level = %d",__FUNCTION__, retValue );
      }
   } else if ( in_order_type == OP_SELL ) {
      for ( i_count = 1; i_count < NUM_OF_NPN_LEVEL; i_count++ ){
         if ( i_count < EA_NANPIN_NARROW_MAX ) {
            tmpNanpinRate = in_1stEntryRate + NanpinWidth_S * i_count;
            tmpLastNanpinRate = tmpNanpinRate;
         } else if ( i_count >= EA_NANPIN_NARROW_MAX ) {
            tmpNanpinRate = tmpLastNanpinRate +
                         NanpinWidth * ( i_count - EA_NANPIN_NARROW_MAX );
         }
         if ( in_TrendInfo.dataClose[1] <= tmpNanpinRate &&
              in_TrendInfo.dataClose[0] >  tmpNanpinRate ) {
              break;
          }
      }
      if ( i_count != NUM_OF_NPN_LEVEL ) {
         retValue = i_count;
         printf("[%s] Sell Nanpin Level = %d",__FUNCTION__, retValue );
      }
   }
   return retValue;
}

//+------------------------------------------------------------------+
//| ZigZag情報を取得
//+------------------------------------------------------------------+
bool GetZigZagInfo ( void )
{
int n = 0, m = 0, t = 0, i = 1;
bool kekka  = False;

   for ( n = i; n <= i + 500; n++) {
      //ZigZagの値を取得
      double Zg = NormalizeDouble( iCustom(NULL,0,"ZigZag",E_Depth,E_Deviation,E_Backstep,0,n), 5 );
      
      //ZigZagの値と最高値が同じ場合、頂点なのでZigTopにセット    
      if(Zg!=0 && Zg == NormalizeDouble(High[n],5) ) {
         if( n == 1 ){
            TopPoint = 1;
         }
         ZigTop[m++] = Zg;
         if ( m >= ZIG_NUM ) {
            break;
         }
      } 
         
      //ZigZagの値と最安値が同じ場合、底なのでZigBottomにセット            
      if( Zg != 0 && Zg == NormalizeDouble(Low[n], 5) ) {
         if( n == 1 ){
            BottomPoint = 1;
         }
         ZigBottom[t++] = Zg;
         if( t >= ZIG_NUM ){
            break;
         }
      }
   }

   kekka=true;

   //目視確認用コメント
   Comment(
          "│ ZigTOP0=", ZigTop[0], "│ ZigBTM0=", ZigBottom[0], "|\n",
          "│ ZigTOP1=", ZigTop[1], "│ ZigBTM1=", ZigBottom[1], "|\n",
          "│ ZigTOP2=", ZigTop[2], "│ ZigBTM2=", ZigBottom[2], "|\n",
          "│ ZigTOP3=", ZigTop[3], "│ ZigBTM3=", ZigBottom[3], "|\n",
          "│ TopP=", TopPoint, "│ BottomP=", BottomPoint, "|\n"
   );

   return(kekka);   
}


//+------------------------------------------------------------------+
//| MA(Moving Averate)のクロスポイントを判断
//+------------------------------------------------------------------+
ENUM_MA_STATE CheckMaCross( stTrendInfo &in_TrendInfo, ENUM_MA_MODE CompareMode )
{
   ENUM_MA_STATE   ret = MAC_NONE;
   
   //　CompareMode  0: Short & Middle, 1: Middle & Long
   
   if ( CompareMode == MAC_SHORT_MIDDLE ){
      if ( in_TrendInfo.dataMaShort[3] < in_TrendInfo.dataMaMiddle[3] &&
           in_TrendInfo.dataMaShort[2] < in_TrendInfo.dataMaMiddle[2] &&
           in_TrendInfo.dataMaShort[1] < in_TrendInfo.dataMaMiddle[1] &&
           in_TrendInfo.dataMaShort[0] > in_TrendInfo.dataMaMiddle[0] ) {
         ret = MAC_SM_UP_CHANGE;
      } else if ( in_TrendInfo.dataMaShort[3] > in_TrendInfo.dataMaMiddle[3] &&
                  in_TrendInfo.dataMaShort[2] > in_TrendInfo.dataMaMiddle[2] &&
                  in_TrendInfo.dataMaShort[1] > in_TrendInfo.dataMaMiddle[1] &&
                  in_TrendInfo.dataMaShort[0] < in_TrendInfo.dataMaMiddle[0] ) {
         ret = MAC_SM_DOWN_CHANGE;
      }   
   } else if (CompareMode == MAC_MIDDLE_LONG ) {
      if ( in_TrendInfo.dataMaMiddle[3] < in_TrendInfo.dataMaLong[3] &&
           in_TrendInfo.dataMaMiddle[2] < in_TrendInfo.dataMaLong[2] &&
           in_TrendInfo.dataMaMiddle[1] < in_TrendInfo.dataMaLong[1] &&
           in_TrendInfo.dataMaMiddle[0] > in_TrendInfo.dataMaLong[0] ) {
         ret = MAC_ML_UP_CHANGE;
      } else if ( in_TrendInfo.dataMaMiddle[3] > in_TrendInfo.dataMaLong[3] &&
                  in_TrendInfo.dataMaMiddle[2] > in_TrendInfo.dataMaLong[2] &&
                  in_TrendInfo.dataMaMiddle[1] > in_TrendInfo.dataMaLong[1] &&
                  in_TrendInfo.dataMaMiddle[0] < in_TrendInfo.dataMaLong[0] ) {
         ret = MAC_ML_DOWN_CHANGE;
      }   
   }

   return ret;    // 現時点ではエラーの想定がない
}

//+------------------------------------------------------------------+
//| トレンド転換ポイントを判断
//+------------------------------------------------------------------+
ENUM_TREND CheckTrendChange( stTrendInfo &in_TrendInfo )
{
   ENUM_TREND   ret = TREND_NONE;

   if ( in_TrendInfo.CandleSize[2] < 0 &&
        in_TrendInfo.CandleSize[1] > 0 &&
        in_TrendInfo.CandleSize[0] > 0 //&&
        //CurrTrendInfo.dataOpen[2] < CurrTrendInfo.dataMaMiddle[2]
         ) {
      // 陰-陽-陽の場合
      //printf("[%s]TREND_UP_CHANGE", __FUNCTION__);
      ret = TREND_UP_CHANGE;
   } else if ( in_TrendInfo.CandleSize[2] > 0 &&
               in_TrendInfo.CandleSize[1] < 0 &&
               in_TrendInfo.CandleSize[0] < 0 //&&
               //CurrTrendInfo.dataOpen[2] > CurrTrendInfo.dataMaMiddle[2] 
               ) {
      // 陽-陰-陰の場合
      //printf("[%s]TREND_DOWN_CHANGE", __FUNCTION__);
      ret = TREND_DOWN_CHANGE;
   } else {
      //printf("[%s]TREND_NONE", __FUNCTION__);
   }
   return ret;
}

//+------------------------------------------------------------------+
//| 陽線・陰線が継続して、ろうそく足の大きさが大きくなっているかを判断
//+------------------------------------------------------------------+
ENUM_TREND CheckTrendPower( stTrendInfo &in_TrendInfo )
{
   ENUM_TREND   ret = TREND_NONE;
   
   if ( in_TrendInfo.CandleSize[0] > 0 &&
        in_TrendInfo.CandleSize[0] > in_TrendInfo.CandleSize[1]) {
        // 強い上昇トレンドが継続
     //printf("[%s]TREND_UP_INCREASE", __FUNCTION__);
     ret = TREND_UP_INCREASE;
   } else if ( in_TrendInfo.CandleSize[0] < 0 &&
               in_TrendInfo.CandleSize[0] < in_TrendInfo.CandleSize[1]) {
        // 強い下降トレンドが継続
     //printf("[%s]TREND_DOWN_INCREASE", __FUNCTION__);
     ret = TREND_DOWN_INCREASE;
   } else {
     //printf("[%s]TREND_DECREASE", __FUNCTION__);
     ret = TREND_DECREASE;
   }
   
   return ret;
}

//+------------------------------------------------------------------+
//| トレンドの継続性を判断（3本連続して陽線/陰線が続く)
//+------------------------------------------------------------------+
ENUM_TREND CheckTrendKeep3( stTrendInfo &in_TrendInfo )
{
   ENUM_TREND   ret = TREND_NONE;
   int   numOfPositive = 0, numOfNegative = 0;

   if ( in_TrendInfo.CandleSize[2] >= 0 &&
        in_TrendInfo.CandleSize[1] >= 0 &&
        in_TrendInfo.CandleSize[0] > 0 ) {
        // 強い上昇トレンドが継続
     //printf("[%s]TREND_KEEP_UP3", __FUNCTION__);
     ret = TREND_KEEP_UP3;
   } else if ( in_TrendInfo.CandleSize[2] <= 0 &&
               in_TrendInfo.CandleSize[1] <= 0 &&
               in_TrendInfo.CandleSize[0] < 0 ) {
        // 強い下降トレンドが継続
     //printf("[%s]TREND_KEEP_DOWN3", __FUNCTION__);
     ret = TREND_KEEP_DOWN3;
   } else {
     //printf("[%s]TREND_NONE", __FUNCTION__);
   }
   
   return ret;    // 現時点ではエラーの想定がない
}

//+------------------------------------------------------------------+
//| ZigZagから高値・安値の切り上げ・切り下げを判断する
//+------------------------------------------------------------------+
ENUM_TREND CheckZigzagTrend( void )
{
   ENUM_TREND ret_ZgTrend = TREND_NONE;
   if ( ZigTop[1]    < ZigTop[0] && 
        ZigBottom[1] < ZigBottom[0] ) {
     //printf("[%s]TREND_ZG_UP", __FUNCTION__);
      ret_ZgTrend = TREND_ZG_UP;
   } else if ( ZigTop[1]    > ZigTop[0] && 
               ZigBottom[1] > ZigBottom[0] ) {
     //printf("[%s]TREND_ZG_DOWN", __FUNCTION__);
      ret_ZgTrend = TREND_ZG_DOWN;
   } else {
     //printf("[%s]TREND_ZG_NONE", __FUNCTION__);
   }
   
   return ret_ZgTrend;
}

//+------------------------------------------------------------------+
//| ZigZagから高値・安値の切り上げ・切り下げを判断する
//+------------------------------------------------------------------+
ENUM_TREND CheckZigzagHighLow( void )
{
   ENUM_TREND ret_ZgTrend = TREND_NONE;
   int tmpCountHigh = 0, tmpCountLow = 0;
   
   for ( int i = 0; i < 5; i++ ) {
      if ( ZigTop[i] < CurrTrendInfo.dataClose[0] ) {
         tmpCountHigh++;
      }
      if ( ZigBottom[i] > CurrTrendInfo.dataClose[0] ) {
         tmpCountLow++;
      }
   }
   
   if ( tmpCountHigh > 4 ) {
     //printf("[%s]TREND_ZG_HIGH", __FUNCTION__);
      ret_ZgTrend = TREND_ZG_HIGH;
   } else if ( tmpCountLow > 4 ) {
     //printf("[%s]TREND_ZG_LOW", __FUNCTION__);
      ret_ZgTrend = TREND_ZG_LOW;
   } else {
     //printf("[%s]TREND_ZG_NONE", __FUNCTION__);
   }
   
   return ret_ZgTrend;
}

//+------------------------------------------------------------------+
//| トレンドの継続性を判断（5本連続して陽線/陰線が続く)
//+------------------------------------------------------------------+
ENUM_TREND CheckTrendKeep5( stTrendInfo &in_TrendInfo )
{
   ENUM_TREND   ret = TREND_NONE;
   int   numOfPositive = 0, numOfNegative = 0;

   if ( in_TrendInfo.CandleSize[4] >= 0 &&
        in_TrendInfo.CandleSize[3] >= 0 &&
        in_TrendInfo.CandleSize[2] >= 0 &&
        in_TrendInfo.CandleSize[1] >= 0 &&
        in_TrendInfo.CandleSize[0] >  0 &&
        CurrTrendInfo.dataClose[0] - CurrTrendInfo.dataOpen[4] > JudgeTrendWidth ) {
        // 強い上昇トレンドが継続
     //printf("[%s]TREND_KEEP_UP5", __FUNCTION__);
     ret = TREND_KEEP_UP5;
   } else if ( in_TrendInfo.CandleSize[4] <= 0 &&
               in_TrendInfo.CandleSize[3] <= 0 &&
               in_TrendInfo.CandleSize[2] <= 0 &&
               in_TrendInfo.CandleSize[1] <= 0 &&
               in_TrendInfo.CandleSize[0] <  0 &&
               CurrTrendInfo.dataOpen[4] - CurrTrendInfo.dataClose[0] > JudgeTrendWidth ) {
        // 強い下降トレンドが継続
     //printf("[%s]TREND_KEEP_DOWN5", __FUNCTION__);
     ret = TREND_KEEP_DOWN5;
   } 
   
   return ret;    // 現時点ではエラーの想定がない
}

//+------------------------------------------------------------------+
//| SMA Middle を終値が抜けた
//+------------------------------------------------------------------+
ENUM_MA_STATE CheckMaMidCross( stTrendInfo &in_TrendInfo )
{
   ENUM_MA_STATE   ret = MAC_NONE;
   int   numOfPositive = 0, numOfNegative = 0;

   if ( in_TrendInfo.dataMaMiddle[1] >= in_TrendInfo.dataClose[1] &&
        in_TrendInfo.dataMaMiddle[0] < in_TrendInfo.dataClose[0] ) {
        // ローソク足の終値がMA25を上抜け
     ret = MAC_MID_CROSS_UP;
   } else if ( in_TrendInfo.dataMaMiddle[1] <= in_TrendInfo.dataClose[1] &&
        in_TrendInfo.dataMaMiddle[0] > in_TrendInfo.dataClose[0] ) {
        // ローソク足の終値がMA25を下抜け
     ret = MAC_MID_CROSS_DOWN;
   } 
   
   return ret;    // 現時点ではエラーの想定がない
}

//+------------------------------------------------------------------+
//| SMA Middle を終値が抜けた
//+------------------------------------------------------------------+
ENUM_MA_STATE CheckMaLongCross( stTrendInfo &in_TrendInfo )
{
   ENUM_MA_STATE   ret = MAC_NONE;
   int   numOfPositive = 0, numOfNegative = 0;

   if ( in_TrendInfo.dataMaLong[1] >= in_TrendInfo.dataClose[1] &&
        in_TrendInfo.dataMaLong[0] < in_TrendInfo.dataClose[0] ) {
        // ローソク足の終値がMA25を上抜け
     ret = MAC_LONG_CROSS_UP;
   } else if ( in_TrendInfo.dataMaLong[1] <= in_TrendInfo.dataClose[1] &&
        in_TrendInfo.dataMaLong[0] > in_TrendInfo.dataClose[0] ) {
        // ローソク足の終値がMA25を下抜け
     ret = MAC_LONG_CROSS_DOWN;
   } 
   
   return ret;    // 現時点ではエラーの想定がない
}

//+------------------------------------------------------------------+
//| 5/7 でトレンドを判断
//+------------------------------------------------------------------+
ENUM_TREND CheckTrend5in7( stTrendInfo &in_TrendInfo )
{
   ENUM_TREND   ret = TREND_NONE;
   int   numOfPositive = 0, numOfNegative = 0;

   for ( int i=0; i < NUM_OF_TREND; i++ ) {
      if ( in_TrendInfo.CandleSize[i] >= 0){
         numOfPositive++;
      } else if ( in_TrendInfo.CandleSize[i] <= 0 ) {
         numOfNegative++;
      }
   }

   if ( numOfPositive >= 5 ) {
      //printf("[%s]TREND_5IN7_UP", __FUNCTION__);
      ret = TREND_5IN7_UP;
   } else if ( numOfNegative >= 5 ) {
      //printf("[%s]TREND_5IN7_DOWN", __FUNCTION__);
      ret = TREND_5IN7_DOWN;
   }
   
   return ret;    // 現時点ではエラーの想定がない
}


//+------------------------------------------------------------------+
//| SMA MIDDLE と SMA LONG のトレンド
//+------------------------------------------------------------------+
ENUM_MA_STATE CheckMATrend( stTrendInfo &in_TrendInfo )
{
   ENUM_MA_STATE ret = MAC_NONE;
   int   numOfPositive = 0, numOfNegative = 0;

   if ( in_TrendInfo.dataMaMiddle[1] < in_TrendInfo.dataMaMiddle[0] &&
        in_TrendInfo.dataMaLong[1] < in_TrendInfo.dataMaLong[0] &&
        in_TrendInfo.dataMaLong[0] < in_TrendInfo.dataMaMiddle[0] ) {
        // SMA中期・長期が上昇トレンド
     //printf("[%s]MAC_TREND_UP", __FUNCTION__);
     ret = MAC_TREND_UP;
   } else if ( in_TrendInfo.dataMaMiddle[1] > in_TrendInfo.dataMaMiddle[0] &&
        in_TrendInfo.dataMaLong[1] > in_TrendInfo.dataMaLong[0] &&
        in_TrendInfo.dataMaLong[0] > in_TrendInfo.dataMaMiddle[0] ) {
        // SMA中期・長期が下降トレンド
        //printf("[%s]MAC_TREND_DOWN", __FUNCTION__);
        ret = MAC_TREND_DOWN;
   } 
   
   return ret;
}

//+------------------------------------------------------------------+
//| 信頼できるUP/DOWNトレンドの判定
//+------------------------------------------------------------------+
ENUM_TREND CheckTrendReliable( stTrendInfo &in_TrendInfo )
{
   ENUM_TREND ret = TREND_NONE;
   int   numOfPositive = 0, numOfNegative = 0;

   if ( in_TrendInfo.dataClose[0] - in_TrendInfo.dataOpen[4] > ReliableWidth ) {
      ret = TREND_UP_RELIABLE;
      printf("[%s]TREND_UP_RELIABLE:ReliableWidth=%f,BarLength=%f", 
            __FUNCTION__, ReliableWidth, in_TrendInfo.dataClose[0] - in_TrendInfo.dataOpen[1] );

   } else if ( in_TrendInfo.dataOpen[4] - in_TrendInfo.dataClose[0] > ReliableWidth ) {
      ret = TREND_DOWN_RELIABLE;
      printf("[%s]TREND_DOWN_RELIABLE:ReliableWidth=%f,BarLength=%f", 
            __FUNCTION__, ReliableWidth, in_TrendInfo.dataOpen[1] - in_TrendInfo.dataClose[0]);
   }
   
   return ret;
}

//+------------------------------------------------------------------+
//| 急激な変化を検出
//+------------------------------------------------------------------+
ENUM_TREND CheckSuddenTrend( void )
{
   ENUM_TREND ret = TREND_NONE;
   int   numOfPositive = 0, numOfNegative = 0;
   double tmpOpen = Open[1], tmpClose = Close[1];
   
   if ( SWITCH_SUDDEN_MODE ) {
      if ( tmpClose - tmpOpen > SuddenChangeWidth ) {
         ret = TREND_UP_SUDDEN;
         printf("[%s]TREND_UP_SUDDEN:SuddenChangeWidth=%f,BarLength=%f", 
               __FUNCTION__, SuddenChangeWidth, tmpClose - tmpOpen );
   
      } else if ( tmpOpen - tmpClose > SuddenChangeWidth ) {
         ret = TREND_DOWN_SUDDEN;
         printf("[%s]TREND_DOWN_SUDDEN:SuddenChangeWidth=%f,BarLength=%f", 
               __FUNCTION__, SuddenChangeWidth, tmpOpen - tmpClose );
      }   
   }

   return ret;
}

//+------------------------------------------------------------------+
//| 直近のNエントリーの時間を返す（変化があった時だけ値を返す）
//+------------------------------------------------------------------+
int CheckNanpinEntryTime( int in_num, int in_dir )
{
   int retTime = 60*24;    // Default を 0 にすると◯◯以下で判定できないので249時間としておく
   int   numOfPositive = 0, numOfNegative = 0;
   static int prevBuyTicketNo, prevSellTicketNo;
   
   if ( in_dir == OP_BUY &&
        numOfBuyPosition >= in_num && numOfBuyPosition <= NUM_OF_POS ) {
   //if ( in_dir == OP_BUY &&
   //     numOfBuyPosition >= in_num && numOfBuyPosition <= NUM_OF_POS &&
   //     BuyPositionInfo[numOfBuyPosition  - 1].ticket_no != prevBuyTicketNo ) {
        
      retTime = BuyPositionInfo[numOfBuyPosition - 1].entry_tick -
                BuyPositionInfo[numOfBuyPosition - in_num].entry_tick;
      prevBuyTicketNo = BuyPositionInfo[numOfBuyPosition  - 1].ticket_no;
      printf("[%s] Dir=BUY, return %d",__FUNCTION__, retTime);

   } 
   if ( in_dir == OP_SELL && 
               numOfSellPosition >= in_num && numOfSellPosition <= NUM_OF_POS ) {
   //if ( in_dir == OP_SELL && 
   //            numOfSellPosition >= in_num && numOfSellPosition <= NUM_OF_POS &&
   //            SellPositionInfo[numOfSellPosition -1].ticket_no != prevSellTicketNo ) {
               
      retTime = SellPositionInfo[numOfSellPosition - 1].entry_tick -
                SellPositionInfo[numOfSellPosition - in_num].entry_tick;
                
      prevSellTicketNo = SellPositionInfo[numOfSellPosition  - 1].ticket_no;
      printf("[%s] Dir=SELL, return %d",__FUNCTION__, retTime);

   }
   return retTime;

}

//+------------------------------------------------------------------+
//| ポジションの状態を確認
//+------------------------------------------------------------------+
ENUM_POSITION_STATE CheckPositionState( stPositionInfo &in_Position, stTrendInfo &in_Trend )
{
   ENUM_POSITION_STATE retState = POS_NUTRAL;
   
   if ( in_Position.entry_dir == OP_BUY ) {
      if ( currBuyLossTotal > ProfitNormal ) {  // ナンピン一括決済をする場合
         // 利確ライン越え
         //printf("[%s]CheckPositionState:POS_OVER_LIMIT", __FUNCTION__);
         retState = POS_OVER_LIMIT;
      } else if ( in_Position.entry_price - LosscutRate > in_Trend.dataClose[0] ) {
         // 損切りライン越え
         //printf("[%s]CheckPositionState:POS_OVER_STOP", __FUNCTION__);
         retState = POS_OVER_STOP;
      }
   } else if ( in_Position.entry_dir == OP_SELL ) {
      if ( currSellLossTotal > ProfitNormal ) { // ナンピン一括決済をする場合
         // 利確ライン越え
         //printf("[%s]CheckPositionState:POS_OVER_LIMIT", __FUNCTION__);
         retState = POS_OVER_LIMIT;
      } else if ( in_Position.entry_price + LosscutRate < in_Trend.dataClose[0] ) {
         // 損切りライン越え
         //printf("[%s]CheckPositionState:POS_OVER_STOP", __FUNCTION__);
         retState = POS_OVER_STOP;
      }
   }
   
   return retState;
}

//+------------------------------------------------------------------+
//| PLを確認
//+------------------------------------------------------------------+
ENUM_PL_STATE CheckPLState( double in_LossTotal )
{
   ENUM_PL_STATE retState = PL_NONE;
   
   if ( in_LossTotal > ProfitNormal ) {  // ナンピン一括決済をする場合
      // 利確ライン越え
      //printf("[%s]PL_OVER_PROFIT: LossTotal=%s", __FUNCTION__, DoubleToStr(in_LossTotal,3) );
      retState = PL_OVER_PROFIT;
   } else if ( in_LossTotal < 0 - LosscutRate ) {
      // ProfitNormal 以上の含み損あり（ProfitNormal 分の損失がある時とする）
      //printf("[%s]PL_HAVING_LOSS: LossTotal=%s, LosscutRate=%s", 
      //   __FUNCTION__, DoubleToStr(in_LossTotal,3), DoubleToString(LosscutRate,3 ));
      retState = PL_HAVING_LOSS;
   }
  
   return retState;
}

//+------------------------------------------------------------------+
//| ポジション情報を取得
//+------------------------------------------------------------------+
bool GetPositionInfoByPositon( stPositionInfo &in_st )
{
   bool  ret = False;

   // チケット指定でポジション情報を取得
   if ( OrderSelect(in_st.ticket_no, SELECT_BY_TICKET ) == true ) {  // インデックス指定でポジションを取得

      in_st.entry_dir   = OrderType();       // オーダータイプを取得
      in_st.set_limit   = OrderTakeProfit(); // リミットを取得
      in_st.set_stop    = OrderStopLoss();   // ストップを取得
      in_st.entry_price = OrderOpenPrice();  // 約定金額を取得
      in_st.flagEnable  = True;              // データを有効化
        
      ret = True;
      
   }
   
   return ret;
}

//+------------------------------------------------------------------+
//| ポジション情報を取得
//+------------------------------------------------------------------+
bool GetPositionInfoByTicket( stPositionInfo &in_st )
{
   bool  ret = false;

   // チケット指定でポジション情報を取得
   if ( OrderSelect(in_st.ticket_no, SELECT_BY_TICKET ) == true ) {  // インデックス指定でポジションを取得

      in_st.entry_dir   = OrderType();       // オーダータイプを取得
      in_st.entry_lot   = OrderLots();       // ロット数取得
      in_st.set_limit   = OrderTakeProfit(); // リミットを取得
      in_st.set_stop    = OrderStopLoss();   // ストップを取得
      in_st.entry_price = OrderOpenPrice();  // 約定金額を取得
      in_st.flagEnable  = true;              // データを有効化
      in_st.entry_tick  = tickCount;
     
      ret = true;
   }
   return ret;
}

//+------------------------------------------------------------------+
//| SUDDENトレンド履歴の初期化
//+------------------------------------------------------------------+
void InitSuddenRecentTrend( void )
{   
   for ( int i = 0; i < NUM_OF_SUDDEN_HISTORY; i++ ) {
      arraySuddenTrend[i] = TREND_NONE;
   }

}

//+------------------------------------------------------------------+
//| SUDDENトレンドの記録
//+------------------------------------------------------------------+
void SetNewSuddenTrend( ENUM_TREND in_dir )
{
   for ( int i = NUM_OF_SUDDEN_HISTORY - 1; i > 0; i-- ) {
      arraySuddenTrend[i] = arraySuddenTrend[i-1];
   }
   arraySuddenTrend[0] = in_dir;
}

//+------------------------------------------------------------------+
//| SUDDENトレンドの確認
//+------------------------------------------------------------------+
ENUM_TREND CheckSuddenRecentTrend( void )
{
   int countUpDir = 0;
   ENUM_TREND retValue = TREND_DOWN_SUDDEN;
   
   for ( int i = 0; i < NUM_OF_SUDDEN_HISTORY; i++ ) {
      if ( arraySuddenTrend[i] == TREND_UP_SUDDEN ) {
         countUpDir++;
      }
   }
   
   if ( countUpDir > NUM_OF_SUDDEN_HISTORY / 2 ) {
      retValue = TREND_UP_SUDDEN;
   } 
   
   return retValue;
}

//+------------------------------------------------------------------+
//| デバッグ用コメント表示
//+------------------------------------------------------------------+
void DispDebugInfo( stPositionInfo &in_st )
{
   string temp_str = "";      // 表示する文字列
   
   temp_str += StringFormat( "チケットNo   :%d\n", in_st.ticket_no );
   temp_str += StringFormat( "オーダータイプ :%d\n", in_st.entry_dir );
   temp_str += StringFormat( "リミット     :%s\n", DoubleToStr(in_st.set_limit,Digits));
   temp_str += StringFormat( "ストップ     :%s\n", DoubleToStr(in_st.set_stop,Digits));
   
   Comment( temp_str );    // コメント表示

}

//+------------------------------------------------------------------+
//| デバッグ用コメント（ポジションステート）
//+------------------------------------------------------------------+
void DispDebugPositionInfo( )
{
   string temp_str = "";      // 表示する文字列
   string temp_Mode = "【FWD】";
   int   numOfDigits = 5;

   if ( EA_NanpinMode == MODE_NANPIN_REV || OneshotNanpinMode == MODE_NANPIN_REV ) {
      temp_Mode = "【REV】";
   }

   temp_str += StringFormat( "●%s:ProfitNormal=%s, ProfitSingle=%s, LosscutRate=%s, NanpinWidth=%s, NanpinWidth_S=%s  %s BuyIdleCount=%d, SellIdleCount=%d\n",
      __FILE__, DoubleToStr(ProfitNormal,numOfDigits),DoubleToStr(ProfitSingle,numOfDigits),
      DoubleToStr(LosscutRate,numOfDigits),DoubleToStr(NanpinWidth,numOfDigits),DoubleToStr(NanpinWidth_S,numOfDigits), temp_Mode,
      countEaBuyIdle, countEaSellIdle );
   temp_str += StringFormat( "                             ■%sポジション( %d個),lastBuyEntryRate =%f, 平均レート =%s, 利確ライン =%s(%s), Buy 含み損 =%s\n",
            "買い" ,numOfBuyPosition,lastBuyEntryRate, DoubleToStr(currBuyAveRate,numOfDigits), 
            DoubleToStr(currBuyAveRate+ProfitNormal,numOfDigits), 
            DoubleToStr(currBuyAveRate+ProfitSingle,numOfDigits),DoubleToStr(currBuyLossTotal,numOfDigits) );
   for ( int i=0; i< NUM_OF_POS; i++ ) {
      temp_str += StringFormat( "                             Buy %2d:%s / %sLots\n", 
            i, DoubleToStr(BuyPositionInfo[i].entry_price,5), DoubleToStr(BuyPositionInfo[i].entry_lot,numOfDigits));
   } 
   temp_str += StringFormat( "\n                             ■%sポジション( %d個),lastSellEntryRate =%f, 平均レート =%s, 利確ライン =%s(%s), SELL 含み損 =%s\n",
             "売り" ,numOfSellPosition, lastSellEntryRate, DoubleToStr(currSellAveRate,numOfDigits), 
             DoubleToStr(currSellAveRate-ProfitNormal,numOfDigits),
             DoubleToStr(currSellAveRate-ProfitSingle,numOfDigits), DoubleToStr(currSellLossTotal,numOfDigits) );
   for ( int i=0; i< NUM_OF_POS; i++ ) {
      temp_str += StringFormat( "                             Sell %2d:%s / %sLots\n", 
            i, DoubleToStr(SellPositionInfo[i].entry_price,5), DoubleToStr(SellPositionInfo[i].entry_lot,numOfDigits));
   }
   temp_str += StringFormat( "                             最大の含み損 =%s (Now %s)\n", DoubleToStr( maxLossTotal,numOfDigits), DoubleToStr(currBuyLossTotal + currSellLossTotal,numOfDigits));

   Comment( temp_str );    // コメント表示
}

//+------------------------------------------------------------------+
//| デバッグ用コメント（ZiGZag情報）
//+------------------------------------------------------------------+
void DispDebugZigZagInfo( )
{
   //目視確認用コメント
   string   tmpZgTrend;
   if ( ZigTop[0]    - ZigTop[1]    > 0 &&
        ZigBottom[0] - ZigBottom[1] > 0 ) {
      tmpZgTrend = "TREND_ZG_UP";
   } else if ( ZigTop[0]    - ZigTop[1]    < 0 &&
               ZigBottom[0] - ZigBottom[1] < 0 ) {
      tmpZgTrend = "TREND_ZG_DOWN";
   } else {
      tmpZgTrend = "TREND_ZG_NONE";   
   }
   Comment(
          "                        │ ZigTOP0=", ZigTop[0], "│ ZigBTM0=", ZigBottom[0], "|\n",
          "                        │ ZigTOP1=", ZigTop[1], "│ ZigBTM1=", ZigBottom[1], "|\n",
          "                        │ ZigTOP2=", ZigTop[2], "│ ZigBTM2=", ZigBottom[2], "|\n",
          "                        │ ZigTOP3=", ZigTop[3], "│ ZigBTM3=", ZigBottom[3], "|\n",
          "                        │ TopP   =", TopPoint, "│ BottomP=", BottomPoint, "|\n",
          "                        │ ZG_TREND   =", tmpZgTrend, "\n"
   );

}

//+------------------------------------------------------------------+
//| ポジション情報をクリア(決済済みの場合)
//+------------------------------------------------------------------+
void ClearPosiInfo( stPositionInfo &in_st )
{
   if (in_st.ticket_no > 0 ) {   // ポジション保有中の場合
      
      bool select_bool;
      
      // ポジションを選択
      select_bool = OrderSelect(
                           in_st.ticket_no,
                           SELECT_BY_TICKET
                           );
      // ポジション選択失敗時
      if ( select_bool == false ) {
         //printf("[%s]不明なチケットNo = %d", NAME4LOG, in_st.ticket_no);
         return;
      }
      
      // ポジションがクローズ済の場合
      if ( OrderCloseTime() > 0 ) {
         ZeroMemory( in_st );    // ゼロクリア
         in_st.flagEnable   = false;    // フラグも明示的に無効化
      }
   }
}

//+------------------------------------------------------------------+
//| 注文変更
//+------------------------------------------------------------------+
bool EA_Modify_Order( int in_ticket )
{
   bool ret = false;
   bool select_bool;
   
   // ポジションを選択
   select_bool = OrderSelect(
                        in_ticket,
                        SELECT_BY_TICKET
                        );
   
   // ポジション選択失敗時
   if ( select_bool == false ) {
      return ret;
   }
   
   bool     modify_bool;         // 注文変更結果
   int      get_order_type;      // エントリー方向
   double   set_limit_rate = 0;  // リミット価格
   double   set_stop_rate = 0;   // ストップ価格
   double   entry_rate;          // エントリー価格
   double   limit_offset;        // リミット用オフセット価格
   double   stop_offset;         // ストップ用オフセット価格
   
   entry_rate     = OrderOpenPrice();    // エントリー価格取得
   get_order_type = OrderType();         // 注文タイプ取得
   
   limit_offset   = entry_rate * 0.2;   // リミットオフセット設定
   stop_offset    = entry_rate * 0.1;   // ストップオフセット設定
   
   if ( get_order_type == OP_BUY ) {
      set_limit_rate = entry_rate + limit_offset;  // リミット価格設定
      set_stop_rate  = entry_rate - stop_offset;   // ストップ価格設定
   } else if ( get_order_type == OP_SELL ) {
      set_limit_rate = entry_rate - limit_offset;  // リミット価格設定
      set_stop_rate  = entry_rate + stop_offset;   // ストップ価格設定
   } else {                                  // 指値エントリーの場合
      return ret;                            // 処理終了
   }

   set_limit_rate = NormalizeDouble( set_limit_rate , Digits ); // リミットレートを正規化
   set_stop_rate  = NormalizeDouble( set_stop_rate  , Digits ); // ストップレートを正規化
    
   double limit_diff;   // リミット価格差
   double stop_diff;    // ストップ価格差
   limit_diff = MathAbs( set_limit_rate - OrderTakeProfit() );
   stop_diff = MathAbs( set_stop_rate   - OrderStopLoss() );
   
   if ( limit_diff < Point() && stop_diff < Point() ) {  // 0.1pips未満の変化の場合
      return ret;
   }
   
   modify_bool = OrderModify(
                        in_ticket,  // チケットNo
                        0,          // エントリー価格(保留中の注文のみ)
                        set_stop_rate, // ストップロス
                        set_limit_rate,   // リミット
                        0,                // 有効期限
                        clrYellow         // ストップリミットラインの色
                        );
   
    if ( modify_bool == false) {    // 変更失敗

        int    get_error_code   = GetLastError();                   // エラーコード取得
        string error_detail_str = ErrorDescription(get_error_code); // エラー詳細取得

        // エラーログ出力
        printf( "[%s]オーダー変更エラー。 エラーコード=%d エラー内容=%s" 
            , NAME4LOG ,  get_error_code , error_detail_str
         );        
    } else {
        // 変更成功
        ret = true;
    }

    return ret;    // 戻り値を返す
}


//+------------------------------------------------------------------+
//| 初期化関数（stPositionInfo）
//+------------------------------------------------------------------+
void InitPositionInfo ( stPositionInfo &in_PositionInfo )
{
	
	in_PositionInfo.flagEnable		= False;
	in_PositionInfo.ticket_no		= -1;
	in_PositionInfo.entry_dir		= 0;
	in_PositionInfo.entry_price	= 0;
	in_PositionInfo.entry_lot     = 0;
	in_PositionInfo.set_limit		= 0;
	in_PositionInfo.set_stop		= 0;
	
}

//+------------------------------------------------------------------+
//| 初期化関数（stEntryInfo）
//+------------------------------------------------------------------+
void InitEntryInfo ( stEntryInfo &in_EntryInfo )
{
	
	in_EntryInfo.order_lot			= _MinLot;
	in_EntryInfo.order_rate			= 0;
	in_EntryInfo.splippage			= 20;
	in_EntryInfo.order_stop_rate	= 0;
	in_EntryInfo.order_limit_rate	= 0;
	in_EntryInfo.order_comment		= "";
	in_EntryInfo.magic_no			= MAGIC_NO;
	in_EntryInfo.order_expire		= 0;
	in_EntryInfo.arrow_color		= clrBlue;
	
}

//+------------------------------------------------------------------+
//| 文字列変換（Ask, Bid）
//+------------------------------------------------------------------+
string TextEntryType ( int in_EntryType ) 
{
   string retString = "";
   
   if ( in_EntryType == OP_BUY ) {
      retString = "OP_BUY";
   } else if ( in_EntryType == OP_SELL ){
      retString = "OP_SELL";
   }

   return retString;
}
