module Config
    #Server
    SERVER_PORT = 23
    FIXNUM_MAX = (2**(0.size * 8 -2) -1)
    SECONDS_PER_DAY = 60 * 60 * 24
    VALID_COMMANDS = [:add, :replace, :set, :prepend, :append, :cas, :get, :gets, :delete, :incr, :decr, :flush_all]
    ONE_LINE_COMMANDS = [:get, :gets, :delete, :flush_all]
    MAX_BYTES = 1000
end