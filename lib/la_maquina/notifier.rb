module LaMaquina
  module Notifier
    extend ActiveSupport::Concern
    include ActiveRecord::Callbacks

    included do
      
      class << self
        attr_accessor :notified_objects
      end

      self.notified_objects = []

      
      class << self
        def notifies_about(object, opts = {})
          notified_objects << {:object => object, :options => opts}
        end
      end

      after_commit  :notify!
    end

    def notify!
      self.class.notified_objects.each do |notified|

        object  = notified[:object]
        options = notified[:options]

        comm_object = options[:using]

        klass = notified_klass( object, options )
        id    = notified_id( object, options )

        notifier_class = LaMaquina.format_object_name(self)

        begin
          if comm_object
            comm_object.notify(:notified_class => klass, :notified_id => id, :notifier_class => notifier_class)
          else
            LaMaquina::Engine.notify! klass, id, notifier_class
          end
        rescue => e
          LaMaquina.error_notifier.notify(  e,
                                            notified_class: klass,
                                            notified_id: id,
                                            notifier_class: notifier_class,
                                            notifier_id: self.id)
        end
      end
    end

    private

    def notified_klass(object, options)
      if object == :self
        return LaMaquina.format_object_name(self)
      end

      if options[:polymorphic]
        return LaMaquina.format_class_name(self.send("#{object}_type"))
      end
      
      if options[:class_name]
        return LaMaquina.format_class_name(options[:class_name])
      end
      
      if options[:class]
        return LaMaquina.format_class_name(options[:class])
      end
      
      return object
    end

    def notified_id(object, options)
      if object == :self
        return self.id 
      end

      if options[:through]
        return self.send(options[:through]).send("#{object}_id") 
      end

      self.send("#{object}_id")
    end
  end
end