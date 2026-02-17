
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api/haberler_api.dart';
import '../models/haber_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final HaberlerApiService _haberlerApi = HaberlerApiService();
  
  List<HaberModel> _allNews = [];
  List<HaberModel> _filteredNews = [];
  bool _isLoading = false;
  bool _isFirstLoad = true;
  String _selectedSource = 'TÜMÜ';
  
  final List<String> _sources = ['TÜMÜ', 'CoinTurk', 'KriptoKoin', 'BitcoinSis'];
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadNews();
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) _loadNews();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNews() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      if (_isFirstLoad) {
        _filteredNews = [];
      }
    });
    
    try {
      final haberler = await _haberlerApi.tumHaberleriGetir();
      
      if (mounted) {
        setState(() {
          _allNews = haberler;
          _filterNews();
          _isLoading = false;
          _isFirstLoad = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFirstLoad = false;
        });
        _showErrorSnackbar('Haberler yüklenemedi. İnternet bağlantınızı kontrol edin.');
      }
    }
  }

  void _filterNews() {
    if (_selectedSource == 'TÜMÜ') {
      _filteredNews = _allNews;
    } else {
      _filteredNews = _allNews.where((haber) => haber.kaynak == _selectedSource).toList();
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Haberi tarayıcıda aç
  Future<void> _openNewsLink(String url) async {
    try {
      String fixedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        fixedUrl = 'https://$url';
      }
      
      final uri = Uri.parse(fixedUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackbar('Link açılamadı');
      }
    } catch (e) {
      _showErrorSnackbar('Haber açılırken bir hata oluştu');
    }
  }

  // Haberin pozitif mi negatif mi olduğunu belirle
  bool _isPositiveNews(String baslik, String aciklama) {
    final text = '${baslik.toLowerCase()} ${aciklama.toLowerCase()}';
    
    final positiveWords = [
      'yükseliş', 'artış', 'rekor', 'kazanç', 'büyüme', 'yükseldi',
      'arttı', 'başarı', 'lansman', 'işbirliği', 'kabul', 'onay',
      'yatırım', 'güçlü', 'olumlu', 'destek', 'gelişme'
    ];
    
    final negativeWords = [
      'düşüş', 'azalma', 'kayıp', 'düştü', 'azaldı', 'kriz',
      'dava', 'soruşturma', 'hack', 'saldırı', 'yasakla', 'ret',
      'tehlike', 'risk', 'olumsuz', 'çöküş', 'iflas'
    ];
    
    int positiveCount = positiveWords.where((word) => text.contains(word)).length;
    int negativeCount = negativeWords.where((word) => text.contains(word)).length;
    
    return positiveCount >= negativeCount;
  }

  // Kategori belirle
  String _getCategory(String baslik) {
    final text = baslik.toLowerCase();
    
    if (text.contains('bitcoin') || text.contains('btc')) return 'BTC';
    if (text.contains('ethereum') || text.contains('eth')) return 'ETH';
    if (text.contains('defi') || text.contains('merkezi olmayan')) return 'DeFi';
    if (text.contains('nft')) return 'NFT';
    if (text.contains('düzenlem') || text.contains('yasak') || text.contains('sec')) return 'REGULATION';
    if (text.contains('altcoin') || text.contains('shib') || text.contains('doge')) return 'ALTCOIN';
    
    return 'MARKET';
  }

  // Tarihi formatla
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Şimdi';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dk önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return DateFormat('dd MMM').format(date);
    }
  }

  // HABER DETAY MODAL GÖSTER
  void _showNewsDetail(HaberModel haber) {
    final isPositive = _isPositiveNews(haber.baslik, haber.aciklama);
    final category = _getCategory(haber.baslik);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF1E2329),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // BAŞLIK ÇUBUĞU
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2A2E39), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // KATEGORİ ETİKETİ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // POZİTİF/NEGATİF GÖSTERGE
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isPositive
                          ? const Color(0xFF26a69a).withOpacity(0.2)
                          : const Color(0xFFef5350).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: isPositive
                          ? const Color(0xFF26a69a)
                          : const Color(0xFFef5350),
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // DETAY İÇERİK
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KAYNAK VE DUYGU GÖSTERGESİ
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getSourceColor(haber.kaynak),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.source,
                                  size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                haber.kaynak,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // TARİH
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 14, color: Colors.white.withOpacity(0.5)),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(haber.tarih),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // DUYGU GÖSTERGESİ
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPositive
                                ? const Color(0xFF26a69a).withOpacity(0.15)
                                : const Color(0xFFef5350).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isPositive
                                  ? const Color(0xFF26a69a)
                                  : const Color(0xFFef5350),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isPositive ? 'POZİTİF' : 'NEGATİF',
                            style: TextStyle(
                              color: isPositive
                                  ? const Color(0xFF26a69a)
                                  : const Color(0xFFef5350),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // BAŞLIK
                    Text(
                      haber.baslik,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // AÇIKLAMA
                    Text(
                      haber.aciklama,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // TAM HABERİ AÇ BUTONU
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openNewsLink(haber.link);
                        },
                        icon: const Icon(Icons.open_in_new, size: 20),
                        label: const Text(
                          'TAM HABERİ OKU',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: const Color(0xFF0B0E11),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2329),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.article_rounded,
                  color: Colors.cyanAccent, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'KRİPTO HABERLER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.cyanAccent,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh,
                      color: Colors.cyanAccent, size: 22),
                  onPressed: _loadNews,
                  tooltip: 'Yenile',
                ),
        ],
      ),
      body: Column(
        children: [
          _buildSourceFilters(),
          if (_filteredNews.isNotEmpty) _buildNewsCount(),
          Expanded(
            child: _isFirstLoad && _isLoading
                ? _buildLoadingState()
                : _filteredNews.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: Colors.cyanAccent,
                        backgroundColor: const Color(0xFF1E2329),
                        onRefresh: _loadNews,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filteredNews.length,
                          itemBuilder: (context, index) {
                            return _buildNewsCard(_filteredNews[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCount() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E2329),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.cyanAccent.withOpacity(0.7)),
          const SizedBox(width: 6),
          Text(
            '${_filteredNews.length} haber gösteriliyor',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceFilters() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2329),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2E39), width: 1),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _sources.length,
        itemBuilder: (context, index) {
          final source = _sources[index];
          final isSelected = source == _selectedSource;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSource = source;
                _filterNews();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.cyanAccent.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.cyanAccent : Colors.white24,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  source,
                  style: TextStyle(
                    color: isSelected ? Colors.cyanAccent : Colors.white54,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewsCard(HaberModel haber) {
    final isPositive = _isPositiveNews(haber.baslik, haber.aciklama);
    final category = _getCategory(haber.baslik);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2A2E39),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showNewsDetail(haber),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ÜST BİLGİ ÇUBUĞU
              Row(
                children: [
                  // KATEGORİ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // POZİTİF/NEGATİF GÖSTERGE
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isPositive
                          ? const Color(0xFF26a69a).withOpacity(0.2)
                          : const Color(0xFFef5350).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: isPositive
                          ? const Color(0xFF26a69a)
                          : const Color(0xFFef5350),
                      size: 14,
                    ),
                  ),
                  const Spacer(),
                  // KAYNAK
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getSourceColor(haber.kaynak),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      haber.kaynak,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // BAŞLIK
              Text(
                haber.baslik,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // AÇIKLAMA
              if (haber.aciklama.isNotEmpty) ...[
                Text(
                  haber.aciklama,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],

              // ALT BİLGİ
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 12, color: Colors.white.withOpacity(0.4)),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(haber.tarih),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios,
                      size: 12, color: Colors.cyanAccent.withOpacity(0.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Colors.cyanAccent,
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text(
            'Haberler yükleniyor...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 60,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _isLoading ? 'Yükleniyor...' : 'Haber bulunamadı',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          if (!_isLoading) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadNews,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Yeniden Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.withOpacity(0.1),
                foregroundColor: Colors.cyanAccent,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.cyanAccent.withOpacity(0.3)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getSourceColor(String kaynak) {
    switch (kaynak) {
      case 'CoinTurk':
        return const Color(0xFF2196F3);
      case 'KriptoKoin':
        return const Color(0xFF9C27B0);
      case 'BitcoinSis':
        return const Color(0xFFFF9800);
      default:
        return Colors.cyanAccent;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'BTC':
        return const Color(0xFFf7931a);
      case 'ETH':
        return const Color(0xFF627eea);
      case 'ALTCOIN':
        return const Color(0xFF00bcd4);
      case 'DeFi':
        return const Color(0xFF9c27b0);
      case 'NFT':
        return const Color(0xFFff9800);
      case 'REGULATION':
        return const Color(0xFFef5350);
      default:
        return Colors.cyanAccent;
    }
  }
}