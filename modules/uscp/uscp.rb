require 'rubygems'
require 'socket'
require 'json'
require 'lrucache'
require 'linguistics'
require 'mongo'
require File.dirname(__FILE__) + '/http'
require File.dirname(__FILE__) + '/tagger'

require 'linkparser'
Linguistics::use(:en)

class USCPclient

  include HTTP_METHODS

  attr_reader :version

  def initialize(ujid, feedUrl, publishUrl)

    @version = "1.0"

    @actor = nil
    @app = 'urn:app:ucpbot'

    @jid = ujid
    @feedUrl = feedUrl
    @publishUrl = publishUrl

    @user =  /^(.+)\@/.match(ujid)[1]
    @userhost =  /^(.+)\@(.+)$/.match(ujid)[2]
    @channel = nil
    @channel_list = Array.new
    @subscriptions = {}
    @paused = false
    @goal = "query"
    @poll_count = 100
    @dict = LinkParser::Dictionary.new
    @debug = false

    @tt = Tagger.new
    @members = Mongo::Connection.new("eat1-app56.corp.linkedin.com").db("ucp_members").collection("members")

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
          poll_subscriptions() if !@paused && @poll_count >= 10
          @poll_count += 1
          sleep 1
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
              ".pause          : Pause subscriptions",
              ".resume         : Resume subscriptions",
              ".say [msg]      : Publish a message",
              ".id [member #]  : Set your member Id (e.g. 45310686)",
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
          @poll_count = 100

        elsif msg.match(/^\.unsub (.+?)$/)
          exec_unsub($1)

        elsif msg.match(/^\.status$/)
          status_info()

        elsif msg.match(/^\.id (.+?)$/)
          exec_set_actor($1)

        elsif msg.match(/^\.bql-help/)
          exec_bql_help()

        elsif msg.match(/^\.pause$/)
          exec_pause

        elsif msg.match(/^\.resume$/)
          exec_resume

        elsif msg.match(/^\.debug$/)
          @debug = !@debug
          status_info()

        elsif msg.match(/^\.quit$/)
          self.disconnect()

        elsif msg.match(/^\.quit (.+)$/)
          self.disconnect()

        elsif msg.match(/^\.goal (.+)$/)
          @goal = $1

        elsif msg.match(/^\.load_lex$/)
          @tt = Tagger.new

        elsif msg.match(/^\.say (.+)$/)
          if @actor.nil?
            @goal = 'ask_user_name'
            seek_goal("")
          else
            exec_say($1)
            @poll_count = 100
          end

        else
          seek_goal(msg)
        end

      rescue SocketError => se
        reply_user(@jid, "Socket error (send): " + se.to_s, "std")
      rescue Exception => ex
        reply_user(@jid, "Error (send): " + ex.to_s, "std")
      end
    end
  end

  def seek_goal(msg)
    case @goal
      when 'ask_user_name'
        reply(["hey stranger, what's your name?"])
        @goal = 'get_name'
      when 'get_name'
        reply(["Hold on, searching for you..."])
        cursor = get_actor_by_name(msg)
        if cursor.nil? or cursor.count() == 0
          reply(["I don't know anyone by that name. Who are you really?"])
        elsif cursor.count() > 1
          reply(["I have too many matches, please be more specific"])
        else
          memberId, actor, record = extract_member_info(cursor.next)
          @memberId = memberId
          @actor = actor
          @firstName = record["firstName"]
          reply(["Hi there, #{@firstName}",
                 "I think your member # is #{@memberId}"])
          @goal = "query"
        end
      else
        puts @goal
        if @actor.nil?
          @goal = 'ask_user_name'
          seek_goal(msg)
        else
          process(msg)
        end
    end
  end

  def process(msg)
    parts = msg.split(/[\s\?\!.]/)
    taggable = parts.join(" ")
    tags = @tt.getTags(taggable)
    if tags.include?('UH')
      greet(msg, tags)
    elsif tags.include?('WP')
      do_query(msg, taggable, parts, tags)
    else
      reply(["ask me a question, like: what are my friends doing?"])
    end
  end

  def greet(msg, tags)
    reply(["Hi there, #{@firstName}"])
  end

  def do_query(msg, taggable, parts, tags)
    bql = simple_parser(msg, taggable, parts, tags)
    reply(["OK, searching..."])
    reply(["bql: " + bql]) if @debug
    puts bql
    body = poll_feed(bql, "{}")
    activities = convert_feed(body)
    if (activities.nil? or activities.length == 0)
      reply(["I didn't find any activities, sorry."])
    else
      send_to_user(activities)
    end
    if parts[0] == "subscribe"
      reply(["Subscribing to your query..."])
      exec_sub("q"+(@subscriptions.length+1).to_s, bql, "")
    end
  end

  # to make a query we need:
  # goal get verb
  #   extract VBG --> verb
  # goal get network scope
  #   distance
  #   individual
  #   subset
  #     company
  #     school
  #
  # extract
  def simple_parser(msg, taggable, parts, tags)
    wp = parts[tags.index "WP"]

    if tags.include? "VBG"
      vbg = parts[tags.index "VBG"]
    end

    if tags.include? "PRP$"
      idx = tags.index "PRP$"
      scopeTarget = parts[idx]
      if (tags[idx+1] == "NNS")
        scope = parts[idx+1]
      end
    end

    if tags.include? "VBZ"
      idx = tags.index "VBZ"
      scopeTarget = parts[idx]
      if (tags[idx+1] == "NNP" || tags[idx+1].nil?)
        scope = parts[idx+1]
        if (tags[idx+2] == "NNP" || (tags[idx+2].nil? && !parts[idx+2].nil?))
          scope += " " + parts[idx+2]
        end
        reply(["scope: " + scope]) if @debug
      end
    end

    if vbg.nil?
      reply(["You didn't ask about what people are doing."])
      vbg = 'doing'
    end

    if scope.nil?
      reply(["Who are you asking about?"])
      scopeTarget = 'my'
      scope = 'friends'
    end

    bql = get_query_prefix

    clauses = []
