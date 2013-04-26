class ApiKey
  APIKEYS_FNAME = 'apikeys.yml'

  def initialize
    @apikey = YAML::load(Rails.root.join('config', APIKEYS_FNAME).open)[Rails.env]
    raise "No API key for #{Rails.env} environment in #{APIKEYS_FNAME}" unless @apikey
    raise "No consumer key for #{Rails.env} environment in #{APIKEYS_FNAME}" unless @apikey['consumer_key']
    raise "No consumer secret for #{Rails.env} environment in #{APIKEYS_FNAME}" unless @apikey['consumer_secret']
    raise "No callback URL for #{Rails.env} environment in #{APIKEYS_FNAME}" unless @apikey['callback_url']
  end

  def consumer_key
    @apikey['consumer_key']
  end

  def consumer_secret
    @apikey['consumer_secret']
  end

  def callback_url
    @apikey['callback_url']
  end

end
