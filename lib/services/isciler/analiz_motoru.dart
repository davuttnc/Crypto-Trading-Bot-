// lib/services/isciler/analiz_motoru.dart
import 'package:candlesticks/candlesticks.dart';
import 'dart:math';

// ══════════════════════════════════════════════════════════════════════════════
// ANALİZ MOTORU v2.0 - ULTRA GÜÇLÜ SİNYAL SİSTEMİ
// ✅ Stablecoin filtresi  → USDT/BUSD gibi sabit coinler engellenir
// ✅ Mum formasyonları    → Hammer, Engulfing, Marubozu, Morning Star
// ✅ Zirve iskontosu      → Dip Tarama indikatöründen (%2-%25 bölge)
// ✅ Düşen trend kırılımı → Takoz/Diamond indikatöründen (slope < 0 + hacim)
// ✅ Alım baskısı filtresi→ Pump/Dump indikatöründen (buyPressure >= 15)
// ✅ Fibonacci destek      → %38.2 / %50.0 / %61.8 destek bölgeleri
// ✅ Yükselen dipler       → Higher Lows yapısı (sağlıklı zemin)
// ✅ Zorunlu ana sinyal    → Her sinyalde en az 1 güçlü tetikleyici
// ✅ RSI filtresi          → Aşırı alım bölgesinde (%75+) sinyal yok
// ══════════════════════════════════════════════════════════════════════════════

enum SignalStrength { WEAK, MEDIUM, STRONG, EXPLOSIVE }

class AnalysisSignal {
  final int index;
  final String type;
  final double entryPrice;
  final double tp1;
  final double tp2;
  final double tp3;
  final double stopLoss;
  final SignalStrength strength;
  final List<String> reasons;
  final double rsi;
  final double adx;
  final double volumeChange;
  final DateTime timestamp;

  AnalysisSignal({
    required this.index,
    required this.type,
    required this.entryPrice,
    required this.tp1,
    required this.tp2,
    required this.tp3,
    required this.stopLoss,
    required this.strength,
    required this.reasons,
    required this.rsi,
    required this.adx,
    required this.volumeChange,
    required this.timestamp,
  });
}

class AnalysisStats {
  final int totalSignals;
  final int explosiveSignals;
  final int strongSignals;
  final int mediumSignals;
  final int weakSignals;
  final double avgSignalStrength;

  AnalysisStats({
    required this.totalSignals,
    required this.explosiveSignals,
    required this.strongSignals,
    required this.mediumSignals,
    required this.weakSignals,
    required this.avgSignalStrength,
  });
}

class AnalysisResult {
  final List<AnalysisSignal> signals;
  final List<double> quantumTrendLine;
  final List<double> yellowLine;
  final List<double> blueATRLine;
  final List<double> qmlBullLevels;
  final List<double> qmlBearLevels;
  final AnalysisStats stats;

  AnalysisResult({
    required this.signals,
    required this.quantumTrendLine,
    required this.yellowLine,
    required this.blueATRLine,
    required this.qmlBullLevels,
    required this.qmlBearLevels,
    required this.stats,
  });
}

class AnalizMotoru {

  // ════════════════════════════════════════════════════════════════════════════
  // TEMEL İNDİKATÖR HESAPLAMALARI
  // ════════════════════════════════════════════════════════════════════════════

  static List<double> _atr(List<Candle> c, int p) {
    if (c.length < p + 1) return List.filled(c.length, 0.0);
    final tr = List.filled(c.length, 0.0);
    for (int i = 1; i < c.length; i++) {
      tr[i] = max(c[i].high - c[i].low,
          max((c[i].high - c[i - 1].close).abs(), (c[i].low - c[i - 1].close).abs()));
    }
    double s = 0;
    for (int i = 1; i <= p; i++) s += tr[i];
    final atr = List.filled(c.length, 0.0);
    atr[p] = s / p;
    for (int i = p + 1; i < c.length; i++) {
      s += tr[i] - tr[i - p];
      atr[i] = s / p;
    }
    return atr;
  }

