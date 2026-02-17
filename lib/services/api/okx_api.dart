import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:candlesticks/candlesticks.dart';

class OkxApiService {
  final String baseUrl = "https://www.okx.com/api/v5/market";
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

      String formattedSymbol = symbol.contains("-SWAP") 
        ? symbol 
        : "${symbol.replaceFirst("USDT", "-USDT")}-SWAP";
      
      Map<String, String> okxMap = {
        "1m": "1m", "5m": "5m", "15m": "15m", "30m": "30m",
        "1h": "1H", "4h": "4H", "1d": "1D", "1w": "1W",
      };
      String okxInterval = okxMap[interval] ?? interval.toUpperCase();

      // Limit 300 (OKX max)
      final response = await _client
          .get(
            Uri.parse('$baseUrl/candles?instId=$formattedSymbol&bar=$okxInterval&limit=300'),
          )
          .timeout(const Duration(seconds: 5)); // Hızlı timeout

      if (response.statusCode == 200) {
        var res = json.decode(response.body);
        List<dynamic> data = res['data'];
        
        List<Candle> candles = data.map((e) => Candle(
          date: DateTime.fromMillisecondsSinceEpoch(int.parse(e[0])),
          open: double.parse(e[1]),
          high: double.parse(e[2]),
          low: double.parse(e[3]),
          close: double.parse(e[4]),
          volume: double.parse(e[5]),
        )).toList();
        
        _cache[cacheKey] = candles;
        _cacheTime[cacheKey] = DateTime.now();
        
        return candles;
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