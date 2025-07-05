// 歯科医院予約管理システム - Service Worker
// オフライン対応・キャッシュ管理・バックグラウンド同期
// SPA並みUX実現のためのPWA機能

const CACHE_NAME = 'dental-clinic-v1.0.0';
const OFFLINE_CACHE = 'dental-clinic-offline-v1.0.0';
const DYNAMIC_CACHE = 'dental-clinic-dynamic-v1.0.0';

// キャッシュするリソース
const STATIC_ASSETS = [
  '/',
  '/appointments/calendar',
  '/assets/application.css',
  '/assets/application.js',
  '/offline.html',
  // FullCalendar関連
  'https://cdn.jsdelivr.net/npm/fullcalendar@6.1.8/index.global.min.js',
  // Tailwind CSS
  'https://cdn.tailwindcss.com',
  // フォント
  'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap'
];

// インストール時の処理
self.addEventListener('install', event => {
  console.log('Service Worker installing...');
  
  event.waitUntil(
    Promise.all([
      // 静的リソースをキャッシュ
      caches.open(CACHE_NAME).then(cache => {
        console.log('Caching static assets...');
        return cache.addAll(STATIC_ASSETS);
      }),
      
      // オフラインページをキャッシュ
      caches.open(OFFLINE_CACHE).then(cache => {
        return fetch('/offline.html').then(response => {
          return cache.put('/offline.html', response);
        });
      })
    ])
  );
  
  // 新しいService Workerを即座にアクティブ化
  self.skipWaiting();
});

// アクティベート時の処理
self.addEventListener('activate', event => {
  console.log('Service Worker activating...');
  
  event.waitUntil(
    Promise.all([
      // 古いキャッシュをクリア
      caches.keys().then(cacheNames => {
        return Promise.all(
          cacheNames.map(cacheName => {
            if (cacheName !== CACHE_NAME && 
                cacheName !== OFFLINE_CACHE && 
                cacheName !== DYNAMIC_CACHE) {
              console.log('Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      }),
      
      // 全てのクライアントを制御下に置く
      self.clients.claim()
    ])
  );
});

// フェッチイベントの処理
self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  
  // GET リクエストのみ処理
  if (request.method !== 'GET') {
    return;
  }
  
  // ブラウザナビゲーションリクエストの場合
  if (request.mode === 'navigate') {
    event.respondWith(handleNavigationRequest(request));
    return;
  }
  
  // API リクエストの場合
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(handleApiRequest(request));
    return;
  }
  
  // 静的アセットの場合
  if (isStaticAsset(request.url)) {
    event.respondWith(handleStaticAsset(request));
    return;
  }
  
  // その他のリクエスト
  event.respondWith(handleOtherRequest(request));
});

// ナビゲーションリクエストの処理
async function handleNavigationRequest(request) {
  try {
    // ネットワークを優先
    const networkResponse = await fetch(request);
    
    // 成功した場合はキャッシュに保存
    if (networkResponse.ok) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
    }
    
    return networkResponse;
    
  } catch (error) {
    console.log('Network failed, trying cache...', error);
    
    // キャッシュから取得を試行
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    
    // カレンダーページの場合はオフライン用ページを返す
    if (request.url.includes('/appointments/calendar')) {
      return caches.match('/offline.html');
    }
    
    // その他はホームページにリダイレクト
    return caches.match('/');
  }
}

// APIリクエストの処理
async function handleApiRequest(request) {
  try {
    // APIは常にネットワークを優先
    const networkResponse = await fetch(request);
    
    // GETリクエストの成功レスポンスのみキャッシュ
    if (request.method === 'GET' && networkResponse.ok) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
    }
    
    return networkResponse;
    
  } catch (error) {
    console.log('API request failed:', error);
    
    // GET リクエストの場合はキャッシュから取得を試行
    if (request.method === 'GET') {
      const cachedResponse = await caches.match(request);
      if (cachedResponse) {
        // オフラインデータであることを示すヘッダーを追加
        const response = cachedResponse.clone();
        response.headers.set('X-Served-From', 'cache');
        return response;
      }
    }
    
    // キャッシュにもない場合はオフライン応答を返す
    return new Response(
      JSON.stringify({
        error: 'オフラインモード',
        message: 'ネットワークに接続されていません',
        cached: false
      }),
      {
        status: 503,
        statusText: 'Service Unavailable',
        headers: {
          'Content-Type': 'application/json',
          'X-Served-From': 'offline'
        }
      }
    );
  }
}

// 静的アセットの処理
async function handleStaticAsset(request) {
  // キャッシュファーストストラテジー
  const cachedResponse = await caches.match(request);
  
  if (cachedResponse) {
    // バックグラウンドで更新
    fetch(request).then(response => {
      if (response.ok) {
        caches.open(CACHE_NAME).then(cache => {
          cache.put(request, response);
        });
      }
    }).catch(() => {
      // ネットワークエラーは無視
    });
    
    return cachedResponse;
  }
  
  // キャッシュにない場合はネットワークから取得
  try {
    const networkResponse = await fetch(request);
    
    if (networkResponse.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, networkResponse.clone());
    }
    
    return networkResponse;
    
  } catch (error) {
    console.log('Failed to fetch static asset:', error);
    
    // 静的アセットが取得できない場合は空のレスポンス
    return new Response('', {
      status: 404,
      statusText: 'Not Found'
    });
  }
}

// その他のリクエストの処理
async function handleOtherRequest(request) {
  try {
    return await fetch(request);
  } catch (error) {
    // キャッシュから取得を試行
    const cachedResponse = await caches.match(request);
    return cachedResponse || new Response('', { status: 404 });
  }
}

// 静的アセット判定
function isStaticAsset(url) {
  const staticExtensions = ['.css', '.js', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.woff', '.woff2', '.ttf'];
  const urlPath = new URL(url).pathname;
  
  return staticExtensions.some(ext => urlPath.endsWith(ext)) || 
         url.includes('/assets/') ||
         url.includes('cdn.jsdelivr.net') ||
         url.includes('fonts.googleapis.com') ||
         url.includes('cdn.tailwindcss.com');
}

console.log('Service Worker loaded successfully');