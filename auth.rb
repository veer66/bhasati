require 'oauth2'

def create_auth_url(conf)
  client = OAuth2::Client.new(conf['app']['client_id'],
                              conf['app']['client_secret'],
                              :site => conf['user']['base_url'])

  client.auth_code.authorize_url(:redirect_uri => 'urn:ietf:wg:oauth:2.0:oob')
end

def get_access_token(conf, code)
  client = OAuth2::Client.new(conf['app']['client_id'],
                              conf['app']['client_secret'],
                              :site => conf['user']['base_url'])
  token = client.auth_code.get_token(code, :redirect_uri => 'urn:ietf:wg:oauth:2.0:oob')
  conf['user']['access_token'] = token.token
end

