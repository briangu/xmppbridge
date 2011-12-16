# encoding: iso-8859-1

require 'rubygems'
require 'socket'
require 'json'
require 'lrucache'
require File.dirname(__FILE__) + '/http'

class USCPclient

  include HTTP_METHODS

  attr_reader :version

  def initialize(ujid, feedUrl, publishUrl)

    @version = "1.0"

    @jid = ujid
    @feedUrl = feedUrl
    @publishUrl = publishUrl

    @user =  /^(.+)\@/.match(ujid)[1]
    @userhost =  /^(.+)\@(.+)$/.match(ujid)[2]
    @channel = nil
    @channel_list = Array.new
    @subscriptions = {}

    @cache = LRUCache.new(:ttl => 3600)

    subscribe("all", "select * from ucp", {})

    @thread = Thread.new do
      begin
        logit("#{self} created for #{@jid}.")
        logit("USCPclient v#{@version} - #{@jid} connection successful.")
        reply_user(@jid, "Welcome to USCP client v#{@version}!", $mtype)
        reply_user(@jid, "Type .h to get help.", "std")

        $lobby_users.each do |u|
          reply_user(u, "#{$user_nicks[@jid]} connected to the USCP.", $mtype)
        end
        $bridges << self
        $bridged_users[@jid] = self # add to player=>bridged_app hash
        #$b.xmpp.status(nil,$b.get_status)

        loop do
          logit("polling")
          poll_subscriptions()
          sleep 10
        end
      rescue Exception => e
        reply_user(@jid, "Socket: " + e.to_s + "\n" + e.backtrace.join, "std")
      end
    end
    @thread[:name] = "USCP:#{@jid}"
  end

  def process_msg(ujid, msgtimestr, msgbody)
    # not doing any internal processing to this message.
    # just pass it on to the remote application.
    #reply_user(@jid, "got process_msg", "std")
    handle_user_input(msgbody)
  end

  def handle_user_input(msg)
    if msg.chomp == "QUIT"
      self.disconnect()
    else
      begin
        if msg.match(/^\.h.*$/)
          show_help()

        elsif msg.match(/^\.\?$/)
          show_help()

        elsif msg.match(/^\.bql (.+?)$/)
          exec_bql($1)

        elsif msg.match(/^\.s (.+?) (.+)$/)
          exec_sub($1, $2, {})

        elsif msg.match(/^\.unsub (.+?)$/)
          exec_unsub($1)

        elsif msg.match(/^\.status$/)
          status_info()

        elsif msg.match(/^\.bql-help/)
          exec_bql_help()

        elsif msg.match(/^\.quit$/)
          self.disconnect()

        elsif msg.match(/^\.quit (.+)$/)
          self.disconnect()
        else
        end

      rescue SocketError => se
        reply_user(@jid, "Socket error (send): " + se.to_s, "std")
      rescue Exception => ex
        reply_user(@jid, "Error (send): " + ex.to_s, "std")
      end
    end
  end

  def disconnect(ujid=nil)
    @sock.close unless @sock.closed?
    Thread.kill(@thread)
    reply_user(@jid, "Disconnected from USCP.", "std")
    $bridges.delete($bridged_users[@jid])
    $bridged_users.delete(@jid)
    logit("#{@jid} has exited the USCP client.")
    reply_user(@jid, "Entering lobby...", "std")
    $lobby_users.each do |user|
      reply_user(user, "#{$user_nicks[@jid]} has exited the USCP and entered the lobby.", "std") unless user == @jid
    end
    $b.add_user_to_lobby(@jid)
    #$b.xmpp.status(nil, $b.get_status)
  end

  def type
    "USCP"
  end

  def info
    "USCP: " + @jid
  end

  private

  def status_info()
    reply_user(@jid, "subscriptions:", "std")
    @subscriptions.each {|key, value|
      reply_user(@jid, "#{key} => #{value[:bql]} [#{value[:params]}] ", "std")
    }
  end

  def send_to_user(activities)
    if activities && activities.length > 0
      activities.each do |activity|
        reply_user(@jid, activity["body"], "std")
      end
    end
  end

  def subscribe(name, bql, params)
    @subscriptions[name] = { :bql => bql, :params => params }
  end

  def unsubscribe(name)
    @subscriptions.delete(name)
  end

  def poll_subscriptions
    @subscriptions.each {|key, value|
      logit("checking feed: " + value[:bql])
      activities = poll_feed(value[:bql], value[:params])
      newActivities = filter_feed(key, activities)
      send_to_user(newActivities)
    }
  end

  def filter_feed(name, raw_json)
    json = JSON.parse(raw_json)
    activities = json["value"]
    newActivities = Array.new
    if activities && activities.length > 0
      activities.each do |update|
        next if @cache[update["id"]]
        newActivities.push(update)
        @cache[update["id"]] = update
      end
    end
    newActivities
  end

  def convert_feed(raw_json)
    json = JSON.parse(raw_json)
    json["value"]
  end

  def poll_feed(bql, params)
    code, headers, body = query_feed(bql, params)
    # filter out events already seen adn return the new ones
    body
  end

  def query_feed(bql, params)
    parameters = (params && params.length > 0) ? JSON.parse(params) : {}
    json = {
#        "viewerId" => member_id,
      "feed" => {
          "query" => bql,
          "params" => parameters || {}
      },
      "start" => 0,
      "count" => 10
    }.to_json
    logit("#{@feedUrl}/?action=query")
    code, headers, body = post("#{@feedUrl}/?action=query", {}, json)
    logit(body)
    return [code, headers, body]
  end

  def send(msg)
    if msg.chomp == "quit"
      disconnect(@jid)
    else
      begin
        # TODO: publish to uscp
      rescue SocketError => se
        reply_user(@jid, "Socket error (send): " + se.to_s, "std")
        logit("Socket error (send): " + se.to_s)
        disconnect(@jid)
      rescue Exception => ex
        reply_user(@jid, "Error (send): " + ex.to_s, "std")
        logit("Error (send): " + ex.to_s)
        disconnect(@jid)
      end
    end
  end

  def show_help
    reply([
      "=== USCP Bridge Commands ===",
      " .bql [bql]     : execute a BQL query",
      " .bql-help      : Show BQL samples and help",
      " .s [name] [BQL | urn] {params} : Subscribe to a feed",
      " .unsub [name]  : Unsubscribe from a feed",
      " .status        : Status info",
      " .app [urn]     : Set application context",
      " .feeds         : View feeds defined in current application context",
      " .h |.?         : This help msg",
      " .quit          : Quit"
    ])
  end

  def exec_bql_help()
    msgs = Array.new

    msgs.push("\nHere's a list of all where clauses and samples:\n")

    selections = load_query_info()
    selections.each {|key, value|
      msgs.push(key + " => " + value["sample"])
    }
    reply(msgs)
  end

  def exec_bql(bql)
    code, header, body = query_feed(bql, {})
    newActivities = convert_feed(body)
    send_to_user(newActivities)
  end

  def exec_sub(name, bql, params)
    subscribe(name, bql, params)
  end

  def exec_unsub(name)
    unsubscribe(name)
  end

  def reply(msgs)
    reply_user(@jid, msgs.join("\n"), "std")
  end

  def reply_ind(msgs)
    msgs.each do |msg|
      reply_user(@jid, msg, "std")
    end
  end

  def load_query_info()
    file = File.open(File.dirname(__FILE__) + "/query-options.json")
    json = file.readlines.to_s
    data = JSON.parse(json)
    data["selections"]
  end
end # class
