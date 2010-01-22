module ActionController
  class Base < Metal
    abstract!

    include AbstractController::Callbacks
    include AbstractController::Layouts
    include AbstractController::Translation

    include ActionController::Helpers
    helper :all # By default, all helpers should be included
    
    include ActionController::HideActions
    include ActionController::UrlFor
    include ActionController::Redirecting
    include ActionController::Rendering
    include ActionController::Renderers::All
    include ActionController::ConditionalGet
    include ActionController::RackDelegation
    include ActionController::Configuration

    # Legacy modules
    include SessionManagement
    include ActionController::Caching
    include ActionController::MimeResponds

    # Rails 2.x compatibility
    include ActionController::Compatibility

    include ActionController::Cookies
    include ActionController::Flash
    include ActionController::Verification
    include ActionController::RequestForgeryProtection
    include ActionController::Streaming
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include ActionController::HttpAuthentication::Digest::ControllerMethods

    # Add instrumentations hooks at the bottom, to ensure they instrument
    # all the methods properly.
    include ActionController::Instrumentation

    # TODO: Extract into its own module
    # This should be moved together with other normalizing behavior
    module ImplicitRender
      def send_action(*)
        ret = super
        default_render unless response_body
        ret
      end

      def default_render
        render
      end

      def method_for_action(action_name)
        super || begin
          if template_exists?(action_name.to_s, {:formats => formats}, :_prefix => controller_path)
            "default_render"
          end
        end
      end
    end

    include ImplicitRender

    include ActionController::Rescue

    def self.inherited(klass)
      ::ActionController::Base.subclasses << klass.to_s
      super
    end

    def self.subclasses
      @subclasses ||= []
    end

    # This method has been moved to ActionDispatch::Request.filter_parameters
    def self.filter_parameter_logging(*args, &block)
      ActiveSupport::Deprecation.warn("Setting filter_parameter_logging in ActionController is deprecated and has no longer effect, please set 'config.filter_parameters' in config/application.rb instead", caller)
      filter = Rails.application.config.filter_parameters
      filter.concat(args)
      filter << block if block
      filter
    end

    def _normalize_options(action=nil, options={}, &blk)
      case action
      when NilClass
      when Hash, String
        options = super
      when Symbol
        options.merge! :action => action
      else
        options.merge! :partial => action
      end

      if options.key?(:action) && options[:action].to_s.index("/")
        options[:template] = options.delete(:action)
      end

      if options[:status]
        options[:status] = Rack::Utils.status_code(options[:status])
      end

      options[:update] = blk if block_given?
      options
    end
  end
end
