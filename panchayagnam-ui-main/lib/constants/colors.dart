import 'package:flutter/material.dart';

class AppColors {
  // ── Primary Institutional Emerald (Panchayagnam FinTech theme) ─────────────
  static const Color primary        = Color(0xFF059669); // institutional emerald green
  static const Color primaryLight   = Color(0xFF10B981); // vibrant jade green
  static const Color primaryDark    = Color(0xFF047857); // deep forest emerald
  static const Color primaryBg      = Color(0xFFECFDF5); // very soft clean mint
  static const Color accentViolet   = Color(0xFF34D399); // bright mint accent

  // ── Aliases (keeps existing code compiling unchanged) ──────────────────────
  static const Color primaryBlue    = primary;
  static const Color darkBlue       = primaryDark;
  static const Color featureIconColor = primaryLight;

  // ── Sidebar (Institutional Obsidian & Slate) ──────────────────────────────
  static const Color sidebarBg      = Color(0xFF061A17); // deep obsidian emerald
  static const Color sidebarActive  = Color(0xFF10B981);
  static const Color sidebarText    = Color(0xFFCBD5E1); // soft slate
  static const Color sidebarIcon    = Color(0xFF94A3B8); // clean slate icon
  static const Color sidebarHover   = Color(0xFF0C2B24);

  // ── Page / Card Backgrounds (Tradetron / Stocks Developer standard) ───────
  static const Color scaffold       = Color(0xFFF8FAFC); // clean slate-light
  static const Color backgroundColor = scaffold;
  static const Color cardBg         = Color(0xFFFFFFFF);
  static const Color white          = Color(0xFFFFFFFF);
  static const Color headerBg       = Color(0xFFFFFFFF);

  // ── Stat Card Accents ──────────────────────────────────────────────────────
  static const Color cardPurple     = Color(0xFF059669);
  static const Color cardViolet     = Color(0xFF0D9488);
  static const Color cardLavender   = Color(0xFF10B981);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFF0F172A); // dark charcoal slate
  static const Color textSecondary  = Color(0xFF64748B); // muted slate
  static const Color textHint       = Color(0xFF94A3B8);
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
  static const Color borderColor    = Color(0xFFE2E8F0); // clean slate border
  static const Color divider        = Color(0xFFF1F5F9);

  // ── Icon ──────────────────────────────────────────────────────────────────
  static const Color iconColor      = Color(0xFF64748B);

  // ── Market Ticker Bar ─────────────────────────────────────────────────────
  static const Color tickerBg       = Color(0xFF0F172A); // dark charcoal
  static const Color tickerText     = Color(0xFFE2E8F0);
}
