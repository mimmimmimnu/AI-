import 'package:flutter/material.dart';

class AppTheme {
  static const rose    = Color(0xFFE8556D);
  static const roseLt  = Color(0xFFF7C5CD);
  static const roseDk  = Color(0xFFC03650);
  static const blush   = Color(0xFFFDF0F2);
  static const cream   = Color(0xFFFBF7F5);
  static const nude    = Color(0xFFF2E8E4);
  static const textCol = Color(0xFF2D1A20);
  static const muted   = Color(0xFF9B7E85);

  static ThemeData get theme => ThemeData(
    colorSchemeSeed: rose,
    fontFamily: 'DMSans',
    scaffoldBackgroundColor: cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textCol,
      elevation: 0,
    ),
  );
}