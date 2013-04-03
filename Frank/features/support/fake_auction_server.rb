require 'xmpp4r'
require 'xmpp4r/roster'

module AuctionSniper
  class FakeAuctionServer
    attr_reader :join_requests, :messages

    def initialize(itemid)
      @join_requests = 0
      @itemid = itemid
      @messages = []
      @join_requests = []
    end

    def start_selling_item
      connect_to_server
      add_callbacks
    end

    def stop_selling_item
      if @messages
        announce_auction_closed
      end

      disconnect!
    end

    def report_price(options)
      return unless @messages.last
      price_message = Jabber::Message.new.set_type(:chat)
      price_message.to = @messages.last.from
      price_message.from = jid
      price_message.body = "SOLVersion: 1.1; Event: PRICE; CurrentPrice: #{options[:price]}; Increment: #{options[:increment]}; Bidder: #{options[:bidder]};"
      @client.send(price_message)
    end

    def disconnect!
      @client.close
    end

  private
    def jid
      Jabber::JID.new("auction-item-#{@itemid}@localhost/auction")
    end

    def connect_to_server
      @client = Jabber::Client.new(jid)
      @client.connect
      @client.auth('auction')
      @client.send(Jabber::Presence.new.set_type(:chat))

      @roster = Jabber::Roster::Helper.new(@client)
    end

    def add_callbacks
      @roster.add_subscription_request_callback do |request, presence|
        @roster.accept_subscription(presence.from)
      end

      @client.add_message_callback do |message|
        @messages << message

        if join_request?(message)
          @join_requests << message
        end
      end
    end

    def announce_auction_closed
        stop_message = Jabber::Message.new.set_type(:chat)
        stop_message.to = @messages.last.from
        stop_message.from = jid
        stop_message.body = 'SOLVersion: 1.1; Event: CLOSE'
        @client.send(stop_message)
    end

    def join_request?(message)
      message.body == 'SOLVersion: 1.1; Command: JOIN;'
    end
  end
end
