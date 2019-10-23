require 'date'
require_relative './value'

class Memcached

    def initialize
        @values = {}
        @semaphore = Mutex.new
    end

    def add(key, value, flag, expiration_time, cas=nil)
        if @values.key? key
            @semaphore.synchronize do
                @values[key].last_used = DateTime.now
            end
            return 'Error'
        end
        @semaphore.synchronize do
            @values[key] = Value.new(value, Integer(flag), Integer(expiration_time), Integer(cas, exception: false))
        end
        print @values
    end

    def replace(key, value, flag, expiration_time, cas=nil)
        unless @values.key? key
            return 'Error'
        end
        @semaphore.synchronize do
            @values[key] = Value.new(value, Integer(flag), Integer(expiration_time), Integer(cas, exception: false))
        end
    end

    def set(key, value, flag, expiration_time, cas=nil)
        @semaphore.synchronize do
            @values[key] = = Value.new(value, Integer(flag), Integer(expiration_time), Integer(cas, exception: false))
        end
    end

    def prepend(key, value, flag, expiration_time, cas=nil)

    end

    def append(key, value, flag, expiration_time, cas=nil)

    end

    def cas(key, value, flag, expiration_time, cas=nil)

    end

    def gets(key, value, flag, expiration_time, cas=nil)

    end

end