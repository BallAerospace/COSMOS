# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/opengl/gl_shape'

module Cosmos

  class TextureMappedSphere < GlShape

    def initialize(x, y, z, texture_filename)
      super(x, y, z)

      @vdata = [ [1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [-1.0, 0.0, 0.0], [0.0, -1.0, 0.0],
                 [0.0, 0.0, 1.0], [0.0, 0.0, -1.0]]

      @tindices = [ [0,4,1], [1,4,2], [2,4,3], [3,4,0], [1,5,0],
                    [2,5,1], [3,5,2], [0,5,3] ]

      @texture_filename = texture_filename
      @image = Qt::Image.new(texture_filename)
      @image_data = @image.bits.unpack("C*")
      index = 0
      length = @image_data.length
      while index < length
        temp = @image_data[index]
        @image_data[index] = @image_data[index + 2]
        @image_data[index + 2] = temp
        index += 4
      end
      @image_data = @image_data.pack("C*")
      @first = true
    end

    def normalize(v)
      normal = []

      d = sqrt((v[0] * v[0]) + (v[1] * v[1]) + (v[2] * v[2]))

      if (d == 0.0)
        puts "Error Zero Length Vector"
        normal = v
      else
        normal[0] = v[0] / d
        normal[1] = v[1] / d
        normal[2] = v[2] / d
      end

      return normal
    end

    def gen_tex_coords(*v)
      lon_value = []
      lat_value = []

      3.times do |index|
        lon = Math.atan2(v[index][1], v[index][0]) + PI # 0 to 360
        lat = Math.acos(v[index][2]) # 0 to 180
        lon_value[index] = lon / (2 * PI)
        lat_value[index] = lat / PI
      end

      if ((lon_value[0] - lon_value[1]).abs > 0.5) or ((lon_value[1] - lon_value[2]).abs > 0.5) or ((lon_value[0] - lon_value[2]).abs > 0.5)
        if (lon_value[0] < 0.5)
          lon_value[0] += 1.0
        end
        if (lon_value[1] < 0.5)
          lon_value[1] += 1.0
        end
        if (lon_value[2] < 0.5)
          lon_value[2] += 1.0
        end
      end

      if lat_value[0] > 0.99 or lat_value[0] < 0.01
        lon_value[0] = (lon_value[1] + lon_value[2]) / 2.0
      end
      if lat_value[1] > 0.99 or lat_value[1] < 0.01
        lon_value[1] = (lon_value[0] + lon_value[2]) / 2.0
      end
      if lat_value[2] > 0.99 or lat_value[2] < 0.01
        lon_value[2] = (lon_value[1] + lon_value[0]) / 2.0
      end

      #GL::TexCoord(lon_value, lat_value)
      return [[lon_value[0], lat_value[0]], [lon_value[1], lat_value[1]], [lon_value[2], lat_value[2]]]
    end

    def draw_triangle(v1, v2, v3)
      GL.Enable(GL::TEXTURE_2D)
      GL.PolygonMode(GL::FRONT_AND_BACK, GL::FILL)
      GL::Begin(GL::TRIANGLES)
        tc1, tc2, tc3 = gen_tex_coords(v1, v2, v3)
        GL::TexCoord(tc1[0], tc1[1])
        GL::Vertex(v1)
        GL::TexCoord(tc2[0], tc2[1])
        GL::Vertex(v2)
        GL::TexCoord(tc3[0], tc3[1])
        GL::Vertex(v3)
      GL::End()
      GL.Disable(GL::TEXTURE_2D);

      #Show Triangles
      #GL.PolygonMode(GL::FRONT_AND_BACK, GL::LINE)
      #GL::Begin(GL::TRIANGLES)
      #  GL::Vertex(v1)
      #  GL::Vertex(v2)
      #  GL::Vertex(v3)
      #GL::End()
    end

    def subdivide_triangle(v1, v2, v3, depth)
      v12 = []
      v23 = []
      v31 = []

      if (depth == 0)
        draw_triangle(v1, v2, v3)
        return
      end

      3.times do |index|
        v12[index] = v1[index] + v2[index]
        v23[index] = v2[index] + v3[index]
        v31[index] = v3[index] + v1[index]
      end

      v12 = normalize(v12)
      v23 = normalize(v23)
      v31 = normalize(v31)
      subdivide_triangle(v1,  v12, v31, depth - 1)
      subdivide_triangle(v2,  v23, v12, depth - 1)
      subdivide_triangle(v3,  v31, v23, depth - 1)
      subdivide_triangle(v12, v23, v31, depth - 1)
    end

    def drawshape(viewer)
      GL.PushMatrix
      GL.ShadeModel(GL::FLAT);
      GL.Enable(GL::DEPTH_TEST);
      if @first == true
        GL.PixelStore(GL::UNPACK_ALIGNMENT, 1)
        texName = GL::GenTextures(1)
        GL::BindTexture(GL::TEXTURE_2D, texName[0])
        GL.TexParameter(GL::TEXTURE_2D, GL::TEXTURE_WRAP_S, GL::REPEAT);
        GL.TexParameter(GL::TEXTURE_2D, GL::TEXTURE_WRAP_T, GL::REPEAT);
        GL.TexParameter(GL::TEXTURE_2D, GL::TEXTURE_MAG_FILTER, GL::NEAREST);
        GL.TexParameter(GL::TEXTURE_2D, GL::TEXTURE_MIN_FILTER, GL::NEAREST);
        GL::TexImage2D(GL::TEXTURE_2D, 0, GL::RGBA, @image.width, @image.height, 0, GL::RGBA, GL::UNSIGNED_BYTE, @image_data)

        GL::TexEnv(GL::TEXTURE_ENV, GL::TEXTURE_ENV_MODE, GL::DECAL)

        @drawing_list = GL.GenLists(1)
        GL.NewList(@drawing_list, GL::COMPILE)
        GL.Enable(GL::TEXTURE_2D);
        GL.TexEnvf(GL::TEXTURE_ENV, GL::TEXTURE_ENV_MODE, GL::DECAL);
        GL::BindTexture(GL::TEXTURE_2D, texName[0])
        8.times do |index|
          subdivide_triangle(@vdata[@tindices[index][0]], @vdata[@tindices[index][1]], @vdata[@tindices[index][2]], 4)
        end
        GL.Disable(GL::TEXTURE_2D);
        GL.EndList

        @first = false
      end

      GL.CallList(@drawing_list)

      #Draw Axises
      #GL::Begin(GL::LINES)
      #  GL::Color3f(1.0, 0.0, 0.0)
      #  GL::Vertex([-2.0,  0.0,  0.0])
      #  GL::Vertex([ 2.0,  0.0,  0.0])
      #  GL::Vertex([ 0.0, -2.0,  0.0])
      #  GL::Vertex([ 0.0,  2.0,  0.0])
      #  GL::Vertex([ 0.0,  0.0, -2.0])
      #  GL::Vertex([ 0.0,  0.0,  2.0])
      #GL::End()

      GL.PopMatrix
    end

    def export
      string =  "TEXTURE_MAPPED_SPHERE \"#{@texture_filename}\"\n"
      string << "  TIP_TEXT \"#{@tipText}\"\n" if @tipText
      string << "  POSITION #{self.position[0]} #{self.position[1]} #{self.position[2]}\n"
      string << "  ROTATION_X #{@rotation_x}\n" if @rotation_x
      string << "  ROTATION_Y #{@rotation_y}\n" if @rotation_y
      string << "  ROTATION_Z #{@rotation_z}\n" if @rotation_z
      return string
    end

  end

end # module Cosmos
