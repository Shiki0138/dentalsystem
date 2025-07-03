// 歯科クリニック予約管理システム - APIクライアント
class DentalClinicAPI {
  constructor(baseURL = 'http://localhost:3001') {
    this.baseURL = baseURL;
    this.token = localStorage.getItem('auth_token');
    this.cable = null;
  }

  // ヘッダー設定
  getHeaders() {
    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    
    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }
    
    return headers;
  }

  // 認証API
  async login(email, password) {
    try {
      const response = await fetch(`${this.baseURL}/api/v1/auth/login`, {
        method: 'POST',
        headers: this.getHeaders(),
        credentials: 'include',
        body: JSON.stringify({ email, password })
      });

      if (!response.ok) throw new Error('ログインに失敗しました');

      const data = await response.json();
      this.token = data.token;
      localStorage.setItem('auth_token', this.token);
      
      // WebSocket接続
      this.connectWebSocket();
      
      return data;
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  }

  async logout() {
    try {
      await fetch(`${this.baseURL}/api/v1/auth/logout`, {
        method: 'POST',
        headers: this.getHeaders(),
        credentials: 'include'
      });

      this.token = null;
      localStorage.removeItem('auth_token');
      
      // WebSocket切断
      if (this.cable) {
        this.cable.close();
      }
    } catch (error) {
      console.error('Logout error:', error);
    }
  }

  async verifyToken() {
    try {
      const response = await fetch(`${this.baseURL}/api/v1/auth/verify`, {
        method: 'GET',
        headers: this.getHeaders(),
        credentials: 'include'
      });

      if (!response.ok) {
        this.token = null;
        localStorage.removeItem('auth_token');
        return false;
      }

      return await response.json();
    } catch (error) {
      console.error('Token verification error:', error);
      return false;
    }
  }

  // 予約API
  async getAppointments(date = null) {
    try {
      const url = date 
        ? `${this.baseURL}/api/v1/appointments?date=${date}`
        : `${this.baseURL}/api/v1/appointments`;
        
      const response = await fetch(url, {
        method: 'GET',
        headers: this.getHeaders(),
        credentials: 'include'
      });

      if (!response.ok) throw new Error('予約の取得に失敗しました');

      return await response.json();
    } catch (error) {
      console.error('Get appointments error:', error);
      throw error;
    }
  }

  async createAppointment(appointmentData) {
    try {
      const response = await fetch(`${this.baseURL}/api/v1/appointments`, {
        method: 'POST',
        headers: this.getHeaders(),
        credentials: 'include',
        body: JSON.stringify({ appointment: appointmentData })
      });

      if (!response.ok) throw new Error('予約の作成に失敗しました');

      return await response.json();
    } catch (error) {
      console.error('Create appointment error:', error);
      throw error;
    }
  }

  async updateAppointment(id, appointmentData) {
    try {
      const response = await fetch(`${this.baseURL}/api/v1/appointments/${id}`, {
        method: 'PUT',
        headers: this.getHeaders(),
        credentials: 'include',
        body: JSON.stringify({ appointment: appointmentData })
      });

      if (!response.ok) throw new Error('予約の更新に失敗しました');

      return await response.json();
    } catch (error) {
      console.error('Update appointment error:', error);
      throw error;
    }
  }

  async cancelAppointment(id, reason) {
    try {
      const response = await fetch(`${this.baseURL}/api/v1/appointments/${id}/cancel`, {
        method: 'POST',
        headers: this.getHeaders(),
        credentials: 'include',
        body: JSON.stringify({ reason })
      });

      if (!response.ok) throw new Error('予約のキャンセルに失敗しました');

      return await response.json();
    } catch (error) {
      console.error('Cancel appointment error:', error);
      throw error;
    }
  }

  // 患者API
  async getPatients(search = '') {
    try {
      const url = search 
        ? `${this.baseURL}/api/v1/patients?search=${encodeURIComponent(search)}`
        : `${this.baseURL}/api/v1/patients`;
        
      const response = await fetch(url, {
        method: 'GET',
        headers: this.getHeaders(),
        credentials: 'include'
      });

      if (!response.ok) throw new Error('患者の取得に失敗しました');

      return await response.json();
    } catch (error) {
      console.error('Get patients error:', error);
      throw error;
    }
  }

  async createPatient(patientData) {
    try {
      const response = await fetch(`${this.baseURL}/api/v1/patients`, {
        method: 'POST',
        headers: this.getHeaders(),
        credentials: 'include',
        body: JSON.stringify({ patient: patientData })
      });

      if (!response.ok) throw new Error('患者の登録に失敗しました');

      return await response.json();
    } catch (error) {
      console.error('Create patient error:', error);
      throw error;
    }
  }

  // WebSocket接続
  connectWebSocket() {
    if (!this.token) return;

    // WebSocket URLの構築
    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsURL = `${wsProtocol}//${this.baseURL.replace(/^https?:\/\//, '')}/cable?token=${this.token}`;

    this.cable = new WebSocket(wsURL);

    this.cable.onopen = () => {
      console.log('WebSocket connected');
      
      // 通知チャンネルを購読
      this.subscribeToChannel('NotificationsChannel');
      this.subscribeToChannel('AppointmentsChannel');
    };

    this.cable.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      if (data.type === 'ping') return;
      
      // イベントを発火
      window.dispatchEvent(new CustomEvent('websocket:message', { detail: data }));
      
      // チャンネル別の処理
      if (data.identifier) {
        const identifier = JSON.parse(data.identifier);
        
        if (identifier.channel === 'NotificationsChannel') {
          this.handleNotification(data.message);
        } else if (identifier.channel === 'AppointmentsChannel') {
          this.handleAppointmentUpdate(data.message);
        }
      }
    };

    this.cable.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    this.cable.onclose = () => {
      console.log('WebSocket disconnected');
      // 5秒後に再接続を試みる
      setTimeout(() => {
        if (this.token) {
          this.connectWebSocket();
        }
      }, 5000);
    };
  }

  subscribeToChannel(channelName) {
    if (!this.cable || this.cable.readyState !== WebSocket.OPEN) return;

    const subscription = {
      command: 'subscribe',
      identifier: JSON.stringify({ channel: channelName })
    };

    this.cable.send(JSON.stringify(subscription));
  }

  handleNotification(message) {
    // 通知をUIに表示
    console.log('Notification received:', message);
    
    // カスタムイベントを発火
    window.dispatchEvent(new CustomEvent('notification:received', { 
      detail: message 
    }));
  }

  handleAppointmentUpdate(message) {
    // 予約更新をUIに反映
    console.log('Appointment update:', message);
    
    // カスタムイベントを発火
    window.dispatchEvent(new CustomEvent('appointment:updated', { 
      detail: message 
    }));
  }

  // ダッシュボードAPI
  async getDashboardStats() {
    try {
      const response = await fetch(`${this.baseURL}/api/v1/dashboard/stats`, {
        method: 'GET',
        headers: this.getHeaders(),
        credentials: 'include'
      });

      if (!response.ok) throw new Error('ダッシュボードデータの取得に失敗しました');

      return await response.json();
    } catch (error) {
      console.error('Get dashboard stats error:', error);
      throw error;
    }
  }

  // AI予測API
  async getAIPredictions(type) {
    try {
      const response = await fetch(`${this.baseURL}/api/v1/ai/predictions/${type}`, {
        method: 'GET',
        headers: this.getHeaders(),
        credentials: 'include'
      });

      if (!response.ok) throw new Error('AI予測の取得に失敗しました');

      return await response.json();
    } catch (error) {
      console.error('Get AI predictions error:', error);
      throw error;
    }
  }
}

// グローバルに公開
window.DentalClinicAPI = DentalClinicAPI;

// 使用例
/*
const api = new DentalClinicAPI();

// ログイン
await api.login('admin@dental.clinic', 'password123');

// 予約を取得
const appointments = await api.getAppointments();

// WebSocketイベントをリスン
window.addEventListener('notification:received', (event) => {
  console.log('通知:', event.detail);
});

window.addEventListener('appointment:updated', (event) => {
  console.log('予約更新:', event.detail);
});
*/