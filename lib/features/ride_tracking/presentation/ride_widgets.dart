import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/shared_prefs/shared_prefs.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../data/ride_stores.dart';
import '../domain/models.dart';
import '../domain/ride_simulator.dart';
import '../ride_controller.dart';

class RideBanner extends StatelessWidget {
  const RideBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RideController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final ride = controller.session;
        if (ride == null) return const SizedBox.shrink();
        return FutureBuilder<List<String>>(
          future: Future.wait([
            controller.currentStationName(ride),
            controller.nextStationName(ride),
            controller.terminusName(ride),
          ]),
          builder: (context, snapshot) {
            final labels = snapshot.data ?? const ['…', '…', '…'];
            return GlassContainer(
              radius: 20,
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          ride.line.label,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: AppColors.onLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${labels[0]} → ${labels[1]}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${controller.etaLabel(ride)} · toward ${labels[2]}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Set destination',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showRideDestinationSheet(
                          context,
                          controller,
                          ride,
                        ),
                        icon: const Icon(
                          Icons.flag_outlined,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Wrong direction',
                        visualDensity: VisualDensity.compact,
                        onPressed: controller.reverseDirection,
                        icon: const Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      IconButton(
                        tooltip: 'I’m not on a train',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => controller.stopRide(
                          reason: 'Stopped by you',
                          notify: false,
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (!ride.confirmed) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Are you on this train?',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => controller.confirmTentative(false),
                          child: const Text('No'),
                        ),
                        FilledButton(
                          onPressed: () => controller.confirmTentative(true),
                          child: const Text('Yes'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Future<void> _showRideDestinationSheet(
  BuildContext context,
  RideController controller,
  RideSession ride,
) async {
  final stations = await controller.stationsFor(ride.line);
  final currentIndex = stations.indexWhere(
    (station) => station.id == ride.currentStationId,
  );
  if (!context.mounted || currentIndex < 0) return;
  final destinations = ride.direction > 0
      ? stations.skip(currentIndex + 1).toList()
      : stations.take(currentIndex).toList().reversed.toList();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        children: [
          const Text(
            'Set destination',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final station in destinations)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                station.id == ride.destinationStationId
                    ? Icons.flag_rounded
                    : Icons.train_outlined,
              ),
              title: Text(station.name),
              onTap: () async {
                await controller.setDestination(station.id);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    ),
  );
}

Future<void> showManualRideSheet(BuildContext context) async {
  await RideController.instance.initialize();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ManualRideSheet(),
  );
}

class _ManualRideSheet extends StatefulWidget {
  const _ManualRideSheet();
  @override
  State<_ManualRideSheet> createState() => _ManualRideSheetState();
}

class _ManualRideSheetState extends State<_ManualRideSheet> {
  TrainLine _line = TrainLine.lrt1;
  int _direction = 1;
  List<Station> _stations = const [];
  Station? _current;
  Station? _destination;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    final stations = await RideController.instance.stationsFor(_line);
    if (!mounted) return;
    setState(() {
      _stations = stations;
      _current = stations.first;
      _destination = null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final validDestinations = _current == null
        ? const <Station>[]
        : _stations
              .where(
                (station) => _direction > 0
                    ? station.orderIndex > _current!.orderIndex
                    : station.orderIndex < _current!.orderIndex,
              )
              .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'I’m on the train',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Works offline. Pick where you are and the direction of travel.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<TrainLine>(
              initialValue: _line,
              dropdownColor: AppColors.surfaceRaised,
              decoration: _decoration('Train line'),
              items: TrainLine.values
                  .map(
                    (line) =>
                        DropdownMenuItem(value: line, child: Text(line.label)),
                  )
                  .toList(),
              onChanged: (line) {
                if (line == null) return;
                setState(() {
                  _line = line;
                  _loading = true;
                });
                _loadStations();
              },
            ),
            const SizedBox(height: 12),
            if (!_loading) ...[
              DropdownButtonFormField<Station>(
                initialValue: _current,
                dropdownColor: AppColors.surfaceRaised,
                decoration: _decoration('Current station'),
                items: _stations
                    .map(
                      (station) => DropdownMenuItem(
                        value: station,
                        child: Text(station.name),
                      ),
                    )
                    .toList(),
                onChanged: (station) => setState(() {
                  _current = station;
                  _destination = null;
                }),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 1,
                    label: Text(
                      'Toward ${_stations.last.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ButtonSegment(
                    value: -1,
                    label: Text(
                      'Toward ${_stations.first.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (value) => setState(() {
                  _direction = value.first;
                  _destination = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Station?>(
                initialValue: _destination,
                dropdownColor: AppColors.surfaceRaised,
                decoration: _decoration('Destination (optional)'),
                items: [
                  const DropdownMenuItem<Station?>(
                    value: null,
                    child: Text('No destination'),
                  ),
                  ...validDestinations.map(
                    (station) => DropdownMenuItem<Station?>(
                      value: station,
                      child: Text(station.name),
                    ),
                  ),
                ],
                onChanged: (station) => setState(() => _destination = station),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading || _current == null
                    ? null
                    : () async {
                        await RideController.instance.manualStart(
                          line: _line,
                          direction: _direction,
                          current: _current!,
                          destinationStationId: _destination?.id,
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                icon: const Icon(Icons.train_rounded),
                label: const Text('Start station alerts'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.surfaceRaised,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

class RideSettingsSection extends StatefulWidget {
  const RideSettingsSection({super.key});
  @override
  State<RideSettingsSection> createState() => _RideSettingsSectionState();
}

class _RideSettingsSectionState extends State<RideSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final controller = RideController.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Train ride alerts',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _SettingSwitch(
                title: 'Automatic detection',
                subtitle: 'On-device station geofences; off by default',
                value: AppPrefs.trainRideAlertsEnabled,
                onChanged: (value) async {
                  if (!value) {
                    await controller.disable();
                    setState(() {});
                    return;
                  }
                  final enabled = await controller.enableAutoDetection();
                  if (!mounted) return;
                  setState(() {});
                  if (!enabled) {
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Background location needed'),
                        content: Text(
                          controller.statusMessage ??
                              'Enable location access in system settings.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Not now'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              controller.openAppSettings();
                            },
                            child: const Text('Open settings'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
              const Divider(color: AppColors.border),
              _SettingSwitch(
                title: 'Auto-detect boarding',
                subtitle: 'Turn off to use manual mode only',
                value: AppPrefs.trainAutoDetect,
                onChanged: (value) async {
                  await AppPrefs.setTrainAutoDetect(value);
                  if (mounted) setState(() {});
                },
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Approach lead time'),
                subtitle: const Text('How early to alert before a station'),
                trailing: DropdownButton<int>(
                  value: AppPrefs.trainApproachLeadSeconds,
                  dropdownColor: AppColors.surfaceRaised,
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 sec')),
                    DropdownMenuItem(value: 60, child: Text('1 min')),
                    DropdownMenuItem(value: 120, child: Text('2 min')),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    await AppPrefs.setTrainApproachLeadSeconds(value);
                    if (mounted) setState(() {});
                  },
                ),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alert style'),
                subtitle: const Text('Used for approaching-station alerts'),
                trailing: DropdownButton<String>(
                  value: AppPrefs.trainAlertStyle,
                  dropdownColor: AppColors.surfaceRaised,
                  items: const [
                    DropdownMenuItem(
                      value: 'sound_vibrate',
                      child: Text('Sound + vibrate'),
                    ),
                    DropdownMenuItem(
                      value: 'vibrate',
                      child: Text('Vibrate only'),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    await AppPrefs.setTrainAlertStyle(value);
                    if (mounted) setState(() {});
                  },
                ),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.train_rounded),
                title: const Text('I’m on the train'),
                subtitle: const Text('Start manually, even with GPS off'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showManualRideSheet(context),
              ),
              if (kDebugMode) ...[
                const Divider(color: AppColors.border),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Ride diagnostics'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RideDebugScreen()),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
    value: value,
    onChanged: onChanged,
  );
}

class RideDebugScreen extends StatefulWidget {
  const RideDebugScreen({super.key});
  @override
  State<RideDebugScreen> createState() => _RideDebugScreenState();
}

class _RideDebugScreenState extends State<RideDebugScreen> {
  final _store = RideLogStore();
  RideSimulationResult? _simulation;
  @override
  Widget build(BuildContext context) {
    final session = RideController.instance.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Ride diagnostics')),
      body: FutureBuilder<List<String>>(
        future: _store.read(),
        builder: (context, snapshot) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Session JSON',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              const JsonEncoder.withIndent(
                '  ',
              ).convert(session?.toJson() ?? {'state': 'idle'}),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 20),
            const Text(
              'Simulate ride (20× scripted time)',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final scenario in RideSimulationScenario.values)
                  ActionChip(
                    label: Text(scenario.name),
                    onPressed: () => setState(
                      () => _simulation = RideSimulator.run(scenario),
                    ),
                  ),
              ],
            ),
            if (_simulation != null) ...[
              const SizedBox(height: 10),
              Text(
                '${_simulation!.events.length} events · '
                '${_simulation!.fixesUsed} fixes · '
                '${_simulation!.approachAlerts} approach alerts',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              for (final event in _simulation!.events)
                Text(
                  '${event.second}s  ${event.type.name}: ${event.note}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent transitions',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final logs = snapshot.data ?? const <String>[];
                    await Clipboard.setData(
                      ClipboardData(text: logs.join('\n')),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ride log copied')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Export'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final entry in (snapshot.data ?? const <String>[]).reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  entry,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
