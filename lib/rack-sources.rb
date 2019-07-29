module Rack
  #
  # Rack Middleware for extracting information from the request params and cookies.
  # It populates +env['source.tag']+, # +env['source.from']+ and
  # +env['source.time'] if it detects a request came from an sourced link
  #
  class Sources
    COOKIE_TAG = "source_tag"
    COOKIE_FROM = "source_from"
    COOKIE_TIME = "source_time"
    COOKIE_EXTRA_VARS = "source_extra"

    def initialize(app, opts = {})
      @app = app
      @param = opts[:param] || "source"
      @cookie_ttl = opts[:ttl] || 60*60*24*30  # 30 days
      @cookie_domain = opts[:domain] || nil
      @allow_overwrite = opts[:overwrite].nil? ? true : opts[:overwrite]
      @cookie_path = opts[:path] || nil
      @extras = opts[:extra_params] || []
    end

    def call(env)
      req = Rack::Request.new(env)

      params_tag = req.params[@param]
      cookie_tag = req.cookies[COOKIE_TAG]

      if cookie_tag
        tag, from, time, extras = cookie_info(req)
      end

      if params_tag && params_tag != cookie_tag
        if tag
          if @allow_overwrite
            tag, from, time, extras = params_info(req)
          end
        else
          tag, from, time, extras = params_info(req)
        end
      end

      if tag
        env["source.tag"] = tag
        env['source.from'] = from
        env['source.time'] = time
        env['source.extras'] = extras
      end

      status, headers, body = @app.call(env)

      if tag != cookie_tag
        bake_cookies(headers, tag, from, time, extras)
      end

      [status, headers, body]
    end

    def source_info(req)
      params_info(req) || cookie_info(req)
    end

    def params_info(req)
      extras = {}
      @extras.each { |key| extras[key] = req.params[key.to_s] }

      [req.params[@param], req.env["HTTP_REFERER"], Time.now.to_i, extras]
    end

    def cookie_info(req)
      extras = {}
      @extras.each { |key| extras[key] = req.cookies["#{COOKIE_EXTRA_VARS}.#{key}"] }
      [req.cookies[COOKIE_TAG], req.cookies[COOKIE_FROM], req.cookies[COOKIE_TIME].to_i, extras]
    end

    protected
    def bake_cookies(headers, tag, from, time, extras)
      expires = Time.now + @cookie_ttl
      data_hash = {
        COOKIE_TAG => tag,
        COOKIE_FROM => from,
        COOKIE_TIME => time
      }
      extras.each { |key, value| data_hash["#{COOKIE_EXTRA_VARS}.#{key}"] = value }

      data_hash.each do |key, value|
        cookie_hash = {:value => value, :expires => expires}
        cookie_hash[:domain] = @cookie_domain if @cookie_domain
        cookie_hash[:path] = @cookie_path if @cookie_path
        Rack::Utils.set_cookie_header!(headers, key, cookie_hash)
      end
    end
  end
end
