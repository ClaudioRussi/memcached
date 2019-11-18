require 'socket'
require_relative './memcached'
require_relative './config'
require_relative './helpers/utils'
require_relative './helpers/output_messages'

# Class that contains the server
class MemcachedServer
  attr_accessor :port, :server

  def initialize(port)
    @port = port
  end

  def close
    @server.close
  end

  def start
    puts 'Starting server'
    @server = TCPServer.new @port
    @memcached = Memcached.new(Config::MAX_BYTES)
    Thread.new do
      loop do
        @memcached.delete_expired
        sleep(1)
      end
    end
    loop do
      Thread.start(server.accept) do |client|
        client.puts 'Connected'
        while (line = client.gets)
          line = Utils.parse_telnet_input(line)
          command = line.split ' '
          unless @memcached.valid_command(command)
            client.puts Output::ERROR
            next
          end
          if @memcached.needs_next_line(command)
            data = Utils.parse_telnet_input(client.gets)
          end
          client.puts @memcached.call_command(command, data)
        end
        client.close
      end
    end
  end
end
