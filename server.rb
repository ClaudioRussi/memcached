require 'socket'

server = TCPServer.new 23
loop do
  Thread.start(server.accept) do |client|
    client.puts "Hello !"
    client.puts "Time is #{Time.now}"

    puts(client.gets)

    #client.close
  end
end