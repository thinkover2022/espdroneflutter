import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:espdroneflutter/presentation/pages/main_page.dart';
import 'package:espdroneflutter/utils/app_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 로그 레벨 설정 (ERROR만 표시하여 부하 감소)
  AppLogger.setQuiet(); // ERROR 레벨로 설정하여 불필요한 로그 제거
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ProviderScope(child: EspDroneApp()));
}

class EspDroneApp extends StatelessWidget {
  const EspDroneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP-Drone Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainPage(),
    );
  }
}
