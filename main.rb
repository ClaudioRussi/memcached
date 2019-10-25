require 'socket'
require_relative './memcached'

VALID_COMMANDS = ['add', 'replace', 'set', 'prepend', 'append', 'cas', 'gets']

class MemcachedServer
  def main()
    server = TCPServer.new 23
    @memcached = Memcached.new
    loop do
      Thread.start(server.accept) do |client|
        client.puts "Connected"
        while line = client.gets
          line = line.chomp.gsub(/[^[:print:]]/i, '')
          command = line.split ' '
          unless is_valid_command()
            client.puts "ERROR\r\n"
            next
          end
          data = client.gets.chomp.gsub(/[^[:print:]]/i, '')
          call_command(command, data)
        end
        client.close
      end
    end
  end

  protected

  def is_valid_command(command_params)
    command, = command_params
    return VALID_COMMANDS.include?(command)
  end

  def is_unsigned_number(number)
    parsed_number = Integer(number, exception: false)
    return parsed_number && parsed_number >= 0
  end

  def are_valid_store_params(params)
    return params[2..-2].all? {|param| is_unsigned_number(param)}
  end

  def call_command(command_params, data)
    command = command_params[0]
    case command
      when "add"
        command, key, flag, expiration, bytes, no_reply = command_params
        if(are_valid_store_params(command_params))
          message = @memcached.add(key, data, flag, expiration, cas)
        end
        return no_reply && (message || "Error")
      when "set"
        command, key, flag, expiration, bytes, no_reply = command_params
        if(are_valid_store_params(command_params))
          message = @memcached.set(key, data, flag, expiration, bytes)
        end
        return no_reply && (message || "Error")
      when "replace"
        command, key, flag, expiration, bytes, no_reply = command_params
        if(are_valid_store_params(command_params))
          message = @memcached.replace(key, data, flag, expiration, bytes)
        end
        return no_reply && (message || "Error")
      when "append"
        command, key, flag, expiration, bytes, no_reply = command_params
        if(are_valid_store_params(command_params))
          message = @memcached.append(key, data, flag, expiration, bytes)
        end
        return no_reply && (message || "Error")
      when "prepend"
        command, key, flag, expiration, bytes, no_reply = command_params
        if(are_valid_store_params(command_params))
          message = @memcached.prepend(key, data, flag, expiration, bytes)
        end
        return no_reply && (message || "Error")
      when "cas"
        command, key, flag, expiration, bytes, cas, no_reply = command_params
        if(are_valid_store_params(command_params))
          message = @memcached.cas(key, data, flag, expiration, bytes, cas)
        end
        return no_reply && (message || "Error")
      else
        print "Command not specified"
      end
  end
end
MemcachedServer.new().main()
