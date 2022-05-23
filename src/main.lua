-- {{
local eg = require "src/easygauge"
local eg_version = eg.version
local eg_image   = eg.image
local eg_canvas  = eg.canvas
local eg_switch  = eg.switch
local eg_gauge   = eg.gauge
local eg_instrument = eg.instrument

function easygauge()
--}}EASYGAUGE RUNNER
  local function main()
    -- User properties
    local eg_property = {
      index = user_prop_add_string("Index", "", "Optionally enter a index value to insert into the variable name (e.g. engine index)." )
    }
    easygauge = static_data_load( "easygauge.json" )
    if easygauge then
      -- User properties
      eg_index = user_prop_get(eg_property.index)
      -- Background
      eg_image(easygauge.background or { EASYGAUGE.IMAGE.BACKGROUND })
      -- The Canvas
      easygauge.id = eg_canvas()
      easygauge.canvas.center = { easygauge.canvas[CANVAS.WIDTH]/2, easygauge.canvas[CANVAS.HEIGHT]/2 }
      canvas_draw(easygauge.id, eg_instrument)
      -- Switches
      for _, switch in ipairs(easygauge.switches) do
        eg_switch(switch)
      end
      -- Gauges
      for _, gauge in ipairs(easygauge.gauges) do
        eg_gauge(gauge)
      end
      -- Cover and Bezel
      print()
      eg_image(easygauge.cover or { EASYGAUGE.IMAGE.COVER } )
      eg_image(easygauge.bezel or { EASYGAUGE.IMAGE.BEZEL } )
      -- Display Instrument
      easygauge.display = function ()
        for _, gauge in ipairs(easygauge.gauges) do
          gauge.indicate()
        end
      end
      easygauge.display()
    else
      log("ERROR", "Loading configuration file 'easygauge.json' failed!")
    end
  end
  
  return main()
end

-- ---------------------------------------------------------------------
-- END Easy Gauge
-- ---------------------------------------------------------------------
