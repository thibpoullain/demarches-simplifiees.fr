
namespace :after_party do
  desc 'Deployment task: back_fill_procedure_defaut_groupe_instructeur_id'
  task back_fill_procedure_defaut_groupe_instructeur_id: :environment do
    puts "Running deploy task 'back_fill_procedure_defaut_groupe_instructeur_id'"

    # rubocop:disable DS/Unscoped
    progress = ProgressReport.new(Procedure.unscoped.where(defaut_groupe_instructeur_id: nil).count)

    Procedure.unscoped.where(defaut_groupe_instructeur_id: nil).find_each do |p|
      if p.defaut_groupe_instructeur.nil?
        # Default instructeur group is not defined for this procedure
        groups = GroupeInstructeur.where(procedure_id: p.id).order(:id)
        if groups.empty?
          # No group is assigned to this procedure - should normally not happen
          # Select first overall group as default group
          group_id = GroupeInstructeur.all.order(:id).first
        else
          # Select first created group for this procedure as default group
          group_id = groups.first.id
        end
        # Assign a group_id to Procedure.default_groupe_instructeur_id
        p.update_columns(defaut_groupe_instructeur_id: group_id) if group_id
      else
        # Use known defaut groupe instructeur for this procedure
        p.update_columns(defaut_groupe_instructeur_id: p.defaut_groupe_instructeur.id)
      end
      progress.inc
    end
    # rubocop:enable DS/Unscoped

    progress.finish

    # Update task as completed. If you remove the line below, the task will
    # run with every deploy (or every time you call after_party:run).
    AfterParty::TaskRecord
      .create version: AfterParty::TaskRecorder.new(__FILE__).timestamp
  end
end
