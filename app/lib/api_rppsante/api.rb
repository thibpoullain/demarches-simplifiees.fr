class APIRppsante::API
  class ResourceNotFound < StandardError
  end

  def self.get_rppsante(id)
    call([API_OPENDATASOFT_URL, 'search'].join('/'), 'ps_libreacces_personne_activite', { 'q': 'identification_nationale_pp:' + id + ' AND NOT #null(code_postal_coord_structure) ' })
  end

  private

  def self.call(url, dataset, params)
    response = Typhoeus.get(url, params: { rows: 1, dataset: dataset }.merge(params))

    if response.success?
      response.body
    else
      message = response.code == 0 ? response.return_message : response.code.to_s
      Rails.logger.error "[APIRppsante] Error on #{url}: #{message}"
      raise ResourceNotFound
    end
  end
end
