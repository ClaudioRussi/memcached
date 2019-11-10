#Represents a node on a linked list
class Node
    attr_accessor :key, :value, :next_node, :previous_node

    def initialize(key, value)
        @value = value
        @key = key
    end
    
end