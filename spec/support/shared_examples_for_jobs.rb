RSpec.shared_examples 'a job retrying transient errors' do |job_class = described_class|
  context 'when a transient network error is raised' do
    unless Object.const_defined?('ExconErrorJob')
      ExconErrorJob = Class.new(job_class) do
        def perform
          raise Excon::Error::InternalServerError, 'msg'
        end
      end
    end

    it 'makes 5 attempts before raising the exception up' do
      assert_performed_jobs 5 do
        ExconErrorJob.perform_later rescue Excon::Error::InternalServerError
      end
    end
  end

  context 'when another type of error is raised' do
    unless Object.const_defined?('StandardErrorJob')
      StandardErrorJob = Class.new(job_class) do
        def perform
          raise StandardError
        end
      end
    end

    it 'makes only 1 attempt before raising the exception up' do
      assert_performed_jobs 1 do
        StandardErrorJob.perform_later rescue StandardError
      end
    end
  end
end
