// lib/components/grafik_katmanlari/core/grafik_yardimci.dart
// Color import
import 'package:flutter/material.dart';


class GrafikYardimci {
  /// Fiyat değerini Y koordinatına çevir
  static double fiyatToY({
    required double fiyat,
    required double minPrice,
    required double maxPrice,
    required double chartHeight,
    double topPadding = 40,
    double bottomPadding = 40,
  }) {
    if (maxPrice <= minPrice) return chartHeight / 2;
    
    final double effectiveHeight = chartHeight - topPadding - bottomPadding;
    final double priceRange = maxPrice - minPrice;
    final double priceFromBottom = fiyat - minPrice;
    final double percentage = priceFromBottom / priceRange;
    
    return topPadding + (effectiveHeight * (1 - percentage));
  }

  /// Mum listesinden min/max fiyat bul ve padding ekle
  static Map<String, double> getMinMaxWithPadding(
    List<dynamic> candles, {
    double paddingPercent = 0.02,
  }) {
    if (candles.isEmpty) {
      return {'min': 0.0, 'max': 100.0};
    }

    double minPrice = double.infinity;
    double maxPrice = double.negativeInfinity;

    for (var candle in candles) {
      if (candle.low < minPrice) minPrice = candle.low;
      if (candle.high > maxPrice) maxPrice = candle.high;
    }

    final double padding = (maxPrice - minPrice) * paddingPercent;
    
    return {
      'min': minPrice - padding,
      'max': maxPrice + padding,
    };
  }

  /// Renk yardımcıları
  static const buyColor = Color(0xFF26a69a);
  static const sellColor = Color(0xFFef5350);
  static const neutralColor = Color(0xFF888888);
  
  /// Fiyat formatla
  static String formatPrice(double price) {
    if (price < 1) {
      return price.toStringAsFixed(5);
    } else if (price < 100) {
      return price.toStringAsFixed(2);
    } else {
      return price.toStringAsFixed(0);
    }
  }

  /// Yüzde formatla
  static String formatPercent(double percent) {
    return "${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%";
  }
}

