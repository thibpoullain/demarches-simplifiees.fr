# frozen_string_literal: true

describe Columns::JSONPathColumn do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :address }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first }
  let(:stable_id) { champ.stable_id }
  let(:column) { described_class.new(procedure_id: procedure.id, label: 'label', stable_id:, jsonpath:, displayable: true) }

  describe '#value' do
    let(:jsonpath) { '$.city_name' }

    subject { column.value(champ) }

    context 'when champ has value_json' do
      before { champ.update(value_json: { city_name: 'Grenoble' }) }

      it { is_expected.to eq('Grenoble') }
    end

    context 'when champ has no value_json' do
      it { is_expected.to be_nil }
    end
  end

  describe '#filtered_ids' do
    let(:jsonpath) { '$.city_name' }

    subject { column.filtered_ids(Dossier.all, ['reno', 'Lyon']) }

    context 'when champ has value_json' do
      before { champ.update(value_json: { city_name: 'Grenoble' }) }

      it { is_expected.to eq([dossier.id]) }
    end

    context 'when champ has no value_json' do
      it { is_expected.to eq([]) }
    end
  end

  describe '#initializer' do
    let(:jsonpath) { %{$.'city_name} }

    it { expect(column.jsonpath).to eq(%{$.''city_name}) }
  end
end
