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
  args.state.butterfly = build_point_mass(BUTTERFLY_MASS, x: 640, y: 360)
  args.state.knife = build_rod_mass(KNIFE_MASS, x: 640, y: 260, length: KNIFE_LENGTH)
end

def build_point_mass(mass, **values)
  build_rigid_body(values).merge!(m: mass, I: 0)
end

def build_rod_mass(mass, length:, **values)
  build_rigid_body(values).merge!(m: mass, I: mass * length * length / 12)
end

def build_rigid_body(values = nil)
  {
    m: 1, x: 640, y: 360, v_x: 0, v_y: 0, F_x: 0, F_y: 0,
    I: 0, angle: 0, v_angle: 0, torque: 0
  }.merge!(values || {})
end

BUTTERFLY_MASS = 1
FLAP_POWER = 4
FLAP_ACCELERATION = FLAP_POWER / BUTTERFLY_MASS

KNIFE_MASS = 100
KNIFE_LENGTH = 200
KNIFE_HALF_LENGTH = KNIFE_LENGTH / 2

GRAVITY = 0.2
MAX_VELOCITY = 4

def process_inputs(inputs, state)
  keyboard = inputs.keyboard
  state.butterfly[:v_y] += FLAP_POWER if keyboard.key_down.space
  state.rotate_knife = keyboard.left_right
end

def update(state)
  # handle_butterfly_movement(state)
  knife = state.knife
  knife.angle += state.rotate_knife
  knife_bottom = {
    x: knife.x - (Math.sin(knife.angle.to_radians) * KNIFE_HALF_LENGTH),
    y: knife.y + (Math.cos(knife.angle.to_radians) * KNIFE_HALF_LENGTH)
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
    x: knife[:x] - 8, y: knife[:y] - KNIFE_HALF_LENGTH - 8, w: 16, h: KNIFE_LENGTH, angle: knife[:angle],
    path: :pixel
  }.sprite!
end

$gtk.reset
