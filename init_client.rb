require 'mastodon'
require './app_conf'
require "pp"

def init_client(conf, server_url)
  conf["user"]["base_url"] = server_url
  conf["app"]["app_url"] = "https://github.com/veer66/bhasati"
  client = Mastodon::REST::Client.new(base_url: conf["user"]["base_url"])
  app = client.create_app("bhasati", conf["app"]["app_url"])
  conf["app"]["client_id"] = app.client_id
  conf["app"]["client_secret"] = app.client_secret
end
