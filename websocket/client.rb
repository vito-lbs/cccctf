require 'celluloid/websocket/client'

ADDRESS = "ws://challs.campctf.ccc.ac:10116/q"

class Celluloid::WebSocket::Client::Connection
  def headers
    {
      'Origin' => 'http://challs.campctf.ccc.ac:10116',
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2478.0 Safari/537.36'
    }
  end
end

class Client
  include Celluloid
  include Celluloid::Logger

  def initialize
    @client = Celluloid::WebSocket::Client.new ADDRESS, current_actor
  end

  def on_open
    info "started"
    @client.text 'f'
  end

  def on_message(data)
    info "message #{data.inspect}"
  end

  def on_close(code, reason)
    debug "closed #{code.inspect} #{reason.inspect}"
  end
end

Client.new

sleep
