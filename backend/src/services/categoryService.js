/**
 * Tarkwa-Nsuaem Municipal Assembly owns EcoWatch as a shared municipal platform.
 * Participating agencies manage incidents within their legal mandate.
 */

const PLATFORM_OWNER = {
  name: 'Tarkwa-Nsuaem Municipal Assembly',
  short: 'TNMA',
};

/** Participating government agencies. */
const AGENCIES = [
  {
    key: 'epa',
    name: 'Environmental Protection Authority',
    short: 'EPA',
    email: 'epa@ecowatch.gov',
    password: 'epa123',
    categories: ['airPollution', 'illegalMining', 'chemicalSpill'],
  },
  {
    key: 'wrc',
    name: 'Water Resources Commission',
    short: 'WRC',
    email: 'wrc@ecowatch.gov',
    password: 'wrc123',
    categories: ['waterPollution'],
  },
  {
    key: 'nadmo',
    name: 'National Disaster Management Organisation',
    short: 'NADMO',
    email: 'nadmo@ecowatch.gov',
    password: 'nadmo123',
    categories: ['flooding', 'chemicalSpill'],
    emergency: true,
  },
  {
    key: 'fire',
    name: 'Ghana National Fire Service',
    short: 'Fire Service',
    email: 'fire@ecowatch.gov',
    password: 'fire123',
    categories: ['bushFire', 'chemicalSpill'],
    emergency: true,
  },
  {
    key: 'forestry',
    name: 'Forestry Commission',
    short: 'Forestry',
    email: 'forestry@ecowatch.gov',
    password: 'forestry123',
    categories: ['illegalLogging'],
  },
  {
    key: 'municipal',
    name: 'Tarkwa-Nsuaem Municipal Assembly',
    short: 'Municipal Assembly',
    email: 'waste@ecowatch.gov',
    password: 'waste123',
    categories: ['wasteDumping'],
  },
  {
    key: 'police',
    name: 'Ghana Police Service',
    short: 'Police',
    email: 'police@ecowatch.gov',
    password: 'police123',
    categories: [],
    supportOnly: true,
  },
];

/** Categories that always involve police support routing. */
const POLICE_CATEGORIES = ['illegalMining', 'illegalLogging', 'chemicalSpill'];

/** Emergency categories (Fire / NADMO emergency officers). */
const EMERGENCY_CATEGORIES = ['flooding', 'bushFire', 'chemicalSpill'];

const INCIDENT_CATEGORIES = [
  { slug: 'air-pollution', key: 'airPollution', label: 'Air Pollution', agencyKey: 'epa' },
  { slug: 'illegal-mining', key: 'illegalMining', label: 'Illegal Mining', agencyKey: 'epa' },
  { slug: 'water-pollution', key: 'waterPollution', label: 'Water Pollution', agencyKey: 'wrc' },
  { slug: 'waste-dumping', key: 'wasteDumping', label: 'Waste Dumping', agencyKey: 'municipal' },
  { slug: 'flooding', key: 'flooding', label: 'Flooding', agencyKey: 'nadmo' },
  { slug: 'bush-fire', key: 'bushFire', label: 'Bush Fire', agencyKey: 'fire' },
  { slug: 'illegal-logging', key: 'illegalLogging', label: 'Illegal Logging', agencyKey: 'forestry' },
  {
    slug: 'chemical-spill',
    key: 'chemicalSpill',
    label: 'Chemical Spill',
    agencyKey: 'epa',
    multiAgency: ['epa', 'fire', 'nadmo'],
  },
].map((c) => {
  const agency = AGENCIES.find((a) => a.key === c.agencyKey);
  return {
    ...c,
    agency: agency?.name || PLATFORM_OWNER.name,
    agencyShort: agency?.short || PLATFORM_OWNER.short,
    officerName: agency?.name || PLATFORM_OWNER.name,
  };
});

