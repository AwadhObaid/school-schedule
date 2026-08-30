const CACHE_NAME = 'school-schedule-v2';
const ASSETS = [
  './',
  './index.html',
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

// Offline-first for same-origin requests, network-first fallback for everything else
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  if (url.origin === self.location.origin) {
    e.respondWith(
      caches.match(e.request).then((cached) => {
        const network = fetch(e.request).then((res) => {
          caches.open(CACHE_NAME).then((cache) => cache.put(e.request, res.clone()));
          return res;
        }).catch(() => cached);
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
