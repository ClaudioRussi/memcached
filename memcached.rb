require 'date'
require_relative './value'

class Memcached

  def initialize
    @values = {}
    @semaphore = Mutex.new
  end

  def add(key, value, flag, expiration_time, bytes)
    if @values.key? key
      @semaphore.synchronize do
        @values[key].last_used = DateTime.now
      end
      return 'NOT_STORED'
    end
    @semaphore.synchronize do
      @values[key] = Value.new(value, Integer(flag), Integer(expiration_time), Integer(bytes))
    end
    return "STORED"
  end

  def replace(key, value, flag, expiration_time, bytes)
    unless @values.key? key
      return 'NOT_STORED'
    end
    @semaphore.synchronize do
      @values[key] = Value.new(value, Integer(flag), Integer(expiration_time), Integer(bytes))
    end
    return "STORED"
  end

  def set(key, value, flag, expiration_time, bytes)
    @semaphore.synchronize do
      @values[key] = Value.new(value, Integer(flag), Integer(expiration_time), Integer(bytes))
    end
    return "STORED"
  end

  def prepend(key, value, flag, expiration_time, bytes)
    unless @values.key? key
      return "NOT_STORED"
    end
    @semaphore.synchronize do
      @values[key].value = value << @values[key].value
      @values[key].flag = Integer(flag)
      @values[key].expiration_time = Integer(expiration_time)
    end
    return "STORED"
  end

  def append(key, value, flag, expiration_time, bytes)
    unless @values.key? key
      return "NOT_STORED"
    end
    @semaphore.synchronize do
      @values[key].value << value
      @values[key].flag = Integer(flag)
      @values[key].expiration_time = Integer(expiration_time)
    end
    return "STORED"
  end

  def cas(key, value, flag, expiration_time, bytes, cas)
    case @values[key].cas
      when nil
        return "NOT_FOUND"
      when cas
        @semaphore.synchronize do
          @values[key] = Value.new(value, Integer(flag), Integer(expiration_time), Integer(bytes))
        end
        return "STORED"
      else
        return "EXISTS"
      end
  end


  def gets(key, value, flag, expiration_time)

  end

  def get(key)
    if @values.key? key
      return "VALUE #{@values[key].value} #{@values[key].flag} #{@values[key].bytes}" 
  end

end