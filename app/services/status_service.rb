require 'json'

class StatusService

  # Différents noms des composants testés, utilisés pour l'attribut JSON
  ACTIVE_RECORD = "active_record"
  ACTIVE_STORAGE = "active_storage"
  MAINTENANCE_FILE = "maintenance_file"
  API_ENTREPRISE = "api_entreprise"

  # Différents type de composants
  STANDARD_COMPONENT_VALUE = "standard"
  CUSTOM_COMPONENT_VALUE = "custom"

  # Différents statuts remontés pour l'état de vie d'un composant
  STATUS_UP_VALUE = "up"
  STATUS_DOWN_VALUE = "down"

  # Différentes clés/attributs de la réponse JSON
  TYPE_JSON_ATTR = "type"
  STATUS_JSON_ATTR = "status"
  MESSAGE_JSON_ATTR = "message"
  EXCEPTION_JSON_ATTR = "exception"
  EXCEPTION_MESSAGE_JSON_ATTR = "message"
  EXCEPTION_TRACE_JSON_ATTR = "trace"

  # ActiveRecord est un composant standard de Rails
  # Pour le tester nous demandons à l'API si nous sommes connecté
  def test_active_record(json)

    active_record = {}
    active_record[TYPE_JSON_ATTR] = STANDARD_COMPONENT_VALUE

    begin
      if ActiveRecord::Base.connected?
        active_record[STATUS_JSON_ATTR] = STATUS_UP_VALUE
        active_record[MESSAGE_JSON_ATTR] = "La connexion via ActiveRecord est opérationnelle"
        http_code = :ok
      else
        active_record[STATUS_JSON_ATTR] = STATUS_DOWN_VALUE
        active_record[MESSAGE_JSON_ATTR] = "La connexion via ActiveRecord n'est pas opérationnelle"
        http_code = :internal_server_error
      end
    rescue StandardError => e
      active_record[STATUS_JSON_ATTR] = STATUS_DOWN_VALUE
      active_record[MESSAGE_JSON_ATTR] = "Une erreur s'est produite à la tentative de connexion via ActiveRecord"
      exception = {}
      exception[EXCEPTION_MESSAGE_JSON_ATTR] = e.message
      exception[EXCEPTION_TRACE_JSON_ATTR] = e.backtrace
      active_record[EXCEPTION_JSON_ATTR] = exception
      http_code = :internal_server_error
    end
    json[ACTIVE_RECORD] = active_record
    http_code
  end

  # L'API entreprise est un composant standard de DS a activé dans les fichiers de configuration
  # Son test consiste a consommé un web service pour connaitre les privilèges associés à notre token
  def test_api_entreprise(json)
    api_entreprise = {}
    api_entreprise[TYPE_JSON_ATTR] = STANDARD_COMPONENT_VALUE
    begin
      api_entreprise_token = Rails.application.secrets.api_entreprise[:key]
      if api_entreprise_token == nil
        api_entreprise_token[STATUS_JSON_ATTR] = STATUS_DOWN_VALUE
        api_entreprise_token[MESSAGE_JSON_ATTR] = "La clé API Entreprise n'est pas définie, le service n'est pas opérationnel"
        http_code = :internal_server_error
      elsif APIEntreprise::API.privileges(api_entreprise_token).values[0][2] == ("entreprises")
        api_entreprise[STATUS_JSON_ATTR] = STATUS_UP_VALUE
        api_entreprise[MESSAGE_JSON_ATTR] = "Le service API Entreprise est opérationnel"
        http_code = :internal_server_error
      else
        api_entreprise[STATUS_JSON_ATTR] = STATUS_DOWN_VALUE
        api_entreprise[MESSAGE_JSON_ATTR] = "Le service API Entreprise n'est pas opérationnel"
        http_code = :ok
      end
    rescue
      exception = {}
      active_storage[STATUS_JSON_ATTR] = STATUS_DOWN_VALUE
      active_storage[MESSAGE_JSON_ATTR] = "Une erreur s'est produite à la tentative d'appel à l'API Entreprise"
      exception[EXCEPTION_MESSAGE_JSON_ATTR] = e.message
      exception[EXCEPTION_TRACE_JSON_ATTR] = e.backtrace
      active_storage[EXCEPTION_JSON_ATTR] = exception
      http_code = :internal_server_error
    end

    json[API_ENTREPRISE] = api_entreprise
    http_code

  end

  # ActiveStorage est un composant standard de Rails
  # Pour le tester nous allons créer et uploadé un fichier
  # pour ensuite le retrouver par son ID
  # sur l'instance retrouvée, nous utilisons l'ID pour supprimer le fichier
  def test_active_storage(json)

    active_storage = {}
    active_storage[TYPE_JSON_ATTR] = STANDARD_COMPONENT_VALUE

    begin
      # ecriture
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("toto"), filename: "toto.txt", content_type: "text/plain")
      # get by id
      blob2 = ActiveStorage::Blob.find blob.id
      # delete by id
      result = ActiveStorage::Blob.delete(blob2)
      if result == 1
        active_storage[STATUS_JSON_ATTR] = STATUS_UP_VALUE
        active_storage[MESSAGE_JSON_ATTR] = "La connexion via ActiveStorage est opérationnelle"
        http_code = :ok
      else
        active_storage[STATUS_JSON_ATTR] = STATUS_DOWN_VALUE
        active_storage[MESSAGE_JSON_ATTR] = "La connexion via ActiveStorage n'est pas opérationnelle"
        http_code = :internal_server_error
      end
    rescue StandardError => e
      exception = {}
      active_storage[STATUS_JSON_ATTR] = STATUS_DOWN_VALUE
      active_storage[MESSAGE_JSON_ATTR] = "Une erreur s'est produite à la tentative de connexion via ActiveStorage"
      exception[EXCEPTION_MESSAGE_JSON_ATTR] = e.message
      exception[EXCEPTION_TRACE_JSON_ATTR] = e.backtrace
      active_storage[EXCEPTION_JSON_ATTR] = exception
      http_code = :internal_server_error
    end
    json[ACTIVE_STORAGE] = active_storage
    http_code
  end

  # Le fichier de maintenance est un processus custom DINUM
  # peut etre utilisé pour un workaround HAProxy
  def test_maintenance_file(json)

    maintenance_file = {}
    maintenance_file[TYPE_JSON_ATTR] = CUSTOM_COMPONENT_VALUE

    begin
      if File.file?(Rails.root.join("maintenance"))
        maintenance_file[STATUS_JSON_ATTR] = STATUS_DOWN_VALUE
        maintenance_file[MESSAGE_JSON_ATTR] = "Le fichier de maintenance est pas présent sur le système de fichier"
        http_code = :internal_server_error
      else
        maintenance_file[STATUS_JSON_ATTR] = STATUS_UP_VALUE
        maintenance_file[MESSAGE_JSON_ATTR] = "Le fichier de maintenance n'est pas présent sur le système de fichier"
        http_code = :ok
      end
    rescue StandardError => e
      exception = {}
      maintenance_file[STATUS_JSON_ATTR] = STATUS_DOWN_VALUE
      maintenance_file[MESSAGE_JSON_ATTR] = "Une erreur s'est produite à l'exécution du test sur le fichier de maintenance "
      exception[EXCEPTION_MESSAGE_JSON_ATTR] = e.message
      exception[EXCEPTION_TRACE_JSON_ATTR] = e.backtrace
      maintenance_file[EXCEPTION_JSON_ATTR] = exception
      http_code = :internal_server_error
    end
    json[MAINTENANCE_FILE] = maintenance_file
    http_code
  end
end
