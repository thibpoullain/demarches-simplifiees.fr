Dir[File.join(Rails.root, "lib", "core_ext", "*.rb")].each do |core_ext_file|
  require core_ext_file
end
