// lib/utils/chart_debug.dart
// VERİ KONTROL VE DEBUG ARACI
import 'package:flutter/material.dart'; // ✅ Widget ve Colors için eklendi
import 'package:candlesticks/candlesticks.dart';

class ChartDebug {
  /// Veriyi kontrol et ve sorunları tespit et
  static void analyzeData(List<Candle> candles, String source) {
    print('\n🔍 ═══════════════════════════════════════');
    print('📊 CHART DEBUG - Veri Analizi: $source');
    print('═══════════════════════════════════════\n');

    if (candles.isEmpty) {
      print('❌ SORUN: Candles listesi BOŞ!');
      return;
    }

    print('✅ Toplam Mum Sayısı: ${candles.length}');
    
    // İLK 3 VE SON 3 MUMU GÖSTER
    print('\n📍 İlk 3 Mum:');
    for (int i = 0; i < 3 && i < candles.length; i++) {
      _printCandle(candles[i], i);
    }
    
    print('\n📍 Son 3 Mum:');
    for (int i = candles.length - 3; i < candles.length; i++) {
      if (i >= 0) _printCandle(candles[i], i);
    }

    // FİYAT ANALİZİ
    print('\n💰 Fiyat Analizi:');
    final prices = candles.map((c) => c.close).toList();
    final double minPrice = prices.reduce((a, b) => a < b ? a : b);
    final double maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final double avgPrice = prices.reduce((a, b) => a + b) / prices.length;
    final double priceRange = maxPrice - minPrice;
    
    print('  Min Fiyat: ${minPrice.toStringAsFixed(2)}');
    print('  Max Fiyat: ${maxPrice.toStringAsFixed(2)}');
    print('  Ort Fiyat: ${avgPrice.toStringAsFixed(2)}');
    print('  Fiyat Aralığı: ${priceRange.toStringAsFixed(2)}');
    
    // SORUN KONTROLÜ
    if (priceRange < 0.01) {
      print('\n❌ SORUN BULUNDU: Fiyat aralığı çok küçük!');
      print('   → Tüm mumlar aynı fiyat seviyesinde olabilir');
      print('   → Bu yüzden grafik DÜZ ÇİZGİ gibi görünür');
    }

    // TÜM MUMLAR AYNI MI?
    final allSame = prices.every((p) => (p - avgPrice).abs() < 0.0001);
    if (allSame) {
      print('\n❌ SORUN: TÜM MUMLAR AYNI FİYATTA!');
      print('   → API doğru çalışmıyor olabilir');
      print('   → Veri kaynağını kontrol et');
    }

    // HACİM ANALİZİ
    print('\n📊 Hacim Analizi:');
    final volumes = candles.map((c) => c.volume).toList();
    final double minVol = volumes.reduce((a, b) => a < b ? a : b);
    final double maxVol = volumes.reduce((a, b) => a > b ? a : b);
    final double avgVol = volumes.reduce((a, b) => a + b) / volumes.length;
    
    print('  Min Hacim: ${minVol.toStringAsFixed(0)}');
    print('  Max Hacim: ${maxVol.toStringAsFixed(0)}');
    print('  Ort Hacim: ${avgVol.toStringAsFixed(0)}');

    // TARİH ANALİZİ
    print('\n📅 Tarih Analizi:');
    final firstDate = candles.first.date;
    final lastDate = candles.last.date;
    final timeSpan = lastDate.difference(firstDate);
    
    print('  İlk Tarih: $firstDate');
    print('  Son Tarih: $lastDate');
    print('  Zaman Aralığı: ${timeSpan.inHours} saat (${timeSpan.inDays} gün)');
    
    // SIRALAMA KONTROLÜ
    bool isNewestFirst = candles.length > 1 && 
                        candles[0].date.isAfter(candles[1].date);
    print('\n🔄 Sıralama: ${isNewestFirst ? "NEWEST-FIRST ✅" : "OLDEST-FIRST ⚠️"}');

    // EMA HESAPLANABİLİR Mİ?
    print('\n🧮 EMA Hesaplama Kontrolü:');
    if (candles.length < 21) {
      print('❌ Yetersiz veri! EMA 21 için minimum 21 mum gerekli');
    } else {
      print('✅ Yeterli veri var (${candles.length} mum)');
    }

    // VOLUME ZONE HESAPLANABİLİR Mİ?
    print('\n📦 Volume Zone Kontrolü:');
    final hasVariation = maxVol > avgVol * 1.5;
    if (!hasVariation) {
      print('⚠️ Hacim varyasyonu düşük - zone oluşmayabilir');
      print('   → Hacim patlaması yok');
    } else {
      print('✅ Hacim varyasyonu var - zone\'lar oluşabilir');
    }

    print('\n═══════════════════════════════════════\n');
  }

  static void _printCandle(Candle c, int index) {
    print('  [$index] ${c.date} | O:${c.open.toStringAsFixed(2)} H:${c.high.toStringAsFixed(2)} L:${c.low.toStringAsFixed(2)} C:${c.close.toStringAsFixed(2)} | Vol:${c.volume.toStringAsFixed(0)}');
  }

  /// Trading chart'tan önce veriyi test et
  static bool isDataValid(List<Candle> candles) {
    if (candles.isEmpty) return false;
    if (candles.length < 21) return false;
    
    final prices = candles.map((c) => c.close).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;
    
    // Fiyat aralığı en az %0.1 olmalı
    return priceRange > (minPrice * 0.001);
  }

  /// Chart widget'ında kullan - Hata overlay'i göster
  static Widget buildDebugOverlay(List<Candle> candles) {
    String errorMessage;
    
    if (candles.isEmpty) {
      errorMessage = 'Veri yüklenemedi';
    } else if (candles.length < 21) {
      errorMessage = 'Yetersiz veri (${candles.length} mum)\nMinimum 21 mum gerekli';
    } else {
      errorMessage = 'Tüm mumlar aynı fiyatta\nAPI kontrolü gerekli';
    }

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline, 
              color: Colors.red, 
              size: 64,
            ),
            const SizedBox(height: 24),
            const Text(
              'VERİ HATASI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => analyzeData(candles, 'Manuel Kontrol'),
              icon: const Icon(Icons.bug_report),
              label: const Text('Debug Bilgisini Console\'da Göster'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Console çıktısını kontrol et',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}