require 'date'
class Value
    SECONDS_PER_DAY = 60 * 60 * 24

    attr_accessor :value, :updated_at, :expiration_time, :flags, :cas
    attr_reader :stored_at, :last_fetched

    def initialize(value, expiration_time, flags, bytes)
        @value = value
        @expiration_time = expiration_time
        @flags = flags
        @bytes = bytes
        @stored_at = DateTime.now
    end

    def get_expiration_date
        return @stored_at + Rational(expiration_time, SECONDS_PER_DAY)
    end
end