const LEGACY_TO_MAIN = {
  airPollution: 'airPollution',
  air_pollution: 'airPollution',
  waterPollution: 'waterPollution',
  water_pollution: 'waterPollution',
  illegalMining: 'illegalMining',
  illegal_mining: 'illegalMining',
  wasteDumping: 'wasteDumping',
  waste_dumping: 'wasteDumping',
  flooding: 'flooding',
  bushFire: 'bushFire',
  bush_fire: 'bushFire',
  illegalLogging: 'illegalLogging',
  illegal_logging: 'illegalLogging',
  chemicalSpill: 'chemicalSpill',
  chemical_spill: 'chemicalSpill',
  landPollution: 'wasteDumping',
  land_pollution: 'wasteDumping',
  deforestation: 'illegalLogging',
  landDegradation: 'wasteDumping',
  land_degradation: 'wasteDumping',
  noisePollution: 'wasteDumping',
  noise_pollution: 'wasteDumping',
  other: 'wasteDumping',
};

const PORTAL_ROLES = [
  'super_admin',
  'municipal_admin',
  'agency_admin',
  'environmental_officer',
  'emergency_officer',
  'police_support',
  'researcher',
];

const MUNICIPAL_SCOPE_ROLES = ['super_admin', 'municipal_admin'];

const AGENCY_WIDE_ROLES = ['agency_admin'];

/** Field officers update investigation actions (status, notes, photos) after assignment. */
const INVESTIGATION_ROLES = [
  'environmental_officer',
  'emergency_officer',
  'police_support',
];

/** Only assigned officers update investigation status. */
const STATUS_UPDATE_ROLES = [...INVESTIGATION_ROLES];

/** Agency leadership assigns officers and approves closure — not day-to-day actions. */
const ASSIGN_ROLES = [
  'super_admin',
  'municipal_admin',
  'agency_admin',
];

const CLOSE_ROLES = [
  'super_admin',
  'municipal_admin',
  'agency_admin',
];

const EXPORT_ROLES = [
  'super_admin',
  'municipal_admin',
  'agency_admin',
  'researcher',
];

const ANNOUNCEMENT_ROLES = ['super_admin', 'municipal_admin'];

const MANAGE_USERS_ROLES = ['super_admin', 'municipal_admin'];

const SYSTEM_SETTINGS_ROLES = ['super_admin'];

const AUDIT_ROLES = ['super_admin'];

const SEVERITY_RANK = { low: 1, medium: 2, high: 3, critical: 4 };

function snakeToCamel(value) {
  if (!value || !value.includes('_')) return value;
  return value
    .split('_')
    .map((part, i) => (i === 0 ? part : part.charAt(0).toUpperCase() + part.slice(1)))
    .join('');
}

function camelToSnake(value) {
  return value.replace(/[A-Z]/g, (m) => `_${m.toLowerCase()}`);
}

function normalizeMainCategory(key) {
  if (!key) return 'wasteDumping';
  const camel = snakeToCamel(key);
  if (LEGACY_TO_MAIN[camel]) return LEGACY_TO_MAIN[camel];
  if (LEGACY_TO_MAIN[key]) return LEGACY_TO_MAIN[key];
  if (INCIDENT_CATEGORIES.some((c) => c.key === camel)) return camel;
  return 'wasteDumping';
}

function categoryPlainName(categoryKey) {
  return camelToSnake(normalizeMainCategory(categoryKey)).replace(/_/g, '');
}

function categoryVariants(key) {
  const main = normalizeMainCategory(key);
  const legacies = Object.entries(LEGACY_TO_MAIN)
    .filter(([, v]) => v === main)
    .map(([k]) => snakeToCamel(k));
  const snake = camelToSnake(main);
  return [...new Set([main, snake, ...legacies, key])];
}

function getCategoryBySlug(slug) {
  return INCIDENT_CATEGORIES.find((c) => c.slug === slug);
}

function getCategoryByKey(key) {
  const main = normalizeMainCategory(key);
  return INCIDENT_CATEGORIES.find((c) => c.key === main);
}

function getAgencyByKey(agencyKey) {
  return AGENCIES.find((a) => a.key === agencyKey) || null;
}

