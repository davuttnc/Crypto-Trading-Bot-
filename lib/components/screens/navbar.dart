import 'package:flutter/material.dart';
import '../../views/anasayfa.dart';
import '../../views/haberler.dart';
import '../../views/market.dart'; 
import '../../views/grafik.dart';
import '../../views/trade.dart';

class MainNavBar extends StatefulWidget {
  const MainNavBar({super.key});

  @override
  State<MainNavBar> createState() => _MainNavBarState();
}

class _MainNavBarState extends State<MainNavBar> {
  int _selectedIndex = 0;
  String? _selectedCoin;

  List<Widget> get _pages => [
    const Anasayfa(), 
    MarketPage(
      onCoinSelected: (symbol) {
        setState(() {
          _selectedCoin = symbol;
          _selectedIndex = 3;
        });
      },
    ),
    TradePage(
      onCoinSelected: (symbol) {
        setState(() {
          _selectedCoin = symbol;
          _selectedIndex = 3;
        });
      },
    ),
    Grafik(initialSymbol: _selectedCoin),
    const NewsPage(), 
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2329),
          border: Border(
            top: BorderSide(
              color: Colors.cyanAccent.withOpacity(0.2),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF1E2329),
          selectedItemColor: Colors.cyanAccent,
          unselectedItemColor: Colors.white38,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          items: [
            _buildNavItem(
              icon: Icons.home_rounded,
              label: 'ANASAYFA',
              index: 0,
            ),
            _buildNavItem(
              icon: Icons.candlestick_chart,
              label: 'MARKET',
              index: 1,
            ),
            _buildNavItem(
              icon: Icons.radar,
              label: 'TARAMA',
              index: 2,
            ),
            _buildNavItem(
              icon: Icons.show_chart_rounded,
              label: 'GRAFİK',
              index: 3,
            ),
            _buildNavItem(
              icon: Icons.article_rounded,
              label: 'HABERLER',
              index: 4,
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected 
            ? Colors.cyanAccent.withOpacity(0.15) 
            : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: isSelected ? 26 : 24,
        ),
      ),
      label: label,
    );
  }
}