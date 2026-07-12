import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../l10n/enum_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/enums.dart';
import '../../../models/map_marker.dart';
import '../../../providers/dependency_injection.dart';

/// Map screen with coordinate-based marker placement and popups.
class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({super.key});

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> {
  IncidentCategory? _filter;
  List<MapMarker> _markers = [];
  bool _showHeatmap = true;
  bool _loading = true;
  MapMarker? _selectedMarker;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    setState(() => _loading = true);
    final result = await ref.read(mapServiceProvider).getVisibleMarkers(
          centerLat: AppConstants.defaultLatitude,
          centerLng: AppConstants.defaultLongitude,
          zoom: AppConstants.defaultMapZoom,
        );
    if (mounted) {
      setState(() {
        _markers = result.dataOrNull ?? [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filtered = _filter == null
        ? _markers
        : _markers.where((m) => m.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapTitle),
        actions: [
          IconButton(
            icon: Icon(_showHeatmap ? Icons.layers : Icons.layers_outlined),
            onPressed: () => setState(() => _showHeatmap = !_showHeatmap),
            tooltip: l10n.toggleHeatmap,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                FilterChip(
                  label: Text(l10n.all),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                ...IncidentCategory.values.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      avatar: CategoryIcon(category: c, size: 16),
                      label: Text(
                        l10n.categoryLabel(c),
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: _filter == c,
                      onSelected: (_) => setState(() => _filter = c),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? EcoLoadingIndicator(message: l10n.loadingMap)
                : _MapView(
                    markers: filtered,
                    showHeatmap: _showHeatmap,
                    selectedMarker: _selectedMarker,
                    onMarkerTap: (m) => setState(() => _selectedMarker = m),
                  ),
          ),
          if (_selectedMarker != null)
            _MarkerPopup(
              marker: _selectedMarker!,
              onClose: () => setState(() => _selectedMarker = null),
            )
          else if (filtered.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Text(
                l10n.mapIncidentSummary(filtered.length),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({
    required this.markers,
    required this.showHeatmap,
    required this.selectedMarker,
    required this.onMarkerTap,
  });

  final List<MapMarker> markers;
  final bool showHeatmap;
  final MapMarker? selectedMarker;
  final ValueChanged<MapMarker> onMarkerTap;

  Offset _project(double lat, double lng, Size size) {
    const centerLat = AppConstants.defaultLatitude;
    const centerLng = AppConstants.defaultLongitude;
    const scale = 12000.0;

    final x = size.width / 2 + (lng - centerLng) * scale;
    final y = size.height / 2 - (lat - centerLat) * scale;
    return Offset(
      x.clamp(20.0, size.width - 20),
      y.clamp(20.0, size.height - 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.shade100,
                    Colors.teal.shade50,
                    Colors.blue.shade50,
                  ],
                ),
              ),
              child: CustomPaint(
                painter: _MarkerPainter(
                  markers: markers,
                  showHeatmap: showHeatmap,
                  project: (lat, lng) => _project(lat, lng, size),
                ),
              ),
            ),
            ...markers.map((m) {
              final pos = _project(m.latitude, m.longitude, size);
              return Positioned(
                left: pos.dx - 16,
                top: pos.dy - 16,
                child: GestureDetector(
                  onTap: () => onMarkerTap(m),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              );
            }),
            Positioned(
              top: 16,
              left: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Tarkwa',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${AppConstants.defaultLatitude}, ${AppConstants.defaultLongitude}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MarkerPopup extends StatelessWidget {
  const _MarkerPopup({required this.marker, required this.onClose});

  final MapMarker marker;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          CategoryIcon(category: marker.category, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  marker.title ?? l10n.categoryLabel(marker.category),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${marker.latitude.toStringAsFixed(4)}, ${marker.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 11),
                ),
                SeverityBadge(severity: marker.severity),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: onClose),
        ],
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  _MarkerPainter({
    required this.markers,
    required this.showHeatmap,
    required this.project,
  });

  final List<MapMarker> markers;
  final bool showHeatmap;
  final Offset Function(double lat, double lng) project;

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in markers) {
      final offset = project(m.latitude, m.longitude);

      if (showHeatmap) {
        final heatPaint = Paint()
          ..color = Color(m.severity.colorHex).withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(offset, 40, heatPaint);
      }

      final paint = Paint()
        ..color = Color(m.severity.colorHex)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(offset, m.isCluster ? 14 : 8, paint);

      if (m.isCluster) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${m.clusterCount}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(
            offset.dx - textPainter.width / 2,
            offset.dy - textPainter.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerPainter oldDelegate) =>
      oldDelegate.markers != markers || oldDelegate.showHeatmap != showHeatmap;
}
