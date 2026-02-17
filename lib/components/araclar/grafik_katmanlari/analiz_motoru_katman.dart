// lib/components/grafik_katmanlari/analiz_motoru_katman.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:candlesticks/candlesticks.dart';
import '../../../services/isciler/analiz_motoru.dart';

class AnalizMotoruKatman {
  final AnalysisResult result;
  final List<Candle> candles;

  AnalizMotoruKatman(this.result, this.candles);

  /// Quantum trend çizgilerini döndür
  List<CartesianSeries<dynamic, dynamic>> buildSeries() {
    List<CartesianSeries<dynamic, dynamic>> series = [
      // Beyaz Trend Hattı (mainMT)
      LineSeries<int, DateTime>(
        dataSource: List.generate(candles.length, (i) => i),
        xValueMapper: (i, _) => candles[i].date,
        yValueMapper: (i, _) => 
          result.quantumTrendLine.isNotEmpty && result.quantumTrendLine[i] > 0 
            ? result.quantumTrendLine[i] 
            : null,
        color: Colors.white.withOpacity(0.6),
        width: 2,
        name: 'Quantum Trend',
      ),
      
      // Sarı Hat (DL)
      LineSeries<int, DateTime>(
        dataSource: List.generate(candles.length, (i) => i),
        xValueMapper: (i, _) => candles[i].date,
        yValueMapper: (i, _) => 
          result.yellowLine.isNotEmpty && result.yellowLine[i] > 0 
            ? result.yellowLine[i] 
            : null,
        color: const Color(0xFFFFEB3B).withOpacity(0.7),
        width: 2,
        name: 'Yellow Line',
      ),
      
      // Mavi ATR Hattı (PUMP/DUMP için kritik!)
      LineSeries<int, DateTime>(
        dataSource: List.generate(candles.length, (i) => i),
        xValueMapper: (i, _) => candles[i].date,
        yValueMapper: (i, _) => 
          result.blueATRLine.isNotEmpty && result.blueATRLine[i] > 0 
            ? result.blueATRLine[i] 
            : null,
        color: const Color(0xFF3B3EFF),
        width: 2.5,
        name: 'Blue ATR',
      ),
    ];

    // TP çizgilerini ekle (Her sinyal için)
    for (final sig in result.signals) {
      if (sig.index < 0 || sig.index >= candles.length) continue;
      final startDate = candles[sig.index].date;
      
      // TP1 çizgisi
      series.add(
        LineSeries<Map<String, dynamic>, DateTime>(
          dataSource: [
            {'date': startDate, 'value': sig.tp1},
            {'date': startDate.add(const Duration(hours: 24)), 'value': sig.tp1},
          ],
          xValueMapper: (data, _) => data['date'],
          yValueMapper: (data, _) => data['value'],
          color: const Color(0xFF66BB6A).withOpacity(0.5),
          width: 1.5,
          dashArray: [3, 3],
        ),
      );

      // TP2 çizgisi
      series.add(
        LineSeries<Map<String, dynamic>, DateTime>(
          dataSource: [
            {'date': startDate, 'value': sig.tp2},
            {'date': startDate.add(const Duration(hours: 24)), 'value': sig.tp2},
          ],
          xValueMapper: (data, _) => data['date'],
          yValueMapper: (data, _) => data['value'],
          color: const Color(0xFF4CAF50).withOpacity(0.5),
          width: 1.5,
          dashArray: [3, 3],
        ),
      );

      // TP3 çizgisi
      series.add(
        LineSeries<Map<String, dynamic>, DateTime>(
          dataSource: [
            {'date': startDate, 'value': sig.tp3},
            {'date': startDate.add(const Duration(hours: 24)), 'value': sig.tp3},
          ],
          xValueMapper: (data, _) => data['date'],
          yValueMapper: (data, _) => data['value'],
          color: const Color(0xFF2E7D32).withOpacity(0.5),
          width: 2,
          dashArray: [3, 3],
        ),
      );

      // Stop Loss çizgisi
      series.add(
        LineSeries<Map<String, dynamic>, DateTime>(
          dataSource: [
            {'date': startDate, 'value': sig.stopLoss},
            {'date': startDate.add(const Duration(hours: 24)), 'value': sig.stopLoss},
          ],
          xValueMapper: (data, _) => data['date'],
          yValueMapper: (data, _) => data['value'],
          color: const Color(0xFFEF5350).withOpacity(0.5),
          width: 1.5,
          dashArray: [5, 5],
        ),
      );
    }

    return series;
  }

