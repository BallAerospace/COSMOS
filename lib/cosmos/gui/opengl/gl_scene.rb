# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/gui/opengl/gl_bounds'

module Cosmos
  # Creates an OpenGL scene with associated shapes. It defers to the shapes to
  # draw themselves.
  class GlScene
    # @return [Array<GlShape>] Shapes to draw in the scene
    attr_reader :shapes
    # @return [GlBounds] Bounds of the scene
    attr_accessor :bounds
    # @return [Integer] Zoom factor
    attr_accessor :zoom
    # @return [Quaternion] Orientation of the scene
    attr_accessor :orientation
    # @return [Array<Float, Float, Float>] Center of the scene
    attr_accessor :center
    # @return [Symbol] The type of projection matrix to use :PARALLEL or :PERSPECTIVE
    attr_accessor :projection

    def initialize
      @shapes = []
      @bounds = GlBounds.new(-5.0, 5.0, -5.0, 5.0, -5.0, 5.0)
      @zoom = 1.0
      @orientation = Quaternion.new([0.0, 0.0, 0.0, 1.0])
      @center = [0.0, 0.0, 0.0]
      @projection = :PARALLEL
    end

    def draw(viewer)
      @shapes.each do |shape|
        if shape.color[3] > 0.96
          shape.draw(viewer)
        end
      end
      @shapes.each do |shape|
        if shape.color[3] <= 0.96
          shape.draw(viewer)
        end
      end
    end

    def hit(viewer)
      GL.PushName(0xffffffff);
      @shapes.each_with_index do |shape, index|
        GL.LoadName(index)
        shape.hit(viewer)
      end
      GL.PopName()
    end

    def identify(index)
      if @shapes[index]
        return @shapes[index].identify
      end
      return nil
    end

    def each
      @shapes.each do |shape|
        yield shape
      end
    end

    def append(shape)
      @shapes << shape
    end
  end
end
