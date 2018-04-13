#
# Author:: Joshua Timberman (<joshua@chef.io>)
# Cookbook Name:: reprepro
# Recipe:: default
#
# Copyright 2010-2015, Chef Software, Inc.
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

include_recipe 'build-essential'

unless node['reprepro']['disable_databag']
  begin
    apt_repo = data_bag_item('reprepro', 'main')
    node['reprepro'].keys.each do |key|
      next if key.to_sym == :pgp
      # NOTE: Use #has_key? so data bags can nil out existing values
      node.default['reprepro'][key] = apt_repo[key] if apt_repo.key?(key)
    end
    node.default['reprepro']['pgp_email'] = apt_repo['pgp']['email']
    node.default['reprepro']['pgp_fingerprint'] = apt_repo['pgp']['fingerprint']
  rescue Net::HTTPServerException
    Chef::Log.warn 'Data bag not found. Using default attribute settings!'
    include_recipe 'gpg'
  end
end

ruby_block 'save node data' do
  block do
    node.save
  end
  action :create
  not_if { ::Chef::Config[:solo] }
end

%w(apt-utils dpkg-dev reprepro debian-keyring devscripts dput).each do |pkg|
  package pkg
end

# Create the base_repo_dir to host the rest of repositories
[node['reprepro']['base_repo_dir']].each do |dir|
  directory dir do
    owner 'nobody'
    group 'nogroup'
    mode '0755'
    recursive true
  end
end

node['reprepro']['repositories_directories'].each do |dir|
  repo_full_path = "#{node['reprepro']['base_repo_dir']}/#{dir}"

  directory repo_full_path  do
    owner 'nobody'
    group 'nogroup'
    mode '0755'
    recursive true
  end

  # incoming directories
  directory "#{repo_full_path}/#{node['reprepro']['incoming']}" do
    owner 'nobody'
    group 'nogroup'
    mode '0755'
    recursive true
  end

  %w(conf db dists pool tarballs).each do |conf_dir|
    directory "#{repo_full_path}/#{conf_dir}" do
      owner 'nobody'
      group 'nogroup'
      mode '0755'
    end
  end

  %w(distributions incoming pulls).each do |conf|
    template "#{repo_full_path}/conf/#{conf}" do
      source "#{conf}.erb"
      mode '0644'
      owner 'nobody'
      group 'nogroup'
      variables(
        allow: node['reprepro']['allow'],
        codenames: node['reprepro']['codenames'],
        architectures: node['reprepro']['architectures'],
        incoming: node['reprepro']['incoming'],
        pulls: node['reprepro']['pulls']
      )
    end
  end

  if node['reprepro']['enable_repository_on_host']
    execute "apt-key add #{pgp_key}" do
      action :nothing
      if apt_repo
        subscribes :run, "template[#{pgp_key}]", :immediately
      else
        subscribes :run, "file[#{pgp_key}]", :immediately
      end
    end

    apt_repository 'reprepro' do
      uri "file://#{repo_full_path}"
      distribution node['lsb']['codename']
      components ['main']
    end
  end
end

if apt_repo
  # TODO: migrate to base_repo_dir when using data_bags
  pgp_key = "#{apt_repo['base_repo_dir']}/#{node['reprepro']['pgp_email']}.gpg.key"

  execute 'import packaging key' do
    command "/bin/echo -e '#{apt_repo['pgp']['private']}' | gpg --import -"
    user 'root'
    cwd '/root'
    environment 'GNUPGHOME' => node['reprepro']['gnupg_home']
    not_if "GNUPGHOME=/root/.gnupg gpg --list-secret-keys --fingerprint #{node['reprepro']['pgp_email']} | egrep -qx '.*Key fingerprint = #{node['reprepro']['pgp_fingerprint']}'"
  end

  template pgp_key do
    source 'pgp_key.erb'
    mode '0644'
    owner 'nobody'
    group 'nogroup'
    variables(
      pgp_public: apt_repo['pgp']['public']
    )
  end
else
  pgp_key = "#{node['reprepro']['base_repo_dir']}/#{node['gpg']['name']['email']}.gpg.key"
  node.default['reprepro']['pgp_email'] = node['gpg']['name']['email']

  execute "sudo -u #{node['gpg']['user']} -i gpg --armor --export #{node['gpg']['name']['real']} > #{pgp_key}" do
    creates pgp_key
  end

  file pgp_key do
    mode '0644'
    owner 'nobody'
    group 'nogroup'
  end

  # Iterate over the list of repositories
  [node['reprepro']['repositories_directories']].each do |dir|
    repo_full_path = "#{node['reprepro']['base_repo_dir']}/#{dir}"

    execute "reprepro -Vb #{repo_full_path} export" do
      action :nothing
      subscribes :run, "file[#{pgp_key}]", :immediately
      environment 'GNUPGHOME' => node['reprepro']['gnupg_home']
    end
  end
end


begin
  include_recipe "reprepro::#{node['reprepro']['server']}"
rescue Chef::Exceptions::RecipeNotFound
  Chef::Log.warn "Missing recipe for #{node['reprepro']['server']}, only 'nginx'or 'apache2' are available"
end
