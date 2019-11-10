require 'test/unit/assertions'
require_relative './value'
require 'minitest/autorun'

class ValueTest < Minitest::Test

    def test_get_expiration_date
        expiration_time = 100
        val = Value.new("value", 1, expiration_time, 10)
        stored_at = DateTime.now
        
        expected = "#{stored_at.year}-#{stored_at.month}-#{stored_at.mday}T" \
        "#{stored_at.hour}:#{stored_at.minute + ((stored_at.second + expiration_time)/60).floor}" \
        ":#{(stored_at.second+expiration_time)%60}#{stored_at.zone}"
        assert_equal(expected, val.get_expiration_date.to_s)
    end
end