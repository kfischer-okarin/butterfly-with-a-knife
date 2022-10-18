module DebugExtension
  class Debug
    attr_reader :static_primitives
    attr_accessor :log_color

    DEBUG_BUILD = false

    def initialize(args)
      @args = args
      @active = DEBUG_BUILD || !$gtk.production
      @debug_mode = false
      @debug_logs = []
      @static_debug_logs = {}
      @static_primitives = []
      @last_debug_y = 720
      @log_color = { r: 0, g: 0, b: 0 }
    end

    def time_block_last_execute(name)
      start = Time.now.to_f
      yield
      duration_ms = ((Time.now.to_f - start) * 1000).floor
      static_log(:"time_#{name}", "Last execution of #{name}: #{duration_ms}ms")
    end

    def debug_mode?
      @debug_mode
    end

    def static_log(name, message)
      @static_debug_logs[name] = message
    end

    def remove_static_log(name)
      @static_debug_logs.delete(name)
    end

    def log(message, pos = nil)
      return unless @active

      label_pos = pos || [0, @last_debug_y]
      @last_debug_y -= 20 unless pos
      @debug_logs << @log_color.merge(x: label_pos.x, y: label_pos.y, text: message).label!
    end

    def tick
      return unless @active

      handle_debug_function

      add_static_logs
      render_debug_logs
      render_debug_primitives
    end

    private

    DEBUG_FUNCTIONS = {
      f9: :toggle_debug,
      f10: :reset_with_same_seed,
      f11: :reset,
      f12: :take_screenshot
    }.freeze

    def handle_debug_function
      pressed_key = DEBUG_FUNCTIONS.keys.find { |key| @args.inputs.keyboard.key_down.send(key) }
      send(DEBUG_FUNCTIONS[pressed_key]) if pressed_key
    end

    def toggle_debug
      @debug_mode = !@debug_mode
    end

    def reset_with_same_seed
      $gtk.reset
    end

    def reset
      $gtk.reset seed: (Time.now.to_f * 1000).to_i
    end

    def take_screenshot
      time = Time.now
      formatted_time = format(
        '%d-%02d-%02dT%02d-%02d-%02d',
        time.year, time.month, time.day, time.hour, time.min, time.sec
      )
      @args.outputs.screenshots << {
        x: 0, y: 0, w: 1280, h: 720, a: 255,
        path: "screenshot-#{formatted_time}.png"
      }
    end

    def handle_reset
      # DO SOMETHING
    end

    def add_static_logs
      @static_debug_logs.each_value do |message|
        log(message)
      end
    end

    def render_debug_logs
      log($gtk.current_framerate.to_i.to_s)
      log('DEBUG MODE') if @debug_mode

      @args.outputs.debug << @debug_logs
      @debug_logs.clear
      @last_debug_y = 720
    end

    def render_debug_primitives
      @args.outputs.debug << @static_primitives
    end
  end

  # Adds args.debug
  module Args
    def debug
      @debug ||= Debug.new(self)
      $debug = @debug
    end
  end

  # Runs the debug tick
  module Runtime
    def tick_core
      @args.debug.tick
      super
    end

    def reset(*args)
      super
      @args.debug.handle_reset
    end
  end
end

GTK::Args.include DebugExtension::Args unless GTK::Args.is_a? DebugExtension::Args
GTK::Runtime.prepend DebugExtension::Runtime unless GTK::Runtime.is_a? DebugExtension::Runtime