  static List<double> _rsi(List<Candle> c, int p) {
    if (c.length < p + 1) return List.filled(c.length, 50.0);
    final rsi = List.filled(c.length, 50.0);
    double gSum = 0, lSum = 0;
    for (int i = 1; i <= p; i++) {
      final d = c[i].close - c[i - 1].close;
      if (d > 0) gSum += d; else lSum -= d;
    }
    double ag = gSum / p, al = lSum / p;
    rsi[p] = al == 0 ? 100 : 100 - (100 / (1 + ag / al));
    for (int i = p + 1; i < c.length; i++) {
      final d = c[i].close - c[i - 1].close;
      ag = ((ag * (p - 1)) + (d > 0 ? d : 0)) / p;
      al = ((al * (p - 1)) + (d < 0 ? -d : 0)) / p;
      rsi[i] = al == 0 ? 100 : 100 - (100 / (1 + ag / al));
    }
    return rsi;
  }

  static List<double> _cci(List<Candle> c, int p) {
    if (c.length < p) return List.filled(c.length, 0.0);
    final cci = List.filled(c.length, 0.0);
    final tp = c.map((x) => (x.high + x.low + x.close) / 3).toList();
    for (int i = p - 1; i < c.length; i++) {
      double sum = 0;
      for (int j = 0; j < p; j++) sum += tp[i - j];
      final sma = sum / p;
      double mad = 0;
      for (int j = 0; j < p; j++) mad += (tp[i - j] - sma).abs();
      mad /= p;
      if (mad != 0) cci[i] = (tp[i] - sma) / (0.015 * mad);
    }
    return cci;
  }

  static List<double> _volSMA(List<Candle> c, int p) {
    if (c.length < p) return List.filled(c.length, 0.0);
    final sma = List.filled(c.length, 0.0);
    double s = 0;
    for (int i = 0; i < p; i++) s += c[i].volume;
    sma[p - 1] = s / p;
    for (int i = p; i < c.length; i++) {
      s += c[i].volume - c[i - p].volume;
      sma[i] = s / p;
    }
    return sma;
  }

  static Map<String, List<double>> _adx(List<Candle> c, int p) {
    final len = c.length;
    if (len < p + 1) {
      return {
        'pDI': List.filled(len, 0.0),
        'mDI': List.filled(len, 0.0),
        'adx': List.filled(len, 0.0)
      };
    }
    final tr = List.filled(len, 0.0);
    final pDM = List.filled(len, 0.0);
    final mDM = List.filled(len, 0.0);
    for (int i = 1; i < len; i++) {
      tr[i] = max(c[i].high - c[i].low,
          max((c[i].high - c[i - 1].close).abs(), (c[i].low - c[i - 1].close).abs()));
      final up = c[i].high - c[i - 1].high;
      final dn = c[i - 1].low - c[i].low;
      if (up > dn && up > 0) pDM[i] = up;
      if (dn > up && dn > 0) mDM[i] = dn;
    }
    final pDI = List.filled(len, 0.0);
    final mDI = List.filled(len, 0.0);
    final adxL = List.filled(len, 0.0);
    double sTR = 0, sPDM = 0, sMDM = 0;
    for (int i = 1; i <= p; i++) { sTR += tr[i]; sPDM += pDM[i]; sMDM += mDM[i]; }
    for (int i = p; i < len; i++) {
      sTR = sTR - sTR / p + tr[i];
      sPDM = sPDM - sPDM / p + pDM[i];
      sMDM = sMDM - sMDM / p + mDM[i];
      if (sTR != 0) { pDI[i] = sPDM / sTR * 100; mDI[i] = sMDM / sTR * 100; }
      final dx = (pDI[i] + mDI[i]) != 0
          ? (pDI[i] - mDI[i]).abs() / (pDI[i] + mDI[i]) * 100 : 0.0;
      adxL[i] = i == p ? dx : (adxL[i - 1] * (p - 1) + dx) / p;
    }
    return {'pDI': pDI, 'mDI': mDI, 'adx': adxL};
  }

