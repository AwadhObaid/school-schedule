const CACHE_NAME = 'school-schedule-v3';
const ASSETS = [
  './',
  './index.html',
  './app-utils.js',
  './manifest.json',
  './icon-192.png',
  './icon-512.png'
];

self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS)).catch(() => {})
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

function isApkRequest(url) {
  return url.pathname.endsWith('/app.apk');
}

function cacheResponse(request, response) {
  if (response && response.ok && response.type === 'basic') {
    caches.open(CACHE_NAME).then(cache => cache.put(request, response.clone()));
  }
  return response;
}

// Keep navigations fresh, while retaining an offline fallback for the app shell.
// APK files and range requests deliberately bypass the service worker so repeated
// downloads never fill the browser cache with multi-megabyte application files.
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  if (url.origin !== self.location.origin || isApkRequest(url) || e.request.headers.has('range')) return;

  if (e.request.mode === 'navigate') {
    e.respondWith(
      fetch(e.request)
        .then(response => cacheResponse(e.request, response))
        .catch(() => caches.match(e.request).then(cached => cached || caches.match('./index.html')))
    );
    return;
  }

  const coreAssetUrls = new Set(ASSETS.map(asset => new URL(asset, self.registration.scope).pathname));
  if (coreAssetUrls.has(url.pathname)) {
    e.respondWith(
      caches.match(e.request).then((cached) => {
        const network = fetch(e.request).then(response => cacheResponse(e.request, response)).catch(() => cached);
        return cached || network;
      })
    );
  }
});

// Placeholder for future server-sent push notifications (requires a push
// backend with VAPID keys — not active yet, safe to leave as-is).
self.addEventListener('push', (e) => {
  if (!e.data) return;
  const data = e.data.json();
  e.waitUntil(
    self.registration.showNotification(data.title || 'التوقيت المدرسي', {
      body: data.body || '',
      icon: './icon-192.png',
      badge: './icon-192.png'
    })
  );
});
