TYPES = %w[Champs::FinessChamp Champs::NirChamp Champs::RppsanteChamp].freeze

def analyze_champs
  results = {}

  TYPES.each do |type|
    dossier_counts = Dossier
      .joins(:champs, :procedure)
      .where(champs: { type: type })
      .group('procedures.libelle')
      .count

    results[type] = dossier_counts.transform_keys(&:to_s)
  end

  results
end

def display_results(results)
  results.each do |type, procedure_counts|
    puts "Type de champ: #{type}"
    procedure_counts.each do |procedure_name, count|
      puts "  #{count} dossier dans la procédure ---> #{procedure_name}"
    end
    puts "\n"
  end
end

results = analyze_champs
display_results(results)
