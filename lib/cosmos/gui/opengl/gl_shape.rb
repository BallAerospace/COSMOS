# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/opengl/opengl'

module Cosmos

  class GlShape
    attr_accessor :base_color
    attr_accessor :click_handler
    attr_accessor :doubleclick_handler
    attr_reader :color
    attr_accessor :position
    attr_reader :rotation_x
    attr_reader :rotation_y
    attr_reader :rotation_z
    attr_accessor :tipText
    attr_accessor :dragable

    #Constructor for the StlShape class
    def initialize(x, y, z)
      @color = [0.5, 0.5, 0.5, 1.0]
      @base_color = [0.5, 0.5, 0.5, 1.0]
      @position = [x, y, z]
      @rotation_x = nil
      @rotation_y = nil
      @rotation_z = nil
      @viewer = nil
      @front_material = GlMaterial.new
      @back_material = nil
      @tipText = nil
      @dragable = true
    end

    def draw(viewer)
      GL.PushAttrib(GL::CURRENT_BIT | GL::LIGHTING_BIT | GL::POINT_BIT | GL::LINE_BIT)
      GL.PushMatrix

      # Object position
      GL::Translatef(@position[0], @position[1], @position[2])

      # Shading
      GL.Enable(GL::LIGHTING)
      GL.Enable(GL::AUTO_NORMAL)
      GL.ShadeModel(GL::SMOOTH)

      # Material
      if @back_material
        GL.Material(GL::FRONT, GL::AMBIENT, @front_material.ambient)
        GL.Material(GL::FRONT, GL::DIFFUSE, @front_material.diffuse)
        GL.Material(GL::FRONT, GL::SPECULAR, @front_material.specular)
        GL.Material(GL::FRONT, GL::EMISSION, @front_material.emission)
        GL.Materialf(GL::FRONT, GL::SHININESS, @front_material.shininess)
        GL.Material(GL::BACK, GL::AMBIENT, @back_material.ambient)
        GL.Material(GL::BACK, GL::DIFFUSE, @back_material.diffuse)
        GL.Material(GL::BACK, GL::SPECULAR, @back_material.specular)
        GL.Material(GL::BACK, GL::EMISSION, @back_material.emission)
        GL.Materialf(GL::BACK, GL::SHININESS, @back_material.shininess)
      else
        GL.Material(GL::FRONT_AND_BACK, GL::AMBIENT, @front_material.ambient)
        GL.Material(GL::FRONT_AND_BACK, GL::DIFFUSE, @front_material.diffuse)
        GL.Material(GL::FRONT_AND_BACK, GL::SPECULAR, @front_material.specular)
        GL.Material(GL::FRONT_AND_BACK, GL::EMISSION, @front_material.emission)
        GL.Materialf(GL::FRONT_AND_BACK, GL::SHININESS, @front_material.shininess)
      end

      # Surface
      GL.PolygonMode(GL::FRONT_AND_BACK, GL::FILL)
      GL.Disable(GL::CULL_FACE);
      drawshape(viewer)

      # Restore attributes and matrix
      GL.PopMatrix
      GL.PopAttrib
    end

    # Draw the StlShape
    def drawshape(viewer)
      raise "drawshape must be implemented by subclass"
    end

    def hit(viewer)
      draw(viewer)
    end

    def identify
      return self
    end

    def drag(viewer, fx, fy, tx, ty)
      if @dragable
        zz = viewer.worldToEyeZ(@position)
        wf = viewer.eyeToWorld(viewer.screenToEye(fx, fy, zz))
        wt = viewer.eyeToWorld(viewer.screenToEye(tx, ty, zz))
        wt_minus_wf = [wt[0] - wf[0], wt[1] - wf[1], wt[2] - wf[2]]
        @position = [@position[0] + wt_minus_wf[0], @position[1] + wt_minus_wf[1], @position[2] + wt_minus_wf[2]]
        return true
      else
        return false
      end
    end

    def handle_click
      @click_handler.call() if @click_handler
    end

    def handle_doubleclick
      @doubleclick_handler.call() if @doubleclick_handler
    end

    def color= (new_color)
      new_color[3] = 1.0 unless new_color[3]
      @color = new_color
      @viewer.update if @viewer
    end

    def rotation_x= (rotation)
      @rotation_x = rotation
      @viewer.update if @viewer
    end

    def rotation_y= (rotation)
      @rotation_y = rotation
      @viewer.update if @viewer
    end

    def rotation_z= (rotation)
      @rotation_z = rotation
      @viewer.update if @viewer
    end

    def export
      raise "export must be defined by subclass"
    end

  end # Shape

end # module Cosmos
