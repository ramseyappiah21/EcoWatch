import 'enums.dart';

/// Legacy fine-grained types — kept for parsing old reports; not shown in UI.
enum SpecificPollutionType {
  industrialSmoke('Industrial smoke / fumes', IncidentCategory.airPollution, ''),
  dustEmissions('Dust emissions', IncidentCategory.airPollution, ''),
  chemicalFumes('Chemical fumes', IncidentCategory.airPollution, ''),
  openBurning('Open burning', IncidentCategory.airPollution, ''),
  oilySheen('Oily sheen on water', IncidentCategory.waterPollution, ''),
  miningRunoff('Mining runoff', IncidentCategory.waterPollution, ''),
  sewageDischarge('Sewage discharge', IncidentCategory.waterPollution, ''),
  chemicalContamination('Chemical water contamination', IncidentCategory.waterPollution, ''),
  sedimentPollution('Sediment pollution', IncidentCategory.waterPollution, ''),
  illegalMining('Illegal mining (galamsey)', IncidentCategory.illegalMining, ''),
  wasteDumping('Illegal waste dumping', IncidentCategory.wasteDumping, ''),
  deforestation('Deforestation', IncidentCategory.illegalMining, ''),
  landDegradation('Land degradation / erosion', IncidentCategory.wasteDumping, ''),
  noisePollution('Noise pollution', IncidentCategory.wasteDumping, ''),
  hazardousLandWaste('Hazardous land contamination', IncidentCategory.wasteDumping, '');

  const SpecificPollutionType(this.label, this.mainCategory, this.description);

  final String label;
  final IncidentCategory mainCategory;
  final String description;

  static SpecificPollutionType? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (_legacyMap.containsKey(raw)) return _legacyMap[raw];
    final camel = raw.contains('_') ? _snakeToCamel(raw) : raw;
    if (_legacyMap.containsKey(camel)) return _legacyMap[camel];
    try {
      return SpecificPollutionType.values.byName(camel);
    } catch (_) {
      return null;
    }
  }

  static final Map<String, SpecificPollutionType> _legacyMap = {
    'illegalMining': SpecificPollutionType.illegalMining,
    'illegal_mining': SpecificPollutionType.illegalMining,
    'wasteDumping': SpecificPollutionType.wasteDumping,
    'waste_dumping': SpecificPollutionType.wasteDumping,
    'noisePollution': SpecificPollutionType.noisePollution,
    'noise_pollution': SpecificPollutionType.noisePollution,
    'landDegradation': SpecificPollutionType.landDegradation,
    'land_degradation': SpecificPollutionType.landDegradation,
    'other': SpecificPollutionType.hazardousLandWaste,
  };

  static List<SpecificPollutionType> forMainCategory(IncidentCategory main) =>
      SpecificPollutionType.values.where((t) => t.mainCategory == main).toList();
}

IncidentCategory normalizeMainCategory(String raw) {
  const legacy = {
    'illegalMining': IncidentCategory.illegalMining,
    'illegal_mining': IncidentCategory.illegalMining,
    'wasteDumping': IncidentCategory.wasteDumping,
    'waste_dumping': IncidentCategory.wasteDumping,
    'flooding': IncidentCategory.flooding,
    'landPollution': IncidentCategory.wasteDumping,
    'land_pollution': IncidentCategory.wasteDumping,
    'deforestation': IncidentCategory.illegalLogging,
    'bushFire': IncidentCategory.bushFire,
    'bush_fire': IncidentCategory.bushFire,
    'illegalLogging': IncidentCategory.illegalLogging,
    'illegal_logging': IncidentCategory.illegalLogging,
    'chemicalSpill': IncidentCategory.chemicalSpill,
    'chemical_spill': IncidentCategory.chemicalSpill,
    'landDegradation': IncidentCategory.wasteDumping,
    'land_degradation': IncidentCategory.wasteDumping,
    'noisePollution': IncidentCategory.wasteDumping,
    'noise_pollution': IncidentCategory.wasteDumping,
    'other': IncidentCategory.wasteDumping,
    'airPollution': IncidentCategory.airPollution,
    'air_pollution': IncidentCategory.airPollution,
    'waterPollution': IncidentCategory.waterPollution,
    'water_pollution': IncidentCategory.waterPollution,
  };
  if (legacy.containsKey(raw)) return legacy[raw]!;
  try {
    return IncidentCategory.values.byName(
      raw.contains('_') ? _snakeToCamel(raw) : raw,
    );
  } catch (_) {
    return IncidentCategory.wasteDumping;
  }
}

String _snakeToCamel(String value) {
  final parts = value.split('_');
  return parts.first +
      parts.skip(1).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join();
}
