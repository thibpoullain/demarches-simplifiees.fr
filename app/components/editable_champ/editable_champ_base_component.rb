# frozen_string_literal: true

class EditableChamp::EditableChampBaseComponent < ApplicationComponent
  include Dsfr::InputErrorable

  attr_reader :attribute

  def initialize(form:, champ:, seen_at: nil, opts: {})
    @form, @champ, @seen_at, @opts = form, champ, seen_at, opts
    @attribute = :value
  end

  def dsfr_champ_container
    :div
  end

  def dsfr_input_classname
    nil
  end

  def describedby_id
    @champ.describedby_id
  end
end
