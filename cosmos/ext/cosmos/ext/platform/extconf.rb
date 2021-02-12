require 'mkmf'

unless $CFLAGS.gsub!(/ -O[\dsz]?/, ' -O3')
  $CFLAGS << ' -O3'
end
if CONFIG['CC'] =~ /gcc/
  $CFLAGS << ' -g -Wall'
  if $DEBUG && !$CFLAGS.gsub!(/ -O[\dsz]?/, ' -O0 -ggdb')
    $CFLAGS << ' -O0 -ggdb'
  end
end

create_makefile 'cosmos/ext/platform'
