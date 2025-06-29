class MemoryOptimizerService
  include Singleton

  def initialize
    @optimization_results = {
      memory_analysis: {},
      n_plus_one_fixes: [],
      query_optimizations: [],
      garbage_collection: {},
      object_allocations: {},
      memory_leaks: [],
      recommendations: [],
      performance_score: 0
    }
  end

  def run_memory_optimization
    Rails.logger.info "Starting memory optimization analysis..."
    
    analyze_current_memory_usage
    detect_n_plus_one_queries
    analyze_object_allocations
    check_garbage_collection
    detect_memory_leaks
    optimize_eager_loading
    generate_optimization_recommendations
    
    calculate_memory_score
    
    Rails.logger.info "Memory optimization completed. Score: #{@optimization_results[:performance_score]}"
    @optimization_results
  end

  private

  def analyze_current_memory_usage
    Rails.logger.info "Analyzing current memory usage..."
    
    # Get process memory information
    memory_info = {
      process_memory_mb: get_process_memory,
      ruby_memory_mb: get_ruby_memory,
      object_counts: ObjectSpace.count_objects,
      gc_stats: GC.stat
    }
    
    # Calculate memory efficiency
    total_objects = memory_info[:object_counts][:TOTAL] - memory_info[:object_counts][:FREE]
    memory_per_object = memory_info[:ruby_memory_mb] / total_objects.to_f * 1024 * 1024 # bytes per object
    
    memory_info[:memory_efficiency] = {
      total_objects: total_objects,
      memory_per_object_bytes: memory_per_object.round(2),
      efficiency_rating: classify_memory_efficiency(memory_per_object)
    }
    
    @optimization_results[:memory_analysis] = memory_info
  end

  def detect_n_plus_one_queries
    Rails.logger.info "Detecting and analyzing N+1 queries..."
    
    n_plus_one_scenarios = [
      {
        name: "Patient appointments access",
        inefficient: -> { 
          patients = Patient.limit(10).to_a
          patients.map { |p| p.appointments.count }
        },
        efficient: -> { 
          Patient.includes(:appointments).limit(10).map { |p| p.appointments.size }
        }
      },
      {
        name: "Employee clockings with details",
        inefficient: -> {
          employees = Employee.limit(5).to_a
          employees.map { |e| e.clockings.map(&:clock_type) }
        },
        efficient: -> {
          Employee.includes(:clockings).limit(5).map { |e| e.clockings.map(&:clock_type) }
        }
      },
      {
        name: "Appointment patient and employee details",
        inefficient: -> {
          appointments = Appointment.limit(10).to_a
          appointments.map { |a| [a.patient&.name, a.employee&.full_name] }
        },
        efficient: -> {
          Appointment.includes(:patient, :employee).limit(10).map { |a| [a.patient&.name, a.employee&.full_name] }
        }
      },
      {
        name: "Payroll employee information",
        inefficient: -> {
          payrolls = Payroll.limit(5).to_a
          payrolls.map { |p| p.employee&.full_name }
        },
        efficient: -> {
          Payroll.includes(:employee).limit(5).map { |p| p.employee&.full_name }
        }
      }
    ]
    
    n_plus_one_fixes = []
    
    n_plus_one_scenarios.each do |scenario|
      # Measure inefficient approach
      inefficient_memory = measure_memory_usage do
        scenario[:inefficient].call rescue nil
      end
      
      # Measure efficient approach
      efficient_memory = measure_memory_usage do
        scenario[:efficient].call rescue nil
      end
      
      memory_saved = inefficient_memory - efficient_memory
      
      if memory_saved > 0.1 # Significant memory difference (MB)
        n_plus_one_fixes << {
          scenario: scenario[:name],
          memory_before_mb: inefficient_memory.round(2),
          memory_after_mb: efficient_memory.round(2),
          memory_saved_mb: memory_saved.round(2),
          savings_percentage: ((memory_saved / inefficient_memory) * 100).round(1),
          priority: memory_saved > 1.0 ? :high : :medium
        }
      end
    end
    
    @optimization_results[:n_plus_one_fixes] = n_plus_one_fixes
  end

  def analyze_object_allocations
    Rails.logger.info "Analyzing object allocations..."
    
    # Track object allocations for common operations
    allocation_tests = [
      {
        name: "Patient creation and search",
        operation: -> {
          Patient.create!(
            name: "Test Patient #{rand(1000)}",
            name_kana: "テストタロウ",
            email: "test#{rand(1000)}@example.com",
            phone: "090-1234-5678"
          )
          Patient.where(name: "Test Patient").limit(5).to_a
        }
      },
      {
        name: "Appointment complex query",
        operation: -> {
          if Patient.any? && Employee.any?
            Appointment.joins(:patient, :employee)
                      .where(appointment_date: Date.current)
                      .select(:id, :appointment_date, :status)
                      .limit(10).to_a
          end
        }
      },
      {
        name: "Payroll calculation",
        operation: -> {
          if Employee.any?
            employee = Employee.first
            payroll = Payroll.new(
              employee: employee,
              pay_period_start: Date.current.beginning_of_month,
              pay_period_end: Date.current.end_of_month
            )
            payroll.send(:calculate_pay) if payroll.respond_to?(:calculate_pay, true)
          end
        }
      }
    ]
    
    object_allocations = []
    
    allocation_tests.each do |test|
      allocations = measure_object_allocations do
        test[:operation].call rescue nil
      end
      
      object_allocations << {
        operation: test[:name],
        total_allocations: allocations[:total],
        object_types: allocations[:by_class].sort_by { |_, count| -count }.first(5).to_h,
        memory_allocated_mb: allocations[:memory_mb],
        efficiency_rating: classify_allocation_efficiency(allocations[:total])
      }
    end
    
    @optimization_results[:object_allocations] = object_allocations
  end

  def check_garbage_collection
    Rails.logger.info "Analyzing garbage collection performance..."
    
    gc_before = GC.stat
    
    # Force a GC cycle to get current stats
    GC.start
    
    gc_after = GC.stat
    
    gc_analysis = {
      heap_available_slots: gc_after[:heap_available_slots],
      heap_live_slots: gc_after[:heap_live_slots],
      heap_free_slots: gc_after[:heap_free_slots],
      heap_final_slots: gc_after[:heap_final_slots],
      total_allocated_pages: gc_after[:total_allocated_pages],
      total_freed_pages: gc_after[:total_freed_pages],
      minor_gc_count: gc_after[:minor_gc_count],
      major_gc_count: gc_after[:major_gc_count],
      heap_usage_ratio: (gc_after[:heap_live_slots].to_f / gc_after[:heap_available_slots] * 100).round(2),
      gc_efficiency: calculate_gc_efficiency(gc_after)
    }
    
    @optimization_results[:garbage_collection] = gc_analysis
  end

  def detect_memory_leaks
    Rails.logger.info "Detecting potential memory leaks..."
    
    memory_leaks = []
    
    # Test for potential memory leaks in common operations
    leak_tests = [
      {
        name: "Repeated patient queries",
        test: -> {
          1000.times do
            Patient.where(active: true).limit(1).first
          end
        }
      },
      {
        name: "Large result set processing",
        test: -> {
          if Patient.count > 0
            Patient.find_each(batch_size: 100) do |patient|
              patient.name.upcase # Simple operation
            end
          end
        }
      },
      {
        name: "Complex association loading",
        test: -> {
          if Patient.any?
            50.times do
              Patient.includes(:appointments, :deliveries).limit(5).to_a
            end
          end
        }
      }
    ]
    
    leak_tests.each do |test|
      memory_before = get_ruby_memory
      
      # Run test operation
      begin
        test[:test].call
      rescue => e
        Rails.logger.error "Memory leak test failed: #{e.message}"
        next
      end
      
      # Force GC to clean up
      GC.start
      
      memory_after = get_ruby_memory
      memory_increase = memory_after - memory_before
      
      if memory_increase > 1.0 # Significant memory increase after GC
        memory_leaks << {
          test_name: test[:name],
          memory_before_mb: memory_before.round(2),
          memory_after_mb: memory_after.round(2),
          memory_leaked_mb: memory_increase.round(2),
          severity: memory_increase > 5.0 ? :high : :medium
        }
      end
    end
    
    @optimization_results[:memory_leaks] = memory_leaks
  end

  def optimize_eager_loading
    Rails.logger.info "Optimizing eager loading strategies..."
    
    # Analyze current eager loading and suggest improvements
    eager_loading_optimizations = [
      {
        model: "Patient",
        current: "Patient.all",
        optimized: "Patient.includes(:appointments)",
        benefit: "Reduces N+1 queries when accessing appointments",
        memory_impact: "Low"
      },
      {
        model: "Employee",
        current: "Employee.all",
        optimized: "Employee.includes(:clockings, :payrolls)",
        benefit: "Preloads related work records",
        memory_impact: "Medium"
      },
      {
        model: "Appointment",
        current: "Appointment.all",
        optimized: "Appointment.includes(:patient, :employee)",
        benefit: "Essential for displaying appointment details",
        memory_impact: "Medium"
      },
      {
        model: "Payroll",
        current: "Payroll.all",
        optimized: "Payroll.includes(:employee, :approved_by)",
        benefit: "Includes employee and approval information",
        memory_impact: "Low"
      }
    ]
    
    @optimization_results[:eager_loading_optimizations] = eager_loading_optimizations
  end

  def generate_optimization_recommendations
    recommendations = []
    
    # Memory usage recommendations
    memory_analysis = @optimization_results[:memory_analysis]
    if memory_analysis[:process_memory_mb] > 500
      recommendations << {
        type: :memory_usage,
        priority: :high,
        description: "High memory usage detected (#{memory_analysis[:process_memory_mb]}MB)",
        solution: "Consider implementing pagination, caching, or background processing"
      }
    end
    
    # N+1 query fixes
    @optimization_results[:n_plus_one_fixes].each do |fix|
      recommendations << {
        type: :n_plus_one,
        priority: fix[:priority],
        description: "Fix N+1 query in #{fix[:scenario]}",
        memory_savings: "#{fix[:memory_saved_mb]}MB (#{fix[:savings_percentage]}%)",
        solution: "Use includes() or joins() for eager loading"
      }
    end
    
    # Object allocation optimizations
    @optimization_results[:object_allocations].each do |allocation|
      if allocation[:efficiency_rating] == :poor
        recommendations << {
          type: :object_allocation,
          priority: :medium,
          description: "High object allocation in #{allocation[:operation]}",
          details: "#{allocation[:total_allocations]} objects allocated",
          solution: "Optimize query structure and reduce intermediate objects"
        }
      end
    end
    
    # Memory leak fixes
    @optimization_results[:memory_leaks].each do |leak|
      recommendations << {
        type: :memory_leak,
        priority: leak[:severity],
        description: "Potential memory leak in #{leak[:test_name]}",
        leaked_memory: "#{leak[:memory_leaked_mb]}MB",
        solution: "Review object lifecycle and ensure proper cleanup"
      }
    end
    
    # GC optimization
    gc_stats = @optimization_results[:garbage_collection]
    if gc_stats[:heap_usage_ratio] > 90
      recommendations << {
        type: :garbage_collection,
        priority: :medium,
        description: "High heap usage ratio (#{gc_stats[:heap_usage_ratio]}%)",
        solution: "Consider tuning Ruby GC parameters or reducing object creation"
      }
    end
    
    @optimization_results[:recommendations] = recommendations
  end

  def calculate_memory_score
    score = 100
    
    # Deduct points for memory issues
    memory_analysis = @optimization_results[:memory_analysis]
    if memory_analysis[:process_memory_mb] > 1000
      score -= 30
    elsif memory_analysis[:process_memory_mb] > 500
      score -= 15
    end
    
    # N+1 query penalties
    @optimization_results[:n_plus_one_fixes].each do |fix|
      penalty = fix[:priority] == :high ? 15 : 8
      score -= penalty
    end
    
    # Memory leak penalties
    @optimization_results[:memory_leaks].each do |leak|
      penalty = leak[:severity] == :high ? 20 : 10
      score -= penalty
    end
    
    # Object allocation penalties
    @optimization_results[:object_allocations].each do |allocation|
      score -= 5 if allocation[:efficiency_rating] == :poor
    end
    
    # GC efficiency penalty
    gc_stats = @optimization_results[:garbage_collection]
    if gc_stats[:heap_usage_ratio] > 90
      score -= 10
    elsif gc_stats[:heap_usage_ratio] > 80
      score -= 5
    end
    
    score = [score, 0].max
    @optimization_results[:performance_score] = score
  end

  def measure_memory_usage
    memory_before = get_ruby_memory
    yield
    memory_after = get_ruby_memory
    memory_after - memory_before
  end

  def measure_object_allocations
    allocations_before = ObjectSpace.count_objects
    memory_before = get_ruby_memory
    
    yield
    
    allocations_after = ObjectSpace.count_objects
    memory_after = get_ruby_memory
    
    total_allocated = 0
    by_class = {}
    
    allocations_after.each do |type, count_after|
      count_before = allocations_before[type] || 0
      allocated = count_after - count_before
      
      if allocated > 0
        total_allocated += allocated
        by_class[type] = allocated
      end
    end
    
    {
      total: total_allocated,
      by_class: by_class,
      memory_mb: memory_after - memory_before
    }
  end

  def get_process_memory
    # Get memory usage in MB
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0 rescue 0
  end

  def get_ruby_memory
    # Get Ruby heap memory in MB
    GC.stat[:heap_live_slots] * 40 / 1024.0 / 1024.0 # Approximate
  end

  def classify_memory_efficiency(memory_per_object)
    case memory_per_object
    when 0..100 then :excellent
    when 100..200 then :good
    when 200..400 then :fair
    when 400..800 then :poor
    else :critical
    end
  end

  def classify_allocation_efficiency(total_allocations)
    case total_allocations
    when 0..1000 then :excellent
    when 1000..5000 then :good
    when 5000..10000 then :fair
    when 10000..20000 then :poor
    else :critical
    end
  end

  def calculate_gc_efficiency(gc_stats)
    live_ratio = gc_stats[:heap_live_slots].to_f / gc_stats[:heap_available_slots]
    
    case live_ratio
    when 0..0.6 then :excellent
    when 0.6..0.75 then :good
    when 0.75..0.85 then :fair
    when 0.85..0.95 then :poor
    else :critical
    end
  end

  # Class methods for easy access
  class << self
    def optimize
      instance.run_memory_optimization
    end

    def quick_memory_check
      {
        current_memory_mb: instance.get_ruby_memory.round(2),
        process_memory_mb: instance.get_process_memory.round(2),
        object_count: ObjectSpace.count_objects[:TOTAL],
        gc_count: GC.stat[:count]
      }
    end

    def generate_eager_loading_guide
      optimizer = instance
      result = optimizer.run_memory_optimization
      
      guide = "# Eager Loading Optimization Guide\n\n"
      
      result[:eager_loading_optimizations].each do |opt|
        guide += "## #{opt[:model]}\n"
        guide += "**Current**: `#{opt[:current]}`\n"
        guide += "**Optimized**: `#{opt[:optimized]}`\n"
        guide += "**Benefit**: #{opt[:benefit]}\n"
        guide += "**Memory Impact**: #{opt[:memory_impact]}\n\n"
      end
      
      guide
    end

    def memory_optimization_report
      optimizer = instance
      result = optimizer.run_memory_optimization
      
      {
        score: result[:performance_score],
        memory_usage_mb: result[:memory_analysis][:process_memory_mb],
        n_plus_one_issues: result[:n_plus_one_fixes].length,
        memory_leaks: result[:memory_leaks].length,
        recommendations: result[:recommendations].length,
        high_priority_issues: result[:recommendations].count { |r| r[:priority] == :high }
      }
    end
  end
end