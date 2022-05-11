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
    pre      = "BETA",
    sub_rel  = "1"
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
  -- API Wrappers
  local eg_image = function ( image )
    if image[1] then
      local img, x, y, w, h = table.unpack(image)
      x = x or 0
      y = y or 0
      w = w or instrument_prop("PREF_WIDTH")
      h = h or instrument_prop("PREF_HEIGHT")
      if resource_info(img) then
        return img_add( img, x, y, w, h )
      end
    end
  end

  local eg_canvas = function ( )
    easygauge.canvas = easygauge.canvas or { 0, 0, instrument_prop("PREF_WIDTH"), instrument_prop("PREF_HEIGHT") }
    return canvas_add( table.unpack(easygauge.canvas) )
  end

  local eg_indicator = function ( gauge )
    local indicator = gauge.indicator or { EASYGAUGE.IMAGE.INDICATOR }
    local img, w, h, x, y  = table.unpack(indicator)
    if img then
      local resource = resource_info(img)
      if resource and resource.TYPE == "IMAGE" then
        w = w or resource.WIDTH
        h = h or resource.HEIGHT
        x = easygauge.canvas[1] + gauge.center[1] - w/2 + (x or 0)
        y = easygauge.canvas[2] + gauge.center[2] - h/2 + (y or 0)
        gauge.indicator = add_image( { img, x, y, w, h } )
        local animation = gauge.animation or {}
        if not gauge.indicate then
          gauge.indicate = function ()
            local position = interpolate_linear( gauge.sections, gauge.value, true )
            rotate(gauge.indicator, position, table.unpack(animation) )
          end
        end
      end
    end
  end

  local eg_subscription = function ( gauge )
    if gauge.variable then
      if not gauge.update then
        gauge.update = function ( value )
          gauge.value = value
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
    gauge.value    = gauge.value or 0.0
    eg_indicator( gauge )
    eg_subscription( gauge )
  end

  local eg_style = function ( style_spec  )
    local style  = style_spec or {}
    
    local font   = style.font   or EASYGAUGE.MARKUP.FONT
    local size   = string.format("%i", style.size or EASYGAUGE.MARKUP.SIZE)
    local color  = style.color  or EASYGAUGE.MARKUP.COLOR
    local valign = style.valign or EASYGAUGE.MARKUP.VALIGN
    local halign = style.halign or EASYGAUGE.MARKUP.HALIGN

    return string.format(EASYGAUGE.MARKUP.FORMAT, font, size, color, valign, halign)
  end

  local eg_minor_mark = function( mark, scale, thinn )
    local cx, cy = table.unpack( scale.center )
    local r1, r2, _ = table.unpack( scale.marks.offset )
    
    local color = scale.marks.color 
    local width = scale.marks.width 
    
    if scale.kind == KIND.CIRCULAR then
                            
      local rad = math.rad( interpolate_linear(scale.marks.sections, mark, true) )
      local sin = math.sin(rad)
      local cos = math.cos(rad)
              
      _move_to(cx + sin * r2, cy - cos * r2)
      _line_to(cx + sin * r1, cy - cos * r1)
      _stroke(color, width * thinn)
    end
  end

  local eg_major_mark = function( mark, scale )
    local cx, cy = table.unpack( scale.center )
    local r1, _, r2 = table.unpack( scale.marks.offset )

    local color = scale.marks.color 
    local width = scale.marks.width 
    
    if scale.kind == KIND.CIRCULAR then
                            
      local rad = math.rad( interpolate_linear(scale.marks.sections, mark, true) )
      local sin = math.sin(rad)
      local cos = math.cos(rad)
              
      _move_to(cx + sin * r2, cy - cos * r2)
      _line_to(cx + sin * r1, cy - cos * r1)
      _stroke(color, width)
    end
  end

  local eg_arc_segment = function ( segment, arc, scale )
    local cx, cy = table.unpack( scale.center )
    local color = arc.segments[segment][SEGMENT.COLOR]
    -- draw segment when color is specified, otherwise skip
    if color then
      if scale.kind == KIND.CIRCULAR then 
        local settings = scale.marks.sections
        local angle1 = interpolate_linear(settings, arc.segments[segment][SEGMENT.VALUE],     true) + EASYGAUGE.ARC.ZERO
        local angle2 = interpolate_linear(settings, arc.segments[segment + 1][SEGMENT.VALUE], true) + EASYGAUGE.ARC.ZERO 
                
        _arc(cx, cy, angle1, angle2, arc.offset, angle2 > angle1 )
        _stroke(color, arc.width)
      end
    end
  end

  local eg_arcs = function (scale)
    if scale.arcs then
      -- draw all arcs in the scale
      for _, arc in ipairs(scale.arcs) do
        -- handle missing arc fields
        arc.width = arc.width or EASYGAUGE.ARC.WIDTH
        arc.segments = arc.segments or { 
          { scale.marks.sections[1][SECTION.VALUE], EASYGAUGE.ARC.COLOR },
          { scale.marks.sections[#scale.marks.sections][SECTION.VALUE] }
        }
        if arc.offset then
          -- draw all segments in the arc
          for segment = 1, #arc.segments - 1 do
            eg_arc_segment( segment, arc, scale )
          end
        end
      end
    end
  end

  local eg_scale_value = function ( value, scale )
    local cx, cy = table.unpack( scale.center )
    local rv = scale.values.offset
    
    if scale.kind == KIND.CIRCULAR then
      local rad = math.rad(interpolate_linear(scale.marks.sections, value, true))
      local sin = math.sin(rad)
      local cos = math.cos(rad)
       
      local text = string.format("%1.0f", value / scale.values.divisor)
      _txt(text, eg_style(scale.values.style), cx + sin * rv, cy - cos * rv)
    end
  end

  local eg_scale = function (scale)
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
          eg_minor_mark( mark, scale, thinn )
        end
        -- draw major section marks
        for mark = min, max, major_step do
          eg_major_mark( mark, scale )
        end
        -- draw section values
        if scale.values then
          local every = scale.values.every or 1
          scale.values.divisor = 10^(scale.values.power or 0)
          for value = min, max, major_step * every do
            eg_scale_value( value, scale )
          end
        end
      end
    end
  end 
       
  local eg_redline = function ( value, scale )
    local cx, cy = table.unpack( scale.center )
    local r1, r2 = table.unpack( scale.redlines.offset )
    -- handle missing fields
    local color = scale.redlines.color or EASYGAUGE.REDLINE.COLOR
    local width = scale.redlines.width or EASYGAUGE.REDLINE.WIDTH
           
    if scale.kind == KIND.CIRCULAR then
      local rad = math.rad(interpolate_linear(scale.marks.sections, value, true))
      local sin = math.sin(rad)
      local cos = math.cos(rad)
      
      _move_to(cx + sin * r1, cy - cos * r1)
      _line_to(cx + sin * r2, cy - cos * r2)
      _stroke(color, width)
    end
  end

  local eg_redlines = function (scale)
    if scale.redlines then
      if scale.redlines.offset then
        local values = scale.redlines.values or {}
        for _, value in ipairs(values) do
          eg_redline( value, scale )
        end
      end
    end
  end

  local eg_markups = function ( markups )
    if markups then
      for _, markup in ipairs( markups ) do
        local text = string.format(markup.text, eg_index)
        _txt(text, eg_style(markup.style), table.unpack(markup.position))
      end
    end
  end

  local eg_instrument = function()
    -- draw scale features
    for k, scale in ipairs( easygauge.scales ) do
      -- handle missing fields
      scale.kind   = scale.kind or KIND.CIRCULAR
      scale.center = scale.center or easygauge.canvas.center
      
      eg_arcs( scale )
      eg_scale( scale )  
      eg_redlines( scale )
      eg_markups( scale.markups )
    end
    -- draw instrument markups
    eg_markups( easygauge.markups )
  end

--{{
  return {
    log_prefix = log_prefix,
    version    = VERSION,
    image      = eg_image,
    canvas     = eg_canvas,
    gauge      = eg_gauge,
    instrument = eg_instrument
  }
--}}