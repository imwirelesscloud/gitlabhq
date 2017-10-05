require 'google/apis/container_v1'

module GoogleApi
  module CloudPlatform
    class Client < GoogleApi::Auth
      DEFAULT_MACHINE_TYPE = 'n1-standard-1'.freeze
      SCOPE = 'https://www.googleapis.com/auth/cloud-platform'.freeze

      class << self
        def session_key_for_token
          :cloud_platform_access_token
        end

        def session_key_for_expires_at
          :cloud_platform_expires_at
        end
      end

      def scope
        SCOPE
      end

      def validate_token(expires_at)
        return false unless access_token
        return false unless expires_at

        # Making sure that the token will have been still alive during the cluster creation.
        unless DateTime.strptime(expires_at, '%s').to_time > Time.now + 10.minutes
          return false
        end

        true
      end

      def projects_zones_clusters_get(project_id, zone, cluster_id)
        service = Google::Apis::ContainerV1::ContainerService.new
        service.authorization = access_token

        service.get_zone_cluster(project_id, zone, cluster_id)
      end

      def projects_zones_clusters_create(project_id, zone, cluster_name, cluster_size, machine_type:)
        service = Google::Apis::ContainerV1::ContainerService.new
        service.authorization = access_token

        request_body = Google::Apis::ContainerV1::CreateClusterRequest.new(
          {
            "cluster": {
              "name": cluster_name,
              "initial_node_count": cluster_size,
              "node_config": {
                "machine_type": machine_type
              }
            }
          } )

        service.create_cluster(project_id, zone, request_body)
      end

      def projects_zones_operations(project_id, zone, operation_id)
        service = Google::Apis::ContainerV1::ContainerService.new
        service.authorization = access_token

        service.get_zone_operation(project_id, zone, operation_id)
      end

      def parse_operation_id(self_link)
        m = self_link.match(%r{projects/.*/zones/.*/operations/(.*)})
        m[1] if m
      end
    end
  end
end
