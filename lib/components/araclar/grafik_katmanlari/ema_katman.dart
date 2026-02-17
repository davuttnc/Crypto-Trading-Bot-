// lib/components/grafik_katmanlari/ema_katman.dart
// PYTHON DESKTOP GİBİ - KUTU GÖRÜNÜMÜ
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:candlesticks/candlesticks.dart';
import '../../../services/isciler/ema_hesaplama.dart';

class EmaKatman {
  final EmaHesaplamaResult result;
  final List<Candle> candles;

  EmaKatman(this.result, this.candles);

  /// EMA çizgileri - Güvenli index kontrolü ile
  List<CartesianSeries<dynamic, dynamic>> buildSeries() {
    List<CartesianSeries<dynamic, dynamic>> series = [];
    final int len = candles.length;

    // EMA Short (9) - Mavi - ✅ DateTime ile
    if (result.emaShort.length >= len) {
      series.add(
        LineSeries<int, DateTime>(
          dataSource: List.generate(len, (i) => i),
          xValueMapper: (i, _) => candles[i].date, // ✅ DateTime
          yValueMapper: (i, _) {
            final v = result.emaShort[i];
            return v == 0.0 ? null : v;
          },
          color: const Color(0xFF2196F3),
          width: 2,
          name: 'EMA 9',
        ),
      );
    }

    // EMA Long (21) - Kırmızı - ✅ DateTime ile
    if (result.emaLong.length >= len) {
      series.add(
        LineSeries<int, DateTime>(
          dataSource: List.generate(len, (i) => i),
          xValueMapper: (i, _) => candles[i].date, // ✅ DateTime
          yValueMapper: (i, _) {
            final v = result.emaLong[i];
            return v == 0.0 ? null : v;
          },
          color: const Color(0xFFEF5350),
          width: 2,
          name: 'EMA 21',
        ),
      );
    }

    // Range Filter - Sarı - ✅ DateTime ile
    if (result.rngFilt.length >= len) {
      series.add(
        LineSeries<int, DateTime>(
          dataSource: List.generate(len, (i) => i),
          xValueMapper: (i, _) => candles[i].date, // ✅ DateTime
          yValueMapper: (i, _) {
            final v = result.rngFilt[i];
            return v == 0.0 ? null : v;
          },
          color: const Color(0xFFFFEB3B),
          width: 2,
          name: 'Range',
        ),
      );
    }

    return series;
  }

  /// Volume Zone KUTULARI - Şeffaf renkli alanlar - ✅ DateTime ile
  List<CartesianSeries<dynamic, dynamic>> buildVolumeZoneSeries() {
    List<CartesianSeries<dynamic, dynamic>> zoneSeries = [];

    if (result.volZones.isEmpty) return zoneSeries;

    // HER ZONE İÇİN KUTU ÇİZ
    for (var zone in result.volZones) {
      Color zoneColor = zone.type == "SUPPORT" 
        ? const Color(0xFF26A69A)  // Yeşil
        : const Color(0xFFEF5350); // Kırmızı

      // RangeAreaSeries - şeffaf kutu - ✅ DateTime ile
      zoneSeries.add(
        RangeAreaSeries<int, DateTime>(
          dataSource: List.generate(candles.length, (i) => i),
          xValueMapper: (i, _) => candles[i].date, // ✅ DateTime
          highValueMapper: (i, _) => zone.top,
          lowValueMapper: (i, _) => zone.bottom,
          color: zoneColor.withOpacity(0.15),
          borderColor: zoneColor.withOpacity(0.6),
          borderWidth: 1.5,
          borderDrawMode: RangeAreaBorderMode.all,
        ),
      );
    }

    print('📊 Volume Zones: ${result.volZones.length} kutu çizildi');
    return zoneSeries;
  }

  /// Volume Zone etiketleri - "S" ve "R" harfleri
  List<CartesianChartAnnotation> buildVolumeZoneAnnotations() {
    List<CartesianChartAnnotation> annotations = [];

    for (var zone in result.volZones) {
      Color labelColor = zone.type == "SUPPORT" 
        ? const Color(0xFF26A69A) 
        : const Color(0xFFEF5350);

      // Sağ tarafta küçük etiket
      annotations.add(
        CartesianChartAnnotation(
          widget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: labelColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: Colors.white.withOpacity(0.3), 
                width: 0.5
              ),
            ),
            child: Text(
              zone.type == "SUPPORT" ? "S" : "R",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          coordinateUnit: CoordinateUnit.point,
          x: candles.length - 1,
          y: (zone.top + zone.bottom) / 2,
          horizontalAlignment: ChartAlignment.far,
        ),
      );
    }

    return annotations;
  }

  /// AL/SAT Sinyalleri - Python gibi KUTU şeklinde etiketler
  List<CartesianChartAnnotation> buildSignalAnnotations() {
    List<CartesianChartAnnotation> annotations = [];

    for (var signal in result.emaSignals) {
      final isBuy = signal.type == "BUY";
      final color = isBuy 
        ? const Color(0xFF26A69A) 
        : const Color(0xFFEF5350);
      
      // Python'daki gibi KUTU etiket
      annotations.add(
        CartesianChartAnnotation(
          widget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withOpacity(0.4), 
                width: 1
              ),
            ),
            child: Text(
              isBuy ? 'AL' : 'SAT',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          coordinateUnit: CoordinateUnit.point,
          x: signal.index,
          y: signal.price,
          verticalAlignment: isBuy ? ChartAlignment.far : ChartAlignment.near,
        ),
      );
    }

    print('📍 Sinyaller: ${result.emaSignals.length} AL/SAT etiketi eklendi');
    return annotations;
  }

  /// İstatistik widget - Alt barda
  Widget buildStats() {
    final buyCount = result.emaSignals.where((s) => s.type == "BUY").length;
    final sellCount = result.emaSignals.where((s) => s.type == "SELL").length;
    final zoneCount = result.volZones.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329).withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.5), 
          width: 1.5
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // EMA ikonu
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.show_chart, 
              color: Color(0xFF2196F3), 
              size: 16
            ),
          ),
          const SizedBox(width: 10),
          
          // BUY
          _buildStatItem('↑', buyCount.toString(), const Color(0xFF26a69a)),
          const SizedBox(width: 12),
          
          // SELL
          _buildStatItem('↓', sellCount.toString(), const Color(0xFFef5350)),
          const SizedBox(width: 12),
          
          // S/R zones
          _buildStatItem('S/R', zoneCount.toString(), Colors.white70),
        ],
      ),
    );
  }

  Widget _buildStatItem(String icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          icon,
          style: TextStyle(
            color: color, 
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}