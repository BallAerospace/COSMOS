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
  # Defines an OpenGL shape including its color, position and how to draw it.
  # These objects should be used within a {GlScene}.
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

    # Create a OpenGL shape to be placed in a {GlScene}.
    # @param x [Integer] Shape center X position
    # @param y [Integer] Shape center Y position
    # @param z [Integer] Shape center Z position
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
      glPushAttrib(OpenGL::GL_CURRENT_BIT | OpenGL::GL_LIGHTING_BIT | OpenGL::GL_POINT_BIT | OpenGL::GL_LINE_BIT)
      glPushMatrix

      # Object position
      glTranslatef(@position[0], @position[1], @position[2])

      # Shading
      glEnable(OpenGL::GL_LIGHTING)
      glEnable(OpenGL::GL_AUTO_NORMAL)
      glShadeModel(OpenGL::GL_SMOOTH)

      # Material
      if @back_material
        glMaterialfv(OpenGL::GL_FRONT, OpenGL::GL_AMBIENT, @front_material.ambient.pack('F*'))
        glMaterialfv(OpenGL::GL_FRONT, OpenGL::GL_DIFFUSE, @front_material.diffuse.pack('F*'))
        glMaterialfv(OpenGL::GL_FRONT, OpenGL::GL_SPECULAR, @front_material.specular.pack('F*'))
        glMaterialfv(OpenGL::GL_FRONT, OpenGL::GL_EMISSION, @front_material.emission.pack('F*'))
        glMaterialfvf(OpenGL::GL_FRONT, OpenGL::GL_SHININESS, @front_material.shininess)
        glMaterialfv(OpenGL::GL_BACK, OpenGL::GL_AMBIENT, @back_material.ambient.pack('F*'))
        glMaterialfv(OpenGL::GL_BACK, OpenGL::GL_DIFFUSE, @back_material.diffuse.pack('F*'))
        glMaterialfv(OpenGL::GL_BACK, OpenGL::GL_SPECULAR, @back_material.specular.pack('F*'))
        glMaterialfv(OpenGL::GL_BACK, OpenGL::GL_EMISSION, @back_material.emission.pack('F*'))
        glMaterialf(OpenGL::GL_BACK, OpenGL::GL_SHININESS, @back_material.shininess)
      else
        glMaterialfv(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_AMBIENT, @front_material.ambient.pack('F*'))
        glMaterialfv(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_DIFFUSE, @front_material.diffuse.pack('F*'))
        glMaterialfv(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_SPECULAR, @front_material.specular.pack('F*'))
        glMaterialfv(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_EMISSION, @front_material.emission.pack('F*'))
        glMaterialf(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_SHININESS, @front_material.shininess)
      end

      # Surface
      glPolygonMode(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_FILL)
      glDisable(OpenGL::GL_CULL_FACE);
      drawshape(viewer)

      # Restore attributes and matrix
      glPopMatrix
      glPopAttrib
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
  end
end
