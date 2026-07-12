const jwt = require('jsonwebtoken');
const config = require('../config');
const { getAgencyByKey, getAgencyForCategory } = require('../services/categoryService');

function resolveAgency(user) {
  if (user.assigned_agency) return getAgencyByKey(user.assigned_agency);
  if (user.assigned_category) return getAgencyForCategory(user.assigned_category);
  return null;
}

function signToken(user) {
  const agency = resolveAgency(user);
  return jwt.sign(
    {
      // Always string UUID so assignment checks match reports.assigned_officer_id
      sub: String(user.id).toLowerCase(),
      email: user.email,
      role: user.role_name,
      assignedAgency: user.assigned_agency || agency?.key || null,
      assignedCategory: user.assigned_category || null,
      agencyName: agency?.name || null,
      agencyShort: agency?.short || null,
      displayName: user.display_name || null,
    },
    config.jwtSecret,
    { expiresIn: config.jwtExpiresIn },
  );
}

function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  try {
    const payload = jwt.verify(header.slice(7), config.jwtSecret);
    req.user = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

function requireRoles(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
}

module.exports = { signToken, authMiddleware, requireRoles };
