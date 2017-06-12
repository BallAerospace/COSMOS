# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/gui/opengl/gl_shape'
require 'cosmos/gui/opengl/stl_reader'
require 'cosmos/gui/dialogs/progress_dialog'

module Cosmos
  # Uses a {StlReader} to read a STL file and create an OpenGL shape which can
  # be rendered in a scene.
  class StlShape < GlShape
    @@splash = nil

    attr_accessor :stl_file
    attr_accessor :stl_scaling_factor
    attr_accessor :show_load_progress
    attr_accessor :window

    def initialize(x, y, z)
      super(x, y, z)
      @mystl = StlReader.new
      @show_load_progress = false
      @stl_scaling_factor = 1.0
      @stl_file = nil
      @progress_dialog = nil
    end

    def load_stl
      if @show_load_progress
        load_setup()
        estimate = @mystl.estimate_num_triangles(@stl_file)
        total_read = 0
        num_read = 1
        while num_read > 0
          num_read = @mystl.process_with_progress(@stl_file, @stl_scaling_factor)
          total_read += num_read
          progress = total_read.to_f / estimate.to_f
          if @@splash
            @@splash.progress = progress
          else
            @progress_dialog.set_overall_progress(progress)
          end
        end
        if @progress_dialog
          Qt.execute_in_main_thread(true) do
            @progress_dialog.dispose
          end
        end
        @progress_dialog = nil
      else
        @mystl.process(@stl_file, @stl_scaling_factor)
      end
    end

    # Draw the StlShape
    def drawshape(viewer)
      @viewer = viewer

      GL.PushMatrix
        GL.Enable(GL::BLEND)
        GL.BlendFunc(GL::SRC_ALPHA, GL::ONE_MINUS_SRC_ALPHA)
        GL.Color4f(@color[0], @color[1], @color[2], @color[3])
        GL.Rotate(@rotation_x, 1.0, 0.0, 0.0) if @rotation_x
        GL.Rotate(@rotation_y, 0.0, 1.0, 0.0) if @rotation_y
        GL.Rotate(@rotation_z, 0.0, 0.0, 1.0) if @rotation_z
        GL.Material(GL::FRONT_AND_BACK, GL::AMBIENT_AND_DIFFUSE, @color)
        draw_stl()
        GL.Disable(GL::BLEND)
      GL.PopMatrix
    end

    def export
      string =  "STL_FILE \"#{@stl_file}\" #{@stl_scaling_factor}\n"
      string << "  TIP_TEXT \"#{@tipText}\"\n" if @tipText
      string << "  COLOR #{color[0]} #{color[1]} #{color[2]} #{color[3]}\n"
      string << "  POSITION #{self.position[0]} #{self.position[1]} #{self.position[2]}\n"
      string << "  ROTATION_X #{@rotation_x}\n" if @rotation_x
      string << "  ROTATION_Y #{@rotation_y}\n" if @rotation_y
      string << "  ROTATION_Z #{@rotation_z}\n" if @rotation_z
      return string
    end

    def self.splash=(splash)
      @@splash = splash
    end

    protected

    def load_setup
      @box = nil
      @bar = nil

      unless @@splash
        @progress_dialog = ProgressDialog.new(Qt::CoreApplication.instance.activeWindow, "Loading STL File", 500, 300, true, false, true, false, false)
        @progress_dialog.show
        @progress_dialog.raise
        @progress_dialog.append_text("Loading #{@stl_file}")
        @progress_dialog.set_overall_progress(0.0)
      else
        @@splash.message = "Loading #{@stl_file}"
        @@splash.progress = 0.0
      end
    end

    def draw_stl
      GL.PushMatrix
      GL.Material(GL::FRONT_AND_BACK, GL::SPECULAR, [1.0, 1.0, 1.0])
      GL.Material(GL::FRONT_AND_BACK, GL::SHININESS, [100.0])
      if @mystl.triangles.empty?
        load_stl
      else
        @mystl.draw_triangles()
      end
      GL.PopMatrix

      # Set Pixel Storage Size
      GL.PixelStorei(GL::UNPACK_ALIGNMENT, 1)
    end
  end
end
