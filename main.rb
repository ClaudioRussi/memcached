require 'socket'
require_relative './memcached'

VALID_COMMANDS = [:add, :replace, :set, :prepend, :append, :cas, :get, :gets, :delete, :incr, :decr, :flush_all]
ONE_LINE_COMMANDS = [:get, :gets, :delete, :flush_all]

class MemcachedServer

  attr_accessor :port

  def initialize(port)
    @port = port
  end

  def start()
    server = TCPServer.new @port
    @memcached = Memcached.new
    Thread.new do
      while true
        @memcached.delete_expired
        sleep(1)
      end
    end
    loop do
      Thread.start(server.accept) do |client|
        client.puts "Connected"
        while line = client.gets
          line = line.chomp.gsub(/[^[:print:]]/i, '')
          command = line.split ' '
          unless is_valid_command(command)
            client.puts "ERROR\r\n"
            next
          end
          if needs_next_line(command)
            data = client.gets.chomp.gsub(/[^[:print:]]/i, '')
          end
          client.puts call_command(command, data)
        end
        client.close
      end
    end
  end

  protected

  def is_valid_command(command_params)
    command, = command_params
    print(command)
    return VALID_COMMANDS.include?(command.to_sym)
  end

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
        message = @memcached.get(key)
        return !no_reply && (message || "Error")
      when :gets
        _, key, no_reply = command_params
        message = @memcached.gets(key)
        return !no_reply && (message || "Error")
      when :delete
        _, key, no_reply = command_params
        message = @memcached.delete(key)
        return !no_reply && (message || "Error")
      when :incr
        _, key, value, no_reply = command_params
        if(is_unsigned_number value)
          message = @memcached.incr(Integer(value))
        else
          message = "CLIENT_ERROR cannot increment or decrement non-numeric value"
        end
        return !no_reply && (message || "Error")
      when :decr
        _, key, value, no_reply = command_params
        if(is_unsigned_number value)
          message = @memcached.incr(-1 * Integer(value))
        else
          message = "CLIENT_ERROR cannot increment or decrement non-numeric value"
        end
        return !no_reply && (message || "Error")
      when :flush_all
        return
      else
        print "Command not specified"
      end
  end

  def call_store_command(method, command_params, data, cas=false)
    if(are_valid_store_params(command_params))
      if cas
        command, key, flag, expiration, bytes, cas, no_reply = command_params
        message = @memcached.send(method, key, data, flag, expiration, bytes, cas)
      else
        command, key, flag, expiration, bytes, no_reply = command_params
        message = @memcached.send(method, key, data, flag, expiration, bytes)
      end
    end
    return !no_reply && (message || "Error")
  end

  def are_valid_store_params(params)
    return params[2..-2].all? {|param| is_unsigned_number(param)}
  end

  def is_unsigned_number(number)
    parsed_number = Integer(number, exception: false)
    return parsed_number && parsed_number >= 0
  end
end
MemcachedServer.new(23).start()
