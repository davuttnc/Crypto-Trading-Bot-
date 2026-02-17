import 'package:flutter/material.dart';

class KontrolPaneli extends StatefulWidget {
  final String currentInterval;
  final Function(String) onIntervalChanged;
  final Function(String) onSearch;
  final bool showEma;
  final bool isCalculating;
  final VoidCallback onEmaToggle;

  const KontrolPaneli({
    super.key,
    required this.currentInterval,
    required this.onIntervalChanged,
    required this.onSearch,
    required this.showEma,
    required this.isCalculating,
    required this.onEmaToggle,
  });

  @override
  State<KontrolPaneli> createState() => _KontrolPaneliState();
}

class _KontrolPaneliState extends State<KontrolPaneli> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _timeframes = ["1m", "5m", "15m", "1h", "4h"];

  void _handleSearch() {
    String text = _controller.text.trim().toUpperCase();
    if (text.isNotEmpty) {
      if (!text.endsWith("USDT")) {
        text = "${text}USDT";
      }
      widget.onSearch(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E2329),
            const Color(0xFF181C20),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ARAMA KUTUSU
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E11),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.cyanAccent.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Coin Ara (Örn: BTC, ETH, AVAX)',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.cyanAccent,
                  size: 22,
                ),
                suffixIcon: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.cyanAccent,
                      size: 18,
                    ),
                  ),
                  onPressed: _handleSearch,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 4,
                ),
              ),
              onSubmitted: (value) => _handleSearch(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // ZAMAN DİLİMLERİ VE EMA BUTONU - GRID YAPISINDA
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E11),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Zaman Dilimi',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Grid layout - 3 sütun
                Row(
                  children: [
                    // Sol taraf: Zaman butonları (3x2 grid)
                    Expanded(
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: _timeframes.length,
                        itemBuilder: (context, index) {
                          final tf = _timeframes[index];
                          final isActive = tf == widget.currentInterval;
                          
                          return GestureDetector(
                            onTap: () => widget.onIntervalChanged(tf),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                gradient: isActive
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.cyanAccent.withOpacity(0.25),
                                        Colors.cyanAccent.withOpacity(0.15),
                                      ],
                                    )
                                  : null,
                                color: isActive ? null : const Color(0xFF1E2329),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isActive 
                                    ? Colors.cyanAccent 
                                    : Colors.white.withOpacity(0.1),
                                  width: isActive ? 1.5 : 1,
                                ),
                                boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: Colors.cyanAccent.withOpacity(0.2),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                      ),
                                    ]
                                  : null,
                              ),
                              child: Center(
                                child: Text(
                                  tf.toUpperCase(),
                                  style: TextStyle(
                                    color: isActive 
                                      ? Colors.cyanAccent 
                                      : Colors.white.withOpacity(0.5),
                                    fontSize: 13,
                                    fontWeight: isActive 
                                      ? FontWeight.bold 
                                      : FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Sağ taraf: EMA butonu (daha büyük)
                    GestureDetector(
                      onTap: widget.isCalculating ? null : widget.onEmaToggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 85,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: widget.showEma
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFFFFC107).withOpacity(0.3), // Sarı
                                  const Color(0xFFFF9800).withOpacity(0.2), // Turuncu
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  const Color(0xFF2A2E39), // Gri
                                  const Color(0xFF23272E), // Koyu gri
                                ],
                              ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.showEma 
                              ? const Color(0xFFFFC107) // Sarı kenarlık
                              : Colors.white.withOpacity(0.15), // Gri kenarlık
                            width: widget.showEma ? 1.5 : 1,
                          ),
                          boxShadow: widget.showEma
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFFC107).withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                ),
                              ]
                            : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.isCalculating)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFFFFC107),
                                ),
                              )
                            else
                              Icon(
                                Icons.analytics_rounded,
                                color: widget.showEma 
                                  ? const Color(0xFFFFC107) // Sarı
                                  : Colors.white.withOpacity(0.3), // Gri
                                size: 24,
                              ),
                            const SizedBox(height: 6),
                            Text(
                              'EMA',
                              style: TextStyle(
                                color: widget.showEma 
                                  ? const Color(0xFFFFC107) // Sarı
                                  : Colors.white.withOpacity(0.3), // Gri
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (widget.showEma && !widget.isCalculating)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 20,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFC107),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}