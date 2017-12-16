require 'mastodon'
require './app_conf'
require 'pp'
require 'oauth2'

app_conf = AppConf.new(".bhasati.toml")
conf = app_conf.load

client = OAuth2::Client.new(conf['app']['client_id'],
                            conf['app']['client_secret'],
                            :site => conf['user']['server_url'])

url = client.auth_code.authorize_url(:redirect_uri => 'urn:ietf:wg:oauth:2.0:oob')
puts url

print "Enter code: "
code = $stdin.gets.chomp
puts "Code = >>>#{code}<<<"

token = client.auth_code.get_token(code, :redirect_uri => 'urn:ietf:wg:oauth:2.0:oob')

conf['user']['access_token'] = token.token
app_conf.save conf

