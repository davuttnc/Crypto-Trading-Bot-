// lib/services/isciler/kirilim_indikator.dart
import 'package:candlesticks/candlesticks.dart';
import 'package:flutter/material.dart'; // ✅ Color için
import 'dart:math' as math;

// ════════════════════════════════════════════════════════════════════════
// QUANTUM PUMP&DUMP V4 - Pine Script'ten Dart'a Tam Çeviri
// ════════════════════════════════════════════════════════════════════════

/// Golden/Dump Sinyal - Pump veya Dump fırsatı
class QuantumSignal {
  final int index;
  final DateTime date;
  final double price;
  final String type; // "PUMP" veya "DUMP"
  final double kirilimFiyati;
  final double asFarkPct; // Alım/Satım baskısı yüzdesi
  final double rsiValue;
  final Color labelColor;

  QuantumSignal({
    required this.index,
    required this.date,
    required this.price,
    required this.type,
    required this.kirilimFiyati,
    required this.asFarkPct,
    required this.rsiValue,
    required this.labelColor,
  });
}

/// QML (Quasimodo) Seviyesi
class QmlLevel {
  final int index;
  final double price;
  final String type; // "BULL" veya "BEAR"
  final Color color;

  QmlLevel({
    required this.index,
    required this.price,
    required this.type,
    required this.color,
  });
}

/// Fibonacci Seviyesi
class FibLevel {
  final double level; // 0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0
  final double price;
  final String label;
  final Color color;

  FibLevel({
    required this.level,
    required this.price,
    required this.label,
    required this.color,
  });
}

/// Quantum Lines (3 hat)
class QuantumLines {
  final List<double> trendLine;   // Beyaz (mainMT)
  final List<double> yellowLine;  // Sarı (mainDL)
  final List<double> blueAtrLine; // Mavi ATR

  QuantumLines({
    required this.trendLine,
    required this.yellowLine,
    required this.blueAtrLine,
  });
}

/// Günlük Kutu
class DayBox {
  final double top;    // Previous day high
  final double bottom; // Previous day close
  final int startBar;  // Kutu başlangıç çubuğu

  DayBox({required this.top, required this.bottom, required this.startBar});
}

/// ── DİP TARAMA (QUANTUM ANALIZ v20.4) ──────────────────────────────────────

enum DipSignalType { bh, v15 }

/// Dip Alım Sinyali
class DipSignal {
  final int index;
  final DateTime date;
  final double price;
  final DipSignalType type;
  final double volDegisim;
  final double adxVal;
  final double rsiVal;
  final double? zirveIskonto; // sadece v15 için
  final double slPrice;
  final double tpPrice;

  DipSignal({
    required this.index,
    required this.date,
    required this.price,
    required this.type,
    required this.volDegisim,
    required this.adxVal,
    required this.rsiVal,
    this.zirveIskonto,
    required this.slPrice,
    required this.tpPrice,
  });

  Color get labelColor =>
      type == DipSignalType.bh ? const Color(0xFF00E676) : const Color(0xFF00E5FF);

  String get typeLabel =>
      type == DipSignalType.bh ? 'DİP ALIM' : '🚀 DİP TOPLAMA';
}

/// Dip SL/TP hatları
class DipLines {
  final List<double> slLine;
  final List<double> tpLine;
  DipLines({required this.slLine, required this.tpLine});
}

/// Dip istatistikleri
class DipStats {
  final int bhCount;
  final int v15Count;
  final double lastAdx;
  final double lastRsi;
  final double lastVolDegisim;
  final double lastIskonto;

  DipStats({
    required this.bhCount,
    required this.v15Count,
    required this.lastAdx,
    required this.lastRsi,
    required this.lastVolDegisim,
    required this.lastIskonto,
  });
}

/// Sonuç
class KirilimIndicatorResult {
  final List<QuantumSignal> signals;
  final List<QmlLevel> qmlLevels;
  final List<FibLevel> fibLevels;
  final QuantumLines quantumLines;
  final DayBox? dayBox;
  // ── Dip Tarama ──────────────────
  final List<DipSignal> dipSignals;
  final DipLines dipLines;
  final DipStats dipStats;

