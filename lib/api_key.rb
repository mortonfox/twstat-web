# Helper class for reading Twitter API key file.
class ApiKey
  APIKEYS_FNAME = 'apikeys.yml'.freeze
  APIKEY_FIELDS = %w(consumer_key consumer_secret callback_url).freeze

  def initialize
    @apikey = YAML.load(Rails.root.join('config', APIKEYS_FNAME).open)[Rails.env]
    fail "No API key for #{Rails.env} environment in #{APIKEYS_FNAME}" unless @apikey

    APIKEY_FIELDS.each { |field|
      # Verify that the API key field exists.
      fail "No #{field} for #{Rails.env} environment in #{APIKEYS_FNAME}" unless @apikey[field]

      # Define an accessor for each API key field.
      define_singleton_method(field) { @apikey[field] }
    }
  end
end
