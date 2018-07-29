#\ -p 5002

$LOAD_PATH.unshift(File.expand_path('.'))
require 'app'

use DocHandler
use Courier::Middleware::JWT
run App