  /// Sinyal annotationları
  List<CartesianChartAnnotation> buildAnnotations() {
    final annotations = <CartesianChartAnnotation>[];

    for (final sig in result.signals) {
      if (sig.index < 0 || sig.index >= candles.length) continue;
      final candle = candles[sig.index];

      // Güç seviyesine göre renk
      Color signalColor;
      IconData icon;
      switch (sig.strength) {
        case SignalStrength.EXPLOSIVE:
          signalColor = const Color(0xFFFF0080); // Pembe - En güçlü!
          icon = Icons.rocket_launch;
          break;
        case SignalStrength.STRONG:
          signalColor = const Color(0xFF00FF41); // Yeşil
          icon = Icons.trending_up;
          break;
        case SignalStrength.MEDIUM:
          signalColor = const Color(0xFFFFEB3B); // Sarı
          icon = Icons.arrow_upward;
          break;
        case SignalStrength.WEAK:
          signalColor = const Color(0xFF90CAF9); // Mavi
          icon = Icons.arrow_upward_outlined;
          break;
      }

      // ── Giriş sinyali etiketi ──────────────────────────────────────
      annotations.add(CartesianChartAnnotation(
        widget: _SignalTag(
          signal: sig,
          color: signalColor,
        ),
        coordinateUnit: CoordinateUnit.point,
        x: candle.date,
        y: candle.low,
        verticalAlignment: ChartAlignment.far,
      ));

      // ── Ok simgesi ─────────────────────────────────────────────────
      annotations.add(CartesianChartAnnotation(
        widget: Icon(
          icon,
          color: signalColor,
          size: sig.strength == SignalStrength.EXPLOSIVE ? 42 : 34,
        ),
        coordinateUnit: CoordinateUnit.point,
        x: candle.date,
        y: candle.low * 0.997,
        verticalAlignment: ChartAlignment.far,
      ));

      // _TradeBoxWidget kaldırıldı - overlay ile gösterilecek
    }

    return annotations;
  }

