#Represents a node for a linked list
class Node
    attr_accessor :value, :next_node, :previous_node

    def initialize(value)
        @value = value
    end
end