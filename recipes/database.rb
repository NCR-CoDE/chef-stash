settings = merge_stash_settings

database_connection = {
  :host => settings['database']['host'],
  :port => settings['database']['port']
}

case settings['database']['type']
when 'mysql'
  mysql2_chef_gem 'default' do
    client_version settings['database']['version'] if settings['database']['version']
    action :install
  end

  mysql_service 'default' do
    version settings['database']['version'] if settings['database']['version']
    bind_address settings['database']['host']
    # See: https://github.com/chef-cookbooks/mysql/pull/361
    port settings['database']['port'].to_s
    data_dir node['mysql']['data_dir'] 
    initial_root_password node['mysql']['server_root_password']
    action [:create, :start]
  end

  database_connection[:username] = 'root'
  database_connection[:password] = node['mysql']['server_root_password']

  mysql_database settings['database']['name'] do
    connection database_connection
    collation 'utf8_bin'
    encoding 'utf8'
    action :create
  end

  # See this MySQL bug: http://bugs.mysql.com/bug.php?id=31061
  mysql_database_user '' do
    connection database_connection
    host '127.0.0.1'
    action :drop
  end

  mysql_database_user settings['database']['user'] do
    connection database_connection
    host '%'
    password settings['database']['password']
    database_name settings['database']['name']
    action [:create, :grant]
  end
when 'postgresql'
  database_connection[:username] = 'postgres'
  database_connection[:password] = node['postgresql']['password']['postgres']

  bash "add_to_bashrc" do
    user "postgres"
    code <<-EOH
      export PGPASSWORD="#{database_connection[:password]}"
      /usr/pgsql-9.3/bin/createdb "#{settings['database']['name']}" -E 'utf8' -e -h 'localhost' -U "#{database_connection[:username]}" -p 5432
      echo "CREATE USER #{settings['database']['user']} WITH PASSWORD '\#{settings['database']['password']}'\;GRANT ALL PRIVILEGES ON DATABASE #{settings['database']['name']} to #{settings['database']['user']}"
    EOH
  end


end
