class Redis
  def self.current
    @current ||= new
  end

  def sadd(*args)
    true
  end

  def expire(*args)
    true
  end

  def get(*args)
    nil
  end
end