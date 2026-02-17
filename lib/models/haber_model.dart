/// Haber verilerinin yapısını tanımlayan model
class HaberModel {
  final String baslik;
  final String aciklama;
  final String link;
  final DateTime tarih;
  final String kaynak;

  HaberModel({
    required this.baslik,
    required this.aciklama,
    required this.link,
    required this.tarih,
    required this.kaynak,
  });

  // İleride JSON veya farklı formatlar gerekirse buraya factory metodları eklenebilir.
}