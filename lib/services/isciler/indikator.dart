// lib/services/isciler/indikator.dart
import 'package:candlesticks/candlesticks.dart';
import 'dart:math';

// ══════════════════════════════════════════════════════════════════════════════
// DUBAI ÇUKULATASI İNDİKATÖRÜ :)]
// Pine Script'ten Dart'a tam çeviri
// ══════════════════════════════════════════════════════════════════════════════

class DubaiTargets {
  final int index;
  final String type; // "BUY" veya "SELL"
  final double entry;
  final double sl;
  final double tp1;
  final double tp2;
  final double tp3;

  DubaiTargets({
    required this.index,
    required this.type,
    required this.entry,
    required this.sl,
    required this.tp1,
    required this.tp2,
    required this.tp3,
  });
}

class DubaiIndicatorResult {
  final List<double> trendLine;
  final List<int> trendDir;
  final List<int> buySignals;
  final List<int> sellSignals;
  final DubaiTargets? activeTargets;
  final String nextDirection; // "UP", "DOWN" veya "NEUTRAL"

  // Follow Line verileri
  final List<double> followLine;
  final List<int> followLineBuySignals;
  final List<int> followLineSellSignals;

  DubaiIndicatorResult({
    required this.trendLine,
    required this.trendDir,
    required this.buySignals,
    required this.sellSignals,
    this.activeTargets,
    required this.nextDirection,
    required this.followLine,
    required this.followLineBuySignals,
    required this.followLineSellSignals,
  });
}

