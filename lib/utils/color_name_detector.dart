import 'package:flutter/material.dart';

class ColorNameDetector {
  // Common color names with their RGB values
  static final List<Map<String, dynamic>> colorNames = [
    {'name': 'Black', 'r': 0, 'g': 0, 'b': 0},
    {'name': 'White', 'r': 255, 'g': 255, 'b': 255},
    {'name': 'Red', 'r': 255, 'g': 0, 'b': 0},
    {'name': 'Green', 'r': 0, 'g': 128, 'b': 0},
    {'name': 'Blue', 'r': 0, 'g': 0, 'b': 255},
    {'name': 'Yellow', 'r': 255, 'g': 255, 'b': 0},
    {'name': 'Orange', 'r': 255, 'g': 165, 'b': 0},
    {'name': 'Purple', 'r': 128, 'g': 0, 'b': 128},
    {'name': 'Pink', 'r': 255, 'g': 192, 'b': 203},
    {'name': 'Brown', 'r': 165, 'g': 42, 'b': 42},
    {'name': 'Gray', 'r': 128, 'g': 128, 'b': 128},
    {'name': 'Cyan', 'r': 0, 'g': 255, 'b': 255},
    {'name': 'Magenta', 'r': 255, 'g': 0, 'b': 255},
    {'name': 'Lime', 'r': 0, 'g': 255, 'b': 0},
    {'name': 'Navy', 'r': 0, 'g': 0, 'b': 128},
    {'name': 'Maroon', 'r': 128, 'g': 0, 'b': 0},
    {'name': 'Olive', 'r': 128, 'g': 128, 'b': 0},
    {'name': 'Teal', 'r': 0, 'g': 128, 'b': 128},
    {'name': 'Silver', 'r': 192, 'g': 192, 'b': 192},
    {'name': 'Gold', 'r': 255, 'g': 215, 'b': 0},
    {'name': 'Coral', 'r': 255, 'g': 127, 'b': 80},
    {'name': 'Salmon', 'r': 250, 'g': 128, 'b': 114},
    {'name': 'Crimson', 'r': 220, 'g': 20, 'b': 60},
    {'name': 'Turquoise', 'r': 64, 'g': 224, 'b': 208},
    {'name': 'Violet', 'r': 238, 'g': 130, 'b': 238},
    {'name': 'Indigo', 'r': 75, 'g': 0, 'b': 130},
    {'name': 'Beige', 'r': 245, 'g': 245, 'b': 220},
    {'name': 'Khaki', 'r': 240, 'g': 230, 'b': 140},
    {'name': 'Lavender', 'r': 230, 'g': 230, 'b': 250},
    {'name': 'Peach', 'r': 255, 'g': 218, 'b': 185},
    {'name': 'Mint', 'r': 189, 'g': 252, 'b': 201},
    {'name': 'Rose', 'r': 255, 'g': 228, 'b': 225},
    {'name': 'Tan', 'r': 210, 'g': 180, 'b': 140},
    {'name': 'Cream', 'r': 255, 'g': 253, 'b': 208},
    {'name': 'Ivory', 'r': 255, 'g': 255, 'b': 240},
    {'name': 'Charcoal', 'r': 54, 'g': 69, 'b': 79},
    {'name': 'Burgundy', 'r': 128, 'g': 0, 'b': 32},
    {'name': 'Amber', 'r': 255, 'g': 191, 'b': 0},
    {'name': 'Emerald', 'r': 80, 'g': 200, 'b': 120},
    {'name': 'Ruby', 'r': 224, 'g': 17, 'b': 95},
    {'name': 'Sapphire', 'r': 15, 'g': 82, 'b': 186},
    {'name': 'Sky Blue', 'r': 135, 'g': 206, 'b': 235},
    {'name': 'Forest Green', 'r': 34, 'g': 139, 'b': 34},
    {'name': 'Brick Red', 'r': 203, 'g': 65, 'b': 84},
    {'name': 'Royal Blue', 'r': 65, 'g': 105, 'b': 225},
    {'name': 'Light Blue', 'r': 173, 'g': 216, 'b': 230},
    {'name': 'Dark Green', 'r': 0, 'g': 100, 'b': 0},
    {'name': 'Light Green', 'r': 144, 'g': 238, 'b': 144},
    {'name': 'Dark Blue', 'r': 0, 'g': 0, 'b': 139},
    {'name': 'Light Yellow', 'r': 255, 'g': 255, 'b': 224},
    {'name': 'Dark Red', 'r': 139, 'g': 0, 'b': 0},
    {'name': 'Light Pink', 'r': 255, 'g': 182, 'b': 193},
    {'name': 'Dark Gray', 'r': 169, 'g': 169, 'b': 169},
    {'name': 'Light Gray', 'r': 211, 'g': 211, 'b': 211},
  ];

  /// Calculate the Euclidean distance between two colors in RGB space
  static double _colorDistance(int r1, int g1, int b1, int r2, int g2, int b2) {
    return ((r1 - r2) * (r1 - r2) + 
            (g1 - g2) * (g1 - g2) + 
            (b1 - b2) * (b1 - b2)).toDouble();
  }

  /// Get the human-readable name of a color from its RGB values
  static String getColorName(Color color) {
    int r = color.red;
    int g = color.green;
    int b = color.blue;

    // Handle very dark colors as black or dark gray
    if (r < 30 && g < 30 && b < 30) {
      return 'Black';
    }

    // Handle very light colors as white or light gray
    if (r > 240 && g > 240 && b > 240) {
      if ((r - g).abs() < 10 && (g - b).abs() < 10 && (r - b).abs() < 10) {
        return 'White';
      }
      return 'Light Gray';
    }

    // Find the closest color name by calculating distance
    double minDistance = double.infinity;
    String closestColor = 'Unknown';

    for (var colorMap in colorNames) {
      double distance = _colorDistance(
        r, g, b,
        colorMap['r'], colorMap['g'], colorMap['b'],
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestColor = colorMap['name'];
      }
    }

    return closestColor;
  }

  /// Get color name from RGB values directly
  static String getColorNameFromRGB(int r, int g, int b) {
    return getColorName(Color.fromRGBO(r, g, b, 1.0));
  }
}

