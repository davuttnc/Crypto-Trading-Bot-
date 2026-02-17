// lib/views/anasayfa.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api/binance_api.dart';
import 'dart:async';
import 'dart:math';

// ══════════════════════════════════════════════════════════════════════════════
// YENİ NESİL ANASAYFA - MODERN DASHBOARD
// ══════════════════════════════════════════════════════════════════════════════

class Anasayfa extends StatefulWidget {
  const Anasayfa({super.key});
  
  @override
  State<Anasayfa> createState() => _AnasayfaState();
}

class _AnasayfaState extends State<Anasayfa> with TickerProviderStateMixin {
  final BinanceApiService _binance = BinanceApiService();
  
  List<BinanceTicker> _allTickers = [];
  List<BinanceTicker> _topGainers = [];
  List<BinanceTicker> _topLosers = [];
  double _totalVolume = 0.0;
  Timer? _refreshTimer;
  
  late AnimationController _pulseController;
  late AnimationController _slideController;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Animasyon controller'ları
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _loadData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (timer) => _loadData(),
    );
    
    _slideController.forward();
  }

  Future<void> _loadData() async {
    try {
      final tickers = await _binance.getMarketTickers();
      
      if (!mounted) return;
      
      // Volume hesapla
      double volume = 0;
      for (var t in tickers) {
        volume += double.parse(t.quoteVolume);
      }
      
      // Top gainers (en çok yükselenler)
      final gainers = tickers.where((t) {
        final change = double.tryParse(t.priceChangePercent) ?? 0;
        return change > 0;
      }).toList()
        ..sort((a, b) => double.parse(b.priceChangePercent)
            .compareTo(double.parse(a.priceChangePercent)));
      
      // Top losers (en çok düşenler)
      final losers = tickers.where((t) {
        final change = double.tryParse(t.priceChangePercent) ?? 0;
        return change < 0;
      }).toList()
        ..sort((a, b) => double.parse(a.priceChangePercent)
            .compareTo(double.parse(b.priceChangePercent)));
      
      setState(() {
        _allTickers = tickers;
        _topGainers = gainers.take(5).toList();
        _topLosers = losers.take(5).toList();
        _totalVolume = volume;
        _isLoading = false;
      });
      
      debugPrint("✅ Anasayfa: ${tickers.length} coin, Volume: \$${(volume / 1000000000).toStringAsFixed(2)}B");
      
    } catch (e) {
      debugPrint("❌ Anasayfa veri hatası: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E11),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ══════════════════════════════════════════════════════════════
            // MODERN APP BAR
            // ══════════════════════════════════════════════════════════════
            _buildAppBar(),
            
            // ══════════════════════════════════════════════════════════════
            // HERO SECTION - Piyasa Özeti
            // ══════════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: _buildHeroSection(),
            ),
            
            // ══════════════════════════════════════════════════════════════
            // HIZLI ERİŞİM BUTONLARI
            // ══════════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: _buildQuickActions(),
            ),
            
            // ══════════════════════════════════════════════════════════════
            // TOP GAINERS
            // ══════════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: _buildSection(
                title: '🚀 En Çok Yükselenler',
                subtitle: 'Son 24 saat',
                color: const Color(0xFF00FF41),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildGainersList(),
            ),
            
            // ══════════════════════════════════════════════════════════════
            // TOP LOSERS
            // ══════════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: _buildSection(
                title: '📉 En Çok Düşenler',
                subtitle: 'Son 24 saat',
                color: const Color(0xFFEF5350),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildLosersList(),
            ),
            
            // ══════════════════════════════════════════════════════════════
            // FOOTER SPACE
            // ══════════════════════════════════════════════════════════════
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODERN APP BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1E2329),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E2329),
                const Color(0xFF0B0E11).withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00F5FF), Color(0xFF0080FF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.dashboard_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dashboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Piyasa Genel Görünüm',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Refresh butonu
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: IconButton(
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.cyanAccent),
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
                          onPressed: _isLoading ? null : _loadData,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HERO SECTION - Piyasa Özeti
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeroSection() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutQuart,
      )),
      child: FadeTransition(
        opacity: _slideController,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E2329),
                Color(0xFF2A2E39),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.cyanAccent.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Arka plan animasyonu
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 1.5,
                          colors: [
                            Colors.cyanAccent.withOpacity(0.1 * _pulseController.value),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // İçerik
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.trending_up, color: Colors.cyanAccent, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '24H',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Ana metrikler
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Toplam Hacim',
                            '\$${(_totalVolume / 1000000000).toStringAsFixed(2)}B',
                            Icons.water_drop_outlined,
                            const Color(0xFF00F5FF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Aktif Coin',
                            '${_allTickers.length}',
                            Icons.token_outlined,
                            const Color(0xFFFFB800),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Yükselenler',
                            '${_topGainers.length}',
                            Icons.arrow_upward,
                            const Color(0xFF00FF41),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Düşenler',
                            '${_topLosers.length}',
                            Icons.arrow_downward,
                            const Color(0xFFEF5350),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HIZLI ERİŞİM BUTONLARI
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              '🔍 Tarama',
              'Coin Tara',
              const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              () {
                // Navigate to trade page
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              '📊 Grafik',
              'Analiz Et',
              const LinearGradient(
                colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
              ),
              () {
                // Navigate to chart page
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, String subtitle, Gradient gradient, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSection({required String title, required String subtitle, required Color color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GAINERS LIST
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGainersList() {
    if (_topGainers.isEmpty) {
      return _buildLoadingState();
    }
    
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _topGainers.length,
        itemBuilder: (context, index) {
          final ticker = _topGainers[index];
          return _buildCoinCard(ticker, true);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOSERS LIST
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLosersList() {
    if (_topLosers.isEmpty) {
      return _buildLoadingState();
    }
    
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _topLosers.length,
        itemBuilder: (context, index) {
          final ticker = _topLosers[index];
          return _buildCoinCard(ticker, false);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COIN CARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCoinCard(BinanceTicker ticker, bool isGainer) {
    final changePercent = double.parse(ticker.priceChangePercent);
    final color = isGainer ? const Color(0xFF00FF41) : const Color(0xFFEF5350);
    
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E2329),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coin ismi
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticker.symbol.replaceAll('USDT', ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  isGainer ? Icons.arrow_upward : Icons.arrow_downward,
                  color: color,
                  size: 16,
                ),
              ],
            ),
            
            const Spacer(),
            
            // Fiyat
            Text(
              '\$${double.parse(ticker.lastPrice).toStringAsFixed(4)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Değişim
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOADING STATE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLoadingState() {
    return const SizedBox(
      height: 140,
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.cyanAccent,
          strokeWidth: 2,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXIT DIALOG
  // ═══════════════════════════════════════════════════════════════════════════
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2329),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.redAccent.withOpacity(0.3),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF5350), Color(0xFFE53935)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.exit_to_app_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'Çıkış Yap',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Uygulamadan çıkmak istediğinize emin misiniz?',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'İptal',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => SystemNavigator.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Çıkış',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}