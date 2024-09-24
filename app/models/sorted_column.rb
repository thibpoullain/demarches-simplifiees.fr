# frozen_string_literal: true

class SortedColumn
  attr_reader :column

  def initialize(column:, order:)
    @column = column
    @order = order
  end

  def ascending? = @order == 'asc'

  def opposite_order = ascending? ? 'desc' : 'asc'

  def ==(other)
    other&.column == column && other.order == order
  end
end
