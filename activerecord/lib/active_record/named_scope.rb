require 'active_support/core_ext/array'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/object/blank'

module ActiveRecord
  module NamedScope
    extend ActiveSupport::Concern

    module ClassMethods
      # Returns an anonymous scope.
      #
      #   posts = Post.scoped
      #   posts.size # Fires "select count(*) from  posts" and returns the count
      #   posts.each {|p| puts p.name } # Fires "select * from posts" and loads post objects
      #
      #   fruits = Fruit.scoped
      #   fruits = fruits.where(:colour => 'red') if options[:red_only]
      #   fruits = fruits.limit(10) if limited?
      #
      # Anonymous \scopes tend to be useful when procedurally generating complex queries, where passing
      # intermediate values (scopes) around as first-class objects is convenient.
      #
      # You can define a scope that applies to all finders using ActiveRecord::Base.default_scope.
      def scoped(options = {}, &block)
        if options.present?
          relation = scoped.apply_finder_options(options)
          block_given? ? relation.extending(Module.new(&block)) : relation
        else
          current_scoped_methods ? unscoped.merge(current_scoped_methods) : unscoped.clone
        end
      end

      def scopes
        read_inheritable_attribute(:scopes) || write_inheritable_attribute(:scopes, {})
      end

      # Adds a class method for retrieving and querying objects. A scope represents a narrowing of a database query,
      # such as <tt>where(:color => :red).select('shirts.*').includes(:washing_instructions)</tt>.
      #
      #   class Shirt < ActiveRecord::Base
      #     scope :red, where(:color => 'red')
      #     scope :dry_clean_only, joins(:washing_instructions).where('washing_instructions.dry_clean_only = ?', true)
      #   end
      #
      # The above calls to <tt>scope</tt> define class methods Shirt.red and Shirt.dry_clean_only. Shirt.red,
      # in effect, represents the query <tt>Shirt.where(:color => 'red')</tt>.
      #
      # Unlike <tt>Shirt.find(...)</tt>, however, the object returned by Shirt.red is not an Array; it resembles the association object
      # constructed by a <tt>has_many</tt> declaration. For instance, you can invoke <tt>Shirt.red.first</tt>, <tt>Shirt.red.count</tt>,
      # <tt>Shirt.red.where(:size => 'small')</tt>. Also, just as with the association objects, named \scopes act like an Array,
      # implementing Enumerable; <tt>Shirt.red.each(&block)</tt>, <tt>Shirt.red.first</tt>, and <tt>Shirt.red.inject(memo, &block)</tt>
      # all behave as if Shirt.red really was an Array.
      #
      # These named \scopes are composable. For instance, <tt>Shirt.red.dry_clean_only</tt> will produce all shirts that are both red and dry clean only.
      # Nested finds and calculations also work with these compositions: <tt>Shirt.red.dry_clean_only.count</tt> returns the number of garments
      # for which these criteria obtain. Similarly with <tt>Shirt.red.dry_clean_only.average(:thread_count)</tt>.
      #
      # All \scopes are available as class methods on the ActiveRecord::Base descendant upon which the \scopes were defined. But they are also available to
      # <tt>has_many</tt> associations. If,
      #
      #   class Person < ActiveRecord::Base
      #     has_many :shirts
      #   end
      #
      # then <tt>elton.shirts.red.dry_clean_only</tt> will return all of Elton's red, dry clean
      # only shirts.
      #
      # Named \scopes can also be procedural:
      #
      #   class Shirt < ActiveRecord::Base
      #     scope :colored, lambda {|color| where(:color => color) }
      #   end
      #
      # In this example, <tt>Shirt.colored('puce')</tt> finds all puce shirts.
      #
      # Named \scopes can also have extensions, just as with <tt>has_many</tt> declarations:
      #
      #   class Shirt < ActiveRecord::Base
      #     scope :red, where(:color => 'red') do
      #       def dom_id
      #         'red_shirts'
      #       end
      #     end
      #   end
      def scope(name, scope_options = {}, &block)
        name = name.to_sym

        if !scopes[name] && respond_to?(name, true)
          logger.warn "Creating scope :#{name}. " \
                      "Overwriting existing method #{self.name}.#{name}."
        end

        scopes[name] = lambda do |*args|
          options = scope_options.is_a?(Proc) ? scope_options.call(*args) : scope_options

          relation = scoped
          relation = options.is_a?(Hash) ? relation.apply_finder_options(options) : scoped.merge(options) if options
          block_given? ? relation.extending(Module.new(&block)) : relation
        end

        singleton_class.send :define_method, name, &scopes[name]
      end

      def named_scope(*args, &block)
        ActiveSupport::Deprecation.warn("Base.named_scope has been deprecated, please use Base.scope instead", caller)
        scope(*args, &block)
      end
    end

  end
end
