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
          unless is_valid_command(command)
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
    command, key, flag, expiration, cas = command_params
    puts(command)
    return VALID_COMMANDS.include?(command) && is_unsigned_number(flag) && is_unsigned_number(expiration) && (!cas || is_unsigned_number(cas))
  end

  def is_unsigned_number(number)
    parsed_number = Integer(number, exception: false)
    return parsed_number && parsed_number >= 0
  end

  def call_command(command_params, data)
    command, key, flag, expiration, cas = command_params
    puts command
    case command
    when "add"
      return @memcached.add(key, data, flag, expiration, cas)
    else
      print "Command not specified"
    end
  end
end
MemcachedServer.new().main()
