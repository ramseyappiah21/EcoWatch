import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/l10n_extensions.dart';

/// Tappable map for picking where an incident occurred.
///
/// Matches the private-reporting UI:
/// - Blue person pin + accuracy halo = your GPS (never submitted)
/// - Red pin = incident location (shared)
class IncidentLocationMap extends StatefulWidget {
  const IncidentLocationMap({
    super.key,
    required this.incidentLocation,
    required this.onIncidentLocationChanged,
    this.deviceLocation,
    this.deviceAccuracyMeters,
    this.height = 280,
  });

  final LatLng incidentLocation;
  final LatLng? deviceLocation;
  final double? deviceAccuracyMeters;
  final ValueChanged<LatLng> onIncidentLocationChanged;
  final double height;

  @override
  State<IncidentLocationMap> createState() => _IncidentLocationMapState();
}

class _IncidentLocationMapState extends State<IncidentLocationMap> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMarkers());
  }

  @override
  void didUpdateWidget(covariant IncidentLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incidentMoved =
        oldWidget.incidentLocation != widget.incidentLocation;
    final deviceChanged = oldWidget.deviceLocation != widget.deviceLocation;
    if (incidentMoved || deviceChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMarkers());
    }
  }

  void _fitMarkers() {
    final device = widget.deviceLocation;
    if (device == null) {
      _mapController.move(widget.incidentLocation, AppConstants.defaultMapZoom);
      return;
    }

    final sameSpot = (device.latitude - widget.incidentLocation.latitude).abs() <
            0.00008 &&
        (device.longitude - widget.incidentLocation.longitude).abs() < 0.00008;

    if (sameSpot) {
      _mapController.move(widget.incidentLocation, 16);
      return;
    }

    final bounds = LatLngBounds(device, widget.incidentLocation);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(48, 48, 48, 64),
        maxZoom: 17,
      ),
    );
  }

  double get _accuracyRadius {
    final meters = widget.deviceAccuracyMeters;
    if (meters == null || meters.isNaN || meters <= 0) return 45;
    return meters.clamp(25, 120).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final device = widget.deviceLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: widget.height,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.incidentLocation,
                initialZoom: AppConstants.defaultMapZoom,
                onTap: (_, point) => widget.onIncidentLocationChanged(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ecowatch.tarkwa',
                ),
                if (device != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: device,
                        radius: _accuracyRadius,
                        useRadiusInMeter: true,
                        color: Colors.blue.withValues(alpha: 0.18),
                        borderColor: Colors.blue.withValues(alpha: 0.45),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (device != null)
                      Marker(
                        point: device,
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: Tooltip(
                          message: l10n.yourPositionPrivate,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x55000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    Marker(
                      point: widget.incidentLocation,
                      width: 48,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: Tooltip(
                        message: l10n.incidentLocationShared,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 46,
                          shadows: [
                            Shadow(
                              color: Color(0x66000000),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.touch_app, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.mapTapHint,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            if (device != null)
              TextButton.icon(
                onPressed: _fitMarkers,
                icon: const Icon(Icons.zoom_out_map, size: 18),
                label: Text(l10n.showBothPins),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _LegendItem(
              color: Colors.red,
              icon: Icons.location_on,
              label: l10n.incidentLocationShared,
            ),
            _LegendItem(
              color: Colors.blue.shade600,
              icon: Icons.person,
              label: device != null
                  ? l10n.youPrivateLegend
                  : l10n.youPrivateWaitingGps,
              dimmed: device == null,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.icon,
    required this.label,
    this.dimmed = false,
  });

  final Color color;
  final IconData icon;
  final String label;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}

LatLng defaultIncidentCenter() => LatLng(
      AppConstants.defaultLatitude,
      AppConstants.defaultLongitude,
    );
