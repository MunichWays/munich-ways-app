import 'dart:math' as math;

const double degrees2Radians = math.pi / 180.0;
const double radians2Degrees = 180.0 / math.pi;

double convertToDegrees(double radians) => radians * radians2Degrees;
double convertToRadians(double degrees) => degrees * degrees2Radians;
