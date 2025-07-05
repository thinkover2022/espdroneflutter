import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:espdroneflutter/presentation/cubit/flight_control_cubit.dart';

class FlightDataDisplay extends StatelessWidget {
  const FlightDataDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlightControlCubit, FlightData>(
      builder: (context, flightData) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Flight Data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDataItem('Roll', flightData.roll, '°'),
                  _buildDataItem('Pitch', flightData.pitch, '°'),
                ],
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDataItem('Yaw', flightData.yaw, '°/s'),
                  _buildDataItem('Thrust', flightData.thrust, ''),
                ],
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    flightData.isFlying
                        ? Icons.flight_takeoff
                        : Icons.flight_land,
                    color: flightData.isFlying ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    flightData.isFlying ? 'Flying' : 'Landed',
                    style: TextStyle(
                      color: flightData.isFlying ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataItem(String label, double value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12.0,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          '${value.toStringAsFixed(2)}$unit',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class FlightDataPanel extends StatelessWidget {
  const FlightDataPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlightControlCubit, FlightData>(
      builder: (context, flightData) {
        return Container(
          height: 100.0,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniDataItem('R', flightData.roll, Colors.red),
              _buildMiniDataItem('P', flightData.pitch, Colors.blue),
              _buildMiniDataItem('Y', flightData.yaw, Colors.yellow),
              _buildMiniDataItem('T', flightData.thrust, Colors.green),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniDataItem(String label, double value, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.0,
          ),
        ),
      ],
    );
  }
}

class FlightStatusIndicator extends StatelessWidget {
  const FlightStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlightControlCubit, FlightData>(
      builder: (context, flightData) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: flightData.isFlying ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                flightData.isFlying ? Icons.flight_takeoff : Icons.flight_land,
                color: Colors.white,
                size: 16.0,
              ),
              const SizedBox(width: 6.0),
              Text(
                flightData.isFlying ? 'FLYING' : 'LANDED',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
