# frozen_string_literal: true

class Instructeurs::ColumnTableHeaderComponent < ApplicationComponent
  def initialize(procedure_presentation:)
    @procedure = procedure_presentation.procedure
    @columns = procedure_presentation.displayed_fields_for_headers
    @sorted_column = procedure_presentation.sorted_column
  end

  private

  def update_sort_path(column)
    column_id = column.id
    order = opposite_order_for(column)

    update_sort_instructeur_procedure_path(@procedure, column_id:, order:)
  end

  def opposite_order_for(column)
    @sorted_column.column == column ? @sorted_column.opposite_order : 'asc'
  end

  def label_and_arrow(column)
    return column.label if @sorted_column.column != column

    @sorted_column.ascending? ? "#{column.label} ↑" : "#{column.label} ↓"
  end

  def aria_sort(column)
    return {} if @sorted_column.column != column

    @sorted_column.ascending? ? { "aria-sort": "ascending" } : { "aria-sort": "descending" }
  end
end
