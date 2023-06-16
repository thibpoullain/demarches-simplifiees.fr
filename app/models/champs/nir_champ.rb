# == Schema Information
#
# Table name: champs
#
#  id                             :integer          not null, primary key
#  data                           :jsonb
#  fetch_external_data_exceptions :string           is an Array
#  prefilled                      :boolean
#  private                        :boolean          default(FALSE), not null
#  rebased_at                     :datetime
#  type                           :string
#  value                          :string
#  value_json                     :jsonb
#  created_at                     :datetime
#  updated_at                     :datetime
#  dossier_id                     :integer
#  etablissement_id               :integer
#  external_id                    :string
#  parent_id                      :bigint
#  row_id                         :string
#  type_de_champ_id               :integer
#
class Champs::NirChamp < Champs::TextChamp
  # Pour les callback, https://api.rubyonrails.org/v7.0.3/classes/ActiveRecord/Callbacks.html

  # Avant enregistrement, chiffrement du nir
  before_save { |nir| nir.value = (nir.value != nil) ? FieldEncryptionService.new.encrypt(nir.value) : nir.value }

  # Déchiffrement également après enregistrement dans le cas où le nir continue d'être manipulé sans chargement depuis la base (ex : contexte de test)
  after_save { |nir| nir.value = (nir.value != nil) ? FieldEncryptionService.new.decrypt(nir.value) : nir.value }

  # Lors du chargement depuis la DB, déchiffrement du nir
  after_find { |nir| nir.value = (nir.value != nil) ? FieldEncryptionService.new.decrypt(nir.value) : nir.value }
end
