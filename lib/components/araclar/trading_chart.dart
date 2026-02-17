// lib/components/araclar/trading_chart.dart
import 'package:flutter/material.dart';
import 'package:candlesticks/candlesticks.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import './grafik_katmanlari/dubai_katman.dart';
import './grafik_katmanlari/ema_katman.dart';
import './grafik_katmanlari/kirilim_katman.dart';
import './grafik_katmanlari/money_trader_katman.dart';
import './grafik_katmanlari/analiz_motoru_katman.dart';


class TradingChart extends StatefulWidget {
  final List<Candle> candles;
  final dynamic emaResult;
  final dynamic dubaiResult;
  final dynamic moneyTraderResult;
  final dynamic kirilimResult;
  final dynamic analizMotoruResult;
  final String currentInterval;
  final Function(String) onIntervalChanged;
  final bool showEma;
  final bool showDubai;
  final bool showMoneyTrader;
  final bool showKirilim;
  final bool showAnalizMotoru;
  final bool isCalculating;
  final bool isCalculatingDubai;
  final bool isCalculatingMoneyTrader;
  final bool isCalculatingKirilim;
  final bool isCalculatingAnalizMotoru;
  final VoidCallback onEmaToggle;
  final VoidCallback onDubaiToggle;
  final VoidCallback onMoneyTraderToggle;
  final VoidCallback onKirilimToggle;
  final VoidCallback onAnalizMotoruToggle;
  final Function(String)? onSearch;

  // YENİ: Performans ve fiyat bilgileri (MEXC tarzı)
  final Map<String, double> performance;
  final double? high;
  final double? low;
  final double? volume;

  const TradingChart({
    super.key,
    required this.candles,
    this.emaResult,
    this.dubaiResult,
    this.moneyTraderResult,
    this.kirilimResult,
    this.analizMotoruResult,
    required this.currentInterval,
    required this.onIntervalChanged,
    required this.showEma,
    required this.showDubai,
    required this.showMoneyTrader,
    required this.showKirilim,
    required this.showAnalizMotoru,
    required this.isCalculating,
    required this.isCalculatingDubai,
    required this.isCalculatingMoneyTrader,
    required this.isCalculatingKirilim,
    required this.isCalculatingAnalizMotoru,
    required this.onEmaToggle,
    required this.onDubaiToggle,
    required this.onMoneyTraderToggle,
    required this.onKirilimToggle,
    required this.onAnalizMotoruToggle,
    this.onSearch,
    // YENİ: Performans ve fiyat bilgileri
    this.performance = const {},
    this.high,
    this.low,
    this.volume,
  });

  @override
  State<TradingChart> createState() => _TradingChartState();
}

class _TradingChartState extends State<TradingChart> {
  final List<String> _timeframes = ["1m", "5m", "15m", "1h", "4h"];
  final TextEditingController _searchController = TextEditingController();
  