function getAgencyForCategory(categoryKey) {
  const cat = getCategoryByKey(categoryKey);
  return cat ? getAgencyByKey(cat.agencyKey) : null;
}

/** All agencies that should receive a report for this category. */
function agenciesForCategory(categoryKey) {
  const cat = getCategoryByKey(categoryKey);
  if (!cat) return [];
  const keys = cat.multiAgency || [cat.agencyKey];
  const agencies = keys.map(getAgencyByKey).filter(Boolean);
  if (POLICE_CATEGORIES.includes(cat.key)) {
    const police = getAgencyByKey('police');
    if (police && !agencies.find((a) => a.key === 'police')) agencies.push(police);
  }
  return agencies;
}

function categoriesForAgency(agencyKey) {
  const agency = getAgencyByKey(agencyKey);
  if (!agency) return [];
  if (agency.key === 'police') {
    return POLICE_CATEGORIES.flatMap((key) => categoryVariants(key));
  }
  const fromAgency = agency.categories.flatMap((key) => categoryVariants(key));
  // Include multi-agency categories that list this agency
  const multi = INCIDENT_CATEGORIES
    .filter((c) => (c.multiAgency || []).includes(agencyKey))
    .flatMap((c) => categoryVariants(c.key));
  return [...new Set([...fromAgency, ...multi])];
}

function buildCategoryScope(user, startParamIndex = 1) {
  if (!user) {
    return { clause: ' AND FALSE', params: [], nextIndex: startParamIndex };
  }
  if (MUNICIPAL_SCOPE_ROLES.includes(user.role) || user.role === 'researcher') {
    return { clause: '', params: [], nextIndex: startParamIndex };
  }

  // Field officers only see incidents assigned to them (they update actions on those cases).
  if (INVESTIGATION_ROLES.includes(user.role)) {
    return {
      clause: ` AND assigned_officer_id = $${startParamIndex}::uuid`,
      params: [String(user.sub || '').toLowerCase()],
      nextIndex: startParamIndex + 1,
    };
  }

  if (AGENCY_WIDE_ROLES.includes(user.role)) {
    const agencyKey = user.assignedAgency
      || getAgencyForCategory(user.assignedCategory)?.key;
    if (!agencyKey) {
      return { clause: ' AND FALSE', params: [], nextIndex: startParamIndex };
    }
    const variants = categoriesForAgency(agencyKey);
    if (agencyKey === 'police') {
      return {
        clause: ` AND (needs_police = TRUE OR category = ANY($${startParamIndex}))`,
        params: [variants],
        nextIndex: startParamIndex + 1,
      };
    }
    return {
      clause: ` AND category = ANY($${startParamIndex})`,
      params: [variants],
      nextIndex: startParamIndex + 1,
    };
  }

  return { clause: ' AND FALSE', params: [], nextIndex: startParamIndex };
}

function canUpdateStatus(user) {
  return Boolean(user && STATUS_UPDATE_ROLES.includes(user.role));
}

function canInvestigate(user) {
  return Boolean(user && INVESTIGATION_ROLES.includes(user.role));
}

function canCloseCases(user) {
  return Boolean(user && CLOSE_ROLES.includes(user.role));
}

function canAssignOfficers(user) {
  return Boolean(user && ASSIGN_ROLES.includes(user.role));
}

function canExportData(user) {
  return Boolean(user && EXPORT_ROLES.includes(user.role));
}

function canManageAnnouncements(user) {
  return Boolean(user && ANNOUNCEMENT_ROLES.includes(user.role));
}

function canManageUsers(user) {
  return Boolean(user && MANAGE_USERS_ROLES.includes(user.role));
}

function canManageSystemSettings(user) {
  return Boolean(user && SYSTEM_SETTINGS_ROLES.includes(user.role));
}

function canViewAuditLogs(user) {
  return Boolean(user && AUDIT_ROLES.includes(user.role));
}

function isResearcher(user) {
  return user?.role === 'researcher';
}

