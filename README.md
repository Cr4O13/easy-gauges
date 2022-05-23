# Create Air Manager Instruments without Programming.

[Air Manager](https://www.siminnovations.com) is an application which allows to create your own 2D instrument panels for a variety of flight simulators.

"Easy Gauges" is a plugin that creates and displays Air Manager instruments from a specification file.

## Requirements

- Release asset .tar file from this Github account
- A licensed version of Air Manager or Air Player 4.1.3
- A flight simulator application
- A external editor (Notepad++ recommended)

Platforms: Any platform supported by Air Manager (tested under Windows 10 Home)

Limitations in the current release:

"Easy Gauges" currently supports
- Microsoft Flight Simulator 2020
- "Steam Gauges" with circular scales

Support for other simulators is planned (all simulators supported by Air Manager).
Support for gauges with horizontal or vertical scales is planned

## Key USP

- No programming required for basic usage.
- Instead, specify instrument features in a few lines of JSON syntax.
- Domain oriented specification

## Instrument Features supported

- Multiple instrument scales
- Each scale with different sized scale sections
- Each section with slectable division delimited with major marks
- Each division with selectable subdivisions separated with minor marks
- Scale values printed at all or selected major marks
- Multiplae scale arcs
- Each arc with differently colored segements
- Redline markings
- Multiple Gauges possible
- Each gauge with its own indicator (needle)
- Scales assigned to gauge(s)
- A subscription for each gauge
- Received values are indicated with perfect match on the assigned scale
- Indicator animation smoothing
- Many default settings for ease of specification

Example: Cessna 310R - Dual Engine Fuel Flow Indicator

<img src="./instruments/C-310R/dual fuel flow/preview.png" alt="Cessna 310R Dual Fuel Flow" stlye="float: left; margin-right: 10px;" />

## Advanced Features

- User property "Index" supporting multiple instances a "Easy Gauge" instrument in the same panel.
- Change default settings to your preferences
- Gauge position and scale tweaking

## Dependencies

Easy Gauges interfaces with Air Manager through its published API. No hacks, no mods.

Easy Gauges uses the following API functions:
- static_data_load
- resource_info
- user_prop_add_string
- user_prop_get
- instrument_prop
- img_add
- canvas_add
- canvas_draw
- _move_to
- _line_to
- _arc
- _stroke
- _text
- fs2020_variable_subscribe
- si_variable_subscribe
- interpolate_linear
- rotate
- log
