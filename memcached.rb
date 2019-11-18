require 'date'
require_relative './value'
require_relative './memcached_storage'
require_relative './config'
require_relative './utils'
require_relative './output_messages'

# Main class, has all the logic related to memcached commands
class Memcached
  attr_reader :values

  VALID_COMMANDS = %i[add replace set prepend append cas get gets delete incr decr flush_all]
  ONE_LINE_COMMANDS = %i[get gets delete flush_all].freeze

  def initialize(max_bytes)
    @values = MemcachedStorage.new(max_bytes)
    # Mutex to prevent race conditions
    @semaphore = Mutex.new
  end

  # Adds an element if the key doesn't exists
  def add(key, value, flag, expiration_time, bytes)
    if @values.key? key
      @values.move_to_end(key)
      return Output::NOT_STORED
    end
    new_value = Value.new(value, flag, expiration_time, bytes)
    @values.set(key, new_value)
    Output::STORED
  end

  # Adds an element only if the key exists
  def replace(key, value, flag, expiration_time, bytes)
    return Output::NOT_STORED unless @values.key? key

    new_value = Value.new(value, flag, expiration_time, bytes)
    @values.set(key, new_value)
    Output::STORED
  end

  # Adds an element without checking if the key exists or not
  def set(key, value, flag, expiration_time, bytes)
    new_value = Value.new(value, flag, expiration_time, bytes)
    @values.set(key, new_value)
    Output::STORED
  end

  # Concatenates a value at the beginning of another value
  def prepend(key, value, flag, expiration_time, bytes)
    return Output::NOT_STORED unless @values.key? key

    new_value = Value.new(value + @values[key].value, flag, expiration_time, bytes)
    @values.set(key, new_value)
    Output::STORED
  end

  # Concatenates a value at the end of another value
  def append(key, value, flag, expiration_time, bytes)
    return Output::NOT_STORED unless @values.key? key

    new_value = Value.new(@values[key].value + value, flag, expiration_time, bytes)
    @values.set(key, new_value)
    Output::STORED
  end

  # Modifies a value if the cas key matches the cas key stored
  def cas(key, value, flag, expiration_time, bytes, cas)
    if @values.key? key
      case @values[key].cas
      when nil
        return Output::EXISTS
      when Integer(cas)
        new_value = Value.new(value, flag, expiration_time, bytes)
        @values.set(key, new_value)
        return Output::STORED
      else
        return Output::EXISTS
      end
    end
    Output::NOT_FOUND
  end

  # Returns a value given a key and generates a cas key
  def gets(key)
    return unless @values.key? key

    value = @values[key]
    value.cas = rand(Utils::FIXNUM_MAX)
    Output.value(value)
  end

  # Returns a value given a key
  def get(key)
    if @values.key? key
      value = @values[key]
      return Output.value(value)
    end
    key ? '' : Output::ERROR
  end

  # Deletes a value given a key
  def delete(key)
    if @values.key? key
      @values.delete(key)
      return Output::DELETED
    end
    Output::NOT_FOUND
  end

  # Increments a value if it is numeric
  def incr(key, increment)
    if @values.key? key
      old_value = Integer(@values[key].value, exception: false)
      if old_value
        new_value = (old_value + increment).to_s
        @values[key].value = new_value
        return new_value.to_s
      end
      return  Output::INCREMENT_ERROR
    end
    Output::NOT_FOUND
  end

  # Removes all expired values
  def delete_expired
    @values.each do |k, v|
      if v.value.expiration_date < DateTime.now && v.value.expiration_time.positive?
        @values.delete(k)
      end
    end
  end

  # Returns true if the command is valid, false otherwise
  def valid_command(command_params)
    command, = command_params
    VALID_COMMANDS.include?(command.to_sym)
  end

  # Returns true if the command requires a second line
  def needs_next_line(command_params)
    command, = command_params
    !ONE_LINE_COMMANDS.include?(command.to_sym)
  end

  def call_command(command_params, data=nil)
    command = command_params[0]
    case command.to_sym
    when :add
      _, key, flag, expiration, bytes, no_reply = command_params
      if are_valid_store_params command_params
        message = add(key, data, flag, expiration, bytes)
      end
      !no_reply && (message || Output.ERROR)
    when :set
      _, key, flag, expiration, bytes, no_reply = command_params
      if are_valid_store_params command_params
        message = set(key, data, flag, expiration, bytes)
      end
      !no_reply && (message || Output.ERROR)
    when :replace
      _, key, flag, expiration, bytes, no_reply = command_params
      if are_valid_store_params command_params
        message = replace(key, data, flag, expiration, bytes)
      end
      !no_reply && (message || Output.ERROR)
    when :append
      _, key, flag, expiration, bytes, no_reply = command_params
      if are_valid_store_params command_params
        message = append(key, data, flag, expiration, bytes)
      end
      !no_reply && (message || Output.ERROR)
    when :prepend
      _, key, flag, expiration, bytes, no_reply = command_params
      if are_valid_store_params command_params
        message = prepend(key, data, flag, expiration, bytes)
      end
      !no_reply && (message || Output.ERROR)
    when :cas
      _, key, flag, expiration, bytes, cas, no_reply = command_params
      if are_valid_store_params command_params
        message = cas(key, data, flag, expiration, bytes, cas)
      end
      !no_reply && (message || Output.ERROR)
    when :get
      _, key, no_reply = command_params
      message = get(key)
      return !no_reply && (message || Output.ERROR)
    when :gets
      _, key, no_reply = command_params
      message = gets(key)
      return !no_reply && (message || Output.ERROR)
    when :delete
      _, key, no_reply = command_params
      message = delete(key)
      return !no_reply && (message || Output.ERROR)
    when :incr
      _, _, value, no_reply = command_params
      unsigned = Utils.unsigned_number? value
      message = unsigned ? incr(Integer(value)) : Output.INCREMENT_ERROR
      return !no_reply && (message || Output.ERROR)
    when :decr
      _, _, value, no_reply = command_params
      unsigned = Utils.unsigned_number? value
      message = unsigned ? incr(-1 * Integer(value)) : Output.INCREMENT_ERROR
      return !no_reply && (message || Output.ERROR)
    when :flush_all
      return
    else
      print Output.NOT_SPECIFIED
    end
  end

  def are_valid_store_params(params)
    params.size >= 5 &&
      params[2..-2].all? { |param| Utils.unsigned_number?(param) }
  end
end
