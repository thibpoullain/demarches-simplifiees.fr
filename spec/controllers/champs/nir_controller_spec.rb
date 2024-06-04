describe Champs::NirController, type: :controller do
  let(:user) { create(:user) }
  let(:procedure) { create(:procedure, :published, :with_nir) }

  describe '#show' do
    let(:dossier) { create(:dossier, user: user, procedure: procedure) }
    let(:champ) { dossier.champs_public.first }

    let(:champs_public_attributes) do
      champ_attributes = []
      champ_attributes[champ.id] = { value: nir }
      champ_attributes
    end
    let(:params) do
      {
        champ_id: champ.id,
        dossier: {
          champs_public_attributes: champs_public_attributes
        }
      }
    end
    let(:nir) { '' }

    context 'when the user is signed in' do
      render_views

      before do
        sign_in user
      end

      context 'when the NIR is empty' do
        subject! { get :show, params: params, format: :turbo_stream }

        it 'clears any information or error message' do
          expect(response.body).to include(ActionView::RecordIdentifier.dom_id(champ, :nir_info))
        end
      end

      context "when the nir is invalid" do
        let(:nir) { '1234' }

        subject! { get :show, params: params, format: :turbo_stream }

        it 'displays the error message' do
          expect(response.body).to include(I18n.t('errors.messages.invalid_nir'))
        end
      end
    end

    context 'when user is not signed in' do
      subject! { get :show, params: { champ_id: champ.id }, format: :turbo_stream }

      it { expect(response).to redirect_to(new_user_session_path) }
    end
  end
end
