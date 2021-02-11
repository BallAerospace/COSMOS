require 'mkmf'

unless $CFLAGS.gsub!(/ -O[\dsz]?/, ' -O3')
  $CFLAGS << ' -O3'
end
if /gcc/.match?(CONFIG['CC'])
  $CFLAGS << ' -Wall'
  if $DEBUG && !$CFLAGS.gsub!(/ -O[\dsz]?/, ' -O0 -ggdb')
    $CFLAGS << ' -O0 -ggdb'
  end
end

create_makefile 'cosmos/ext/polynomial_conversion'
