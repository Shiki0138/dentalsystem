// パフォーマンス最適化JavaScriptコントローラー
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lazyImage", "deferredContent"]
  
  connect() {
    this.setupLazyLoading()
    this.setupIntersectionObserver()
    this.optimizeScrollPerformance()
    this.preloadCriticalResources()
  }

  disconnect() {
    if (this.lazyLoadObserver) {
      this.lazyLoadObserver.disconnect()
    }
    if (this.deferredObserver) {
      this.deferredObserver.disconnect()
    }
  }

  // 遅延読み込み設定
  setupLazyLoading() {
    if (!('IntersectionObserver' in window)) {
      // フォールバック: 全画像を即座に読み込み
      this.lazyImageTargets.forEach(img => this.loadImage(img))
      return
    }

    this.lazyLoadObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.loadImage(entry.target)
          this.lazyLoadObserver.unobserve(entry.target)
        }
      })
    }, {
      rootMargin: '50px 0px',
      threshold: 0.01
    })

    this.lazyImageTargets.forEach(img => {
      this.lazyLoadObserver.observe(img)
    })
  }

  // 画像読み込み
  loadImage(img) {
    const src = img.dataset.src
    if (!src) return

    img.addEventListener('load', () => {
      img.classList.add('loaded')
      img.classList.remove('loading')
    })

    img.addEventListener('error', () => {
      img.classList.add('error')
      img.classList.remove('loading')
      // デフォルト画像を設定
      img.src = '/assets/placeholder.svg'
    })

    img.classList.add('loading')
    img.src = src
  }

  // 遅延コンテンツ読み込み
  setupIntersectionObserver() {
    if (!this.deferredContentTargets.length) return

    this.deferredObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.loadDeferredContent(entry.target)
          this.deferredObserver.unobserve(entry.target)
        }
      })
    }, {
      rootMargin: '100px 0px'
    })

    this.deferredContentTargets.forEach(element => {
      this.deferredObserver.observe(element)
    })
  }

  // 遅延コンテンツ読み込み
  loadDeferredContent(element) {
    const url = element.dataset.url
    if (!url) return

    element.classList.add('loading')
    
    fetch(url)
      .then(response => response.text())
      .then(html => {
        element.innerHTML = html
        element.classList.remove('loading')
        element.classList.add('loaded')
      })
      .catch(error => {
        console.error('Failed to load deferred content:', error)
        element.classList.remove('loading')
        element.classList.add('error')
        element.innerHTML = '<p class="text-red-500">コンテンツの読み込みに失敗しました</p>'
      })
  }

  // スクロールパフォーマンス最適化
  optimizeScrollPerformance() {
    let ticking = false

    const updateScrollPosition = () => {
      this.handleScroll()
      ticking = false
    }

    const requestScrollUpdate = () => {
      if (!ticking) {
        requestAnimationFrame(updateScrollPosition)
        ticking = true
      }
    }

    window.addEventListener('scroll', requestScrollUpdate, { passive: true })
  }

  // スクロール処理
  handleScroll() {
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop
    
    // ヘッダーの表示/非表示
    const header = document.querySelector('.navbar')
    if (header) {
      if (scrollTop > 100) {
        header.classList.add('scrolled')
      } else {
        header.classList.remove('scrolled')
      }
    }

    // トップに戻るボタン
    const backToTop = document.querySelector('.back-to-top')
    if (backToTop) {
      if (scrollTop > 300) {
        backToTop.classList.add('visible')
      } else {
        backToTop.classList.remove('visible')
      }
    }
  }

  // 重要リソースの先読み
  preloadCriticalResources() {
    const criticalResources = [
      '/assets/critical.css',
      '/assets/fonts/main.woff2'
    ]

    criticalResources.forEach(resource => {
      const link = document.createElement('link')
      link.rel = 'preload'
      link.href = resource
      
      if (resource.endsWith('.css')) {
        link.as = 'style'
      } else if (resource.endsWith('.woff2')) {
        link.as = 'font'
        link.type = 'font/woff2'
        link.crossOrigin = 'anonymous'
      }
      
      document.head.appendChild(link)
    })
  }

  // 画像プリロード
  preloadImages(urls) {
    urls.forEach(url => {
      const img = new Image()
      img.src = url
    })
  }

  // Service Worker登録
  registerServiceWorker() {
    if ('serviceWorker' in navigator && 'caches' in window) {
      navigator.serviceWorker.register('/sw.js')
        .then(registration => {
          console.log('Service Worker registered:', registration)
        })
        .catch(error => {
          console.log('Service Worker registration failed:', error)
        })
    }
  }

  // Web Vitals測定
  measureWebVitals() {
    // Core Web Vitals
    this.measureLCP() // Largest Contentful Paint
    this.measureFID() // First Input Delay
    this.measureCLS() // Cumulative Layout Shift
  }

  measureLCP() {
    if ('PerformanceObserver' in window) {
      const observer = new PerformanceObserver((list) => {
        const entries = list.getEntries()
        const lastEntry = entries[entries.length - 1]
        console.log('LCP:', lastEntry.startTime)
        
        // メトリクス送信
        this.sendMetric('lcp', lastEntry.startTime)
      })
      
      observer.observe({ entryTypes: ['largest-contentful-paint'] })
    }
  }

  measureFID() {
    if ('PerformanceObserver' in window) {
      const observer = new PerformanceObserver((list) => {
        const firstEntry = list.getEntries()[0]
        console.log('FID:', firstEntry.processingStart - firstEntry.startTime)
        
        this.sendMetric('fid', firstEntry.processingStart - firstEntry.startTime)
      })
      
      observer.observe({ entryTypes: ['first-input'] })
    }
  }

  measureCLS() {
    let clsValue = 0
    
    if ('PerformanceObserver' in window) {
      const observer = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (!entry.hadRecentInput) {
            clsValue += entry.value
          }
        }
        
        console.log('CLS:', clsValue)
        this.sendMetric('cls', clsValue)
      })
      
      observer.observe({ entryTypes: ['layout-shift'] })
    }
  }

  // メトリクス送信
  sendMetric(name, value) {
    if (navigator.sendBeacon) {
      const data = JSON.stringify({ metric: name, value: value, timestamp: Date.now() })
      navigator.sendBeacon('/api/v1/metrics', data)
    }
  }

  // リソースヒント追加
  addResourceHints() {
    const hints = [
      { rel: 'dns-prefetch', href: '//fonts.googleapis.com' },
      { rel: 'preconnect', href: 'https://api.example.com' },
      { rel: 'prefetch', href: '/next-page.html' }
    ]

    hints.forEach(hint => {
      const link = document.createElement('link')
      link.rel = hint.rel
      link.href = hint.href
      if (hint.crossorigin) link.crossOrigin = hint.crossorigin
      document.head.appendChild(link)
    })
  }

  // キャッシュ戦略
  implementCacheStrategy() {
    // localStorage使用量確認
    this.checkLocalStorageUsage()
    
    // セッションストレージクリーンアップ
    this.cleanupSessionStorage()
  }

  checkLocalStorageUsage() {
    try {
      const used = new Blob(Object.values(localStorage)).size
      const total = 5 * 1024 * 1024 // 5MB
      const usage = (used / total * 100).toFixed(2)
      
      console.log(`LocalStorage usage: ${usage}%`)
      
      if (usage > 80) {
        console.warn('LocalStorage usage is high, consider cleanup')
        this.cleanupLocalStorage()
      }
    } catch (error) {
      console.error('Error checking localStorage usage:', error)
    }
  }

  cleanupLocalStorage() {
    const keysToRemove = []
    const expirePrefix = 'expire_'
    
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i)
      
      if (key.startsWith(expirePrefix)) {
        const expireTime = parseInt(localStorage.getItem(key))
        if (Date.now() > expireTime) {
          const dataKey = key.replace(expirePrefix, '')
          keysToRemove.push(key, dataKey)
        }
      }
    }
    
    keysToRemove.forEach(key => localStorage.removeItem(key))
  }

  cleanupSessionStorage() {
    // 1時間以上前のデータを削除
    const oneHourAgo = Date.now() - (60 * 60 * 1000)
    
    for (let i = sessionStorage.length - 1; i >= 0; i--) {
      const key = sessionStorage.key(i)
      const value = sessionStorage.getItem(key)
      
      try {
        const data = JSON.parse(value)
        if (data.timestamp && data.timestamp < oneHourAgo) {
          sessionStorage.removeItem(key)
        }
      } catch (error) {
        // JSON以外のデータはそのまま保持
      }
    }
  }
}