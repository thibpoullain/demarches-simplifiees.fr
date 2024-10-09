# # To use : rails runner bin/calcultate_stats.rb

# TYPES = %w[Champs::FinessChamp Champs::NirChamp Champs::RppsanteChamp].freeze

# def analyze_champs
#   Champ.where(type: TYPES).includes(dossier: :procedure).group_by(&:type).transform_values do |champs|
#     {
#       champs_count: champs.size,
#       dossiers: champs.map(&:dossier).uniq.map { |d| { id: d.id, name: d.procedure&.libelle } }
#     }
#   end
# end

# def display_results(results)
#   results.each do |type, data|
#     puts "Champ #{type} : #{data[:champs_count]} champs sont utilisés dans #{data[:dossiers].count} dossier#{'s' if data[:dossiers].count > 1}, voici les ids et noms des dossiers :"
#     # data[:dossiers].each { |dossier| puts "- id: #{dossier[:id]}, nom: #{dossier[:name]}" }
#     puts "\n"
#   end
# end

# results = analyze_champs
# display_results(results)


TYPES = %w[Champs::FinessChamp Champs::NirChamp Champs::RppsanteChamp].freeze

def analyze_champs
  results = {}
  TYPES.each do |type|

    unique_dossiers = Dossier.joins(:champs)
                            .where(champs: { type: type })
                            .select('dossiers.id')
                            .distinct

    dossier_count = unique_dossiers.uniq.count

    results[type] = dossier_count
  end
  results
end

def display_results(results)
  results.each do |type, data|
    puts "Champ #{type} : #{data} dossiers utilisent ce champ"
    puts "\n"
  end
end

results = analyze_champs
display_results(results)
