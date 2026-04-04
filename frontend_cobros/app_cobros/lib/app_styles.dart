import 'package:flutter/material.dart';

class AppTextStyles {
  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );

  static const TextStyle body = TextStyle(fontSize: 16, color: Colors.black);

  static const TextStyle button = TextStyle(
    fontSize: 16,
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  // Agrega más estilos según tus necesidades
}

class AppButtonStyles {
  static final ButtonStyle green = ElevatedButton.styleFrom(
    backgroundColor: Colors.green,
    foregroundColor: Colors.white,
    textStyle: AppTextStyles.button,
  );
  static final ButtonStyle blue = ElevatedButton.styleFrom(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
    textStyle: AppTextStyles.button,
  );
  static final ButtonStyle orange = ElevatedButton.styleFrom(
    backgroundColor: Colors.orange,
    foregroundColor: Colors.white,
    textStyle: AppTextStyles.button,
  );
  static final ButtonStyle purple = ElevatedButton.styleFrom(
    backgroundColor: Colors.purple,
    foregroundColor: const Color.fromARGB(255, 255, 255, 255),
    textStyle: AppTextStyles.button,
  );
  static final ButtonStyle teal = ElevatedButton.styleFrom(
    backgroundColor: Colors.teal,
    foregroundColor: Colors.white,
    textStyle: AppTextStyles.button,
  );
  static final ButtonStyle red = ElevatedButton.styleFrom(
    backgroundColor: Colors.red,
    foregroundColor: Colors.white,
    textStyle: AppTextStyles.button,
  );
}
