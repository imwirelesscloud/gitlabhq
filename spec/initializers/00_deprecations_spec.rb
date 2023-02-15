# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '00_deprecations', feature_category: :shared do
  def setup_other_deprecations
    Warning.process(__FILE__) { :default }
  end

  def load_initializer
    load Rails.root.join('config/initializers/00_deprecations.rb')
  end

  let(:rails_env) { nil }
  let(:gitlab_log_deprecations) { nil }

  before do
    stub_rails_env(rails_env) if rails_env
    stub_env('GITLAB_LOG_DEPRECATIONS', gitlab_log_deprecations)

    setup_other_deprecations

    ActiveSupport::Deprecation.disallowed_warnings = nil
    ActiveSupport::Notifications.unsubscribe('deprecation.rails')

    load_initializer
  end

  around do |example|
    Warning.clear(&example)
  end

  shared_examples 'logs to Gitlab::DeprecationJsonLogger' do |message, source|
    it 'logs them to Gitlab::DeprecationJsonLogger' do
      expect(Gitlab::DeprecationJsonLogger).to receive(:info).with(
        message: match(/^#{message}/),
        source: source
      )

      subject
    end
  end

  shared_examples 'does not log to Gitlab::DeprecationJsonLogger' do
    it 'does not log them to Gitlab::DeprecationJsonLogger' do
      expect(Gitlab::DeprecationJsonLogger).not_to receive(:info)

      subject
    end
  end

  shared_examples 'logs to stderr' do |message|
    it 'logs them to stderr' do
      expect { subject }.to output(match(/^#{message}/)).to_stderr
    end
  end

  shared_examples 'does not log to stderr' do
    it 'does not log them to stderr' do
      expect { subject }.not_to output.to_stderr
    end
  end

  describe 'Ruby deprecations' do
    context 'when catching deprecations through Kernel#warn' do
      subject { warn('ABC gem is deprecated and will be removed') }

      include_examples 'logs to Gitlab::DeprecationJsonLogger', 'ABC gem is deprecated and will be removed', 'ruby'
      include_examples 'logs to stderr', 'ABC gem is deprecated and will be removed'

      context 'when in production environment' do
        let(:rails_env) { 'production' }

        include_examples 'does not log to Gitlab::DeprecationJsonLogger'
        include_examples 'logs to stderr', 'ABC gem is deprecated and will be removed'

        context 'when GITLAB_LOG_DEPRECATIONS is set' do
          let(:gitlab_log_deprecations) { '1' }

          include_examples 'logs to Gitlab::DeprecationJsonLogger', 'ABC gem is deprecated and will be removed', 'ruby'
          include_examples 'logs to stderr', 'ABC gem is deprecated and will be removed'
        end
      end
    end

    context 'when other messages from Kernel#warn' do
      subject { warn('Sure is hot today') }

      include_examples 'does not log to Gitlab::DeprecationJsonLogger'
      include_examples 'logs to stderr', 'Sure is hot today'
    end
  end

  describe 'Rails deprecations' do
    context 'when catching deprecation warnings' do
      subject { ActiveSupport::Deprecation.warn('ABC will be removed') }

      include_examples 'logs to Gitlab::DeprecationJsonLogger', 'DEPRECATION WARNING: ABC will be removed', 'rails'
      include_examples 'logs to stderr', 'DEPRECATION WARNING: ABC will be removed'

      context 'when in production environment' do
        let(:rails_env) { 'production' }

        include_examples 'does not log to Gitlab::DeprecationJsonLogger'
        include_examples 'does not log to stderr'

        context 'when GITLAB_LOG_DEPRECATIONS is set' do
          let(:gitlab_log_deprecations) { '1' }

          include_examples 'logs to Gitlab::DeprecationJsonLogger', 'DEPRECATION WARNING: ABC will be removed', 'rails'
          include_examples 'does not log to stderr'
        end
      end
    end

    context 'when catching disallowed warnings' do
      before do
        ActiveSupport::Deprecation.disallowed_warnings << /disallowed warning 1/
      end

      subject { ActiveSupport::Deprecation.warn('This is disallowed warning 1.') }

      it 'raises ActiveSupport::DeprecationException' do
        expect { subject }.to raise_error(ActiveSupport::DeprecationException)
      end

      context 'when in production environment' do
        let(:rails_env) { 'production' }

        it 'does not raise ActiveSupport::DeprecationException' do
          expect { subject }.not_to raise_error
        end

        context 'when GITLAB_LOG_DEPRECATIONS is set' do
          let(:gitlab_log_deprecations) { '1' }

          it 'does not raise ActiveSupport::DeprecationException' do
            expect { subject }.not_to raise_error
          end
        end
      end
    end

    describe 'configuring ActiveSupport::Deprecation.disallowed_warnings' do
      it 'sets disallowed warnings' do
        expect(ActiveSupport::Deprecation.disallowed_warnings).not_to be_empty
      end

      context 'when in production environment' do
        let(:rails_env) { 'production' }

        it 'does not set disallowed warnings' do
          expect(ActiveSupport::Deprecation.disallowed_warnings).to be_empty
        end

        context 'when GITLAB_LOG_DEPRECATIONS is set' do
          let(:gitlab_log_deprecations) { '1' }

          it 'does not set disallowed warnings' do
            expect(ActiveSupport::Deprecation.disallowed_warnings).to be_empty
          end
        end
      end
    end
  end
end
