// lib/services/isciler/money_trader.dart
import 'package:candlesticks/candlesticks.dart';
import 'dart:math';

// ══════════════════════════════════════════════════════════════════════════════
// MONEY TRADER KING — Pine Script'ten Dart'a çeviri
// candlesticks paketi NEWEST-FIRST sıralar → girişte reversed() ile düzeltilir
// ══════════════════════════════════════════════════════════════════════════════

class MoneyTraderSignal {
  final int index;        // orijinal (newest-first) indeks
  final String type;      // "BUY" veya "SELL"
  final double entryPrice;
  final double targetPrice;
  final double majorLevel; // kırılan direnç/destek seviyesi

  MoneyTraderSignal({
    required this.index,
    required this.type,
    required this.entryPrice,
    required this.targetPrice,
    required this.majorLevel,
  });
}

class MoneyTraderStats {
  final int wins;
  final int losses;
  final double winRate;   // 0–100
  final int avgBarsToTarget;

  MoneyTraderStats({
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.avgBarsToTarget,
  });
}

class MoneyTraderResult {
  final List<MoneyTraderSignal> signals;
  final List<double> majorHighLine; // newest-first, son lookback döneminin en yükseği
  final List<double> majorLowLine;  // newest-first, son lookback döneminin en düşüğü
  final MoneyTraderStats stats;

  MoneyTraderResult({
    required this.signals,
    required this.majorHighLine,
    required this.majorLowLine,
    required this.stats,
  });
}

