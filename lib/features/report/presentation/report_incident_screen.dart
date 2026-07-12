import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../../l10n/enum_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/enums.dart';
import '../../../models/media.dart';
import '../../../models/pollution_types.dart';
import '../../../models/report.dart';
import '../../../providers/dependency_injection.dart';
import '../../../services/gis/location_label.dart';
import '../../../services/gis/reverse_geocoding_service.dart';
import '../../../services/media/media_capture_service.dart';
import 'widgets/incident_location_map.dart';

class ReportIncidentScreen extends ConsumerStatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  ConsumerState<ReportIncidentScreen> createState() =>
      _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends ConsumerState<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _communityController = TextEditingController();
  final _locationSearchController = TextEditingController();
  final _descriptionController = TextEditingController();

  IncidentCategory? _category;
  bool _waterNearby = false;
  bool _submitting = false;
  bool _locating = false;
  bool _geocoding = false;
  GeoLocation? _deviceLocation;
  LatLng _incidentPin = defaultIncidentCenter();
  String? _locationError;
  bool _userEditedLocation = false;
  bool _searchingLocation = false;
  String? _locationSearchError;
  List<PlaceSearchResult> _locationSearchResults = [];
  final List<MediaAttachment> _media = [];

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    await _loadDraft();
    await _acquireDeviceLocation();
    if (!_userEditedLocation && _communityController.text.trim().isEmpty) {
      await _resolvePlaceNameForPin(_incidentPin);
    }
  }

  @override
  void dispose() {
    _communityController.dispose();
    _locationSearchController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _acquireDeviceLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });

    final mapService = ref.read(mapServiceProvider);
    final result = await mapService.getCurrentLocation();

    if (!mounted) return;

    result.when(
      success: (loc) {
        final deviceLatLng = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _deviceLocation = loc;
          _locating = false;
          _locationError = null;
          // Place the red incident pin on your GPS first; you can move it.
          if (!_userEditedLocation) {
            _incidentPin = deviceLatLng;
          }
        });
        if (!_userEditedLocation) {
          _resolvePlaceNameForPin(deviceLatLng);
        }
      },
      failure: (e) {
        setState(() {
          _deviceLocation = null;
          _locationError = e.message;
          _locating = false;
        });
      },
    );
  }

  Future<void> _onIncidentPinChanged(LatLng point) async {
    setState(() {
      _incidentPin = point;
      _locationSearchResults = [];
    });
    await _resolvePlaceNameForPin(point);
  }

  Future<void> _searchLocation() async {
    final l10n = context.l10n;
    final query = _locationSearchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _locationSearchError = l10n.searchMinChars;
        _locationSearchResults = [];
      });
      return;
    }

    setState(() {
      _searchingLocation = true;
      _locationSearchError = null;
      _locationSearchResults = [];
    });

    final results = await ref.read(mapServiceProvider).searchPlaces(query);

    if (!mounted) return;
    setState(() {
      _searchingLocation = false;
      _locationSearchResults = results;
      if (results.isEmpty) {
        _locationSearchError = l10n.noPlacesFound;
      }
    });
  }

  void _selectSearchResult(PlaceSearchResult place) {
    setState(() {
      _incidentPin = LatLng(place.latitude, place.longitude);
      _communityController.text = place.displayName;
      _userEditedLocation = true;
      _locationSearchResults = [];
      _locationSearchError = null;
      _locationSearchController.clear();
    });
  }

  Future<void> _resolvePlaceNameForPin(LatLng point) async {
    setState(() => _geocoding = true);

    final mapService = ref.read(mapServiceProvider);
    final geo = GeoLocation(latitude: point.latitude, longitude: point.longitude);
    final placeName = await mapService.resolvePlaceName(geo);

    if (!mounted) return;
    setState(() {
      _geocoding = false;
      if (!_userEditedLocation && placeName != null && placeName.trim().isNotEmpty) {
        _communityController.text = placeName.trim();
      }
    });
  }

  String? _resolvedCommunityName() {
    return LocationLabel.sanitizeName(_communityController.text);
  }

  Future<void> _loadDraft() async {
    final draft =
        await ref.read(localReportDataSourceProvider).getDraft();
    if (draft == null || !mounted) return;

    final incidentLat = (draft['incidentLat'] as num?)?.toDouble();
    final incidentLng = (draft['incidentLng'] as num?)?.toDouble();

    setState(() {
      final draftCategory = draft['category'] as String?;
      _category = draftCategory != null
          ? normalizeMainCategory(draftCategory)
          : null;
      _communityController.text = draft['community'] as String? ?? '';
      _descriptionController.text = draft['description'] as String? ?? '';
      _userEditedLocation = _communityController.text.trim().isNotEmpty;
      _waterNearby = draft['waterNearby'] as bool? ?? false;

      if (incidentLat != null && incidentLng != null) {
        _incidentPin = LatLng(incidentLat, incidentLng);
      }

      final mediaJson = draft['media'] as List<dynamic>? ?? [];
      _media
        ..clear()
        ..addAll(
          mediaJson
              .map((e) => MediaAttachment.tryFromJson(e as Map<String, dynamic>))
              .whereType<MediaAttachment>(),
        );
    });
  }

  Future<void> _saveDraft() async {
    await ref.read(localReportDataSourceProvider).saveDraft({
      if (_category != null) 'category': _category!.name,
      'community': LocationLabel.sanitizeName(_communityController.text) ?? '',
      'description': _descriptionController.text.trim(),
      'incidentLat': _incidentPin.latitude,
      'incidentLng': _incidentPin.longitude,
      'waterNearby': _waterNearby,
      'media': _media.map((m) => m.toJson()).toList(),
      'savedAt': DateTime.now().toIso8601String(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.draftSaved)),
      );
    }
  }

  Future<void> _addPhoto({required bool useCamera}) async {
    final capture = ref.read(mediaCaptureServiceProvider);
    final picked = await capture.pickPhoto(useCamera: useCamera);
    if (picked == null || !mounted) return;

    setState(() {
      _media.add(
        MediaAttachment(
          id: const Uuid().v4(),
          type: MediaType.photo,
          localPath: picked.path,
          capturedAt: DateTime.now(),
        ),
      );
    });
  }

  Future<void> _addVideo({required bool useCamera}) async {
    final capture = ref.read(mediaCaptureServiceProvider);
    final picked = await capture.pickVideo(useCamera: useCamera);
    if (picked == null || !mounted) return;

    setState(() {
      _media.add(
        MediaAttachment(
          id: const Uuid().v4(),
          type: MediaType.video,
          localPath: picked.path,
          capturedAt: DateTime.now(),
        ),
      );
    });
  }

  void _removeMedia(String id) {
    setState(() => _media.removeWhere((m) => m.id == id));
  }

  Future<void> _showMediaOptions({required bool forVideo}) async {
    final l10n = context.l10n;
    final capture = ref.read(mediaCaptureServiceProvider);
    final useLiveCamera = capture.supportsLiveCamera;

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (useLiveCamera) ...[
              ListTile(
                leading: Icon(forVideo ? Icons.videocam : Icons.camera_alt),
                title: Text(forVideo ? l10n.recordVideo : l10n.takePhoto),
                onTap: () {
                  Navigator.pop(ctx);
                  if (forVideo) {
                    _addVideo(useCamera: true);
                  } else {
                    _addPhoto(useCamera: true);
                  }
                },
              ),
            ],
            ListTile(
              leading: Icon(forVideo ? Icons.video_library : Icons.photo_library),
              title: Text(
                forVideo ? l10n.chooseVideoFromFiles : l10n.choosePhotoFromFiles,
              ),
              onTap: () {
                Navigator.pop(ctx);
                if (forVideo) {
                  _addVideo(useCamera: false);
                } else {
                  _addPhoto(useCamera: false);
                }
              },
            ),
            if (!useLiveCamera)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  l10n.desktopMediaHint,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.categoryRequired)),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final communityName = _resolvedCommunityName();
    final incidentLocation = GeoLocation(
      latitude: _incidentPin.latitude,
      longitude: _incidentPin.longitude,
      address: communityName,
      landmark: communityName,
    );

    final report = Report(
      id: const Uuid().v4(),
      trackingToken: '',
      category: _category!,
      description: _descriptionController.text.trim(),
      location: incidentLocation,
      status: ReportStatus.submitted,
      severity: SeverityLevel.low,
      source: ReportSource.app,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingUpload,
      isAnonymous: true,
      waterBodyNearby: _waterNearby,
      communityName: communityName,
      media: List.unmodifiable(_media),
    );

    final result = await ref.read(reportRepositoryProvider).submitReport(report);

    if (!mounted) return;
    setState(() => _submitting = false);

    result.when(
      success: (saved) async {
        await ref.read(localReportDataSourceProvider).clearDraft();
        ref.read(reportsListVersionProvider.notifier).state++;
        if (!context.mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final l10n = ctx.l10n;
            return AlertDialog(
            title: Text(l10n.reportSubmitted),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.saveTrackingToken),
                const SizedBox(height: 8),
                SelectableText(
                  saved.trackingToken,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                SeverityBadge(severity: saved.severity),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                },
                child: Text(l10n.done),
              ),
            ],
          );
          },
        );
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devicePin = _deviceLocation == null
        ? null
        : LatLng(_deviceLocation!.latitude, _deviceLocation!.longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportIncident),
        actions: [
          TextButton(
            onPressed: _saveDraft,
            child: Text(l10n.saveDraft),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CategoryPicker(
              selected: _category,
              onSelected: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showMediaOptions(forVideo: false),
                    icon: const Icon(Icons.camera_alt),
                    label: Text(l10n.photo),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showMediaOptions(forVideo: true),
                    icon: const Icon(Icons.videocam),
                    label: Text(l10n.video),
                  ),
                ),
              ],
            ),
            if (_media.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._media.map(
                (m) => _MediaTile(
                  attachment: m,
                  onRemove: () => _removeMedia(m.id),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              l10n.descriptionSection,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.descriptionOptional,
                hintText: l10n.descriptionHint,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.incidentLocationSection,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _PrivacyLocationCard(
              locating: _locating,
              geocoding: _geocoding,
              deviceLocation: _deviceLocation,
              incidentPin: _incidentPin,
              error: _locationError,
              onRefreshGps: _acquireDeviceLocation,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationSearchController,
              decoration: InputDecoration(
                labelText: l10n.searchLocation,
                hintText: l10n.searchLocationHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _searchingLocation ? null : _searchLocation,
                        tooltip: l10n.searchAction,
                      ),
              ),
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) => _searchLocation(),
            ),
            if (_locationSearchError != null) ...[
              const SizedBox(height: 6),
              Text(
                _locationSearchError!,
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
              ),
            ],
            if (_locationSearchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: _locationSearchResults.map((place) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(
                        place.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${place.latitude.toStringAsFixed(4)}, '
                        '${place.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => _selectSearchResult(place),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            IncidentLocationMap(
              incidentLocation: _incidentPin,
              deviceLocation: devicePin,
              deviceAccuracyMeters: _deviceLocation?.accuracyMeters,
              onIncidentLocationChanged: _onIncidentPinChanged,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _communityController,
              onChanged: (_) => _userEditedLocation = true,
              decoration: InputDecoration(
                labelText: l10n.incidentLocationName,
                hintText: l10n.incidentLocationHint,
                suffixIcon: _geocoding
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.nearWaterBody),
              subtitle: Text(l10n.nearWaterBodySubtitle),
              value: _waterNearby,
              onChanged: (v) => setState(() => _waterNearby = v),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const EcoLoadingIndicator()
                  : Text(l10n.submitReport),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.selected,
    required this.onSelected,
  });

  final IncidentCategory? selected;
  final ValueChanged<IncidentCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.mainPollutionCategory,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.mainPollutionCategoryHelper,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        ...IncidentCategory.values.map((category) {
          final isSelected = selected == category;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(category),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      CategoryIcon(category: category),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.categoryLabel(category),
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            Text(
                              category.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PrivacyLocationCard extends StatelessWidget {
  const _PrivacyLocationCard({
    required this.locating,
    required this.geocoding,
    required this.deviceLocation,
    required this.incidentPin,
    required this.error,
    required this.onRefreshGps,
  });

  final bool locating;
  final bool geocoding;
  final GeoLocation? deviceLocation;
  final LatLng incidentPin;
  final String? error;
  final VoidCallback onRefreshGps;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final coords =
        '${incidentPin.latitude.toStringAsFixed(5)}, ${incidentPin.longitude.toStringAsFixed(5)}';

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  locating ? Icons.gps_not_fixed : Icons.shield_outlined,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.privateReporting,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: locating ? null : onRefreshGps,
                  icon: const Icon(Icons.my_location),
                  tooltip: l10n.refreshGpsTooltip,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              locating
                  ? l10n.locatingGps
                  : deviceLocation != null
                      ? l10n.gpsSharedNote
                      : l10n.gpsUnavailableNote,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.incidentPinLabel(coords, lookingUp: geocoding),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            if (error != null) ...[
              const SizedBox(height: 4),
              Text(
                error!,
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.attachment, required this.onRemove});

  final MediaAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPhoto = attachment.type == MediaType.photo;
    final showPreview = !kIsWeb && isPhoto && File(attachment.localPath).existsSync();

    final icon = isPhoto ? Icons.image : Icons.videocam;
    final title = isPhoto ? l10n.photoAttached : l10n.videoAttached;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: showPreview
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(attachment.localPath),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              )
            : Icon(icon),
        title: Text(title),
        subtitle: Text(
          attachment.localPath.split(RegExp(r'[\\/]')).last,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