  // FIX: Zoom için ZoomPanBehavior ekle
  late ZoomPanBehavior _zoomPanBehavior;

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      enableSelectionZooming: true,
      zoomMode: ZoomMode.xy,
      maximumZoomLevel: 0.01,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fiyat değişim hesaplama
  Map<String, dynamic> _getPriceInfo() {
    if (widget.candles.length < 2) {
      return {
        'price': 0.0,
        'change': 0.0,
        'changePercent': 0.0,
        'high24h': 0.0,
        'low24h': 0.0,
        'volume24h': 0.0,
      };
    }

    final latest = widget.candles.last;
    final previous = widget.candles[widget.candles.length - 2];
    final change = latest.close - previous.close;
    final changePercent = (change / previous.close) * 100;

    final high24h = widget.candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final low24h = widget.candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final volume24h = widget.candles.map((c) => c.volume).reduce((a, b) => a + b);

    return {
      'price': latest.close,
      'change': change,
      'changePercent': changePercent,
      'high24h': high24h,
      'low24h': low24h,
      'volume24h': volume24h,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ════════════════════════════════════════════════════════════
        // 1. ARAMA KUTUSU (KÜÇÜLTÜLDÜ - Height 40)
        // ════════════════════════════════════════════════════════════
        _buildSearchBar(),
        
        // ════════════════════════════════════════════════════════════
        // 2. FİYAT PANELİ (COMPACT - Height 45)
        // ════════════════════════════════════════════════════════════
        _buildPricePanel(),
        
        // ════════════════════════════════════════════════════════════
        // 3. İNDİKATÖR BUTONLARI + ZAMAN DİLİMİ (TEK SATIRDA)
        // ════════════════════════════════════════════════════════════
        _buildControlPanel(),
        
        // ════════════════════════════════════════════════════════════
        // 4. ANA GRAFİK (BÜYÜTÜLDÜ - Kalan tüm alan)
        // ════════════════════════════════════════════════════════════
        Expanded(
          child: _buildChart(),
        ),
        
        // ════════════════════════════════════════════════════════════
        // 5. İNDİKATÖR İSTATİSTİKLERİ (Compact)
        // ════════════════════════════════════════════════════════════
        if (widget.showDubai || widget.showEma || widget.showKirilim || widget.showMoneyTrader || widget.showAnalizMotoru)
          _buildIndicatorStats(),
        
        // ════════════════════════════════════════════════════════════
        // 6. PERFORMANS METRİKLERİ (KÜÇÜLTÜLDÜ - Height 50)
        // ════════════════════════════════════════════════════════════
        _buildPerformanceMetrics(),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // 1️⃣ ARAMA KUTUSU - KÜÇÜLTÜLDÜ
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0E11),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.cyanAccent.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
          decoration: InputDecoration(
            hintText: 'Coin Ara (BTC, ETH...)',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 11,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Colors.cyanAccent,
              size: 18,
            ),
            suffixIcon: IconButton(
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.cyanAccent,
                size: 16,
              ),
              onPressed: () => _handleSearch(),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            isDense: true,
          ),
          onSubmitted: (_) => _handleSearch(),
        ),
      ),
    );
  }

  void _handleSearch() {
    String text = _searchController.text.trim().toUpperCase();
    if (text.isNotEmpty) {
      if (!text.endsWith("USDT")) text = "${text}USDT";
      widget.onSearch?.call(text);
      _searchController.clear();
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // 2️⃣ FİYAT PANELİ - COMPACT
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildPricePanel() {
    final info = _getPriceInfo();
    final isPositive = info['change'] >= 0;

    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Fiyat
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                info['price'].toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${isPositive ? '+' : ''}${info['changePercent'].toStringAsFixed(2)}%',
                style: TextStyle(
                  color: isPositive ? const Color(0xFF26A69A) : const Color(0xFFEF5350),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          // 24h High/Low
          Row(
            children: [
              _buildStatItem('24h H', info['high24h'].toStringAsFixed(2)),
              const SizedBox(width: 12),
              _buildStatItem('24h L', info['low24h'].toStringAsFixed(2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // 3️⃣ KONTROL PANELİ - İNDİKATÖR BUTONLARI + ZAMAN DİLİMİ TEK SATIRDA
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // İNDİKATÖR BUTONLARI - İLK SATIR (3 buton)
          Row(
            children: [
              Expanded(
                child: _buildIndicatorButton(
                  'EMA',
                  Icons.analytics_rounded,
                  widget.showEma,
                  widget.isCalculating,
                  widget.onEmaToggle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildIndicatorButton(
                  'Dubai',
                  Icons.trending_up_rounded,
                  widget.showDubai,
                  widget.isCalculatingDubai,
                  widget.onDubaiToggle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildIndicatorButton(
                  'Money',
                  Icons.attach_money_rounded,
                  widget.showMoneyTrader,
                  widget.isCalculatingMoneyTrader,
                  widget.onMoneyTraderToggle,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 6),
          
          // İNDİKATÖR BUTONLARI - İKİNCİ SATIR (2 buton)
          Row(
            children: [
              Expanded(
                child: _buildIndicatorButton(
                  'Kırılım',
                  Icons.show_chart_rounded,
                  widget.showKirilim,
                  widget.isCalculatingKirilim,
                  widget.onKirilimToggle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildIndicatorButton(
                  '🚀 ANALİZ',
                  Icons.rocket_launch,
                  widget.showAnalizMotoru,
                  widget.isCalculatingAnalizMotoru,
                  widget.onAnalizMotoruToggle,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // ZAMAN DİLİMİ BUTONLARI - Yatay row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _timeframes.map((tf) {
              final isActive = tf == widget.currentInterval;
              return GestureDetector(
                onTap: () => widget.onIntervalChanged(tf),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive 
                      ? Colors.cyanAccent.withOpacity(0.15) 
                      : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isActive ? Colors.cyanAccent : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    tf.toUpperCase(),
                    style: TextStyle(
                      color: isActive ? Colors.cyanAccent : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorButton(
    String label,
    IconData icon,
    bool isActive,
    bool isLoading,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
            ? const Color(0xFFFFC107).withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFFFFC107) : Colors.white24,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFFC107),
                ),
              )
            else
              Icon(
                icon,
                color: isActive ? const Color(0xFFFFC107) : Colors.white38,
                size: 14,
              ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFFFFC107) : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // 4️⃣ ANA GRAFİK - ZOOM ÇALIŞIR HALDE + POZİSYON KUTUSU
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildChart() {
    if (widget.candles.isEmpty) {
      return Container(
        color: const Color(0xFF131722),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2962FF),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF131722),
      child: Stack(
        children: [
          // ANA CHART
          SfCartesianChart(
            backgroundColor: const Color(0xFF131722),
            
            // FIX: Zoom ve Pan - initState'te tanımlanan _zoomPanBehavior kullan
            zoomPanBehavior: _zoomPanBehavior,

            // X ekseni (Tarih)
            primaryXAxis: DateTimeAxis(
              majorGridLines: const MajorGridLines(width: 0),
              axisLine: const AxisLine(width: 0),
              labelStyle: const TextStyle(color: Colors.white38, fontSize: 9),
            ),

            // Y ekseni (Fiyat) - Sağda
            primaryYAxis: NumericAxis(
              opposedPosition: true,
              majorGridLines: MajorGridLines(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
              axisLine: const AxisLine(width: 0),
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 9),
            ),

            // Seriler
            series: _buildSeries(),

            // Annotations (Sadece Dubai sinyalleri - kutu Stack'te)
            annotations: _buildAnnotations(),

            // Tooltip
            tooltipBehavior: TooltipBehavior(
              enable: true,
              color: const Color(0xFF1E2329),
              textStyle: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),

          // POZİSYON KUTUSU - Dubai overlay (Stack ile)
          if (widget.showDubai && widget.dubaiResult != null)
            _buildPositionBox(),

          // Money Trader başarı tablosu - sol üst overlay
          if (widget.showMoneyTrader && widget.moneyTraderResult != null)
            MoneyTraderKatman(widget.moneyTraderResult!, widget.candles).buildStatsOverlay(),

          // Analiz Motoru işlem kutusu - sol alt overlay
          if (widget.showAnalizMotoru && widget.analizMotoruResult != null)
            ...[
              AnalizMotoruKatman(widget.analizMotoruResult!, widget.candles).buildSignalOverlay() ?? const SizedBox.shrink(),
            ],

          // Zoom Reset Butonu - Sağ üst
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.zoom_out_map_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
              onPressed: () {
                _zoomPanBehavior.reset();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// FIX: POZİSYON KUTUSU - Stack/Positioned ile
  Widget _buildPositionBox() {
    final dubaiLayer = DubaiKatman(widget.dubaiResult!, widget.candles);
    
    if (dubaiLayer.result.activeTargets == null) {
      return const SizedBox.shrink();
    }

    final t = dubaiLayer.result.activeTargets!;
    final bool isBuy = t.type == "BUY";
    final Color boxColor = isBuy 
        ? const Color(0xFF26A69A)
        : const Color(0xFFEF5350);
    final Color textColor = Colors.white;

    String calcPercent(double target) {
      final percent = ((target - t.entry) / t.entry) * 100;
      return '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%';
    }

    String formatPrice(double price) {
      if (price >= 1000) return price.toStringAsFixed(2);
      else if (price >= 1) return price.toStringAsFixed(4);
      else return price.toStringAsFixed(6);
    }

    return Positioned(
      top: 12,
      right: 45, // Zoom butonunun solunda
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: boxColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: boxColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık
            Row(
              children: [
                Icon(
                  isBuy ? Icons.arrow_upward : Icons.arrow_downward,
                  color: textColor,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  '${isBuy ? "AL" : "SAT"} Pozisyon',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            
            // Giriş
            _buildTargetRow('Giriş:', formatPrice(t.entry), textColor, fontSize: 9),
            
            // Stop Loss
            _buildTargetRow(
              'Stop:',
              '${formatPrice(t.sl)} (${calcPercent(t.sl)})',
              textColor.withOpacity(0.9),
              fontSize: 8,
            ),
            
            Divider(color: textColor.withOpacity(0.3), height: 8, thickness: 1),
            
            // TP1
            _buildTargetRow('1.', '${formatPrice(t.tp1)} (${calcPercent(t.tp1)})', textColor, fontSize: 8),
            
            // TP2
            _buildTargetRow('2.', '${formatPrice(t.tp2)} (${calcPercent(t.tp2)})', textColor, fontSize: 8),
            
            // TP3
            _buildTargetRow('3.', '${formatPrice(t.tp3)} (${calcPercent(t.tp3)})', textColor, fontSize: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetRow(String label, String value, Color color, {double fontSize = 9}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// SERİLER: Candlestick + EMA
  List<CartesianSeries<dynamic, dynamic>> _buildSeries() {
    List<CartesianSeries<dynamic, dynamic>> seriesList = [];

    // Candlestick
    seriesList.add(
      CandleSeries<Candle, DateTime>(
        dataSource: widget.candles,
        xValueMapper: (Candle c, _) => c.date,
        lowValueMapper: (Candle c, _) => c.low,
        highValueMapper: (Candle c, _) => c.high,
        openValueMapper: (Candle c, _) => c.open,
        closeValueMapper: (Candle c, _) => c.close,
        bearColor: const Color(0xFFEF5350), // Kırmızı
        bullColor: const Color(0xFF26A69A), // Yeşil
        enableSolidCandles: true,
      ),
    );

    // EMA serileri
    if (widget.showEma && widget.emaResult != null) {
      final emaLayer = EmaKatman(widget.emaResult!, widget.candles);
      seriesList.addAll(emaLayer.buildSeries());
      seriesList.addAll(emaLayer.buildVolumeZoneSeries());
    }

    // Money Trader serileri (Major High/Low çizgileri)
    if (widget.showMoneyTrader && widget.moneyTraderResult != null) {
      final moneyLayer = MoneyTraderKatman(widget.moneyTraderResult!, widget.candles);
      seriesList.addAll(moneyLayer.buildSeries());
    }

    // Kırılım serileri (Pump/Dump + Fibonacci + Dip SL/TP)
    if (widget.showKirilim && widget.kirilimResult != null) {
      final kirilimLayer = KirilimKatman(widget.kirilimResult!, widget.candles);
      seriesList.addAll(kirilimLayer.buildSeries());
      seriesList.addAll(kirilimLayer.buildFibonacciSeries());
      seriesList.addAll(kirilimLayer.buildDipSeries());
    }

    // Analiz Motoru serileri (Quantum trend + Mavi ATR + Sarı hat)
    if (widget.showAnalizMotoru && widget.analizMotoruResult != null) {
      final analizLayer = AnalizMotoruKatman(widget.analizMotoruResult!, widget.candles);
      seriesList.addAll(analizLayer.buildSeries());
    }

    return seriesList;
  }

  /// ANNOTATIONS: Dubai + EMA sinyalleri (POZİSYON KUTUSU HARİÇ - o Stack'te)
  List<CartesianChartAnnotation> _buildAnnotations() {
    List<CartesianChartAnnotation> annotations = [];

    // Dubai İndikatörü - Sadece sinyaller
    if (widget.showDubai && widget.dubaiResult != null) {
      final dubaiLayer = DubaiKatman(widget.dubaiResult!, widget.candles);
      annotations.addAll(dubaiLayer.buildSignalAnnotations());
      // Kutu eklenmez - Stack'te gösteriliyor
    }

    // Money Trader annotationları (sinyal + hedef etiketi)
    if (widget.showMoneyTrader && widget.moneyTraderResult != null) {
      final moneyLayer = MoneyTraderKatman(widget.moneyTraderResult!, widget.candles);
      annotations.addAll(moneyLayer.buildAnnotations());
    }

    // Kırılım annotationları (Pump/Dump + QML + Fib + Dip sinyalleri)
    if (widget.showKirilim && widget.kirilimResult != null) {
      final kirilimLayer = KirilimKatman(widget.kirilimResult!, widget.candles);
      annotations.addAll(kirilimLayer.buildQmlAnnotations());
      annotations.addAll(kirilimLayer.buildSignalAnnotations());
      annotations.addAll(kirilimLayer.buildFibonacciLabels());
      annotations.addAll(kirilimLayer.buildDayBoxAnnotation());
      annotations.addAll(kirilimLayer.buildDipAnnotations());
    }

    // EMA İndikatörü
    if (widget.showEma && widget.emaResult != null) {
      final emaLayer = EmaKatman(widget.emaResult!, widget.candles);
      annotations.addAll(emaLayer.buildSignalAnnotations());
      annotations.addAll(emaLayer.buildVolumeZoneAnnotations());
    }

    // Analiz Motoru annotationları (Explosive sinyaller!)
    if (widget.showAnalizMotoru && widget.analizMotoruResult != null) {
      final analizLayer = AnalizMotoruKatman(widget.analizMotoruResult!, widget.candles);
      annotations.addAll(analizLayer.buildAnnotations());
    }

    return annotations;
  }

  /// İNDİKATÖR İSTATİSTİKLERİ - Dubai ve EMA panelleri (KÜÇÜLTÜLDÜ)
  Widget _buildIndicatorStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Kırılım istatistikleri (Pump/Dump)
            if (widget.showKirilim && widget.kirilimResult != null) ...[
              KirilimKatman(widget.kirilimResult!, widget.candles).buildStats(),
              const SizedBox(width: 8),
            ],

            // Dip Tarama istatistikleri
            if (widget.showKirilim && widget.kirilimResult != null) ...[
              KirilimKatman(widget.kirilimResult!, widget.candles).buildDipStats(),
              const SizedBox(width: 8),
            ],

            // Money Trader istatistikleri
            if (widget.showMoneyTrader && widget.moneyTraderResult != null) ...[
              MoneyTraderKatman(widget.moneyTraderResult!, widget.candles).buildStats(),
              const SizedBox(width: 8),
            ],

            // Dubai istatistikleri
            if (widget.showDubai && widget.dubaiResult != null) ...[
              DubaiKatman(widget.dubaiResult!, widget.candles).buildStats(),
              const SizedBox(width: 8),
            ],

            // EMA istatistikleri
            if (widget.showEma && widget.emaResult != null) ...[
              EmaKatman(widget.emaResult!, widget.candles).buildStats(),
              const SizedBox(width: 8),
            ],

            // Analiz Motoru istatistikleri
            if (widget.showAnalizMotoru && widget.analizMotoruResult != null) ...[
              AnalizMotoruKatman(widget.analizMotoruResult!, widget.candles).buildStats(),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // 5️⃣ PERFORMANS METRİKLERİ - KÜÇÜLTÜLDÜ
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildPerformanceMetrics() {
    final performance = widget.performance.isNotEmpty
        ? widget.performance
        : {
            'Today': 0.0,
            '7D': 0.0,
            '30D': 0.0,
            '90D': 0.0,
            '180D': 0.0,
            '1Y': 0.0,
          };

    return Container(
      height: 50,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            children: [
              Container(
                width: 2,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF2962FF),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Performans',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Performans değerleri
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: performance.entries.map((entry) {
                final isPositive = entry.value >= 0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.value > 0 ? '+' : ''}${entry.value.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: isPositive
                            ? const Color(0xFF26A69A)
                            : const Color(0xFFEF5350),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}