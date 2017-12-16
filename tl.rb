require 'mastodon'
require './app_conf'
require "pp"

app_conf = AppConf.new(".bhasati.toml")
conf = app_conf.load

client = Mastodon::REST::Client.new(base_url: conf["app"]["base_url"],
                                    bearer_token: conf["user"]["access_token"])

PP.pp client.home_timeline


