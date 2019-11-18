require 'date'
require_relative './config'
require_relative './helpers/utils'

# This class represents an entry in memcached.
# value: string to store
# expiration_time: seconds to expiration
# flag: flag value
# cas: cas value
# bytes: bytes to store
class Value
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

  # Calculates the expiration date
  def expiration_date
    @stored_at + Rational(expiration_time.to_i, Utils::SECONDS_PER_DAY)
  end
end
