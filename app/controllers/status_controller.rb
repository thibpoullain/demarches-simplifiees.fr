require 'json'
require 'status_service'

class StatusController < ApplicationController

  def index

    Rails.logger.silence do

      tests = {}
      status_code = :ok

      status_service = StatusService::new

      # test sur la connection à la base de données
      if status_service::test_active_record(tests) != :ok
        status_code = :internal_server_error
      end

      # test sur la lecture / ecriture via active storage
      if status_service::test_active_storage(tests) != :ok
        status_code = :internal_server_error
      end

      # test sur la présence du fichier "maintenance" à la racine
      if status_service::test_maintenance_file(tests) != :ok
        status_code = :internal_server_error
      end

      # test sur la disponibilité de l'API entreprise
      if status_service::test_api_entreprise(tests) != :ok
        status_code = :internal_server_error
      end

      # test sur l'envoi de 2 mails
      if status_service::test_email(tests) != :ok
        status_code = :internal_server_error
      end

      render json: tests, status: status_code
    end
  end
end
