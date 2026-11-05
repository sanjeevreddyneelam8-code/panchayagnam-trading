import 'package:flutter/material.dart';

class AppColors {
  // ── Primary Purple (NOTIONIC theme) ───────────────────────────────────────
  static const Color primary        = Color(0xFF7C3AED); // vivid purple
  static const Color primaryLight   = Color(0xFF9B59F5); // lighter purple
  static const Color primaryDark    = Color(0xFF5B21B6); // deep purple
  static const Color primaryBg      = Color(0xFFEDE9FE); // very light lavender
  static const Color accentViolet   = Color(0xFFA855F7); // violet accent

  // ── Legacy aliases (keeps existing code compiling unchanged) ──────────────
  static const Color primaryBlue    = primary;
  static const Color darkBlue       = primaryDark;
  static const Color featureIconColor = primaryLight;

  // ── Sidebar ────────────────────────────────────────────────────────────────
  static const Color sidebarBg      = Color(0xFF7C3AED);
  static const Color sidebarActive  = Color(0xFFFFFFFF);
  static const Color sidebarText    = Color(0xFFEDE9FE);
  static const Color sidebarIcon    = Color(0xFFDDD6FE);
  static const Color sidebarHover   = Color(0xFF6D28D9);

  // ── Page / Card Backgrounds ────────────────────────────────────────────────
  static const Color scaffold       = Color(0xFFF3F0FB);
  static const Color backgroundColor = scaffold;
  static const Color cardBg         = Color(0xFFFFFFFF);
  static const Color white          = Color(0xFFFFFFFF);
  static const Color headerBg       = Color(0xFFFFFFFF);

  // ── Stat Card Accents ──────────────────────────────────────────────────────
  static const Color cardPurple     = Color(0xFF7C3AED);
  static const Color cardViolet     = Color(0xFF8B5CF6);
  static const Color cardLavender   = Color(0xFFA78BFA);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFF1E1B4B);
  static const Color textSecondary  = Color(0xFF6B7280);
  static const Color textHint       = Color(0xFF9CA3AF);
  static const Color textWhite      = Color(0xFFFFFFFF);

  // ── Status / Semantic ──────────────────────────────────────────────────────
  static const Color success        = Color(0xFF10B981);
  static const Color successBg      = Color(0xFFD1FAE5);
  static const Color error          = Color(0xFFEF4444);
  static const Color errorBg        = Color(0xFFFEE2E2);
  static const Color warning        = Color(0xFFF59E0B);
  static const Color warningBg      = Color(0xFFFEF3C7);
  static const Color info           = Color(0xFF059669);
  static const Color infoBg         = Color(0xFFD1FAE5);

  // ── Borders / Dividers ─────────────────────────────────────────────────────
  static const Color borderColor    = Color(0xFFE5E7EB);
  static const Color divider        = Color(0xFFF3F4F6);

  // ── Icon ──────────────────────────────────────────────────────────────────
  static const Color iconColor      = Color(0xFF6B7280);

  // ── Market Ticker Bar ─────────────────────────────────────────────────────
  static const Color tickerBg       = Color(0xFF5B21B6);
  static const Color tickerText     = Color(0xFFEDE9FE);
}