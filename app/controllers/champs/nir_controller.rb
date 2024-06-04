class Champs::NirController < ApplicationController
  before_action :authenticate_logged_user!

  def show
    @champ = policy_scope(Champ).find(params[:champ_id])
    @champ.value = read_param_value(@champ.input_name, 'value')
    @errors = @champ.errors.full_messages.join(', ') unless @champ.valid?
  end
end
