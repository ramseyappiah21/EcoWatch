const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

const uploadDir = path.join(__dirname, '../../uploads');

function ensureUploadDir() {
  if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
  }
}

function isAudioFile(file) {
  const mime = file.mimetype || '';
  if (mime.startsWith('audio')) return true;
  const ext = path.extname(file.originalname || '').toLowerCase();
  return ['.m4a', '.mp3', '.wav', '.aac', '.ogg'].includes(ext);
}

/**
 * Local file storage stub — swap for MinIO/S3/Cloudinary in production.
 */
function mediaTypeFromFile(file) {
  if (isAudioFile(file)) {
    throw new Error('Audio uploads are not supported for privacy reasons');
  }
  const mime = file.mimetype || '';
  if (mime.startsWith('video')) return 'video';
  const ext = path.extname(file.originalname || '').toLowerCase();
  if (['.mp4', '.mov', '.webm', '.mkv'].includes(ext)) return 'video';
  return 'photo';
}

async function storeMediaFile(file) {
  if (isAudioFile(file)) {
    throw new Error('Audio uploads are not supported for privacy reasons');
  }

  ensureUploadDir();
  const mime = file.mimetype || '';
  const extFromMime = {
    'image/jpeg': '.jpg',
    'image/jpg': '.jpg',
    'image/png': '.png',
    'image/webp': '.webp',
    'image/gif': '.gif',
    'video/mp4': '.mp4',
    'video/quicktime': '.mov',
  };
  const ext = path.extname(file.originalname || '') || extFromMime[mime] || '.jpg';
  const filename = `${uuidv4()}${ext}`;
  const dest = path.join(uploadDir, filename);
  await fs.promises.rename(file.path, dest);

  // Files are stored on local disk and served by Express at /uploads.
  // STORAGE_PUBLIC_URL is only used when mediaService uploads to S3/MinIO.
  const publicUrl = `/uploads/${filename}`;

  return {
    storageUrl: publicUrl,
    mimeType: file.mimetype,
    fileSizeBytes: file.size,
  };
}

/** Remove a locally stored upload referenced by storage_url. */
async function deleteStoredFile(storageUrl) {
  if (!storageUrl) return;
  let filename = storageUrl;
  if (filename.includes('ecowatch-media/')) {
    filename = filename.split('/').pop();
  } else if (filename.includes('/')) {
    filename = filename.split('/').pop();
  }
  const filePath = path.join(uploadDir, filename);
  if (fs.existsSync(filePath)) {
    await fs.promises.unlink(filePath);
  }
}

module.exports = { storeMediaFile, deleteStoredFile, uploadDir, mediaTypeFromFile, isAudioFile };