  /// İstatistik widget'ı
  Widget buildStats() {
    final stats = result.stats;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329).withOpacity(0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFF0080).withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🚀', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          const Text(
            'ANALİZ',
            style: TextStyle(
              color: Color(0xFFFF0080),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          
          // Toplam sinyal
          _buildCompactStat('${stats.totalSignals}', const Color(0xFFFF0080)),
          const SizedBox(width: 8),
          
          // Explosive sinyaller
          if (stats.explosiveSignals > 0) ...[
            _buildCompactStat('⚡${stats.explosiveSignals}', const Color(0xFFFF0080)),
            const SizedBox(width: 8),
          ],
          
          // Strong sinyaller
          if (stats.strongSignals > 0) ...[
            _buildCompactStat('💪${stats.strongSignals}', const Color(0xFF00FF41)),
            const SizedBox(width: 8),
          ],
          
          // Ortalama güç
          Text(
            'Güç: ${stats.avgSignalStrength.toStringAsFixed(1)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String value, Color color) {
    return Text(
      value,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Stack overlay: Başarı tablosu
  Widget buildStatsOverlay() {
    final s = result.stats;

    return Positioned(
      top: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0E11).withOpacity(0.88),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: const Color(0xFFFF0080).withOpacity(0.5), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: const [
              Text('🚀', style: TextStyle(fontSize: 11)),
              SizedBox(width: 4),
              Text('ANALİZ MOTORU',
                  style: TextStyle(
                      color: Color(0xFFFF0080),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 5),
            _tableRow('Toplam', '${s.totalSignals}', Colors.white70),
            _tableRow('⚡ Patlama', '${s.explosiveSignals}', const Color(0xFFFF0080)),
            _tableRow('💪 Güçlü', '${s.strongSignals}', const Color(0xFF00FF41)),
            _tableRow('⚖️ Orta', '${s.mediumSignals}', const Color(0xFFFFEB3B)),
            _tableRow('Güç Ort.', s.avgSignalStrength.toStringAsFixed(1),
                const Color(0xFF90CAF9)),
          ],
        ),
      ),
    );
  }

  /// Grafikte küçük flat işlem kutusu (en güçlü sinyal)
  Widget? buildSignalOverlay() {
    if (result.signals.isEmpty) return null;

    // En güçlü sinyali seç
    final sig = result.signals.reduce((a, b) {
      int _val(SignalStrength s) {
        switch (s) {
          case SignalStrength.EXPLOSIVE: return 4;
          case SignalStrength.STRONG: return 3;
          case SignalStrength.MEDIUM: return 2;
          case SignalStrength.WEAK: return 1;
        }
      }
      return _val(a.strength) >= _val(b.strength) ? a : b;
    });

    Color signalColor;
    String strengthLabel;
    switch (sig.strength) {
      case SignalStrength.EXPLOSIVE:
        signalColor = const Color(0xFFFF0080);
        strengthLabel = '⚡ PATLAMA';
        break;
      case SignalStrength.STRONG:
        signalColor = const Color(0xFF00FF41);
        strengthLabel = '💪 GÜÇLÜ';
        break;
      case SignalStrength.MEDIUM:
        signalColor = const Color(0xFFFFEB3B);
        strengthLabel = '⚖️ ORTA';
        break;
      case SignalStrength.WEAK:
        signalColor = const Color(0xFF90CAF9);
        strengthLabel = '📊 ZAYIF';
        break;
    }

    String fmt(double p) {
      if (p >= 1000) return p.toStringAsFixed(2);
      if (p >= 1) return p.toStringAsFixed(4);
      return p.toStringAsFixed(6);
    }

    String pct(double target, double entry) {
      final v = ((target - entry) / entry) * 100;
      return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%';
    }

    return Positioned(
      bottom: 8,
      left: 8,
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0E11).withOpacity(0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: signalColor.withOpacity(0.7), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık
            Row(
              children: [
                const Text('🚀', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    strengthLabel,
                    style: TextStyle(
                      color: signalColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _flatRow('Giriş', fmt(sig.entryPrice), Colors.white),
            _flatRow('Stop', fmt(sig.stopLoss), const Color(0xFFEF5350),
                sub: pct(sig.stopLoss, sig.entryPrice)),
            const Divider(color: Colors.white12, height: 5, thickness: 0.5),
            _flatRow('TP1', fmt(sig.tp1), const Color(0xFF66BB6A),
                sub: pct(sig.tp1, sig.entryPrice)),
            _flatRow('TP2', fmt(sig.tp2), const Color(0xFF4CAF50),
                sub: pct(sig.tp2, sig.entryPrice)),
            _flatRow('TP3', fmt(sig.tp3), const Color(0xFF2E7D32),
                sub: pct(sig.tp3, sig.entryPrice)),
          ],
        ),
      ),
    );
  }

  Widget _flatRow(String label, String val, Color color, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 8)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(val,
                  style: TextStyle(
                      color: color, fontSize: 8, fontWeight: FontWeight.bold)),
              if (sub != null) ...[
                const SizedBox(width: 2),
                Text(sub,
                    style: TextStyle(
                        color: color.withOpacity(0.7), fontSize: 7)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 8)),
        ),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Sinyal giriş etiketi
// ════════════════════════════════════════════════════════════════════════
class _SignalTag extends StatelessWidget {
  final AnalysisSignal signal;
  final Color color;

  const _SignalTag({
    required this.signal,
    required this.color,
  });

  String _fmt(double p) {
    if (p >= 1000) return p.toStringAsFixed(2);
    if (p >= 1) return p.toStringAsFixed(4);
    return p.toStringAsFixed(6);
  }

  String _getStrengthText() {
    switch (signal.strength) {
      case SignalStrength.EXPLOSIVE:
        return '⚡ PATLAMA';
      case SignalStrength.STRONG:
        return '💪 GÜÇLÜ';
      case SignalStrength.MEDIUM:
        return '⚖️ ORTA';
      case SignalStrength.WEAK:
        return '📊 ZAYIF';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.92),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getStrengthText(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _fmt(signal.entryPrice),
            style: const TextStyle(color: Colors.white, fontSize: 8),
          ),
          if (signal.reasons.length >= 5) ...[
            const SizedBox(height: 2),
            Text(
              '${signal.reasons.length} Koşul',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// İşlem Kutusu (Trade Box) - TP1, TP2, TP3 ve SL
// ════════════════════════════════════════════════════════════════════════
class _TradeBoxWidget extends StatelessWidget {
  final AnalysisSignal signal;
  final Color color;

  const _TradeBoxWidget({
    required this.signal,
    required this.color,
  });

  String _fmt(double p) {
    if (p >= 1000) return p.toStringAsFixed(2);
    if (p >= 1) return p.toStringAsFixed(4);
    return p.toStringAsFixed(6);
  }

  @override
  Widget build(BuildContext context) {
    final entry = signal.entryPrice;
    final tp1Pct = ((signal.tp1 - entry) / entry) * 100;
    final tp2Pct = ((signal.tp2 - entry) / entry) * 100;
    final tp3Pct = ((signal.tp3 - entry) / entry) * 100;
    final slPct = ((entry - signal.stopLoss) / entry) * 100;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E11).withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.8), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                'İŞLEM BİLGİSİ',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          
          // Giriş
          _buildRow('💰 Giriş:', _fmt(entry), Colors.white),
          const SizedBox(height: 3),
          
          // Stop Loss
          _buildRow('🛑 Stop:', _fmt(signal.stopLoss), const Color(0xFFEF5350),
              suffix: ' (-${slPct.toStringAsFixed(2)}%)'),
          
          const Divider(color: Colors.white24, height: 8),
          
          // TP1
          _buildRow('🟢 TP1:', _fmt(signal.tp1), const Color(0xFF66BB6A),
              suffix: ' (+${tp1Pct.toStringAsFixed(2)}%)'),
          const SizedBox(height: 3),
          
          // TP2
          _buildRow('🟢 TP2:', _fmt(signal.tp2), const Color(0xFF4CAF50),
              suffix: ' (+${tp2Pct.toStringAsFixed(2)}%)'),
          const SizedBox(height: 3),
          
          // TP3
          _buildRow('🟢 TP3:', _fmt(signal.tp3), const Color(0xFF2E7D32),
              suffix: ' (+${tp3Pct.toStringAsFixed(2)}%)'),
          
          const Divider(color: Colors.white24, height: 8),
          
          // ADX & RSI
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMiniStat('ADX', signal.adx.toStringAsFixed(1), 
                  const Color(0xFFFFEB3B)),
              const SizedBox(width: 8),
              _buildMiniStat('RSI', signal.rsi.toStringAsFixed(0), 
                  const Color(0xFF90CAF9)),
              const SizedBox(width: 8),
              _buildMiniStat('Hacim', '+${signal.volumeChange.toStringAsFixed(0)}%', 
                  const Color(0xFFFF9800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, Color valueColor, {String? suffix}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (suffix != null)
          Text(
            suffix,
            style: TextStyle(
              color: valueColor.withOpacity(0.7),
              fontSize: 8,
            ),
          ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 7,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}