// 患者リアルタイム検索システム - 史上最高品質
document.addEventListener('DOMContentLoaded', function() {
  const searchInput = document.getElementById('patient-search-input');
  const searchResults = document.getElementById('search-results');
  const patientsGrid = document.getElementById('patients-grid');
  let searchTimeout;
  let currentRequest;

  if (!searchInput) return;

  // 検索入力時のイベントハンドラー
  searchInput.addEventListener('input', function(e) {
    const query = e.target.value.trim();
    
    // 既存のタイムアウトをクリア
    clearTimeout(searchTimeout);
    
    // 既存のリクエストをキャンセル
    if (currentRequest) {
      currentRequest.abort();
    }

    // 300ms後に検索実行（デバウンス）
    searchTimeout = setTimeout(() => {
      performSearch(query);
    }, 300);
  });

  // 検索実行関数
  function performSearch(query) {
    // 空の場合は全患者表示
    if (query === '') {
      showAllPatients();
      hideSearchResults();
      return;
    }

    // 最低2文字以上で検索
    if (query.length < 2) {
      hideSearchResults();
      return;
    }

    // ローディング状態表示
    showLoadingState();

    // AJAX検索リクエスト
    currentRequest = fetch(`/patients/search?q=${encodeURIComponent(query)}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error('検索に失敗しました');
      }
      return response.json();
    })
    .then(data => {
      displaySearchResults(data);
      hideLoadingState();
    })
    .catch(error => {
      if (error.name !== 'AbortError') {
        console.error('検索エラー:', error);
        showErrorState();
      }
    })
    .finally(() => {
      currentRequest = null;
    });
  }

  // 検索結果表示
  function displaySearchResults(patients) {
    if (!searchResults) return;

    searchResults.style.display = 'block';
    
    if (patients.length === 0) {
      searchResults.innerHTML = `
        <div class="search-no-results">
          <div class="no-results-icon">
            <svg class="w-12 h-12 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M9.172 16.172a4 4 0 015.656 0M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
          </div>
          <h3 class="text-lg font-medium text-gray-400 mb-2">該当する患者が見つかりません</h3>
          <p class="text-sm text-gray-500">検索条件を変更してお試しください</p>
        </div>
      `;
      return;
    }

    const resultsHTML = patients.map(patient => `
      <div class="search-result-item" data-patient-id="${patient.id}">
        <div class="patient-avatar">
          <span class="avatar-text">${patient.name.charAt(0)}</span>
        </div>
        <div class="patient-info">
          <div class="patient-name">
            <span class="name-text">${highlightText(patient.name, searchInput.value)}</span>
            <span class="patient-number">${patient.patient_number}</span>
          </div>
          <div class="patient-details">
            <span class="kana-text">${highlightText(patient.name_kana || '', searchInput.value)}</span>
            ${patient.phone ? `<span class="phone-text">${highlightText(patient.phone, searchInput.value)}</span>` : ''}
          </div>
        </div>
        <div class="patient-actions">
          <a href="/patients/${patient.id}" class="action-btn view-btn">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
            </svg>
            詳細
          </a>
          <a href="/patients/${patient.id}/edit" class="action-btn edit-btn">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
            </svg>
            編集
          </a>
        </div>
      </div>
    `).join('');

    searchResults.innerHTML = `
      <div class="search-results-header">
        <h3 class="results-title">検索結果 (${patients.length}件)</h3>
        <button class="clear-search-btn" onclick="clearSearch()">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
          クリア
        </button>
      </div>
      <div class="search-results-list">
        ${resultsHTML}
      </div>
    `;

    // 患者グリッドを隠す
    if (patientsGrid) {
      patientsGrid.style.display = 'none';
    }
  }

  // 検索結果のテキストハイライト
  function highlightText(text, query) {
    if (!query || !text) return text;
    
    const regex = new RegExp(`(${escapeRegex(query)})`, 'gi');
    return text.replace(regex, '<mark class="search-highlight">$1</mark>');
  }

  // 正規表現エスケープ
  function escapeRegex(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  // ローディング状態表示
  function showLoadingState() {
    if (!searchResults) return;
    
    searchResults.style.display = 'block';
    searchResults.innerHTML = `
      <div class="search-loading">
        <div class="loading-spinner">
          <svg class="animate-spin w-6 h-6 text-blue-600" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        </div>
        <span class="loading-text">検索中...</span>
      </div>
    `;
  }

  // エラー状態表示
  function showErrorState() {
    if (!searchResults) return;
    
    searchResults.style.display = 'block';
    searchResults.innerHTML = `
      <div class="search-error">
        <div class="error-icon">
          <svg class="w-8 h-8 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.082 16.5c-.77.833.192 2.5 1.732 2.5z"/>
          </svg>
        </div>
        <p class="error-text">検索中にエラーが発生しました</p>
        <button class="retry-btn" onclick="performSearch(document.getElementById('patient-search-input').value)">
          再試行
        </button>
      </div>
    `;
  }

  // ローディング状態を隠す
  function hideLoadingState() {
    // 既にdisplaySearchResults内で処理済み
  }

  // 検索結果を隠す
  function hideSearchResults() {
    if (searchResults) {
      searchResults.style.display = 'none';
    }
  }

  // 全患者表示
  function showAllPatients() {
    if (patientsGrid) {
      patientsGrid.style.display = 'block';
    }
  }

  // グローバル関数: 検索クリア
  window.clearSearch = function() {
    searchInput.value = '';
    hideSearchResults();
    showAllPatients();
    searchInput.focus();
  };

  // Enter キーでの最初の結果への移動
  searchInput.addEventListener('keydown', function(e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      const firstResult = searchResults.querySelector('.search-result-item .view-btn');
      if (firstResult) {
        window.location.href = firstResult.href;
      }
    }
  });

  // 検索結果クリック時の統計記録
  document.addEventListener('click', function(e) {
    if (e.target.closest('.search-result-item')) {
      // 検索利用統計を記録（今後の改善のため）
      console.log('Search result clicked:', {
        query: searchInput.value,
        timestamp: new Date().toISOString()
      });
    }
  });
});

// CSS スタイル（インライン定義）
const searchStyles = `
<style>
  .search-loading {
    @apply flex items-center justify-center p-6 text-gray-600;
  }
  
  .loading-spinner {
    @apply mr-3;
  }
  
  .search-error {
    @apply text-center p-6;
  }
  
  .error-icon {
    @apply mb-3;
  }
  
  .retry-btn {
    @apply mt-3 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors;
  }
  
  .search-no-results {
    @apply text-center p-8;
  }
  
  .no-results-icon {
    @apply mb-4;
  }
  
  .search-results-header {
    @apply flex items-center justify-between p-4 border-b border-gray-200 bg-gray-50;
  }
  
  .results-title {
    @apply text-lg font-semibold text-gray-900;
  }
  
  .clear-search-btn {
    @apply flex items-center px-3 py-1.5 text-sm text-gray-600 hover:text-gray-800 transition-colors;
  }
  
  .search-results-list {
    @apply divide-y divide-gray-100;
  }
  
  .search-result-item {
    @apply flex items-center p-4 hover:bg-blue-50 transition-colors duration-200;
  }
  
  .patient-avatar {
    @apply w-12 h-12 bg-gradient-to-br from-blue-400 to-blue-600 rounded-full flex items-center justify-center mr-4 flex-shrink-0;
  }
  
  .avatar-text {
    @apply text-white font-bold text-lg;
  }
  
  .patient-info {
    @apply flex-1 min-w-0;
  }
  
  .patient-name {
    @apply flex items-center space-x-2 mb-1;
  }
  
  .name-text {
    @apply font-medium text-gray-900;
  }
  
  .patient-number {
    @apply text-xs bg-blue-100 text-blue-800 px-2 py-0.5 rounded-full;
  }
  
  .patient-details {
    @apply text-sm text-gray-500 space-x-3;
  }
  
  .search-highlight {
    @apply bg-yellow-200 px-1 rounded;
  }
  
  .patient-actions {
    @apply flex items-center space-x-2;
  }
  
  .action-btn {
    @apply inline-flex items-center px-3 py-1.5 text-sm font-medium rounded-lg transition-colors duration-200;
  }
  
  .view-btn {
    @apply text-blue-700 bg-blue-100 hover:bg-blue-200;
  }
  
  .edit-btn {
    @apply text-gray-700 bg-gray-100 hover:bg-gray-200;
  }
  
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
  
  .animate-spin {
    animation: spin 1s linear infinite;
  }
</style>
`;

// スタイルを注入
if (!document.getElementById('patients-search-styles')) {
  const styleElement = document.createElement('div');
  styleElement.id = 'patients-search-styles';
  styleElement.innerHTML = searchStyles;
  document.head.appendChild(styleElement);
}