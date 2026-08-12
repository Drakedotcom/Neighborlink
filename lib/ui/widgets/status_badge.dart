import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// LuL Label to state offer / request.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  /// Constructor for the available / reserved / closed
  factory StatusBadge.forStatus({
    required String label,
    required StatusTone tone,
    IconData? icon,
    bool dense = false,
  }) {
    return StatusBadge(
      label: label,
      color: switch (tone) {
        StatusTone.available => AppColors.statusAvailable,
        StatusTone.reserved => AppColors.statusReserved,
        StatusTone.closed => AppColors.statusClosed,
      },
      icon: icon,
      dense: dense,
    );
  }

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual tone of status
enum StatusTone { available, reserved, closed }
