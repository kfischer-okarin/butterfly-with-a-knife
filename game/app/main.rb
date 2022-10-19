require 'lib/debug_mode.rb'
require 'lib/extra_keys.rb'
require 'lib/resources.rb'

require 'app/resources.rb'

def tick(args)
  setup(args) if args.tick_count.zero?
  process_inputs(args.inputs, args.state)
  update(args.state)
  render(args.state, args.outputs)
end

def setup(args)
  args.state.butterfly = { x: 640, y: 360, v_x: 0, v_y: 0 }
  args.state.knife = { x: 640, y: 260, length: 200, angle: 0 }
end

GRAVITY = 0.2
MAX_VELOCITY = 4
FLAP_STRENGTH = 4

def process_inputs(inputs, state)
  keyboard = inputs.keyboard
  state.butterfly[:v_y] += FLAP_STRENGTH if keyboard.key_down.space
  state.rotate_knife = keyboard.left_right
end

def update(state)
  # handle_butterfly_movement(state)
  knife = state.knife
  knife.angle += state.rotate_knife
  knife_bottom = {
    x: knife.x - (Math.sin(knife.angle.to_radians) * knife[:length].half),
    y: knife.y + (Math.cos(knife.angle.to_radians) * knife[:length].half)
  }
  diff_x = state.butterfly[:x] - knife_bottom[:x]
  diff_y = state.butterfly[:y] - knife_bottom[:y]
  state.knife[:x] += diff_x
  state.knife[:y] += diff_y
  state.knife_bottom = knife_bottom
end

def handle_butterfly_movement(state)
  state.butterfly[:v_y] -= GRAVITY
  state.butterfly[:v_y] = MAX_VELOCITY if state.butterfly[:v_y] > MAX_VELOCITY
  state.butterfly[:x] += state.butterfly[:v_x]
  state.butterfly[:y] += state.butterfly[:v_y]
end

def render(state, outputs)
  render_butterfly state.butterfly, outputs
  render_knife state.knife, outputs
end

def render_butterfly(butterfly, outputs)
  outputs.primitives << {
    x: butterfly[:x] - 16, y: butterfly[:y] - 16, w: 32, h: 32
  }.solid!
end

def render_knife(knife, outputs)
  outputs.primitives << {
    x: knife[:x] - 8, y: knife[:y] - knife[:length].half - 8, w: 16, h: knife[:length], angle: knife[:angle],
    path: :pixel
  }.sprite!
end

$gtk.reset
