// lib/pages/trade.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:candlesticks/candlesticks.dart';
import '../services/api/binance_api.dart';
import '../services/api/mexc_api.dart';
import '../services/isciler/analiz_motoru.dart';
import 'dart:async';

// ══════════════════════════════════════════════════════════════════════════════
// TRADE SAYFASI - OTOMATİK TARAMA VE SİNYAL LİSTESİ
// ══════════════════════════════════════════════════════════════════════════════

class BulunanSinyal {
  final String symbol;
  final AnalysisSignal signal;
  final DateTime bulunanZaman;
  bool okundu;

  BulunanSinyal({
    required this.symbol,
    required this.signal,
    required this.bulunanZaman,
    this.okundu = false,
  });
}

// Top-level function for isolate
AnalysisResult _analizIsolate(List<Candle> candles) {
  return AnalizMotoru.hesapla(candles);
}

class TradePage extends StatefulWidget {
  final Function(String)? onCoinSelected;
  
  const TradePage({super.key, this.onCoinSelected});

  @override
  State<TradePage> createState() => _TradePageState();
}

class _TradePageState extends State<TradePage> {
  final BinanceApiService _binance = BinanceApiService();
  final MexcApiService _mexc = MexcApiService();
  
  bool _isScanning = false;
  int _scannedCount = 0;
  int _totalCoins = 0;
  String _currentScanning = "";
  
  final List<BulunanSinyal> _sinyaller = [];
  Timer? _scanTimer;
  
