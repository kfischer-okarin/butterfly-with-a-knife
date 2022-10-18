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
  args.state.position = { x: 640, y: 360 }
  args.state.velocity = { x: 0, y: 0 }
  args.state.knife = { x: 640, y: 260, length: 200, angle: 0 }
end

GRAVITY = 0.2
MAX_VELOCITY = 4
FLAP_STRENGTH = 4

def process_inputs(inputs, state)
  keyboard = inputs.keyboard
  state.velocity[:y] += FLAP_STRENGTH if keyboard.key_down.space
  state.rotate_knife = keyboard.left_right
end

def update(state)
  # handle_butterfly_movement(state)
  knife = state.knife
  knife.angle += state.rotate_knife
  state.knife_bottom = {
    x: knife.x - (Math.sin(knife.angle.to_radians) * knife[:length].half),
    y: knife.y + (Math.cos(knife.angle.to_radians) * knife[:length].half)
  }
  diff_x = state.position.x - state.knife_bottom.x
  diff_y = state.position.y - state.knife_bottom.y
  state.knife[:x] += diff_x
  state.knife[:y] += diff_y
end

def handle_butterfly_movement(state)
  state.velocity[:y] -= GRAVITY
  state.velocity[:y] = MAX_VELOCITY if state.velocity[:y] > MAX_VELOCITY
  state.position[:x] += state.velocity[:x]
  state.position[:y] += state.velocity[:y]
end

def render(state, outputs)
  outputs.primitives << {
    x: state.position.x - 16, y: state.position.y - 16, w: 32, h: 32
  }.solid!

  knife = state.knife
  outputs.primitives << {
    x: knife[:x] - 8, y: knife[:y] - knife[:length].half - 8, w: 16, h: knife[:length], angle: knife[:angle],
    path: :pixel
  }.sprite!
end

$gtk.reset
