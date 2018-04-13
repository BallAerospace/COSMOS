# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/opengl/gl_shape'

module Cosmos
  # Maps an image onto a 3D sphere in OpenGl.
  class TextureMappedSphere < GlShape
    # @param x (see GlShape#initialize)
    # @param y (see GlShape#initialize)
    # @param z (see GlShape#initialize)
    # @param texture_filename [String] Image filename to load and apply to the
    #   sphere
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

      #glTexCoord(lon_value, lat_value)
      return [[lon_value[0], lat_value[0]], [lon_value[1], lat_value[1]], [lon_value[2], lat_value[2]]]
    end

    def draw_triangle(v1, v2, v3)
      glEnable(OpenGL::GL_TEXTURE_2D)
      glPolygonMode(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_FILL)
      glBegin(OpenGL::GL_TRIANGLES)
        tc1, tc2, tc3 = gen_tex_coords(v1, v2, v3)
        glTexCoord2f(tc1[0], tc1[1])
        glVertex3f(v1[0], v1[1], v1[2])
        glTexCoord2f(tc2[0], tc2[1])
        glVertex3f(v2[0], v2[1], v2[2])
        glTexCoord2f(tc3[0], tc3[1])
        glVertex3f(v3[0], v3[1], v3[2])
      glEnd()
      glDisable(OpenGL::GL_TEXTURE_2D);

      #Show Triangles
      #glPolygonMode(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_LINE)
      #glBegin(OpenGL::GL_TRIANGLES)
      #  glVertex(v1)
      #  glVertex(v2)
      #  glVertex(v3)
      #glEnd()
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
      glPushMatrix()
      glShadeModel(OpenGL::GL_FLAT);
      glEnable(OpenGL::GL_DEPTH_TEST);
      if @first == true
        glPixelStorei(OpenGL::GL_UNPACK_ALIGNMENT, 1)
        tex_name_buf = ' ' * 8 # Buffer to hold texture names
        glGenTextures(1, tex_name_buf)
        texName = tex_name_buf.unpack('L2')[0]
        glBindTexture(OpenGL::GL_TEXTURE_2D, texName)
        glTexParameteri(OpenGL::GL_TEXTURE_2D, OpenGL::GL_TEXTURE_WRAP_S, OpenGL::GL_REPEAT)
        glTexParameteri(OpenGL::GL_TEXTURE_2D, OpenGL::GL_TEXTURE_WRAP_T, OpenGL::GL_REPEAT)
        glTexParameteri(OpenGL::GL_TEXTURE_2D, OpenGL::GL_TEXTURE_MAG_FILTER, OpenGL::GL_NEAREST)
        glTexParameteri(OpenGL::GL_TEXTURE_2D, OpenGL::GL_TEXTURE_MIN_FILTER, OpenGL::GL_NEAREST)
        glTexImage2D(OpenGL::GL_TEXTURE_2D, 0, OpenGL::GL_RGBA, @image.width, @image.height, 0, OpenGL::GL_RGBA, OpenGL::GL_UNSIGNED_BYTE, @image_data)

        glTexEnvi(OpenGL::GL_TEXTURE_ENV, OpenGL::GL_TEXTURE_ENV_MODE, OpenGL::GL_DECAL)

        @drawing_list = glGenLists(1)
        glNewList(@drawing_list, OpenGL::GL_COMPILE)
        glEnable(OpenGL::GL_TEXTURE_2D)
        glTexEnvf(OpenGL::GL_TEXTURE_ENV, OpenGL::GL_TEXTURE_ENV_MODE, OpenGL::GL_DECAL)
        glBindTexture(OpenGL::GL_TEXTURE_2D, texName)
        8.times do |index|
          subdivide_triangle(@vdata[@tindices[index][0]], @vdata[@tindices[index][1]], @vdata[@tindices[index][2]], 4)
        end
        glDisable(OpenGL::GL_TEXTURE_2D);
        glEndList()

        @first = false
      end

      glCallList(@drawing_list)

      #Draw Axises
      #glBegin(OpenGL::GL_LINES)
      #  glColor3f(1.0, 0.0, 0.0)
      #  glVertex([-2.0,  0.0,  0.0])
      #  glVertex([ 2.0,  0.0,  0.0])
      #  glVertex([ 0.0, -2.0,  0.0])
      #  glVertex([ 0.0,  2.0,  0.0])
      #  glVertex([ 0.0,  0.0, -2.0])
      #  glVertex([ 0.0,  0.0,  2.0])
      #glEnd()

      glPopMatrix()
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
end
