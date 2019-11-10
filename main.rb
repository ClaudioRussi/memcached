require 'socket'
require_relative './memcached'
require_relative './config'
require_relative './utils'

#Class that contains the server
class MemcachedServer

  attr_accessor :port

  def initialize(port)
    @port = port
  end

  def start()
    server = TCPServer.new @port
    @memcached = Memcached.new(Config::MAX_BYTES)
    Thread.new do
      while true
        @memcached.delete_expired
        sleep(1)
      end
    end
    loop do
      Thread.start(server.accept) do |client|
        client.puts 'Connected'
        while line = client.gets
          line = Utils::parse_telnet_input(line)
          command = line.split ' '
          unless @memcached.is_valid_command(command)
            client.puts 'ERROR\r\n'
            next
          end
          if @memcached.needs_next_line(command)
            puts("yes")
            data = Utils::parse_telnet_input(client.gets)
          end
          client.puts @memcached.call_command(command, data)
        end
        client.close
      end
    end
  end
end
MemcachedServer.new(Config::SERVER_PORT).start()
