import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:candlesticks/candlesticks.dart';

class MexcApiService {
  final String baseUrl = "https://api.mexc.com/api/v3";
  static final http.Client _client = http.Client();
  
  // Cache
  static Map<String, List<Candle>> _cache = {};
  static Map<String, DateTime> _cacheTime = {};

  Future<List<Candle>> fetchCandles(String symbol, String interval) async {
    final cacheKey = "${symbol}_$interval";
    
    try {
      // Cache kontrolü - 20 saniye
      if (_cache.containsKey(cacheKey) && _cacheTime.containsKey(cacheKey)) {
        final timeDiff = DateTime.now().difference(_cacheTime[cacheKey]!);
        if (timeDiff.inSeconds < 20) {
          return _cache[cacheKey]!;
        }
      }

      String formattedSymbol = symbol.toUpperCase().replaceAll("_", ""); 
      
      Map<String, String> intervalMap = {
        "1m": "1m", "5m": "5m", "15m": "15m", "30m": "30m",
        "1h": "60m", "4h": "4h", "1d": "1d", "1w": "1W", "1M": "1M",
      };

      String mexcInterval = intervalMap[interval] ?? interval;

      // Limit 500
      final response = await _client
          .get(
            Uri.parse('$baseUrl/klines?symbol=$formattedSymbol&interval=$mexcInterval&limit=500'),
          )
          .timeout(const Duration(seconds: 5)); // Hızlı timeout

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Candle> candles = data.map((e) => Candle(
          date: DateTime.fromMillisecondsSinceEpoch(e[0]),
          open: double.parse(e[1].toString()),
          high: double.parse(e[2].toString()),
          low: double.parse(e[3].toString()),
          close: double.parse(e[4].toString()),
          volume: double.parse(e[5].toString()),
        )).toList();

        final reversed = candles.reversed.toList();
        _cache[cacheKey] = reversed;
        _cacheTime[cacheKey] = DateTime.now();
        
        return reversed;
      }
      
      // Cache varsa döndür
      if (_cache.containsKey(cacheKey)) {
        return _cache[cacheKey]!;
      }
      return [];
    } catch (e) {
      // Sessiz hata - sadece cache'den döndür
      if (_cache.containsKey(cacheKey)) {
        return _cache[cacheKey]!;
      }
      return [];
    }
  }
  
  void dispose() {
    // Statik client kullanıldığı için kapatmıyoruz
  }
}