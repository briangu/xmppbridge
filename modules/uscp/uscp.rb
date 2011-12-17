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

    @actor = "urn:member:45310686"
    @app = 'urn:app:ucpbot'

    @jid = ujid
    @feedUrl = feedUrl
    @publishUrl = publishUrl

    @user =  /^(.+)\@/.match(ujid)[1]
    @userhost =  /^(.+)\@(.+)$/.match(ujid)[2]
    @channel = nil
    @channel_list = Array.new
    @subscriptions = {}

    @cache = LRUCache.new(:max_size => 4096, :default => nil)

    subscribe("all", "select * from ucp", {})
    subscribe("all-li", "select * from ucp where app = 'urn:app:linkedin'", {})

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

  def show_help
    reply([
              "=== USCP Bridge Commands ===",
              ".bql [bql]      : execute a BQL query",
              ".bql-help       : Show BQL samples and help",
              ".s [name] [BQL] : Subscribe to a feed",
              ".unsub [name]   : Unsubscribe from a feed",
              ".say [msg]      : Publish a message",
              ".status         : Status info",
              #      ".app [urn]      : Set application context",
              #      ".feeds          : View feeds defined in current application context",
              ".h |.?          : This help msg",
              ".quit           : Quit"
          ])
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

        elsif msg.match(/^\.app (.+?)$/)
          exec_app($1)

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

        elsif msg.match(/^\.say (.+)$/)
          exec_say($1)

        else
          reply(["sup dawg"])
        end

      rescue SocketError => se
        reply_user(@jid, "Socket error (send): " + se.to_s, "std")
      rescue Exception => ex
        reply_user(@jid, "Error (send): " + ex.to_s, "std")
      end
    end
  end

  def disconnect(ujid=nil)
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
    msgs = []
    msgs.push("app: " + @app)
    msgs.push("subscriptions:")
    @subscriptions.each {|key, value|
      msgs.push("#{key} => #{value[:bql]} [#{value[:params]}] ")
    }

    reply(msgs)
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
        next if !@cache.fetch(update["id"]).nil?
        newActivities.push(update)
        @cache.store(update["id"], 1)
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

  def publish_activity(activity)
    publish_activity_json(activity.to_json)
  end

  def publish_activity_json(activity)
    code, headers, body = post("#{@publishUrl}", {}, activity)
  end

  def create_object_summary(type, url, title, description, image, properties)
    object = {}
    object[:type] = type unless type.nil?
    object[:url] = url unless url.nil?
    object[:title] = title unless title.nil?
    object[:description] = description unless description.nil?
    object[:image] = image unless image.nil?
    object[:properties] = properties unless properties.nil?
    object
  end

  def default_visibility
    {"public" => true}
  end

  def create_activity(app, actor, verb, object, visibility)
    activity = {}
    activity[:app] = app
    activity[:actor] = actor
    activity[:verb] = verb
    activity[:object] = object
    activity[:visibility] = visibility
    activity
  end

  def create_verb_summary(type, commentary, properties)
    verb = {}
    verb["type"] = type unless type.nil?
    verb["commentary"] = commentary unless commentary.nil?
    verb["properties"] = properties unless properties.nil?
    verb
  end

  def exec_say(msg)
    verb = create_verb_summary("urn:verb:ucpbot:say", msg, nil)
    object = create_object_summary(nil, nil, nil, nil, nil, nil)
    activity = create_activity("urn:app:ucpbot", @actor, verb, object, default_visibility)
    publish_activity(activity)
#    reply(["you said: " + msg])
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

  def exec_app(app)
    @app = app
    status_info()
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
    reply_user(@jid, "\n" + msgs.join("\n"), "std")
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
