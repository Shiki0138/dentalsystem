import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    data: Array,
    type: String,
    title: String
  }
  
  connect() {
    this.renderChart()
    
    // Re-render on window resize for responsiveness
    this.resizeHandler = this.handleResize.bind(this)
    window.addEventListener('resize', this.resizeHandler)
  }
  
  disconnect() {
    window.removeEventListener('resize', this.resizeHandler)
  }
  
  renderChart() {
    const canvas = document.createElement('canvas')
    canvas.style.width = '100%'
    canvas.style.height = '300px'
    this.element.appendChild(canvas)
    
    // Simple bar chart implementation using Canvas API
    const ctx = canvas.getContext('2d')
    const data = this.dataValue
    
    if (!data || data.length === 0) {
      this.renderEmptyState(ctx, canvas)
      return
    }
    
    // Set canvas size
    const rect = this.element.getBoundingClientRect()
    canvas.width = rect.width * window.devicePixelRatio
    canvas.height = 300 * window.devicePixelRatio
    ctx.scale(window.devicePixelRatio, window.devicePixelRatio)
    
    // Draw based on chart type
    switch (this.typeValue) {
      case 'bar':
        this.drawBarChart(ctx, canvas, data)
        break
      case 'line':
        this.drawLineChart(ctx, canvas, data)
        break
      case 'pie':
        this.drawPieChart(ctx, canvas, data)
        break
      default:
        this.drawBarChart(ctx, canvas, data)
    }
  }
  
  drawBarChart(ctx, canvas, data) {
    const padding = 40
    const chartWidth = canvas.width / window.devicePixelRatio - padding * 2
    const chartHeight = canvas.height / window.devicePixelRatio - padding * 2
    const barWidth = chartWidth / data.length * 0.8
    const gap = chartWidth / data.length * 0.2
    
    // Find max value
    const maxValue = Math.max(...data.map(d => d.value))
    
    // Draw bars
    data.forEach((item, index) => {
      const barHeight = (item.value / maxValue) * chartHeight
      const x = padding + (index * (barWidth + gap))
      const y = padding + chartHeight - barHeight
      
      // Bar
      ctx.fillStyle = '#4F46E5'
      ctx.fillRect(x, y, barWidth, barHeight)
      
      // Value label
      ctx.fillStyle = '#111827'
      ctx.font = '12px sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText(item.value.toString(), x + barWidth / 2, y - 5)
      
      // Label
      ctx.save()
      ctx.translate(x + barWidth / 2, padding + chartHeight + 15)
      ctx.rotate(-Math.PI / 4)
      ctx.textAlign = 'right'
      ctx.fillText(item.label, 0, 0)
      ctx.restore()
    })
    
    // Title
    if (this.titleValue) {
      ctx.fillStyle = '#111827'
      ctx.font = 'bold 16px sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText(this.titleValue, canvas.width / window.devicePixelRatio / 2, 20)
    }
  }
  
  drawLineChart(ctx, canvas, data) {
    // Simplified line chart implementation
    const padding = 40
    const chartWidth = canvas.width / window.devicePixelRatio - padding * 2
    const chartHeight = canvas.height / window.devicePixelRatio - padding * 2
    
    const maxValue = Math.max(...data.map(d => d.value))
    const xStep = chartWidth / (data.length - 1)
    
    // Draw line
    ctx.strokeStyle = '#4F46E5'
    ctx.lineWidth = 2
    ctx.beginPath()
    
    data.forEach((item, index) => {
      const x = padding + (index * xStep)
      const y = padding + chartHeight - (item.value / maxValue * chartHeight)
      
      if (index === 0) {
        ctx.moveTo(x, y)
      } else {
        ctx.lineTo(x, y)
      }
      
      // Draw point
      ctx.fillStyle = '#4F46E5'
      ctx.beginPath()
      ctx.arc(x, y, 4, 0, Math.PI * 2)
      ctx.fill()
    })
    
    ctx.stroke()
  }
  
  drawPieChart(ctx, canvas, data) {
    // Simplified pie chart implementation
    const centerX = canvas.width / window.devicePixelRatio / 2
    const centerY = canvas.height / window.devicePixelRatio / 2
    const radius = Math.min(centerX, centerY) - 40
    
    const total = data.reduce((sum, item) => sum + item.value, 0)
    let currentAngle = -Math.PI / 2
    
    const colors = ['#4F46E5', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6']
    
    data.forEach((item, index) => {
      const sliceAngle = (item.value / total) * Math.PI * 2
      
      // Draw slice
      ctx.fillStyle = colors[index % colors.length]
      ctx.beginPath()
      ctx.moveTo(centerX, centerY)
      ctx.arc(centerX, centerY, radius, currentAngle, currentAngle + sliceAngle)
      ctx.closePath()
      ctx.fill()
      
      // Draw label
      const labelAngle = currentAngle + sliceAngle / 2
      const labelX = centerX + Math.cos(labelAngle) * (radius * 0.7)
      const labelY = centerY + Math.sin(labelAngle) * (radius * 0.7)
      
      ctx.fillStyle = '#FFFFFF'
      ctx.font = 'bold 12px sans-serif'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText(`${item.label}: ${item.value}`, labelX, labelY)
      
      currentAngle += sliceAngle
    })
  }
  
  renderEmptyState(ctx, canvas) {
    ctx.fillStyle = '#9CA3AF'
    ctx.font = '14px sans-serif'
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText('データがありません', canvas.width / window.devicePixelRatio / 2, canvas.height / window.devicePixelRatio / 2)
  }
  
  handleResize() {
    // Clear and re-render chart
    this.element.innerHTML = ''
    this.renderChart()
  }
}