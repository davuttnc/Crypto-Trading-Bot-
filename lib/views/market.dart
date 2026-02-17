import 'package:flutter/material.dart';
import '../services/api/binance_api.dart'; // Güncellediğimiz api dosyasını import et

class MarketPage extends StatefulWidget {
  final Function(String)? onCoinSelected; // Coin seçildiğinde tetiklenecek callback
  
  const MarketPage({super.key, this.onCoinSelected});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  // Mevcut servisi kullanıyoruz
  final BinanceApiService _apiService = BinanceApiService();
  final TextEditingController _searchController = TextEditingController();

  List<BinanceTicker> _allTickers = [];
  List<BinanceTicker> _filteredTickers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getData();
    
    // Arama dinleyicisi
    _searchController.addListener(() {
      _filterList(_searchController.text);
    });
  }

  // API'den veriyi çek
  Future<void> _getData() async {
    setState(() => _isLoading = true);
    // getMarketTickers fonksiyonunu kullanıyoruz
    List<BinanceTicker> data = await _apiService.getMarketTickers();
    
    if (mounted) {
      setState(() {
        _allTickers = data;
        _filteredTickers = data;
        _isLoading = false;
      });
    }
  }

  void _filterList(String query) {
    if (query.isEmpty) {
      setState(() => _filteredTickers = _allTickers);
    } else {
      setState(() {
        _filteredTickers = _allTickers
            .where((t) => t.symbol.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Görseldeki gibi açık tema mı istersin? Yoksa koyu mu kalsın? (Şu an koyu yapıyorum uyumlu olsun diye)
      // Eğer görseldeki gibi beyaz olsun istersen üst satırı: backgroundColor: Colors.white, yap.
      // Ben uygulamanın geneli koyu olduğu için koyu modda devam ediyorum:
      body: Container(
        color: const Color(0xFF0B0E11), // Koyu arka plan
        child: SafeArea(
          child: Column(
            children: [
              // --- ARAMA ÇUBUĞU ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2329),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search Coin",
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),

              // --- FİLTRE BUTONLARI (Görseldeki "Spot", "Futures" vb.) ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildTab("All", true),
                    _buildTab("Spot", false),
                    _buildTab("Futures", false),
                    _buildTab("Favorites", false),
                  ],
                ),
              ),

              const Divider(color: Colors.white10, height: 1),

              // --- LİSTE BAŞLIKLARI ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text("Pair / Vol", style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                    Expanded(flex: 3, child: Text("Last Price", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                    Expanded(flex: 2, child: Text("Change", textAlign: TextAlign.end, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                  ],
                ),
              ),

              // --- COIN LİSTESİ ---
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF0ECB81)))
                    : RefreshIndicator(
                        onRefresh: _getData,
                        color: const Color(0xFF0ECB81),
                        backgroundColor: const Color(0xFF1E2329),
                        child: ListView.builder(
                          itemCount: _filteredTickers.length,
                          itemBuilder: (context, index) {
                            return _buildCoinRow(_filteredTickers[index]);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tab Görünümü (Sadece görsel amaçlı şimdilik)
  Widget _buildTab(String text, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 20.0),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 15,
        ),
      ),
    );
  }

  // Liste Elemanı Satırı
  Widget _buildCoinRow(BinanceTicker ticker) {
    final double change = double.tryParse(ticker.priceChangePercent) ?? 0.0;
    final bool isUp = change >= 0;
    final Color color = isUp ? const Color(0xFF0ECB81) : const Color(0xFFF6465D);
    
    // Sembolü temizle (BTCUSDT -> BTC)
    final String symbol = ticker.symbol.replaceAll("USDT", "");
    
    return InkWell(
      onTap: () {
        // Callback varsa onu çağır (navbar üzerinden grafik sayfasına geç)
        if (widget.onCoinSelected != null) {
          widget.onCoinSelected!(ticker.symbol);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          children: [
            // 1. SOL KISIM: İSİM VE HACİM
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: symbol,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                      children: const [
                         TextSpan(text: " /USDT", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.normal)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatVolume(ticker.quoteVolume),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),

            // 2. ORTA KISIM: FİYAT
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center, // Fiyat ortada olsun
                children: [
                  Text(
                    double.parse(ticker.lastPrice).toString(), // Sıfırları temizle
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // TL karşılığı eklenebilir, şimdilik boş
                ],
              ),
            ),

            // 3. SAĞ KISIM: DEĞİŞİM KUTUSU
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 75,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "${isUp ? '+' : ''}${change.toStringAsFixed(2)}%",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hacim formatlayıcı (84.04K gibi)
  String _formatVolume(String val) {
    double v = double.tryParse(val) ?? 0;
    if (v >= 1000000) return "${(v/1000000).toStringAsFixed(2)}M";
    if (v >= 1000) return "${(v/1000).toStringAsFixed(2)}K";
    return v.toStringAsFixed(2);
  }
}