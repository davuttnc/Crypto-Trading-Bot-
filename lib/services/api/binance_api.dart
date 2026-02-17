import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:candlesticks/candlesticks.dart';

// --- MARKET LISTESI IÇIN MODEL ---
class BinanceTicker {
  final String symbol;
  final String lastPrice;
  final String priceChangePercent;
  final String quoteVolume; // Hacim

  BinanceTicker({
    required this.symbol,
    required this.lastPrice,
    required this.priceChangePercent,
    required this.quoteVolume,
  });

  factory BinanceTicker.fromJson(Map<String, dynamic> json) {
    return BinanceTicker(
      symbol: json['symbol'],
      lastPrice: double.parse(json['lastPrice']).toString(),
      priceChangePercent: json['priceChangePercent'],
      quoteVolume: double.parse(json['quoteVolume']).toStringAsFixed(2),
    );
  }
}

class BinanceApiService {
  final String baseUrl = "https://api.binance.com/api/v3";
  
  // HTTP client'ı tekrar kullanmak için
  static final http.Client _client = http.Client();
  
  // CACHE - Aynı veriyi tekrar çekmemek için
  static List<BinanceTicker>? _cachedTickers;
  static DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(seconds: 30); // 30 saniye cache
  
  static Map<String, List<Candle>> _candleCache = {};
  static Map<String, DateTime> _candleCacheTime = {};

  // --- 1. FONKSIYON: MARKET LISTESI VERILERINI ÇEKER (CACHE'Lİ) ---
  Future<List<BinanceTicker>> getMarketTickers() async {
    try {
      // Cache kontrolü
      if (_cachedTickers != null && 
          _cacheTime != null && 
          DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        print("✅ Cache'den market verisi döndürülüyor");
        return _cachedTickers!;
      }

      print("🌐 Binance'den market verisi çekiliyor...");
      
      final response = await _client
          .get(Uri.parse('$baseUrl/ticker/24hr'))
          .timeout(const Duration(seconds: 3)); // Hızlı timeout

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        
        // Sadece USDT paritelerini filtreleyip döndürür
        final tickers = data
            .where((item) => item['symbol'].toString().endsWith("USDT"))
            .map((item) => BinanceTicker.fromJson(item))
            .toList();
        
        // Cache'e kaydet
        _cachedTickers = tickers;
        _cacheTime = DateTime.now();
        
        print("✅ ${tickers.length} coin verisi alındı ve cache'lendi");
        return tickers;
      }
      
      print("❌ HTTP Hatası: ${response.statusCode}");
      // Cache varsa eski veriyi döndür
      if (_cachedTickers != null) {
        print("⚠️  Cache'den eski veri döndürülüyor");
        return _cachedTickers!;
      }
      return [];
    } catch (e) {
      print("❌ Market Verisi Hatası: $e");
      // Hata durumunda cache'deki veriyi döndür
      if (_cachedTickers != null) {
        print("⚠️  Hata! Cache'den eski veri döndürülüyor");
        return _cachedTickers!;
      }
      return [];
    }
  }

  // --- 2. FONKSIYON: GRAFIK (MUM) VERILERINI ÇEKER (CACHE'Lİ) ---
  Future<List<Candle>> fetchCandles(String symbol, String interval) async {
    final cacheKey = "${symbol}_$interval";
    
    try {
      // Cache kontrolü - 20 saniye
      if (_candleCache.containsKey(cacheKey) && 
          _candleCacheTime.containsKey(cacheKey)) {
        final timeDiff = DateTime.now().difference(_candleCacheTime[cacheKey]!);
        if (timeDiff.inSeconds < 20) {
          print("✅ Cache'den $symbol mum verisi döndürülüyor");
          return _candleCache[cacheKey]!;
        }
      }

      print("🌐 Binance'den $symbol mum verisi çekiliyor...");
      
      // Limit 500 - Dubai indikatörü için yeterli
      final response = await _client
          .get(
            Uri.parse('$baseUrl/klines?symbol=${symbol.toUpperCase()}&interval=$interval&limit=500'),
          )
          .timeout(const Duration(seconds: 3)); // Hızlı timeout

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        
        List<Candle> candles = data.map((e) => Candle(
          date: DateTime.fromMillisecondsSinceEpoch(e[0]),
          open: double.parse(e[1]),
          high: double.parse(e[2]),
          low: double.parse(e[3]),
          close: double.parse(e[4]),
          volume: double.parse(e[5]),
        )).toList();

        final reversed = candles.reversed.toList();
        
        // Cache'e kaydet
        _candleCache[cacheKey] = reversed;
        _candleCacheTime[cacheKey] = DateTime.now();
        
        print("✅ $symbol için ${candles.length} mum verisi alındı");
        return reversed;
      }
      
      print("❌ HTTP Hatası: ${response.statusCode}");
      // Cache varsa eski veriyi döndür
      if (_candleCache.containsKey(cacheKey)) {
        print("⚠️  Cache'den eski $symbol verisi döndürülüyor");
        return _candleCache[cacheKey]!;
      }
      return [];
    } catch (e) {
      print("❌ Binance Mum Hatası ($symbol): $e");
      // Hata durumunda cache'deki veriyi döndür
      if (_candleCache.containsKey(cacheKey)) {
        print("⚠️  Hata! Cache'den eski $symbol verisi döndürülüyor");
        return _candleCache[cacheKey]!;
      }
      return [];
    }
  }
  
  // Cache'i temizle
  static void clearCache() {
    _cachedTickers = null;
    _cacheTime = null;
    _candleCache.clear();
    _candleCacheTime.clear();
    print("🗑️  Cache temizlendi");
  }
  
  // Client'ı dispose et
  void dispose() {
    // Statik client'ı kapatmıyoruz, uygulama boyunca kullanılacak
  }
}