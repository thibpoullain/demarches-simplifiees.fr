require 'securerandom'
require 'aws-sdk-s3'

# Configuration du client S3 pour Minio
s3_client = Aws::S3::Client.new(
  access_key_id: 'minioadmin',
  secret_access_key: 'minioadmin',
  endpoint: 'http://localhost:9000',
  force_path_style: true,
  region: 'us-east-1'
)

bucket_name = 'dematsocial'

# Vérifier si le bucket existe, sinon le créer
begin
  s3_client.head_bucket(bucket: bucket_name)
  puts "Bucket '#{bucket_name}' exists"
rescue Aws::S3::Errors::NotFound
  s3_client.create_bucket(bucket: bucket_name)
  puts "Bucket '#{bucket_name}' created"
rescue Aws::S3::Errors::ServiceError => e
  puts "Error accessing or creating bucket: #{e.message}"
  exit 1
end

# Vérifier que le service de stockage est correctement configuré
unless Rails.application.config.active_storage.service == :minio
  puts "Warning: Active Storage is not configured to use Minio. Please check your configuration."
  exit 1
end

# Lire les clés du fichier
file_path = 'last_150_objects.txt'
unless File.exist?(file_path)
  puts "Error: File '#{file_path}' not found."
  exit 1
end

keys = File.readlines(file_path).map(&:strip)

# Vérifier si les blobs existent déjà, les supprimer
existing_blobs = ActiveStorage::Blob.where(key: keys)
if existing_blobs.any?
  puts "Deleting #{existing_blobs.count} existing blobs..."
  existing_blobs.find_each do |blob|
    blob.purge
    puts "Deleted blob with key: #{blob.key}"
  end
end

# Créer des blobs pour chaque clé
keys.each_with_index do |key, index|
  # Créer un contenu aléatoire
  content = SecureRandom.hex(100) # 200 caractères aléatoires
  file = Tempfile.new('random_file')
  file.write(content)
  file.rewind
  begin
    # Créer le blob
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file,
      filename: "#{key}.txt",
      content_type: "text/plain",
      key: key
    )
    puts "Created blob with key: #{blob.key} (#{index + 1}/#{keys.count})"
  rescue ActiveRecord::RecordNotUnique
    puts "Error: Duplicate key '#{key}'. Skipping."
  rescue StandardError => e
    puts "Error creating blob with key '#{key}': #{e.message}"
  ensure
    file.close
    file.unlink
  end
end

puts "Finished processing #{keys.count} keys."
puts "Total blobs in database: #{ActiveStorage::Blob.count}"
puts "Total objects in Minio bucket: #{s3_client.list_objects(bucket: bucket_name).contents.count}"
