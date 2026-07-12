require('dotenv').config();

module.exports = {
  port: Number(process.env.PORT || 3000),
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET || 'dev-secret',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '8h',
  corsOrigin: process.env.CORS_ORIGIN || '*',
  storage: {
    endpoint: process.env.STORAGE_ENDPOINT,
    bucket: process.env.STORAGE_BUCKET || 'ecowatch-media',
    accessKey: process.env.STORAGE_ACCESS_KEY,
    secretKey: process.env.STORAGE_SECRET_KEY,
    publicUrl: process.env.STORAGE_PUBLIC_URL,
  },
  africaTalking: {
    apiKey: process.env.AT_API_KEY,
    username: process.env.AT_USERNAME,
    shortCode: process.env.AT_SHORT_CODE || '*920*500#',
    smsSender: process.env.AT_SMS_SENDER || '',
    smsEnabled: process.env.AT_SMS_ENABLED !== 'false',
  },
};
