// «Хот унтлаа» — ангийн мафи, нэг утсаар.
//
// Офлайн. `INTERNET` зөвшөөрөл манифестад БАЙХГҮЙ (GDD-00 §5, CI шалгадаг).
// Дүрмийг `packages/engine`, дарааллыг `lib/game/game_controller.dart`,
// зураглалыг `lib/app_shell.dart` эзэмшинэ.

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter/services.dart';

import 'app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Утас ширээн дунд, босоо. Эргэлт нь ёслолыг тасалдуулна.
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const HotUntlaaApp());
}
