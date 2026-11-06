import 'package:flutter/widgets.dart';

/// Íconos de [Lucide](https://lucide.dev) (licencia ISC) desde la fuente local
/// `assets/fonts/lucide/lucide.ttf` (paquete `lucide-static` 1.68.0).
///
/// Es la iconografía de la app (guía visual, "Iconografía"). Para agregar un
/// ícono, busca su nombre en `codepoints.json` de `lucide-static` y suma una
/// constante aquí. En las compilaciones de lanzamiento Flutter solo incluye los
/// glifos que se usan (*tree shaking* de íconos).
abstract final class LucideIcons {
  static const _family = 'Lucide';

  static const IconData activity = IconData(0xe038, fontFamily: _family);
  static const IconData arrowDown = IconData(0xe042, fontFamily: _family);
  static const IconData arrowLeft = IconData(0xe048, fontFamily: _family);
  static const IconData arrowRight = IconData(0xe049, fontFamily: _family);
  static const IconData arrowUp = IconData(0xe04a, fontFamily: _family);
  static const IconData arrowUpRight = IconData(0xe04d, fontFamily: _family);
  static const IconData badgeCheck = IconData(0xe241, fontFamily: _family);
  static const IconData calendar = IconData(0xe063, fontFamily: _family);
  static const IconData calendarCheck = IconData(0xe2b7, fontFamily: _family);
  static const IconData camera = IconData(0xe064, fontFamily: _family);
  static const IconData chartColumn = IconData(0xe2a3, fontFamily: _family);
  static const IconData chartPie = IconData(0xe06b, fontFamily: _family);
  static const IconData check = IconData(0xe06c, fontFamily: _family);
  static const IconData chevronDown = IconData(0xe06d, fontFamily: _family);
  static const IconData chevronLeft = IconData(0xe06e, fontFamily: _family);
  static const IconData chevronRight = IconData(0xe06f, fontFamily: _family);
  static const IconData circleAlert = IconData(0xe077, fontFamily: _family);
  static const IconData circleCheck = IconData(0xe226, fontFamily: _family);
  static const IconData circleQuestionMark = IconData(
    0xe082,
    fontFamily: _family,
  );
  static const IconData circleX = IconData(0xe084, fontFamily: _family);
  static const IconData clock = IconData(0xe087, fontFamily: _family);
  static const IconData cloudOff = IconData(0xe08d, fontFamily: _family);
  static const IconData copy = IconData(0xe09e, fontFamily: _family);
  static const IconData droplet = IconData(0xe0b4, fontFamily: _family);
  static const IconData dumbbell = IconData(0xe3a1, fontFamily: _family);
  static const IconData egg = IconData(0xe25d, fontFamily: _family);
  static const IconData eye = IconData(0xe0ba, fontFamily: _family);
  static const IconData eyeOff = IconData(0xe0bb, fontFamily: _family);
  static const IconData fileText = IconData(0xe0cc, fontFamily: _family);
  static const IconData flag = IconData(0xe0d1, fontFamily: _family);
  static const IconData flame = IconData(0xe0d2, fontFamily: _family);
  static const IconData history = IconData(0xe1f5, fontFamily: _family);
  static const IconData house = IconData(0xe0f5, fontFamily: _family);
  static const IconData idCard = IconData(0xe617, fontFamily: _family);
  static const IconData image = IconData(0xe0f6, fontFamily: _family);
  static const IconData imageOff = IconData(0xe1c0, fontFamily: _family);
  static const IconData images = IconData(0xe5c4, fontFamily: _family);
  static const IconData info = IconData(0xe0f9, fontFamily: _family);
  static const IconData link = IconData(0xe102, fontFamily: _family);
  static const IconData lock = IconData(0xe10b, fontFamily: _family);
  static const IconData logOut = IconData(0xe10e, fontFamily: _family);
  static const IconData mail = IconData(0xe10f, fontFamily: _family);
  static const IconData minus = IconData(0xe11c, fontFamily: _family);
  static const IconData notebookPen = IconData(0xe596, fontFamily: _family);
  static const IconData plus = IconData(0xe13d, fontFamily: _family);
  static const IconData qrCode = IconData(0xe1df, fontFamily: _family);
  static const IconData refreshCw = IconData(0xe145, fontFamily: _family);
  static const IconData ruler = IconData(0xe14b, fontFamily: _family);
  static const IconData salad = IconData(0xe3a8, fontFamily: _family);
  static const IconData scale = IconData(0xe212, fontFamily: _family);
  static const IconData scan = IconData(0xe257, fontFamily: _family);
  static const IconData search = IconData(0xe151, fontFamily: _family);
  static const IconData settings = IconData(0xe154, fontFamily: _family);
  static const IconData share2 = IconData(0xe156, fontFamily: _family);
  static const IconData slidersHorizontal = IconData(
    0xe29a,
    fontFamily: _family,
  );
  static const IconData sparkles = IconData(0xe412, fontFamily: _family);
  static const IconData target = IconData(0xe180, fontFamily: _family);
  static const IconData trash2 = IconData(0xe18e, fontFamily: _family);
  static const IconData trendingDown = IconData(0xe190, fontFamily: _family);
  static const IconData trendingUp = IconData(0xe191, fontFamily: _family);
  static const IconData triangleAlert = IconData(0xe193, fontFamily: _family);
  static const IconData unlink = IconData(0xe19c, fontFamily: _family);
  static const IconData user = IconData(0xe19f, fontFamily: _family);
  static const IconData userCheck = IconData(0xe1a0, fontFamily: _family);
  static const IconData userPlus = IconData(0xe1a2, fontFamily: _family);
  static const IconData userRound = IconData(0xe468, fontFamily: _family);
  static const IconData userRoundSearch = IconData(0xe578, fontFamily: _family);
  static const IconData users = IconData(0xe1a4, fontFamily: _family);
  static const IconData usersRound = IconData(0xe46e, fontFamily: _family);
  static const IconData utensils = IconData(0xe2f6, fontFamily: _family);
  static const IconData utensilsCrossed = IconData(0xe2f7, fontFamily: _family);
  static const IconData weight = IconData(0xe530, fontFamily: _family);
  static const IconData whistle = IconData(0xe74d, fontFamily: _family);
  static const IconData wifiOff = IconData(0xe1af, fontFamily: _family);
  static const IconData x = IconData(0xe1b2, fontFamily: _family);
}
