require 'socket'
def main()
  semaphore = Mutex.new
  server = TCPServer.new 23
  loop do
    Thread.start(server.accept) do |client|
      client.puts("Connected")
      #semaphore.synchronize do
          #client.puts "Hello !"
          #client.puts "Time is #{Time.now}"
        #while(true) do 
        #end
      #end
      client.close
    end
  end
end

main()
