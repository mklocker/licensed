# frozen_string_literal: true

module Licensed
  module Source
    class GitSubmodule
      REMOTE_URL_ARGUMENT = "$(git remote get-url origin)".freeze
      GIT_SUBMODULES_ARGUMENTS = [
        "$displaypath", # path from repo root to submodule folder to find the name and submodule content
        "$toplevel", # path to parent repository to calculate the ancestor chain
        "$sha1", # use the commit reference of the submodule as the version
        "$(git config --get remote.origin.url)", # use the configured remote origin url as the homepage
      ].freeze

      def self.type
        "git_submodule"
      end

      def initialize(config)
        @config = config
      end

      def enabled?
        return false unless Licensed::Shell.tool_available?("git") && Licensed::Git.git_repo?
        gitmodules_path.exist?
      end

      def dependencies
        @dependencies ||= git_submodules_command.lines.map do |line|
          displaypath, toplevel, version, homepage = line.strip.split
          name = File.basename(displaypath)
          submodule_path = if toplevel == @config.pwd.to_s
            name
          else
            parent = File.basename(toplevel)
            "#{submodule_paths[parent]}/#{name}"
          end
          submodule_paths[name] = submodule_path

          Licensed::Dependency.new(@config.pwd.join(displaypath), {
            "type" => self.class.type,
            "name" => name,
            "version" => version,
            "homepage" => homepage,
            "path" => submodule_path
          })
        end
      end

      def submodule_paths
        @submodule_paths ||= {}
      end

      def git_submodules_command
        Licensed::Shell.execute("git", "submodule", "foreach", "-q", "--recursive", "echo #{GIT_SUBMODULES_ARGUMENTS.join(" ")}")
      end

      def gitmodules_path
        @config.pwd.join(".gitmodules")
      end
    end
  end
end
