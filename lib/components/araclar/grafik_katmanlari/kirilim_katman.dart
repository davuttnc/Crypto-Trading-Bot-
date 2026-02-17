// lib/components/araclar/grafik_katmanlari/kirilim_katman.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:candlesticks/candlesticks.dart';
import '../../../services/isciler/kirilim_indikator.dart';

class KirilimKatman {
  final KirilimIndicatorResult result;
  final List<Candle> candles;

  KirilimKatman(this.result, this.candles);

  /// ════════════════════════════════════════════════════════════════════
  /// 1. QUANTUM LINES (3 Hat: Beyaz Trend, Sarı, Mavi ATR)
  /// ════════════════════════════════════════════════════════════════════
  List<CartesianSeries<dynamic, dynamic>> buildSeries() {
    List<CartesianSeries<dynamic, dynamic>> series = [];
    int n = candles.length;

    // Beyaz Trend Line (mainMT)
    series.add(
      LineSeries<int, DateTime>(
        dataSource: List.generate(n, (i) => i),
        xValueMapper: (i, _) => candles[i].date,
        yValueMapper: (i, _) => 
          i < result.quantumLines.trendLine.length 
            ? result.quantumLines.trendLine[i] 
            : null,
        color: Colors.white,
        width: 2,
        name: 'Quantum Trend',
      ),
    );

    // Sarı Hat (mainDL)
    series.add(
      LineSeries<int, DateTime>(
        dataSource: List.generate(n, (i) => i),
        xValueMapper: (i, _) => candles[i].date,
        yValueMapper: (i, _) => 
          i < result.quantumLines.yellowLine.length 
            ? result.quantumLines.yellowLine[i] 
            : null,
        color: const Color(0xFFFFEB3B),
        width: 2,
        name: 'Yellow Line',
      ),
    );

    // Mavi ATR Hattı
    series.add(
      LineSeries<int, DateTime>(
        dataSource: List.generate(n, (i) => i),
        xValueMapper: (i, _) => candles[i].date,
        yValueMapper: (i, _) => 
          i < result.quantumLines.blueAtrLine.length 
            ? result.quantumLines.blueAtrLine[i] 
            : null,
        color: const Color(0xFF3B3EFF),
        width: 2,
        name: 'Blue ATR',
      ),
    );

    return series;
  }

  /// ════════════════════════════════════════════════════════════════════
  /// 2. FİBONACCİ SEVİYELERİ (Yatay Çizgiler)
  /// ════════════════════════════════════════════════════════════════════
  List<CartesianSeries<dynamic, dynamic>> buildFibonacciSeries() {
    List<CartesianSeries<dynamic, dynamic>> series = [];
    int n = candles.length;

    for (var fib in result.fibLevels) {
      series.add(
        LineSeries<int, DateTime>(
          dataSource: List.generate(n, (i) => i),
          xValueMapper: (i, _) => candles[i].date,
          yValueMapper: (i, _) => fib.price,
          color: fib.color.withOpacity(0.7),
          width: fib.level == 0.5 ? 3 : (fib.level == 0.0 || fib.level == 1.0 ? 2 : 1),
          dashArray: fib.level != 0.0 && fib.level != 1.0 && fib.level != 0.5 
            ? <double>[5, 5] 
            : null,
          name: 'Fib ${fib.label}',
        ),
      );
    }

    return series;
  }

