require_relative './memcached'
require_relative './node'

#Uses a hash in order to get O(1) in searchs with the key, and a linked list in order to use lru when it has no space left
class MemcachedStorage 
  attr_reader :head_node, :tail_node, :hashed_storage, :max_bytes

  def initialize(max_bytes)
    @semaphore = Mutex.new
    @max_bytes = max_bytes
    @hashed_storage = {}
  end
  
  #Sets a value and key pair in the hash, and stores an entry at the end of the linked list 
  def set(key, value)
    node = Node.new(key, value)

    if value.bytes > @max_bytes
      return false
    elsif is_empty?
      @semaphore.synchronize do
        @head_node = node
        @tail_node = node
        @hashed_storage[key] = node
        return node
      end
    end
    while value.bytes + get_used_bytes() > @max_bytes do
      @semaphore.synchronize do
        @hashed_storage.delete(@head_node.key)
        @head_node = @head_node.previous_node
        if @head_node 
          @head_node.next_node = nil
        end
      end
    end
    @semaphore.synchronize do
      node.next_node = @tail_node
      @tail_node.previous_node = node
      @tail_node = node
      @hashed_storage[key] = node
    end
    return value
  end

  def is_empty?
    @semaphore.synchronize do 
      return @hashed_storage.empty?
    end
  end

  #Returns the amount of bytes stored
  def get_used_bytes
    size = 0
    unless is_empty?
      @semaphore.synchronize do
        actual_node = @tail_node
        while actual_node != nil do
          size += actual_node.value.bytes
          actual_node = actual_node.next_node
        end
      end
    end
    return size
  end

  #Returns a key if exists
  def get(key)
    @semaphore.synchronize do
      return @hashed_storage[key] && @hashed_storage[key].value
    end
  end

  #Returns wheter a key is stored or not
  def key?(key)
    @semaphore.synchronize do
      return @hashed_storage.key? key
    end
    return false
  end

  #Method to get a value given a key
  def [](key)
    @semaphore.synchronize do
      return @hashed_storage[key] && @hashed_storage[key].value
    end
  end

  #Method to store a value given a key
  def []=(key, value)
    set(key, value)
  end

  #Retuns how many values are stored
  def size
    @semaphore.synchronize do
      return @hashed_storage.size
    end
  end

  #Iterates over all key, value pair
  def each(&block)
    @hashed_storage.each(&block)
  end

  #Removes a key, value pair if exists
  def delete(key)
    if key? key
      @semaphore.synchronize do
        node = @hashed_storage[key]
        if node == @head_node
          @head_node = node.previous_node
        end
        if node == @tail_node
          @tail_node = node.next_node
        end
        if node.previous_node
          node.previous_node.next_node = node.next_node
        end
        if node.next_node
          node.next_node.previous_node = node.previous_node
        end
        @hashed_storage.delete(key)
      end
    end
  end

  #Moves the value to the end of the linked list
  def move_to_end(key)
    if key? key
      @semaphore.synchronize do
        node = @hashed_storage[key]
        if(@head_node == node)
          @head_node = node.previous_node
        end
        if node.previous_node
          node.previous_node.next_node = node.next_node
        end
        if node.next_node
          node.next_node.previous_node = node.previous_node
        end
        node.previous_node = nil
        node.next_node = @tail_node
        @tail_node.previous_node = node
        @tail_node = node
      end
    end
  end
end