require 'rails_helper'

RSpec.describe Champs::NirChamp, type: :model do
  describe 'validations' do
    it 'validates the format of the nir' do
      dossier = create(:dossier)
      champ = Champs::NirChamp.new(value: '188065913203161', dossier:, type_de_champ: create(:type_de_champ, :nir))
      expect(champ).to be_valid

      champ.value = '12345678901234'
      expect(champ).not_to be_valid

      champ.value = '1234567890123456'
      expect(champ).not_to be_valid

      champ.value = '12345678901234A'
      expect(champ).not_to be_valid

      champ.value = '12345678901234B'
      expect(champ).not_to be_valid

      champ.value = '12345678901234AB'
      expect(champ).not_to be_valid
    end
  end

  it 'validate that the value can be nil' do
    champ = Champs::NirChamp.new(value: nil, dossier: create(:dossier), type_de_champ: create(:type_de_champ, :nir))
    expect(champ).to be_valid
  end

  describe 'callbacks' do
    let(:nir) { Champs::NirChamp.new(value: '188065913203161', dossier: create(:dossier), type_de_champ: create(:type_de_champ, :nir)) }

    it 'stores encrypted value in the database' do
      nir.save
      stored_value = Champs::NirChamp.where(id: nir.id).pick(:value)
      expect(stored_value).not_to eq '188065913203161'
    end

    it 'decrypts the value after finding from the database' do
      nir.save
      expect { Champs::NirChamp.find(nir.id).to eq('188065913203161') }
    end
  end
end
