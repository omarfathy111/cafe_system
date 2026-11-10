import 'package:cafe_system/core/utils/app_constants.dart';
import 'package:flutter/material.dart';

/// Shared title row for the main cafe pages.
class CafePageHeading extends StatelessWidget {
  const CafePageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null) ...[
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2ED),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.green),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
          ],
        ),
      ),
      ...actions,
    ],
  );
}
