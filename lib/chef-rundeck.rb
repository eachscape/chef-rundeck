#
# Copyright 2010, Opscode, Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'sinatra/base'
require 'chef'
require 'chef/node'
require 'chef/mixin/xml_escape'

class ChefRundeck < Sinatra::Base

  include Chef::Mixin::XMLEscape

  class << self
    attr_accessor :config_file
    attr_accessor :username
    attr_accessor :web_ui_url

    def configure
      Chef::Config.from_file(ChefRundeck.config_file)
      Chef::Log.level = Chef::Config[:log_level]
    end
  end

  get '/' do
    content_type 'text/xml'
    response = '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE project PUBLIC "-//DTO Labs Inc.//DTD Resources Document 1.0//EN" "project.dtd"><project>'
    primary_nodes = {}
    Chef::Node.list(true).each do |node_array|
      begin
        node = node_array[1]
        next unless node[:fqdn]
        puts node
        #--
        # Certain features in Rundeck require the osFamily value to be set to 'unix' to work appropriately. - SRK
        #++
        os_family = node[:kernel][:os] =~ /windows/i ? 'windows' : 'unix'
        env = node.chef_environment
        roles = node.run_list.roles
        tags = []
        roles.each do |r|
          primary_nodes[env] ||= {}
          if primary_nodes[env][r].nil?
            primary_nodes[env][r] = node
            tags << "#{r}-primary"
          else
            tags << "#{r}-secondary"
          end
        end
        response << <<-EOH
  <node name="#{xml_escape(node[:fqdn])}" 
        type="Node" 
        description="#{xml_escape(node.name)}"
        osArch="#{xml_escape(node[:kernel][:machine])}"
        osFamily="#{xml_escape(os_family)}"
        osName="#{xml_escape(node[:platform])}"
        osVersion="#{xml_escape(node[:platform_version])}"
        tags="#{xml_escape(([env] + tags + roles).join(','))}"
        username="#{xml_escape('deploy')}"
        hostname="#{xml_escape(node[:fqdn])}"
        editUrl="#{xml_escape(ChefRundeck.web_ui_url)}/nodes/#{xml_escape(node.name)}/edit"/>
EOH
      rescue Exception => e
        puts "#{e}: #{e.message}"
        puts e.backtrace.join("\n")
        next
      end
    end
    response << "</project>"
    response
  end
end

