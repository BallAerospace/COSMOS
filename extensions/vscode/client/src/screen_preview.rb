#!/usr/bin/ruby

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/qt_tool'
require 'cosmos/gui/utilities/classification_banner'
require 'cosmos/script'
require 'cosmos/tools/tlm_viewer/widgets'
require 'cosmos/tools/tlm_viewer/screen'

begin
    v1 = ARGV[0]

    app = Qt::Application.new(ARGV)
    window = Cosmos::Screen.new("preview", v1, nil, :REALTIME, nil, nil, nil, nil, false, true, nil)
    app.exec
rescue Exception 
    # Don't care what we do here because the error is always:
    #
    # uninitialized class variable @@redirect_io_thread_sleeper in Cosmos::QtTool
    # Did you mean?  @@redirect_io_thread
    #
    # This is because its looking for another Cosmos thread that doesn't exist
    # since we are running this screen standalone to just view the screen
end