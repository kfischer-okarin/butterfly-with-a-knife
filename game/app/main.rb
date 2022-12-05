require 'lib/debug_mode.rb'
require 'lib/extra_keys.rb'
require 'lib/resources.rb'

require 'app/resources.rb'

def tick(args)
  setup(args) if args.tick_count.zero?
  process_inputs(args.inputs, args.state)
  update(args.state)
  render(args.state, args.outputs, args.audio)
end

def setup(args)
  args.state.butterfly = build_point_mass(BUTTERFLY_MASS, x: 640, y: 360).merge!(
    ticks_since_flap: 0,
    ticks_since_audio: 0
  )
  args.state.knife = build_rod_mass(
    KNIFE_MASS,
    x: 640, y: 260, length: KNIFE_LENGTH * LENGTH_FACTOR, angle: 270
  ).merge!(
    ticks_since_cut: 0,
    ticks_since_audio: 0
  )
  update_knife_points args.state.knife
  args.state.spider = { x: 1000, y: 150 }
  args.state.start_time = Time.now.to_f
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
  update_knife_points(state.knife)
  apply_gravity(state.butterfly)
  apply_gravity(state.knife)
  apply_connection_force(state.butterfly, state.knife)
  update_body(state.butterfly)
  update_body(state.knife)
  update_butterfly(state.butterfly)
  update_knife(state.knife)
  check_knife_collision(state.knife, state.spider)
  update_spider(state.spider)
end

def update_knife_points(knife)
  rotator = PointRotator.new knife, knife[:angle]
  knife[:bottom] = rotator.rotate(x: 0, y: KNIFE_HALF_LENGTH)
  knife[:previous_blade_top] = knife[:blade_top] || rotator.rotate(x: 0, y: -80)
  knife[:blade_top] = rotator.rotate(x: 0, y: -80)
end

class PointRotator
  def initialize(center, angle)
    @center = center
    @sin = Math.sin(angle.to_radians)
    @cos = Math.cos(angle.to_radians)
  end

  def rotate(relative_point)
    {
      x: @center[:x] + (relative_point[:x] * @cos) - (relative_point[:y] * @sin),
      y: @center[:y] + (relative_point[:x] * @sin) + (relative_point[:y] * @cos)
    }
  end
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
  body[:angle] = body[:angle] % 360
  body[:F_x] = 0
  body[:F_y] = 0
  body[:torque] = 0
end

def apply_connection_force(butterfly, knife)
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

def update_butterfly(butterfly)
  butterfly[:ticks_since_flap] += 1
  butterfly[:ticks_since_audio] += 1
end

def update_knife(knife)
  knife[:cut] = knife_cuts? knife
  knife[:ticks_since_audio] += 1
  knife[:ticks_since_cut] += 1
  return unless knife[:cut]

  knife[:cut_position] = knife[:blade_top].dup
  knife[:cut_hitbox] = {
    x: knife[:cut_position][:x], y: knife[:cut_position][:y] - 130,
    w: 160, h: 160
  }
  knife[:ticks_since_cut] = 0
end

def knife_cuts?(knife)
  knife[:tip_v] = {
    x: knife[:blade_top][:x] - knife[:previous_blade_top][:x],
    y: knife[:blade_top][:y] - knife[:previous_blade_top][:y]
  }
  knife[:tip_speed] = Math.sqrt(
    (knife[:tip_v][:x]**2) + (knife[:tip_v][:y]**2)
  )

  # 0 degree is down, 90 is right, 180 is up, 270 is left
  knife[:angle] > 100 && knife[:angle] < 120 && knife[:v_angle] < -3 && knife[:tip_speed] > 7 &&
    knife[:ticks_since_cut] > 20
end

def check_knife_collision(knife, spider)
  spider[:hit] = knife[:ticks_since_cut] < 3 && knife[:cut_hitbox] &&
                 knife[:cut_hitbox].intersect_rect?(spider[:hitbox])
end

def update_spider(spider)
  spider[:hitbox] = {
    x: spider[:x] - 65, y: spider[:y] - 50, w: 130, h: 100
  }
end