#    clauses.push("verb.type not in ('urn:linkedin:comment')")

    verbs = []
    case vbg
      when 'reading'
        verbs.push("urn:linkedin:discuss")
        verbs.push("urn:linkedin:post")
        verbs.push("urn:linkedin:share")
        verbs.push("urn:linkedin:like")
      when 'posting'
        verbs.push("urn:linkedin:post")
        verbs.push("urn:linkedin:share")
      when 'following'
        verbs.push("urn:linkedin:following")
    end

    if verbs.length > 0
      clauses.push("verb.type in ('#{verbs.join(",")}')")
    end

    case scopeTarget
      when 'my'
        case scope
          when 'friends'
            includeNetwork = true
            clauses.push("My-Network in ('0','1')")
          when 'coworkers'
            clauses.push("actor.company = 'urn:company:1337'")
        end
      when 'is'
        cursor = get_actor_by_name(scope)
        actors = []
        if cursor.nil? or cursor.count() == 0
          reply(["I don't know anyone by that name."])
        else
          cursor.each do |item|
            memberId, actor, record = extract_member_info(item)
            next if memberId.nil?
            actors.push("'"+actor+"'")
          end
        end
        if actors.length > 0
          clauses.push("actor.id in (#{actors.join(",")})")
        end
    end

    bql += clauses.join(" and ")

    if !includeNetwork.nil?
      bql += get_network_query_suffix(@memberId)
    end

    bql
  end

  def fancy_parser(msg, tags)
    sent = @dict.parse(msg)
    if sent.num_valid_linkages == 0
      reply(["I don't know what you are asking about.  Ask me again.'"])
      return
    end

    # build query
    linkages = sent.linkages
    links = linkages[0]
    links.each do |link|
      case link.label
        when "Wq"
          if link.lword == "LEFT-WALL"
          else
          end
        when 'Bsw'
          whp = ''
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
    msgs.push("debug: " + @debug.to_s)
    msgs.push("actor: " + @actor)
    msgs.push("firstName: " + @firstName)
    msgs.push("app: " + @app)
    msgs.push("paused: " + @paused.to_s)
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
    @poll_count = 0
    @subscriptions.each {|key, value|
      logit("checking feed: " + value[:bql])
      activities = poll_feed(value[:bql], value[:params])
      newActivities = filter_feed(activities)
      send_to_user(newActivities)
    }
  end

  def filter_feed(raw_json)
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

  def exec_set_actor(id)
    @actor = "urn:member:"+id
  end

  def exec_app(app)
    @app = app
    status_info()
  end

  def exec_pause()
    @paused = true
    status_info()
  end

  def exec_resume()
    @paused = false
    status_info()
  end

  def exec_say(msg)
    reply(["OK, sending: " + msg])
    verb = create_verb_summary("urn:verb:ucpbot:say", msg, nil)
    object = create_object_summary(nil, nil, nil, nil, nil, nil)
    activity = create_activity("urn:app:ucpbot", @actor, verb, object, default_visibility)
    publish_activity(activity)
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

  def reply_msg(msgs)
    reply_user(@jid, "\n" + msgs.join("\n"), "std")
  end

  def reply(msgs)
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

  def get_actor_by_name(name)
    parts = name.split(' ')
    if (parts.length == 1)
      firstName = parts[0]
      query = {"firstName" => firstName}
    else
      firstName = parts[0]
      lastName = parts[1]
      query = {"firstName" => firstName, "lastName" => lastName}
    end
    search_member(query)
  end

  def get_actor_by_username(username)
    return search_member({"username" => "#{user}"})
  end

  def search_member(query)
    cursor = @members.find(query)
    puts cursor.inspect
    puts cursor.count()
    cursor
  end

  def extract_member_info(record)
    puts record.inspect
    if record.nil? or record["id"].nil?
      memberId = nil
    else
      memberId = record["id"]
    end
    actor = "urn:member:#{memberId}"
    puts "actor: #{actor}"
    return memberId, actor, record
  end

  def get_query_prefix()
    "select * from ucp where "
  end

  def get_network_query(memberId)
    get_query_prefix() + " verb.type not in (\"comment\") and My-Network in ('0', '1')" + get_network_query_suffix(memberId)
  end

  def get_actor_query(memberId)
    "actor.id in (\"urn:member:$memberId\")"
  end

  def get_network_query_suffix(memberId)
#    " My-Network in (\"0\", \"1\") GIVEN FACET PARAM (My-Network, \"srcid\", int, \"#{memberId}\")"
    " GIVEN FACET PARAM (My-Network, \"srcid\", int, \"#{memberId}\")"
  end

end # class
