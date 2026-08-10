import 'package:flutter/material.dart';

/// The NeighborLink colour palette (green, natural, calm).
class AppColors {
  const AppColors._();

  // --- Brand -----------------------------------------------------------------
  /// Main brand green, used for the app bar, primary buttons and highlights.
  static const Color primary = Color(0xFF1B7F5A);
  static const Color primaryDark = Color(0xFF125B41);
  static const Color primaryLight = Color(0xFF4CAF87);

  /// Fresh secondary green used for accents and selected states.
  static const Color accent = Color(0xFF7CB342);
  static const Color accentSoft = Color(0xFFE7F3E4);

  // --- Neutrals --------------------------------------------------------------
  static const Color background = Color(0xFFF3F7F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEDF3EE);
  static const Color border = Color(0xFFDDE7E0);

  static const Color textPrimary = Color(0xFF16241D);
  static const Color textSecondary = Color(0xFF5B6E64);
  static const Color textDisabled = Color(0xFF9AA8A0);

  // --- Semantic status colours ----------------------------------------------
  /// "verfügbar" / "offen"
  static const Color statusAvailable = Color(0xFF2E9E63);

  /// "reserviert"
  static const Color statusReserved = Color(0xFFE0912F);

  /// "abgeholt" / "vergeben" / "übernommen"
  static const Color statusClosed = Color(0xFF7A8C84);

  /// Errors and destructive actions.
  static const Color danger = Color(0xFFC0453F);

  /// Informational hints.
  static const Color info = Color(0xFF3E7CB1);

  // --- Category accents (community feed) -------------------------------------
  static const Color categoryFood = Color(0xFF3EA76B);
  static const Color categoryFurniture = Color(0xFF8D6E52);
  static const Color categoryRide = Color(0xFF3E7CB1);
  static const Color categoryChildCare = Color(0xFFD1699B);
  static const Color categoryPetCare = Color(0xFFB07CC6);
  static const Color categoryEvent = Color(0xFFE0912F);
  static const Color categoryGeneral = Color(0xFF6C8079);

  /// Soft background derived from an accent colour, used behind icons.
  static Color tint(Color base) => Color.alphaBlend(
    base.withValues(alpha: 0.12),
    surface,
  );
}
