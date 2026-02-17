// lib/components/grafik_katmanlari/money_trader_katman.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:candlesticks/candlesticks.dart';
import '../../../services/isciler/money_trader.dart';

class MoneyTraderKatman {
  final MoneyTraderResult result;
  final List<Candle> candles;

  MoneyTraderKatman(this.result, this.candles);

  /// Major High/Low çizgilerini döndür - ✅ DateTime ile
  List<CartesianSeries<dynamic, dynamic>> buildSeries() {
    return [
      // Major High Line - ✅ DateTime ile
      LineSeries<int, DateTime>(
        dataSource: List.generate(candles.length, (i) => i),
        xValueMapper: (i, _) => candles[i].date, // ✅ DateTime
        yValueMapper: (i, _) => 
          result.majorHighLine.isNotEmpty && result.majorHighLine[i] > 0 
            ? result.majorHighLine[i] 
            : null,
        color: const Color(0xFFef5350).withOpacity(0.6),
        width: 1.5,
        dashArray: const [5, 5],
        name: 'Major High',
      ),
      // Major Low Line - ✅ DateTime ile
      LineSeries<int, DateTime>(
        dataSource: List.generate(candles.length, (i) => i),
        xValueMapper: (i, _) => candles[i].date, // ✅ DateTime
        yValueMapper: (i, _) => 
          result.majorLowLine.isNotEmpty && result.majorLowLine[i] > 0 
            ? result.majorLowLine[i] 
            : null,
        color: const Color(0xFF26a69a).withOpacity(0.6),
        width: 1.5,
        dashArray: const [5, 5],
        name: 'Major Low',
      ),
    ];
  }

  // Not: buildSignals metodu kaldırıldı - Syncfusion'ın buildAnnotations() metodu kullanılıyor

  /// İstatistik widget'ı
  Widget buildStats() {
    final stats = result.stats;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329).withOpacity(0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF26A65B).withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💰', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          const Text(
            'MONEY',
            style: TextStyle(
              color: Color(0xFF26A65B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          _buildCompactStat('${result.signals.length}', const Color(0xFF26A65B)),
          const SizedBox(width: 8),
          _buildCompactStat('${stats.winRate.toStringAsFixed(0)}%', 
            stats.winRate >= 50 ? const Color(0xFF26a69a) : const Color(0xFFef5350)),
          const SizedBox(width: 8),
          Text(
            '${stats.wins}W/${stats.losses}L',
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

  // ════════════════════════════════════════════════════════════════════
  // 2. ANNOTATİONS: Sinyal etiketi + hedef fiyat etiketi
  // ════════════════════════════════════════════════════════════════════
  List<CartesianChartAnnotation> buildAnnotations() {
    final annotations = <CartesianChartAnnotation>[];

    for (final sig in result.signals) {
      if (sig.index < 0 || sig.index >= candles.length) continue;
      final candle = candles[sig.index];
      final isBuy = sig.type == 'BUY';
      final sigColor =
          isBuy ? const Color(0xFF26A69A) : const Color(0xFFEF5350);

      // ── Giriş sinyali etiketi ──────────────────────────────────────
      annotations.add(CartesianChartAnnotation(
        widget: _SignalTag(
          label: isBuy ? '💰 AL' : '💰 SAT',
          price: sig.entryPrice,
          color: sigColor,
        ),
        coordinateUnit: CoordinateUnit.point,
        x: candle.date,
        y: isBuy ? candle.low : candle.high,
        verticalAlignment:
            isBuy ? ChartAlignment.far : ChartAlignment.near,
      ));

      // ── Ok ─────────────────────────────────────────────────────────
      annotations.add(CartesianChartAnnotation(
        widget: Icon(
          isBuy ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          color: sigColor,
          size: 34,
        ),
        coordinateUnit: CoordinateUnit.point,
        x: candle.date,
        y: isBuy ? candle.low * 0.998 : candle.high * 1.002,
        verticalAlignment:
            isBuy ? ChartAlignment.far : ChartAlignment.near,
      ));

      // ── Hedef fiyat etiketi ────────────────────────────────────────
      annotations.add(CartesianChartAnnotation(
        widget: _TargetTag(
          price: sig.targetPrice,
          entry: sig.entryPrice,
          color: sigColor,
        ),
        coordinateUnit: CoordinateUnit.point,
        x: candle.date,
        y: sig.targetPrice,
        verticalAlignment: ChartAlignment.center,
        horizontalAlignment: ChartAlignment.near,
      ));
    }

    return annotations;
  }

  // ════════════════════════════════════════════════════════════════════
  // 3. STACK OVERLAY: Kompakt başarı tablosu (sol üst)
  // ════════════════════════════════════════════════════════════════════
  Widget buildStatsOverlay() {
    final s = result.stats;
    final rateColor =
        s.winRate >= 50 ? const Color(0xFF26A69A) : const Color(0xFFEF5350);

    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0E11).withOpacity(0.88),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: const Color(0xFF26A65B).withOpacity(0.5), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: const [
              Text('💰', style: TextStyle(fontSize: 11)),
              SizedBox(width: 4),
              Text('MONEY TRADER',
                  style: TextStyle(
                      color: Color(0xFF26A65B),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 5),
            _tableRow('Sinyal',    '${result.signals.length}', Colors.white70),
            _tableRow('Başarı',    '%${s.winRate.toStringAsFixed(1)}', rateColor),
            _tableRow('W / L',     '${s.wins} / ${s.losses}', Colors.white54),
            _tableRow('Ort. Süre', '${s.avgBarsToTarget} mum',
                const Color(0xFFFFEB3B)),
          ],
        ),
      ),
    );
  }

  Widget _tableRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 62,
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

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 9)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Sinyal giriş etiketi (AL / SAT)
// ════════════════════════════════════════════════════════════════════════
class _SignalTag extends StatelessWidget {
  final String label;
  final double price;
  final Color color;
  const _SignalTag(
      {required this.label, required this.price, required this.color});

  String _fmt(double p) {
    if (p >= 1000) return p.toStringAsFixed(2);
    if (p >= 1) return p.toStringAsFixed(4);
    return p.toStringAsFixed(6);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.92),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 6),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold)),
        Text(_fmt(price),
            style: const TextStyle(color: Colors.white, fontSize: 7)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Hedef fiyat etiketi (HEDEF: xxx +x.x%)
// ════════════════════════════════════════════════════════════════════════
class _TargetTag extends StatelessWidget {
  final double price;
  final double entry;
  final Color color;
  const _TargetTag(
      {required this.price, required this.entry, required this.color});

  String _fmt(double p) {
    if (p >= 1000) return p.toStringAsFixed(2);
    if (p >= 1) return p.toStringAsFixed(4);
    return p.toStringAsFixed(6);
  }

  @override
  Widget build(BuildContext context) {
    final pct = ((price - entry) / entry) * 100;
    final pctStr = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(0.6), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.flag_rounded, color: color, size: 9),
        const SizedBox(width: 3),
        Text('${_fmt(price)}  $pctStr',
            style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}