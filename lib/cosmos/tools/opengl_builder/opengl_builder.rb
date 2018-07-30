# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
Cosmos.catch_fatal_exception do
  require 'cosmos/gui/qt_tool'
  require 'cosmos/gui/choosers/file_chooser'
  require 'cosmos/gui/choosers/float_chooser'
  require 'cosmos/gui/choosers/string_chooser'
  require 'cosmos/gui/dialogs/splash'
  require 'cosmos/gui/dialogs/progress_dialog'
  require 'cosmos/gui/opengl/gl_viewer'
  require 'cosmos/gui/opengl/stl_shape'
  require 'cosmos/gui/opengl/earth_model'
  require 'cosmos/gui/opengl/moon_model'
  require 'cosmos/tools/opengl_builder/scene_config'
end

include Math

module Cosmos

  class OpenGLBuilder < QtTool

    # Constructor
    def initialize (options)
      super(options) # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      Cosmos.load_cosmos_icon("opengl_builder.png")

      @stl_scaling_factor = 1.0
      @bounds = GlBounds.new(-5.0, 5.0, -5.0, 5.0, -5.0, 5.0)
      @scene = GlScene.new
      @previous_selection = nil

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize()

      @earth_scene = GlScene.new
      @earth_scene.append(EarthModel.new(0.0, 0.0, 0.0))

      @moon_scene = GlScene.new
      @moon_scene.append(MoonModel.new(0.0, 0.0, 0.0))

      statusBar.showMessage("")
    end

    def initialize_actions
      super()

      # File Menu
      @file_open = Qt::Action.new('&Open Scene', self)
      @file_open_key_seq = Qt::KeySequence.new('Ctrl+O')
      @file_open.shortcut = @file_open_key_seq
      @file_open.statusTip = 'Open Scene File'
      @file_open.connect(SIGNAL('triggered()')) { file_open() }

      @file_add_shape = Qt::Action.new('&Add Shape', self)
      @file_add_shape_key_seq = Qt::KeySequence.new('Ctrl+A')
      @file_add_shape.shortcut = @file_add_shape_key_seq
      @file_add_shape.statusTip = 'Add a Shape to the Scene'
      @file_add_shape.connect(SIGNAL('triggered()')) { file_add_shape() }

      @file_export = Qt::Action.new('&Export Scene', self)
      @file_export_key_seq = Qt::KeySequence.new('Ctrl+X')
      @file_export.shortcut = @file_export_key_seq
      @file_export.statusTip = 'Export Scene to File'
      @file_export.connect(SIGNAL('triggered()')) { file_export() }

      # View Menu
      @view_perspective = Qt::Action.new('&Perspective', self)
      @view_perspective_key_seq = Qt::KeySequence.new('Ctrl+P')
      @view_perspective.shortcut = @view_perspective_key_seq
      @view_perspective.statusTip = 'Perspective View'
      @view_perspective.connect(SIGNAL('triggered()')) { view_perspective() }

      @view_top = Qt::Action.new('&Top', self)
      @view_top_key_seq = Qt::KeySequence.new('Ctrl+T')
      @view_top.shortcut = @view_top_key_seq
      @view_top.statusTip = 'View From Above'
      @view_top.connect(SIGNAL('triggered()')) { view_top() }

      @view_bottom = Qt::Action.new('&Bottom', self)
      @view_bottom_key_seq = Qt::KeySequence.new('Ctrl+B')
      @view_bottom.shortcut = @view_bottom_key_seq
      @view_bottom.statusTip = 'View From Below'
      @view_bottom.connect(SIGNAL('triggered()')) { view_bottom() }

      @view_front = Qt::Action.new('&Front', self)
      @view_front_key_seq = Qt::KeySequence.new('Ctrl+F')
      @view_front.shortcut = @view_front_key_seq
      @view_front.statusTip = 'View From Front'
      @view_front.connect(SIGNAL('triggered()')) { view_front() }

      @view_back = Qt::Action.new('Bac&k', self)
      @view_back_key_seq = Qt::KeySequence.new('Ctrl+W')
      @view_back.shortcut = @view_back_key_seq
      @view_back.statusTip = 'View From Back'
      @view_back.connect(SIGNAL('triggered()')) { view_back() }

      @view_left = Qt::Action.new('&Left', self)
      @view_left_key_seq = Qt::KeySequence.new('Ctrl+L')
      @view_left.shortcut = @view_left_key_seq
      @view_left.statusTip = 'View From Left'
      @view_left.connect(SIGNAL('triggered()')) { view_left() }

      @view_right = Qt::Action.new('&Right', self)
      @view_right_key_seq = Qt::KeySequence.new('Ctrl+R')
      @view_right.shortcut = @view_right_key_seq
      @view_right.statusTip = 'View From Right'
      @view_right.connect(SIGNAL('triggered()')) { view_right() }

      # Show Menu
      @show_scene = Qt::Action.new('Show &Scene', self)
      @show_scene_key_seq = Qt::KeySequence.new('Ctrl+S')
      @show_scene.shortcut = @show_scene_key_seq
      @show_scene.statusTip = 'Show the Normal Scene'
      @show_scene.connect(SIGNAL('triggered()')) { show_scene() }

      @show_earth = Qt::Action.new('Show &Earth', self)
      @show_earth_key_seq = Qt::KeySequence.new('Ctrl+E')
      @show_earth.shortcut = @show_earth_key_seq
      @show_earth.statusTip = 'Show the Earth'
      @show_earth.connect(SIGNAL('triggered()')) { show_earth() }

      @show_moon = Qt::Action.new('Show &Moon', self)
      @show_moon_key_seq = Qt::KeySequence.new('Ctrl+M')
      @show_moon.shortcut = @show_moon_key_seq
      @show_moon.statusTip = 'Show the Moon'
      @show_moon.connect(SIGNAL('triggered()')) { show_moon() }
    end

    def initialize_menus
      # File Menu
      @file_menu = menuBar.addMenu('&File')
      @file_menu.addAction(@file_open)
      @file_menu.addAction(@file_add_shape)
      @file_menu.addAction(@file_export)
      @file_menu.addSeparator()
      @file_menu.addAction(@exit_action)

      # View Menu
      @view_menu = menuBar.addMenu('&View')
      @view_menu.addAction(@view_perspective)
      @view_menu.addAction(@view_top)
      @view_menu.addAction(@view_bottom)
      @view_menu.addAction(@view_front)
      @view_menu.addAction(@view_back)
      @view_menu.addAction(@view_left)
      @view_menu.addAction(@view_right)

      # Show Menu
      @show_menu = menuBar.addMenu('&Show')
      @show_menu.addAction(@show_scene)
      @show_menu.addAction(@show_earth)
      @show_menu.addAction(@show_moon)

      # Help Menu
      @about_string = "OpenGL Builder is an example application using OpenGL"
      initialize_help_menu()
    end

    def initialize_central_widget
      # Create the central widget
      @central_widget = Qt::Widget.new
      setCentralWidget(@central_widget)
      @top_layout = Qt::VBoxLayout.new
      @central_widget.setLayout(@top_layout)

      @viewer = GlViewer.new(self)
      @viewer.draw_axis = 15
      @viewer.scene = @scene
      @viewer.selection_callback = method(:selection_callback)
      @top_layout.addWidget(@viewer)
    end

    def keyPressEvent(event)
      selection = @viewer.selection
      if selection
        color = selection.base_color.clone

        case event.text
        when 'x'
          rotation = selection.rotation_x
          rotation = 0.0 unless rotation
          selection.rotation_x = rotation + 1.0

        when 'X'
          rotation = selection.rotation_x
          rotation = 0.0 unless rotation
          selection.rotation_x = rotation - 1.0

        when 'y'
          rotation = selection.rotation_y
          rotation = 0.0 unless rotation
          selection.rotation_y = rotation + 1.0

        when 'Y'
          rotation = selection.rotation_y
          rotation = 0.0 unless rotation
          selection.rotation_y = rotation - 1.0

        when 'z'
          rotation = selection.rotation_z
          rotation = 0.0 unless rotation
          selection.rotation_z = rotation + 1.0

        when 'Z'
          rotation = selection.rotation_z
          rotation = 0.0 unless rotation
          selection.rotation_z = rotation - 1.0

        when *%w(r R g G b B a A)
          index = 0 # r R
          index = 1 if %w(g G).include?(event.text)
          index = 2 if %w(b B).include?(event.text)
          index = 3 if %w(a A).include?(event.text)

          if %w(R G B A).include?(event.text)
            value = 1.0
            increment = 0.05
          else
            value = 0.0
            # Minimum alpha value shouldn't go to 0 or it disappears
            value = 0.05 if event.text == 'a'
            increment = -0.05
          end

          color[index] += increment
          if value == 1.0
            color[index] = value if color[index] > value
          else
            color[index] = value if color[index] < value
          end
          selection.base_color = color.clone
          selection.color = selection.base_color.clone
          statusBar.showMessage("Color: [#{color[0]} #{color[1]} #{color[2]} #{color[3]}]")

        # TODO: Mouseover tip text is currently not supported in QT OpenGL
        #when 't'
        #  dialog = Qt::Dialog.new(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
        #  dialog.setWindowTitle('Set Tip Text...')

        #  dialog_layout = Qt::VBoxLayout.new
        #  string_chooser = StringChooser.new(dialog, 'TipText:', selection.tipText.to_s, 60, true)
        #  dialog_layout.addWidget(string_chooser)

        #  button_layout = Qt::HBoxLayout.new
        #  ok = Qt::PushButton.new("Ok")
        #  ok.connect(SIGNAL('clicked()')) { dialog.accept() }
        #  button_layout.addWidget(ok)
        #  cancel = Qt::PushButton.new("Cancel")
        #  cancel.connect(SIGNAL('clicked()')) { dialog.reject() }
        #  button_layout.addWidget(cancel)
        #  dialog_layout.addLayout(button_layout)
        #  dialog.setLayout(dialog_layout)

        #  if dialog.exec == Qt::Dialog::Accepted
        #    tipText = string_chooser.string
        #    if tipText.to_s.empty?
        #      selection.tipText = nil
        #    else
        #      selection.tipText = tipText
        #    end
        #  end
        #  dialog.dispose

        end # case event.text

      end # if selection

    end # def keyPressEvent

    def file_open
      filename = Qt::FileDialog.getOpenFileName(self, "Open Scene File:", File.join(USERPATH, 'config', 'tools', 'opengl_builder'), "Scene Files (*.txt);;All Files (*)")
      if !filename.to_s.empty?
        begin
          scene_config = SceneConfig.new(filename)
          @scene = scene_config.scene
          @viewer.scene = @scene
        rescue Exception => error
          ExceptionDialog.new(self, error, "Error Loading Scene", false)
        end
      end
    end

    def file_add_shape
      dialog = Qt::Dialog.new(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      dialog.setWindowTitle('Add Shape...')

      dialog_layout = Qt::VBoxLayout.new
      scaling_chooser = FloatChooser.new(dialog, 'STL Scaling Factor:', @stl_scaling_factor)
      file_chooser = FileChooser.new(dialog, 'STL File:', '', 'Select STL File', File.join(USERPATH, 'config', 'data'), 60, false, "STL Files (*.STL);;All Files (*)")
      dialog_layout.addWidget(scaling_chooser)
      dialog_layout.addWidget(file_chooser)

      button_layout = Qt::HBoxLayout.new
      ok = Qt::PushButton.new("Ok")
      ok.connect(SIGNAL('clicked()')) do
        dialog.accept()
      end
      button_layout.addWidget(ok)
      cancel = Qt::PushButton.new("Cancel")
      cancel.connect(SIGNAL('clicked()')) do
        dialog.reject()
      end
      button_layout.addWidget(cancel)
      dialog_layout.addLayout(button_layout)
      dialog.setLayout(dialog_layout)

      if dialog.exec == Qt::Dialog::Accepted
        filename = file_chooser.filename
        if !filename.to_s.empty?
          shape = StlShape.new(0.0, 0.0, 0.0)
          shape.stl_file = filename
          shape.color = [0.0, 0.7, 0.0, 1.0]
          shape.dragable = true
          shape.show_load_progress = true
          shape.tipText = filename
          @stl_scaling_factor = scaling_chooser.value
          shape.stl_scaling_factor = @stl_scaling_factor
          @scene.append(shape)
          @viewer.update
        end
      end
      dialog.dispose
    end

    def file_export
      filename = Qt::FileDialog.getSaveFileName(self, "Export Scene to File", File.join(USERPATH, 'config', 'tools', 'opengl_builder', 'scene.txt'), "Scene Files (*.txt);;All Files (*)")
      if !filename.to_s.empty?
        string  = "ZOOM #{@viewer.zoom}\n"
        orientation = @viewer.orientation
        string << "ORIENTATION #{orientation.q0} #{orientation.q1} #{orientation.q2} #{orientation.q3}\n"
        center = @viewer.center
        string << "CENTER #{center[0]} #{center[1]} #{center[2]}\n"
        string << "BOUNDS #{@bounds[0]} #{@bounds[1]} #{@bounds[2]} #{@bounds[3]} #{@bounds[4]} #{@bounds[5]}\n\n"

        @scene.each do |shape|
          string << shape.export
          string << "\n"
        end
        File.open(filename, 'w') do |file|
          file.write(string)
        end
      end
    end

    def view_perspective
      @viewer.orientation = Quaternion.new([1.0, 1.0, 0.0], 0.8)
    end

    def view_top
      @viewer.orientation = Quaternion.new([1.0, 0.0, 0.0], PI/2)
    end

    def view_bottom
      @viewer.orientation = Quaternion.new([1.0, 0.0, 0.0], -PI/2)
    end

    def view_front
      @viewer.orientation = Quaternion.new([1.0, 0.0, 0.0], 0.0)
    end

    def view_back
      @viewer.orientation = Quaternion.new([1.0, 0.0, 0.0], PI)
    end

    def view_left
      @viewer.orientation = Quaternion.new([0.0, 1.0, 0.0], PI/2)
    end

    def view_right
      @viewer.orientation = Quaternion.new([0.0, 1.0, 0.0], -PI/2)
    end

    def show_scene
      @viewer.scene = @scene
    end

    def show_earth
      @viewer.scene = @earth_scene
    end

    def show_moon
      @viewer.scene = @moon_scene
    end

    def selection_callback(shape)
      @previous_selection.color = @previous_selection.base_color.clone if @previous_selection
      shape.color = [1.0, 0.0, 0.0, 1.0] if shape
      @previous_selection = shape
    end

    # Runs the application
    def self.run (option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.title = "OpenGL Builder"
        end
        super(option_parser, options)
      end
    end

  end # class OpenGLBuilder

end # module Cosmos
