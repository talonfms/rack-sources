require 'helper'
include Rack::Test::Methods

def app
  hello_world_app = lambda do |env|
    [200, {}, "Hello World"]
  end

  @app = Rack::Sources.new(hello_world_app)
end

describe "RackSources" do
  before :each do
    clear_cookies
  end

  it "should handle empty source info" do
    get '/'

    assert_nil last_request.env['source.tag']
    assert_nil last_request.env['source.from']
    assert_nil last_request.env['source.time']
  end

  it "should set source info from params" do
    Timecop.freeze do
      @time = Time.now
      get '/', {'ref'=>'123'}, 'HTTP_REFERER' => "http://www.foo.com"
    end

    last_request.env['source.tag'].must_equal "123"
    last_request.env['source.from'].must_equal "http://www.foo.com"
    last_request.env['source.time'].must_equal @time.to_i
  end

  it "should save source info in a cookie" do
    Timecop.freeze do
      @time = Time.now
      get '/', {'ref'=>'123'}, 'HTTP_REFERER' => "http://www.foo.com"
    end

    rack_mock_session.cookie_jar["source_tag"].must_equal "123"
    rack_mock_session.cookie_jar["source_from"].must_equal "http://www.foo.com"
    rack_mock_session.cookie_jar["source_time"].must_equal "#{@time.to_i}"
  end

  describe "when cookie exists" do
    before :each do
      @time = Time.now
      clear_cookies
      set_cookie("source_tag=123")
      set_cookie("source_from=http://www.foo.com")
      set_cookie("source_time=#{@time.to_i}")
    end

    it "should restore source info from cookie" do
      Timecop.freeze do
        get '/', {}, 'HTTP_REFERER' => "http://www.bar.com"
      end

      last_request.env['source.tag'].must_equal "123"
      last_request.env['source.from'].must_equal "http://www.foo.com"
      last_request.env['source.time'].must_equal @time.to_i
    end

    it 'should not update existing cookie' do
      Timecop.freeze(60*60*24) do #1 day later
        get '/', {}, 'HTTP_REFERER' => "http://www.bar.com"
      end

      last_request.env['source.tag'].must_equal "123"
      last_request.env['source.from'].must_equal "http://www.foo.com"

      # should not change timestamp of older cookie
      last_request.env['source.time'].must_equal @time.to_i

      rack_mock_session.cookie_jar["source_tag"].must_equal "123"
      rack_mock_session.cookie_jar["source_from"].must_equal "http://www.foo.com"
      rack_mock_session.cookie_jar["source_time"].must_equal "#{@time.to_i}"
    end

    it "should use newer source from params" do
      Timecop.freeze(60*60*24) do #1 day later
        @new_time = Time.now
        get '/', {'ref' => 456}, 'HTTP_REFERER' => "http://www.bar.com"
      end

      rack_mock_session.cookie_jar["source_tag"].must_equal "456"
      rack_mock_session.cookie_jar["source_from"].must_equal "http://www.bar.com"
      rack_mock_session.cookie_jar["source_time"].must_equal "#{@new_time.to_i}"

      last_request.env['source.tag'].must_equal "456"
      last_request.env['source.from'].must_equal "http://www.bar.com"
      last_request.env['source.time'].must_equal @new_time.to_i
    end
  end
end
