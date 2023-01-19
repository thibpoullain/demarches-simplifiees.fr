class CustomProcedureExportService < ProcedureExportService
  def export(format, target, client)
    case target
    when 's3'
      exportToS3(format)
    when 'sftp'
      exportViaSFTP(format, client)
    end
  end

  protected

  def exportToS3(format)
    ActiveStorage::Blob.create_and_upload!(
      io: get_io(format),
      filename: get_filename(format),
      content_type: get_content_type(format),
      service_name: 's3'
    )
  end

  def exportViaSFTP(format, client)
    demat_custom_export_sftp_user = ENV["DEMAT_CUSTOM_EXPORT_SFTP_" + client.upcase + "_URL"].match '^[^\@]*'
    demat_custom_export_sftp_host = ENV["DEMAT_CUSTOM_EXPORT_SFTP_" + client.upcase + "_URL"].match '(?<=@)(.*?)(?=:)'
    demat_custom_export_sftp_port = ENV["DEMAT_CUSTOM_EXPORT_SFTP_" + client.upcase + "_URL"].match '(?<=:)(.*?)(?=/)'
    demat_custom_export_sftp_folder = ENV["DEMAT_CUSTOM_EXPORT_SFTP_" + client.upcase + "_URL"].match '(?=\/)(.*)'
    # options possibles : https://www.rubydoc.info/github/net-ssh/net-ssh/Net%2FSSH.start
    Net::SFTP.start(demat_custom_export_sftp_host[0],
                    demat_custom_export_sftp_user[0],
                    port: demat_custom_export_sftp_port[0],
                    passphrase: ENV["DEMAT_CUSTOM_EXPORT_SFTP_" + client.upcase + "_KEY_PASSPHRASE"],
                    key_data: [ENV["DEMAT_CUSTOM_EXPORT_SFTP_" + client.upcase + "_KEY_DATA"]]) do |sftp|
      sftp.upload!(get_io(format), demat_custom_export_sftp_folder[0] + get_filename(format))
      # Création d'un fichier (vide) d'acquittement pour signifier la fin du transfert
      sftp.upload!(StringIO.new(), demat_custom_export_sftp_folder[0] + "acquittement.txt")
    end
  end

  def get_io(format)
    case format
    when "csv"
      return to_csv_io
    when "xlsx"
      return to_xlsx_io
    when "ods"
      return to_ods_io
    end
  end

  def get_filename(format)
    filename(format)
  end

  def get_content_type(format)
    content_type(format)
  end

  def to_csv_io
    StringIO.new(SpreadsheetArchitect.to_csv(options_for(:dossiers, :csv)))
  end

  def to_xlsx_io
    # We recursively build multi page spreadsheet
    @tables.reduce(nil) do |package, table|
      SpreadsheetArchitect.to_axlsx_package(options_for(table, :xlsx), package)
    end.to_stream
  end

  def to_ods_io
    # We recursively build multi page spreadsheet
    StringIO.new(@tables.reduce(nil) do |spreadsheet, table|
      SpreadsheetArchitect.to_rodf_spreadsheet(options_for(table, :ods), spreadsheet)
    end.bytes)
  end
end
