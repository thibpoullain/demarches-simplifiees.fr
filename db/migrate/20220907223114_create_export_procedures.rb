class CreateExportProcedures < ActiveRecord::Migration[6.1]
  def change
    create_table :export_procedures do |t|
      t.bigint :procedure_id
      t.string :client_key
      t.string :format
      t.string :target
      t.string :time_span_type

      t.timestamps
    end
  end
end
