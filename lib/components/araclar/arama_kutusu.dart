import 'package:flutter/material.dart';

class AramaKutusu extends StatefulWidget {
  final Function(String) onSearch;
  const AramaKutusu({super.key, required this.onSearch});

  @override
  State<AramaKutusu> createState() => _AramaKutusuState();
}

class _AramaKutusuState extends State<AramaKutusu> {
  final TextEditingController _controller = TextEditingController();

  void _handleSearch() {
    String text = _controller.text.trim().toUpperCase();
    if (text.isNotEmpty) {
      // Eğer kullanıcı USDT eklemediyse biz ekleyelim
      if (!text.endsWith("USDT")) {
        text = "${text}USDT";
      }
      widget.onSearch(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Kutu arka planı beyaz
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _controller,
        style: const TextStyle(color: Colors.black), // Yazı rengi siyah
        decoration: InputDecoration(
          hintText: 'Coin Ara (Örn: BTC veya AVAX)',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.blue),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.blue),
            onPressed: _handleSearch, // Butona basınca ara
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
        onSubmitted: (value) => _handleSearch(), // Enter'a basınca ara
      ),
    );
  }
}