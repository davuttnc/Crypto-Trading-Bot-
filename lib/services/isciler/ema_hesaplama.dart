// lib/services/isciler/ema_hesaplama.dart
import 'package:candlesticks/candlesticks.dart';
import 'dart:math';

// ══════════════════════════════════════════════════════════════════════════════
// Pine Script'ten tam çeviri: EMA + Volume S/R + RSI + Range Filter
// ══════════════════════════════════════════════════════════════════════════════

class EmaSignal {
  final int index;   // orijinal (newest-first) indeks
  final String type; // "BUY", "SELL", "BUY_RSI", "SELL_RSI", "BUY_RANGE", "SELL_RANGE"
  final double price;

  EmaSignal({
    required this.index,
    required this.type,
    required this.price,
  });
}

class VolumeZone {
  final String type;       // "SUPPORT" veya "RESISTANCE"
  final double top;
  final double bottom;
  final int startIndex;    // Zone'un başladığı indeks
  final int endIndex;      // Zone'un bittiği indeks (genelde son mum = 0)
  final double volScore;
  final String label;
  bool isBreakout;
  bool isHold;
  
  VolumeZone({
    required this.type,
    required this.top,
    required this.bottom,
    required this.startIndex,
    required this.endIndex,
    required this.volScore,
    required this.label,
    this.isBreakout = false,
    this.isHold = false,
  });
}

class EmaHesaplamaResult {
  final List<double> emaShort;
  final List<double> emaLong;
  final List<EmaSignal> emaSignals;
  final List<EmaSignal> rsiSignals;
  final List<EmaSignal> rangeSignals;
  final List<VolumeZone> volZones;
  final List<double> rngFilt;     // Range Filter line
  final List<double> hBand;       // Upper band
  final List<double> lBand;       // Lower band

  EmaHesaplamaResult({
    required this.emaShort,
    required this.emaLong,
    required this.emaSignals,
    required this.rsiSignals,
    required this.rangeSignals,
    required this.volZones,
    required this.rngFilt,
    required this.hBand,
    required this.lBand,
  });
}

class EmaHesaplamaService {
  
