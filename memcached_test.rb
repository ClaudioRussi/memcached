require 'test/unit/assertions'
require_relative './memcached'
require 'minitest/autorun'
require_relative './config'

class MemcachedTest < Minitest::Test
  def setup
    @memcached = Memcached.new(Config::MAX_BYTES)
    @memcached.add('miKey', '1234', 1, 0, 5)
  end

  def test_adding_with_repeated_key_returns_not_stored
    values_size = @memcached.values.size
    message = @memcached.add('miKey', 'my value', 1, 0, 8)
    assert_equal 'NOT_STORED', message
    assert_equal values_size, @memcached.values.size
  end

  def test_adding_with_correct_params_returns_stored
    values_size = @memcached.values.size
    message = @memcached.add('miKey2', 'my value', 1, 0, 8)
    assert_equal 'STORED', message
    assert_equal (values_size + 1), @memcached.values.size
  end

  def test_relplacing_with_non_existing_key_returns_not_stored
    key = 'miKey3'
    message = @memcached.replace(key, 'my value 2', 1, 0, 8)
    assert_equal 'NOT_STORED', message
    assert !@memcached.values.key?(key)
  end

  def test_relplacing_with_existing_key_returns_stored
    key = 'miKey'
    value = 'my value 2'
    message = @memcached.replace(key, value, 1, 0, 8)
    assert_equal 'STORED', message
    assert_equal value, @memcached.values[key].value
  end

  def test_set_stores_the_value_when_key_exists
    key = 'miKey'
    value = 'my value 3'
    values_size = @memcached.values.size
    message = @memcached.set(key, value, 1, 0, 8)
    assert_equal 'STORED', message
    assert_equal value, @memcached.values[key].value
  end

  def test_set_stores_the_value_when_key_doesnt_exists
    key = 'miKey4'
    value = 'my value 4'
    values_size = @memcached.values.size
    message = @memcached.set(key, value, 1, 0, 8)
    assert_equal 'STORED', message
    assert_equal value, @memcached.values[key].value
  end

  def test_prepend_doesnt_work_when_key_doesnt_exists
    key = 'miKey5'
    value = 'my value 5'
    message = @memcached.prepend(key, value, 1, 0, 8)
    assert_equal 'NOT_STORED', message
  end

  def test_prepend_works_when_key_exists
    key = 'miKey'
    value = 'my value 5'
    old_value = @memcached.values[key].value
    message = @memcached.prepend(key, value, 1, 0, 8)
    assert_equal 'STORED', message
    assert_equal value+old_value, @memcached.values[key].value
  end

  def test_append_doesnt_work_when_key_doesnt_exists
    key = 'miKey5'
    value = 'my value 5'
    message = @memcached.append(key, value, 1, 0, 8)
    assert_equal 'NOT_STORED', message
  end

  def test_append_works_when_key_exists
    key = 'miKey'
    value = 'my value 5'
    old_value = @memcached.values[key].value
    message = @memcached.append(key, value, 1, 0, 8)
    assert_equal 'STORED', message
    assert_equal old_value + value, @memcached.values[key].value
  end

  def test_gets_returns_new_cas_value
    key = 'miKey'
    val = @memcached.values[key]
    expected_message = "VALUE #{val.value} #{val.flag} #{val.bytes} #{val.cas}"
    cas = val.cas
    message = @memcached.gets(key)
    assert message != expected_message
    assert cas != val.cas
  end

  def test_cas_swaps_when_cas_numbers_match
    key = 'miKey'
    value = 'my value 6'
    @memcached.gets(key)
    stored_val = @memcached.values[key]
    cas = stored_val.cas
    @message = @memcached.cas(key, value, 1, 0, 8, cas)
    assert_equal 'STORED', @message
    assert_equal value, @memcached.values[key].value
  end

  def test_cas_doesnt_swap_when_cas_numbers_dont_match
    key = 'miKey'
    @memcached.gets(key)
    stored_val = @memcached.values[key]
    old_value = stored_val.value
    cas = stored_val.cas + 5
    @message = @memcached.cas(key, 'my value 6', 1, 0, 8, cas)
    assert_equal 'EXISTS', @message
    assert_equal old_value, @memcached.values[key].value
  end

  def test_cas_doesnt_swap_when_key_doesnt_exists_match
    key = 'miKey6'
    @memcached.gets(key)
    cas = 10
    @message = @memcached.cas(key, 'my value 6', 1, 0, 8, cas)
    assert_equal 'NOT_FOUND', @message
  end

  def test_delete_removes_value_when_key_exists
    key = 'miKey'
    old_size = @memcached.values.size
    value_existed = @memcached.values.key? key
    @message = @memcached.delete(key)
    assert_equal 'DELETED', @message
    assert_equal old_size - 1, @memcached.values.size
    assert value_existed
    assert !(@memcached.values.key? key)
  end

  def test_delete_doesnt_remove_if_key_doesnt_exists
    key = 'asd'
    values_size = @memcached.values.size
    @message = @memcached.delete(key)
    assert_equal 'NOT_FOUND', @message
    assert_equal values_size, @memcached.values.size
  end

  def test_incr_increments_when_value_is_numeric
    key = 'miKey'
    increment = 5
    old_value = @memcached.values[key].value
    @message = @memcached.incr(key, increment)
    expected_value = (Integer(old_value) + increment).to_s
    assert_equal expected_value, @message
    assert_equal expected_value, @memcached.values[key].value
  end

  def test_incr_doesnt_increments_when_value_is_not_numeric
    expected_message = 'CLIENT_ERROR cannot increment or decrement non-numeric value'
    key = 'miKey7'
    old_value = 'my value 7'
    @memcached.add(key, old_value, 1, 0, 8)
    increment = 5
    @message = @memcached.incr(key, increment)
    assert_equal expected_message, @message
    assert_equal old_value, @memcached.values[key].value
  end

  def test_incr_doesnt_increments_when_key_doesnt_exists
    key = 'miKey8'
    old_value = 'my value 8'
    increment = 5
    @message = @memcached.incr(key, increment)
    assert_equal 'NOT_FOUND', @message
  end

  def test_delete_expired_removes_expired_key
    key = 'miKey9'
    old_value = 'my value 9'
    @memcached.add(key, old_value, 1, 1, 8)
    old_size = @memcached.values.size
    sleep(2)
    @memcached.delete_expired
    assert_equal old_size - 1, @memcached.values.size
    assert !(@memcached.values.key? key)
  end

  def test_delete_expired_doesnt_remove_when_key_isnt_expired
    key = 'miKey9'
    old_value = 'my value 9'
    @memcached.add(key, old_value, 1, 3, 8)
    old_size = @memcached.values.size
    sleep(1)
    @memcached.delete_expired
    assert_equal old_size, @memcached.values.size
  end

  def test_delete_expired_doesnt_remove_when_key_isnt_expired
    key = 'miKey9'
    old_value = 'my value 9'
    @memcached.add(key, old_value, 1, 3, 8)
    old_size = @memcached.values.size
    sleep(1)
    @memcached.delete_expired
    assert_equal old_size, @memcached.values.size
    assert @memcached.values.key? key
  end

  def test_delete_expired_doesnt_remove_when_expiration_time_is_0
    key = 'miKey10'
    old_value = 'my value 10'
    @memcached.add(key, old_value, 1, 0, 8)
    old_size = @memcached.values.size
    sleep(1)
    @memcached.delete_expired
    assert_equal old_size, @memcached.values.size
    assert @memcached.values.key? key
  end
end