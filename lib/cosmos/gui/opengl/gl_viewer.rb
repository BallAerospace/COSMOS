# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
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

  class GlViewer < Qt::GLWidget
    MAX_PICKBUF = 1024
    MAX_SELPATH = 64
    EPS = 1.0e-2
    PICK_TOL = 3
    DTOR = 0.0174532925199432957692369077
    RTOD = 57.295779513082320876798154814

    attr_accessor :projection # :PARALLEL or :PERSPECTIVE
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
    attr_reader :top_background
    attr_reader :bottom_background
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
    def initialize(parent)
      super(parent)

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
      GL.MatrixMode(GL::PROJECTION);
      GL.LoadIdentity()
      GL.Translatef(pickx, picky, 0.0)
      GL.Scalef(pickw, pickh, 1.0)
      case projection
      when :PARALLEL
        GL.Ortho(@wvt.left, @wvt.right, @wvt.bottom, @wvt.top, @wvt.hither, @wvt.yon)
      when :PERSPECTIVE
        GL.Frustum(@wvt.left, @wvt.right, @wvt.bottom, @wvt.top, @wvt.hither, @wvt.yon)
      end

      # Model matrix
      GL.MatrixMode(GL::MODELVIEW);
      GL.LoadMatrixf(@transform)

      # Loop until room enough to fit
      while true
        nhits = 0
        buffer = GL.SelectBuffer(mh)
        GL.RenderMode(GL::SELECT);
        GL.InitNames()
        GL.PushName(0)
        @scene.hit(self) if @scene
        GL.PopName()
        nhits = GL.RenderMode(GL::RENDER)
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
      GL.GetError()

      # Initialize GL context
      GL.RenderMode(GL::RENDER)

      # Fast hints
      GL.Hint(GL::POLYGON_SMOOTH_HINT, GL::FASTEST)
      GL.Hint(GL::PERSPECTIVE_CORRECTION_HINT, GL::FASTEST)
      GL.Hint(GL::FOG_HINT, GL::FASTEST)
      GL.Hint(GL::LINE_SMOOTH_HINT, GL::FASTEST)
      GL.Hint(GL::POINT_SMOOTH_HINT, GL::FASTEST)

      # Z-buffer test on
      GL.Enable(GL::DEPTH_TEST)
      GL.DepthFunc(GL::LESS)
      GL.DepthRange(0.0, 1.0)
      GL.ClearDepth(1.0)
      GL.ClearColor(@top_background[0], @top_background[1], @top_background[2], @top_background[3])

      # No face culling
      GL.Disable(GL::CULL_FACE)
      GL.CullFace(GL::BACK)
      GL.FrontFace(GL::CCW)

      # Two sided lighting
      GL.LightModeli(GL::LIGHT_MODEL_TWO_SIDE, 1)
      GL.LightModel(GL::LIGHT_MODEL_AMBIENT, @ambient)

      # Preferred blend over background
      GL.BlendFunc(GL::SRC_ALPHA, GL::ONE_MINUS_SRC_ALPHA)

      # Light on
      GL.Enable(GL::LIGHT0)
      GL.Light(GL::LIGHT0, GL::AMBIENT, @light.ambient)
      GL.Light(GL::LIGHT0, GL::DIFFUSE, @light.diffuse)
      GL.Light(GL::LIGHT0, GL::SPECULAR, @light.specular)
      GL.Light(GL::LIGHT0, GL::POSITION, @light.position)
      GL.Light(GL::LIGHT0, GL::SPOT_DIRECTION, @light.direction)
      GL.Lightf(GL::LIGHT0, GL::SPOT_EXPONENT, @light.exponent)
      GL.Lightf(GL::LIGHT0, GL::SPOT_CUTOFF, @light.cutoff)
      GL.Lightf(GL::LIGHT0, GL::CONSTANT_ATTENUATION, @light.c_attn)
      GL.Lightf(GL::LIGHT0, GL::LINEAR_ATTENUATION, @light.l_attn)
      GL.Lightf(GL::LIGHT0, GL::QUADRATIC_ATTENUATION, @light.q_attn)

      # Viewer is close
      GL.LightModeli(GL::LIGHT_MODEL_LOCAL_VIEWER, 1)

      # Material colors
      GL.Material(GL::FRONT_AND_BACK, GL::AMBIENT, @material.ambient)
      GL.Material(GL::FRONT_AND_BACK, GL::DIFFUSE, @material.diffuse)
      GL.Material(GL::FRONT_AND_BACK, GL::SPECULAR, @material.specular)
      GL.Material(GL::FRONT_AND_BACK, GL::EMISSION, @material.emission)
      GL.Materialf(GL::FRONT_AND_BACK, GL::SHININESS, @material.shininess)

      # Vertex colors change both diffuse and ambient
      GL.ColorMaterial(GL::FRONT_AND_BACK, GL::AMBIENT_AND_DIFFUSE)
      GL.Disable(GL::COLOR_MATERIAL)

      # Simplest and fastest drawing is default
      GL.ShadeModel(GL::FLAT)
      GL.Disable(GL::BLEND)
      GL.Disable(GL::LINE_SMOOTH)
      GL.Disable(GL::POINT_SMOOTH)
      GL.Disable(GL::COLOR_MATERIAL)

      # Lighting
      GL.Disable(GL::LIGHTING)

      # No normalization of normals (it's broken on some machines anyway)
      GL.Disable(GL::NORMALIZE)

      # Dithering if needed
      GL.Disable(GL::DITHER)
    end

    def paintGL
      # Set viewport
      GL.Viewport(0, 0, @wvt.w, @wvt.h)

      # Reset important stuff
      GL.ShadeModel(GL::SMOOTH)
      GL.PolygonMode(GL::FRONT_AND_BACK, GL::FILL)
      GL.Disable(GL::LIGHTING)
      GL.Disable(GL::ALPHA_TEST)
      GL.Disable(GL::BLEND)
      GL.Disable(GL::DITHER)
      GL.Disable(GL::FOG)
      GL.Disable(GL::LOGIC_OP)
      GL.Disable(GL::POLYGON_SMOOTH)
      GL.Disable(GL::POLYGON_STIPPLE)
      GL.Disable(GL::STENCIL_TEST)
      GL.Disable(GL::CULL_FACE)
      GL.Disable(GL::COLOR_MATERIAL)

      # Reset matrices
      GL.MatrixMode(GL::PROJECTION)
      GL.LoadIdentity
      GL.MatrixMode(GL::MODELVIEW)
      GL.LoadIdentity

      # Clear to solid background
      GL.ClearDepth(1.0)
      GL.ClearColor(@top_background[0], @top_background[1], @top_background[2], @top_background[3])
      if @top_background == @bottom_background
        begin
          GL.Clear(GL::COLOR_BUFFER_BIT | GL::DEPTH_BUFFER_BIT)
        rescue
          # Raises false error on Mac
        end
      else # Clear to gradient background
        begin
          GL.Clear(GL::DEPTH_BUFFER_BIT)
        rescue
          # Raises false error on Mac
        end
        GL.Disable(GL::DEPTH_TEST)
        GL.DepthMask(GL::FALSE)
        GL.Begin(GL::TRIANGLE_STRIP)
        GL.Color(@bottom_background); GL.Vertex3f(-1.0, -1.0, 0.0); GL.Vertex3f(1.0, -1.0, 0.0)
        GL.Color(@top_background); GL.Vertex3f(-1.0, 1.0, 0.0); GL.Vertex3f(1.0, 1.0, 0.0)
        begin
          GL.End
        rescue
          # Raises false error on Mac
        end
      end

      # Depth test on by default
      GL.DepthMask(GL::TRUE)
      GL.Enable(GL::DEPTH_TEST)

      # Switch to projection matrix
      GL.MatrixMode(GL::PROJECTION)
      GL.LoadIdentity
      case @projection
      when :PARALLEL
        GL.Ortho(@wvt.left, @wvt.right, @wvt.bottom, @wvt.top, @wvt.hither, @wvt.yon)
      when :PERSPECTIVE
        GL.Frustum(@wvt.left, @wvt.right, @wvt.bottom, @wvt.top, @wvt.hither, @wvt.yon)
      end

      # Switch to model matrix
      GL.MatrixMode(GL::MODELVIEW)
      GL.LoadIdentity

      # Set light parameters
      GL.Enable(GL::LIGHT0)
      GL.Light(GL::LIGHT0, GL::AMBIENT, @light.ambient)
      GL.Light(GL::LIGHT0, GL::DIFFUSE, @light.diffuse)
      GL.Light(GL::LIGHT0, GL::SPECULAR, @light.specular)
      GL.Light(GL::LIGHT0, GL::POSITION, @light.position)
      GL.Light(GL::LIGHT0, GL::SPOT_DIRECTION, @light.direction)
      GL.Lightf(GL::LIGHT0, GL::SPOT_EXPONENT, @light.exponent)
      GL.Lightf(GL::LIGHT0, GL::SPOT_CUTOFF, @light.cutoff)
      GL.Lightf(GL::LIGHT0, GL::CONSTANT_ATTENUATION, @light.c_attn)
      GL.Lightf(GL::LIGHT0, GL::LINEAR_ATTENUATION, @light.l_attn)
      GL.Lightf(GL::LIGHT0, GL::QUADRATIC_ATTENUATION, @light.q_attn)

      # Default material colors
      GL.Material(GL::FRONT_AND_BACK, GL::AMBIENT, @material.ambient)
      GL.Material(GL::FRONT_AND_BACK, GL::DIFFUSE, @material.diffuse)
      GL.Material(GL::FRONT_AND_BACK, GL::SPECULAR, @material.specular)
      GL.Material(GL::FRONT_AND_BACK, GL::EMISSION, @material.emission)
      GL.Materialf(GL::FRONT_AND_BACK, GL::SHININESS, @material.shininess)

      # Color commands change both
      GL.ColorMaterial(GL::FRONT_AND_BACK, GL::AMBIENT_AND_DIFFUSE)

      # Global ambient light
      GL.LightModel(GL::LIGHT_MODEL_AMBIENT, @ambient)

      # Enable fog
      if @options.include?(:VIEWER_FOG)
        GL.Enable(GL::FOG)
        GL.Fog(GL::FOG_COLOR, @top_background) # Disappear into the background
        GL.Fogf(GL::FOG_START, (@distance - @diameter).to_f) # Range tight around model position
        GL.Fogf(GL::FOG_END, (@distance + @diameter).to_f) # Far place same as clip plane:- clipped stuff is in the mist!
        GL.Fogi(GL::FOG_MODE, GL::LINEAR) # Simple linear depth cueing
      end

      # Dithering
      GL.Enable(GL::DITHER) if @options.include?(:VIEWER_DITHER)

      # Enable lighting
      GL.Enable(GL::LIGHTING) if @options.include?(:VIEWER_LIGHTING)

      # Set model matrix
      GL.LoadMatrixf(@transform)

      if (@draw_axis and @draw_axis > 0)
        # Draw axis
        GL.PushMatrix
          GL.LineWidth(2.5)
          GL.Color3f(1.0, 0.0, 0.0)
          GL.Begin(GL::LINES)
            GL.Vertex3f(-@draw_axis, 0.0, 0.0)
            GL.Vertex3f(@draw_axis, 0, 0)
          GL.End
          GL.Color3f(0.0, 1.0, 0.0)
          GL.Begin(GL::LINES)
            GL.Vertex3f(0, -@draw_axis, 0.0)
            GL.Vertex3f(0, @draw_axis, 0)
          GL.End
          GL.Color3f(0.0, 0.0, 1.0)
          GL.Begin(GL::LINES)
            GL.Vertex3f(0, 0, -@draw_axis)
            GL.Vertex3f(0, 0, @draw_axis)
          GL.End
        GL.PopMatrix
        end

      # Draw what's visible
      @scene.draw(self) if @scene
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

    def eyeToWorld(e)
      [e[0]*@itransform[0][0] + e[1]*@itransform[1][0] + e[2]*@itransform[2][0] + @itransform[3][0],
       e[0]*@itransform[0][1] + e[1]*@itransform[1][1] + e[2]*@itransform[2][1] + @itransform[3][1],
       e[0]*@itransform[0][2] + e[1]*@itransform[1][2] + e[2]*@itransform[2][2] + @itransform[3][2]]
    end

    def worldToEyeZ(w)
      w[0]*@transform[0][2] + w[1]*@transform[1][2] + w[2]*@transform[2][2] + @transform[3][2]
    end

    def worldVector(fx, fy, tx, ty)
      wfm = screenToTarget(fx, fy)
      wto = screenToTarget(tx, ty)
      wfm_prime = [wfm[0]*@itransform[0][0] + wfm[1]*@itransform[1][0] + wfm[2]*@itransform[2][0] + @itransform[3][0],
                         wfm[0]*@itransform[0][1] + wfm[1]*@itransform[1][1] + wfm[2]*@itransform[2][1] + @itransform[3][1],
                         wfm[0]*@itransform[0][2] + wfm[1]*@itransform[1][2] + wfm[2]*@itransform[2][2] + @itransform[3][2]]
      wto_prime = [wto[0]*@itransform[0][0] + wto[1]*@itransform[1][0] + wto[2]*@itransform[2][0] + @itransform[3][0],
                         wto[0]*@itransform[0][1] + wto[1]*@itransform[1][1] + wto[2]*@itransform[2][1] + @itransform[3][1],
                         wto[0]*@itransform[0][2] + wto[1]*@itransform[1][2] + wto[2]*@itransform[2][2] + @itransform[3][2]]
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

  end # class OpenGLViewer

end # module Cosmos
