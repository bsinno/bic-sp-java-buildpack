# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/jre'
require 'java_buildpack/util/tokenized_version'
require 'java_buildpack/jre/memory/openjdk_memory_heuristic_factory'
require 'java_buildpack/component'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Jre

    # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK-like JRE.
    class OpenJDKLikeJre < JavaBuildpack::Component::VersionedDependencyComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        @application    = context[:application]
        @component_name = context[:component_name]
        @configuration  = context[:configuration]
        @droplet        = context[:droplet]

        @droplet.java_home.root = @droplet.sandbox
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @version, @uri             = JavaBuildpack::Repository::ConfiguredItem.find_item(@component_name,
                                                                                         @configuration)
        @droplet.java_home.version = @version
        super
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
        @droplet.copy_resources
      end

     # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        toolPath = qualify_path_tool(@droplet.java_home.root) + "/lib/tools.jar"
        @droplet.java_opts
          .add_system_property('java.io.tmpdir', '$TMPDIR')
          .push('-XX:+HeapDumpOnOutOfMemoryError')
          .push('-Xbootclasspath/a:'+ toolPath)
          .add_option('-XX:HeapDumpPath', '$PWD/oom_heapdump_work.hprof')
          .add_option('-XX:OnOutOfMemoryError',  killjava )
          .concat memory
      end

      private

      KEY_MEMORY_HEURISTICS = 'memory_heuristics'.freeze

      KEY_MEMORY_SIZES = 'memory_sizes'.freeze

      VERSION_8 = JavaBuildpack::Util::TokenizedVersion.new('1.8.0').freeze

      private_constant :KEY_MEMORY_HEURISTICS, :KEY_MEMORY_SIZES, :VERSION_8
      
      def qualify_path(path, root = @droplet.root)
        "$PWD/#{path.relative_path_from(root)}"
      end
      
      def qualify_path_tool(path, root = @droplet.root)
        "#{path.relative_path_from(root)}"
      end
      
      
      def killjava
        if @application.services.one_service?'heapdump-uploader'
          credentials = @application.services.find_service('heapdump-uploader')['credentials']
          username = credentials['username']
          password = credentials['password']
          endpoint = credentials['endpoint']
          qualify_path(@droplet.sandbox) + "\'/bin/killjava.sh #{username} #{password} #{endpoint}'"
        else
          @droplet.sandbox + 'bin/killjava.sh'
        end
      end

      def memory
        sizes      = @configuration[KEY_MEMORY_SIZES] ? @configuration[KEY_MEMORY_SIZES].clone : {}
        heuristics = @configuration[KEY_MEMORY_HEURISTICS] ? @configuration[KEY_MEMORY_HEURISTICS].clone : {}

        if @version < VERSION_8
          heuristics.delete 'metaspace'
          sizes.delete 'metaspace'
        else
          heuristics.delete 'permgen'
          sizes.delete 'permgen'
        end

        OpenJDKMemoryHeuristicFactory.create_memory_heuristic(sizes, heuristics, @version).resolve
      end

    end

  end
end
