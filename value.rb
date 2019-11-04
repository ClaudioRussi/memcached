require 'date'
class Value
    SECONDS_PER_DAY = 60 * 60 * 24

    attr_accessor :value, :expiration_time, :flag, :cas, :bytes
    attr_reader :stored_at

    def initialize(value, flag, expiration_time, bytes, cas=nil)
        date = DateTime.now
        @value = value
        @expiration_time = expiration_time
        @flag = flag
        @bytes = bytes
        @cas = cas
        @stored_at = date
    end

    def get_expiration_date
        return @stored_at + Rational(expiration_time, SECONDS_PER_DAY)
    end
end