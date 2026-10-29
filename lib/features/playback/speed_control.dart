import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import 'playback_cubit.dart';

class SpeedControl extends StatelessWidget {
  /// Shared with the tempo marking, which opens the same menu.
  final MenuController controller;

  const SpeedControl({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackCubit>();
    final speed = context.select<PlaybackCubit, double>(
      (c) => c.state.practice.speed,
    );
    String percent(double s) => '${(s * 100).round()}%';
    return MenuAnchor(
      controller: controller,
      menuChildren: [
        for (final shortcut in const [0.5, 0.75, 1.0])
          MenuItemButton(
            onPressed: () => playback.setSpeed(shortcut),
            child: Text(percent(shortcut)),
          ),
        SizedBox(
          width: 240,
          child: Slider(
            value: speed,
            min: 0.25,
            max: 1.5,
            divisions: 25,
            label: percent(speed),
            onChanged: playback.setSpeed,
          ),
        ),
      ],
      builder: (context, controller, _) => TextButton.icon(
        key: const Key('speedButton'),
        icon: const Icon(Icons.speed, size: IconSizes.md),
        label: Text(percent(speed)),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
