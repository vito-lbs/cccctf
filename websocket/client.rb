require 'celluloid'
require 'celluloid/io'
require 'websocket'
require 'uri'
require 'set'

module URI
  class WS < HTTP
  end

  @@schemes['WS'] = WS
end

ADDRESS = URI.parse "ws://challs.campctf.ccc.ac:10116/q"

class Connection
  include Celluloid
  include Celluloid::Logger

  def initialize
    open_socket
    send_handshake
    upgrade_connection
  end

  def frame(data)
    send_frame data
    expect_frame.data
  end

  private

  def send_frame(data)
    frame = WebSocket::Frame::Outgoing::Client.new(
      version: @handshake.version,
      data: data,
      type: :text
    )
    @sock.write frame.to_s
  end

  def expect_frame
    until n = incoming.next
      incoming << @sock.read
    end

    n
  end

  def open_socket
    info "opening #{ADDRESS}"
    @sock = Celluloid::IO::TCPSocket.new(ADDRESS.host,
                                         ADDRESS.port)
  end

  def send_handshake
    @handshake = WebSocket::Handshake::Client.new(
      url: ADDRESS.to_s,
      headers: {
        'Origin' => 'http://challs.campctf.ccc.ac:10116/'
      }
    )

    info "sending handshake"
    puts @handshake.to_s

    @sock.write @handshake.to_s
  end

  def upgrade_connection
    until @handshake.finished?
      @handshake << @sock.read(1)
    end

    info "valid handshake? #{@handshake.valid?}"
  end

  def incoming
    @incoming ||= WebSocket::Frame::Incoming::Client.new(
      version: @handshake.version
    )
  end
end

class Haystack
  attr_reader :entries, :values

  def initialize
    @entries = Hash.new
    @values = Set.new
  end

  def add(entry)
    @entries[entry.address] = entry
    @values.add entry.value
    puts entry.inspect unless entry.value =~ /silver/
  end
end

class HaystackEntry
  attr_reader :address, :value

  def initialize(data)
    @address, @value = data.split ','
  end
end

class Solver
  include Celluloid::Logger

  def initialize(conn)
    @conn = conn
    @haystack = Haystack.new
  end

  def phase1
    @p1 = Set.new
    (0..255).each do |c|
      chr = c.chr
      response = @conn.frame chr
      next if response == 'not found'
      entry = HaystackEntry.new response
      @haystack.add entry
      @p1.add chr
    end
  end

  def phase2
    @p2 = Set.new
    puts
    @p1.each_with_index do |f, i|
      print "\r#{i}/#{@p1.size}"
      (0..255).each do |c|
        chr = f + c.chr
        response = @conn.frame(chr)
        next if response == 'not found'
        entry = HaystackEntry.new response
        @haystack.add entry
        @p2.add chr
      end
    end
    puts

    info @haystack.values
    info @haystack.entries.size
  end

  def phase3
    @p3 = Set.new
    info "phase 3"
    @p2.each_with_index do |f, i|
      print "\r#{i}/#{@p2.size}"
      (0..255).each do |c|
        chr = f + c.chr
        response = @conn.frame(chr)
        next if response == 'not found'
        entry = HaystackEntry.new response
        @haystack.add entry
        @p3.add chr
      end
    end
    puts

    info @haystack.values
    info @haystack.entries.size
  end
end

conn = Connection.new
solver = Solver.new conn
solver.phase1
solver.phase2
solver.phase3

binding.pry
