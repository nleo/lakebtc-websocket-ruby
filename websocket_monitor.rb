require 'bundler/setup'
require 'eventmachine'
require 'faye/websocket'
require 'json'
require 'colorize'
require 'pry'

def say(msg)
	puts "#{Time.now.strftime('%FT%T%z')}: #{msg}"
end

@connection_id = nil
@channels = [
	'orderbook_USD'
]

class WsMessage
	def initialize(name, data, con_id = nil)
	    @_name = name
			@_data = data
			@_connection_id = con_id
			return self
	end


	def name=(n)
		@_name = n
	end

	def connection_id=(cid)
		@_connection_id= cid
	end

	def data=(d)
		@_data = d
	end

	def to_a
		data = {}
		data['data'] = @_data
		if @_connection_id
			data['connection_id'] = @_connection_id
		end
		return [@_name, data]
	end

end


EM.run {
  ws = Faye::WebSocket::Client.new("wss://www.lakebtc.com/websocket")

  ws.on :open do |event|
    say 'Connection opened'
  end

  ws.on :message do |event|
    msg = JSON.parse(event.data).first
		msg_name = msg.first
		msg_hash = msg.last
		msg_channel = msg_hash['channel']
		case msg_name
		when 'client_connected'
			@connection_opened = Time.now
			@connection_id = msg_hash['data']['connection_id']
			say "Connection set: #{msg_hash['data']['connection_id']}"

			@pong = WsMessage.new 'websocket_rails.pong', nil, @connection_id

			say 'Subscribing to channels:'
			@channels.each do |c|
				sub = WsMessage.new 'websocket_rails.subscribe', {channel: c}
				say " -> #{c}"
				ws.send sub.to_a.to_json
			end

		when 'websocket_rails.subscribe'


		when 'websocket_rails.ping'
			ws.send @pong.to_a.to_json

		when 'websocket_rails.channel_token'
			say 'FIXME: channel tokens!'.red

		when 'update'
			# binding.pry
			say "Update notification: #{msg_channel} with bids = =#{msg_hash['data']['bids'].first}"

		when 'data'
			d = msg_hash['data']
			say "Display data for display id=#{d['id']}"

		when 'error'
			d = msg_hash['data']
			say "ERROR: Channel: \"#{msg_channel}\" Display: #{d['display_id']}, message #{d['message']}".red
		else
			say 'Got unhandled message: '
			if msg_channel
				say " -> Channel: #{msg_channel} message: #{msg_name} hash: #{msg_hash}".yellow
			else
				say " -> Message: #{msg_name} success: #{msg_hash['success']} data: #{msg_hash['data']}".yellow
			end
		end

  end

  ws.on :close do |event|
		say "Connection was opened at: #{@connection_opened.strftime('%FT%T%z')}".red
		say "Connection was up for #{Time.diff(Time.now, @connection_opened, "%h:%m:%s")[:diff]}".red
    abort "Connection closed!".red
  end
}
