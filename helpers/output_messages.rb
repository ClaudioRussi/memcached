# Module with common error and output messages
module Output
  ERROR = 'ERROR\r\n'
  INCREMENT_ERROR = 'CLIENT_ERROR cannot increment or decrement non-numeric value'
  NOT_SPECIFIED = 'Command not specified'
  DELETED = 'DELETED'
  NOT_FOUND = 'NOT_FOUND'
  NOT_STORED = 'NOT_STORED'
  EXISTS = 'EXISTS'
  STORED = 'STORED'

  def self.value(value)
    "VALUE #{value.value} #{value.flag} #{value.bytes} #{value.cas}"
  end
end