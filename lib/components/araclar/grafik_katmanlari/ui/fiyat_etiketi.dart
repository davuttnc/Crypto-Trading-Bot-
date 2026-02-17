// lib/components/grafik_katmanlari/ui/fiyat_etiketi.dart
import 'package:flutter/material.dart';

class FiyatEtiketi extends StatelessWidget {
  final double topPosition;
  final String emoji;
  final String fiyatText;
  final String? extraText;
  final Color backgroundColor;

  const FiyatEtiketi({
    super.key,
    required this.topPosition,
    required this.emoji,
    required this.fiyatText,
    this.extraText,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 4,
      top: topPosition,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: extraText != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        fiyatText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    extraText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                    ),
                  ),
                ],
              )
            : Text(
                '$emoji $fiyatText',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}