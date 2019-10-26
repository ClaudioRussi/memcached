require 'date'
require_relative './value'

class Memcached

    FIXNUM_MAX = (2**(0.size * 8 -2) -1)

  def initialize
    @values = {}
    @semaphore = Mutex.new
  end

  def add(key, value, flag, expiration_time, bytes)
    @semaphore.synchronize do
      if @values.key? key
          @values[key].last_used = DateTime.now
        return 'NOT_STORED'
      end
      @values[key] = Value.new(value, Integer(flag), Integer(expiration_time), Integer(bytes))
    end
    return "STORED"
  end

  def replace(key, value, flag, expiration_time, bytes)
    @semaphore.synchronize do
      unless @values.key? key
        return 'NOT_STORED'
      end
    
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
    @semaphore.synchronize do
      unless @values.key? key
        return "NOT_STORED"
      end
      @values[key] = Value.new(value + @values[key].value, Integer(flag), Integer(expiration_time), Integer(bytes))
    end
    return "STORED"
  end

  def append(key, value, flag, expiration_time, bytes)
    @semaphore.synchronize do
      unless @values.key? key
        return "NOT_STORED"
      end
      @values[key] = Value.new(@values[key].value + value, Integer(flag), Integer(expiration_time), Integer(bytes))
    end
    return "STORED"
  end

  def cas(key, value, flag, expiration_time, bytes, cas)
    @semaphore.synchronize do
      case @values[key].cas
        when nil
          return "NOT_FOUND"
        when cas
            @values[key] = Value.new(value, Integer(flag), Integer(expiration_time), Integer(bytes))
          return "STORED"
        else
          return "EXISTS"
        end
    end
  end

  def gets(key, value, flag, expiration_time)
    @semaphore.synchronize do
      if @values.key? key
        @values[key].cas = rand(FIXNUM_MAX)
        return "VALUE #{@values[key].value} #{@values[key].flag} #{@values[key].bytes} #{@values[key].cas}" 
      end
   end
  end

  def get(key)
    @semaphore.synchronize do
      if @values.key? key
        return "VALUE #{@values[key].value} #{@values[key].flag} #{@values[key].bytes}" 
      end
    end
  end

  def delete(key)
    @semaphore.synchronize do
      if @values.key? key
        @values.delete(key)
        return "DELETED"
      end
    end
    return "NOT FOUND"
  end

  def incr(key, increment)
    @semaphore.synchronize do
      if @values.key? key
        old_value = Integer(@values[key], exception: false)
        if (old_value)
          new_value = "#{val + increment}"
          @values[key].value = new_value
          return new_value
        end
        return "CLIENT_ERROR cannot increment or decrement non-numeric value"
      end
    end
    return "NOT FOUND"
  end

  def delete_expired
    @semaphore.synchronize do
      @values.each do |k, v| 
        if Date.(v.get_expiration_date).past?
          @values.delete(k)
        end
      end
    end
  end

end