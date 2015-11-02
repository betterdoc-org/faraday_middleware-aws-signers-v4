require 'faraday_middleware/aws_signers_v4_ext'

class FaradayMiddleware::AwsSignersV4 < Faraday::Middleware
  class Request
    def initialize(env)
      @env = env
    end

    def headers
      @env.request_headers
    end

    def body
      @env.body || ''
    end

    def endpoint
      url = @env.url.dup

      # Escape the query string or the request won't sign correctly
      if url and url.query
        re_escape_query!(url)
      end

      url
    end

    def http_method
      @env.method.to_s.upcase
    end

    private

    def re_escape_query!(url)
      unescaped = CGI.unescape(url.query)

      if unescaped =~ / /
        url.query = Seahorse::Util.uri_escape(unescaped)
      end
    end
  end

  def initialize(app, options = nil)
    super(app)

    credentials = options.fetch(:credentials)
    service_name = options.fetch(:service_name)
    region = options.fetch(:region)
    @signer = Aws::Signers::V4.new(credentials, service_name, region)
    @net_http = net_http?(app)
  end

  def call(env)
    normalize_for_net_http!(env)
    req = Request.new(env)
    @signer.sign(req)
    @app.call(env)
  end

  private

  def net_http?(app)
    app.is_a?(Faraday::Adapter::NetHttp)
  end

  def normalize_for_net_http!(env)
    return unless @net_http

    if Net::HTTP::HAVE_ZLIB
      env.request_headers['Accept-Encoding'] ||= 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3'
    end

    env.request_headers['Accept'] ||= '*/*'
  end
end
