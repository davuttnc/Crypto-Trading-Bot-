// lib/components/grafik_katmanlari/ui/indikator_buton.dart
import 'package:flutter/material.dart';

class IndikatorButon extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool isLoading;
  final VoidCallback? onTap;
  final Color activeColor;
  final Color inactiveColor;

  const IndikatorButon({
    super.key,
    required this.label,
    required this.icon,
    required this.isActive,
    this.isLoading = false,
    this.onTap,
    this.activeColor = const Color(0xFFFFC107),
    this.inactiveColor = const Color(0xFF888888),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive 
            ? activeColor.withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: activeColor,
                ),
              )
            else
              Icon(
                icon,
                color: isActive ? activeColor : inactiveColor,
                size: 16,
              ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}