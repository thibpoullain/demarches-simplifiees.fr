class APIFiness::API
  class ResourceNotFound < StandardError
  end

  def self.get_finess(id)
    call([API_OPENDATASOFT_URL, 'search'].join('/'), 't_finess', { 'finess': id })
  end

  private

  def self.call(url, dataset, params)
    response = Typhoeus.get(url, params: { rows: 1, dataset: dataset }.merge(params))

    if response.success?
      response.body
    else
      message = response.code == 0 ? response.return_message : response.code.to_s
      Rails.logger.error "[APIFiness] Error on #{url}: #{message}"
      raise ResourceNotFound
    end
  end
end
