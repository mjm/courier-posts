#\ -p 5003

$LOAD_PATH.unshift(File.expand_path('.'))
require 'app'

use Courier::Middleware::Documentation, __dir__
use Courier::Middleware::JWT
run App
