require_relative './memcached_server'
def main()
  MemcachedServer.new(Config::SERVER_PORT).start()
end
main()
