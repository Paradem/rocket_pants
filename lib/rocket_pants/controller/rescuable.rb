module RocketPants
  # An alternative to Rail's built in ActionController::Rescue module,
  # tailored to deeply integrate rescue notififers into the application.
  #
  # Thus, it is relatively simple to 
  module Rescuable
    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable

    DEFAULT_NOTIFIER_CALLBACK = lambda do |controller, exception, req|
      # Do nothing by default...
    end

    NAMED_NOTIFIER_CALLBACKS = {
      :airbrake => lambda { |c, e, r|
        unless c.send(:airbrake_local_request?)
          controller.error_identifier = Airbrake.notify(exception, c.send(:airbrake_request_data))
        end
      }
    }

    included do
      class_attribute :exception_notifier_callback
      attr_accessor :error_identifier
      self.exception_notifier_callback ||= DEFAULT_NOTIFIER_CALLBACK
    end

    module ClassMethods

      # Tells rocketpants to use the given exception handler to deal with errors.
      # E.g. use_named_exception_handler! :airbrake
      # @param [Symbol] name the name of the exception handler to use.
      def use_named_exception_notifier(name)
        handler = NAMED_NOTIFIER_CALLBACKS.fetch(name, DEFAULT_NOTIFIER_CALLBACK)
        self.exception_notifier_callback = handler
      end

    end

    module InstanceMethods

      # Overrides the lookup_error_extras method to also include an error_identifier field
      # to be sent back to the client.
      def lookup_error_extras(exception)
        extras = super
        extras = extras.merge(:error_identifier => error_identifier) if error_identifier
        extras
      end

      private

      # Overrides the processing internals to rescue any exceptions and handle them with the
      # registered exception rescue handler.
      def process_action(*args)
        super
      rescue Exception => exception
        # Otherwise, use the default built in handler.
        logger.error "Exception occured: #{exception.class.name} - #{exception.message}"
        logger.error "Exception backtrace:"
        exception.backtrace[0, 10].each do |backtrace_line|
          logger.error "=> #{backtrace_line}"
        end
        exception_notifier_callback.call(self, exception, request)
        render_error exception
      end

    end

  end
end