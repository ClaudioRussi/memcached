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
                @values[key].last_fetched = DateTime.now
            end
            return 'Error'
        end
        @semaphore.synchronize do
            @values[key] = Value.new(value, Integer(flag), Integer(expiration_time), Integer(cas, exception: false))
        end
        print @values
    end

    def replace(key, value)
    end

    def set

    end

    def prepend

    end

    def append

    end

    def cas

    end

    def gets

    end

end