class MoneyTraderIndicator {
  // ─────────────────────────────────────────────────────────────────────────
  // ATR — O(n) sliding window, oldest-first
  // ─────────────────────────────────────────────────────────────────────────
  static List<double> _calculateAtr(List<Candle> candles, int period) {
    if (candles.length < period + 1) return List.filled(candles.length, 0.0);

    final List<double> tr = List.filled(candles.length, 0.0);
    for (int i = 1; i < candles.length; i++) {
      final double h  = candles[i].high;
      final double l  = candles[i].low;
      final double pc = candles[i - 1].close;
      tr[i] = max(h - l, max((h - pc).abs(), (l - pc).abs()));
    }

    double sum = 0.0;
    for (int i = 1; i <= period; i++) sum += tr[i];

    final List<double> atr = List.filled(candles.length, 0.0);
    atr[period] = sum / period;

    for (int i = period + 1; i < candles.length; i++) {
      sum += tr[i] - tr[i - period];
      atr[i] = sum / period;
    }
    return atr;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Volume SMA — O(n) sliding window, oldest-first
  // ─────────────────────────────────────────────────────────────────────────
  static List<double> _calculateVolumeSma(List<Candle> candles, int period) {
    if (candles.length < period) return List.filled(candles.length, 0.0);

    final List<double> sma = List.filled(candles.length, 0.0);
    double sum = 0.0;
    for (int i = 0; i < period; i++) sum += candles[i].volume;
    sma[period - 1] = sum / period;

    for (int i = period; i < candles.length; i++) {
      sum += candles[i].volume - candles[i - period].volume;
      sma[i] = sum / period;
    }
    return sma;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ANA HESAPLAMA
  // ─────────────────────────────────────────────────────────────────────────
  static MoneyTraderResult hesapla(
    List<Candle> candles, {
    int lookbackPeriod  = 30,
    double volMultiplier = 1.5,
    int atrLength       = 14,
    double targetATRMult = 3.0,
    int maxBars         = 50,
  }) {
    if (candles.isEmpty || candles.length < lookbackPeriod + atrLength + 5) {
      return MoneyTraderResult(
        signals: [],
        majorHighLine: [],
        majorLowLine: [],
        stats: MoneyTraderStats(wins: 0, losses: 0, winRate: 0, avgBarsToTarget: 0),
      );
    }

    // FIX: newest-first → oldest-first
    final List<Candle> sorted = candles.reversed.toList();
    final int n = sorted.length;
    int toOriginal(int i) => n - 1 - i;

    final List<double> atr     = _calculateAtr(sorted, atrLength);
    final List<double> volSma  = _calculateVolumeSma(sorted, 20);

    // ═══════════════════════════════════════════════════════════════════
    // majorHigh / majorLow: Pine'da high[1] ve low[1] ile lookback alınır
    // Dart'ta: i-1'den geriye lookbackPeriod mumun max/min'i
    // ═══════════════════════════════════════════════════════════════════
    final List<double> majorHighSorted = List.filled(n, 0.0);
    final List<double> majorLowSorted  = List.filled(n, double.infinity);

    for (int i = lookbackPeriod; i < n; i++) {
      double mh = double.negativeInfinity;
      double ml = double.infinity;
      // [1..lookbackPeriod] önceki mumlar (bar_index-1 offset — Pine uyumu)
      for (int j = 1; j <= lookbackPeriod; j++) {
        mh = max(mh, sorted[i - j].high);
        ml = min(ml, sorted[i - j].low);
      }
      majorHighSorted[i] = mh;
      majorLowSorted[i]  = ml;
    }

    // ═══════════════════════════════════════════════════════════════════
    // SİNYAL ÜRETME
    // bullishBreak: close[i] > majorHigh[i] && close[i-1] <= majorHigh[i-1] && yüksek hacim
    // bearishBreak: close[i] < majorLow[i]  && close[i-1] >= majorLow[i-1]  && yüksek hacim
    // ═══════════════════════════════════════════════════════════════════
    final List<MoneyTraderSignal> signals = [];

    int wins = 0, losses = 0, totalBarsToWin = 0;

    // Aktif hedef takibi (Pine'daki var active_target mantığı)
    double? activeTarget;
    int?    startBar;
    bool    activeIsLong = false;

    for (int i = lookbackPeriod + 1; i < n; i++) {
      final double close     = sorted[i].close;
      final double closePrev = sorted[i - 1].close;
      final double mh        = majorHighSorted[i];
      final double ml        = majorLowSorted[i];
      final double mhPrev    = majorHighSorted[i - 1];
      final double mlPrev    = majorLowSorted[i - 1];
      final double vol       = sorted[i].volume;
      final double avgVol    = volSma[i];
      final double atrVal    = atr[i];

      if (avgVol == 0 || atrVal == 0) continue;

      final bool isHighVol    = vol > avgVol * volMultiplier;
      final bool bullishBreak = close > mh && closePrev <= mhPrev && isHighVol;
      final bool bearishBreak = close < ml && closePrev >= mlPrev && isHighVol;

      // Aktif hedef takibi — Pine uyumu
      if (activeTarget != null && startBar != null) {
        final bool hitTarget = activeIsLong
            ? sorted[i].high >= activeTarget!
            : sorted[i].low  <= activeTarget!;
        final bool timedOut = (i - startBar!) >= maxBars;

        if (hitTarget) {
          wins++;
          totalBarsToWin += i - startBar!;
          activeTarget = null;
          startBar     = null;
        } else if (timedOut) {
          losses++;
          activeTarget = null;
          startBar     = null;
        }
      }

      // Yeni sinyal
      if ((bullishBreak || bearishBreak) && activeTarget == null) {
        final double targetPrice = bullishBreak
            ? close + atrVal * targetATRMult
            : close - atrVal * targetATRMult;

        signals.add(MoneyTraderSignal(
          index:        toOriginal(i),
          type:         bullishBreak ? "BUY" : "SELL",
          entryPrice:   close,
          targetPrice:  targetPrice,
          majorLevel:   bullishBreak ? mh : ml,
        ));

        activeTarget   = targetPrice;
        startBar       = i;
        activeIsLong   = bullishBreak;
      }
    }

    // İstatistik
    final int total   = wins + losses;
    final double rate = total > 0 ? (wins / total) * 100 : 0.0;
    final int avgBars = wins > 0 ? (totalBarsToWin / wins).round() : 0;

    // majorHigh/Low dizilerini newest-first'e çevir
    final List<double> majorHighOrig = majorHighSorted.reversed.toList();
    final List<double> majorLowOrig  = majorLowSorted.reversed
        .map((v) => v == double.infinity ? 0.0 : v)
        .toList();

    print("✅ MoneyTrader: ${signals.length} sinyal | W:$wins L:$losses | Oran: ${rate.toStringAsFixed(1)}%");

    return MoneyTraderResult(
      signals: signals,
      majorHighLine: majorHighOrig,
      majorLowLine: majorLowOrig,
      stats: MoneyTraderStats(
        wins: wins,
        losses: losses,
        winRate: rate,
        avgBarsToTarget: avgBars,
      ),
    );
  }
}