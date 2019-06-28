# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/dialogs/about_dialog'
require 'cosmos/gui/dialogs/exception_dialog'
require 'cosmos/gui/dialogs/pry_dialog'
require 'cosmos/gui/dialogs/scroll_text_dialog'
require 'cosmos/gui/utilities/classification_banner'
require 'ostruct'
require 'optparse'

module Cosmos

  # Base class of all COSMOS GUI Tools based on QT. It creates the help menu
  # which contains the About menu option. It provides configuration to all
  # tools to remember both the application window location and size across
  # executions. It also redirects all I/O from the application (any printing to
  # stdout or stderr) and creates popups.
  class QtTool < Qt::MainWindow
    slots 'about()'

    @@redirect_io_thread = nil

    include ClassificationBanner

    # Create a new application. IO is redirected such that writing to stdout or
    # stderr will result in a popup to be displayed to the user. Thus
    # applications should not write to stdout (i.e. puts or write) or stderr
    # unless they want a popup titled "Unexpected STD[OUT/ERR] output". By
    # default the title is set to the options.title and the default COSMOS icon
    # is set.
    #
    # @param options [OpenStruct] Application command line options
    def initialize(options)
      # Call QT::MainWindow constructor
      super() # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      @options = options
      @about_string = nil

      # Add Path for plugins
      Qt::Application.instance.addLibraryPath(Qt::PLUGIN_PATH) if Kernel.is_windows?
      # Prevent killing the parent process from killing this GUI application
      Process.setpgrp unless Kernel.is_windows?

      self.class.redirect_io if @options.redirect_io
      self.window_title = @options.title
      Cosmos.load_cosmos_icon

      # Read the application wide stylesheet if it exists
      app_style = File.join(Cosmos::USERPATH, 'config', 'tools', 'application.css')
      @stylesheet = ''
      @stylesheet = File.read(app_style) if File.exist? app_style

      self.class.normalize_config_options(@options)

      # Add a banner based on system configuration
      add_classification_banner
    end

    # Normalizes config_dir, config_file, and stylesheet options
    def self.normalize_config_options(options)
      # Determine the tool name based on the class
      tool_name = self.to_s.class_name_to_filename.split('.')[0] # remove .rb
      options.config_dir = File.join(Cosmos::USERPATH, 'config', 'tools', tool_name) unless options.config_dir
      tool_name = options.config_dir.split('/')[-1]
      if File.exist?(options.config_dir)
        options.config_file = config_path(options, options.config_file, ".txt", tool_name)
        options.stylesheet = config_path(options, options.stylesheet, ".css", tool_name)
      elsif options.config_file == true
        # If the config_file is required and the config_dir doesn't exist then
        # this is a core COSMOS configuration error so just raise an error
        raise "ERROR! config_dir #{options.config_dir} does not exist. tool_name = #{tool_name}"
      else
        options.config_file = nil
        options.stylesheet = nil
      end      
    end

    # Creates a path to a configuration file. If the file is given it is
    # checked for an absolute path. If it is not absolute, the configuration
    # directory is prepended to the filename. If no file is given a default is
    # generated based on the application name.
    #
    # @param filename [String|Boolean|nil] Path to a configuration file which means
    #   the file must be found. true which means that a default configuration file
    #   is required and must be found. nil which means a default file is acceptable
    #   but not required.
    # @param type [String] File extension, e.g. '.txt'
    # @param tool_name [String] Name of the tool calling this method
    # @return [String|nil] Path to an existing configuration file. nil is returned
    #   if filename is nil and the default is not found. An error is raised if
    #   filename is a string or true and it is not found.
    def self.config_path(options, filename, type, tool_name)
      # First check for an absolute path
      return filename if filename && filename != true && File.exist?(filename)
      # Build a default filename
      default_filename = File.join(options.config_dir, "#{tool_name}#{type}")
      if filename == true # The config file is required but not given
        return default_filename if File.exist?(default_filename)
        message = "\n\nDefault configuration file #{default_filename} not found.\n"\
          "Either create this file or pass a configuration filename using the --config option.\n"
        raise message
      elsif filename # Filename was given so look for it in the config dir
        new_filename = File.join(options.config_dir, filename)
        return new_filename if File.exist?(new_filename)
        # If a filename is passed in it is an error if it does not exist
        raise "\n\nConfiguration file #{new_filename} not found.\n"
      end
      # If filename is nil check for the default and return it
      return default_filename if File.exist?(default_filename)
      nil # return nil if filename is nil and the default is not found
    end

    # Create the exit_action and the about_action. The exit_action is not
    # placed in the File menu and must be manually added by the user. The
    # about_action is added to the Help menu by {#initialize_help_menu}.
    def initialize_actions
      @exit_action = Qt::Action.new(Cosmos.get_icon('close.png'), 'E&xit', self)
      @exit_keyseq = Qt::KeySequence.new('Ctrl+Q')
      @exit_action.shortcut = @exit_keyseq
      @exit_action.statusTip = 'Exit the application'
      connect(@exit_action, SIGNAL('triggered()'), self, SLOT('close()'))

      @about_action = Qt::Action.new(Cosmos.get_icon('help.png'), '&About', self)
      @about_action.statusTip = 'About the application'
      connect(@about_action, SIGNAL('triggered()'), self, SLOT('about()'))
      @documentation_action = Qt::Action.new('&Documentation', self)
      @documentation_action.statusTip = 'COSMOS Online Documentation'
      self.connect(@documentation_action, SIGNAL('triggered()')) do
        Qt::DesktopServices.openUrl(Qt::Url.new("http://cosmosrb.com"))
      end
    end

    # Adds menu actions for each target directory. The default_dirs parameter
    # is added as a default and then a separator is added. The target_sub_dir
    # is looked for in each of the target directories and if it exists, this
    # directory is added to the menu. The callback method is called when the
    # menu action is triggered. This method is used primarily in the File->New
    # or File->Open menu since it references system and target directories.
    #
    # @param menu [Qt::Menu] Menu to add the actions to
    # @param default_dirs [String|Array<String>] Either a directory or array of
    #   directories which should correspond to a default system location.
    # @param target_sub_dir [String] The directory name to look for under each target
    # @param callback [#call] Callback method which will be passed the directory
    # @param status_tip [String] Optional status tip string to display when
    #   mousing over the menu action
    def target_dirs_action(menu, default_dirs, target_sub_dir, callback, status_tip = nil)
      default_dirs = [default_dirs] unless default_dirs.is_a? Array
      default_dirs.each do |default_dir|
        default_context = default_dir.split('/')[-2..-1].join('/')
        action = Qt::Action.new(default_context, self)
        action.statusTip = status_tip if status_tip
        action.connect(SIGNAL('triggered()')) { callback.call(default_dir) }
        menu.addAction(action)
      end

      dirs = {}
      System.targets.each do |target_name, target|
        dir = File.join(target.dir, target_sub_dir)
        dirs[target_name] = dir if File.exist?(dir)
      end
      unless dirs.empty?
        menu.addSeparator()
        dirs.each do |target_name, dir|
          if target_sub_dir.empty?
            name = target_name
          else
            name = "#{target_name}/#{target_sub_dir}"
          end
          action = Qt::Action.new(name, self)
          action.statusTip = status_tip if status_tip
          action.connect(SIGNAL('triggered()')) { callback.call(dir) }
          menu.addAction(action)
        end
      end
    end

    # Creates the Help menu and adds the about_action to it. Thus this MUST be
    # called after initialize_actions.
    def initialize_help_menu
      @help_menu = menuBar().addMenu('&Help')
      @help_menu.addAction(@about_action)
      @help_menu.addAction(@documentation_action)
    end

    # This should be called after the tool has been completely laid out and all
    # widgets added. It resizes the application if necessary and positions the
    # window on the screen if necessary. It also remembers the size and
    # position of the windows for subsequent launches of the application.
    # Finally it can initally show the application as minimized or maximized.
    def complete_initialize
      if @options.stylesheet
        @stylesheet << File.read(@options.stylesheet)
      end
      setStyleSheet(@stylesheet)

      # Handle manually sizing the window
      resize(@options.width, @options.height) unless @options.auto_size

      # Handle manually positioning the window
      unless @options.auto_position
        # Get the desktop's geometry
        desktop = Qt::Application.desktop

        # Handle position relative to right edge
        @options.x = desktop.width - frameGeometry().width + @options.x + 1 if @options.x < 0

        # Handle position relative to bottom edge
        @options.y = desktop.height - frameGeometry().height + @options.y + 1 if @options.y < 0

        # Move to the desired position
        move(@options.x, @options.y)
      end

      if @options.remember_geometry and !@options.command_line_geometry
        settings = Qt::Settings.new('Ball Aerospace', self.class.to_s)
        if settings.contains('size') and @options.restore_size and @options.startup_state != :DEFAULT
          size = settings.value('size').toSize
          resize(size)
        end
        if settings.contains('position') and @options.restore_position
          position = settings.value('position').toPoint
          move(position)
        end
      end

      case @options.startup_state
      when :MINIMIZED
        showMinimized()
      when :MAXIMIZED
        showMaximized()
      else
        show()
      end
      self.raise()
    end

    # The closeEvent is sent to the application when it is about to close. We
    # re-implement it in order to remember the position and size of the window
    # for subsequent launches of the application.
    #
    # @param event [Qt::CloseEvent] The close event passed by Qt
    def closeEvent(event)
      if @options.remember_geometry and not @options.command_line_geometry
        settings = Qt::Settings.new('Ball Aerospace', self.class.to_s)
        settings.setValue('position', Qt::Variant.new(pos()))
        settings.setValue('size',     Qt::Variant.new(size()))
      end

      self.class.restore_io if @options.redirect_io

      # Close any remaining dialogs
      qt_version_split = Qt::qVersion.split('.')

      # Only closeAllWindows on Qt versions greater than 4.6
      if qt_version_split[0].to_i > 4 or (qt_version_split[0].to_i == 4 and qt_version_split[1].to_i > 6)
        Qt::Application.closeAllWindows()
      end

      super(event)
    end

    # Display the {AboutDialog} with the about_string. The about_string should
    # be set by the user in the constructor of their application.
    def about
      AboutDialog.new(self, @about_string)
    end

    # Called after parsing all the command line options passed to the
    # application. Users can re-implement this method to return false which
    # will cause the application to exit without being shown. Return true to
    # contine creating the window and execing the application.
    #
    # @param (see #initialize)
    # @return [Boolean] Whether to contine running the application
    def self.post_options_parsed_hook(options)
      true
    end

    # Called after the Qt::Application has been created but before the
    # application itself has been created. This is the last chance to execute
    # custom code before the application executes.
    #
    # @param (see #initialize)
    def self.pre_window_new_hook(options)
    end

    # Create the default application options and parse the command line
    # options. Create the application instance and call exec on the
    # Qt::Application.
    #
    # @param option_parser [OptionParser] Parses the command line options
    # @param options [OpenStruct] Stores all the command line options that are
    #   parsed by the option_parser
    def self.run(option_parser = nil, options = nil)
      Cosmos.set_working_dir do
        option_parser, options = create_default_options() unless option_parser and options
        option_parser.parse!(ARGV)

        if post_options_parsed_hook(options)
          @@application = nil
          begin
            @@application = Qt::Application.new(ARGV)
            @@application.addLibraryPath(Qt::PLUGIN_PATH) if Kernel.is_windows?
            pre_window_new_hook(options)
            @@window = self.new(options)
            #Qt.debug_level = Qt::DebugLevel::High
            #Qt::Internal::setDebug(Qt::QtDebugChannel::QTDB_ALL)
            #Qt::Internal::setDebug(Qt::QtDebugChannel::QTDB_AMBIGUOUS)
            #Qt::Internal::setDebug(Qt::QtDebugChannel::QTDB_CALLS)
            #Qt::Internal::setDebug(Qt::QtDebugChannel::QTDB_GC)
            #Qt::Internal::setDebug(Qt::QtDebugChannel::QTDB_METHOD_MISSING)
            #Qt::Internal::setDebug(Qt::QtDebugChannel::QTDB_VERBOSE)
            #Qt::Internal::setDebug(Qt::QtDebugChannel::QTDB_VIRTUAL)
            @@application.exec
          rescue Exception => error
            unless error.class == SystemExit or error.class == Interrupt
              Cosmos.handle_fatal_exception(error, false)
            end
          end
        end
      end
    end

    # Creates the default application options in a OpenStruct instance. These
    # options include the window size and position. Options also exist to
    # automatically size and position the window and whether to remember the
    # previous size and position.
    #
    # @return [OptionParser, OpenStruct] The options parser which contains all
    #   default command line options as well as the open struct which contains
    #   the default values.
    def self.create_default_options
      options = OpenStruct.new
      options.auto_position = true
      options.x = 0
      options.y = 0
      options.auto_size = true
      options.width = 800
      options.height = 600
      options.command_line_geometry = false
      options.remember_geometry = true
      options.restore_position = true
      options.restore_size = true
      options.redirect_io = true
      options.title = "COSMOS Tool"
      options.config_file = nil
      options.stylesheet = nil

      parser = OptionParser.new do |option_parser|
        option_parser.banner = "Usage: ruby #{option_parser.program_name} [options]"
        option_parser.separator("")

        # Create the help option
        option_parser.on("-h", "--help", "Show this message") do
          puts option_parser
          exit
        end

        # Create the version option
        option_parser.on("-v", "--version", "Show version") do
          puts "COSMOS Version: #{COSMOS_VERSION}"
          puts "User Version: #{USER_VERSION}" if defined? USER_VERSION
          exit
        end

        # Create the system option
        option_parser.on("--system FILE", "Use an alternative system.txt file") do |arg|
          System.instance(File.join(USERPATH, 'config', 'system', arg))
        end
        option_parser.on("-c", "--config FILE", "Use the specified configuration file") do |arg|
          options.config_file = arg
        end
        option_parser.on("--stylesheet FILE", "Use the specified stylesheet") do |arg|
          options.stylesheet = arg
        end

        option_parser.separator("")
        option_parser.separator("Window Size Options:")

        # Create the minimized option
        option_parser.on("--minimized", "Start the tool minimized") do |arg|
          options.startup_state = :MINIMIZED
        end

        # Create the maximized option
        option_parser.on("--maximized", "Start the tool maximized") do |arg|
          options.startup_state = :MAXIMIZED
        end

        # Create the defaultsize option
        option_parser.on("--defaultsize", "Start the tool in its default size") do |arg|
          options.startup_state = :DEFAULT
        end

        # Create the x and y position options
        option_parser.separator("")
        option_parser.separator("Window X & Y Position Options:")
        option_parser.separator("  Positive values indicate a position from the top and left of the screen.")
        option_parser.separator("  Negative values indicate a position from the bottom and right of the screen.")
        option_parser.separator("  A value of -1 indicates to place the right or bottom side of the window")
        option_parser.separator("  next to the right or bottom edge of the screen.")
        option_parser.on("-x VALUE", "--xpos VALUE", Integer, "Window X position") do |arg|
          options.x = arg
          options.auto_position = false
          options.command_line_geometry = true
        end
        option_parser.on("-y VALUE", "--ypos VALUE", Integer, "Window Y position") do |arg|
          options.y = arg
          options.auto_position = false
          options.command_line_geometry = true
        end

        # Create the width and height options
        option_parser.separator("")
        option_parser.separator("Window Width and Height Options:")
        option_parser.separator("  Specifing width and height will force the specified dimension.")
        option_parser.separator("  Otherwise the window will layout according to its defaults.")
        option_parser.on("-w VALUE", "--width VALUE", Integer, "Window width") do |arg|
          options.width = arg
          options.auto_size = false
          options.command_line_geometry = true
        end
        option_parser.on("-t VALUE", "--height VALUE", Integer, "Window height") do |arg|
          options.height = arg
          options.auto_size = false
          options.command_line_geometry = true
        end
        option_parser.separator ""
      end

      return parser, options
    end

    # Redirect stdout and stderr to a stringIO and monitor it for text.
    # If text is found create a popup titled "Unexpected STD[OUT/ERR] output".
    # Thus applications should not print to standard output or standard error
    # in their applications unless they are trying to warn the user.
    #
    # NOTE: This is automatically called in {#initialize} if the redirect_io
    # option is set which it is by default.
    #
    # NOTE: For debugging purposes use STDOUT.puts "Message" which will print
    # to the command line when run from the command line. If run from the
    # COSMOS Launcher the output will be lost.
    #
    # @param stdout [Boolean] Whether to redirect standard output
    # @param stderr [Boolean] Whether to redirect standard error
    def self.redirect_io(stdout = true, stderr = true)
      if stdout
        stdout_stringio = StringIO.new('', 'r+')
        $stdout = stdout_stringio
      end

      if stderr
        stderr_stringio = StringIO.new('', 'r+')
        $stderr = stderr_stringio if stderr
      end

      # Monitor for text to be written
      @@redirect_io_thread = Thread.new do
        @@redirect_io_thread_sleeper = Sleeper.new
        begin
          loop do
            if stdout and stdout_stringio.string.length > 0
              saved_string = stdout_stringio.string.dup
              stdout_stringio.string = ''
              Qt.execute_in_main_thread(true) do
                ScrollTextDialog.new(Qt::CoreApplication.instance.activeWindow, 'Unexpected STDOUT output', saved_string)
              end
            end
            if stderr and stderr_stringio.string.length > 0
              saved_string = stderr_stringio.string.dup
              stderr_stringio.string = ''
              Qt.execute_in_main_thread(true) do
                ScrollTextDialog.new(Qt::CoreApplication.instance.activeWindow, 'Unexpected STDERR output', saved_string)
              end
            end
            break if @@redirect_io_thread_sleeper.sleep(1)
          end
        rescue Exception => error
          Qt.execute_in_main_thread(true) { || ExceptionDialog.new(Qt::CoreApplication.instance.activeWindow, error, 'Exception in Redirect IO Thread') }
        end
      end
    end

    # Restore stdout and stderr so text will not be captured and generate a
    # popup. This should be called if redirect_io was called.
    #
    # NOTE: {#closeEvent} automatically calls restore_io if the redirect_io
    # option is set (which means redirect_io was called upon startup).
    #
    # @param stdout [Boolean] Whether to redirect standard output
    # @param stderr [Boolean] Whether to redirect standard error
    def self.restore_io(stdout = true, stderr = true)
      $stdout = STDOUT if stdout
      $stderr = STDERR if stderr
      @@redirect_io_thread_sleeper.cancel
      Qt::CoreApplication.processEvents()
      Cosmos.kill_thread(self, @@redirect_io_thread)
      @@redirect_io_thread = nil
    end

    # Unimplemented to provide this method to all QtTools
    def self.graceful_kill
      # Just to remove warning
    end
  end
end
