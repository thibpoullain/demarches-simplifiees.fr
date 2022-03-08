require 'json'

class StatusService

  STANDARD_COMPONENT = "STANDARD"
  CUSTOM_COMPONENT = "CUSTOM"

  # ActiveRecord est un composant standard de Rails
  # Pour le tester nous demandons à l'API si nous sommes connecté
  def test_active_record(json)

    active_record = {}
    active_record["type"] = STANDARD_COMPONENT

    begin
      if ActiveRecord::Base.connected?
        active_record["status"] = "UP"
        active_record["message"] = "La connexion via ActiveRecord est opérationnelle"
        http_code = :ok
      else
        active_record["status"] = "DOWN"
        active_record["message"] = "La connexion via ActiveRecord n'est pas opérationnelle"
        http_code = :internal_server_error
      end
    rescue StandardError => e
      active_record["status"] = "DOWN"
      active_record["message"] = "Une erreur s'est produite à la tentative de connexion via ActiveRecord"
      exception = {}
      exception["message"] = e.message
      exception["trace"] = e.backtrace
      active_record["exception"] = exception
      http_code = :internal_server_error
    end
    json["active_record"] = active_record
    http_code
  end

  # ActiveStorage est un composant standard de Rails
  # Pour le tester nous allons créer et uploadé un fichier
  # pour ensuite le retrouver par son ID
  # sur l'instance retrouvée, nous utilisons l'ID pour supprimer le fichier
  def test_active_storage(json)

    active_storage = {}
    active_storage["type"] = STANDARD_COMPONENT

    begin
      # ecriture
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("toto"), filename: "toto.txt", content_type: "text/plain")
      # get by id
      blob2 = ActiveStorage::Blob.find blob.id
      # delete by id
      result = ActiveStorage::Blob.delete(blob2)
      if result==1
        active_storage["status"] = "UP"
        active_storage["message"] = "La connexion via ActiveStorage est opérationnelle"
        http_code = :ok
      else
        active_storage["status"] = "DOWN"
        active_storage["message"] = "La connexion via ActiveStorage n'est pas opérationnelle"
        http_code = :internal_server_error
      end
    rescue StandardError => e
      exception = {}
      active_storage["status"] = "DOWN"
      active_storage["message"] = "Une erreur s'est produite à la tentative de connexion via ActiveStorage"
      exception["message"] = e.message
      exception["trace"] = e.backtrace
      active_storage["exception"] = exception
      http_code = :internal_server_error
    end
    json["active_storage"] = active_storage
    http_code
  end

  # Le fichier de maintenance est un processus custom DINUM
  # peut etre utilisé pour un workaround HAProxy
  def test_maintenance_file(json)

    maintenance_file = {}
    maintenance_file["type"] = CUSTOM_COMPONENT

    begin
      if File.file?(Rails.root.join("maintenance"))
        maintenance_file["status"] = "DOWN"
        maintenance_file["message"] = "Le fichier de maintenance est pas présent sur le système de fichier"
        http_code = :internal_server_error
      else
        maintenance_file["status"] = "UP"
        maintenance_file["message"] = "Le fichier de maintenance n'est pas présent sur le système de fichier"
        http_code = :ok
      end
    rescue StandardError => e
      exception = {}
      maintenance_file["status"] = "DOWN"
      maintenance_file["message"] = "Une erreur s'est produite à l'exécution du test sur le fichier de maintenance "
      exception["message"] = e.message
      exception["trace"] = e.backtrace
      maintenance_file["exception"] = exception
      http_code = :internal_server_error
    end
    json["maintenance_file"] = maintenance_file
    http_code
  end

end
