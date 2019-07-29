Rack::Sources
================

Rack::Sources is a rack middleware that extracts information about an external source. Specifically, it looks up for specific parameter (<code>source</code> by default) in the request. If found, it persists source tag, referring url and time in a cookie for later use.

Common Scenario
---------------

Original source tracking is used to track referral from an external source using a specifically generated link. This middleware helps you to do that.

1. You associate an source tag (for eg. <code>LinkedIn</code>) and add it to public URLs.
2. The public url is posted on external sites like <code>http://yoursite.org?source=LinkedIn</code>.
3. A user clicks through the link and lands on your site.
4. Rack::Sources middleware finds <code>source</code> parameter in the request, extracts source tag and saves it in a cookie
5. User signs up (now or later) and you mark it as a referral from your partner

Installation
------------
Works with Rails version **> 2** (including Rails 5).

Include the gem in your Gemfile:

    gem 'rack-sources'
    
or install it:

    gem install rack-sources

Rails Example Usage
---------------------

Add the middleware to your application stack:

    # Rails 3+ App - in config/application.rb
    class Application < Rails::Application
      ...
      config.middleware.use Rack::Sources
      ...
    end
    
    # Rails 2 App - in config/environment.rb
    Rails::Initializer.run do |config|
      ...
      config.middleware.use "Rack::Sources"
      ...
    end

Now you can check any request to see who came to your site via an affiliated link and use this information in your application. Affiliate tag is saved in the cookie and will come into play if user returns to your site later.

    class ExampleController < ApplicationController
      def index
        str = if request.env['source.tag'] && source = Source.find_by_source_tag(request.env['source.tag'])
          "Halo, referral! You've been referred here by #{source.name} from #{request.env['source.from']} @ #{Time.at(env['source.time'])}"
        else
          "We're glad you found us on your own!"
        end
        
        render :text => str
      end
    end


Customization
-------------

You can customize parameter name by providing <code>:param</code> option (default is <code>source</code>).
By default cookie is set for 30 days, you can extend time to live with <code>:ttl</code> option (default is 30 days). 

    #Rails 3+ in config/application.rb
    class Application < Rails::Application
      ...
      config.middleware.use Rack::Sources, {:param => 'src_id', :ttl => 3.months}
      ...
    end

The <code>:domain</code> option allows to customize cookie domain. 

    #Rails 3+ in config/application.rb
    class Application < Rails::Application
      ...
      config.middleware.use Rack::Sources, :domain => '.example.org'
      ...
    end

The <code>:path</code> option allows to hardcode the cookie path allowing you to record affiliate links at any URL on your site.

    #Rails 3+ in config/application.rb
    class Application < Rails::Application
      ...
      config.middleware.use Rack::Sources, { :path => '/' }
      ...
    end

Middleware will set cookie on <code>.example.org</code> so it's accessible on <code>www.example.org</code>, <code>app.example.org</code> etc.

The <code>:overwrite</code> option allows to set whether to overwrite the existing affiliate tag previously stored in cookies. By default it is set to `true`.

If you want to capture more attributes from the query string whenever it comes from an affiliate you can define those with the <code>extra_params</code> value.

    #Rails 3+ in config/application.rb
    class Application < Rails::Application
      ...
      config.middleware.use Rack::Sources, { :extra_params => [:great_query_parameter] }
      ...
    end

These will be availble through <code>env['source.extras']</code> as a hash with the same keys.

Credits
=======

Cloned from rack-affiliated (https://github.com/alexlevin/rack-affiliates) to allow us to use both middlewares in the same application