  /// ════════════════════════════════════════════════════════════════════
  /// 3. QML SEVİYELERİ (Yatay Çizgiler + Ok İşareti)
  /// ════════════════════════════════════════════════════════════════════
  List<CartesianChartAnnotation> buildQmlAnnotations() {
    List<CartesianChartAnnotation> annotations = [];

    for (var qml in result.qmlLevels) {
      if (qml.index < 0 || qml.index >= candles.length) continue;
      
      // Yatay çizgi (son bara kadar uzatılmış gibi annotation)
      annotations.add(
        CartesianChartAnnotation(
          widget: Container(
            width: 200,
            height: 2,
            color: qml.color.withOpacity(0.6),
          ),
          coordinateUnit: CoordinateUnit.point,
          x: candles[qml.index].date,
          y: qml.price,
        ),
      );

      // Ok işareti ve etiket
      annotations.add(
        CartesianChartAnnotation(
          widget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: qml.color.withOpacity(0.9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  qml.type == "BULL" ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  '${qml.type} (${qml.price.toStringAsFixed(4)})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          coordinateUnit: CoordinateUnit.point,
          x: candles[qml.index].date,
          y: qml.price,
          verticalAlignment: qml.type == "BULL" ? ChartAlignment.far : ChartAlignment.near,
        ),
      );
    }

    return annotations;
  }

  /// ════════════════════════════════════════════════════════════════════
  /// 4. PUMP/DUMP SİNYALLERİ (Büyük Etiketler)
  /// ════════════════════════════════════════════════════════════════════
  List<CartesianChartAnnotation> buildSignalAnnotations() {
    List<CartesianChartAnnotation> annotations = [];

    for (var signal in result.signals) {
      if (signal.index < 0 || signal.index >= candles.length) continue;
      
      final candle = candles[signal.index];
      final isPump = signal.type == "PUMP";

      // Büyük etiket (Pine Script'teki gibi)
      String txt = isPump
          ? "⚡ QUANTUM PUMP ⚡\nKırılım: ${signal.kirilimFiyati.toStringAsFixed(6)}\nAlım Baskısı: %${signal.asFarkPct.toStringAsFixed(1)}\nRSI: ${signal.rsiValue.toStringAsFixed(0)}"
          : "💥 QUANTUM DUMP 💥\nKırılım: ${signal.kirilimFiyati.toStringAsFixed(6)}\nSatım Baskısı: %${signal.asFarkPct.abs().toStringAsFixed(1)}\nRSI: ${signal.rsiValue.toStringAsFixed(0)}";

      annotations.add(
        CartesianChartAnnotation(
          widget: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: signal.labelColor.withOpacity(0.95),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: signal.labelColor.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Text(
              txt,
              style: TextStyle(
                color: isPump ? Colors.black : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          coordinateUnit: CoordinateUnit.point,
          x: candle.date,
          y: isPump ? candle.low : candle.high,
          verticalAlignment: isPump ? ChartAlignment.far : ChartAlignment.near,
        ),
      );

      // Ok işareti
      annotations.add(
        CartesianChartAnnotation(
          widget: Icon(
            isPump ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: signal.labelColor,
            size: 48,
          ),
          coordinateUnit: CoordinateUnit.point,
          x: candle.date,
          y: isPump ? candle.low * 0.997 : candle.high * 1.003,
          verticalAlignment: isPump ? ChartAlignment.far : ChartAlignment.near,
        ),
      );
    }

    return annotations;
  }

  /// ════════════════════════════════════════════════════════════════════
  /// 5. FİBONACCİ ETİKETLERİ (Sağda)
  /// ════════════════════════════════════════════════════════════════════
  List<CartesianChartAnnotation> buildFibonacciLabels() {
    List<CartesianChartAnnotation> annotations = [];

    for (var fib in result.fibLevels) {
      annotations.add(
        CartesianChartAnnotation(
          widget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: fib.color.withOpacity(0.8),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '${fib.label} (${fib.price.toStringAsFixed(2)})',
              style: TextStyle(
                color: fib.level == 0.0 || fib.level == 0.5 ? Colors.white : Colors.black,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          coordinateUnit: CoordinateUnit.point,
          x: candles.last.date,
          y: fib.price,
          horizontalAlignment: ChartAlignment.far,
        ),
      );
    }

    return annotations;
  }

  /// ════════════════════════════════════════════════════════════════════
  /// 6. GÜNLÜK KUTU (Annotation ile)
  /// ════════════════════════════════════════════════════════════════════
  /// ════════════════════════════════════════════════════════════════════
  /// 6. GÜNLÜK KUTU (Box Annotation)
  /// ════════════════════════════════════════════════════════════════════
  List<CartesianChartAnnotation> buildDayBoxAnnotation() {
    List<CartesianChartAnnotation> annotations = [];
    
    if (result.dayBox == null) return annotations;
    
    final box = result.dayBox!;
    
    // Dikdörtgen annotation (kutu)
    annotations.add(
      CartesianChartAnnotation(
        widget: Container(
          width: double.infinity,
          height: 100,
          color: const Color(0xFFE0EE1D).withOpacity(0.15),
          child: const Center(
            child: Text(
              'Previous Day',
              style: TextStyle(
                color: Color(0xFFE0EE1D),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        coordinateUnit: CoordinateUnit.point,
        x: candles[box.startBar].date,
        y: (box.top + box.bottom) / 2,
      ),
    );
    
    return annotations;
  }

  /// ════════════════════════════════════════════════════════════════════
  /// 7. İSTATİSTİK PANELİ (Alt Bar)
  /// ════════════════════════════════════════════════════════════════════
  Widget buildStats() {
    final pumpCount = result.signals.where((s) => s.type == "PUMP").length;
    final dumpCount = result.signals.where((s) => s.type == "DUMP").length;
    final qmlBullCount = result.qmlLevels.where((q) => q.type == "BULL").length;
    final qmlBearCount = result.qmlLevels.where((q) => q.type == "BEAR").length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E2329).withOpacity(0.95),
            const Color(0xFF0B0E11).withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE3F706).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE3F706).withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // QUANTUM İkonu
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F706).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.bolt,
              color: Color(0xFFE3F706),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          
          // PUMP
          _buildStatItem('⚡', pumpCount.toString(), const Color(0xFFE3F706)),
          const SizedBox(width: 12),
          
          // DUMP
          _buildStatItem('💥', dumpCount.toString(), const Color(0xFFFF0000)),
          const SizedBox(width: 12),
          
          // QML BULL
          _buildStatItem('↑', qmlBullCount.toString(), const Color(0xFF00FFCC)),
          const SizedBox(width: 12),
          
          // QML BEAR
          _buildStatItem('↓', qmlBearCount.toString(), const Color(0xFFFF6A6A)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 8. DİP TARAMA SERİLERİ (SL + TP çizgileri)
  // ════════════════════════════════════════════════════════════════════
  List<CartesianSeries<dynamic, dynamic>> buildDipSeries() {
    final n = candles.length;
    final series = <CartesianSeries<dynamic, dynamic>>[];

    // Stop Loss hattı (kırmızı kesik)
    series.add(LineSeries<int, DateTime>(
      dataSource: List.generate(n, (i) => i),
      xValueMapper: (i, _) => candles[i].date,
      yValueMapper: (i, _) {
        if (i >= result.dipLines.slLine.length) return null;
        final v = result.dipLines.slLine[i];
        return v.isNaN ? null : v;
      },
      color: const Color(0xFFEF5350).withOpacity(0.75),
      width: 1,
      dashArray: const <double>[6, 4],
      name: 'Dip SL',
    ));

    // Take Profit hattı (yeşil kesik)
    series.add(LineSeries<int, DateTime>(
      dataSource: List.generate(n, (i) => i),
      xValueMapper: (i, _) => candles[i].date,
      yValueMapper: (i, _) {
        if (i >= result.dipLines.tpLine.length) return null;
        final v = result.dipLines.tpLine[i];
        return v.isNaN ? null : v;
      },
      color: const Color(0xFF00E676).withOpacity(0.75),
      width: 1,
      dashArray: const <double>[6, 4],
      name: 'Dip TP',
    ));

    return series;
  }

  // ════════════════════════════════════════════════════════════════════
  // 9. DİP TARAMA SİNYAL ETİKETLERİ
  // ════════════════════════════════════════════════════════════════════
  List<CartesianChartAnnotation> buildDipAnnotations() {
    final annotations = <CartesianChartAnnotation>[];

    for (final sig in result.dipSignals) {
      if (sig.index < 0 || sig.index >= candles.length) continue;
      final candle = candles[sig.index];
      final isBh = sig.type == DipSignalType.bh;

      // Etiket
      final lines = [
        sig.typeLabel,
        'F: ${sig.price.toStringAsFixed(2)}',
        'H:%${sig.volDegisim.toStringAsFixed(1)}',
        'ADX:${sig.adxVal.toStringAsFixed(0)}',
        if (!isBh && sig.zirveIskonto != null)
          'İsk:%${sig.zirveIskonto!.toStringAsFixed(1)}',
      ];

      annotations.add(CartesianChartAnnotation(
        widget: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: sig.labelColor.withOpacity(0.93),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(color: sig.labelColor.withOpacity(0.35), blurRadius: 6),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((l) {
              final isTitle = l == lines.first;
              return Text(
                l,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: isTitle ? 8 : 7,
                  fontWeight: isTitle ? FontWeight.bold : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
        ),
        coordinateUnit: CoordinateUnit.point,
        x: candle.date,
        y: candle.low,
        verticalAlignment: ChartAlignment.far,
      ));

      // Ok
      annotations.add(CartesianChartAnnotation(
        widget: Icon(Icons.arrow_drop_up, color: sig.labelColor, size: 32),
        coordinateUnit: CoordinateUnit.point,
        x: candle.date,
        y: candle.low * 0.998,
        verticalAlignment: ChartAlignment.far,
      ));
    }

    return annotations;
  }

  // ════════════════════════════════════════════════════════════════════
  // 10. DİP TARAMA İSTATİSTİK PANELİ
  // ════════════════════════════════════════════════════════════════════
  Widget buildDipStats() {
    final s = result.dipStats;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF0D2B1A).withOpacity(0.97),
          const Color(0xFF0B0E11).withOpacity(0.97),
        ]),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.radar, color: Color(0xFF00E676), size: 13),
          const SizedBox(width: 7),
          _dipStat('DİP', s.bhCount.toString(), const Color(0xFF00E676)),
          const SizedBox(width: 9),
          _dipStat('v15', s.v15Count.toString(), const Color(0xFF00E5FF)),
          const SizedBox(width: 9),
          _dipStat('ADX', s.lastAdx.toStringAsFixed(0), const Color(0xFFFFEB3B)),
          const SizedBox(width: 9),
          _dipStat('RSI', s.lastRsi.toStringAsFixed(0), const Color(0xFFFF9800)),
          const SizedBox(width: 9),
          _dipStat('İsk', '%${s.lastIskonto.toStringAsFixed(1)}', const Color(0xFF00E5FF)),
        ],
      ),
    );
  }

  Widget _dipStat(String label, String value, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      const SizedBox(width: 3),
      Text(value, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    ]);
  }}