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
end

GRAVITY = 0.2
MAX_VELOCITY = 4
FLAP_STRENGTH = 4

def process_inputs(inputs, state)
  state.velocity[:y] += FLAP_STRENGTH if inputs.keyboard.key_down.space
end

def update(state)
  state.velocity[:y] -= GRAVITY
  state.velocity[:y] = MAX_VELOCITY if state.velocity[:y] > MAX_VELOCITY
  state.position[:x] += state.velocity[:x]
  state.position[:y] += state.velocity[:y]
end

def render(state, outputs)
  outputs.primitives << {
    x: state.position.x - 16, y: state.position.y - 16, w: 32, h: 32,
  }.solid!
end

$gtk.reset
