// Versão "desligar": o app sempre carrega direto da internet, sem cópia guardada no aparelho.
// Remove as caches antigas e o próprio service worker.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil((async () => {
  const ks = await caches.keys();
  await Promise.all(ks.map(k => caches.delete(k)));
  await self.registration.unregister();
})()));