  KirilimIndicatorResult({
    required this.signals,
    required this.qmlLevels,
    required this.fibLevels,
    required this.quantumLines,
    this.dayBox,
    required this.dipSignals,
    required this.dipLines,
    required this.dipStats,
  });
}

class KirilimIndicator {
  // ════════════════════════════════════════════════════════════════════════
  // AYARLAR (Pine Script'teki gibi)
  // ════════════════════════════════════════════════════════════════════════
  static const int len = 10;                    // Hassasiyet (Pivot)
  static const Color qmlBullCol = Color(0xFF00FFCC);
  static const Color qmlBearCol = Color(0xFFFF6A6A);
  static const Color trendCol = Color(0xFF00897B);
  
  static const int ap = 10;                     // Hassasiyet (ATR)
  static const double mult2 = 3.0;              // Mesafe
  static const int lookbackF = 150;             // Fibonacci lookback
  static const int offsetRight = 25;            // Sağa uzatma

  // ════════════════════════════════════════════════════════════════════════
  // ANA HESAPLAMA
  // ════════════════════════════════════════════════════════════════════════
  static KirilimIndicatorResult hesapla(List<Candle> candles) {
    print("🔮 QUANTUM İndikatör başlıyor...");
    print("  📊 Toplam mum: ${candles.length}");

    if (candles.isEmpty || candles.length < 50) {
      print("  ❌ Yetersiz veri");
      return KirilimIndicatorResult(
        signals: [],
        qmlLevels: [],
        fibLevels: [],
        quantumLines: QuantumLines(trendLine: [], yellowLine: [], blueAtrLine: []),
        dipSignals: [],
        dipLines: DipLines(slLine: [], tpLine: []),
        dipStats: DipStats(
          bhCount: 0,
          v15Count: 0,
          lastAdx: 0,
          lastRsi: 50,
          lastVolDegisim: 0,
          lastIskonto: 0,
        ),
      );
    }

    int n = candles.length;
    List<double> highs = candles.map((c) => c.high).toList();
    List<double> lows = candles.map((c) => c.low).toList();
    List<double> closes = candles.map((c) => c.close).toList();

    // ════════════════════════════════════════════════════════════════════════
    // 1. PIVOT VE ZIKZAK
    // ════════════════════════════════════════════════════════════════════════
    List<double> ph = _pivotHigh(highs, len, len);
    List<double> pl = _pivotLow(lows, len, len);

    double? h1, h2, l1, l2;
    int? h1Idx, h2Idx, l1Idx, l2Idx;

    // ════════════════════════════════════════════════════════════════════════
    // 2. QML (QUASIMODO) SEVİYELERİ
    // ════════════════════════════════════════════════════════════════════════
    List<QmlLevel> qmlLevels = [];
    double sonBullSeviye = 0.0;
    double sonBearSeviye = 0.0;

    for (int i = 0; i < n; i++) {
      // Pivot güncelle
      if (ph[i] > 0) {
        h2 = h1;
        h2Idx = h1Idx;
        h1 = ph[i];
        h1Idx = i;
      }
      if (pl[i] > 0) {
        l2 = l1;
        l2Idx = l1Idx;
        l1 = pl[i];
        l1Idx = i;
      }

      // Bull QML: high > h2 crossover
      if (h2 != null && h2Idx != null && i > 0) {
        if (highs[i] > h2 && highs[i - 1] <= h2 && h2 != sonBullSeviye) {
          qmlLevels.add(QmlLevel(
            index: i,
            price: h2,
            type: "BULL",
            color: qmlBullCol,
          ));
          sonBullSeviye = h2;
          print("  ✅ BULL QML: ${h2.toStringAsFixed(4)} @ bar $i");
        }
      }

      // Bear QML: low < l2 crossunder
      if (l2 != null && l2Idx != null && i > 0) {
        if (lows[i] < l2 && lows[i - 1] >= l2 && l2 != sonBearSeviye) {
          qmlLevels.add(QmlLevel(
            index: i,
            price: l2,
            type: "BEAR",
            color: qmlBearCol,
          ));
          sonBearSeviye = l2;
          print("  ⛔ BEAR QML: ${l2.toStringAsFixed(4)} @ bar $i");
        }
      }
    }

    // ════════════════════════════════════════════════════════════════════════
    // 3. QUANTUM HESAPLAMALARI
    // ════════════════════════════════════════════════════════════════════════
    
    // DMI (ADX)
    var dmiResult = _calculateDMI(highs, lows, closes, 14, 14);
    List<double> plusDI = dmiResult[0];
    List<double> minusDI = dmiResult[1];

    // Alım/Satım Farkı
    List<double> asFarkPct = List.generate(n, (i) {
      double sum = plusDI[i] + minusDI[i];
      return sum > 0 ? ((plusDI[i] - minusDI[i]) / sum) * 100 : 0;
    });

    // RSI
    List<double> rsiVals = _calculateRSI(closes, 14);

    // ATR
    List<double> atrAp = _calculateATR(highs, lows, closes, ap);
    List<double> atr14 = _calculateATR(highs, lows, closes, 14);

    // CCI
    List<double> cci21 = _calculateCCI(highs, lows, closes, 21);

    // HL2
    List<double> hl2 = List.generate(n, (i) => (highs[i] + lows[i]) / 2);

    // upT, dnT
    List<double> upT = List.generate(n, (i) => hl2[i] - atrAp[i] * mult2);
    List<double> dnT = List.generate(n, (i) => hl2[i] + atrAp[i] * mult2);

    // mainMT (Trend Line - Beyaz)
    List<double> mainMT = List.filled(n, 0.0);
    if (n > 0) {
      mainMT[0] = cci21[0] >= 0 ? upT[0] : dnT[0];
      for (int i = 1; i < n; i++) {
        if (cci21[i] >= 0) {
          mainMT[i] = math.max(upT[i], mainMT[i - 1]);
        } else {
          mainMT[i] = math.min(dnT[i], mainMT[i - 1]);
        }
      }
    }

    // mainDL (Sarı Hat)
    List<double> thrC = List.generate(n, (i) => atr14[i] * 2.0);
    List<double> mainDL = List.filled(n, 0.0);
    if (n > 0) {
      mainDL[0] = closes[0];
      for (int i = 1; i < n; i++) {
        if (closes[i] > mainDL[i - 1] + thrC[i]) {
          mainDL[i] = closes[i] - thrC[i];
        } else if (closes[i] < mainDL[i - 1] - thrC[i]) {
          mainDL[i] = closes[i] + thrC[i];
        } else {
          mainDL[i] = mainDL[i - 1];
        }
      }
    }

    // Kırılım Fiyatı
    List<double> kirilimFiyati = List.generate(n, (i) => (mainMT[i] + mainDL[i]) / 2);

    // Mavi ATR Hattı
    List<double> sariAtrDeger = atr14;
    List<double> maviAtrHatti = List.filled(n, 0.0);
    if (n > 0) {
      maviAtrHatti[0] = closes[0];
      for (int i = 1; i < n; i++) {
        if (closes[i] > maviAtrHatti[i - 1]) {
          maviAtrHatti[i] = math.max(maviAtrHatti[i - 1], closes[i] - sariAtrDeger[i] * 1.3);
        } else {
          maviAtrHatti[i] = math.min(maviAtrHatti[i - 1], closes[i] + sariAtrDeger[i] * 1.3);
        }
      }
    }

    // ════════════════════════════════════════════════════════════════════════
    // 4. SİGNAL MANTIĞI: MAVİ SARIYI KESERSİ
    // ════════════════════════════════════════════════════════════════════════
    List<QuantumSignal> signals = [];

    for (int i = 1; i < n; i++) {
      // Crossover/Crossunder
      bool v15Crossover = maviAtrHatti[i - 1] < mainDL[i - 1] && maviAtrHatti[i] >= mainDL[i];
      bool v15Crossunder = maviAtrHatti[i - 1] > mainDL[i - 1] && maviAtrHatti[i] <= mainDL[i];

      // Golden (Pump)
      if (v15Crossover && asFarkPct[i] >= 10) {
        signals.add(QuantumSignal(
          index: i,
          date: candles[i].date,
          price: closes[i],
          type: "PUMP",
          kirilimFiyati: kirilimFiyati[i],
          asFarkPct: asFarkPct[i],
          rsiValue: rsiVals[i],
          labelColor: const Color(0xFFE3F706), // Sarı-yeşil
        ));
        print("  ⚡ PUMP @ bar $i: ${closes[i].toStringAsFixed(4)}");
      }

      // Dump
      if (v15Crossunder && asFarkPct[i].abs() >= 10) {
        signals.add(QuantumSignal(
          index: i,
          date: candles[i].date,
          price: closes[i],
          type: "DUMP",
          kirilimFiyati: kirilimFiyati[i],
          asFarkPct: asFarkPct[i],
          rsiValue: rsiVals[i],
          labelColor: const Color(0xFFFF0000), // Kırmızı
        ));
        print("  💥 DUMP @ bar $i: ${closes[i].toStringAsFixed(4)}");
      }
    }

    // ════════════════════════════════════════════════════════════════════════
    // 5. FIBONACCI
    // ════════════════════════════════════════════════════════════════════════
    int startIdx = math.max(0, n - lookbackF);
    double hiF = highs.sublist(startIdx).reduce(math.max);
    double loF = lows.sublist(startIdx).reduce(math.min);
    double diffF = hiF - loF;

    List<FibLevel> fibLevels = [
      FibLevel(level: 0.0, price: hiF, label: "0.000", color: const Color(0xFFFF0000)),
      FibLevel(level: 0.236, price: hiF - diffF * 0.236, label: "0.236", color: const Color(0xFF808080)),
      FibLevel(level: 0.382, price: hiF - diffF * 0.382, label: "0.382", color: const Color(0xFF808080)),
      FibLevel(level: 0.5, price: hiF - diffF * 0.5, label: "0.500", color: const Color(0xFFFF9800)),
      FibLevel(level: 0.618, price: hiF - diffF * 0.618, label: "0.618", color: const Color(0xFF808080)),
      FibLevel(level: 0.786, price: hiF - diffF * 0.786, label: "0.786", color: const Color(0xFF808080)),
      FibLevel(level: 1.0, price: loF, label: "1.000", color: const Color(0xFF00FF00)),
    ];

    // ════════════════════════════════════════════════════════════════════════
    // 6. GÜNLÜK KUTU (Previous Day)
    // ════════════════════════════════════════════════════════════════════════
    DayBox? dayBox;
    if (n > 2) {
      double prevDayHigh = highs[n - 2];
      double prevDayClose = closes[n - 2];
      int boxStart = math.max(0, n - 70);
      dayBox = DayBox(top: prevDayHigh, bottom: prevDayClose, startBar: boxStart);
    }

    print("  📊 ${signals.length} sinyal bulundu");
    print("  📏 ${fibLevels.length} Fibonacci seviyesi hazır");

    // ════════════════════════════════════════════════════════════════════════
    // 7. DİP TARAMA (QUANTUM ANALIZ v20.4 - aynı verilerle)
    // ════════════════════════════════════════════════════════════════════════
    final dipResult = _hesaplaDip(candles, highs, lows, closes);

    print("  🎯 ${dipResult.$1.length} dip sinyali bulundu");
    print("✅ QUANTUM hesaplama tamamlandı!\n");

    return KirilimIndicatorResult(
      signals: signals,
      qmlLevels: qmlLevels,
      fibLevels: fibLevels,
      quantumLines: QuantumLines(
        trendLine: mainMT,
        yellowLine: mainDL,
        blueAtrLine: maviAtrHatti,
      ),
      dayBox: dayBox,
      dipSignals: dipResult.$1,
      dipLines: dipResult.$2,
      dipStats: dipResult.$3,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // DİP TARAMA HESAPLAMA
  // ════════════════════════════════════════════════════════════════════════
  static (List<DipSignal>, DipLines, DipStats) _hesaplaDip(
    List<Candle> candles,
    List<double> highs,
    List<double> lows,
    List<double> closes,
  ) {
    final int n = candles.length;
    final volumes = candles.map((c) => c.volume).toList();

    // ── RSI ─────────────────────────────────────────────────────────────
    final rsiVals = _calculateRSI(closes, 14);

    // ── Volume SMA + degisim ─────────────────────────────────────────────
    final volAvg = _sma(volumes, 20);
    final volDegisim = List.generate(n, (i) {
      if (volAvg[i] == 0) return 0.0;
      return ((volumes[i] - volAvg[i]) / volAvg[i]) * 100;
    });

    // ── ADX (DI farkından basit) ─────────────────────────────────────────
    final dmi  = _calculateDMI(highs, lows, closes, 14, 14);
    final adxVals = List.generate(n, (i) {
      final sum = dmi[0][i] + dmi[1][i];
      return sum > 0 ? ((dmi[0][i] - dmi[1][i]).abs() / sum) * 100 : 0.0;
    });

    // ── Quantum mainMT + mainDL (aynı parametreler) ──────────────────────
    final atrAp = _calculateATR(highs, lows, closes, ap);
    final atr14 = _calculateATR(highs, lows, closes, 14);
    final cci21 = _calculateCCI(highs, lows, closes, 21);
    final hl2   = List.generate(n, (i) => (highs[i] + lows[i]) / 2);
    final upT   = List.generate(n, (i) => hl2[i] - atrAp[i] * mult2);
    final dnT   = List.generate(n, (i) => hl2[i] + atrAp[i] * mult2);

    final mainMT = List.filled(n, 0.0);
    mainMT[0] = cci21[0] >= 0 ? upT[0] : dnT[0];
    for (int i = 1; i < n; i++) {
      mainMT[i] = cci21[i] >= 0
          ? math.max(upT[i], mainMT[i - 1])
          : math.min(dnT[i], mainMT[i - 1]);
    }

    final thrC   = List.generate(n, (i) => atr14[i] * 2.0);
    final mainDL = List.filled(n, 0.0);
    mainDL[0] = closes[0];
    for (int i = 1; i < n; i++) {
      if (closes[i] > mainDL[i - 1] + thrC[i]) {
        mainDL[i] = closes[i] - thrC[i];
      } else if (closes[i] < mainDL[i - 1] - thrC[i]) {
        mainDL[i] = closes[i] + thrC[i];
      } else {
        mainDL[i] = mainDL[i - 1];
      }
    }

    // ── 20-bar highest iskonto ────────────────────────────────────────────
    final high20 = List.generate(n, (i) {
      final start = math.max(0, i - 19);
      return highs.sublist(start, i + 1).reduce(math.max);
    });
    final zirveIskonto = List.generate(n, (i) {
      if (high20[i] == 0) return 0.0;
      return ((high20[i] - closes[i]) / high20[i]) * 100;
    });

    // ── SL / TP hatları ───────────────────────────────────────────────────
    final slLine = List.filled(n, double.nan);
    final tpLine = List.filled(n, double.nan);

    // ── Sinyal mantığı ────────────────────────────────────────────────────
    const double volMultBh    = 1.5;
    const int    cooldown     = 15;
    const double iskontoEsigi = 0.5;
    const double slMult       = 1.5;
    const double tpMult       = 3.0;

    final signals = <DipSignal>[];
    int lastSBar = 0;

    for (int i = 1; i < n; i++) {
      // BH: close crosses over mainMT, rsi > 30, vol arttı, vol > volAvg*1.5
      final bhBuyRaw = closes[i - 1] <= mainMT[i - 1] &&
          closes[i] > mainMT[i] &&
          rsiVals[i] > 30 &&
          volDegisim[i] > 0 &&
          volumes[i] > volAvg[i] * volMultBh;

      final canSignalBh  = (i - lastSBar) > cooldown;
      final finalBhBuy   = bhBuyRaw && canSignalBh;

      // v15: mainDL crosses over mainMT, iskonto >= 0.5, vol arttı
      final canV15Buy = mainDL[i - 1] <= mainMT[i - 1] &&
          mainDL[i] > mainMT[i] &&
          zirveIskonto[i] >= iskontoEsigi &&
          volDegisim[i] > 0;

      final sl = lows[i] - (atr14[i] * slMult);
      final tp = closes[i] + (atr14[i] * tpMult);

      if (finalBhBuy || canV15Buy) {
        for (int j = i; j < n; j++) {
          slLine[j] = sl;
          tpLine[j] = tp;
        }
      }

      if (finalBhBuy) {
        lastSBar = i;
        signals.add(DipSignal(
          index: i,
          date: candles[i].date,
          price: closes[i],
          type: DipSignalType.bh,
          volDegisim: volDegisim[i],
          adxVal: adxVals[i],
          rsiVal: rsiVals[i],
          slPrice: sl,
          tpPrice: tp,
        ));
      }

      if (canV15Buy) {
        signals.add(DipSignal(
          index: i,
          date: candles[i].date,
          price: closes[i],
          type: DipSignalType.v15,
          volDegisim: volDegisim[i],
          adxVal: adxVals[i],
          rsiVal: rsiVals[i],
          zirveIskonto: zirveIskonto[i],
          slPrice: sl,
          tpPrice: tp,
        ));
      }
    }

    final stats = DipStats(
      bhCount:        signals.where((s) => s.type == DipSignalType.bh).length,
      v15Count:       signals.where((s) => s.type == DipSignalType.v15).length,
      lastAdx:        adxVals.last,
      lastRsi:        rsiVals.last,
      lastVolDegisim: volDegisim.last,
      lastIskonto:    zirveIskonto.last,
    );

    return (signals, DipLines(slLine: slLine, tpLine: tpLine), stats);
  }

  // ── SMA yardımcı (Dip için) ──────────────────────────────────────────────
  static List<double> _sma(List<double> vals, int p) {
    final n = vals.length;
    final out = List.filled(n, 0.0);
    for (int i = p - 1; i < n; i++) {
      double s = 0;
      for (int j = 0; j < p; j++) s += vals[i - j];
      out[i] = s / p;
    }
    return out;
  }

  // ════════════════════════════════════════════════════════════════════════
  // YARDIMCI FONKSİYONLAR
  // ════════════════════════════════════════════════════════════════════════

  static List<double> _pivotHigh(List<double> highs, int left, int right) {
    int n = highs.length;
    List<double> ph = List.filled(n, 0.0); // ✅ 0.0 kullan (NaN yerine)
    
    for (int i = left; i < n - right; i++) {
      double center = highs[i];
      bool isPivot = true;
      
      // Check left
      for (int j = i - left; j < i; j++) {
        if (highs[j] >= center) {
          isPivot = false;
          break;
        }
      }
      
      // Check right
      if (isPivot) {
        for (int j = i + 1; j <= i + right; j++) {
          if (highs[j] >= center) {
            isPivot = false;
            break;
          }
        }
      }
      
      if (isPivot) {
        ph[i] = center;
      }
    }
    
    return ph;
  }

  static List<double> _pivotLow(List<double> lows, int left, int right) {
    int n = lows.length;
    List<double> pl = List.filled(n, 0.0); // ✅ 0.0 kullan
    
    for (int i = left; i < n - right; i++) {
      double center = lows[i];
      bool isPivot = true;
      
      // Check left
      for (int j = i - left; j < i; j++) {
        if (lows[j] <= center) {
          isPivot = false;
          break;
        }
      }
      
      // Check right
      if (isPivot) {
        for (int j = i + 1; j <= i + right; j++) {
          if (lows[j] <= center) {
            isPivot = false;
            break;
          }
        }
      }
      
      if (isPivot) {
        pl[i] = center;
      }
    }
    
    return pl;
  }

  static List<double> _calculateATR(List<double> highs, List<double> lows, List<double> closes, int period) {
    int n = highs.length;
    List<double> atr = List.filled(n, 0.0);
    
    if (n == 0) return atr;
    
    // İlk TR
    atr[0] = highs[0] - lows[0];
    
    // Sonrakiler
    for (int i = 1; i < n; i++) {
      double tr = math.max(
        highs[i] - lows[i],
        math.max(
          (highs[i] - closes[i - 1]).abs(),
          (lows[i] - closes[i - 1]).abs(),
        ),
      );
      
      if (i < period) {
        atr[i] = tr;
      } else {
        atr[i] = (atr[i - 1] * (period - 1) + tr) / period;
      }
    }
    
    return atr;
  }

  static List<double> _calculateCCI(List<double> highs, List<double> lows, List<double> closes, int period) {
    int n = highs.length;
    List<double> cci = List.filled(n, 0.0);
    
    for (int i = period - 1; i < n; i++) {
      // Typical Price
      double sumTP = 0;
      for (int j = 0; j < period; j++) {
        sumTP += (highs[i - j] + lows[i - j] + closes[i - j]) / 3;
      }
      double sma = sumTP / period;
      
      // Mean Deviation
      double sumDev = 0;
      for (int j = 0; j < period; j++) {
        double tp = (highs[i - j] + lows[i - j] + closes[i - j]) / 3;
        sumDev += (tp - sma).abs();
      }
      double meanDev = sumDev / period;
      
      // CCI
      double currentTP = (highs[i] + lows[i] + closes[i]) / 3;
      cci[i] = meanDev > 0 ? (currentTP - sma) / (0.015 * meanDev) : 0;
    }
    
    return cci;
  }

  static List<List<double>> _calculateDMI(List<double> highs, List<double> lows, List<double> closes, int diLength, int adxLength) {
    int n = highs.length;
    List<double> plusDI = List.filled(n, 0.0);
    List<double> minusDI = List.filled(n, 0.0);
    
    if (n < diLength) return [plusDI, minusDI];
    
    for (int i = diLength; i < n; i++) {
      double sumPlusDM = 0;
      double sumMinusDM = 0;
      double sumTR = 0;
      
      for (int j = 0; j < diLength; j++) {
        int idx = i - j;
        if (idx <= 0) continue;
        
        double upMove = highs[idx] - highs[idx - 1];
        double downMove = lows[idx - 1] - lows[idx];
        
        double plusDM = (upMove > downMove && upMove > 0) ? upMove : 0;
        double minusDM = (downMove > upMove && downMove > 0) ? downMove : 0;
        
        sumPlusDM += plusDM;
        sumMinusDM += minusDM;
        
        double tr = math.max(
          highs[idx] - lows[idx],
          math.max(
            (highs[idx] - closes[idx - 1]).abs(),
            (lows[idx] - closes[idx - 1]).abs(),
          ),
        );
        sumTR += tr;
      }
      
      plusDI[i] = sumTR > 0 ? (sumPlusDM / sumTR) * 100 : 0;
      minusDI[i] = sumTR > 0 ? (sumMinusDM / sumTR) * 100 : 0;
    }
    
    return [plusDI, minusDI];
  }

  static List<double> _calculateRSI(List<double> values, int period) {
    int n = values.length;
    List<double> rsi = List.filled(n, 50.0);
    
    if (n < period + 1) return rsi;
    
    double avgGain = 0;
    double avgLoss = 0;
    
    // İlk period
    for (int i = 1; i <= period; i++) {
      double change = values[i] - values[i - 1];
      if (change > 0) {
        avgGain += change;
      } else {
        avgLoss += change.abs();
      }
    }
    avgGain /= period;
    avgLoss /= period;
    
    rsi[period] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss));
    
    // Sonrakiler
    for (int i = period + 1; i < n; i++) {
      double change = values[i] - values[i - 1];
      double gain = change > 0 ? change : 0;
      double loss = change < 0 ? change.abs() : 0;
      
      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
      
      rsi[i] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss));
    }
    
    return rsi;
  }
}