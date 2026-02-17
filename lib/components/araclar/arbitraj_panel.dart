import 'package:flutter/material.dart';

class ArbitrajPanel extends StatelessWidget {
  final double binance;
  final double mexc;
  final double okx;

  const ArbitrajPanel({super.key, required this.binance, required this.mexc, required this.okx});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E222D),
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _priceBox("BINANCE", binance, Colors.orangeAccent),
          _priceBox("MEXC", mexc, Colors.blueAccent),
          _priceBox("OKX", okx, Colors.white70),
        ],
      ),
    );
  }

  Widget _priceBox(String title, double price, Color labelColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(
          "\$${price.toStringAsFixed(4)}",
          style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}