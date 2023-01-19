class API::V1::ExportController < APIController
  before_action :fetch_procedure_and_check_token

  @@default_format = "xlsx"
  @@default_time_span_type = "all"

  @@client_keys = (ENV["DEMAT_CUSTOM_EXPORT_SFTP_CLIENTS"] || '').split(',')
  @@formats = ["xlsx", "csv", "ods"] # formats autorisés
  @@targets = ["s3", "sftp"] # où va l'export

  def show
    @procedure_id = params[:procedure_id]
    @client_key = params[:id]
    @format = params[:file_format]
    @target = params[:target]
    @time_span_type = params[:time_span_type]
    @days = params[:days]

    if @client_key == nil
      return render json: { message: "Erreur P2" }, status: 400
    end

    if @target == nil
      return render json: { message: "Erreur P3" }, status: 400
    end

    unless @@client_keys.include?(@client_key)
      return render json: { message: "Erreur P4" }, status: 400
    end

    if @format != nil
      unless @@formats.include?(@format)
        return render json: { message: "Erreur P5" }, status: 400
      end
    else
      @format = @@default_format
    end

    @time_span_type = "all" # export de tous les dossiers
    if @days != nil
      @time_span_type = @days # export des dossiers sur x jours
    end

    unless @@targets.include?(@target)
      return render json: { message: "Erreur P6" }, status: 400
    end

    # test existence de la procédure => RecordNotFound
    Procedure.active(@procedure_id)

    ExportProcedure.create(procedure_id: @procedure_id, client_key: @client_key, format: @format, target: @target, time_span_type: @time_span_type)

    return render json: { message: "OK" }, status: 200

  rescue ActiveRecord::RecordNotFound
    return render json: { message: "Erreur R7" }, status: 404
  end

  private

  def fetch_procedure_and_check_token
    if params[:procedure_id] == nil
      return render json: { message: "Erreur P1" }, status: 400
    end

    @procedure = Procedure.for_api.find(params[:procedure_id])

    administrateur = find_administrateur_for_token(@procedure)
    if administrateur
      Current.administrateur = administrateur
    else
      render json: { message: "Erreur T8" }, status: :unauthorized
    end

  rescue ActiveRecord::RecordNotFound
    render json: { message: "Erreur R1" }, status: :not_found
  end
end
