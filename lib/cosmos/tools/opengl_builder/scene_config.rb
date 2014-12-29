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
require 'cosmos/gui/opengl/stl_shape'
require 'cosmos/gui/opengl/texture_mapped_sphere'

module Cosmos

  class SceneConfig

    attr_accessor :scene

    def initialize(filename, dragable = true)
      @scene = GlScene.new

      shape = nil
      parser = ConfigParser.new
      parser.parse_file(filename) do |keyword, parameters|
        case keyword
        when 'STL_FILE'
          usage = "#{keyword} <filename> <scaling factor (optional)>"
          parser.verify_num_parameters(1, 2, usage)
          shape = StlShape.new(0.0, 0.0, 0.0)
          if parameters[0] =~ /^\// or parameters[0] =~ /^\w:/
            shape.stl_file = parameters[0]
          else
            shape.stl_file = File.join(Cosmos::USERPATH, 'config', 'data', parameters[0])
          end
          raise "STL File \"#{shape.stl_file}\" does not exist" unless File.exist? shape.stl_file
          shape.show_load_progress = true
          shape.tipText = parameters[0]
          shape.dragable = dragable
          if parameters[1]
            shape.stl_scaling_factor = parameters[1].to_f
          end
          @scene.append(shape)

        when 'TEXTURE_MAPPED_SPHERE'
          usage = "#{keyword} <texture_filename>"
          parser.verify_num_parameters(1, 1, usage)
          shape = TextureMappedSphere.new(0.0, 0.0, 0.0, parameters[0])
          shape.dragable = dragable
          @scene.append(shape)

        when 'TIP_TEXT'
          usage = "#{keyword} <text>"
          parser.verify_num_parameters(1, 1, usage)
          shape.tipText = parameters[0]

        when 'COLOR'
          usage = "#{keyword} <red> <green> <blue> <alpha (optional)>"
          parser.verify_num_parameters(3, 4, usage)
          if parameters[3]
            shape.base_color = [parameters[0].to_f, parameters[1].to_f, parameters[2].to_f, parameters[3].to_f]
          else
            shape.base_color = [parameters[0].to_f, parameters[1].to_f, parameters[2].to_f, 1.0]
          end
          shape.color = shape.base_color.clone

        when 'POSITION'
          usage = "#{keyword} <x> <y> <z>"
          parser.verify_num_parameters(3, 3, usage)
          shape.position = [parameters[0].to_f, parameters[1].to_f, parameters[2].to_f]

        when 'ROTATION_X'
          usage = "#{keyword} <rotation_x>"
          parser.verify_num_parameters(1, 1, usage)
          shape.rotation_x = parameters[0].to_f

        when 'ROTATION_Y'
          usage = "#{keyword} <rotation_y>"
          parser.verify_num_parameters(1, 1, usage)
          shape.rotation_y = parameters[0].to_f

        when 'ROTATION_Z'
          usage = "#{keyword} <rotation_z>"
          parser.verify_num_parameters(1, 1, usage)
          shape.rotation_z = parameters[0].to_f

        when 'ZOOM'
          usage = "#{keyword} <zoom>"
          parser.verify_num_parameters(1, 1, usage)
          @scene.zoom = parameters[0].to_f

        when 'ORIENTATION'
          usage = "#{keyword} <q0> <q1> <q2> <q3 - scalar>"
          parser.verify_num_parameters(4, 4, usage)
          @scene.orientation = Quaternion.new([parameters[0].to_f, parameters[1].to_f, parameters[2].to_f, parameters[3].to_f])

        when 'CENTER'
          usage = "#{keyword} <x> <y> <z>"
          parser.verify_num_parameters(3, 3, usage)
          @scene.center = [parameters[0].to_f, parameters[1].to_f, parameters[2].to_f]

        when 'BOUNDS'
          usage = "#{keyword} <x0> <x1> <y0> <y1> <z0> <z1>"
          parser.verify_num_parameters(6, 6, usage)
          @scene.bounds = GlBounds.new(parameters[0].to_f, parameters[1].to_f, parameters[2].to_f, parameters[3].to_f, parameters[4].to_f, parameters[5].to_f)

        else
          raise "Unknown keyword #{keyword} with parameters #{parameters.join(' ')}"
        end # case keyword
      end # parser.parse_file

    end

  end # class SceneDefinition

end # module Cosmos
