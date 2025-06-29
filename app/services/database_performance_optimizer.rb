class DatabasePerformanceOptimizer
  include Singleton

  def initialize
    @optimization_results = {
      query_analysis: {},
      index_recommendations: [],
      n_plus_one_detections: [],
      slow_queries: [],
      connection_pool_status: {},
      table_statistics: {},
      overall_health: :unknown,
      performance_score: 0
    }
  end

  def run_comprehensive_optimization
    Rails.logger.info "Starting database performance optimization..."
    
    analyze_query_performance
    detect_missing_indexes
    detect_n_plus_one_queries
    analyze_slow_queries
    check_connection_pool
    analyze_table_statistics
    generate_optimization_recommendations
    
    calculate_performance_score
    
    Rails.logger.info "Database optimization completed. Score: #{@optimization_results[:performance_score]}"
    @optimization_results
  end

  private

  def analyze_query_performance
    Rails.logger.info "Analyzing query performance..."
    
    # Enable query logging temporarily
    original_log_level = ActiveRecord::Base.logger.level
    ActiveRecord::Base.logger.level = Logger::DEBUG
    
    query_stats = {
      total_queries: 0,
      slow_queries: 0,
      average_duration: 0,
      max_duration: 0,
      queries_by_table: {}
    }
    
    # Monitor common operations
    test_queries = [
      -> { Patient.limit(10).to_a },
      -> { Employee.includes(:clockings).limit(5).to_a },
      -> { Appointment.includes(:patient, :employee).limit(5).to_a },
      -> { Payroll.includes(:employee).limit(5).to_a }
    ]
    
    durations = []
    
    test_queries.each do |query_proc|
      start_time = Time.current
      begin
        query_proc.call
        duration = (Time.current - start_time) * 1000 # Convert to milliseconds
        durations << duration
        
        if duration > 100 # Slow query threshold
          query_stats[:slow_queries] += 1
        end
        
        query_stats[:total_queries] += 1
      rescue => e
        Rails.logger.error "Query failed: #{e.message}"
      end
    end
    
    if durations.any?
      query_stats[:average_duration] = durations.sum / durations.length
      query_stats[:max_duration] = durations.max
    end
    
    # Restore original log level
    ActiveRecord::Base.logger.level = original_log_level
    
    @optimization_results[:query_analysis] = query_stats
  end

  def detect_missing_indexes
    Rails.logger.info "Detecting missing indexes..."
    
    index_recommendations = []
    
    # Check for foreign keys without indexes
    ActiveRecord::Base.connection.tables.each do |table_name|
      next if table_name == 'schema_migrations' || table_name == 'ar_internal_metadata'
      
      begin
        columns = ActiveRecord::Base.connection.columns(table_name)
        indexes = ActiveRecord::Base.connection.indexes(table_name)
        indexed_columns = indexes.flat_map(&:columns)
        
        foreign_key_columns = columns.select { |col| col.name.end_with?('_id') }
        
        foreign_key_columns.each do |fk_column|
          unless indexed_columns.include?(fk_column.name)
            index_recommendations << {
              table: table_name,
              column: fk_column.name,
              type: :foreign_key,
              priority: :high,
              reason: "Foreign key #{fk_column.name} lacks index for join performance"
            }
          end
        end
        
        # Check for commonly queried columns
        common_query_columns = %w[email status created_at updated_at name]
        
        common_query_columns.each do |col_name|
          if columns.any? { |col| col.name == col_name } && !indexed_columns.include?(col_name)
            index_recommendations << {
              table: table_name,
              column: col_name,
              type: :query_optimization,
              priority: :medium,
              reason: "Commonly queried column #{col_name} would benefit from index"
            }
          end
        end
        
      rescue => e
        Rails.logger.error "Error analyzing table #{table_name}: #{e.message}"
      end
    end
    
    @optimization_results[:index_recommendations] = index_recommendations
  end

  def detect_n_plus_one_queries
    Rails.logger.info "Detecting N+1 queries..."
    
    n_plus_one_detections = []
    
    # Test common N+1 scenarios
    test_scenarios = [
      {
        name: "Patients with appointments",
        query: -> { 
          patients = Patient.limit(5).to_a
          patients.each { |p| p.appointments.count }
        },
        solution: "Use Patient.includes(:appointments)"
      },
      {
        name: "Employees with clockings",
        query: -> {
          employees = Employee.limit(5).to_a
          employees.each { |e| e.clockings.count }
        },
        solution: "Use Employee.includes(:clockings)"
      },
      {
        name: "Appointments with patient and employee",
        query: -> {
          appointments = Appointment.limit(5).to_a
          appointments.each { |a| [a.patient&.name, a.employee&.full_name] }
        },
        solution: "Use Appointment.includes(:patient, :employee)"
      }
    ]
    
    test_scenarios.each do |scenario|
      query_count_before = count_queries do
        # Run a single query to establish baseline
        scenario[:query]&.call rescue nil
      end
      
      query_count_after = count_queries do
        scenario[:query]&.call rescue nil
      end
      
      if query_count_after > 3 # Threshold for N+1 detection
        n_plus_one_detections << {
          scenario: scenario[:name],
          query_count: query_count_after,
          solution: scenario[:solution],
          severity: query_count_after > 10 ? :high : :medium
        }
      end
    end
    
    @optimization_results[:n_plus_one_detections] = n_plus_one_detections
  end

  def analyze_slow_queries
    Rails.logger.info "Analyzing slow queries..."
    
    slow_queries = []
    
    # Test potentially slow operations
    slow_query_tests = [
      {
        name: "Large patient search",
        query: -> { Patient.where("name ILIKE ?", "%田中%").limit(100) },
        expected_max_time: 500 # milliseconds
      },
      {
        name: "Complex payroll calculation",
        query: -> { 
          if Payroll.any?
            Payroll.joins(:employee)
                   .where(status: 'approved')
                   .group('employees.employment_type')
                   .sum(:gross_pay)
          end
        },
        expected_max_time: 1000
      },
      {
        name: "Appointment date range query",
        query: -> {
          Appointment.where(appointment_date: 1.month.ago..Date.current)
                    .includes(:patient, :employee)
                    .limit(50)
        },
        expected_max_time: 800
      }
    ]
    
    slow_query_tests.each do |test|
      start_time = Time.current
      begin
        result = test[:query].call
        duration_ms = (Time.current - start_time) * 1000
        
        if duration_ms > test[:expected_max_time]
          slow_queries << {
            name: test[:name],
            duration_ms: duration_ms.round(2),
            expected_max: test[:expected_max_time],
            severity: duration_ms > test[:expected_max_time] * 2 ? :high : :medium,
            recommendation: generate_query_recommendation(test[:name])
          }
        end
      rescue => e
        slow_queries << {
          name: test[:name],
          error: e.message,
          severity: :high,
          recommendation: "Fix query error: #{e.message}"
        }
      end
    end
    
    @optimization_results[:slow_queries] = slow_queries
  end

  def check_connection_pool
    Rails.logger.info "Checking connection pool status..."
    
    pool = ActiveRecord::Base.connection_pool
    
    connection_stats = {
      pool_size: pool.size,
      active_connections: pool.active_connection? ? 1 : 0,
      checked_out_connections: 0,
      available_connections: pool.size,
      pool_utilization: 0.0,
      status: :healthy
    }
    
    begin
      # Get connection pool statistics if available
      if pool.respond_to?(:stat)
        stats = pool.stat
        connection_stats.merge!(stats)
      end
      
      utilization = connection_stats[:checked_out_connections].to_f / connection_stats[:pool_size]
      connection_stats[:pool_utilization] = (utilization * 100).round(2)
      
      connection_stats[:status] = case utilization
                                 when 0..0.7 then :healthy
                                 when 0.7..0.9 then :warning
                                 else :critical
                                 end
      
    rescue => e
      Rails.logger.error "Error checking connection pool: #{e.message}"
      connection_stats[:status] = :error
      connection_stats[:error] = e.message
    end
    
    @optimization_results[:connection_pool_status] = connection_stats
  end

  def analyze_table_statistics
    Rails.logger.info "Analyzing table statistics..."
    
    table_stats = {}
    
    ActiveRecord::Base.connection.tables.each do |table_name|
      next if table_name == 'schema_migrations' || table_name == 'ar_internal_metadata'
      
      begin
        # Get basic table information
        stats = {
          row_count: 0,
          table_size: 'Unknown',
          index_count: 0,
          has_primary_key: true,
          has_timestamps: false
        }
        
        # Count rows (be careful with large tables)
        begin
          stats[:row_count] = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{table_name}").first['count'].to_i
        rescue => e
          stats[:row_count] = "Error: #{e.message}"
        end
        
        # Get column information
        columns = ActiveRecord::Base.connection.columns(table_name)
        column_names = columns.map(&:name)
        
        stats[:has_timestamps] = column_names.include?('created_at') && column_names.include?('updated_at')
        stats[:has_primary_key] = column_names.include?('id')
        
        # Get index information
        indexes = ActiveRecord::Base.connection.indexes(table_name)
        stats[:index_count] = indexes.length
        
        # Analyze potential issues
        issues = []
        issues << "Missing primary key" unless stats[:has_primary_key]
        issues << "Missing timestamps" unless stats[:has_timestamps]
        issues << "No indexes" if stats[:index_count] == 0
        issues << "High row count without indexes" if stats[:row_count].is_a?(Integer) && stats[:row_count] > 1000 && stats[:index_count] < 2
        
        stats[:issues] = issues
        stats[:health] = issues.empty? ? :good : :needs_attention
        
        table_stats[table_name] = stats
        
      rescue => e
        table_stats[table_name] = {
          error: e.message,
          health: :error
        }
      end
    end
    
    @optimization_results[:table_statistics] = table_stats
  end

  def generate_optimization_recommendations
    recommendations = []
    
    # Index recommendations
    @optimization_results[:index_recommendations].each do |rec|
      recommendations << {
        type: :index,
        priority: rec[:priority],
        description: "Add index on #{rec[:table]}.#{rec[:column]}",
        sql: "CREATE INDEX idx_#{rec[:table]}_#{rec[:column]} ON #{rec[:table]} (#{rec[:column]});",
        reason: rec[:reason]
      }
    end
    
    # N+1 query fixes
    @optimization_results[:n_plus_one_detections].each do |n_plus_one|
      recommendations << {
        type: :n_plus_one,
        priority: n_plus_one[:severity],
        description: "Fix N+1 query in #{n_plus_one[:scenario]}",
        solution: n_plus_one[:solution],
        queries_eliminated: n_plus_one[:query_count] - 1
      }
    end
    
    # Slow query optimizations
    @optimization_results[:slow_queries].each do |slow_query|
      recommendations << {
        type: :slow_query,
        priority: slow_query[:severity],
        description: "Optimize slow query: #{slow_query[:name]}",
        current_time: "#{slow_query[:duration_ms]}ms",
        target_time: "#{slow_query[:expected_max]}ms",
        recommendation: slow_query[:recommendation]
      }
    end
    
    # Connection pool recommendations
    pool_status = @optimization_results[:connection_pool_status]
    if pool_status[:status] == :warning
      recommendations << {
        type: :connection_pool,
        priority: :medium,
        description: "Connection pool utilization is high (#{pool_status[:pool_utilization]}%)",
        solution: "Consider increasing pool size or optimizing query efficiency"
      }
    elsif pool_status[:status] == :critical
      recommendations << {
        type: :connection_pool,
        priority: :high,
        description: "Connection pool is critically overutilized (#{pool_status[:pool_utilization]}%)",
        solution: "Immediately increase pool size and investigate connection leaks"
      }
    end
    
    @optimization_results[:optimization_recommendations] = recommendations
  end

  def calculate_performance_score
    score = 100
    
    # Deduct points for issues
    score -= @optimization_results[:index_recommendations].count { |r| r[:priority] == :high } * 10
    score -= @optimization_results[:index_recommendations].count { |r| r[:priority] == :medium } * 5
    
    score -= @optimization_results[:n_plus_one_detections].count { |n| n[:severity] == :high } * 15
    score -= @optimization_results[:n_plus_one_detections].count { |n| n[:severity] == :medium } * 8
    
    score -= @optimization_results[:slow_queries].count { |q| q[:severity] == :high } * 12
    score -= @optimization_results[:slow_queries].count { |q| q[:severity] == :medium } * 6
    
    case @optimization_results[:connection_pool_status][:status]
    when :critical
      score -= 20
    when :warning
      score -= 10
    end
    
    # Ensure score doesn't go below 0
    score = [score, 0].max
    
    @optimization_results[:performance_score] = score
    @optimization_results[:overall_health] = case score
                                           when 90..100 then :excellent
                                           when 80..89 then :good
                                           when 70..79 then :fair
                                           when 60..69 then :poor
                                           else :critical
                                           end
  end

  def count_queries
    query_count = 0
    
    original_logger = ActiveRecord::Base.logger
    counter_logger = Logger.new(StringIO.new)
    
    # Override logger to count queries
    ActiveRecord::Base.logger = counter_logger
    
    begin
      yield
      query_count = counter_logger.instance_variable_get(:@logdev).dev.string.scan(/SELECT|INSERT|UPDATE|DELETE/).length
    ensure
      ActiveRecord::Base.logger = original_logger
    end
    
    query_count
  end

  def generate_query_recommendation(query_name)
    case query_name.downcase
    when /patient search/
      "Add GIN index for full-text search or use dedicated search engine"
    when /payroll calculation/
      "Consider denormalizing frequently calculated fields"
    when /appointment.*range/
      "Add composite index on (appointment_date, status)"
    else
      "Analyze query execution plan and add appropriate indexes"
    end
  end

  # Class methods for easy access
  class << self
    def optimize
      instance.run_comprehensive_optimization
    end

    def quick_health_check
      optimizer = instance
      result = optimizer.run_comprehensive_optimization
      
      {
        overall_health: result[:overall_health],
        performance_score: result[:performance_score],
        critical_issues: result[:optimization_recommendations].count { |r| r[:priority] == :high },
        recommendations_count: result[:optimization_recommendations].length
      }
    end

    def generate_migration_for_indexes
      optimizer = instance
      result = optimizer.run_comprehensive_optimization
      
      migration_content = "class AddPerformanceIndexes < ActiveRecord::Migration[7.2]\n"
      migration_content += "  def change\n"
      
      result[:index_recommendations].each do |rec|
        migration_content += "    add_index :#{rec[:table]}, :#{rec[:column]} # #{rec[:reason]}\n"
      end
      
      migration_content += "  end\n"
      migration_content += "end\n"
      
      migration_content
    end
  end
end