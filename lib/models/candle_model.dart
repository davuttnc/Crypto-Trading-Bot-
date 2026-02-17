// Bu model Candlesticks paketinin anladığı dildir.
import 'package:candlesticks/candlesticks.dart';

// MEXC verisini bu formata çevireceğiz
class MexcCandle extends Candle {
  MexcCandle({
    required super.date,
    required super.high,
    required super.low,
    required super.open,
    required super.close,
    required super.volume,
  });

  // JSON'dan profesyonel modele dönüşüm
  factory MexcCandle.fromJson(List<dynamic> json) {
    return MexcCandle(
      date: DateTime.fromMillisecondsSinceEpoch(json[0] * 1000),
      open: double.parse(json[1].toString()),
      high: double.parse(json[2].toString()),
      low: double.parse(json[3].toString()),
      close: double.parse(json[4].toString()),
      volume: double.parse(json[5].toString()), // Hacim verisi eklendi!
    );
  }
}