module Aegis
  class Permissions
    class << self

      UNDEFINED_ACTION_STRATEGIES = [
        :allow, :deny, :default_permission, :error
      ]

      def missing_action_means(strategy)
        UNDEFINED_ACTION_STRATEGIES.include?(strategy) or raise ArgumentError, "missing_action_means must be one of #{UNDEFINED_ACTION_STRATEGIES.inspect}"
        @undefined_action_strategy = strategy
      end

      def permission(*args)
        raise "The Aegis API has changed. Please check http://github.com/makandra/aegis for details."
      end

      def action(*args, &block)
        prepare
        @parser.action(*args, &block)
      end

      def resource(*args, &block)
        prepare
        @parser.resource(*args, &block)
      end

      def namespace(*args, &block)
        prepare
        @parser.namespace(*args, &block)
      end

      def resources(*args, &block)
        prepare
        @parser.resources(*args, &block)
      end

      def may?(user, path, *args)
        find_action_by_path(path).may?(user, *args)
      end

      def may!(user, path, *args)
        find_action_by_path(path).may!(user, *args)
      end

      def role(role_name, options = {})
        role_name = role_name.to_s
        role_name != 'everyone' or raise "Cannot define a role named: #{role_name}"
        @roles_by_name ||= {}
        @roles_by_name[role_name] = Aegis::Role.new(role_name, options)
      end

      def roles
        @roles_by_name.values.sort
      end

      def find_role_by_name(name)
        @roles_by_name[name.to_s]
      end

      def guess_action(resource, action_name, map)
        action = nil
        guess_action_paths(resource, action_name, map).detect do |path|
          action = find_action_by_path(path, false)
        end
        handle_undefined_action(action)
      end

      def find_action_by_path(path, handle_undefined = true)
        compile
        action = @actions_by_path[path.to_s]
        action = handle_undefined_action(action) if handle_undefined
        action
      end

      def app_permissions(option)
        if option.is_a?(Class)
          option
        else
          (option || '::Permissions').constantize
        end
      end

      def inspect
        compile
        "Permissions(#{@root_resource.inspect})"
      end

      private

      def handle_undefined_action(possibly_undefined_action)
        possibly_undefined_action ||= case @undefined_action_strategy
          when :default_permission then Aegis::Action.undefined
          when :allow then Aegis::Action.allow_to_all
          when :deny then Aegis::Action.deny_to_all
          when :error then raise "Undefined Aegis action: #{action}"
        end
      end

      def guess_action_paths(resource, action_name, map)
        if mapped = map[action_name]
          [ mapped.singularize,
            mapped.pluralize ]
        else
          [ "#{action_name}_#{resource.singularize}",
            "#{action_name}_#{resource.pluralize}" ]
        end
      end

      def prepare
        unless @parser
          @parser = Aegis::Parser.new
          @undefined_action_strategy ||= :default_permission
        end
      end

      def compile
        unless @root_resource
          prepare
          @root_resource = Aegis::Resource.new(nil, nil, :root, {})
          Aegis::Compiler.compile(@root_resource, @parser.atoms)
          @actions_by_path = @root_resource.index_actions_by_path
        end
      end

    end
  end
end
