class ExportProcedureJob < ApplicationJob
  queue_as :export_procedures

  discard_on ActiveRecord::RecordNotFound

  def perform(exportProcedure)
    exportProcedure.compute
  end
end
