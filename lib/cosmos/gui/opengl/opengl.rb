# encoding: ascii-8bit

require 'opengl'
include OpenGL
OpenGL.load_lib
require 'glu'
include GLU
GLU.load_lib

require 'cosmos/gui/opengl/gl_viewport'
require 'cosmos/gui/opengl/gl_light'
require 'cosmos/gui/opengl/gl_material'
require 'cosmos/gui/opengl/gl_bounds'
require 'cosmos/gui/opengl/gl_scene'
