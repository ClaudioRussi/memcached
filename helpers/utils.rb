# Module for utils, generic methods and constants
module Utils
  def self.parse_telnet_input(input)
    input.chomp.gsub(/[^[:print:]]/i, '')
  end

  def self.unsigned_number?(number)
    parsed_number = Integer(number, exception: false)
    parsed_number && parsed_number >= 0
  end

  FIXNUM_MAX = (2**(0.size * 8 - 2) - 1)
  SECONDS_PER_DAY = 60 * 60 * 24
end
