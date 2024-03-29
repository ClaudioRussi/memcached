require_relative './memcached'
require_relative './node'

# Uses a hash in order to get O(1) in searchs with the key,
# and a linked list in order to use lru when it has no space left
class MemcachedStorage 
  attr_reader :head_node, :tail_node, :hashed_storage, :max_bytes

  def initialize(max_bytes)
    @semaphore = Mutex.new
    @max_bytes = max_bytes
    @hashed_storage = {}
  end

  # Sets a value and key pair in the hash,
  # and stores an entry at the end of the linked list
  def set(key, value)
    @semaphore.synchronize do
      node = Node.new(key, value)
      return false if value.value.length > @max_bytes

      if empty?
        @head_node = node
        @tail_node = node
        @hashed_storage[key] = node
        return node
      end
      while value.value.length + used_bytes > @max_bytes
        @hashed_storage.delete(@head_node.key)
        @head_node = @head_node.previous_node
        @head_node.next_node = nil if @head_node 
      end
      node.next_node = @tail_node
      @tail_node.previous_node = node
      @tail_node = node
      @hashed_storage[key] = node
    end
    value
  end

  def empty?
    @hashed_storage.empty?
  end

  # Returns the amount of bytes stored
  def used_bytes
    size = 0
    unless empty?
      actual_node = @tail_node
      while actual_node != nil do
        size += actual_node.value.value.length
        actual_node = actual_node.next_node
      end
    end
    size
  end

  # Returns a key if exists
  def get(key)
    @semaphore.synchronize do
      return @hashed_storage[key]&.value
    end
  end

  # Returns wheter a key is stored or not
  def key?(key)
    @semaphore.synchronize do
      return @hashed_storage.key? key
    end
  end

  def delete_expired
    expired_keys = []
    @semaphore.synchronize do
      @hashed_storage.each do |k, v|
        expired = v.value.expiration_date < DateTime.now &&
                  v.value.expiration_time.to_i.positive?
        expired_keys << k if expired
      end
    end
    expired_keys.each do |key|
      delete(key)
    end
  end

  # Retuns how many values are stored
  def size
    @semaphore.synchronize do
      return @hashed_storage.size
    end
  end

  # Removes a key, value pair if exists
  def delete(key)
    return unless key? key

    @semaphore.synchronize do
      node = @hashed_storage[key]
      @head_node = node.previous_node if node == @head_node
      @tail_node = node.next_node if node == @tail_node
      node.previous_node.next_node = node.next_node if node.previous_node
      node.next_node.previous_node = node.previous_node if node.next_node
      @hashed_storage.delete(key)
    end
  end

  # Moves the value to the end of the linked list
  def move_to_end(key)
    return unless key? key

    @semaphore.synchronize do
      node = @hashed_storage[key]
      @head_node = node.previous_node if @head_node == node
      node.previous_node.next_node = node.next_node if node.previous_node
      node.next_node.previous_node = node.previous_node if node.next_node
      node.previous_node = nil
      node.next_node = @tail_node
      @tail_node.previous_node = node
      @tail_node = node
    end
  end
end
