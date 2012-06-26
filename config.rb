RACK_ENV     = ENV['RACK_ENV'] || 'development'

if RACK_ENV != 'heroku'
  FILEPATH     = File.expand_path(File.dirname(__FILE__))
  CONFIG_EMAIL = YAML.load_file(File.join(FILEPATH, 'config', 'email.yml'))
  CONFIG_DB    = YAML.load_file(File.join(FILEPATH, 'config', 'database.yml'))
  DB           = Sequel.connect(CONFIG_DB[RACK_ENV].to_sym)
else
  CONFIG_EMAIL = {
    'smtp' => {
      'address' => ENV['EMAIL_SMTP_SERVER']           || 'smtp.gmail.com',
      'port' => ENV['EMAIL_SMTP_PORT']                || '587',
      'enable_starttls_auto' => ENV['EMAIL_SMTP_TLS'] || true,
      'authentication' => ENV['EMAIL_SMTP_AUTH']      || 'login',
      'domain' => ENV['EMAIL_SMTP_DOMAIN']            || 'localhost.localdomain',
      'user_name' => ENV['EMAIL_SMTP_USER'],
      'password' => ENV['EMAIL_SMTP_PASS']},
    'email' => {
      'to' => ENV['EMAIL_TARGET']}}

  DB = Sequel.connect(ENV['DATABASE_URL'])
end

SMTP_CONFIG = CONFIG_EMAIL[RACK_ENV]['smtp'].to_sym

LOG         = Logger.new(STDOUT)
LOG.level   = Logger::ERROR
