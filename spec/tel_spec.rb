require File.expand_path '../../tel.rb', __FILE__
require File.expand_path '../spec_helper.rb', __FILE__
require 'qu/backend/immediate'

describe 'tel' do
  let(:account) { create(:account, handle: 'zach', api_key: 'musubi') }

  before(:each) do
    Mongoid.purge!
  end

  describe 'Interesting' do
    subject { Class.new { include Interesting }.new }

    let(:mock_sounds) { [] }

    let(:mock_mp3) do
      File.open(File.expand_path('../dkc.mp3', __FILE__), 'r') do |file|
        t = Tempfile.new ['', '.mp3']
        t.rewind
        t.write file.read
        t
      end
    end

    let(:mock_m4a) do
      File.open(File.expand_path('../mario.m4a', __FILE__), 'r') do |file|
        t = Tempfile.new ['', '.m4a']
        t.rewind
        t.write file.read
        t
      end
    end

    describe '#sound_duration' do
      it 'runs a command to determine the length of the provided audio file' do
        allow(Cocaine::CommandLine).to receive(:new).and_call_original

        result = subject.sound_duration(mock_mp3)

        expect(Cocaine::CommandLine).to have_received(:new).with('sox', ":in -n stat 2>&1 | grep 'Length (seconds)'")
        expect(result).to eq(8.616)
      end
    end

    describe '#convert_sound_format_to_mp3' do
      it 'converts a file to mp3' do
        allow(Cocaine::CommandLine).to receive(:new).and_call_original

        result = subject.convert_sound_format_to_mp3(mock_m4a)

        expect(Cocaine::CommandLine).to have_received(:new).with('ffmpeg', '-i :in -acodec libmp3lame -y -b:a 128k -ar 44100 :out')
        expect(result.size).to eq(375048)
        expect(result.path).to end_with('.mp3')
      end
    end

    describe '#process_sound' do
      it 'converts a non-mp3' do
        expect(subject).to receive(:convert_sound_format_to_mp3).with(mock_m4a).and_call_original

        subject.process_sound(mock_m4a, 'audio/m4a')
      end

      it 'does not convert an mp3' do
        expect(subject).not_to receive(:convert_sound)

        subject.process_sound(mock_mp3, 'audio/mp3')
      end

      it 'runs an m4a' do
        allow(Cocaine::CommandLine).to receive(:new).and_call_original

        result = subject.process_sound(mock_m4a, 'audio/m4a')

        expect(Cocaine::CommandLine).to have_received(:new).with('sox', ':in -c 1 -C 128 :out norm riaa vad reverse vad reverse')
        expect(result.first.size).to eq(343335)
        expect(result.last).to eq(22.0212)
      end

      it 'runs an mp3' do
        result = subject.process_sound(mock_mp3, 'audio/mp3')

        expect(result.first.size).to eq(124445)
        expect(result.last).to eq(8.016)
      end
    end

    describe '#combine_sounds' do
      let(:mock_sounds) do
        %w(dkc.mp3 starfox.mp3 dkc.mp3).map do |filename|
          File.open(File.expand_path("../#{filename}", __FILE__), 'r') do |file|
            t = Tempfile.new ['', '.mp3']
            t.rewind
            t.write file.read
            t
          end
        end
      end

      before do
        allow(subject).to receive(:fetch_sounds).and_return(mock_sounds)
      end

      it 'runs' do
        arg = "#{mock_sounds.map(&:path).join(' ')} :out splice"
        arg2 = ":in -n stat 2>&1 | grep 'Length (seconds)'"

        allow(Cocaine::CommandLine).to receive(:new).and_call_original

        response = subject.combine_sounds []

        expect(Cocaine::CommandLine).to have_received(:new).with('sox', arg)
        expect(Cocaine::CommandLine).to have_received(:new).with('sox', arg2)

        expect(response.first.size).to eq(286950)
        expect(response.last).to eq(37.104)
      end
    end

    describe '#upload_to_s3' do

    end
  end

  describe 'Chain', type: :model do
    let(:chain) { Chain.create description: 'some crazy dude' }

    describe '#next_position' do
      context 'when chain has no sounds' do
        it 'returns 1' do
          expect(chain.next_position).to eq(1)
        end
      end

      context 'when chain has some sounds' do
        before do
          chain.add_sound!(url: 'blep', duration: 1)
          chain.add_sound!(url: 'blop', duration: 4)
        end

        it 'returns highest sound position + 1' do
          expect(chain.next_position).to eq(3)
        end
      end
    end

    describe '#add_sound!' do
      context 'when no sounds exist yet' do
        it 'adds a sound at position 1' do
          sound = chain.add_sound! url: 'blep', duration: 7.77

          expect(sound.position).to eq(1)
          expect(sound.visible).to eq(true)
          expect(sound.included).to eq(true)
          expect(sound.url).to eq('blep')
          expect(sound.duration).to eq(7.77)
        end
      end

      context 'when some sounds exist' do
        let!(:sound1) { create(:sound, url: 'boop', duration: 3, chain: chain, included: true, visible: true, position: 1) }
        let!(:sound2) { create(:sound, url: 'beep', duration: 3, chain: chain, included: true, visible: true, position: 2) }

        it 'add a sound at the end' do
          sound = chain.add_sound! url: 'blep', duration: 7.77

          expect(sound.position).to eq(3)
          expect(sound.visible).to eq(true)
          expect(sound.included).to eq(true)
          expect(sound.url).to eq('blep')
          expect(sound.duration).to eq(7.77)
        end
      end

      context 'when some sounds exist and a before attr is provided' do
        let!(:sound1) { create(:sound, url: 'boop', duration: 3, chain: chain, included: true, visible: true, position: 1) }
        let!(:sound2) { create(:sound, url: 'beep', duration: 3, chain: chain, included: true, visible: true, position: 2) }
        let!(:sound3) { create(:sound, url: 'baap', duration: 3, chain: chain, included: true, visible: true, position: 3) }

        it 'adds the sound at a certain point when given a sound' do
          sound = chain.add_sound! before: sound2, url: 'blep', duration: 7.77

          expect(sound.position).to eq(2)
          expect(sound.visible).to eq(true)
          expect(sound.included).to eq(true)
          expect(sound.url).to eq('blep')
          expect(sound.duration).to eq(7.77)
          expect(sound2.reload.position).to eq(3)
          expect(sound3.reload.position).to eq(4)
        end

        it 'adds the sound at a certain point when given an id' do
          sound = chain.add_sound! before: sound2.id, url: 'blep', duration: 7.77

          expect(sound.position).to eq(2)
          expect(sound.visible).to eq(true)
          expect(sound.included).to eq(true)
          expect(sound.url).to eq('blep')
          expect(sound.duration).to eq(7.77)
          expect(sound2.reload.position).to eq(3)
          expect(sound3.reload.position).to eq(4)
        end

        context 'when sound specified in before attr is not real' do
          it 'returns nil' do
            sound = chain.add_sound! before: 'something', url: 'blep', duration: 7.77

            expect(sound).to eq(nil)
            expect(sound2.reload.position).to eq(2)
            expect(sound3.reload.position).to eq(3)
          end
        end
      end
    end
  end

  describe 'api' do
    # describe 'POST /accounts' do
    #   context 'when a good code is provided' do
    #     let!(:code1) { create(:z_code, code: 'zbx123') }
    #
    #     it 'responds with an api key' do
    #       xhr_post '/accounts', { handle: 'teppo', code: 'zbx123' }
    #       expect(Account.count).to eq 1
    #       expect(response_json).to eq 'account' => { 'id' => Account.first.id.to_s, 'handle' => 'teppo' }
    #     end
    #   end
    #
    #   context 'when an already-claimed handle is requested' do
    #     let!(:account) { create :account, handle: 'teppo', api_key: 'blep' }
    #     let!(:code1) { create(:z_code, code: 'zbx123') }
    #
    #     it 'fails' do
    #       xhr_post '/accounts', { handle: 'teppo', code: 'zbx123' }
    #
    #       expect(last_response.status).to eq(400)
    #       expect(response_json).to eq('error' => 'sorry, something went wrong')
    #     end
    #   end
    #
    #   context 'when user does not have a valid zcode' do
    #     it 'fails' do
    #       xhr_post '/accounts', { handle: 'teppo', code: 'zbx123' }
    #
    #       expect(last_response.status).to eq(400)
    #       expect(response_json).to eq('error' => 'sorry, something went wrong')
    #     end
    #   end
    # end

    describe 'GET /chains/:chain_id' do
      let!(:creator1) { create(:creator, handle: 'zach', creatable: chain) }
      let(:chain) { create(:chain, description: 'hi', url: 'e', duration: 3) }
      let!(:sound2) { create(:sound, chain: chain, url: 'b', duration: 3, included: true, position: 1) }

      let(:blob2) do
        {
          chain: {
            id: '58e513188447b3051caf486c',
            description: 'hi',
            url: 'e',
            duration: 3,
            creator: {
              handle: 'zach'
            },
            'sounds': [
              {
                id: '58e513188447b3051caf4875',
                url: 'b',
                duration: 3.0,
                position: 1,
                creator: {}
              }
            ]
          }
          }
      end

      context 'when a chain exists' do
        it 'returns some chain data' do
          xhr_get "/chains/#{chain.id}?api_key=#{account.api_key}"

          expect(response_json.to_json).to be_json_eql(blob2.to_json)
        end
      end

      context 'when a chain does not exist' do
        it 'fails' do
          xhr_get "/chains/pep?api_key=#{account.api_key}"

          expect(response_json).to eq('chain' => {})
        end
      end
    end

    describe 'GET /chains' do
      context 'when invoked' do
        let(:blob1) do
          {
            id: '58e513188447b3051caf4877',
            description: 'te',
            url: 't',
            duration: 5,
            creator: {},
            sounds: [
              {
                id: '58e513188447b3051caf4878',
                url: 'f',
                duration: 5.0,
                position: 1,
                creator: {}
              }
            ]
          }
        end

        let(:blob2) do
          {
            id: '58e513188447b3051caf486c',
            description: 'hi',
            url: 'e',
            duration: 3,
            creator: {
              handle: 'zach'
            },
            'sounds': [
              {
                id: '58e513188447b3051caf4875',
                url: 'b',
                duration: 3.0,
                position: 1,
                creator: {}
              }
            ]
          }
        end

        let(:blob3) do
          {
            id: '58e513188447b3051caf4873',
            description: 'yo',
            url: 'w',
            duration: 2,
            creator: {},
            sounds: [
              {
                id: '58e513188447b3051caf4874',
                url: 'a',
                duration: 2.0,
                position: 1,
                creator: {}
              }
            ]
          }
        end

        let(:blob4) do
          {
            id: '58e513188447b3051caf486e',
            description: 'fa',
            url: 'r',
            duration: 4,
            creator: {},
            sounds: [
              {
                id: '58e513188447b3051caf4876',
                url: 'c',
                duration: 2.0,
                position: 2,
                creator: {}
              }, {
                id: '58e513188447b3051caf486f',
                url: 'd',
                duration: 2.0,
                position: 3,
                creator: {
                  handle: 'chet'
                }
              }
            ]
          }
        end

        let!(:creator1) { create(:creator, handle: 'zach', creatable: chain3) }
        let!(:creator2) { create(:creator, handle: 'chet', creatable: sound4) }
        let!(:creator3) { create(:creator, handle: 'zach', creatable: sound5) }

        let(:chain1) { create(:chain, description: 'he', url: 'q', duration: 0) }
        let(:chain2) { create(:chain, description: 'yo', url: 'w', duration: 2) }
        let(:chain3) { create(:chain, description: 'hi', url: 'e', duration: 3) }
        let(:chain4) { create(:chain, description: 'fa', url: 'r', duration: 4) }
        let(:chain5) { create(:chain, description: 'te', url: 't', duration: 5) }

        let!(:sound1) { create(:sound, chain: chain2, url: 'a', duration: 2, included: true, position: 1) }
        let!(:sound2) { create(:sound, chain: chain3, url: 'b', duration: 3, included: true, position: 1) }
        let!(:sound3) { create(:sound, chain: chain4, url: 'c', duration: 2, included: true, position: 2) }
        let(:sound4) { create(:sound, chain: chain4, url: 'd', duration: 2, included: true, position: 3) }
        let(:sound5) { create(:sound, chain: chain4, url: 'e', duration: 1, included: false, position: 1) }
        let!(:sound6) { create(:sound, chain: chain5, url: 'f', duration: 5, included: true, position: 1) }

        it 'should return a little something' do
          xhr_get "/chains?api_key=#{account.api_key}"

          expect(response_json['chains'].count).to eq(4)
          expect(response_json['chains'].to_json).to include_json(blob1.to_json)
          expect(response_json['chains'].to_json).to include_json(blob2.to_json)
          expect(response_json['chains'].to_json).to include_json(blob3.to_json)
          expect(response_json['chains'].to_json).to include_json(blob4.to_json)
        end
      end
    end

    describe '#post /chains' do
      before do
        allow(BuildAudio).to receive(:perform).with(any_args).and_call_original
        allow(Qu).to receive(:enqueue).with(any_args).and_call_original
        allow(Qu::Payload).to receive(:new).with(any_args).and_call_original
        allow_any_instance_of(Sinatra::Application).to receive(:upload_to_s3).and_return('some_path')
        allow(BuildAudio).to receive(:combine_sounds).and_return(['blah', 5])
        allow(BuildAudio).to receive(:upload_to_s3).and_return('some_path')
      end

      context 'when no upload is provided' do
        it 'creates the chain' do
          expect(Chain.count).to eq(0)

          xhr_post '/chains', {}

          expect(Chain.count).to eq(1)
          expect(Chain.first.description).to be_nil
        end

        it 'does not queue a job or call processing functions' do
          expect_any_instance_of(Sinatra::Application).to_not receive(:upload_to_s3)
          expect_any_instance_of(Sinatra::Application).to_not receive(:combine_sounds)
          expect(Qu).to_not receive(:enqueue)

          xhr_post '/chains', {}
        end
      end

      context 'when an upload is provided' do
        let(:good_params) do
          {
            api_key: account.api_key,
            upload: Rack::Test::UploadedFile.new(File.expand_path('../mario.m4a', __FILE__), 'audio/m4a')
          }
        end

        it 'creates the chain' do
          expect(Chain.count).to eq(0)

          xhr_post '/chains', {}

          expect(Chain.count).to eq(1)
          expect(Chain.first.description).to be_nil
        end

        it 'enqueues a job' do
          xhr_post '/chains', good_params

          expect(Qu.length).to eq(1)
          expect(Qu::Payload).to have_received(:new).with(:klass => BuildAudio, :args => [Chain.first.id.to_s])
        end

        it 'runs a job' do
          Qu.backend = Qu::Backend::Immediate.new

          xhr_post '/chains', good_params

          expect(Chain.count).to eq(1)
          expect(Chain.first.description).to be_nil
          expect(BuildAudio).to have_received(:combine_sounds)
          expect(BuildAudio).to have_received(:upload_to_s3)
        end
      end
    end

    describe '#post /chains/:chain_id/sounds' do
      let(:good_params) do
        {
          api_key: account.api_key,
          upload: Rack::Test::UploadedFile.new(File.expand_path('../mario.m4a', __FILE__), 'audio/m4a')
        }
      end

      let(:chain) { Chain.create(description: 'A cool chain.', creator: Creator.new_with_account(account)) }
      let(:error_response_json) { { error: 'sorry, something went wrong' }.to_json }

      before do
        allow_any_instance_of(Sinatra::Application).to receive(:upload_to_s3).and_return('some_path')
        allow_any_instance_of(Sinatra::Application).to receive(:combine_sounds).and_return(['blah', 5])
      end

      context 'when everything is great' do
        it 'works' do
          xhr_post "/chains/#{chain.id}/sounds", good_params

          expect(response_json.to_json).to be_json_eql({chain: chain.reload.to_h}.to_json)
        end
      end

      context 'when something goes wrong' do
        before do
          allow_any_instance_of(Chain).to receive(:add_sound!).and_raise('aw fuck')
        end

        it 'renders a generic error message' do
          xhr_post "/chains/#{chain.id}/sounds", good_params

          expect(response_json).to eq('error' => 'sorry, something went wrong')
        end
      end
    end

    describe '#post /chains/:chain_id/sounds/:sound_id/toggle' do
      let(:chain) { Chain.create description: 'A cool chain.', url: 'tepid', duration: 1, creator: Creator.new_with_account(account) }

      context 'when fiddly bits are stubbed out' do
        let!(:sound) { chain.sounds.create url: 'something', duration: 5, included: true, visible: true }

        before do
          allow_any_instance_of(Sinatra::Application).to receive(:upload_to_s3).and_return('some_path')
          allow_any_instance_of(Sinatra::Application).to receive(:combine_sounds).and_return(['blah', 5])
        end

        context 'when something goes wrong' do
          before do
            sound.destroy
          end

          it 'responds with success = false and with the error' do
            expect(chain.included_sounds.count).to eq(0)
            expect(chain.sounds.count).to eq(0)

            xhr_post "/chains/#{chain.id}/sounds/#{sound.id}/toggle", api_key: account.api_key

            expect(response_json['error']).to eq('sorry, something went wrong')
          end
        end

        context 'when sound is included' do
          it 'dis-includes the sound' do
            expect(chain.included_sounds.count).to eq(1)
            expect(chain.sounds.count).to eq(1)

            xhr_post "/chains/#{chain.id}/sounds/#{sound.id}/toggle", api_key: account.api_key

            expect(response_json['chain']['sounds'].length).to eq(0)
            expect(response_json['chain']['url']).to eq('some_path')
            expect(response_json['chain']['duration']).to eq(5)
            expect(sound.reload.included).to eq(false)
            expect(chain.reload.included_sounds.count).to eq(0)
            expect(chain.sounds.count).to eq(1)
          end
        end

        context 'when sound is not included' do
          before do
            sound.included = false
            sound.save
          end

          it 'includes the sound' do
            expect(chain.included_sounds.count).to eq(0)
            expect(chain.sounds.count).to eq(1)

            xhr_post "/chains/#{chain.id}/sounds/#{sound.id}/toggle", api_key: account.api_key

            expect(response_json['chain']['sounds'].length).to eq(1)
            expect(response_json['chain']['url']).to eq('some_path')
            expect(response_json['chain']['duration']).to eq(5)
            expect(sound.reload.included).to eq(true)
            expect(chain.reload.included_sounds.count).to eq(1)
            expect(chain.sounds.count).to eq(1)
          end
        end
      end
    end

    describe '#post /chains/:chain_id/sounds/:sound_id/delete' do
      let(:chain) { create :chain, description: 'A cool chain.', creator: Creator.new_with_account(account) }
      let!(:sound) { create :sound, chain: chain, position: 1, url: 'something', duration: 5 }

      context 'when something goes wrong' do
        before do
          allow_any_instance_of(Sound).to receive(:update!).and_raise('hi')
        end

        it 'responds with an error' do
          xhr_post "/chains/#{chain.id}/sounds/#{sound.id}/delete", api_key: account.api_key

          expect(response_json['error']).to eq('sorry, something went wrong')
        end
      end

      context 'when the chain and sound exist' do
        context 'when the chain is visible' do
          it 'set visibility do false' do
            xhr_post "/chains/#{chain.id}/sounds/#{sound.id}/delete", api_key: account.api_key

            expect(sound.reload.visible).to eq(false)
          end
        end

        context 'when the sound is invisible' do
          before do
            sound.visible = false
            sound.save
          end

          it 'keeps visibility as false' do
            xhr_post "/chains/#{chain.id}/sounds/#{sound.id}/delete", api_key: account.api_key

            expect(sound.visible).to eq(false)
          end
        end
      end
    end
  end
end