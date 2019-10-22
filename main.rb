require 'socket'
require_relative './memcached'

VALID_COMMANDS = ['ADD', 'REPLACE', 'SET', 'PREPEND', 'APPEND', 'CAS']

def main()
  server = TCPServer.new 23
  loop do
    Thread.start(server.accept) do |client|
      client.puts("Connected")
      lines = []
      while line = client.gets
        line = line.chomp.gsub(/[^[:print:]]/i, '')
        puts(line)
        if is_valid_command(line) || lines.size > 0
          lines << line
        end
        if(lines.size > 1)
          parse_input(lines)
        end
        print(lines)
      end
      client.close
    end
  end
end

def is_valid_command(input)
  return VALID_COMMANDS.include? input.split(' ')[0].upcase
end

def parse_input(lines)

end

main()
