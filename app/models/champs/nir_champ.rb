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

  NIR_REGEX = Regexp.new('\A
                (?<sexe>[123478])                                      #  1 pour les hommes, 2 pour les femmes, 3 ou 7 pour les personnes étrangères de sexe masculin en cours d\'immatriculation en France, 4 ou 8 pour les personnes étrangères de sexe féminin en cours d\'immatriculation en France
                (?<annee>[0-9]{2})                                     # année de naissance
                (?<mois>0[1-9]|1[0-2]|[2-3][0-9]|4[0-2]|[5-9][0-9])    # mois de naissance: de 01 (janvier) à 12 (décembre) ou entre 20 et 42 ou entre 50 et 99
                        (?<departement>[0][0-9]|2[AB]|[1-9][0-9])      # le département : de 01 à 95, ou 2A ou 2B pour la Corse après le 1er janvier 1976, ou 96 à 98 pour des naissances hors France métropolitaine et 99 pour des naissances à l\'étranger. 00 pour les personnes en cours d\'immatriculation. Attention, cas particuliers supplémentaire outre-mer traité plus loin, hors expreg
                        (?<numcommune>[0-9]{3})                        # numéro d\'ordre de la commune (attention car particuler pour hors métro  traité hors expression régulière)
                        (?<numacte>00[1-9]|0[1-9][0-9]|[1-9][0-9]{2})  # numéro d\'ordre d\'acte de naissance dans le mois et la commune ou pays
                        (?<clef>0[1-9]|[1-8][0-9]|9[0-7])?             # numéro de contrôle (facultatif)
                        \z', Regexp::EXTENDED)

  validates :value, format: { with: NIR_REGEX, message: I18n.t('errors.messages.invalid_nir') }, allow_blank: true

  # Avant enregistrement, chiffrement du nir
  before_save { |nir| nir.value = (nir.value != nil) ? FieldEncryptionService.new.encrypt(nir.value) : nir.value }

  # Déchiffrement également après enregistrement dans le cas où le nir continue d'être manipulé sans chargement depuis la base (ex : contexte de test)
  after_save { |nir| nir.value = (nir.value != nil) ? FieldEncryptionService.new.decrypt(nir.value) : nir.value }

  # Lors du chargement depuis la DB, déchiffrement du nir
  after_find { |nir| nir.value = (nir.value != nil) ? FieldEncryptionService.new.decrypt(nir.value) : nir.value }
end