  // Tarama ayarları
  String _selectedTimeframe = "15m";
  SignalStrength _minStrength = SignalStrength.STRONG;
  
  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TARAMAYA BAŞLA
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _startScanning() async {
    if (_isScanning) {
      // Durdur
      _scanTimer?.cancel();
      setState(() {
        _isScanning = false;
        _currentScanning = "";
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _scannedCount = 0;
      _sinyaller.clear();
    });

    try {
      // 1. Coin listesini al
      debugPrint("📋 Coin listesi alınıyor...");
      final tickers = await _binance.getMarketTickers();
      
      if (!mounted) return;
      
      // Top 100 coin'i filtrele (hacim sırasına göre)
      final sortedTickers = tickers
          .where((t) => double.parse(t.quoteVolume) > 1000000) // Min 1M hacim
          .toList()
        ..sort((a, b) => double.parse(b.quoteVolume).compareTo(double.parse(a.quoteVolume)));
      
      final topCoins = sortedTickers.take(100).toList();
      
      setState(() {
        _totalCoins = topCoins.length;
      });
      
      debugPrint("🎯 ${topCoins.length} coin taranacak");

      // 2. Her coini tara
      int index = 0;
      _scanTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (!_isScanning || index >= topCoins.length) {
          timer.cancel();
          setState(() {
            _isScanning = false;
            _currentScanning = "";
          });
          debugPrint("✅ Tarama tamamlandı! ${_sinyaller.length} sinyal bulundu.");
          return;
        }

        final ticker = topCoins[index];
        await _scanCoin(ticker.symbol);
        
        setState(() {
          _scannedCount = index + 1;
        });
        
        index++;
      });

    } catch (e) {
      debugPrint("❌ Tarama hatası: $e");
      setState(() {
        _isScanning = false;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TEK COİN TARAMA
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _scanCoin(String symbol) async {
    try {
      setState(() {
        _currentScanning = symbol;
      });

      // Mum verilerini çek
      List<Candle> candles = [];
      
      // MEXC'den dene
      try {
        candles = await _mexc.fetchCandles(symbol, _selectedTimeframe);
      } catch (e) {
        // Başarısızsa Binance'den dene
        try {
          candles = await _binance.fetchCandles(symbol, _selectedTimeframe);
        } catch (e2) {
          debugPrint("⚠️ $symbol veri alınamadı");
          return;
        }
      }

      if (candles.length < 100) return;

      // Analiz et
      final result = await compute(_analizIsolate, candles);

      // Güçlü sinyalleri filtrele
      final strongSignals = result.signals.where((s) {
        switch (_minStrength) {
          case SignalStrength.EXPLOSIVE:
            return s.strength == SignalStrength.EXPLOSIVE;
          case SignalStrength.STRONG:
            return s.strength == SignalStrength.EXPLOSIVE || 
                   s.strength == SignalStrength.STRONG;
          case SignalStrength.MEDIUM:
            return s.strength != SignalStrength.WEAK;
          case SignalStrength.WEAK:
            return true;
        }
      }).toList();

      // Sinyalleri listeye ekle
      if (strongSignals.isNotEmpty && mounted) {
        setState(() {
          for (final signal in strongSignals) {
            _sinyaller.add(BulunanSinyal(
              symbol: symbol,
              signal: signal,
              bulunanZaman: DateTime.now(),
            ));
          }
          // En güçlüden zayıfa sırala
          _sinyaller.sort((a, b) => _getStrengthValue(b.signal.strength)
              .compareTo(_getStrengthValue(a.signal.strength)));
        });
        
        debugPrint("🚀 $symbol: ${strongSignals.length} sinyal bulundu!");
      }

    } catch (e) {
      debugPrint("❌ $symbol analiz hatası: $e");
    }
  }

  int _getStrengthValue(SignalStrength s) {
    switch (s) {
      case SignalStrength.EXPLOSIVE: return 4;
      case SignalStrength.STRONG: return 3;
      case SignalStrength.MEDIUM: return 2;
      case SignalStrength.WEAK: return 1;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2329),
        elevation: 0,
        title: const Text(
          '🚀 OTOMATİK TARAMA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        actions: [
          // Ayarlar menüsü
          PopupMenuButton<SignalStrength>(
            icon: const Icon(Icons.tune, color: Colors.cyanAccent),
            color: const Color(0xFF1E2329),
            onSelected: (value) {
              setState(() {
                _minStrength = value;
              });
            },
            itemBuilder: (context) => [
              _buildMenuItem(SignalStrength.EXPLOSIVE, '⚡ Sadece PATLAMA'),
              _buildMenuItem(SignalStrength.STRONG, '💪 GÜÇLÜ ve Üstü'),
              _buildMenuItem(SignalStrength.MEDIUM, '⚖️ ORTA ve Üstü'),
              _buildMenuItem(SignalStrength.WEAK, '📊 Tümü'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ══════════════════════════════════════════════════════════════
          // 1. TARAMA BAŞLAT BUTONU VE DURUM
          // ══════════════════════════════════════════════════════════════
          _buildScanButton(),
          
          // ══════════════════════════════════════════════════════════════
          // 2. TARANAN COİNLER VE İLERLEME
          // ══════════════════════════════════════════════════════════════
          if (_isScanning || _scannedCount > 0)
            _buildScanProgress(),
          
          // ══════════════════════════════════════════════════════════════
          // 3. BULUNAN SİNYALLER LİSTESİ
          // ══════════════════════════════════════════════════════════════
          Expanded(
            child: _sinyaller.isEmpty
                ? _buildEmptyState()
                : _buildSignalList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TARAMA BUTONU
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildScanButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: _startScanning,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isScanning 
              ? const Color(0xFFEF5350) 
              : const Color(0xFF00FF41),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: _isScanning ? 8 : 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isScanning ? Icons.stop_circle : Icons.play_circle_filled,
              color: Colors.black,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              _isScanning 
                  ? 'TARAMAYI DURDUR' 
                  : 'TARAMAYA BAŞLA ($_totalCoins Coin)',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TARAMA İLERLEMESİ
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildScanProgress() {
    final progress = _totalCoins > 0 ? _scannedCount / _totalCoins : 0.0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.cyanAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İlerleme çubuğu
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_scannedCount/$_totalCoins',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Taranıyor göstergesi
          if (_currentScanning.isNotEmpty)
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Taranıyor: $_currentScanning',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          
          // Bulunan sinyal sayısı
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bulunan Sinyaller: ${_sinyaller.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _selectedTimeframe.toUpperCase(),
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOŞ DURUM
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.radar,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _isScanning 
                ? 'Coinler taranıyor...' 
                : 'Henüz tarama yapılmadı',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TARAMAYA BAŞLA butonuna basın',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SİNYAL LİSTESİ
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSignalList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sinyaller.length,
      itemBuilder: (context, index) {
        final bulunanSinyal = _sinyaller[index];
        return _buildSignalCard(bulunanSinyal);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SİNYAL KARTI
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSignalCard(BulunanSinyal bulunanSinyal) {
    final signal = bulunanSinyal.signal;
    
    // Güç rengi
    Color strengthColor;
    String strengthText;
    switch (signal.strength) {
      case SignalStrength.EXPLOSIVE:
        strengthColor = const Color(0xFFFF0080);
        strengthText = '⚡ PATLAMA';
        break;
      case SignalStrength.STRONG:
        strengthColor = const Color(0xFF00FF41);
        strengthText = '💪 GÜÇLÜ';
        break;
      case SignalStrength.MEDIUM:
        strengthColor = const Color(0xFFFFEB3B);
        strengthText = '⚖️ ORTA';
        break;
      case SignalStrength.WEAK:
        strengthColor = const Color(0xFF90CAF9);
        strengthText = '📊 ZAYIF';
        break;
    }

    return GestureDetector(
      onTap: () {
        // Grafik sayfasına yönlendir
        setState(() {
          bulunanSinyal.okundu = true;
        });
        widget.onCoinSelected?.call(bulunanSinyal.symbol);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2329),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: bulunanSinyal.okundu 
                ? Colors.white12 
                : strengthColor.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: bulunanSinyal.okundu ? [] : [
            BoxShadow(
              color: strengthColor.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            // Başlık - Coin ve Güç
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: strengthColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  // Coin ismi
                  Expanded(
                    child: Text(
                      bulunanSinyal.symbol.replaceAll('USDT', '/USDT'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  // Güç seviyesi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: strengthColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      strengthText,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // İşlem Bilgileri
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Giriş
                  _buildInfoRow(
                    '💰 Giriş:',
                    _fmt(signal.entryPrice),
                    Colors.white,
                  ),
                  const Divider(color: Colors.white12, height: 16),
                  
                  // Stop Loss
                  _buildInfoRow(
                    '🛑 Stop:',
                    _fmt(signal.stopLoss),
                    const Color(0xFFEF5350),
                    suffix: _getPct(signal.stopLoss, signal.entryPrice),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // TP'ler
                  _buildInfoRow(
                    '🟢 TP1:',
                    _fmt(signal.tp1),
                    const Color(0xFF66BB6A),
                    suffix: _getPct(signal.tp1, signal.entryPrice),
                  ),
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    '🟢 TP2:',
                    _fmt(signal.tp2),
                    const Color(0xFF4CAF50),
                    suffix: _getPct(signal.tp2, signal.entryPrice),
                  ),
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    '🟢 TP3:',
                    _fmt(signal.tp3),
                    const Color(0xFF2E7D32),
                    suffix: _getPct(signal.tp3, signal.entryPrice),
                  ),
                  
                  const Divider(color: Colors.white12, height: 16),
                  
                  // İndikatörler
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniIndicator('ADX', signal.adx.toStringAsFixed(1), Colors.orange),
                      _buildMiniIndicator('RSI', signal.rsi.toStringAsFixed(0), Colors.blue),
                      _buildMiniIndicator('Hacim', '+${signal.volumeChange.toStringAsFixed(0)}%', Colors.purple),
                      _buildMiniIndicator('Koşul', '${signal.reasons.length}/7', strengthColor),
                    ],
                  ),
                ],
              ),
            ),

            // Alt bilgi - Zaman
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getTimeAgo(bulunanSinyal.bulunanZaman),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.touch_app, size: 14, color: Colors.cyanAccent),
                      SizedBox(width: 4),
                      Text(
                        'Grafiğe Git',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // YARDIMCI WİDGET'LAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildInfoRow(String label, String value, Color color, {String? suffix}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (suffix != null) ...[
              const SizedBox(width: 6),
              Text(
                suffix,
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMiniIndicator(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  PopupMenuItem<SignalStrength> _buildMenuItem(SignalStrength value, String text) {
    return PopupMenuItem<SignalStrength>(
      value: value,
      child: Row(
        children: [
          if (_minStrength == value)
            const Icon(Icons.check, color: Colors.cyanAccent, size: 16),
          if (_minStrength == value)
            const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: _minStrength == value ? Colors.cyanAccent : Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FORMATTERS
  // ═══════════════════════════════════════════════════════════════════════════
  String _fmt(double p) {
    if (p >= 1000) return '\$${p.toStringAsFixed(2)}';
    if (p >= 1) return '\$${p.toStringAsFixed(4)}';
    return '\$${p.toStringAsFixed(6)}';
  }

  String _getPct(double target, double entry) {
    final pct = ((target - entry) / entry) * 100;
    return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%';
  }

  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    if (diff.inHours < 24) return '${diff.inHours}s önce';
    return '${diff.inDays}g önce';
  }
}