import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // compute()
import 'package:candlesticks/candlesticks.dart';
import '../components/araclar/trading_chart.dart';
import '../services/api/binance_api.dart';
import '../services/api/mexc_api.dart';
import '../services/api/okx_api.dart';
import '../services/isciler/ema_hesaplama.dart';
import '../services/isciler/indikator.dart';
import '../services/isciler/money_trader.dart';
import '../services/isciler/kirilim_indikator.dart';
import '../services/isciler/analiz_motoru.dart';
import 'dart:async';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level fonksiyonlar — compute() closure kabul etmez, bunlar zorunlu
// ─────────────────────────────────────────────────────────────────────────────
DubaiIndicatorResult _dubaiHesaplaIsolate(List<Candle> candles) {
  return DubaiCikolatasiIndicator.hesapla(candles);
}

EmaHesaplamaResult _emaHesaplaIsolate(List<Candle> candles) {
  return EmaHesaplamaService.emaHesapla(
    candles,
    shortLen: 9,
    longLen: 21,
    lookback: 5,
  );
}

MoneyTraderResult _moneyTraderHesaplaIsolate(List<Candle> candles) {
  return MoneyTraderIndicator.hesapla(candles);
}

KirilimIndicatorResult _kirilimHesaplaIsolate(List<Candle> candles) {
  return KirilimIndicator.hesapla(candles);
}

AnalysisResult _analizMotoruHesaplaIsolate(List<Candle> candles) {
  return AnalizMotoru.hesapla(candles);
}

// ─────────────────────────────────────────────────────────────────────────────

class Grafik extends StatefulWidget {
  final String? initialSymbol;
  const Grafik({super.key, this.initialSymbol});

  @override
  State<Grafik> createState() => _GrafikState();
}

class _GrafikState extends State<Grafik> {
  final BinanceApiService _binance = BinanceApiService();
  final MexcApiService _mexc = MexcApiService();
  final OkxApiService _okx = OkxApiService();

  List<Candle> _rawCandles = [];
  String _symbol = "BTCUSDT";
  String _interval = "5m";
  Timer? _timer;

  bool _showEma = false;
  EmaHesaplamaResult? _emaResult;
  bool _isCalculating = false;

  bool _showDubai = false;
  DubaiIndicatorResult? _dubaiResult;
  bool _isCalculatingDubai = false;

  bool _showMoneyTrader = false;
  MoneyTraderResult? _moneyTraderResult;
  bool _isCalculatingMoneyTrader = false;

  bool _showKirilim = false;
  KirilimIndicatorResult? _kirilimResult;
  bool _isCalculatingKirilim = false;

  bool _showAnalizMotoru = false;
  AnalysisResult? _analizMotoruResult;
  bool _isCalculatingAnalizMotoru = false;

  // FIX: Gereksiz yeniden hesaplamayı önlemek için son mum tarihini takip et
  DateTime? _lastCandleTime;

  // YENİ: Performans ve fiyat bilgileri (MEXC tarzı)
  Map<String, double> _performance = {};
  double? _high, _low, _volume;

