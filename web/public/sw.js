const SHELL_CACHE = 'orbit-shell-v3';
const SHELL_ASSETS = [
  '/offline',
  '/manifest.webmanifest',
  '/orbit-icon-192.png',
];

function isSensitiveRequest(url, request) {
  if (request.method !== 'GET') return true;
  if (request.headers && request.headers.get('authorization')) return true;

  const pathname = url.pathname || '';
  if (url.hostname.endsWith('.supabase.co')) return true;
  if (
    pathname.startsWith('/api/') ||
    pathname.startsWith('/rest/') ||
    pathname.startsWith('/auth/') ||
    pathname.startsWith('/storage/') ||
    pathname.startsWith('/realtime/')
  ) {
    return true;
  }
  return false;
}

function isStaticShellAsset(url) {
  const pathname = url.pathname || '';
  if (
    pathname === '/offline' ||
    pathname === '/manifest.webmanifest' ||
    pathname === '/orbit-icon-192.png' ||
    pathname === '/orbit-icon.png' ||
    pathname === '/orbit-logo.png'
  ) {
    return true;
  }
  if (pathname.startsWith('/_next/static/')) {
    return true;
  }
  return false;
}

function sanitizeDeepLink(rawUrl) {
  if (typeof rawUrl !== 'string' || !rawUrl.startsWith('/')) {
    return '/hari-ini';
  }
  if (rawUrl.startsWith('//')) {
    return '/hari-ini';
  }
  return rawUrl;
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(SHELL_CACHE).then(async (cache) => {
      await Promise.allSettled(
        SHELL_ASSETS.map(async (assetUrl) => {
          try {
            const response = await fetch(assetUrl, { cache: 'reload' });
            if (response.ok) {
              await cache.put(assetUrl, response);
            }
          } catch {
            // Abaikan kegagalan prefetch saat instalasi offline
          }
        })
      );
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key !== SHELL_CACHE)
            .map((legacyKey) => caches.delete(legacyKey))
        )
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  let url;
  try {
    url = new URL(request.url);
  } catch {
    return;
  }

  if (url.origin !== self.location.origin) {
    return;
  }

  // Jangan pernah meng-cache endpoint sensitif auth, REST, atau API
  if (isSensitiveRequest(url, request)) {
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request).catch(async () => {
        const cachedOffline = await caches.match('/offline');
        if (cachedOffline) {
          return cachedOffline;
        }
        return new Response('Orbit sedang offline.', {
          status: 503,
          headers: { 'Content-Type': 'text/plain; charset=utf-8' },
        });
      })
    );
    return;
  }

  if (isStaticShellAsset(url)) {
    event.respondWith(
      caches.match(request).then((cached) => {
        const networkPromise = fetch(request)
          .then((response) => {
            if (response && response.ok && response.type === 'basic') {
              const clone = response.clone();
              caches.open(SHELL_CACHE).then((cache) => cache.put(request, clone));
            }
            return response;
          })
          .catch(() => cached);

        return cached || networkPromise;
      })
    );
  }
});

self.addEventListener('push', (event) => {
  let payload = {};
  if (event.data) {
    try {
      payload = event.data.json();
    } catch {
      payload = { body: event.data.text() };
    }
  }

  const privacyMasked = Boolean(payload && payload.privacyMasked);
  const title =
    !privacyMasked && typeof payload.title === 'string' && payload.title.trim()
      ? payload.title.trim()
      : 'Notifikasi Orbit';
  const body =
    !privacyMasked && typeof payload.body === 'string' && payload.body.trim()
      ? payload.body.trim()
      : 'Ada pembaruan penting di ruang kerja Orbit Anda. Buka aplikasi untuk detail.';
  const targetUrl = sanitizeDeepLink(payload && payload.url);
  const tag =
    typeof payload.tag === 'string' && payload.tag.trim()
      ? payload.tag.trim()
      : 'orbit-push-alert';

  event.waitUntil(
    self.registration.showNotification(title, {
      body,
      icon: '/orbit-icon-192.png',
      badge: '/orbit-icon-192.png',
      tag,
      data: { url: targetUrl },
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const rawUrl =
    event.notification && event.notification.data
      ? event.notification.data.url
      : '/hari-ini';
  const targetUrl = sanitizeDeepLink(rawUrl);

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then(async (windowClients) => {
        for (const client of windowClients) {
          if (client.url.startsWith(self.location.origin) && 'focus' in client) {
            await client.focus();
            if ('navigate' in client) {
              try {
                await client.navigate(targetUrl);
              } catch {
                // Abaikan jika navigate tidak diizinkan pada client aktif
              }
            }
            return;
          }
        }
        if (self.clients.openWindow) {
          await self.clients.openWindow(targetUrl);
        }
      })
  );
});
