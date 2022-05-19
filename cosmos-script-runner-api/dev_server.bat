FOR /F "tokens=*" %%i IN (..\.env) DO set %%i
set RUBYLIB=%cd%\..\cosmos\lib
set COSMOS_REDIS_HOSTNAME=127.0.0.1
set COSMOS_REDIS_EPHEMERAL_HOSTNAME=127.0.0.1
call bundle install
call bundle exec rails s