  // ─────────────────────────────────────────────────────────────────────────
  // EMA Hesaplama
  // ─────────────────────────────────────────────────────────────────────────
  static List<double> _calculateEma(List<double> closes, int period) {
    if (closes.isEmpty || period <= 0 || closes.length < period) return [];

    final List<double> ema = List.filled(closes.length, 0.0);
    final double multiplier = 2.0 / (period + 1);

    // SMA ile başla
    double sum = 0.0;
    for (int i = 0; i < period; i++) sum += closes[i];
    ema[period - 1] = sum / period;

    for (int i = period; i < closes.length; i++) {
      ema[i] = (closes[i] - ema[i - 1]) * multiplier + ema[i - 1];
    }

    return ema;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RSI Hesaplama (RMA kullanarak - Pine Script tarzı)
  // ─────────────────────────────────────────────────────────────────────────
  static List<double> _rma(List<double> series, int length) {
    if (series.isEmpty || length <= 0) return List.filled(series.length, 0.0);

    final List<double> rma = List.filled(series.length, 0.0);
    final double alpha = 1.0 / length;

    double sum = 0.0;
    for (int i = 0; i < min(length, series.length); i++) sum += series[i];
    if (series.length >= length) rma[length - 1] = sum / length;

    for (int i = length; i < series.length; i++) {
      rma[i] = alpha * series[i] + (1 - alpha) * rma[i - 1];
    }

    return rma;
  }

  static List<double> _calculateRsi(List<double> closes, int length) {
    if (closes.length < length + 1) return List.filled(closes.length, 0.0);

    List<double> changes = [];
    for (int i = 1; i < closes.length; i++) {
      changes.add(closes[i] - closes[i - 1]);
    }

    List<double> ups = [0.0];
    List<double> downs = [0.0];
    for (double change in changes) {
      ups.add(max(change, 0.0));
      downs.add(max(-change, 0.0));
    }

    List<double> upRma = _rma(ups, length);
    List<double> downRma = _rma(downs, length);

    List<double> rsi = List.filled(closes.length, 0.0);
    for (int i = length; i < closes.length; i++) {
      if (downRma[i] == 0) {
        rsi[i] = 100.0;
      } else if (upRma[i] == 0) {
        rsi[i] = 0.0;
      } else {
        double rs = upRma[i] / downRma[i];
        rsi[i] = 100 - (100 / (1 + rs));
      }
    }

    return rsi;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ATR Hesaplama
  // ─────────────────────────────────────────────────────────────────────────
  static List<double> _calculateAtr(List<Candle> candles, int period) {
    if (candles.length < period + 1) return List.filled(candles.length, 0.0);

    final List<double> tr = [0.0]; // İlk mum için TR = high - low
    tr[0] = candles[0].high - candles[0].low;

    for (int i = 1; i < candles.length; i++) {
      final double h = candles[i].high;
      final double l = candles[i].low;
      final double pc = candles[i - 1].close;
      tr.add(max(h - l, max((h - pc).abs(), (l - pc).abs())));
    }

    final List<double> atr = List.filled(candles.length, 0.0);
    double sum = 0.0;
    for (int i = 0; i < min(period, tr.length); i++) sum += tr[i];
    if (tr.length >= period) atr[period - 1] = sum / period;

    for (int i = period; i < candles.length; i++) {
      atr[i] = (atr[i - 1] * (period - 1) + tr[i]) / period;
    }

    return atr;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Range Filter (Pine Script mantığı)
  // ─────────────────────────────────────────────────────────────────────────
  static List<double> _smoothRange(List<double> src, int per, double mult) {
    List<double> diff = [0.0];
    for (int i = 1; i < src.length; i++) {
      diff.add((src[i] - src[i - 1]).abs());
    }

    List<double> avrng = _calculateEma(diff, per);
    int wper = per * 2 - 1;
    List<double> smrng = _calculateEma(avrng, wper);

    for (int i = 0; i < smrng.length; i++) {
      smrng[i] *= mult;
    }

    return smrng;
  }

  static List<double> _rangeFilter(List<double> src, List<double> r) {
    List<double> rngfilt = List.from(src);
    
    for (int i = 1; i < src.length; i++) {
      double prev = rngfilt[i - 1];
      double curr = src[i];
      double ri = i < r.length ? r[i] : r.last;

      if (curr > prev) {
        rngfilt[i] = (curr - ri < prev) ? prev : curr - ri;
      } else {
        rngfilt[i] = (curr + ri > prev) ? prev : curr + ri;
      }
    }

    return rngfilt;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pivot Hesaplama (Pine Script tarzı - close bazlı)
  // ─────────────────────────────────────────────────────────────────────────
  static bool _isPivotHigh(List<double> series, int index, int lookback) {
    if (index < lookback || index + lookback >= series.length) return false;
    
    double center = series[index];
    for (int i = index - lookback; i <= index + lookback; i++) {
      if (i != index && series[i] >= center) return false;
    }
    return true;
  }

  static bool _isPivotLow(List<double> series, int index, int lookback) {
    if (index < lookback || index + lookback >= series.length) return false;
    
    double center = series[index];
    for (int i = index - lookback; i <= index + lookback; i++) {
      if (i != index && series[i] <= center) return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ANA HESAPLAMA
  // ─────────────────────────────────────────────────────────────────────────
  static EmaHesaplamaResult emaHesapla(
    List<Candle> candles, {
    int shortLen = 9,
    int longLen = 21,
    int rsiLen = 14,
    double rsiSellTh = 69.0,
    double rsiBuyTh = 31.0,
    int rangePer = 100,
    double rangeMult = 3.0,
    int lookback = 20,
    int volLen = 2,
    double boxWidth = 1.0,
  }) {
    if (candles.isEmpty || candles.length < max(longLen, rangePer) + 10) {
      return EmaHesaplamaResult(
        emaShort: [],
        emaLong: [],
        emaSignals: [],
        rsiSignals: [],
        rangeSignals: [],
        volZones: [],
        rngFilt: [],
        hBand: [],
        lBand: [],
      );
    }

    // Veriyi ters çevir (oldest-first)
    // Sıfır hacimli mumları EMA hesabından hariç tut ama grafik için koru
    final List<Candle> sorted = candles.reversed.toList();
    final int n = sorted.length;
    int toOriginal(int i) => n - 1 - i;

    final List<double> closes = sorted.map((c) => c.close).toList();
    final List<double> highs = sorted.map((c) => c.high).toList();
    final List<double> lows = sorted.map((c) => c.low).toList();
    final List<double> opens = sorted.map((c) => c.open).toList();
    final List<double> volumes = sorted.map((c) => c.volume).toList();

    // ═══════════════════════════════════════════════════════════════════
    // 1. EMA HESAPLAMA VE SİNYALLER
    // ═══════════════════════════════════════════════════════════════════
    final List<double> emaShort = _calculateEma(closes, shortLen);
    final List<double> emaLong = _calculateEma(closes, longLen);

    final List<EmaSignal> emaSignals = [];
    for (int i = longLen; i < n; i++) {
      if (emaShort[i - 1] < emaLong[i - 1] && emaShort[i] > emaLong[i]) {
        emaSignals.add(EmaSignal(
          index: toOriginal(i),
          type: "BUY",
          price: lows[i],
        ));
      } else if (emaShort[i - 1] > emaLong[i - 1] && emaShort[i] < emaLong[i]) {
        emaSignals.add(EmaSignal(
          index: toOriginal(i),
          type: "SELL",
          price: highs[i],
        ));
      }
    }

    // ═══════════════════════════════════════════════════════════════════
    // 2. RSI VE SİNYALLER
    // ═══════════════════════════════════════════════════════════════════
    final List<double> rsi = _calculateRsi(closes, rsiLen);
    final List<EmaSignal> rsiSignals = [];
    
    for (int i = rsiLen + 1; i < n; i++) {
      // SELL RSI (crossunder 69)
      if (rsi[i - 1] >= rsiSellTh && rsi[i] < rsiSellTh) {
        rsiSignals.add(EmaSignal(
          index: toOriginal(i),
          type: "SELL_RSI",
          price: highs[i],
        ));
      }
      // BUY RSI (crossover 31)
      if (rsi[i - 1] <= rsiBuyTh && rsi[i] > rsiBuyTh) {
        rsiSignals.add(EmaSignal(
          index: toOriginal(i),
          type: "BUY_RSI",
          price: lows[i],
        ));
      }
    }

    // ═══════════════════════════════════════════════════════════════════
    // 3. RANGE FILTER VE SİNYALLER
    // ═══════════════════════════════════════════════════════════════════
    final List<double> smrng = _smoothRange(closes, rangePer, rangeMult);
    final List<double> rngFilt = _rangeFilter(closes, smrng);

    final List<int> upward = List.filled(n, 0);
    final List<int> downward = List.filled(n, 0);

    for (int i = 1; i < n; i++) {
      if (rngFilt[i] > rngFilt[i - 1]) {
        upward[i] = upward[i - 1] + 1;
        downward[i] = 0;
      } else if (rngFilt[i] < rngFilt[i - 1]) {
        downward[i] = downward[i - 1] + 1;
        upward[i] = 0;
      } else {
        upward[i] = upward[i - 1];
        downward[i] = downward[i - 1];
      }
    }

    // Bands
    final List<double> hBand = List.filled(n, 0.0);
    final List<double> lBand = List.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      hBand[i] = rngFilt[i] + (i < smrng.length ? smrng[i] : 0);
      lBand[i] = rngFilt[i] - (i < smrng.length ? smrng[i] : 0);
    }

    // Sinyaller
    final List<EmaSignal> rangeSignals = [];
    int condIni = 0;

    for (int i = 1; i < n; i++) {
      bool longCond = (closes[i] > rngFilt[i]) && 
                      ((closes[i] > closes[i - 1] && upward[i] > 0) || 
                       (closes[i] < closes[i - 1] && upward[i] > 0));
      
      bool shortCond = (closes[i] < rngFilt[i]) && 
                       ((closes[i] < closes[i - 1] && downward[i] > 0) || 
                        (closes[i] > closes[i - 1] && downward[i] > 0));

      if (longCond) condIni = 1;
      else if (shortCond) condIni = -1;

      bool longCondition = longCond && condIni == -1;
      bool shortCondition = shortCond && condIni == 1;

      if (longCondition) {
        rangeSignals.add(EmaSignal(
          index: toOriginal(i),
          type: "BUY_RANGE",
          price: lows[i],
        ));
      }
      if (shortCondition) {
        rangeSignals.add(EmaSignal(
          index: toOriginal(i),
          type: "SELL_RANGE",
          price: highs[i],
        ));
      }
    }

    // ═══════════════════════════════════════════════════════════════════
    // 4. VOLUME ZONES (S/R KUTULARI) - İYİLEŞTİRİLMİŞ MANTIK
    // ═══════════════════════════════════════════════════════════════════
    final List<VolumeZone> volZones = [];
    
    // Ortalama hacim hesapla (BURAYA EKLENDİ!)
    double totalVolume = 0.0;
    for (int i = 0; i < n; i++) {
      totalVolume += volumes[i];
    }
    double avgVol = totalVolume / n;
    double volThreshold = avgVol * 1.5; // Eşik: Ortalama hacmin 1.5 katı

    // ATR (200 period - Pine script'te)
    final List<double> atr = _calculateAtr(sorted, 200);

    // Zone oluştur - BASİT VE ETKİLİ FİLTRE
    for (int i = lookback; i < n - lookback; i++) {
      bool isPivotLowClose = _isPivotLow(closes, i, lookback);
      bool isPivotHighClose = _isPivotHigh(closes, i, lookback);
      
      double withd = atr[i] * boxWidth;
      
      // Hacim kontrolü - basit ve etkili
      bool hasHighVolume = volumes[i] > volThreshold;

      // SUPPORT Zone (Pivot Low + Yüksek Hacim)
      if (isPivotLowClose && hasHighVolume) {
        double supportLevel = closes[i];
        double supportLevel1 = supportLevel - withd;

        volZones.add(VolumeZone(
          type: "SUPPORT",
          top: supportLevel,
          bottom: supportLevel1,
          startIndex: toOriginal(i - lookback),
          endIndex: 0, // Son muma kadar uzat
          volScore: volumes[i] / avgVol, // Hacim oranı
          label: "Vol: ${(volumes[i] / avgVol).toStringAsFixed(1)}x",
        ));
      }

      // RESISTANCE Zone (Pivot High + Yüksek Hacim)
      if (isPivotHighClose && hasHighVolume) {
        double resistanceLevel = closes[i];
        double resistanceLevel1 = resistanceLevel + withd;

        volZones.add(VolumeZone(
          type: "RESISTANCE",
          top: resistanceLevel1,
          bottom: resistanceLevel,
          startIndex: toOriginal(i - lookback),
          endIndex: 0, // Son muma kadar uzat
          volScore: volumes[i] / avgVol, // Hacim oranı
          label: "Vol: ${(volumes[i] / avgVol).toStringAsFixed(1)}x",
        ));
      }
    }

    // En güçlü 8 zone'u seç
    volZones.sort((a, b) => b.volScore.abs().compareTo(a.volScore.abs()));
    final List<VolumeZone> finalZones = volZones.take(8).toList();

    print("✅ EMA Güncellendi:");
    print("  - EMA Sinyalleri: ${emaSignals.length}");
    print("  - RSI Sinyalleri: ${rsiSignals.length}");
    print("  - Range Sinyalleri: ${rangeSignals.length}");
    print("  - Volume Zones: ${finalZones.length}");

    // Newest-first'e çevir
    return EmaHesaplamaResult(
      emaShort: emaShort.reversed.toList(),
      emaLong: emaLong.reversed.toList(),
      emaSignals: emaSignals,
      rsiSignals: rsiSignals,
      rangeSignals: rangeSignals,
      volZones: finalZones,
      rngFilt: rngFilt.reversed.toList(),
      hBand: hBand.reversed.toList(),
      lBand: lBand.reversed.toList(),
    );
  }
}