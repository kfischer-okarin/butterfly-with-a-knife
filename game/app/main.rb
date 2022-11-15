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
  args.state.butterfly = build_point_mass(BUTTERFLY_MASS, x: 640, y: 360).merge!(ticks_since_flap: 0)
  args.state.knife = build_rod_mass(KNIFE_MASS, x: 640, y: 260, length: KNIFE_LENGTH * LENGTH_FACTOR, angle: 270)
  args.state.knife[:bottom] = calc_knife_bottom(args.state.knife)
  move_knife_to_butterfly(args.state.knife, args.state.butterfly)
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

AIR_FRICTION = 0.01

BUTTERFLY_MASS = 1
FLAP_FORCE = 6
HORIZONTAL_FORCE = 0.15

KNIFE_MASS = 2
KNIFE_LENGTH = 200
LENGTH_FACTOR = 0.15
KNIFE_HALF_LENGTH = KNIFE_LENGTH / 2

GRAVITY = 0.1

CONNECTION_STRENGTH = 0.03

def process_inputs(inputs, state)
  keyboard = inputs.keyboard
  if keyboard.key_down.space
    state.butterfly[:F_y] += FLAP_FORCE
    state.butterfly[:ticks_since_flap] = -1
  end
  state.butterfly[:F_x] += keyboard.left_right * HORIZONTAL_FORCE
end

def update(state)
  apply_gravity(state.butterfly)
  apply_gravity(state.knife)
  apply_connection_force(state.butterfly, state.knife)
  update_body(state.butterfly)
  update_body(state.knife)
  state.butterfly[:ticks_since_flap] += 1
end

def apply_gravity(body)
  apply_force(body, force: { x: 0, y: -GRAVITY * body[:m] })
end

def update_body(body)
  body[:v_x] = (body[:v_x] * (1 - AIR_FRICTION)) + (body[:F_x] / body[:m])
  body[:v_y] = (body[:v_y] * (1 - AIR_FRICTION)) + (body[:F_y] / body[:m])
  body[:x] += body[:v_x]
  body[:y] += body[:v_y]
  body[:v_angle] = (body[:v_angle] * (1 - AIR_FRICTION)) + (body[:torque] / body[:I])
  body[:angle] += body[:v_angle]
  body[:F_x] = 0
  body[:F_y] = 0
  body[:torque] = 0
end

def apply_connection_force(butterfly, knife)
  knife[:bottom] = calc_knife_bottom(knife)
  butterfly_to_knife = {
    x: knife[:bottom][:x] - butterfly[:x],
    y: knife[:bottom][:y] - butterfly[:y]
  }

  apply_force(
    butterfly,
    force: {
      x: butterfly_to_knife[:x] * CONNECTION_STRENGTH,
      y: butterfly_to_knife[:y] * CONNECTION_STRENGTH
    }
  )

  apply_force(
    knife,
    force: {
      x: -butterfly_to_knife[:x] * CONNECTION_STRENGTH,
      y: -butterfly_to_knife[:y] * CONNECTION_STRENGTH
    },
    position: knife[:bottom]
  )
end

def calc_knife_bottom(knife)
  {
    x: knife[:x] - (Math.sin(knife.angle.to_radians) * KNIFE_HALF_LENGTH),
    y: knife[:y] + (Math.cos(knife.angle.to_radians) * KNIFE_HALF_LENGTH)
  }
end

def move_knife_to_butterfly(knife, butterfly)
  diff_x = butterfly[:x] - knife[:bottom][:x]
  diff_y = butterfly[:y] - knife[:bottom][:y]
  knife[:x] += diff_x
  knife[:y] += diff_y
end

def apply_force(body, force:, position: nil)
  body[:F_x] += force[:x]
  body[:F_y] += force[:y]
  return unless position

  body[:torque] += ((position[:x] - body[:x]) * force[:y]) - ((position[:y] - body[:y]) * force[:x])
end

def render(state, outputs)
  render_butterfly state.butterfly, outputs
  render_knife state.knife, outputs
end

def render_butterfly(butterfly, outputs)
  path = butterfly[:ticks_since_flap] < 5 ? 'sprites/butterfly_flap.png' : 'sprites/butterfly.png'
  outputs.primitives << {
    x: butterfly[:x] - 100, y: butterfly[:y] - 100, w: 256, h: 256, path: path
  }.sprite!
end

def render_knife(knife, outputs)
  outputs.primitives << {
    x: knife[:x] - 8, y: knife[:y] - KNIFE_HALF_LENGTH - 8, w: 61, h: KNIFE_LENGTH, angle: knife[:angle] + 180,
    path: 'sprites/knife.png'
  }.sprite!
end

$gtk.reset
