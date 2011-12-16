# encoding: iso-8859-1
#=======================================================
#  XMPPBridge module commands for uscp
#
#  Copyright 2011 by Brian Guarraci
#
#=======================================================

# !uscp
$cmdarray.push(Botcmd.new(
  :name => 'uscp',
  :type => :public,
  :code => %q{
    begin
      player = ujid
      if $bridged_users.include?(player)
        reply_user(player, "You are already bridged.  Use !quit first if you want to join or create a new bridge to another application or game.", $mtype)
      else
        leave_lobby(player, "connecting to USCP")
        reply_user(player, "Connecting to USCP...", $mtype)
        logit("#{player} connecting to USCP...")
        uscp = USCPclient.new(player, 'http://eat1-app219.stg.linkedin.com:1340/activityviews', 'http://eat1-app219.stg.linkedin.com:1338/activities')
      end
    rescue Exception => e
      reply_user(ujid, "Error (!testuscp): " + e.to_s, $mtype)
    end
  },
  :return => nil,
  :helptxt => 'Connect to Sandbox USCP.'
  ))

