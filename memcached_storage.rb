require_relative './memcached'
require_relative './node'

#Uses a hash in order to get O(1) in searchs with the key, and a linked list in order to use lru when it has no space left
class MemcachedStorage 
    attr_reader :head_node, :tail_node, :hashed_storage, :max_bytes

    def initialize(max_bytes)
        @max_bytes = max_bytes
        hashed_storage = Memcached.new()
    end

    def set(key, value)
        node = Node.new(value)
        if(value.bytes + get_used_bytes() > @max_bytes)
            @head_value = @head_value.previous_node
            @head_value.next_node = nil
        end
        node.next_node = @tail_value
        @tail_value = node
        @hashed_storage[key] = node
    end

    def get_used_bytes
        actual_node = @tail_node
        size = 0
        while tail_node != @head_node
            size += actual_node.value.bytes
            actual_node = actual_node.next_node
        end
        return size
    end

    def get(key)
        return @hashed_storage[key]
    end

    def key?(key)
        return @hashed_storage.key? key
    end

    def [](key)
        return @hashed_storage[key].value
    end

    def []=(key, value)
        set(key, value)
    end
end