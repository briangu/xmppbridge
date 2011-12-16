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

  def channel_listing
    begin
      if @channel_list.length > 0
        reply_user(@jid, "List of active channels:", "std")
        count = 0
        @channel_list.each do |c|
          reply_user(@jid, "--> #{c.name}", "std")
        end
        reply_user(@jid, "Currently active on: '#{@channel.name}'", "std")
      else
        reply_user(@jid, "Not on any channels.  Use .j to join.", "std")
      end
      if @muted_channel_list.length > 0
        reply_user(@jid, "List of muted channels:", "std")
        count = 0
        @muted_channel_list.each do |c|
          reply_user(@jid, "--> #{c.name} [Muted]", "std")
        end
      end
    rescue Exception => ex
      reply_user(@jid, "Error (channel_listing): " + ex.to_s, "std")
    end
  end

  def change_active_channel(channel_name=nil)
    begin
      if channel_name
        found = false
        @channel_list.each do |c|
          if c.name == channel_name
            @channel = c
            found = true
          end
        end
        if found
          reply_user(@jid, "active channel now '#{@channel.name}'", "std")
        else
          reply_user(@jid, "you aren't joined to '#{channel_name}'", "std")
        end
      else
        if @channel_list.length > 0
          i = 0
          @channel_list.each do |c|
            if c.name == @channel.name
              if i < (@channel_list.length - 1)
                @channel = @channel_list[i+1]
              else
                @channel = @channel_list[0]
              end
              break
            end
            i += 1
          end
          reply_user(@jid, "active channel now '#{@channel.name}'", "std")
        else
          reply_user(@jid, "Not on any channels.  Use .j to join.", "std")
        end
      end
    rescue Exception => ex
      reply_user(@jid, "Error (change_active_channel): " + ex.to_s, "std")
    end
  end

  def get_channel_roster
    begin
      if not @channel
        reply_user(@jid, "Not on any channels.  Use .j to join.", "std")
        return nil
      end
      usercount = 0
      opcount = 0
      userlist = ""
      users = Array.new
      @channel.roster.each do |k, v|
        if v.op
          users << "@#{v.nick}"
          opcount += 1
        else
          users << v.nick
          usercount += 1
        end
      end
      userlist = users.join(", ")
      reply_user(@jid, "[#{@channel.name}]: #{userlist}", "std")
      reply_user(@jid, "[#{@channel.name}]: #{usercount} users, #{opcount} ops", "std")
    rescue Exception => ex
      reply_user(@jid, "Error (get_channel_roster): " + ex.to_s, "std")
    end
  end

  def show_help
    reply_user(@jid, "=== USCP Bridge Commands ===", "std")
    reply_user(@jid, " .quit [msg] : Quit (with msg)", "std")
    reply_user(@jid, " .status    : Status info", "std")
    reply_user(@jid, " .h |.?     : This help msg", "std")
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

        elsif msg.match(/^\.status$/)
          status_info()

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

  def process_msg(ujid, msgtimestr, msgbody)
    # not doing any internal processing to this message.
    # just pass it on to the remote application.
    #reply_user(@jid, "got process_msg", "std")
    handle_user_input(msgbody)
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

  def send_to_user(activities)
    if activities && activities.length > 0
      activities.each do |activity|
        reply_user(@jid, activity["body"], "std")
      end
    end
  end

end # class
