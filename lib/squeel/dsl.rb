module Squeel
  # Interprets DSL blocks, generating various Squeel nodes as appropriate.
  class DSL

    # We're creating a BlankSlate-type class here, since we want most
    # method calls to fall through to method_missing.
    Squeel.evil_things do
      (instance_methods + private_instance_methods).each do |method|
        unless method.to_s =~ /^(__|instance_eval)/
          undef_method method
        end
      end
    end

    # Called from an adapter, not directly.
    # Evaluates a block of Squeel DSL code.
    #
    # @example A DSL block that uses instance_eval
    #   Post.where{title == 'Hello world!'}
    #
    # @example A DSL block with access to methods from the closure
    #   Post.where{|dsl| dsl.title == local_method(local_var)}
    #
    # @yield [dsl] A block of Squeel DSL code, with an optional argument if
    #   access to closure methods is desired.
    # @return The results of the interpreted DSL code.
    def self.eval(&block)
      if block.arity > 0
        yield self.new(block.binding)
      else
        self.new(block.binding).instance_eval(&block)
      end
    end

    private

    def initialize(caller_binding)
      @caller = caller_binding.eval 'self'
    end

    def my(&block)
      @caller.instance_eval &block
    end

    # Node generation inside DSL blocks.
    #
    # @overload node_name
    #   Creates a Stub. Method calls chained from this Stub will determine
    #   what type of node we eventually end up with.
    #   @return [Nodes::Stub] A stub with the name of the method
    # @overload node_name(klass)
    #   Creates a Join with a polymorphic class matching the given parameter
    #   @param [Class] klass The polymorphic class of the join node
    #   @return [Nodes::Join] A join node with the name of the method and the given class
    # @overload node_name(first_arg, *other_args)
    #   Creates a Function with the given arguments becoming the function's arguments
    #   @param first_arg The first argument
    #   @param *other_args Optional additional arguments
    #   @return [Nodes::Function] A function node for the given method name with the given arguments
    def method_missing(method_id, *args)
      super if method_id == :to_ary

      if args.empty?
        Nodes::Stub.new method_id
      elsif (args.size == 1) && (Class === args[0])
        Nodes::Join.new(method_id, Arel::InnerJoin, args[0])
      else
        Nodes::Function.new method_id, args
      end
    end

  end
end