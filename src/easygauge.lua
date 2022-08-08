-- ---------------------------------------------------------------------
-- Easy Gauges 
-- ---------------------------------------------------------------------
-- Copyright (C) 2022 Paul Hoesli. <tetrachromat at outlook dot com>.
-- Licensed user of Air Manager / Air Player are permitted to use, copy 
-- and modify the software for their personal use. Distribution of the 
-- original or modified software, whether for profit or non-profit 
-- requires a licensing agreement with the copyright owner.
-- ---------------------------------------------------------------------
-- This code allows Air Manager / Air Player users to create personal
-- instruments without programming in LUA.
--
-- Specify instrument features in the resource file "easygauge.json"
-- ---------------------------------------------------------------------
-- Easygauge Default Settings
EASYGAUGE = {
  IMAGE = {
    BACKGROUND = "background.png",
    COVER      = "cover.png",
    BEZEL      = "bezel.png",
    INDICATOR  = "needle.png"
  },
  MARKUP = {
    FONT   = "roboto_bold.ttf",
    SIZE   = 48,
    COLOR  = "white",
    VALIGN = "center",
    HALIGN = "center",
    FORMAT = "font:%s; size:%s; color:%s; valign:%s; halign:%s;"
  },
  MARKS = {
    WIDTH  = 4,
    COLOR  = "white",
    SECTIONS = {}
  },
  ARC = {
    ZERO  = -90,
    WIDTH = 4,
    COLOR = "white"
  },
  REDLINE = {
    WIDTH = 4,
    COLOR = "red"
  }
}
function easygauge()
--{{
end
--}}
  -- Local Data
  local log_prefix = "EG: "
  local VERSION = {
    semantic = "1.0.0",
    build    = "Home",
    pre      = "RC",
    sub_rel  = "2"
  }

  local version = VERSION.semantic .. " " .. VERSION.build 
  if VERSION.pre then 
    version = version .. " (" .. VERSION.pre .. " " .. VERSION.sub_rel .. ")"
  end

  -- Table Indexes
  local CANVAS = {
    LEFT   = 1,
    TOP    = 2,
    WIDTH  = 3,
    HEIGHT = 4
  }
  local SECTION = {
    VALUE = 1,
    ANGLE = 2,
    MAJOR = 3,
    MINOR = 4,
    THINN = 5
  }
  local SEGMENT = {
    VALUE = 1,
    COLOR = 2
  }
  -- Keywords
  local KIND = {
    CIRCULAR = "circular",
    VERTICAL = "vertical",
    HORIZONTAL = "horizontal"
  }

  -- The Easyguage Specification
  local easygauge = {}

  -- FUNCTIONS
  -- drawing helper
  local eg_style = function ( style_spec  )
    local style  = style_spec or {}
    
    local font   = style.font   or EASYGAUGE.MARKUP.FONT
    local size   = string.format("%i", style.size or EASYGAUGE.MARKUP.SIZE)
    local color  = style.color  or EASYGAUGE.MARKUP.COLOR
    local valign = style.valign or EASYGAUGE.MARKUP.VALIGN
    local halign = style.halign or EASYGAUGE.MARKUP.HALIGN

    return string.format(EASYGAUGE.MARKUP.FORMAT, font, size, color, valign, halign)
  end

  local eg_offsets = function ( kind, pos, r1, r2 )
    if kind == KIND.CIRCULAR then
      local rad = math.rad(pos)
      local sin = math.sin(rad)
      local cos = math.cos(rad)
      return sin * r1, cos * r1, sin * r2, cos * r2
    elseif kind == KIND.HORIZONTAL then
      return pos, r1, pos, r2
    elseif kind == KIND.VERTICAL then
      return r1, pos, r2, pos
    end
  end

  -- API Wrappers
  local eg_image = function ( image )
    if type(image) == "table" then
      local img, x, y, w, h = table.unpack(image)
      if img then
        local resource = resource_info(img)
        if resource and resource.TYPE == "IMAGE" then
          img_add( img, x or 0, y or 0, w or instrument_prop("PREF_WIDTH"), h or instrument_prop("PREF_HEIGHT") )
        end
      end
    end
  end

  local eg_canvas = function ( )
    easygauge.canvas = easygauge.canvas or { 0, 0, instrument_prop("PREF_WIDTH"), instrument_prop("PREF_HEIGHT") }
    if type(easygauge.canvas) == "table" then
      return canvas_add( table.unpack(easygauge.canvas) )
    end
  end

  local eg_indicator = function ( gauge )
    local indicator = gauge.indicator or { EASYGAUGE.IMAGE.INDICATOR }
    if type(indicator) == "table" then
      local img, w, h, x, y  = table.unpack(indicator)
      if img then
        local resource = resource_info(img)
        if resource and resource.TYPE == "IMAGE" then
          local ccx, ccy = table.unpack(easygauge.canvas)
          local gcx, gcy = table.unpack(gauge.center)
          w = w or resource.WIDTH
          h = h or resource.HEIGHT
          x = ccx + gcx - w/2 + (x or 0)
          y = ccy + gcy - h/2 + (y or 0)
          gauge.indicator = img_add( img, x, y, w, h )
          local animation = gauge.animation or {}
          if not gauge.indicate then
            gauge.indicate = function ()
              local pos = interpolate_linear( gauge.sections, gauge.value, true )
              if gauge.kind == KIND.CIRCULAR then
                rotate(gauge.indicator, pos, table.unpack(animation) )
              elseif gauge.kind == KIND.HORIZONTAL or gauge.kind == KIND.VERTICAL then
                local dx, dy = eg_offsets( gauge.kind, pos, 0, 0 )
                move(gauge.indicator, x + dx, y + dy, w, h, table.unpack(animation) )
              end
            end
          end
        end
      end
    end
  end

  local eg_subscription = function ( gauge )
    if gauge.variable then
      if not gauge.update then
        gauge.update = function ( value )
          if type(value) == "boolean" then 
            gauge.value = fif(value, 1, 0) 
          else
            local position = value
            if gauge.map then
              position = gauge.map[string.format("%d", value)]
            end
            gauge.value = position or gauge.value
          end
          gauge.indicate()
        end
      end
      local variable = string.format(gauge.variable[1], eg_index)
      local unit     = gauge.variable[2]
      local source   = gauge.variable[3]
      if source == "SI" then
        si_variable_subscribe( variable, unit, gauge.update )
      else
        fs2020_variable_subscribe(variable, unit, gauge.update)
      end
    end
  end

  local eg_gauge = function (gauge)
    -- reference to scale object
    local scale = gauge.scale or 1
    if type(scale) == "number" then 
      scale = easygauge.scales[scale]
    end
    -- gauge properties
    gauge.center   = gauge.center or scale.center
    gauge.sections = gauge.sections or scale.marks.sections
    gauge.kind     = scale.kind
    gauge.value    = gauge.value or 0
    eg_indicator( gauge )
    eg_subscription( gauge )
  end

  -- control support
  local eg_action = function ( control, direction )
    direction = direction or 0
    local i = control.value + direction + 1
    if control.event then
      local event = control.event[i]
      if event then
        if type(event) == "string" then
          event = { event }
        end
        if type(event) == "table" then
          fs2020_event( table.unpack(event) )
        end
      end
    elseif control.write then
      local message = control.write[i]
      if message then
        if type(message) == "table" then
          fs2020_variable_write( table.unpack(message) )
        end
      end
    end
  end
  
  local eg_button = function ( control )
    local img_normal, img_pressed, x, y, w, h = table.unpack(control.images)
    if not img_normal  then img_normal  = nil end
    if not img_pressed then img_pressed = nil end
    if not control.set then
      control.set = function ()
        eg_action( control )
      end
    end
    control.id = button_add( img_normal, img_pressed, x-w/2, y-h/2, w, h, control.set, control.set )
    eg_subscription( control )
  end
 
  local eg_switch = function ( control )
    local x, y, w, h, args = table.unpack(control.images)
    if not control.set then
      control.set = function ( position, direction )
        eg_action( control, direction )
      end
    end
    table.insert(args, x-w/2)
    table.insert(args, y-h/2)
    table.insert(args, w)
    table.insert(args, h)
    table.insert(args, control.set) 
    control.id = switch_add( table.unpack(args) )
    control.indicate = function ()
      switch_set_position(control.id, control.value)
    end
    eg_subscription( control )
  end
  
  local eg_dial = function ( control )
    local image, x, y, w, h = table.unpack(control.images)
    if not control.set then 
      control.set = function ( direction )
        eg_action( control, direction )
      end
    end
    control.id = dial_add( image, x-w/2, y-h/2, w, h, control.set )
    touch_setting(control.id , "ROTATE_TICK", 6)
    eg_subscription( control )
  end
  
  local eg_control = function (control)
    if control.type == "buttton" then
      eg_button(control)
    elseif control.type == "switch" then
      eg_switch(control)
    elseif control.type == "dial" then
      eg_dial(control)
    end
  end
  -- END control support

  -- drawing
  local eg_draw_minor_mark = function( mark, scale, thinn )
    local r1, r2, _ = table.unpack( scale.marks.offset )
    local pos = interpolate_linear(scale.marks.sections, mark, true)
    local dx1, dy1, dx2, dy2 = eg_offsets( scale.kind, pos, r1, r2 )
    local cx, cy = table.unpack( scale.center )
    _move_to(cx + dx1, cy - dy1)
    _line_to(cx + dx2, cy - dy2)
    _stroke(scale.marks.color, scale.marks.width * thinn)
  end

  local eg_draw_major_mark = function( mark, scale )
    local pos = interpolate_linear(scale.marks.sections, mark, true)
    local r1, _, r2 = table.unpack( scale.marks.offset )
    local dx1, dy1, dx2, dy2 = eg_offsets( scale.kind, pos, r1, r2 )
    local cx, cy = table.unpack( scale.center )
    _move_to(cx + dx1, cy - dy1)
    _line_to(cx + dx2, cy - dy2)
    _stroke(scale.marks.color , scale.marks.width )
  end

  local eg_draw_scale_value = function ( value, scale )
    local pos = interpolate_linear(scale.marks.sections, value, true)
    local dx1, dy1, dx2, dy2 = eg_offsets( scale.kind, pos, scale.values.offset, 0 )
    local cx, cy = table.unpack( scale.center )
    local text = string.format("%1.0f", value / scale.values.divisor)
    _txt(text, eg_style(scale.values.style), cx + dx1, cy - dy1)
  end

  local eg_draw_redline = function ( value, redline, scale )
    local pos = interpolate_linear(scale.marks.sections, value, true)
    local dx1, dy1, dx2, dy2 = eg_offsets( scale.kind, pos, table.unpack( redline.offset ) )
    local cx, cy = table.unpack( scale.center )
    local color = redline.color or EASYGAUGE.REDLINE.COLOR
    local width = redline.width or EASYGAUGE.REDLINE.WIDTH
    _move_to(cx + dx1, cy - dy1)
    _line_to(cx + dx2, cy - dy2)
    _stroke(color, width)
  end

  local eg_draw_segment = function ( segment, arc, scale )
    local color = arc.segments[segment][SEGMENT.COLOR]
    if color then
      local cx, cy = table.unpack( scale.center )
      local settings = scale.marks.sections
      local pos1 = interpolate_linear(settings, arc.segments[segment][SEGMENT.VALUE],     true)
      local dx1, dy1 = eg_offsets( scale.kind, pos1, arc.offset, 0 )      
      local pos2 = interpolate_linear(settings, arc.segments[segment + 1][SEGMENT.VALUE], true) 
      local dx2, dy2 = eg_offsets( scale.kind, pos2, arc.offset, 0 )      
      if scale.kind == KIND.CIRCULAR then
        pos1 = pos1 + EASYGAUGE.ARC.ZERO
        pos2 = pos2 + EASYGAUGE.ARC.ZERO 
        _arc(cx, cy, pos1, pos2, arc.offset, pos2 > pos1 )
        _stroke(color, arc.width)
      elseif scale.kind == KIND.HORIZONTAL or scale.kind == KIND.VERTICAL then  
        _move_to(cx + dx1, cy - dy1)
        _line_to(cx + dx2, cy - dy2)
        _stroke(color, arc.width)
      end
    end
  end
  
  -- scale features
  local eg_arcs = function (scale)
    -- draw all arcs in the scale
    for _, arc in ipairs(scale.arcs or {}) do
      -- handle missing arc fields
      arc.width = arc.width or EASYGAUGE.ARC.WIDTH
      arc.segments = arc.segments or { 
        { scale.marks.sections[1][SECTION.VALUE], EASYGAUGE.ARC.COLOR },
        { scale.marks.sections[#scale.marks.sections][SECTION.VALUE] }
      }
      if arc.offset then
        -- draw all segments in the arc
        for segment = 1, #arc.segments - 1 do
          eg_draw_segment( segment, arc, scale )
        end
      end
    end
  end

  local eg_markings_and_values = function (scale)
    -- handle missing marking attributes
    scale.marks.color = scale.marks.color or EASYGAUGE.MARKS.COLOR
    scale.marks.width = scale.marks.width or EASYGAUGE.MARKS.WIDTH
    -- draw that scale if sections and offsets are specified
    local sections = scale.marks.sections
    if scale.marks.offset and sections then
      for s = 1, #sections - 1 do
        local min  = sections[s][SECTION.VALUE]
        local max  = sections[s + 1][SECTION.VALUE]
        local minor_step = sections[s][SECTION.MINOR] or sections[s][SECTION.MAJOR] or 0
        local major_step = sections[s][SECTION.MAJOR] or 0
        local thinn      = sections[s][SECTION.THINN] or 1
        
        -- draw minor section marks
        for mark = min, max, minor_step do
          eg_draw_minor_mark( mark, scale, thinn )
        end
        -- draw major section marks
        for mark = min, max, major_step do
          eg_draw_major_mark( mark, scale )
        end
        -- draw section values
        if scale.values then
          local every = scale.values.every or 1
          scale.values.divisor = 10^(scale.values.power or 0)
          for value = min, max, major_step * every do
            eg_draw_scale_value( value, scale )
          end
        end
      end
    end
  end 
       
  local eg_redlines = function (scale)
    for _, redline in ipairs(scale.redlines or {}) do
      if redline.offset then
        for _, value in ipairs(redline.values or {}) do
          eg_draw_redline( value, redline, scale )
        end
      end
    end
  end

  local eg_markups = function ( markups )
    for _, markup in ipairs( markups or {}) do
      if markup.text then
        local text = string.format(markup.text, eg_index)
        _txt(text, eg_style(markup.style), table.unpack(markup.position))
      elseif markup.image then
        local img, x, y, w, h = table.unpack(markup.image)
        local resource = resource_info(img)
        if resource and resource.TYPE == "IMAGE" then
          w = w or resource.WIDTH
          h = h or resource.HEIGHT
          img_add( img, (x or 0) - w/2 , (y or 0) - h/2, w, h )
        end
      end
    end
  end

  local eg_instrument = function()
    for k, scale in ipairs( easygauge.scales or {}) do
      -- handle missing fields
      scale.kind   = scale.kind or KIND.CIRCULAR
      scale.center = scale.center or easygauge.canvas.center
      -- draw scale features
      eg_arcs( scale )
      eg_markings_and_values( scale )  
      eg_redlines( scale )
      eg_markups( scale.markups )
    end
    for _, control in ipairs( easygauge.controls or {}) do
      eg_markups( control.markups )
    end
    -- instrument markups
    eg_markups( easygauge.markups )
  end

--{{
  return {
    log_prefix = log_prefix,
    version    = VERSION,
    image      = eg_image,
    canvas     = eg_canvas,
    control    = eg_control,
    gauge      = eg_gauge,
    instrument = eg_instrument
  }
--}}