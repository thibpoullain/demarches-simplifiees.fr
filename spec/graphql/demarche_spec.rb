RSpec.describe Types::DemarcheType, type: :graphql do
  let(:query) { '' }
  let(:context) { { internal_use: true } }
  let(:variables) { {} }

  subject { API::V2::Schema.execute(query, variables: variables, context: context) }

  let(:data) { subject['data'].deep_symbolize_keys }
  let(:errors) { subject['errors'].deep_symbolize_keys }

  describe 'context should correctly preserve demarche authorization state' do
    let(:query) { DEMARCHE_QUERY }
    let(:admin) { create(:administrateur) }
    let(:procedure) { create(:procedure, administrateurs: [admin]) }

    let(:other_admin_procedure) { create(:procedure) }
    let(:context) { { administrateur_id: admin.id } }
    let(:variables) { { number: procedure.id } }

    it do
      result = API::V2::Schema.execute(query, variables: variables, context: context)
      graphql_context = result.context

      expect(graphql_context.authorized_demarche?(procedure)).to be_truthy
      expect(graphql_context.authorized_demarche?(other_admin_procedure)).to be_falsey
    end
  end

  DEMARCHE_QUERY = <<-GRAPHQL
  query($number: Int!) {
    demarche(number: $number) {
      number
    }
  }
  GRAPHQL

  DEMARCHE_WITH_CHAMP_DESCRIPTORS_QUERY = <<-GRAPHQL
  query($number: Int!) {
    demarche(number: $number) {
      number
      champDescriptors {
        id
        label
      }
      draftRevision {
        champDescriptors {
          id
          label
        }
      }
    }
  }
  GRAPHQL
end
