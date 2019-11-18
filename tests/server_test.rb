require 'socket'
require 'minitest/autorun'
require 'test/unit/assertions'
require_relative '../memcached_server'
require_relative '../config'

# Test for the server
class ServerTest < Minitest::Test
  def setup
    @server = MemcachedServer.new(Config::SERVER_PORT)
    @thread = Thread.new do
      begin
        @server.start
      rescue IOError
        'Avoids exceptions on tests'
      end
    end
    @hostname = 'localhost'
    sleep(1)
  end

  def test_10_users_can_store_values
    threads = []
    10.times do |i|
      threads << Thread.new do 
        s = TCPSocket.open(@hostname, Config::SERVER_PORT)
        s.gets
        res = set_value(s, i, 0, 0, i.to_s.size, i)
        s.close
        assert_equal("STORED\n", res.encode('UTF-8'))
      end
    end
    threads.each(&:join)
    10.times do |i|
      threads << Thread.new do
        s = TCPSocket.open(@hostname, Config::SERVER_PORT)
        s.gets
        res = get_value(s, i)
        s.close
        expected = "VALUE #{i} 0 #{i.to_s.size} \n"
        # Test that all values are stored
        assert_equal(expected, res.encode('UTF-8'))
      end
    end
    threads.each(&:join)
  end

  def test_10_users_can_replace_the_same_value
    threads = []
    semaphore = Mutex.new
    last_value = nil
    10.times do |i|
      threads << Thread.new do 
        s = TCPSocket.open(@hostname, Config::SERVER_PORT)
        s.gets
        res = set_value(s, 1, 0, 0, i.to_s.size, i)
        s.close
        assert_equal("STORED\n", res.encode('UTF-8'))
        semaphore.synchronize do
          last_value = i
        end
      end
    end
    threads.each(&:join)
    s = TCPSocket.open(@hostname, Config::SERVER_PORT)
    s.gets
    res = get_value(s, 1)
    expected = "VALUE #{last_value} 0 1 \n"
    assert_equal(expected, res.encode('UTF-8'))
  end

  def set_value(socket, key, flags, time, bytes, value)
    socket.puts("set #{key} #{flags} #{time} #{bytes}")
    socket.puts(value)
    socket.gets
  end

  def get_value(socket, key)
    socket.puts("get #{key}")
    socket.gets
  end

  def teardown
    @server.close
    @thread.kill
  end
end
