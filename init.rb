require 'mastodon'
require './app_conf'
require "pp"

app_conf = AppConf.new(".bhasati.toml")
conf = app_conf.load
conf["app"]["base_url"] = "https://mastodon.xyz"
client = Mastodon::REST::Client.new(base_url: conf["app"]["base_url"])

app = client.create_app("bhasati", "https://github.com/veer66/bhasati")
conf["app"]["client_id"] = app.client_id
conf["app"]["client_secret"] = app.client_secret
conf["user"]["server_url"] = "https://mastodon.xyz"

app_conf.save(conf)