  // ════════════════════════════════════════════════════════════════════════════
  // QUANTUM TREND + SARI HAT
  // ════════════════════════════════════════════════════════════════════════════
  static Map<String, List<double>> _quantumTrend(
      List<Candle> c, int atrP, double mult) {
    final n = c.length;
    final atrV = _atr(c, atrP);
    final cciV = _cci(c, 21);
    final mt = List.filled(n, 0.0);
    final dl = List.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final hl2 = (c[i].high + c[i].low) / 2;
      final upT = hl2 - atrV[i] * mult;
      final dnT = hl2 + atrV[i] * mult;
      mt[i] = i == 0
          ? (cciV[i] >= 0 ? upT : dnT)
          : (cciV[i] >= 0 ? max(upT, mt[i - 1]) : min(dnT, mt[i - 1]));
    }
    final atrY = _atr(c, 14);
    for (int i = 0; i < n; i++) {
      final thr = atrY[i] * 2.0;
      final cl = c[i].close;
      if (i == 0) { dl[i] = cl; continue; }
      if (cl > dl[i - 1] + thr) dl[i] = cl - thr;
      else if (cl < dl[i - 1] - thr) dl[i] = cl + thr;
      else dl[i] = dl[i - 1];
    }
    return {'mainMT': mt, 'mainDL': dl};
  }

  static List<double> _blueATR(List<Candle> c, int p, double mult) {
    final n = c.length;
    final atrV = _atr(c, p);
    final blue = List.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final cl = c[i].close;
      if (i == 0) { blue[i] = cl; continue; }
      blue[i] = cl > blue[i - 1]
          ? max(blue[i - 1], cl - atrV[i] * mult)
          : min(blue[i - 1], cl + atrV[i] * mult);
    }
    return blue;
  }

  static Map<String, List<double>> _qml(List<Candle> c, int pLen) {
    final n = c.length;
    final bull = List.filled(n, 0.0);
    final bear = List.filled(n, 0.0);
    double? h1, h2, l1, l2;
    for (int i = pLen; i < n - pLen; i++) {
      bool isPH = true;
      for (int j = 1; j <= pLen; j++) {
        if (c[i].high <= c[i - j].high || c[i].high <= c[i + j].high) { isPH = false; break; }
      }
      if (isPH) { h2 = h1; h1 = c[i].high; }
      bool isPL = true;
      for (int j = 1; j <= pLen; j++) {
        if (c[i].low >= c[i - j].low || c[i].low >= c[i + j].low) { isPL = false; break; }
      }
      if (isPL) { l2 = l1; l1 = c[i].low; }
      if (h2 != null && c[i].high > h2) bull[i] = h2;
      if (l2 != null && c[i].low < l2) bear[i] = l2;
    }
    return {'bull': bull, 'bear': bear};
  }

  // ════════════════════════════════════════════════════════════════════════════
  // YENİ: STABİLCOİN / DÜŞÜK VOLATİLİTE FİLTRESİ
  // USDT, BUSD, USDC gibi sabit coinleri, çok durgun coingleri engeller
  // ════════════════════════════════════════════════════════════════════════════
  static bool _isValidCoin(List<Candle> c) {
    final lookback = min(30, c.length - 1);
    // Ortalama mum değişimi
    double totalChg = 0;
    for (int i = 1; i <= lookback; i++) {
      if (c[i - 1].close > 0) {
        totalChg += ((c[i].close - c[i - 1].close) / c[i - 1].close).abs();
      }
    }
    final avgChg = totalChg / lookback;
    if (avgChg < 0.0008) return false; // %0.08 altı = stablecoin

    // Ortalama gövde/aralık oranı
    double totalRange = 0;
    for (int i = 0; i < lookback; i++) {
      if (c[i].close > 0) totalRange += (c[i].high - c[i].low) / c[i].close;
    }
    if (totalRange / lookback < 0.0015) return false; // Çok sıkışık fiyat

    return true;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // YENİ: MUM FORMASYONLARI
  // Hammer, Bullish Engulfing, Marubozu, Morning Star
  // ════════════════════════════════════════════════════════════════════════════
  static String? _candlePattern(List<Candle> c, int i) {
    if (i < 1) return null;
    final cur = c[i];
    final prev = c[i - 1];
    final body = (cur.close - cur.open).abs();
    final range = cur.high - cur.low;
    if (range == 0) return null;
    final upperWick = cur.high - max(cur.open, cur.close);
    final lowerWick = min(cur.open, cur.close) - cur.low;

    // 🔨 HAMMER (Yeşil = daha güçlü)
    if (body / range < 0.35 && lowerWick > body * 2 && upperWick < body && cur.close > cur.open) {
      return "🔨 HAMMER";
    }

    // 🌟 BULLISH ENGULFING
    if (cur.close > cur.open && prev.close < prev.open &&
        cur.open < prev.close && cur.close > prev.open) {
      return "🌟 ENGULFING";
    }

    // 🚀 BULLISH MARUBOZU
    if (cur.close > cur.open && body / range > 0.85) {
      return "🚀 MARUBOZU";
    }

    // ⭐ MORNING STAR (3 mum)
    if (i >= 2) {
      final pp = c[i - 2];
      if (pp.close < pp.open &&
          (prev.close - prev.open).abs() < (pp.close - pp.open).abs() * 0.4 &&
          cur.close > cur.open &&
          cur.close > (pp.open + pp.close) / 2) {
        return "⭐ MORNING STAR";
      }
    }

    return null;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // YENİ: FİBONACCİ DESTEK BÖLGESİ
  // Son N mumun en yüksek/düşüğüne göre Fib seviyeleri (%38.2 / %50 / %61.8)
  // ════════════════════════════════════════════════════════════════════════════
  static String? _fibZone(List<Candle> c, int i, int lookback) {
    if (i < lookback) return null;
    double hi = c[i].high, lo = c[i].low;
    for (int j = 1; j < lookback && i - j >= 0; j++) {
      hi = max(hi, c[i - j].high);
      lo = min(lo, c[i - j].low);
    }
    final diff = hi - lo;
    if (diff == 0) return null;
    final close = c[i].close;
    final tol = diff * 0.015;
    if ((close - (hi - diff * 0.618)).abs() < tol) return "📐 FİB %61.8";
    if ((close - (hi - diff * 0.500)).abs() < tol) return "📐 FİB %50.0";
    if ((close - (hi - diff * 0.382)).abs() < tol) return "📐 FİB %38.2";
    return null;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // YENİ: DÜŞEN TREND KIRILIMI (Diamond / Otomatik Takoz indikatöründen)
  // Düşen pivot high trendini hacim ile birlikte kıran barları tespit eder
  // ════════════════════════════════════════════════════════════════════════════
  static List<bool> _fallingTrendBreaks(List<Candle> c, int pivotLB, List<double> volAvg) {
    final n = c.length;
    final breaks = List.filled(n, false);
    double? p1, p2;
    int? t1, t2;
    for (int i = pivotLB; i < n - 1; i++) {
      // Pivot high tespiti
      bool isPH = true;
      for (int j = 1; j <= pivotLB; j++) {
        if (i - j < 0 || i + j >= n) { isPH = false; break; }
        if (c[i].high <= c[i - j].high || c[i].high <= c[i + j].high) { isPH = false; break; }
      }
      if (isPH) { p2 = p1; t2 = t1; p1 = c[i].high; t1 = i; }

      if (p1 != null && p2 != null && t1 != null && t2 != null && t1 != t2 && i > t1) {
        final slope = (p1 - p2) / (t1 - t2);
        if (slope < 0) {
          // Düşen trend
          final trendVal = p1 + slope * (i - t1);
          final prevTrendVal = p1 + slope * (i - 1 - t1);
          // Kırılım: bugün kapanış trend üstünde, dün altındaydı
          if (c[i].close > trendVal && c[i - 1].close <= prevTrendVal) {
            // Hacim onayı (opsiyonel ama güçlendiriyor)
            final hasVolConfirm = volAvg[i] > 0 && c[i].volume > volAvg[i] * 1.2;
            if (hasVolConfirm) breaks[i] = true;
          }
        }
      }
    }
    return breaks;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // YENİ: YÜKSELİŞ YAPISI (Higher Lows)
  // ════════════════════════════════════════════════════════════════════════════
  static bool _hasHigherLows(List<Candle> c, int i, int lookback) {
    if (i < lookback + 2) return false;
    final pivotLows = <double>[];
    for (int j = 1; j < lookback - 1 && i - j - 1 >= 0; j++) {
      final cur = c[i - j].low;
      if (cur < c[i - j - 1].low && cur < c[i - j + 1].low) {
        pivotLows.add(cur);
        if (pivotLows.length >= 3) break;
      }
    }
    if (pivotLows.length < 2) return false;
    return pivotLows[0] > pivotLows[1]; // Son dip öncekinden yüksek
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ANA HESAPLAMA FONKSİYONU
  // ════════════════════════════════════════════════════════════════════════════
  static AnalysisResult hesapla(
    List<Candle> candles, {
    int atrPeriod = 10,
    double trendMultiplier = 3.0,
    int blueATRPeriod = 14,
    double blueATRMultiplier = 1.3,
    int pivotLength = 10,
    double volumeMultiplier = 1.5,
    double minADX = 20.0,
    int cooldownBars = 10,
  }) {
    final _empty = AnalysisResult(
      signals: [],
      quantumTrendLine: [],
      yellowLine: [],
      blueATRLine: [],
      qmlBullLevels: [],
      qmlBearLevels: [],
      stats: AnalysisStats(
          totalSignals: 0,
          explosiveSignals: 0,
          strongSignals: 0,
          mediumSignals: 0,
          weakSignals: 0,
          avgSignalStrength: 0),
    );

    if (candles.isEmpty || candles.length < 100) return _empty;

    // newest-first → oldest-first
    final sorted = candles.reversed.toList();
    final n = sorted.length;
    int toOrig(int i) => n - 1 - i;

    // ══ 🚫 STABİLCOİN / DÜŞÜK VOLATİLİTE FİLTRESİ ══
    if (!_isValidCoin(sorted)) {
      print("🚫 ANALİZ MOTORU: Stablecoin/düşük volatilite → sinyal yok");
      return _empty;
    }

    // ══ İNDİKATÖR HESAPLAMALARI ══
    final qt       = _quantumTrend(sorted, atrPeriod, trendMultiplier);
    final mainMT   = qt['mainMT']!;
    final mainDL   = qt['mainDL']!;
    final blueA    = _blueATR(sorted, blueATRPeriod, blueATRMultiplier);
    final qmlData  = _qml(sorted, pivotLength);
    final qmlBull  = qmlData['bull']!;
    final qmlBear  = qmlData['bear']!;
    final rsiArr   = _rsi(sorted, 14);
    final adxData  = _adx(sorted, 14);
    final plusDI   = adxData['pDI']!;
    final minusDI  = adxData['mDI']!;
    final adxArr   = adxData['adx']!;
    final atrArr   = _atr(sorted, 14);
    final volAvg   = _volSMA(sorted, 20);

    // Düşen trend kırılımları (hesaplandı)
    final ftBreaks = _fallingTrendBreaks(sorted, pivotLength, volAvg);

    // ══ SİNYAL ÜRETME ══
    final signals = <AnalysisSignal>[];
    int lastBar = 0;

    for (int i = 100; i < n; i++) {
      if (i - lastBar < cooldownBars) continue;

      final close  = sorted[i].close;
      final vol    = sorted[i].volume;
      final avgVol = volAvg[i];

      if (avgVol == 0 || atrArr[i] == 0 || close == 0) continue;

      // ─── Bar bazında volatilite filtresi (stablecoin bar'ı geç) ──────────
      if (atrArr[i] / close < 0.0015) continue;

      final reasons = <String>[];

      // ── 1: MAVİ ATR SARIYI YUKARI KESİYOR ──────────────────────────────
      if (blueA[i] > mainDL[i] && blueA[i - 1] <= mainDL[i - 1]) {
        reasons.add("🔷 MAVİ/SARI KIRILIM");
      }

      // ── 2: QUANTUM TREND CROSSOVER ──────────────────────────────────────
      if (close > mainMT[i] && sorted[i - 1].close <= mainMT[i - 1]) {
        reasons.add("📈 TREND KIRILIM");
      }

      // ── 3: QML (QUASIMODO) KIRILIM ──────────────────────────────────────
      if (qmlBull[i] > 0) reasons.add("⚡ QML KIRILIM");

      // ── 4: ADX + ALIM BASKISI (Pump/Dump indikatöründen) ────────────────
      double buyPressure = 0;
      if ((plusDI[i] + minusDI[i]) > 0) {
        buyPressure = (plusDI[i] - minusDI[i]) / (plusDI[i] + minusDI[i]) * 100;
      }
      if (adxArr[i] >= minADX && buyPressure >= 15) {
        reasons.add("💪 ADX ${adxArr[i].toStringAsFixed(1)} / Baskı %${buyPressure.toStringAsFixed(0)}");
      }

      // ── 5: HACİM PATLAMASI ───────────────────────────────────────────────
      final volChg = avgVol > 0 ? ((vol - avgVol) / avgVol) * 100 : 0.0;
      if (vol > avgVol * volumeMultiplier) {
        reasons.add("📊 HACİM +${volChg.toStringAsFixed(0)}%");
      }

      // ── 6: RSI OPTİMAL BÖLGE (Sıkılaştırıldı: 35-65) ───────────────────
      if (rsiArr[i] > 35 && rsiArr[i] < 65) {
        reasons.add("✓ RSI ${rsiArr[i].toStringAsFixed(0)}");
      }

      // ── 7: SARI/BEYAZ KESİŞME ───────────────────────────────────────────
      if (mainDL[i] > mainMT[i] && mainDL[i - 1] <= mainMT[i - 1]) {
        reasons.add("🌟 SARI/BEYAZ KESİŞME");
      }

      // ── 8: MUM FORMASYONU (YENİ) ─────────────────────────────────────────
      final pattern = _candlePattern(sorted, i);
      if (pattern != null) reasons.add(pattern);

      // ── 9: ZİRVE İSKONTOSU - Dip Tarama indikatöründen (YENİ) ───────────
      double high20 = sorted[i].high;
      for (int j = 1; j < 20 && i - j >= 0; j++) {
        high20 = max(high20, sorted[i - j].high);
      }
      final discount = high20 > 0 ? ((high20 - close) / high20) * 100 : 0.0;
      // %2 ile %30 arasındaki iskonto = "dip bölgesi"
      if (discount >= 2.0 && discount <= 30.0) {
        reasons.add("💸 İSKONTO %${discount.toStringAsFixed(1)}");
      }

      // ── 10: DÜŞEN TREND KIRILIMI - Takoz/Diamond (YENİ) ──────────────────
      if (ftBreaks[i]) reasons.add("📉➡️📈 DÜŞEN TREND KIRILDI");

      // ── 11: FİBONACCİ DESTEK BÖLGESİ (YENİ) ─────────────────────────────
      final fib = _fibZone(sorted, i, 100);
      if (fib != null) reasons.add(fib);

      // ── 12: YÜKSELİŞ YAPISI Higher Lows (YENİ) ────────────────────────
      if (_hasHigherLows(sorted, i, 20)) reasons.add("📊 YÜKSELEN DİPLER");

      // ════════════════════════════════════════════════════════════════════
      // ZORUNLU FİLTRELER: Sahte sinyalleri eler
      // ════════════════════════════════════════════════════════════════════

      // 1) En az 1 "ana tetikleyici" olmak zorunda
      final hasMainSignal = reasons.any((r) =>
          r.contains("MAVİ") || r.contains("TREND") || r.contains("QML") ||
          r.contains("DÜŞEN TREND") || r.contains("ENGULFING") || r.contains("MORNING"));
      if (!hasMainSignal) continue;

      // 2) RSI aşırı alım bölgesinde sinyal yok
      if (rsiArr[i] >= 75) continue;

      // 3) ADX çok düşükse (trendsiz piyasa) zayıf sinyalleri filtrele
      if (adxArr[i] < 15 && reasons.length < 4) continue;

      // 4) Stablecoin son kontrolü: ATR/fiyat oranı
      if (atrArr[i] / close < 0.002 && reasons.length < 5) continue;

      // ════════════════════════════════════════════════════════════════════
      // GÜÇ SEVİYESİ (12 koşul üzerinden)
      // ════════════════════════════════════════════════════════════════════
      SignalStrength strength;
      if (reasons.length >= 7)      strength = SignalStrength.EXPLOSIVE;
      else if (reasons.length >= 5) strength = SignalStrength.STRONG;
      else if (reasons.length >= 3) strength = SignalStrength.MEDIUM;
      else if (reasons.length >= 1) strength = SignalStrength.WEAK;
      else continue;

      // ════════════════════════════════════════════════════════════════════
      // HEDEF & STOP LOSS
      // ADX güçlüyse daha geniş TP hedefleri
      // Stop: Son 5 mum dibi veya ATR × 1.5 (hangisi daha altta)
      // ════════════════════════════════════════════════════════════════════
      final tpBoost = adxArr[i] >= 30 ? 1.2 : 1.0;
      final tp1 = close + atrArr[i] * 1.5 * tpBoost;
      final tp2 = close + atrArr[i] * 2.5 * tpBoost;
      final tp3 = close + atrArr[i] * 3.5 * tpBoost;

      double recentLow = sorted[i].low;
      for (int j = 1; j < 5 && i - j >= 0; j++) {
        recentLow = min(recentLow, sorted[i - j].low);
      }
      final slByATR = close - atrArr[i] * 1.5;
      final stopLoss = max(recentLow - atrArr[i] * 0.3, slByATR);

      signals.add(AnalysisSignal(
        index: toOrig(i),
        type: "ROCKET_BUY",
        entryPrice: close,
        tp1: tp1, tp2: tp2, tp3: tp3,
        stopLoss: stopLoss,
        strength: strength,
        reasons: reasons,
        rsi: rsiArr[i],
        adx: adxArr[i],
        volumeChange: volChg,
        timestamp: sorted[i].date,
      ));

      lastBar = i;
    }

    // İstatistik
    final expC = signals.where((s) => s.strength == SignalStrength.EXPLOSIVE).length;
    final strC = signals.where((s) => s.strength == SignalStrength.STRONG).length;
    final medC = signals.where((s) => s.strength == SignalStrength.MEDIUM).length;
    final wkC  = signals.where((s) => s.strength == SignalStrength.WEAK).length;
    double avg = 0;
    if (signals.isNotEmpty) {
      final total = signals.fold(0, (s, x) {
        switch (x.strength) {
          case SignalStrength.EXPLOSIVE: return s + 4;
          case SignalStrength.STRONG: return s + 3;
          case SignalStrength.MEDIUM: return s + 2;
          case SignalStrength.WEAK: return s + 1;
        }
      });
      avg = total / signals.length;
    }

    print("🚀 ANALİZ v2: ${signals.length} sinyal | ⚡$expC 💪$strC ⚖️$medC 📊$wkC");

    return AnalysisResult(
      signals: signals,
      quantumTrendLine: mainMT.reversed.toList(),
      yellowLine: mainDL.reversed.toList(),
      blueATRLine: blueA.reversed.toList(),
      qmlBullLevels: qmlBull.reversed.toList(),
      qmlBearLevels: qmlBear.reversed.toList(),
      stats: AnalysisStats(
        totalSignals: signals.length,
        explosiveSignals: expC,
        strongSignals: strC,
        mediumSignals: medC,
        weakSignals: wkC,
        avgSignalStrength: avg,
      ),
    );
  }
}