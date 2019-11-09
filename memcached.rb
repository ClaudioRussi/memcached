require 'date'
require_relative './value'
require_relative './memcached_storage'
require_relative './config'

class Memcached
    attr_reader :values

  def initialize(max_bytes)
    @values = MemcachedStorage.new(max_bytes)
    #Mutex to prevent race conditions
    @semaphore = Mutex.new
  end

  #Adds an element if the key doesn't exists
  def add(key, value, flag, expiration_time, bytes)
    if @values.key? key
        @values.move_to_end(key)
        return 'NOT_STORED'
    end
    new_value = Value.new(value, Integer(flag), Integer(expiration_time), Integer(bytes))
    @values.set(key, new_value)
    return "STORED"
  end

  #Adds an element only if the key exists
  def replace(key, value, flag, expiration_time, bytes)
    unless @values.key? key
      return 'NOT_STORED'
    end
    new_value = Value.new(value, Integer(flag), Integer(expiration_time), Integer(bytes))
    @values.set(key, new_value)
    return "STORED"
  end

  #Adds an element without checking if the key exists or not
  def set(key, value, flag, expiration_time, bytes)
    new_value = Value.new(value, Integer(flag), Integer(expiration_time), Integer(bytes))
    @values.set(key, new_value)
    return "STORED"
  end

  #Concatenates a value at the beginning of another value
  def prepend(key, value, flag, expiration_time, bytes)
    unless @values.key? key
      return "NOT_STORED"
    end
    new_value = Value.new(value + @values[key].value, Integer(flag), Integer(expiration_time), Integer(bytes))
    @values.set(key, new_value)
    return "STORED"
  end

  #Concatenates a value at the end of another value
  def append(key, value, flag, expiration_time, bytes)
    unless @values.key? key
      return "NOT_STORED"
    end
    new_value = Value.new(@values[key].value + value, Integer(flag), Integer(expiration_time), Integer(bytes))
    @values.set(key, new_value)
    return "STORED"
  end

  #Modifies a value if the cas key matches the cas key stored
  def cas(key, value, flag, expiration_time, bytes, cas)
    if @values.key? key
      case @values[key].cas
        when nil
          return "EXISTS"
        when Integer(cas)
          new_value = Value.new(value, Integer(flag), Integer(expiration_time), Integer(bytes))
          @values.set(key, new_value)
          return "STORED"
        else
          return "EXISTS"
        end
    end
    return "NOT_FOUND"
  end

  #Returns a value given a key and generates a cas key
  def gets(key)
    if @values.key? key
      value = @values[key]
      value.cas = rand(Config::FIXNUM_MAX)
      return "VALUE #{value.value} #{value.flag} #{value.bytes} #{value.cas}" 
    end
  end

  #Returns a value given a key
  def get(key)
    if @values.key? key
      value = @values[key]
      return "VALUE #{value.value} #{value.flag} #{value.bytes}" 
    end
    return ""
  end

  #Deletes a value given a key
  def delete(key)
    if @values.key? key
      @values.delete(key)
      return "DELETED"
    end
    return "NOT_FOUND"
  end

  #Increments a value if it is numeric
  def incr(key, increment)
    if @values.key? key
      old_value = Integer(@values[key].value, exception: false)
      if (old_value)
        new_value = "#{old_value + increment}"
        @values[key].value = new_value
        return new_value.to_s
      end
      return "CLIENT_ERROR cannot increment or decrement non-numeric value"
    end
    return "NOT_FOUND"
  end

  #Removes all expired values
  def delete_expired
    @values.each do |k, v| 
      if v.value.get_expiration_date < DateTime.now && v.value.expiration_time > 0
        @values.delete(k)
      end
    end
  end

  #Returns true if the command is valid, false otherwise
  def is_valid_command(command_params)
    command, = command_params
    print(command)
    return Config::VALID_COMMANDS.include?(command.to_sym)
  end

  #Returns true if the command requires a second line
  def needs_next_line(command_params)
    command, = command_params
    return !Config::ONE_LINE_COMMANDS.include?(command.to_sym)
  end
end