require 'test/unit/assertions'
require 'minitest/autorun'
require_relative './config'
require_relative './memcached_storage'
require_relative './value'

class MemcachedTest < Minitest::Test
    def setup
        @storage = MemcachedStorage.new(30)
        @first_value = Value.new('Value', 5, 10, 6)
        @storage.set('my_key', @first_value)
    end

    def test_set_adds_a_value_when_given_correct_params
        value = Value.new("Value2", 5, 15, 7)
        key = "my_key2"
        old_size = @storage.size
        @storage.set(key, value)
        assert_equal old_size + 1, @storage.size
        assert_equal value, @storage.get(key)
    end

    def test_set_replaces_a_value_when_keys_match
        value = Value.new("Value2", 5, 15, 7)
        key = "my_key"
        old_size = @storage.size
        @storage.set(key, value)
        assert_equal old_size, @storage.size
        assert_equal value, @storage.get(key)
    end

    def test_set_replaces_last_value_if_is_full
        key = "my_key2"
        value = Value.new("Value2", 5, 15, 7)
        @storage.set("my_key3", Value.new("abcdefghijk", 5, 15, 10))
        @storage.set("my_key4", Value.new("abcdefghijk", 5, 15, 10))
        old_size = @storage.size
        @storage.set(key, value)
        assert_equal old_size, @storage.size
        assert @storage.key? key
        assert !(@storage.key? 'my_key')
        assert_equal value, @storage.get(key)
    end

    def test_set_replace_more_values_if_head_value_isnt_enough
        key = "my_key2"
        value = Value.new("Value2", 5, 15, 7)
        @storage.set("my_key3", Value.new("abcd", 5, 15, 4))
        @storage.set("my_key4", Value.new("abcdefghijk", 5, 15, 10))
        @storage.set("my_key5", Value.new("abcdefghijk", 5, 15, 10))
        old_size = @storage.size
        @storage.set(key, value)
        assert_equal old_size - 1, @storage.size
        assert @storage.key? key
        assert !(@storage.key? 'my_key')
        assert !(@storage.key? 'my_key3')
        assert_equal value, @storage.get(key)
    end

    def test_delete
        @storage.set("my_key2", Value.new("abcdefghijk", 5, 15, 10))
        @storage.set("my_key3", Value.new("abcdefghijk", 5, 15, 10))
        @storage.delete('my_key2')
        assert_equal(2, @storage.size)
        assert !(@storage.key? 'my_key2')
        @storage.delete('my_key3')
        assert_equal(1, @storage.size)
        assert !(@storage.key? 'my_key3')
        @storage.delete('my_key')
        assert_equal(0, @storage.size)
        assert !(@storage.key? 'my_key')
    end

    def test_get_used_bytes
        value = Value.new("Value2", 5, 15, 7)
        key = "my_key2"
        size = @storage.get_used_bytes
        assert_equal(6, size)
        @storage.set(key, value)
        size = @storage.get_used_bytes
        assert_equal(13, size)
        @storage.delete('my_key')
        size = @storage.get_used_bytes
        assert_equal(7, size)
    end

    def test_is_empty
        assert !(@storage.is_empty?)
        @storage.delete('my_key')
        assert (@storage.is_empty?)
    end

    def test_get
        value = Value.new("value", 1, 10, 5)
        @storage.set("key2", value)
        assert_equal(value, @storage.get("key2"))
        assert (!@storage.get("otherkey"))
    end

    def test_move_to_end
        second_value = Value.new("abcdefghijk", 5, 15, 10)
        third_value = Value.new("abcdefghijk", 5, 15, 10)
        @storage.set("my_key2", second_value)
        @storage.set("my_key3", third_value)
        @storage.move_to_end('my_key')
        assert_equal(@first_value, @storage.tail_node.value)
        assert_equal(second_value, @storage.head_node.value)
        @storage.move_to_end('my_key2')
        assert_equal(second_value, @storage.tail_node.value)
        assert_equal(third_value, @storage.head_node.value)
        @storage.move_to_end('my_key3')
        assert_equal(third_value, @storage.tail_node.value)
        assert_equal(@first_value, @storage.head_node.value)
    end

end