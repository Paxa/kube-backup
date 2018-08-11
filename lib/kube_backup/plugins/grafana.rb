module KubeBackup; end
module KubeBackup::Plugins

  class Grafana
    def initialize(writter)
      @grafana_url = ENV['GRAFANA_URL']
      @grafana_token = ENV['GRAFANA_TOKEN']
      @writter = writter
    end

    def run
      if !@grafana_url || @grafana_url == ''
        KubeBackup.logger.info "Skip Grafana plugin"
        return
      end

      backup_dashboards
      backup_data_sources
      backup_frontend_settings
      backup_org
      backup_org_users
    end

    def backup_dashboards
      dashboards = get_json('/api/search')
      #puts JSON.pretty_generate(dashboards)

      dashboards.each do |dashboard|
        if dashboard['type'] == "dash-db" || dashboard['type'] == "dash-folder"
          dash_name = dashboard['uri'].sub(%r{^db/}, '')

          KubeBackup.logger.info "Saving dashboard #{dashboard['folderTitle']}/#{dash_name}"

          dashboard_json = get_json("/api/dashboards/#{dashboard['uri']}")

          file_path = [
            "_grafana_/dashboards",
            dashboard['folderTitle'],
            dash_name
          ].compact.join('/')
          @writter.write_raw("#{file_path}.json", JSON.pretty_generate(dashboard_json))
        else
          raise "unknown type '#{dashboard['type']}'"
        end
      end
    end


    def backup_data_sources
      datasources = get_json('/api/datasources/')
      #puts JSON.pretty_generate(datasources)

      datasources.each do |datasource|
        KubeBackup.logger.info "Saving datasource #{datasource['name']}"
        @writter.write_raw("_grafana_/datasources/#{datasource['name']}.json", JSON.pretty_generate(datasource))
      end
    end

    def backup_frontend_settings
      settings = get_json('/api/frontend/settings')
      #puts JSON.pretty_generate(settings)

      KubeBackup.logger.info "Saving frontend_settings"
      @writter.write_raw("_grafana_/frontend_settings.json", JSON.pretty_generate(settings))
    end

    def backup_org
      org = get_json('/api/org')
      #puts JSON.pretty_generate(users)

      KubeBackup.logger.info "Saving organization"
      @writter.write_raw("_grafana_/org.json", JSON.pretty_generate(org))
    end

    def backup_org_users
      users = get_json('/api/org/users')
      #puts JSON.pretty_generate(users)

      users.each do |user|
        KubeBackup.logger.info "Saving user #{user['login']}"
        user.delete('lastSeenAtAge')
        user.delete('lastSeenAt')
        @writter.write_raw("_grafana_/users/#{user['login']}.json", JSON.pretty_generate(user))
      end
    end

    def get_json(path)
      require 'json'
      require 'excon'

      url = @grafana_url + path
      KubeBackup.logger.debug "GET #{url}"

      response = Excon.get(@grafana_url + path, {
        headers: {
          'Authorization' => "Bearer #{@grafana_token}"
        }
      })

      JSON.parse(response.body)
    end
  end

end
