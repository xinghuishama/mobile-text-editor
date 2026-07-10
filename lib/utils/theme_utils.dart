import 'package:flutter/material.dart';

class ThemeUtils {
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    ),
    cardTheme: const CardTheme(
      color: Colors.white,
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.grey[900],
    scaffoldBackgroundColor: Colors.grey[900],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[850],
      foregroundColor: Colors.white,
    ),
    cardTheme: CardTheme(
      color: Colors.grey[850],
    ),
  );
}