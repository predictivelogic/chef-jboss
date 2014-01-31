#
# Cookbook Name:: jboss
# Recipe:: default
#
# Copyright 2011, Bryan W. Berry
#
# license Apache v2.0
#

jboss_home = node['jboss']['jboss_home']
jboss_user = node['jboss']['jboss_user']
jboss_url = node['jboss']['dl_url']

# find all members of the jboss group, so we can make them members
jboss_members = Array.new
jboss_members << jboss_user

# (MT) We don't use Chef Server (yet?).  There's probably a more 
# elegant way to get rid of this Chef Server dependency, but
# at this  point I just want to  provision a JBoss server, so
# elegance takes a back seat.
#search(:users, "groups:jboss").each do |u|
#  jboss_members << u.id
#end

ext = '.zip'

jboss_filename = node['jboss']['dl_url'].
  split('/')[-1].
  sub!(ext, '')
path_arr = jboss_home.split('/')
path_arr.delete_at(-1)
jboss_parent = path_arr.join('/')

# create user
user jboss_user


group jboss_user do
  # find all users that currently exist on the machine
  # then only add those jboss_members that already have
  # user accounts
  local_users = Array.new
  node['etc']['passwd'].each do |name,values|
    local_users << name
  end
  jboss_members = jboss_members & local_users
  members jboss_members
  action :modify
end

directory jboss_parent do
  group jboss_user
  owner jboss_user
  mode "0755"
end

# get files
log "Installing JBoss from #{jboss_url} to #{jboss_parent}"
bash "put_files" do
  code <<-EOH
  cd /tmp
  wget #{jboss_url}

  cd #{jboss_parent}
  unzip /tmp/#{jboss_filename}#{ext}
  UNZIPDIR=`ls`
  
  chown -R jboss:jboss #{jboss_parent}
  ln -s $UNZIPDIR #{jboss_home}
  chown -R jboss:jboss #{jboss_home}
  rm -f #{jboss_filename}#{ext}
  EOH
  not_if "test -d #{jboss_home}"
end


# set perms on directory
#directory jboss_home do
#  group jboss_user
#  owner jboss_user
#  mode "0755"
#end

# template init file
template "/etc/init.d/jboss" do
  if platform? ["centos", "redhat"] 
    source "init_el.erb"
  else
    if node['jboss']['version'][0] == "5"
      source "init_deb5.erb"
    else
      source "init_deb.erb"
    end
  end
  mode "0755"
  owner "root"
  group "root"
end

# template jboss-log4j.xml

# start service
log "Starting JBOSS Service"
service "jboss" do
  action [ :enable, :start ]
end

# add sudoers
template "/etc/sudoers.d/jboss" do
  source "jboss_sudoers"
  mode 0440
  owner "root"
  group "root"
end