  @override
  void initState() {
    super.initState();
    if (widget.initialSymbol != null) {
      _symbol = widget.initialSymbol!;
    }
    _allDataFetch();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (t) => _allDataFetch(),
    );
  }

  @override
  void didUpdateWidget(Grafik oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSymbol != null &&
        widget.initialSymbol != oldWidget.initialSymbol) {
      setState(() {
        _symbol = widget.initialSymbol!;
        _rawCandles = [];
        _emaResult = null;
        _dubaiResult = null;
        _moneyTraderResult = null;
        _kirilimResult = null;
        _analizMotoruResult = null;
        _showEma = false;
        _showDubai = false;
        _showMoneyTrader = false;
        _showKirilim = false;
        _showAnalizMotoru = false;
        _lastCandleTime = null;
      });
      _allDataFetch();
    }
  }

  void _allDataFetch() async {
    try {
      // ÖNCELİK SIRASI: MEXC → Binance → OKX
      // Paralel değil, sıralı - ilk başarılı olan kullanılır
      List<Candle> candles = [];
      
      // 1. Önce MEXC dene
      try {
        candles = await _mexc.fetchCandles(_symbol, _interval);
        if (candles.isNotEmpty) {
          debugPrint("✅ MEXC'den veri alındı");
        }
      } catch (e) {
        debugPrint("⚠️ MEXC hatası: $e");
      }
      
      // 2. MEXC başarısızsa Binance dene
      if (candles.isEmpty) {
        try {
          candles = await _binance.fetchCandles(_symbol, _interval);
          if (candles.isNotEmpty) {
            debugPrint("✅ Binance'den veri alındı");
          }
        } catch (e) {
          debugPrint("⚠️ Binance hatası: $e");
        }
      }
      
      // 3. İkisi de başarısızsa OKX dene
      if (candles.isEmpty) {
        try {
          candles = await _okx.fetchCandles(_symbol, _interval);
          if (candles.isNotEmpty) {
            debugPrint("✅ OKX'den veri alındı");
          }
        } catch (e) {
          debugPrint("⚠️ OKX hatası: $e");
        }
      }

      if (!mounted) return;

      setState(() {
        _rawCandles = candles;
      });

      // FIX: Sadece yeni bir mum geldiyse yeniden hesapla
      if (candles.isNotEmpty) {
        final DateTime newTime = candles.last.date;
        final bool isNewCandle = newTime != _lastCandleTime;

        if (isNewCandle) {
          _lastCandleTime = newTime;

          // YENİ: Performans ve fiyat bilgilerini hesapla
          _calculatePerformance();

          if (_showEma) _calculateEma();
          if (_showDubai) _calculateDubai();
          if (_showMoneyTrader) _calculateMoneyTrader();
          if (_showKirilim) _calculateKirilim();
          if (_showAnalizMotoru) _calculateAnalizMotoru();
        }
      }
    } catch (e) {
      debugPrint("Veri çekme hatası: $e");
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // YENİ: PERFORMANS VE FİYAT BİLGİLERİNİ HESAPLA (MEXC Tarzı)
  // ═══════════════════════════════════════════════════════════════════════════
  void _calculatePerformance() {
    if (_rawCandles.isEmpty) return;

    try {
      // High, Low, Volume hesapla
      _high = _rawCandles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
      _low = _rawCandles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
      _volume = _rawCandles.map((c) => c.volume).reduce((a, b) => a + b);

      // Performans yüzdelerini hesapla
      _performance = {
        'Today': _calculateChange(1),
        '7D': _calculateChange(7),
        '30D': _calculateChange(30),
        '90D': _calculateChange(90),
        '180D': _calculateChange(180),
        '1Y': _calculateChange(365),
      };

      debugPrint("✅ Performans Hesaplandı:");
      debugPrint("  - High: ${_high?.toStringAsFixed(2)}");
      debugPrint("  - Low: ${_low?.toStringAsFixed(2)}");
      debugPrint("  - Volume: ${(_volume! / 1000000).toStringAsFixed(2)}M");
      debugPrint("  - Today: ${_performance['Today']?.toStringAsFixed(2)}%");
    } catch (e) {
      debugPrint("❌ Performans hesaplama hatası: $e");
    }
  }

  double _calculateChange(int days) {
    if (_rawCandles.length < days) {
      // Yeterli veri yoksa 0 döndür
      return 0.0;
    }

    final startIndex = _rawCandles.length - days;
    final startPrice = _rawCandles[startIndex].close;
    final endPrice = _rawCandles.last.close;

    return ((endPrice - startPrice) / startPrice) * 100;
  }

  // FIX: compute() ile ayrı isolate'da çalıştır — UI donmaz
  void _calculateEma() async {
    if (_rawCandles.isEmpty) return;

    setState(() => _isCalculating = true);

    try {
      final result = await compute(_emaHesaplaIsolate, _rawCandles);

      if (!mounted) return;
      setState(() {
        _emaResult = result;
        _isCalculating = false;
      });

      debugPrint("✅ EMA Hesaplandı:");
      debugPrint("  - ${result.emaSignals.length} sinyal bulundu");
      debugPrint("  - ${result.volZones.length} volume zone bulundu");
    } catch (e) {
      debugPrint("EMA hesaplama hatası: $e");
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  // FIX: compute() ile ayrı isolate'da çalıştır — UI donmaz
  void _calculateDubai() async {
    if (_rawCandles.isEmpty) return;

    setState(() => _isCalculatingDubai = true);

    try {
      final result = await compute(_dubaiHesaplaIsolate, _rawCandles);

      if (!mounted) return;
      setState(() {
        _dubaiResult = result;
        _isCalculatingDubai = false;
      });

      debugPrint("✅ Dubai İndikatör Hesaplandı:");
      debugPrint("  - ${result.buySignals.length} AL sinyali");
      debugPrint("  - ${result.sellSignals.length} SAT sinyali");
      if (result.activeTargets != null) {
        debugPrint("  - Aktif hedef: ${result.activeTargets!.type}");
        debugPrint("  - TP1: ${result.activeTargets!.tp1.toStringAsFixed(2)}");
        debugPrint("  - TP2: ${result.activeTargets!.tp2.toStringAsFixed(2)}");
        debugPrint("  - TP3: ${result.activeTargets!.tp3.toStringAsFixed(2)}");
        debugPrint("  - STOP: ${result.activeTargets!.sl.toStringAsFixed(2)}");
      }
    } catch (e) {
      debugPrint("Dubai hesaplama hatası: $e");
      if (mounted) setState(() => _isCalculatingDubai = false);
    }
  }

  void _toggleEma() {
    setState(() => _showEma = !_showEma);

    if (_showEma && _rawCandles.isNotEmpty) {
      _calculateEma();
    } else {
      setState(() => _emaResult = null);
    }
  }

  void _toggleDubai() {
    setState(() => _showDubai = !_showDubai);

    if (_showDubai && _rawCandles.isNotEmpty) {
      _calculateDubai();
    } else {
      setState(() => _dubaiResult = null);
    }
  }

  // FIX: compute() ile ayrı isolate'da çalıştır — UI donmaz
  void _calculateMoneyTrader() async {
    if (_rawCandles.isEmpty) return;

    setState(() => _isCalculatingMoneyTrader = true);

    try {
      final result = await compute(_moneyTraderHesaplaIsolate, _rawCandles);

      if (!mounted) return;
      setState(() {
        _moneyTraderResult = result;
        _isCalculatingMoneyTrader = false;
      });

      debugPrint("✅ MoneyTrader Hesaplandı:");
      debugPrint("  - ${result.signals.length} sinyal");
      debugPrint("  - Başarı: ${result.stats.winRate.toStringAsFixed(1)}%");
      debugPrint("  - W:${result.stats.wins} L:${result.stats.losses}");
    } catch (e) {
      debugPrint("MoneyTrader hesaplama hatası: $e");
      if (mounted) setState(() => _isCalculatingMoneyTrader = false);
    }
  }

  void _toggleMoneyTrader() {
    setState(() => _showMoneyTrader = !_showMoneyTrader);

    if (_showMoneyTrader && _rawCandles.isNotEmpty) {
      _calculateMoneyTrader();
    } else {
      setState(() => _moneyTraderResult = null);
    }
  }

  // YENİ: Kırılım İndikatör Hesaplama
  void _calculateKirilim() async {
    if (_rawCandles.isEmpty) return;

    setState(() => _isCalculatingKirilim = true);

    try {
      final result = await compute(_kirilimHesaplaIsolate, _rawCandles);

      if (!mounted) return;
      setState(() {
        _kirilimResult = result;
        _isCalculatingKirilim = false;
      });

      debugPrint("✅ Kırılım İndikatör Hesaplandı:");
      debugPrint("  - ${result.signals.length} Golden Signal");
      debugPrint("  - ${result.fibLevels.length} Fibonacci seviyesi");
      debugPrint("  - Quantum hatları hazır");
    } catch (e) {
      debugPrint("Kırılım hesaplama hatası: $e");
      if (mounted) setState(() => _isCalculatingKirilim = false);
    }
  }

  void _toggleKirilim() {
    setState(() => _showKirilim = !_showKirilim);

    if (_showKirilim && _rawCandles.isNotEmpty) {
      _calculateKirilim();
    } else {
      setState(() => _kirilimResult = null);
    }
  }

  // YENİ: Analiz Motoru Hesaplama
  void _calculateAnalizMotoru() async {
    if (_rawCandles.isEmpty) return;

    setState(() => _isCalculatingAnalizMotoru = true);

    try {
      final result = await compute(_analizMotoruHesaplaIsolate, _rawCandles);

      if (!mounted) return;
      setState(() {
        _analizMotoruResult = result;
        _isCalculatingAnalizMotoru = false;
      });

      debugPrint("🚀 ANALİZ MOTORU Hesaplandı:");
      debugPrint("  - ${result.signals.length} sinyal");
      debugPrint("  - EXPLOSIVE: ${result.stats.explosiveSignals}");
      debugPrint("  - STRONG: ${result.stats.strongSignals}");
      debugPrint("  - Ortalama Güç: ${result.stats.avgSignalStrength.toStringAsFixed(1)}");
    } catch (e) {
      debugPrint("Analiz Motoru hesaplama hatası: $e");
      if (mounted) setState(() => _isCalculatingAnalizMotoru = false);
    }
  }

  void _toggleAnalizMotoru() {
    setState(() => _showAnalizMotoru = !_showAnalizMotoru);

    if (_showAnalizMotoru && _rawCandles.isNotEmpty) {
      _calculateAnalizMotoru();
    } else {
      setState(() => _analizMotoruResult = null);
    }
  }

  void _changeTimeframe(String newInterval) {
    setState(() {
      _interval = newInterval;
      _rawCandles = [];
      _emaResult = null;
      _dubaiResult = null;
      _moneyTraderResult = null;
      _kirilimResult = null;
      _analizMotoruResult = null;
      _lastCandleTime = null;
    });
    _allDataFetch();
  }

  void _handleSearch(String symbol) {
    setState(() {
      _symbol = symbol.toUpperCase();
      _rawCandles = [];
      _emaResult = null;
      _dubaiResult = null;
      _moneyTraderResult = null;
      _kirilimResult = null;
      _analizMotoruResult = null;
      _showEma = false;
      _showDubai = false;
      _showMoneyTrader = false;
      _showKirilim = false;
      _showAnalizMotoru = false;
      _lastCandleTime = null;
    });
    _allDataFetch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2329),
        elevation: 0,
        title: Text(
          _symbol,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _allDataFetch,
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF131722),
        child: _rawCandles.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white54),
              )
            : TradingChart(
                candles: _rawCandles,
                emaResult: _showEma ? _emaResult : null,
                dubaiResult: _showDubai ? _dubaiResult : null,
                moneyTraderResult: _showMoneyTrader ? _moneyTraderResult : null,
                kirilimResult: _showKirilim ? _kirilimResult : null,
                analizMotoruResult: _showAnalizMotoru ? _analizMotoruResult : null,
                currentInterval: _interval,
                onIntervalChanged: _changeTimeframe,
                showEma: _showEma,
                showDubai: _showDubai,
                showMoneyTrader: _showMoneyTrader,
                showKirilim: _showKirilim,
                showAnalizMotoru: _showAnalizMotoru,
                isCalculating: _isCalculating,
                isCalculatingDubai: _isCalculatingDubai,
                isCalculatingMoneyTrader: _isCalculatingMoneyTrader,
                isCalculatingKirilim: _isCalculatingKirilim,
                isCalculatingAnalizMotoru: _isCalculatingAnalizMotoru,
                onEmaToggle: _toggleEma,
                onDubaiToggle: _toggleDubai,
                onMoneyTraderToggle: _toggleMoneyTrader,
                onKirilimToggle: _toggleKirilim,
                onAnalizMotoruToggle: _toggleAnalizMotoru,
                onSearch: _handleSearch,
                // YENİ: Performans ve fiyat bilgilerini geçir
                performance: _performance,
                high: _high,
                low: _low,
                volume: _volume,
              ),
      ),
    );
  }
}