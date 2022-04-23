require 'uri'
require 'socket'

DEBUG = false

# class represents an FTP connection
# class implements following commands: 
#    user, pass, type I, mode S, stru F, list, 
#    dele, mkd, rmd, stor, petr, quit, pasv
# class also implements wrappers around the commands
# mainly should be used by calling FTP.open(url) with a block statement
class FTP
  DIVIDER = ' '
  ENDING = '\r'

  def initialize(url)
    uri = URI.parse(url)
    abort 'ERROR: Given URL is not FTP' unless uri.kind_of?(URI::FTP)

    @username = uri.user.nil? ? 'anonymous' : uri.user
    @password = uri.password
    @host = uri.host
    @port = uri.port.nil? ? 21 : uri.port
    @path = uri.path
  end

  # opens ftp connection with block statement, where connection
  # should be used, closes connection when block is closed
  def self.open(url, &block)
    ftp = new(url)
    ftp.connect
    return ftp unless block_given?
    yield ftp
  ensure
    ftp.close
  end

  # create and setup FTP connection
  def connect
    open_control
    auth
    setup
  end

  # open control channel through TCP socket
  def open_control
    @control = TCPSocket.open(@host, @port)
    welcome = @control.gets
    puts 'Opening control channel' if DEBUG
    puts "answer: #{welcome}" if DEBUG
  end

  # open data channel through TCP socket with block statement
  # should be used by opening data_channel with block statement,
  # at the end of the block, closes connection
  def open_data_channel
    _, _, host, port = pasv
    puts 'Opening data channel\n\n' if DEBUG
    data_channel = TCPSocket.open(host, port)
    return data_channel unless block_given?
    yield data_channel
  ensure
    data_channel.close
  end

  # login with username and password if available
  def auth
    user(@username)
    pass(@password) unless @password.nil?
  end

  # setup type, mode, and structure required for cs3700ftp
  def setup
    set_binary
    set_stream
    set_file_oriented
  end

  # send given command to the server
  # return answer as (code, msg)
  def send(cmd)
    abort 'FTP ERROR: control channel is not up' if @control.nil?

    @control.puts(cmd)
    answer = @control.gets
    puts 'cmd: ' + cmd + '\n' + 'answer: ' + answer + '\n' if DEBUG

    code, msg = unfold_answer(answer)
    [code, msg]
  end

  # send given command to the server,
  # return answer as (code, msg, data), where data is from data channel
  def request(cmd)
    abort 'FTP ERROR: control channel is nil' if @control.nil?

    open_data_channel do |data_channel|
      @control.puts(cmd)
      answer = @control.gets
      puts "cmd: #{cmd}" if DEBUG
      puts "answer: #{answer}" if DEBUG

      data = data_channel.read
      puts 'data:' if DEBUG
      puts "#{data}\n" if DEBUG

      code, msg = unfold_answer(answer)
      [code, msg, data]
    end
  end

  # send given command, send given data through data channel
  # return answer as (code, msg)
  def transfer(cmd, data)
    abort 'FTP ERROR: control channel is nil' if @control.nil?

    open_data_channel do |data_channel|
      @control.puts(cmd)
      answer = @control.gets
      puts 'cmd: ' + cmd + '\n' + 'answer: '+ answer + '\n' if DEBUG
      
      data_channel.write(data)
      puts 'data send' + '\n\n' if DEBUG
      
      code, msg = unfold_answer(answer)
      return code, msg
    end
  end

  # unflod given answer into (code, msg)
  def unfold_answer(answer)
    answer = answer.chop.split
    code = answer.shift
    msg = answer.join(' ').chomp('.')

    ensure_code(code, msg)
    return code, msg
  end

  # ensure that code is not error, otherwise abort
  def ensure_code(code, msg)
    first_digit = code[0,1].to_i
    case first_digit
    when 1..3
      puts 'ensured code: ' + code + '\n\n' if DEBUG
    when 4..6
      abort 'FTP ERROR: ' + code + ' ' + msg
    else
      abort 'FTP ERROR: CODE is not recognized'
    end
  end

  # Close connection to FTP server and close the controll channel socket
  def close
    quit
    @control.close unless @control.nil?
  end

  # USER <username>
  # Login to the FTP server as the specified username.
  def user(username)
    send('USER' + DIVIDER + username + ENDING)
  end

  # PASS <password>
  # Login to the FTP server using the specified password.
  def pass(password)
    send('PASS' + DIVIDER + password + ENDING)
  end

  # TYPE I
  # Set the connection to 8-bit binary data mode.
  def set_binary()
    send('TYPE' + DIVIDER + 'I' + ENDING)
  end

  # MODE S
  # Set the connection to stream mode.
  def set_stream()
    send('MODE' + DIVIDER + 'S' + ENDING)
  end

  # STRU F
  # Set the connection to file-oriented structure.
  def set_file_oriented()
    send('STRU' + DIVIDER + 'F' + ENDING)
  end

  # LIST <path-to-directory>
  # List the contents of the given directory on the FTP server.
  def list(path: @path)
    _, _, data = request('LIST' + DIVIDER + path + ENDING)
    puts data
  end

  # DELE <path-to-file>
  # Delete the given file on the FTP server.
  def dele(path: @path)
    send('DELE' + DIVIDER + path + ENDING)
  end

  # MKD <path-to-directory>
  # Make a directory at the given path on the FTP server.
  def mkd(path: @path)
    send('MKD' + DIVIDER + path + ENDING)
  end

  # RMD <path-to-directory>
  # Delete the directory at the given path on the FTP server.
  def rmd(path: @path)
    send('RMD' + DIVIDER + path + ENDING)
  end

  # STOR <path-to-file>
  # Upload a new file from data with the given path and name to the FTP server.
  def stor(data, path: @path)
    cmd = 'STOR' + DIVIDER + path + ENDING
    transfer(cmd, data)
  end

  # RETR <path-to-file>
  # Download a file with the given path and name from the FTP server.
  # returns data of the downloaded file
  def retr(path: @path)
    _, _, data = request("RETR#{DIVIDER}#{path}#{ENDING}")
    data
  end

  # QUIT
  # Ask the FTP server to close the connection.
  def quit
    send("QUIT #{ENDING}")
  end

  # PASV
  # Ask the FTP server to open a data channel.
  # returns (code, msg, host, port)
  def pasv
    code, answer = send("PASV #{ENDING}")

    answer = answer.split(' ')
    data = answer.pop
    msg = answer.join(' ')

    data = data.reverse.chomp('(').reverse.chomp(')').split(',')
    host = data.slice(0, 4).join('.')
    port_bits = data.slice(4,5)

    port_first_8_bits = port_bits.shift.to_i
    port_second_8_bits = port_bits.shift.to_i
    port = (port_first_8_bits << 8) + port_second_8_bits

    [code, msg, host, port]
  end
end
