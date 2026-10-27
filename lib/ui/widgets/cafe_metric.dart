import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class CafeMetric extends StatelessWidget {
  const CafeMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.green, size: 19),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