class DubaiCikolatasiIndicator {
  // ─────────────────────────────────────────────────────────────────────────
  // ATR — O(n) sliding window (eskisi O(n×period) idi)
  // ─────────────────────────────────────────────────────────────────────────
  static List<double> _calculateAtr(List<Candle> candles, int period) {
    if (candles.length < period + 1) return List.filled(candles.length, 0.0);

    // True Range dizisini hesapla
    final List<double> tr = List.filled(candles.length, 0.0);
    for (int i = 1; i < candles.length; i++) {
      final double high = candles[i].high;
      final double low = candles[i].low;
      final double prevClose = candles[i - 1].close;
      tr[i] = max(
        high - low,
        max((high - prevClose).abs(), (low - prevClose).abs()),
      );
    }

    // İlk pencere toplamı
    double windowSum = 0.0;
    for (int i = 1; i <= period; i++) windowSum += tr[i];

    final List<double> atr = List.filled(candles.length, 0.0);
    atr[period] = windowSum / period;

    // Sliding window ile O(n)
    for (int i = period + 1; i < candles.length; i++) {
      windowSum += tr[i] - tr[i - period];
      atr[i] = windowSum / period;
    }

    return atr;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SMA — O(n) sliding window (eskisi O(n×period) idi)
  // ─────────────────────────────────────────────────────────────────────────
  static List<double> _calculateSma(List<double> values, int period) {
    if (values.length < period) return List.filled(values.length, 0.0);

    final List<double> sma = List.filled(values.length, 0.0);

    // İlk pencere
    double windowSum = 0.0;
    for (int i = 0; i < period; i++) windowSum += values[i];
    sma[period - 1] = windowSum / period;

    // Sliding window
    for (int i = period; i < values.length; i++) {
      windowSum += values[i] - values[i - period];
      sma[i] = windowSum / period;
    }

    return sma;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STDEV — değişmedi (SMA artık O(n) olduğu için bu da daha hızlı)
  // ─────────────────────────────────────────────────────────────────────────
  static List<double> _calculateStdev(List<double> values, int period) {
    final List<double> stdev = List.filled(values.length, 0.0);
    final List<double> sma = _calculateSma(values, period);

    for (int i = period - 1; i < values.length; i++) {
      double sum = 0.0;
      for (int j = 0; j < period; j++) {
        sum += pow(values[i - j] - sma[i], 2);
      }
      stdev[i] = sqrt(sum / period);
    }

    return stdev;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bollinger Bands
  // ─────────────────────────────────────────────────────────────────────────
  static Map<String, List<double>> _calculateBollingerBands(
    List<double> closes,
    int period,
    double deviation,
  ) {
    final List<double> middle = _calculateSma(closes, period);
    final List<double> stdev = _calculateStdev(closes, period);

    final List<double> upper = List.filled(closes.length, 0.0);
    final List<double> lower = List.filled(closes.length, 0.0);

    for (int i = 0; i < closes.length; i++) {
      upper[i] = middle[i] + (stdev[i] * deviation);
      lower[i] = middle[i] - (stdev[i] * deviation);
    }

    return {'upper': upper, 'middle': middle, 'lower': lower};
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ANA HESAPLAMA
  //
  // ÖNEMLİ: candlesticks paketi mumları NEWEST-FIRST sıralar (index 0 = en yeni).
  // Tüm hesaplamalar OLDEST-FIRST bekler. Bu yüzden:
  //   1. Girişte listeyi ters çevir  → en eski[0], en yeni[n-1]
  //   2. Hesapla
  //   3. Sinyal/hedef indekslerini orijinal (newest-first) pozisyona çevir:
  //      originalIdx = n - 1 - hesaplamaIdx
  // ─────────────────────────────────────────────────────────────────────────
  static DubaiIndicatorResult hesapla(
    List<Candle> candles, {
    int length = 10,
    int targetOffset = 0,
    int atrPeriod = 5,
    int bbPeriod = 21,
    double bbDeviation = 1.0,
    bool useAtrFilter = true,
  }) {
    print("🔍 Dubai İndikatör başlıyor...");
    print("  📊 Toplam mum: ${candles.length}");

    // FIX: Minimum mum kontrolü - 50'den az varsa boş dön
    if (candles.isEmpty || candles.length < 50) {
      print("  ❌ YETERSİZ VERİ: En az 50 mum gerekli, mevcut: ${candles.length}");
      print("  ⚠️  activeTargets: NULL (yetersiz veri)");
      return DubaiIndicatorResult(
        trendLine: [],
        trendDir: [],
        buySignals: [],
        sellSignals: [],
        activeTargets: null,
        nextDirection: "NEUTRAL",
        followLine: [],
        followLineBuySignals: [],
        followLineSellSignals: [],
      );
    }

    // FIX: candlesticks paketi newest-first verir → hesaplama için ters çevir
    final List<Candle> sorted = candles.reversed.toList(); // oldest[0] … newest[n-1]
    final int n = sorted.length;

    // İndeks dönüşüm yardımcısı: hesaplama indeksi → orijinal (newest-first) indeksi
    int toOriginal(int i) => n - 1 - i;

    final List<double> highs = sorted.map((c) => c.high).toList();
    final List<double> lows = sorted.map((c) => c.low).toList();
    final List<double> closes = sorted.map((c) => c.close).toList();

    // ═══════════════════════════════════════════════════════════════════
    // KISIM 1: TREND SİSTEMİ
    // ═══════════════════════════════════════════════════════════════════

    int atrLongPeriod;
    String quality;

    if (n >= 500) {
      atrLongPeriod = 200;
      quality = "⭐⭐⭐⭐⭐ Mükemmel (500 mum)";
    } else if (n >= 300) {
      atrLongPeriod = 150;
      quality = "⭐⭐⭐⭐ Çok İyi (300 mum)";
    } else if (n >= 200) {
      atrLongPeriod = 100;
      quality = "⭐⭐⭐ İyi (200 mum)";
    } else if (n >= 100) {
      atrLongPeriod = 50;
      quality = "⭐⭐ Orta (100 mum)";
    } else {
      atrLongPeriod = 20;
      quality = "⭐ Minimum (50-99 mum)";
    }

    print("  📈 ATR Periyodu: $atrLongPeriod");
    print("  💎 Kalite: $quality");

    final List<double> atrLong = _calculateAtr(sorted, atrLongPeriod);
    final List<double> atrValue = _calculateSma(atrLong, atrLongPeriod);
    for (int i = 0; i < atrValue.length; i++) {
      atrValue[i] *= 0.8;
    }

    final List<double> smaHigh = _calculateSma(highs, length);
    final List<double> smaLow = _calculateSma(lows, length);

    for (int i = 0; i < n; i++) {
      smaHigh[i] += atrValue[i];
      smaLow[i] -= atrValue[i];
    }

    final List<int> trend = List.filled(n, 1);
    final List<double> trendLine = List.filled(n, 0.0);

    int currTrend = 1;
    int trendChanges = 0;

    for (int i = 1; i < n; i++) {
      final double c = closes[i];
      final double sh = smaHigh[i];
      final double sl = smaLow[i];

      if (sh == 0 || sl == 0) {
        trend[i] = currTrend;
        trendLine[i] = 0;
        continue;
      }

      final int prevTrend = currTrend;

      if (c > sh && closes[i - 1] <= smaHigh[i - 1]) {
        currTrend = 1;
        if (prevTrend != currTrend) trendChanges++;
      } else if (c < sl && closes[i - 1] >= smaLow[i - 1]) {
        currTrend = -1;
        if (prevTrend != currTrend) trendChanges++;
      }

      trend[i] = currTrend;
      trendLine[i] = currTrend == 1 ? sl : sh;
    }

    print("  🔄 Trend değişimi: $trendChanges kez");

    // Sinyal indeksleri → orijinal (newest-first) pozisyona çevrilmiş
    final List<int> buySignals = [];
    final List<int> sellSignals = [];

    for (int i = 1; i < n; i++) {
      if (trend[i] == 1 && trend[i - 1] == -1) {
        buySignals.add(toOriginal(i));
        print("  ✅ AL sinyali: #${toOriginal(i)} (${sorted[i].date})");
      }
      if (trend[i] == -1 && trend[i - 1] == 1) {
        sellSignals.add(toOriginal(i));
        print("  ⛔ SAT sinyali: #${toOriginal(i)} (${sorted[i].date})");
      }
    }

    print("  📊 Toplam sinyal: ${buySignals.length} AL, ${sellSignals.length} SAT");

    // trendLine ve trendDir'i orijinal sırayla döndür (newest-first)
    final List<double> trendLineOrig = trendLine.reversed.toList();
    final List<int> trendDirOrig = trend.reversed.toList();

    // ═══════════════════════════════════════════════════════════════════
    // KISIM 2: FOLLOW LINE
    // ═══════════════════════════════════════════════════════════════════

    final List<double> atrShort = _calculateAtr(sorted, atrPeriod);
    final Map<String, List<double>> bb =
        _calculateBollingerBands(closes, bbPeriod, bbDeviation);

    final List<double> followLineData = List.filled(n, 0.0);
    final List<int> followLineBuySignals = [];
    final List<int> followLineSellSignals = [];

    int bbSignal = 0;
    int iTrend = 0;

    for (int i = 1; i < n; i++) {
      if (closes[i] > bb['upper']![i]) {
        bbSignal = 1;
      } else if (closes[i] < bb['lower']![i]) {
        bbSignal = -1;
      }

      if (bbSignal == 1) {
        followLineData[i] = useAtrFilter
            ? lows[i] - atrShort[i]
            : lows[i];
        if (followLineData[i] < followLineData[i - 1]) {
          followLineData[i] = followLineData[i - 1];
        }
      }

      if (bbSignal == -1) {
        followLineData[i] = useAtrFilter
            ? highs[i] + atrShort[i]
            : highs[i];
        if (followLineData[i] > followLineData[i - 1]) {
          followLineData[i] = followLineData[i - 1];
        }
      }

      if (followLineData[i] > followLineData[i - 1]) {
        iTrend = 1;
      } else if (followLineData[i] < followLineData[i - 1]) {
        iTrend = -1;
      }

      int prevTrend = 0;
      if (followLineData[i - 1] > (i > 1 ? followLineData[i - 2] : 0)) {
        prevTrend = 1;
      } else if (followLineData[i - 1] < (i > 1 ? followLineData[i - 2] : 0)) {
        prevTrend = -1;
      }

      // Follow line sinyalleri → orijinal pozisyona çevir
      if (prevTrend == -1 && iTrend == 1) followLineBuySignals.add(toOriginal(i));
      if (prevTrend == 1 && iTrend == -1) followLineSellSignals.add(toOriginal(i));
    }

    // followLineData orijinal sırayla (newest-first)
    final List<double> followLineOrig = followLineData.reversed.toList();

    // ═══════════════════════════════════════════════════════════════════
    // KISIM 3: HEDEF KUTULARI
    // Sinyal taraması sorted (oldest-first) üzerinden yapılır,
    // aktif hedef indeksi orijinale (newest-first) çevrilir.
    // ═══════════════════════════════════════════════════════════════════

    DubaiTargets? activeTargets;
    
    // FIX: En yeni 150 mumu tara (önceki 100 yerine - daha fazla şans)
    final int scanStart = max(0, n - 150);
    
    print("  🎯 Hedef kutusu taraması: Son ${n - scanStart} mum kontrol ediliyor...");

    for (int i = n - 1; i >= scanStart; i--) {
      final int origIdx = toOriginal(i); // newest-first'teki pozisyon

      if (buySignals.contains(origIdx)) {
        final double atr = atrValue[i];
        final double entryPrice = closes[i];
        activeTargets = DubaiTargets(
          index: origIdx,   // trading_chart.dart bunu candles[origIdx] için kullanır
          type: "BUY",
          entry: entryPrice,
          sl: smaLow[i],
          tp1: entryPrice + atr * (5 + targetOffset),
          tp2: entryPrice + atr * (10 + targetOffset * 2),
          tp3: entryPrice + atr * (15 + targetOffset * 3),
        );
        print("  ✅ Aktif BUY hedefi bulundu!");
        print("     Index: #$origIdx (${sorted[i].date})");
        print("     Giriş: ${entryPrice.toStringAsFixed(4)}");
        print("     Stop: ${activeTargets.sl.toStringAsFixed(4)}");
        print("     TP1: ${activeTargets.tp1.toStringAsFixed(4)}");
        break;
      } else if (sellSignals.contains(origIdx)) {
        final double atr = atrValue[i];
        final double entryPrice = closes[i];
        activeTargets = DubaiTargets(
          index: origIdx,
          type: "SELL",
          entry: entryPrice,
          sl: smaHigh[i],
          tp1: entryPrice - atr * (5 + targetOffset),
          tp2: entryPrice - atr * (10 + targetOffset * 2),
          tp3: entryPrice - atr * (15 + targetOffset * 3),
        );
        print("  ✅ Aktif SELL hedefi bulundu!");
        print("     Index: #$origIdx (${sorted[i].date})");
        print("     Giriş: ${entryPrice.toStringAsFixed(4)}");
        print("     Stop: ${activeTargets.sl.toStringAsFixed(4)}");
        print("     TP1: ${activeTargets.tp1.toStringAsFixed(4)}");
        break;
      }
    }

    // FIX: activeTargets null ise uyarı ver
    if (activeTargets == null) {
      print("  ⚠️  activeTargets: NULL (Son ${n - scanStart} mumda sinyal bulunamadı)");
      print("  💡 Çözüm: Daha fazla mum verisi gerekebilir (şu an: $n)");
    }

    // ═══════════════════════════════════════════════════════════════════
    // KISIM 4: TAHMİN SİSTEMİ (Next Direction Prediction)
    // ═══════════════════════════════════════════════════════════════════
    String nextDirection = "NEUTRAL";
    
    if (n > 10) {
      // Son trend yönü
      final int lastTrend = trend.last;
      
      // Momentum hesaplamaları (son 5 mum vs son 10 mum)
      final double shortMomentum = closes.last - closes[n - 5];
      final double longMomentum = closes.last - closes[n - 10];
      final double lastAtr = atrValue.last;
      
      // Trend ve momentum kombinasyonu
      if (lastTrend == 1 && shortMomentum > 0 && longMomentum > 0) {
        // Güçlü yükseliş trendi
        nextDirection = "UP";
      } else if (lastTrend == -1 && shortMomentum < 0 && longMomentum < 0) {
        // Güçlü düşüş trendi
        nextDirection = "DOWN";
      } else if (lastTrend == 1 && shortMomentum > lastAtr * 0.5) {
        // Yukarı trend ve kısa vadeli güçlü momentum
        nextDirection = "UP";
      } else if (lastTrend == -1 && shortMomentum < -lastAtr * 0.5) {
        // Aşağı trend ve kısa vadeli güçlü momentum
        nextDirection = "DOWN";
      } else if (longMomentum > lastAtr * 1.5) {
        // Çok güçlü yukarı momentum
        nextDirection = "UP";
      } else if (longMomentum < -lastAtr * 1.5) {
        // Çok güçlü aşağı momentum
        nextDirection = "DOWN";
      }
    }

    print("  🔮 Tahmin: $nextDirection");
    print("✅ Dubai İndikatör hesaplama tamamlandı!\n");

    return DubaiIndicatorResult(
      trendLine: trendLineOrig,   // newest-first sırada
      trendDir: trendDirOrig,     // newest-first sırada
      buySignals: buySignals,     // orijinal (newest-first) indeksler
      sellSignals: sellSignals,   // orijinal (newest-first) indeksler
      activeTargets: activeTargets,
      nextDirection: nextDirection, // Tahmin eklendi
      followLine: followLineOrig, // newest-first sırada
      followLineBuySignals: followLineBuySignals,
      followLineSellSignals: followLineSellSignals,
    );
  }
}