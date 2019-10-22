require 'date'

class Memcached

    def initialize
        @values = {}
        @semaphore = Mutex.new
    end

    def add(key, value)
        if values[key]
            @semaphore.synchronize do
                values[key].last_fetched = DateTime.now
            end
            return 'Error'
        end
        @semaphore.synchronize do
            values[key] = values
        end
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