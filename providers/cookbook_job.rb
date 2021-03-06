# encoding: UTF-8
include JenkinsUtils
include JenkinsUtils::ConfigFileProvider

def whyrun_supported?
  true
end

use_inline_resources

action :create_if_missing do
  if @current_resource.exists
    Chef::Log.info "#{ @new_resource } already exists - nothing to do."
  else
    converge_by("Create #{ @new_resource }") do
      create_cookbook_job
      new_resource.updated_by_last_action(true)
    end
  end
end

action :create do
  if @current_resource.exists && !@current_resource.changed
    Chef::Log.info "#{ @new_resource } exists and unchanged - nothing to do."
  elsif @current_resource.exists
    Chef::Log.info "#{ @new_resource } already exists - updating."
    converge_by("Update #{ @new_resource }") do
      create_cookbook_job
      new_resource.updated_by_last_action(true)
    end
  else
    converge_by("Create #{ @new_resource }") do
      create_cookbook_job
      new_resource.updated_by_last_action(true)
    end
  end
end

action :disable do
  if @current_resource.exists && @current_resource.job_disabled
    Chef::Log.info "#{ @new_resource } already disabled - nothing to do."
  elsif @current_resource.exists && !@current_resource.job_disabled
    Chef::Log.info "#{ @new_resource } exists and not disabled - disabling."
    converge_by("Disable #{ @new_resource }") do
      disable_cookbook_job
      new_resource.updated_by_last_action(true)
    end
  else
    Chef::Log.fatal "#{ @new_resource } doesn't exist - can't disable."
  end
end

action :delete do
  if @current_resource.exists
    Chef::Log.info "#{ @new_resource } exists - deleting."
    converge_by("Disable #{ @new_resource }") do
      delete_cookbook_job
      new_resource.updated_by_last_action(true)
    end
  else
    Chef::Log.info "#{ @new_resource } doesn't exist - nothing to do."
  end
end

action :enable do
  if @current_resource.exists && @current_resource.job_disabled
    Chef::Log.info "#{ @new_resource } exists and disabled - enabling."
    converge_by("Enable #{ @new_resource }") do
      enable_cookbook_job
      new_resource.updated_by_last_action(true)
    end
  elsif @current_resource.exists
    Chef::Log.info "#{ @new_resource } already enabled - nothing to do."
  else
    Chef::Log.fatal "#{ @new_resource } doesn't exist - can't enabled."
  end
end

def load_current_resource
  @current_resource =
    Chef::Resource::JenkinsUtilsCookbookJob.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource.description(@new_resource.description)
  @current_resource.keep_dependencies(@new_resource.keep_dependencies)
  @current_resource.git_repo_url(@new_resource.git_repo_url)
  @current_resource.git_branch(@new_resource.git_branch)
  @current_resource.can_roam(@new_resource.can_roam)
  @current_resource.job_disabled(@new_resource.job_disabled)
  @current_resource.block_downstream(@new_resource.block_downstream)
  @current_resource.block_upstream(@new_resource.block_upstream)
  @current_resource.auth_token(@new_resource.auth_token)
  @current_resource.build_timers(@new_resource.build_timers)
  @current_resource.scm_poll_timers(@new_resource.scm_poll_timers)
  @current_resource.ignore_post_commit_hooks(
    @new_resource.ignore_post_commit_hooks)
  @current_resource.concurrent_build(@new_resource.concurrent_build)
  @current_resource.commands(@new_resource.commands)
  @current_resource.managed_files(@new_resource.managed_files)
  @current_resource.rvm_env(@new_resource.rvm_env)

  return unless job_exists?(node, @current_resource.name)
  @current_resource.exists = true
  @current_resource.job_disabled = true if job_disabled?(node,
                                                         @current_resource.name)
  @current_resource.changed = true if job_changed?(node, @current_resource)
end

private

def create_cookbook_job
  config_xml = ::File.join(Chef::Config[:file_cache_path],
                           "#{new_resource.name}-config.xml")
  description = "Jenkins Job for Chef cookbook #{new_resource.name}."
  description = new_resource.description unless new_resource.description.nil?
  managed_files = process_managed_files
  config_xml_template(config_xml, description, managed_files)
  jenkins_job new_resource.name do
    config config_xml
  end
end

def process_managed_files
  managed_files = []
  unless new_resource.managed_files.nil?
    new_resource.managed_files.each do |file|
      fn = file[:file_name] || file['file_name']
      tl = file[:target_location] || file['target_location']
      cnf_file = config_files(node)[fn]
      mf = { file_id: cnf_file[:id], target_location: tl }
      managed_files.push(mf)
    end
  end
  managed_files
end

def config_xml_template(config_xml, description, managed_files)
  template config_xml do
    source 'config.xml.erb'
    cookbook 'jenkins_utils'
    variables(description: description,
              keep_dependencies: new_resource.keep_dependencies,
              git_repo_url: new_resource.git_repo_url,
              git_branch: new_resource.git_branch,
              can_roam: new_resource.can_roam,
              job_disabled: new_resource.job_disabled,
              block_downstream: new_resource.block_downstream,
              auth_token: new_resource.auth_token,
              build_timers: new_resource.build_timers,
              scm_poll_timers: new_resource.scm_poll_timers,
              ignore_post_commit_hooks: new_resource.ignore_post_commit_hooks,
              block_upstream: new_resource.block_upstream,
              concurrent_build: new_resource.concurrent_build,
              commands: new_resource.commands,
              managed_files: managed_files,
              rvm_env: new_resource.rvm_env)
  end
end

def disable_cookbook_job
  jenkins_job new_resource.name do
    action :disable
  end
end

def delete_cookbook_job
  jenkins_job new_resource.name do
    action :delete
  end
end

def enable_cookbook_job
  jenkins_job new_resource.name do
    action :enable
  end
end
