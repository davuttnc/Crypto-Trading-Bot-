import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:webfeed_plus/webfeed_plus.dart';
import '../../models/haber_model.dart';

class HaberlerApiService {
  // Kaynak listesi
  final List<Map<String, String>> _kaynaklar = [
    {"isim": "CoinTurk", "url": "https://coin-turk.com/feed"},
    {"isim": "KriptoKoin", "url": "https://kriptokoin.com/feed"},
    {"isim": "BitcoinSis", "url": "https://bitcoinsistemi.com/feed"}
  ];

  /// Tüm kaynaklardan haberleri toplar - TIMEOUT ile optimize edilmiş
  Future<List<HaberModel>> tumHaberleriGetir() async {
    List<HaberModel> tumHaberler = [];

    // Tüm kaynakları paralel çek (daha hızlı)
    final results = await Future.wait(
      _kaynaklar.map((kaynak) => _rssCek(kaynak["url"]!, kaynak["isim"]!)),
    );

    // Tüm sonuçları birleştir
    for (var veriler in results) {
      tumHaberler.addAll(veriler);
    }

    // Tarihe göre sıralama: En güncel en başta
    tumHaberler.sort((a, b) => b.tarih.compareTo(a.tarih));
    
    // İlk 50 haberi döndür (performans için)
    return tumHaberler.take(50).toList();
  }

  /// RSS verisini çekip model listesine dönüştürür - TIMEOUT eklendi
  Future<List<HaberModel>> _rssCek(String url, String kaynakIsmi) async {
    try {
      // 10 saniye timeout ekle
      final response = await http.get(
        Uri.parse(url),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print("$kaynakIsmi timeout oldu");
          return http.Response('Error', 408);
        },
      );

      if (response.statusCode == 200) {
        var feed = RssFeed.parse(utf8.decode(response.bodyBytes));
        
        return feed.items!.take(20).map((item) { // İlk 20 haber
          return HaberModel(
            baslik: item.title ?? "Başlık Yok",
            aciklama: _temizle(item.description ?? ""),
            link: item.link ?? "",
            tarih: item.pubDate ?? DateTime.now(),
            kaynak: kaynakIsmi,
          );
        }).toList();
      } else {
        print("$kaynakIsmi HTTP hatası: ${response.statusCode}");
      }
    } catch (e) {
      print("$kaynakIsmi hatası: $e");
    }
    return [];
  }

  /// HTML etiketlerini ve gereksiz boşlukları temizler
  String _temizle(String metin) {
    String temiz = metin.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '').trim();
    return temiz.length > 150 ? "${temiz.substring(0, 147)}..." : temiz;
  }
}