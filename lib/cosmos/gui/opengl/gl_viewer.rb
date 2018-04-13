# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file is inspired by the FOX Gui toolkit's FXGLViewer class

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/opengl/opengl'

module Cosmos
  # Widget which paints an OpenGL scene. Handles user interaction with the
  # scene by tracking mouse movements to drag objects and scale and pan within
  # the scene.
  class GlViewer < Qt::GLWidget
    MAX_PICKBUF = 1024
    MAX_SELPATH = 64
    EPS = 1.0e-2
    PICK_TOL = 3
    DTOR = 0.0174532925199432957692369077
    RTOD = 57.295779513082320876798154814

    attr_accessor :projection # :PARALLEL or :PERSPECTIVE
    attr_accessor :top_background
    attr_accessor :bottom_background
    attr_reader :zoom
    attr_reader :fov
    attr_reader :wvt
    attr_reader :diameter
    attr_reader :distance
    attr_reader :orientation
    attr_reader :center
    attr_reader :scale
    attr_reader :transform
    attr_reader :itransform
    attr_reader :maxhits
    attr_reader :ambient
    attr_reader :light
    attr_reader :material
    attr_reader :dropped
    attr_reader :selection
    attr_reader :scene
    attr_reader :smode
    attr_reader :options

    attr_accessor :selection_callback
    attr_accessor :draw_axis
    def initialize(parent, share_widget=nil)
      super(parent, share_widget)

      @defaultCursor = nil
      @dragCursor = nil
      @projection = :PERSPECTIVE
      @zoom = 1.0
      @fov = 30.0
      @wvt = GlViewport.new
      @diameter = 2.0;
      @distance = 7.464116;
      @orientation = Quaternion.new([0.0, 0.0, 0.0, 1.0])
      @center = [0.0, 0.0, 0.0]
      @scale = [1.0, 1.0, 1.0]
      updateProjection()
      updateTransform()
      @maxhits = 512;
      @top_background = [0.5, 0.5, 1.0, 1.0]
      @bottom_background = [1.0, 1.0, 1.0, 1.0]
      @ambient = [0.2, 0.2, 0.2, 1.0]
      @light = GlLight.new
      @material = GlMaterial.new
      @dial = [0, 0, 0]
      @dropped = nil
      @selection = nil
      @scene = nil
      @mode = :HOVERING
      @draw_axis = nil
      @options = []

      @selection_callback = nil
    end

    def minimumSizeHint
      return Qt::Size.new(100, 100)
    end

    def sizeHint
      return Qt::Size.new(400, 400)
    end

    def scene=(scene)
      @scene = scene
      @scale = [1.0, 1.0, 1.0]
      if @scene
        self.bounds = @scene.bounds
        @zoom = @scene.zoom
        @orientation = @scene.orientation
        @center = @scene.center
        @projection = @scene.projection
      end
      updateProjection()
      updateTransform()
      updateGL()
    end

    def fov=(fov)
      fov = 2.0 if fov < 2.0
      fov = 90.0 if fov > 90.0
      @fov = fov
      tn = tan(0.5 * DTOR * @fov)
      @distance = @diameter / tn
      updateProjection()
      updateTransform()
      updateGL()
    end

    def distance=(distance)
      distance = @diameter if distance < @diameter
      distance = 114.0 * @diameter if distance > (114.0 * @diameter)
      if distance != @distance
        @distance = distance
        @fov = 2.0 * RTOD * atan2(@diameter, @distance)
        updateProjection()
        updateTransform()
        updateGL()
      end
    end

    def zoom=(zoom)
      zoom = 1.0e-30 if zoom < 1.0e-30
      if zoom != @zoom
        @zoom = zoom
        updateProjection()
        updateGL()
      end
    end

    def scale= (scale)
      scale[0] = 0.000001 if scale[0] < 0.000001
      scale[1] = 0.000001 if scale[1] < 0.000001
      scale[2] = 0.000001 if scale[2] < 0.000001
      if scale != @scale
        @scale = scale
        updateTransform()
        updateGL()
      end
    end

    def orientation= (orientation)
      if (orientation.q0 != @orientation.q0) or (orientation.q1 != @orientation.q1) or (orientation.q2 != @orientation.q2) or (orientation.q3 != @orientation.q3)
        @orientation = orientation.clone.normalize
        updateTransform()
        update()
      end
    end

    def bounds= (bounds)
      # Model center
      @center = bounds.center

      # Model size
      @diameter = bounds.longest

      # Fix zero size model
      @diameter = 1.0 if @diameter < 1.0e-30

      # Set equal scaling initially
      @scale = [1.0, 1.0, 1.0]

      # Reset distance (and thus field of view)
      self.distance = 1.1 * @diameter
    end

    def center= (center)
      if center != @center
        @center = center
        updateTransform()
        updateGL()
      end
    end

    def selection= (shape)
      @selection = shape
      @selection_callback.call(shape) if @selection_callback
      updateGL()
    end

    def translate(vector)
      @center[0] += vector[0]
      @center[1] += vector[1]
      @center[2] += vector[2]
      updateTransform()
      updateGL()
    end

    def selectHits(x, y, w, h)
      mh = @maxhits
      nhits = 0
      makeCurrent()

      # Where to pick
      pickx = (@wvt.w - 2.0*x - w) / w.to_f
      picky = (2.0*y + h - @wvt.h) / h.to_f
      pickw = @wvt.w / w.to_f
      pickh = @wvt.h / h.to_f

      # Set pick projection matrix
      glMatrixMode(OpenGL::GL_PROJECTION)
      glLoadIdentity()
      glTranslatef(pickx, picky, 0.0)
      glScalef(pickw, pickh, 1.0)
      case projection
      when :PARALLEL
        glOrtho(@wvt.left, @wvt.right, @wvt.bottom, @wvt.top, @wvt.hither, @wvt.yon)
      when :PERSPECTIVE
        glFrustum(@wvt.left, @wvt.right, @wvt.bottom, @wvt.top, @wvt.hither, @wvt.yon)
      end

      # Model matrix
      glMatrixMode(OpenGL::GL_MODELVIEW)
      glLoadMatrixf(@transform.to_a.flatten.pack('F*'))

      # Loop until room enough to fit
      while true
        nhits = 0
        buffer = ' ' * mh
        glSelectBuffer(mh, buffer)
        glRenderMode(OpenGL::GL_SELECT)
        glInitNames()
        glPushName(0)
        @scene.hit(self) if @scene
        glPopName()
        nhits = glRenderMode(OpenGL::GL_RENDER)
        mh <<= 1
        break if nhits >= 0
      end
      doneCurrent()
      return buffer.unpack("L*"), nhits
    end

    def processHits(pickbuffer, nhits)
      if nhits > 0
        zmin = 4294967295
        zmax = 4294967295
        i = 0
        while nhits > 0
          n = pickbuffer[i]
          d1 = pickbuffer[1+i]
          d2 = pickbuffer[2+i]
          if ((d1 < zmin) || ((d1 == zmin) && (d2<=zmax)))
            zmin = d1
            zmax = d2
            sel = i
          end
          i += n + 3
          nhits -= 1
        end
        return @scene.identify(pickbuffer[4 + sel])
      end
      return nil
    end

    def pick(x, y)
      obj = nil
      if @scene and @maxhits
        pickbuffer, nhits = selectHits(x-PICK_TOL, y-PICK_TOL, PICK_TOL*2, PICK_TOL*2)
        obj = processHits(pickbuffer, nhits) if nhits > 0
      end
      return obj;
    end

    def initializeGL
      # Initialize GL context
      glRenderMode(OpenGL::GL_RENDER)

      # Fast hints
      glHint(OpenGL::GL_POLYGON_SMOOTH_HINT, OpenGL::GL_FASTEST)
      glHint(OpenGL::GL_PERSPECTIVE_CORRECTION_HINT, OpenGL::GL_FASTEST)
      glHint(OpenGL::GL_FOG_HINT, OpenGL::GL_FASTEST)
      glHint(OpenGL::GL_LINE_SMOOTH_HINT, OpenGL::GL_FASTEST)
      glHint(OpenGL::GL_POINT_SMOOTH_HINT, OpenGL::GL_FASTEST)

      # Z-buffer test on
      glEnable(OpenGL::GL_DEPTH_TEST)
      glDepthFunc(OpenGL::GL_LESS)
      glDepthRange(0.0, 1.0)
      glClearDepth(1.0)
      glClearColor(@top_background[0], @top_background[1], @top_background[2], @top_background[3])

      # No face culling
      glDisable(OpenGL::GL_CULL_FACE)
      glCullFace(OpenGL::GL_BACK)
      glFrontFace(OpenGL::GL_CCW)

      # Two sided lighting
      glLightModeli(OpenGL::GL_LIGHT_MODEL_TWO_SIDE, 1)
      glLightModelfv(OpenGL::GL_LIGHT_MODEL_AMBIENT, @ambient.pack('F*'))

      # Preferred blend over background
      glBlendFunc(OpenGL::GL_SRC_ALPHA, OpenGL::GL_ONE_MINUS_SRC_ALPHA)

      enable_light(@light)
      # Viewer is close
      glLightModeli(OpenGL::GL_LIGHT_MODEL_LOCAL_VIEWER, 1)

      enable_material(@material)
      # Vertex colors change both diffuse and ambient
      glColorMaterial(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_AMBIENT_AND_DIFFUSE)
      glDisable(OpenGL::GL_COLOR_MATERIAL)

      # Simplest and fastest drawing is default
      glShadeModel(OpenGL::GL_FLAT)
      glDisable(OpenGL::GL_BLEND)
      glDisable(OpenGL::GL_LINE_SMOOTH)
      glDisable(OpenGL::GL_POINT_SMOOTH)
      glDisable(OpenGL::GL_COLOR_MATERIAL)

      # Lighting
      glDisable(OpenGL::GL_LIGHTING)

      # No normalization of normals (it's broken on some machines anyway)
      glDisable(OpenGL::GL_NORMALIZE)

      # Dithering if needed
      glDisable(OpenGL::GL_DITHER)
    end

    def paintGL
      # Set viewport
      glViewport(0, 0, @wvt.w, @wvt.h)
      reset_gl_state()
      clear_solid_background()

      # Depth test on by default
      glDepthMask(OpenGL::GL_TRUE)
      glEnable(OpenGL::GL_DEPTH_TEST)

      # Switch to projection matrix
      glMatrixMode(OpenGL::GL_PROJECTION)
      glLoadIdentity
      case @projection
      when :PARALLEL
        glOrtho(@wvt.left, @wvt.right, @wvt.bottom, @wvt.top, @wvt.hither, @wvt.yon)
      when :PERSPECTIVE
        glFrustum(@wvt.left, @wvt.right, @wvt.bottom, @wvt.top, @wvt.hither, @wvt.yon)
      end

      # Switch to model matrix
      glMatrixMode(OpenGL::GL_MODELVIEW)
      glLoadIdentity

      enable_light(@light)
      enable_material(@material)

      # Color commands change both
      glColorMaterial(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_AMBIENT_AND_DIFFUSE)
      # Global ambient light
      glLightModelfv(OpenGL::GL_LIGHT_MODEL_AMBIENT, @ambient.pack('F*'))

      # Enable fog
      if @options.include?(:VIEWER_FOG)
        glEnable(OpenGL::GL_FOG)
        glFog(OpenGL::GL_FOG_COLOR, @top_background) # Disappear into the background
        glFogf(OpenGL::GL_FOG_START, (@distance - @diameter).to_f) # Range tight around model position
        glFogf(OpenGL::GL_FOG_END, (@distance + @diameter).to_f) # Far place same as clip plane:- clipped stuff is in the mist!
        glFogi(OpenGL::GL_FOG_MODE, OpenGL::GL_LINEAR) # Simple linear depth cueing
      end

      # Dithering
      glEnable(OpenGL::GL_DITHER) if @options.include?(:VIEWER_DITHER)
      # Enable lighting
      glEnable(OpenGL::GL_LIGHTING) if @options.include?(:VIEWER_LIGHTING)

      # Set model matrix
      glLoadMatrixf(@transform.to_a.flatten.pack('F*'))

      draw_axis() if (@draw_axis and @draw_axis > 0)

      # Draw what's visible
      @scene.draw(self) if @scene
    end

    def reset_gl_state
      glShadeModel(OpenGL::GL_SMOOTH)
      glPolygonMode(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_FILL)
      glDisable(OpenGL::GL_LIGHTING)
      glDisable(OpenGL::GL_ALPHA_TEST)
      glDisable(OpenGL::GL_BLEND)
      glDisable(OpenGL::GL_DITHER)
      glDisable(OpenGL::GL_FOG)
      glDisable(OpenGL::GL_LOGIC_OP)
      glDisable(OpenGL::GL_POLYGON_SMOOTH)
      glDisable(OpenGL::GL_POLYGON_STIPPLE)
      glDisable(OpenGL::GL_STENCIL_TEST)
      glDisable(OpenGL::GL_CULL_FACE)
      glDisable(OpenGL::GL_COLOR_MATERIAL)

      # Reset matrices
      glMatrixMode(OpenGL::GL_PROJECTION)
      glLoadIdentity
      glMatrixMode(OpenGL::GL_MODELVIEW)
      glLoadIdentity
    end

    def clear_solid_background
      glClearDepth(1.0)
      glClearColor(@top_background[0], @top_background[1], @top_background[2], @top_background[3])
      if @top_background == @bottom_background
        begin
          glClear(OpenGL::GL_COLOR_BUFFER_BIT | OpenGL::GL_DEPTH_BUFFER_BIT)
        rescue
          # Raises false error on Mac
        end
      else # Clear to gradient background
        begin
          glClear(OpenGL::GL_DEPTH_BUFFER_BIT)
        rescue
          # Raises false error on Mac
        end
        glDisable(OpenGL::GL_DEPTH_TEST)
        glDepthMask(OpenGL::GL_FALSE)
        glBegin(OpenGL::GL_TRIANGLE_STRIP)
        glColor4f(@bottom_background[0], @bottom_background[1], @bottom_background[2], @bottom_background[3])
        glVertex3f(-1.0, -1.0, 0.0)
        glVertex3f(1.0, -1.0, 0.0)
        glColor4f(@top_background[0], @top_background[1], @top_background[2], @bottom_background[3])
        glVertex3f(-1.0, 1.0, 0.0)
        glVertex3f(1.0, 1.0, 0.0)
        begin
          glEnd
        rescue
          # Raises false error on Mac
        end
      end
    end

    def draw_axis
      glPushMatrix
        glLineWidth(2.5)
        glColor3f(1.0, 0.0, 0.0)
        glBegin(OpenGL::GL_LINES)
          glVertex3f(-@draw_axis.to_f, 0.0, 0.0)
          glVertex3f(@draw_axis.to_f, 0.0, 0.0)
        begin
          glEnd
        rescue
          # Raises false error on Mac
        end
        glColor3f(0.0, 1.0, 0.0)
        glBegin(OpenGL::GL_LINES)
          glVertex3f(0, -@draw_axis, 0.0)
          glVertex3f(0, @draw_axis, 0)
        begin
          glEnd
        rescue
          # Raises false error on Mac
        end
        glColor3f(0.0, 0.0, 1.0)
        glBegin(OpenGL::GL_LINES)
          glVertex3f(0, 0, -@draw_axis)
          glVertex3f(0, 0, @draw_axis)
        begin
          glEnd
        rescue
          # Raises false error on Mac
        end
      glPopMatrix
    end

    def enable_light(light)
      glEnable(OpenGL::GL_LIGHT0)
      glLightfv(OpenGL::GL_LIGHT0, OpenGL::GL_AMBIENT, light.ambient.pack('F*'))
      glLightfv(OpenGL::GL_LIGHT0, OpenGL::GL_DIFFUSE, light.diffuse.pack('F*'))
      glLightfv(OpenGL::GL_LIGHT0, OpenGL::GL_SPECULAR, light.specular.pack('F*'))
      glLightfv(OpenGL::GL_LIGHT0, OpenGL::GL_POSITION, light.position.pack('F*'))
      glLightfv(OpenGL::GL_LIGHT0, OpenGL::GL_SPOT_DIRECTION, light.direction.pack('F*'))
      glLightf(OpenGL::GL_LIGHT0, OpenGL::GL_SPOT_EXPONENT, light.exponent)
      glLightf(OpenGL::GL_LIGHT0, OpenGL::GL_SPOT_CUTOFF, light.cutoff)
      glLightf(OpenGL::GL_LIGHT0, OpenGL::GL_CONSTANT_ATTENUATION, light.c_attn)
      glLightf(OpenGL::GL_LIGHT0, OpenGL::GL_LINEAR_ATTENUATION, light.l_attn)
      glLightf(OpenGL::GL_LIGHT0, OpenGL::GL_QUADRATIC_ATTENUATION, light.q_attn)
    end

    def enable_material(material)
      glMaterialfv(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_AMBIENT, material.ambient.pack('F*'))
      glMaterialfv(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_DIFFUSE, material.diffuse.pack('F*'))
      glMaterialfv(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_SPECULAR, material.specular.pack('F*'))
      glMaterialfv(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_EMISSION, material.emission.pack('F*'))
      glMaterialf(OpenGL::GL_FRONT_AND_BACK, OpenGL::GL_SHININESS, material.shininess)
    end

    def resizeGL(width, height)
      @wvt.w = width;
      @wvt.h = height;
      updateProjection()
    end

    def screenToEye(sx, sy, eyez)
      e = [0.0, 0.0, 0.0]
      xp = (@worldpx*sx + @ax).to_f
      yp = (@ay - @worldpx*sy).to_f
      if @projection == :PERSPECTIVE
        if @distance != 0.0
          e.x = [((-eyez*xp) / @distance).to_f, ((-eyez*yp) / @distance).to_f, eyez]
        end
      else
        e = [xp, yp, eyez]
      end
      return e;
    end

    def screenToTarget(sx, sy)
      [@worldpx*sx.to_f + @ax, @ay - @worldpx*sy.to_f, -@distance.to_f]
    end

    def worldToEyeZ(w)
      w[0]*@transform[0][2] + w[1]*@transform[1][2] + w[2]*@transform[2][2] + @transform[3][2]
    end

    def eyeToWorld(e)
      calc_prime(e)
    end

    def calc_prime(v)
      [v[0]*@itransform[0][0] + v[1]*@itransform[1][0] + v[2]*@itransform[2][0] + @itransform[3][0],
       v[0]*@itransform[0][1] + v[1]*@itransform[1][1] + v[2]*@itransform[2][1] + @itransform[3][1],
       v[0]*@itransform[0][2] + v[1]*@itransform[1][2] + v[2]*@itransform[2][2] + @itransform[3][2]]
    end

    def worldVector(fx, fy, tx, ty)
      wfm_prime = calc_prime(screenToTarget(fx, fy))
      wto_prime = calc_prime(screenToTarget(tx, ty))
      return [wto_prime[0] - wfm_prime[0], wto_prime[1] - wfm_prime[1], wto_prime[2] - wfm_prime[2]]
    end

    def spherePoint(x, y)
      if @wvt.w > @wvt.h
        screenmin = wvt.h.to_f
      else
        screenmin = wvt.w.to_f
      end
      v = []
      v[0] = 2.0 * (x - 0.5*@wvt.w) / screenmin
      v[1] = 2.0 * (0.5 * @wvt.h - y) / screenmin
      d = v[0]*v[0] + v[1]*v[1]

      if d < 0.75
        v[2] = sqrt(1.0-d)
      elsif d < 3.0
        d = 1.7320508008 - sqrt(d)
        t = 1.0 - d*d
        t = 0.0 if t < 0.0
        v[2] = 1.0 - sqrt(t)
      else
        v[2] = 0.0
      end

      length = sqrt(v[0]*v[0]+v[1]*v[1]+v[2]*v[2])
      if length > 0.0
        return [v[0] / length, v[1] / length, v[2] / length]
      else
        return [0.0, 0.0, 0.0]
      end
    end

    def turn(fx, fy, tx, ty)
      return Quaternion.arc(spherePoint(fx,fy), spherePoint(tx,ty))
    end

    def mode=(mode)
      @mode = mode
      case @mode
      when :ZOOMING
        Qt::Application.setOverrideCursor(Cosmos.getCursor(Qt::SizeVerCursor))
      when :DRAGGING
        Qt::Application.setOverrideCursor(Cosmos.getCursor(Qt::ClosedHandCursor))
      when :ROTATING
        Qt::Application.setOverrideCursor(Cosmos.getCursor(Qt::CrossCursor))
      when :TRANSLATING
        Qt::Application.setOverrideCursor(Cosmos.getCursor(Qt::SizeAllCursor))
      else
        Qt::Application.restoreOverrideCursor
      end
    end

    def mousePressEvent(event)
      case event.button
      when Qt::LeftButton
        self.mode = :PICKING
        if (event.buttons & Qt::RightButton.to_i) != 0
          self.mode = :ZOOMING
        elsif (@selection and @selection.dragable and @selection == pick(event.x, event.y))
          self.mode = :DRAGGING
        end
      when Qt::RightButton
        if (event.buttons & Qt::LeftButton.to_i) != 0
          self.mode = :ZOOMING
        else
          self.mode = :POSTING
        end
      when Qt::MidButton
        self.mode = :ZOOMING
      end
      @lastPos = event.pos
    end

    def mouseReleaseEvent(event)
      case @mode
      when :PICKING
        self.selection = pick(event.x, event.y)
      end

      if (((event.buttons & Qt::RightButton.to_i) != 0) and ((event.buttons & Qt::LeftButton.to_i) != 0)) or ((event.buttons & Qt::MidButton.to_i) != 0)
        self.mode = :ZOOMING
      elsif (event.buttons & Qt::LeftButton.to_i) != 0
        self.mode = :ROTATING
      elsif (event.buttons & Qt::RightButton.to_i) != 0
        self.mode = :TRANSLATING
      else
        self.mode = :HOVERING
      end
    end

    def mouseMoveEvent(event)
      dx = event.x - @lastPos.x
      dy = event.y - @lastPos.y

      case @mode
      when :PICKING, :POSTING
        if dx.abs > 0 or dy.abs > 0
          if @mode == :PICKING
            self.mode = :ROTATING
          else
            self.mode = :TRANSLATING
          end
        end
      when :TRANSLATING
        vector = worldVector(@lastPos.x, @lastPos.y, event.x, event.y)
        translate([-vector[0], -vector[1], -vector[2]])
      when :DRAGGING
        if @selection and @selection.drag(self, @lastPos.x, @lastPos.y, event.x, event.y)
          updateGL()
        end
      when :ROTATING
        self.orientation = turn(@lastPos.x, @lastPos.y, event.x, event.y) * @orientation
      when :ZOOMING
        delta = 0.005 * dy
        self.zoom = @zoom * (2.0 ** delta)
      end

      @lastPos = event.pos
    end

    def wheelEvent(event)
      self.zoom = @zoom * (2.0 ** (-0.1 * event.delta / 120.0))
    end

    protected

    def updateProjection
      # Should be non-0 size viewport
      if @wvt.w > 0 and @wvt.h > 0
        # Aspect ratio of viewer
        aspect = @wvt.h.to_f / @wvt.w.to_f

        # Get world box
        r = 0.5 * @diameter / @zoom
        if @wvt.w <= @wvt.h
          @wvt.left = -r
          @wvt.right = r
          @wvt.bottom = -r * aspect
          @wvt.top = r * aspect
        else
          @wvt.left = -r / aspect
          @wvt.right = r / aspect
          @wvt.bottom = -r
          @wvt.top = r
        end

        @wvt.yon = @distance + @diameter
        @wvt.hither = 0.1 * @wvt.yon

        # Size of a pixel in world and model
        @worldpx = (@wvt.right - @wvt.left) / @wvt.w
        @modelpx = @worldpx * @diameter

        # Precalc stuff for view->world backmapping
        @ax = @wvt.left
        @ay = @wvt.top - @worldpx

        # Correction for perspective
        if @projection == :PERSPECTIVE
          hither_fac= @wvt.hither / @distance
          @wvt.left *= hither_fac
          @wvt.right *= hither_fac
          @wvt.top *= hither_fac
          @wvt.bottom *= hither_fac
        end
      end
    end

    def updateTransform
      @transform = Matrix.identity(4)
      @transform.trans4(0.0, 0.0, -@distance.to_f)
      @transform.rot4(@orientation);
      @transform.scale4(@scale[0], @scale[1], @scale[2]);
      @transform.trans4(-@center[0], -@center[1], -@center[2]);
      @itransform = @transform.inverse
    end
  end
end