# def line_circle_intersection(line, circle)
#   line_origin = { x: line[:x1], y: line[:y1] }
#   line_vector = { x: line[:x2] - line[:x1], y: line[:y2] - line[:y1] }
#   circle_to_line_origin = { x: line_origin[:x] - circle[:x], y: line_origin[:y] - circle[:y] }
#   a = line_vector[:x] * line_vector[:x] + line_vector[:y] * line_vector[:y]
#   b = 2 * (line_vector[:x] * circle_to_line_origin[:x] + line_vector[:y] * circle_to_line_origin[:y])
#   c = circle_to_line_origin[:x] * circle_to_line_origin[:x] + circle_to_line_origin[:y] * circle_to_line_origin[:y] - circle[:r] * circle[:r]
#   discriminant = b * b - 4 * a * c
#   if discriminant < 0
#     return nil
#   else
#     discriminant = Math.sqrt(discriminant)
#     t1 = (-b - discriminant) / (2 * a)
#     t2 = (-b + discriminant) / (2 * a)
#     if t1 >= 0 && t1 <= 1
#       return t1
#     elsif t2 >= 0 && t2 <= 1
#       return t2
#     else
#       return nil
#     end
#   end
# end

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

def render(state, outputs, audio)
  render_butterfly state.butterfly, state.knife, outputs, audio
  render_spider state.spider, outputs
  render_ui state, outputs
end

def render_butterfly(butterfly, knife, outputs, audio)
  suffix = butterfly[:ticks_since_flap] < 5 ? '_flap.png' : '.png'
  rect = { x: butterfly[:x] - 93, y: butterfly[:y] - 50, w: 187, h: 196 }
  outputs.primitives << rect.to_sprite(path: "sprites/butterfly#{suffix}")
  knife_rect = {
    x: knife[:x] - 30, y: knife[:y] - KNIFE_HALF_LENGTH,
    w: 61, h: KNIFE_LENGTH,
    angle: knife[:angle], angle_anchor_x: 0.5, angle_anchor_y: 0.5
  }
  outputs.primitives << knife_rect.to_sprite(angle: knife[:angle] + 180, path: 'sprites/knife.png')

  if butterfly[:ticks_since_audio] > 5 && butterfly[:ticks_since_flap].zero?
    butterfly[:ticks_since_audio] = -1
    audio[:butterfly_flap] = {
      input: "audio/flap#{(rand * 3).ceil}.wav"
    }
  end

  if knife[:cut] && knife[:ticks_since_audio] > 60
    knife[:ticks_since_audio] = -1
    audio[:knife_cut] = {
      input: "audio/woosh#{(rand * 3).ceil}.wav",
      pitch: 0.5 + (rand * 0.5)
    }
  end

  if knife[:ticks_since_cut] < 18 && knife[:cut_position]
    outputs.primitives << {
      x: knife[:cut_position][:x] - 100, y: knife[:cut_position][:y] - 150,
      w: 275, h: 200,
      path: "sprites/slash/File#{(knife[:ticks_since_cut] / 3).floor + 1}.png"
    }.sprite!

    outputs.primitives << knife[:cut_hitbox].to_border(r: 255, g: 0, b: 0) if $debug.debug_mode?
  end

  return unless $debug.debug_mode?

  outputs.primitives << rect.to_border(r: 255)
  outputs.primitives << knife_rect.to_sprite(path: :pixel, r: 255, g: 0, b: 0, a: 64)
  outputs.primitives << { x: butterfly[:x] - 8, y: butterfly[:y] - 8, w: 16, h: 16, r: 255 }.solid!
  outputs.primitives << { x: knife[:x] - 8, y: knife[:y] - 8, w: 16, h: 16, r: 255 }.solid!
  outputs.primitives << { x: knife[:blade_top][:x] - 8, y: knife[:blade_top][:y] - 8, w: 16, h: 16, g: 255 }.solid!
  outputs.primitives << { x: knife[:bottom][:x]  - 8, y: knife[:bottom][:y] - 8, w: 16, h: 16, r: 255 }.solid!
end

def render_spider(spider, outputs)
  color = spider[:hit] ? { r: 255, g: 0, b: 0 } : { r: 255, g: 255, b: 255 }
  outputs.primitives << { x: spider[:x] - 77, y: spider[:y] - 65, w: 155, h: 130, path: 'sprites/spider_body.png' }.sprite!(color)
  return unless $debug.debug_mode?

  outputs.primitives << spider[:hitbox].to_border(r: 255, g: 0, b: 0)
  outputs.primitives << { x: spider[:x] - 8, y: spider[:y] - 8, w: 16, h: 16, r: 255 }.solid!
end

def render_ui(state, outputs)
  remaining_time = [20 - (Time.now.to_f - state.start_time).floor, 0].max
  outputs.primitives << {
    x: 640,
    y: 700,
    size_enum: 5,
    alignment_enum: 1,
    text: '%02d' % remaining_time,
  }.label!
  return unless $debug.debug_mode?

  $debug.log "knife tip speed: #{state.knife[:tip_speed]}"
end

$gtk.reset
