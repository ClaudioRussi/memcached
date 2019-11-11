require 'date'
require_relative './value'
require_relative './memcached_storage'
require_relative './config'
require_relative './utils'

#Main class, has all the logic related to memcached commands
class Memcached
    attr_reader :values

  VALID_COMMANDS = [:add, :replace, :set, :prepend, :append, :cas, :get, :gets, :delete, :incr, :decr, :flush_all]
  ONE_LINE_COMMANDS = [:get, :gets, :delete, :flush_all]

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
    return 'STORED'
  end

  #Adds an element only if the key exists
  def replace(key, value, flag, expiration_time, bytes)
    unless @values.key? key
      return 'NOT_STORED'
    end
    new_value = Value.new(value, Integer(flag), Integer(expiration_time), Integer(bytes))
    @values.set(key, new_value)
    return 'STORED'
  end

  #Adds an element without checking if the key exists or not
  def set(key, value, flag, expiration_time, bytes)
    new_value = Value.new(value, Integer(flag), Integer(expiration_time), Integer(bytes))
    @values.set(key, new_value)
    return 'STORED'
  end

  #Concatenates a value at the beginning of another value
  def prepend(key, value, flag, expiration_time, bytes)
    unless @values.key? key
      return 'NOT_STORED'
    end
    new_value = Value.new(value + @values[key].value, Integer(flag), Integer(expiration_time), Integer(bytes))
    @values.set(key, new_value)
    return 'STORED'
  end

  #Concatenates a value at the end of another value
  def append(key, value, flag, expiration_time, bytes)
    unless @values.key? key
      return 'NOT_STORED'
    end
    new_value = Value.new(@values[key].value + value, Integer(flag), Integer(expiration_time), Integer(bytes))
    @values.set(key, new_value)
    return 'STORED'
  end

  #Modifies a value if the cas key matches the cas key stored
  def cas(key, value, flag, expiration_time, bytes, cas)
    if @values.key? key
      case @values[key].cas
        when nil
          return 'EXISTS'
        when Integer(cas)
          new_value = Value.new(value, Integer(flag), Integer(expiration_time), Integer(bytes))
          @values.set(key, new_value)
          return 'STORED'
        else
          return 'EXISTS'
        end
    end
    return 'NOT_FOUND'
  end

  #Returns a value given a key and generates a cas key
  def gets(key)
    if @values.key? key
      value = @values[key]
      value.cas = rand(Utils::FIXNUM_MAX)
      return "VALUE #{value.value} #{value.flag} #{value.bytes} #{value.cas}" 
    end
  end

  #Returns a value given a key
  def get(key)
    if @values.key? key
      value = @values[key]
      return "VALUE #{value.value} #{value.flag} #{value.bytes}" 
    end
    return key ? '' : 'Error' 
  end

  #Deletes a value given a key
  def delete(key)
    if @values.key? key
      @values.delete(key)
      return 'DELETED'
    end
    return 'NOT_FOUND'
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
      return 'CLIENT_ERROR cannot increment or decrement non-numeric value'
    end
    return 'NOT_FOUND'
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
    return VALID_COMMANDS.include?(command.to_sym)
  end

  #Returns true if the command requires a second line
  def needs_next_line(command_params)
    command, = command_params
    return !ONE_LINE_COMMANDS.include?(command.to_sym)
  end

  def call_command(command_params, data=nil)
    command = command_params[0]
    case command.to_sym
      when :add
        return(call_store_command(:add, command_params, data))
      when :set
        return(call_store_command(:set, command_params, data))
      when :replace
        return(call_store_command(:replace, command_params, data))
      when :append
        return(call_store_command(:append, command_params, data))
      when :prepend
        return(call_store_command(:prepend, command_params, data))
      when :cas
        return(call_store_command(:cas, command_params, data, true))
      when :get
        _, key, no_reply = command_params
        message = get(key)
        return !no_reply && (message || 'Error')
      when :gets
        _, key, no_reply = command_params
        message = gets(key)
        return !no_reply && (message || 'Error')
      when :delete
        _, key, no_reply = command_params
        message = delete(key)
        return !no_reply && (message || 'Error')
      when :incr
        _, key, value, no_reply = command_params
        if(Utils::is_unsigned_number value)
          message = incr(Integer(value))
        else
          message = 'CLIENT_ERROR cannot increment or decrement non-numeric value'
        end
        return !no_reply && (message || 'Error')
      when :decr
        _, key, value, no_reply = command_params
        if(Utils::is_unsigned_number value)
          message = incr(-1 * Integer(value))
        else
          message = 'CLIENT_ERROR cannot increment or decrement non-numeric value'
        end
        return !no_reply && (message || 'Error')
      when :flush_all
        return
      else
        print 'Command not specified'
      end
  end

  def call_store_command(method, command_params, data, cas=false)
    if(are_valid_store_params(command_params))
      if cas
        command, key, flag, expiration, bytes, cas, no_reply = command_params
        message = send(method, key, data, flag, expiration, bytes, cas)
      else
        command, key, flag, expiration, bytes, no_reply = command_params
        message = send(method, key, data, flag, expiration, bytes)
      end
    end
    return !no_reply && (message || 'Error')
  end

  def are_valid_store_params(params)
    return params.size >= 5 && params[2..-2].all? {|param| Utils::is_unsigned_number(param)}
  end
end