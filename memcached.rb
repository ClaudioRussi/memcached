require 'date'
require_relative './value'

class Memcached

    FIXNUM_MAX = (2**(0.size * 8 -2) -1)

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
    if @values.key? key
        @values[key].cas = rand(FIXNUM_MAX)
        return "VALUE #{@values[key].value} #{@values[key].flag} #{@values[key].bytes} #{@values[key].cas}" 
      end
  end

  def get(key)
    if @values.key? key
      return "VALUE #{@values[key].value} #{@values[key].flag} #{@values[key].bytes}" 
    end
  end

  def delete(key)

  end

  def incr(key, value)

  end

  def decr(key, value)

  end

  def flush_all(time)

  end

end