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

  class StlReader

    attr_accessor :triangles
    attr_accessor :use_cache

    @@files = {}

    def initialize
      @triangles = []
      @file = nil
      @is_ascii = nil
      @packet = nil
      @num_facets = nil
      @use_cache = true
    end

    def build_triangles(filename, scaling_factor = 1.0)
      if @@files[filename].nil? or !@use_cache
        @triangles = []
        @is_ascii = File.is_ascii?(filename)
        if @is_ascii
          @file = File.new(filename, 'r')
        else
          @file = File.new(filename, 'rb')
        end
        read_triangles(4000000000, scaling_factor)
        @file.close
        @file = nil
        @@files.delete_if {|key, stl_reader| stl_reader == self}
        @@files[filename] = self
      else
        @triangles = @@files[filename].triangles
      end
    end

    def prep_vertex_arrays
      @normals = []
      @vertexes = []
      @triangles.each do |triangle|
        @normals.concat(triangle[0])
        @normals.concat(triangle[0])
        @normals.concat(triangle[0])
        @vertexes.concat(triangle[1])
        @vertexes.concat(triangle[2])
        @vertexes.concat(triangle[3])
      end
      @normals_packed = @normals.pack('f*')
      @vertexes_packed = @vertexes.pack('f*')
    end

    def draw_triangles
      GL.EnableClientState(GL::NORMAL_ARRAY)
      GL.EnableClientState(GL::VERTEX_ARRAY)
      GL.NormalPointer(GL::FLOAT, 0, @normals_packed)
      GL.VertexPointer(3, GL::FLOAT, 0, @vertexes_packed)
      GL.DrawArrays(GL::TRIANGLES, 0, @triangles.length * 3)
      GL.DisableClientState(GL::NORMAL_ARRAY)
      GL.DisableClientState(GL::VERTEX_ARRAY)
    end

    def process(filename, scaling_factor = 1.0)
      build_triangles(filename, scaling_factor)
      prep_vertex_arrays()
      draw_triangles()
    end

    def process_with_progress(filename, scaling_factor = 1.0)
      num_read = 0
      if @@files[filename].nil? or !@use_cache
        @is_ascii = File.is_ascii?(filename)
        if @file.nil?
          if @is_ascii
            @file = File.new(filename, 'r')
          else
            @file = File.new(filename, 'rb')
          end
          @triangles = []
        end

        num_read = read_triangles(1000, scaling_factor)
        if num_read == 0
          @file.close
          @file = nil
          prep_vertex_arrays()
          draw_triangles()
          @@files.delete_if {|key, stl_reader| stl_reader == self}
          @@files[filename] = self
        end
      else
        @triangles = @@files[filename].triangles
        prep_vertex_arrays()
        draw_triangles()
      end
      return num_read
    end

    def estimate_num_triangles(filename)
      @is_ascii = File.is_ascii?(filename)
      stat = File.stat(filename)
      if @is_ascii
        return (stat.size / 268).to_i + 1
      else
        return (stat.size / 50).to_i + 1
      end
    end

    def reset
      @triangles = []
      GC.start
    end

    private

    def read_triangles(max_triangles, scaling_factor = 1.0)
      if @is_ascii
        read_triangles_ascii(max_triangles, scaling_factor)
      else
        read_triangles_binary(max_triangles, scaling_factor)
      end
    end

    #Reads up to max_triangles from the file - returns number read
    def read_triangles_ascii(max_triangles, scaling_factor = 1.0)
      triangle = nil
      read_count = 0
      while read_count < max_triangles
        begin
          line = @file.readline
        rescue Exception
          break
        end
        data = line.split
        if (data[0] == 'facet')
          triangle = []
          triangle[0] = [data[2].to_f, data[3].to_f, data[4].to_f]
        elsif (data[0] == 'vertex')
          triangle << [data[1].to_f * scaling_factor, data[2].to_f * scaling_factor, data[3].to_f * scaling_factor]
        elsif (data[0] == 'endloop')
          @triangles << triangle
          read_count += 1
        elsif (data[0] == 'endsolid')
          break
        end
      end

      return read_count
    end

    def read_triangles_binary(max_triangles, scaling_factor = 1.0)
      triangle = nil
      read_count = 0

      if @triangles.empty?
        #Assemble Generic Packet to Read Each Triangle
        @packet = Packet.new(nil, nil, :LITTLE_ENDIAN)
        @packet.append_item('normal0', 32, :FLOAT)
        @packet.append_item('normal1', 32, :FLOAT)
        @packet.append_item('normal2', 32, :FLOAT)
        @packet.append_item('vertex00', 32, :FLOAT)
        @packet.append_item('vertex01', 32, :FLOAT)
        @packet.append_item('vertex02', 32, :FLOAT)
        @packet.append_item('vertex10', 32, :FLOAT)
        @packet.append_item('vertex11', 32, :FLOAT)
        @packet.append_item('vertex12', 32, :FLOAT)
        @packet.append_item('vertex20', 32, :FLOAT)
        @packet.append_item('vertex21', 32, :FLOAT)
        @packet.append_item('vertex22', 32, :FLOAT)
        @packet.append_item('attribute_length', 16, :UINT)
        @packet.enable_method_missing

        #Read 80 Ascii Characters at beginning of file and throw away
        @file.read(80)

        #Read number of facets (triangles) in the file
        @num_facets = @file.read(4)
        @num_facets = @num_facets.unpack('V')[0]
      end

      while (@triangles.length < @num_facets) and (read_count < max_triangles)
        triangle = []
        data = @file.read(50)
        @packet.buffer = data
        triangle << [@packet.normal0, @packet.normal1, @packet.normal2]
        triangle << [@packet.vertex00 * scaling_factor, @packet.vertex01 * scaling_factor, @packet.vertex02 * scaling_factor]
        triangle << [@packet.vertex10 * scaling_factor, @packet.vertex11 * scaling_factor, @packet.vertex12 * scaling_factor]
        triangle << [@packet.vertex20 * scaling_factor, @packet.vertex21 * scaling_factor, @packet.vertex22 * scaling_factor]
        @triangles << triangle
        read_count += 1
      end

      return read_count
    end

  end

end # module Cosmos