function isMunicipalScope(user) {
  return Boolean(user && MUNICIPAL_SCOPE_ROLES.includes(user.role));
}

function severityMeetsThreshold(severity, threshold = 'high') {
  return (SEVERITY_RANK[severity] || 0) >= (SEVERITY_RANK[threshold] || 3);
}

function getAgencyDisplayName(categoryKey) {
  const agency = getAgencyForCategory(categoryKey);
  return agency?.short || agency?.name || 'Agency';
}

function agencyAdminDisplayName(categoryKey) {
  const agency = getAgencyForCategory(categoryKey);
  return agency?.name || 'Agency Admin';
}

function emailForCategory(categoryKey) {
  const agency = getAgencyForCategory(categoryKey);
  return agency?.email || `${categoryPlainName(categoryKey)}@ecowatch.gov`;
}

function emailForRole(role, agencyKey = null) {
  if (role === 'super_admin') return 'superadmin@ecowatch.gov';
  if (role === 'municipal_admin') return 'municipal@ecowatch.gov';
  if (role === 'researcher') return 'researcher@ecowatch.gov';
  if (agencyKey && role === 'agency_admin') {
    return getAgencyByKey(agencyKey)?.email || `${agencyKey}@ecowatch.gov`;
  }
  if (agencyKey && role === 'environmental_officer') return `${agencyKey}.officer@ecowatch.gov`;
  if (agencyKey && role === 'emergency_officer') return `${agencyKey}.emergency@ecowatch.gov`;
  if (role === 'police_support') return 'police@ecowatch.gov';
  return 'admin@ecowatch.gov';
}

function passwordForRole(role, agencyKey = null) {
  if (role === 'super_admin') return 'superadmin123';
  if (role === 'municipal_admin') return 'municipal123';
  if (role === 'researcher') return 'researcher123';
  if (agencyKey) {
    const agency = getAgencyByKey(agencyKey);
    if (role === 'agency_admin' && agency) return agency.password;
    if (role === 'environmental_officer') return `${agencyKey}off123`;
    if (role === 'emergency_officer') return `${agencyKey}emg123`;
  }
  if (role === 'police_support') return 'police123';
  return 'ecowatch123';
}

function passwordForCategory(categoryKey) {
  const agency = getAgencyForCategory(categoryKey);
  return agency?.password || `${categoryPlainName(categoryKey)}123`;
}

function anonymizeCoordinate(value) {
  return Math.round(Number(value) * 100) / 100;
}

module.exports = {
  PLATFORM_OWNER,
  AGENCIES,
  INCIDENT_CATEGORIES,
  LEGACY_TO_MAIN,
  POLICE_CATEGORIES,
  EMERGENCY_CATEGORIES,
  PORTAL_ROLES,
  MUNICIPAL_SCOPE_ROLES,
  AGENCY_WIDE_ROLES,
  INVESTIGATION_ROLES,
  STATUS_UPDATE_ROLES,
  ASSIGN_ROLES,
  CLOSE_ROLES,
  EXPORT_ROLES,
  ANNOUNCEMENT_ROLES,
  MANAGE_USERS_ROLES,
  SYSTEM_SETTINGS_ROLES,
  AUDIT_ROLES,
  snakeToCamel,
  camelToSnake,
  normalizeMainCategory,
  categoryVariants,
  getCategoryBySlug,
  getCategoryByKey,
  getAgencyByKey,
  getAgencyForCategory,
  agenciesForCategory,
  categoriesForAgency,
  getAgencyDisplayName,
  agencyAdminDisplayName,
  buildCategoryScope,
  canUpdateStatus,
  canInvestigate,
  canCloseCases,
  canAssignOfficers,
  canExportData,
  canManageAnnouncements,
  canManageUsers,
  canManageSystemSettings,
  canViewAuditLogs,
  isResearcher,
  isMunicipalScope,
  severityMeetsThreshold,
  anonymizeCoordinate,
  officerPortalPath: () => '/admin',
  emailForCategory,
  emailForRole,
  passwordForCategory,
  passwordForRole,
};
