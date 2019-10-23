require 'date'
class Value
    SECONDS_PER_DAY = 60 * 60 * 24

    attr_accessor :value, :updated_at, :expiration_time, :flag, :cas, :last_used
    attr_reader :stored_at

    def initialize(value, flag, expiration_time, cas=nil)
        date = DateTime.now
        @value = value
        @expiration_time = expiration_time
        @flag = flag
        @cas = cas
        @stored_at = date
        @last_used = date
    end

    def get_expiration_date
        return @stored_at + Rational(expiration_time, SECONDS_PER_DAY)
    end
end