# == Schema Information
#
# Table name: export_procedures
#
#  id             :bigint           not null, primary key
#  client_key     :string
#  format         :string
#  target         :string
#  time_span_type :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  procedure_id   :bigint
#
class ExportProcedure < ApplicationRecord
  # après enregistrement de l'objet la méthode est appelée
  after_commit :compute_async

  def compute_async
    ExportProcedureJob.perform_later(self)
  end

  def compute
    procedure = Procedure.active(self.procedure_id)
    service = CustomProcedureExportService.new(procedure, dossiers_filtered(procedure))
    service.export(format, self.target, self.client_key)
  end

  def dossiers_filtered(procedure)
    if self.time_span_type == "all" # tous les dossiers
      Dossier.where(groupe_instructeurs: procedure.groupe_instructeurs)
    else # x derniers jours
      dateUpdatedSince = (Date.today - self.time_span_type.to_i).to_date
      Dossier.where(groupe_instructeurs: procedure.groupe_instructeurs).where("last_champ_updated_at >= ?", dateUpdatedSince)
    end
  end
end
