import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:espdroneflutter/presentation/pages/main_page.dart';
import 'package:espdroneflutter/presentation/cubit/drone_connection_cubit.dart';
import 'package:espdroneflutter/presentation/cubit/flight_control_cubit.dart';
import 'package:espdroneflutter/data/drivers/esp_udp_driver.dart';
import 'package:espdroneflutter/data/drivers/ble_driver.dart';

void main() {
  runApp(const EspDroneApp());
}

class EspDroneApp extends StatelessWidget {
  const EspDroneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => DroneConnectionCubit(
            EspUdpDriver(),
            BleDriver(),
          ),
        ),
        BlocProvider(
          create: (context) => FlightControlCubit(),
        ),
      ],
      child: MaterialApp(
        title: 'ESP-Drone Controller',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MainPage(),
      ),
    );
  }
}
