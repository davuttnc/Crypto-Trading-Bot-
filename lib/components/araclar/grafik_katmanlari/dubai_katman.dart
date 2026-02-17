// lib/components/araclar/grafik_katmanlari/dubai_katman.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:candlesticks/candlesticks.dart';
import '../../../services/isciler/indikator.dart';

class DubaiKatman {
  final DubaiIndicatorResult result;
  final List<Candle> candles;

  DubaiKatman(this.result, this.candles);

  /// BUY/SELL Sinyalleri - Üçgenler ve etiketler
  List<CartesianChartAnnotation> buildSignalAnnotations() {
    List<CartesianChartAnnotation> annotations = [];

    // BUY sinyalleri - Yeşil üçgen ve AL etiketi
    for (var idx in result.buySignals) {
      if (idx < 0 || idx >= candles.length) continue;
      
      final candle = candles[idx];
      
      // AL etiketi (kutucuk)
      annotations.add(
        CartesianChartAnnotation(
          widget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF26A69A).withOpacity(0.9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF26A69A).withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Text(
              'AL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          coordinateUnit: CoordinateUnit.point,
          x: candle.date,
          y: candle.low * 0.995, // Mumun altına yerleştir
          verticalAlignment: ChartAlignment.far,
        ),
      );

      // Yeşil üçgen (ok)
      annotations.add(
        CartesianChartAnnotation(
          widget: Icon(
            Icons.arrow_drop_up,
            color: const Color(0xFF26A69A),
            size: 36,
          ),
          coordinateUnit: CoordinateUnit.point,
          x: candle.date,
          y: candle.low * 0.997,
          verticalAlignment: ChartAlignment.far,
        ),
      );
    }

    // SELL sinyalleri - Kırmızı üçgen ve SAT etiketi
    for (var idx in result.sellSignals) {
      if (idx < 0 || idx >= candles.length) continue;
      
      final candle = candles[idx];
      
      // SAT etiketi (kutucuk)
      annotations.add(
        CartesianChartAnnotation(
          widget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350).withOpacity(0.9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF5350).withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Text(
              'SAT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          coordinateUnit: CoordinateUnit.point,
          x: candle.date,
          y: candle.high * 1.005,
          verticalAlignment: ChartAlignment.near,
        ),
      );

      // Kırmızı üçgen (ok)
      annotations.add(
        CartesianChartAnnotation(
          widget: Icon(
            Icons.arrow_drop_down,
            color: const Color(0xFFEF5350),
            size: 36,
          ),
          coordinateUnit: CoordinateUnit.point,
          x: candle.date,
          y: candle.high * 1.003,
          verticalAlignment: ChartAlignment.near,
        ),
      );
    }

    print('📍 Dubai Sinyalleri: ${result.buySignals.length} AL, ${result.sellSignals.length} SAT eklendi');
    return annotations;
  }

  /// FIX: Pozisyon Kutusu Annotation'ı KALDIRILDI
  /// Artık trading_chart.dart'ta Stack/Positioned ile gösteriliyor
  /// Bu method boş liste döndürür (geriye uyumluluk için)
  List<CartesianChartAnnotation> buildPositionBoxAnnotation() {
    // Log kontrol
    if (result.activeTargets == null) {
      print('⚠️ activeTargets null - kutu gösterilmiyor');
    } else {
      print('✅ activeTargets var - Stack\'te gösterilecek');
    }
    
    // Boş liste dön - kutu artık annotation değil, Stack widget
    return [];
  }

  /// İstatistik Widget - Alt barda
  Widget buildStats() {
    final buyCount = result.buySignals.length;
    final sellCount = result.sellSignals.length;
    final hasActive = result.activeTargets != null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329).withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFC107).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dubai ikonu
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.auto_graph,
              color: Color(0xFFFFC107),
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          
          // BUY
          _buildStatItem('↑', buyCount.toString(), const Color(0xFF26A69A)),
          const SizedBox(width: 10),
          
          // SELL
          _buildStatItem('↓', sellCount.toString(), const Color(0xFFEF5350)),
          const SizedBox(width: 10),
          
          // Aktif pozisyon
          if (hasActive) ...[
            _buildStatItem(
              '🎯',
              result.activeTargets!.type,
              result.activeTargets!.type == "BUY"
                  ? const Color(0xFF26A69A)
                  : const Color(0xFFEF5350),
            ),
          ],
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
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}