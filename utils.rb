module Utils
    def parse_telnet_input(input)
        input.chomp.gsub(/[^[:print:]]/i, '')
    end

    def is_unsigned_number(number)
        parsed_number = Integer(number, exception: false)
        return parsed_number && parsed_number >= 0
      end
end