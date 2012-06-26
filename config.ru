require "./web"

use(Rack::Auth::Basic, "Restricted Area") { |username, password| [username, password] == [ENV['APP_USER'], ENV['APP_PWD']] }

run HelloApp
