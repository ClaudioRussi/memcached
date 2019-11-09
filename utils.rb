module Utils
    def parse_telnet_input(input)
        input.chomp.gsub(/[^[:print:]]/i, '')
    end
end